import SwiftUI
import Photos

final class PhotoManager: ObservableObject {

    @Published var currentPhoto: UIImage?
    @Published var nextPhoto: UIImage?
    @Published var currentAsset: PHAsset?
    @Published var photoCount: Int = 0
    @Published var permissionStatus: PHAuthorizationStatus = .notDetermined
    @Published var isLoading: Bool = false
    @Published var deletedCount: Int = 0

    private var nextAsset: PHAsset?
    private struct UndoItem {
        let image: UIImage
        let asset: PHAsset
    }

    private var undoStack: [UndoItem] = []
    private var allAssetIDs: [String] = []

    private let workQueue = DispatchQueue(label: "PhotoManager", qos: .userInitiated)
    private let imageTargetSize: CGSize = {
        let scale = UIScreen.main.scale
        let screenWidth = UIScreen.main.bounds.width * scale
        let screenHeight = UIScreen.main.bounds.height * scale
        return CGSize(width: screenWidth, height: screenHeight)
    }()

    // MARK: - Permission

    func requestPermission() {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if current == .authorized || current == .limited {
            DispatchQueue.main.async { self.permissionStatus = current }
            startLoading()
            return
        }

        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async { self.permissionStatus = status }
            if status == .authorized || status == .limited {
                self.startLoading()
            }
        }
    }

    // MARK: - Bootstrap

    private func startLoading() {
        DispatchQueue.main.async { self.isLoading = true }

        workQueue.async {
            self.refreshAssetIDsSync()
            self.fetchRandomSync { image, asset in
                DispatchQueue.main.async {
                    self.currentPhoto = image
                    self.currentAsset = asset
                    self.isLoading = false
                }
            }
            self.fetchRandomSync { image, asset in
                DispatchQueue.main.async {
                    self.nextPhoto = image
                    self.nextAsset = asset
                }
            }
        }
    }

    // MARK: - Actions

    func keepCurrentPhoto() {
        if let image = currentPhoto, let asset = currentAsset {
            undoStack.append(UndoItem(image: image, asset: asset))
        }
        advanceToNext()
    }

    func deleteCurrentPhoto() {
        guard let asset = currentAsset, let image = currentPhoto else { return }

        undoStack.append(UndoItem(image: image, asset: asset))

        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets([asset] as NSFastEnumeration)
        }) { success, _ in
            if success {
                DispatchQueue.main.async {
                    self.deletedCount += 1
                }
                self.workQueue.async {
                    self.allAssetIDs.removeAll { $0 == asset.localIdentifier }
                    DispatchQueue.main.async { self.photoCount = self.allAssetIDs.count }
                }
            }
        }

        advanceToNext()
    }

    func undoLastAction() {
        guard let lastItem = undoStack.popLast() else { return }

        if let current = self.currentPhoto, let currentAsset = self.currentAsset {
            self.nextPhoto = current
            self.nextAsset = currentAsset
        }
        self.currentPhoto = lastItem.image
        self.currentAsset = lastItem.asset
    }

    var canUndo: Bool {
        !undoStack.isEmpty
    }

    // MARK: - Advance

    private func advanceToNext() {
        DispatchQueue.main.async {
            if let next = self.nextPhoto, let nextA = self.nextAsset {
                self.currentPhoto = next
                self.currentAsset = nextA
                self.nextPhoto = nil
                self.nextAsset = nil
            } else {
                self.currentPhoto = nil
                self.currentAsset = nil
                self.isLoading = true
            }
        }

        workQueue.async {
            if self.currentPhoto == nil {
                self.fetchRandomSync { image, asset in
                    DispatchQueue.main.async {
                        self.currentPhoto = image
                        self.currentAsset = asset
                        self.isLoading = false
                    }
                }
            }
            self.fetchRandomSync { image, asset in
                DispatchQueue.main.async {
                    self.nextPhoto = image
                    self.nextAsset = asset
                }
            }
        }
    }

    // MARK: - Sync Fetch Helpers

    private func refreshAssetIDsSync() {
        let opts = PHFetchOptions()
        opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let result = PHAsset.fetchAssets(with: .image, options: opts)
        var ids: [String] = []
        ids.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in
            ids.append(asset.localIdentifier)
        }
        allAssetIDs = ids
        DispatchQueue.main.async { self.photoCount = ids.count }
    }

    private func fetchRandomSync(completion: @escaping (UIImage?, PHAsset?) -> Void) {
        guard let randomID = allAssetIDs.randomElement() else {
            refreshAssetIDsSync()
            guard let retryID = allAssetIDs.randomElement() else {
                completion(nil, nil)
                return
            }
            fetchImageSync(identifier: retryID, completion: completion)
            return
        }
        fetchImageSync(identifier: randomID, completion: completion)
    }

    private func fetchImageSync(identifier: String, completion: @escaping (UIImage?, PHAsset?) -> Void) {
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = result.firstObject else {
            allAssetIDs.removeAll { $0 == identifier }
            completion(nil, nil)
            return
        }

        let manager = PHImageManager.default()
        let options = imageRequestOptions()
        options.isSynchronous = true

        var finalImage: UIImage?
        manager.requestImage(
            for: asset,
            targetSize: imageTargetSize,
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            finalImage = image
        }

        completion(finalImage, finalImage != nil ? asset : nil)
    }

    private func imageRequestOptions() -> PHImageRequestOptions {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        return options
    }
}

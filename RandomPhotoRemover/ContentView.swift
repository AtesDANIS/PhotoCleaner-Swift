import SwiftUI
import Photos
import PhotosUI
import CoreMotion

struct ContentView: View {
    @State private var selectedImage: UIImage?
    @State private var currentAsset: PHAsset?
    @State private var photoHistory: [PHAsset] = []
    @State private var historyIndex: Int = -1
    @State private var showingPermissionDenied = false
    @State private var showingDeleteConfirmation = false
    @State private var showingDeleteError = false
    @State private var downloadProgress: Double = 0.0
    @State private var isDownloading: Bool = false
    @State private var isSampleImage: Bool = false // Track if current image is a sample

    // List of sample image names in the app bundle
    private let sampleImageNames = ["sample1", "sample2", "sample3", "sample4"]

    var body: some View {
        VStack {
            if let image = selectedImage {
                if downloadProgress < 1.0 && !isSampleImage {
                    // Show progress bar during fetching (not for sample images)
                    VStack {
                        ProgressView(value: downloadProgress, total: 1.0)
                            .progressViewStyle(.linear)
                            .tint(.blue)
                            .scaleEffect(x: 1, y: 2, anchor: .center)
                            .padding(.horizontal, 20)
                            .animation(.easeInOut, value: downloadProgress)
                    }
                }

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 400)
                    .onTapGesture {
                        checkPermissionAndShowPhoto()
                    }

                HStack(spacing: 50) {
                    // Back Button
                    Button("⬅️") {
                        goBack()
                    }
                    .font(.largeTitle.bold())
                    .controlSize(.large)

                    // Delete Button (disabled for sample images)
                    Button("🗑️", role: .destructive) {
                        deleteCurrentPhoto()
                    }
                    .font(.largeTitle.bold())
                    .controlSize(.large)

                    Button("🔄") {
                        checkPermissionAndShowPhoto()
                    }
                    .font(.largeTitle.bold())
                    .controlSize(.large)
                }
                .padding()

                // Optional: Inform user if viewing sample images
                if isSampleImage {
                    Text("No photos found in gallery. Showing sample image.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.top, 5)
                }
            } else {
                Text("App needs access to your photos to show you a random photo from your gallery. Please grant permission in Settings.")
                    .font(.caption)
                    .foregroundColor(.gray)
              
                
                Button("🔄") {
                    checkPermissionAndShowPhoto()
                }
                .font(.largeTitle.bold())
                .controlSize(.large)
            }
        }
        .padding()
        .onAppear {
            checkPermissionAndShowPhoto()
        }
//        .onChange(of: selectedImage) { _, newValue in
//            print("UI: selectedImage changed to \(newValue == nil ? "nil" : "non-nil")")
//        }
//        .onChange(of: downloadProgress) { _, newValue in
//            print("UI: downloadProgress updated to \(newValue)")
//        }
        .alert("Permission Denied", isPresented: $showingPermissionDenied) {
            Button("Open Settings", action: openSettings)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable photo access in Settings to use this feature.")
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.deviceDidShakeNotification)) { _ in
            if !isSampleImage { // Prevent shake-to-delete for sample images
                deleteCurrentPhoto()
            }
        }
    }

    func checkPermissionAndShowPhoto() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    self.fetchRandomPhoto()
                case .denied, .restricted:
                    self.showingPermissionDenied = true
                case .notDetermined:
                    break
                @unknown default:
                    break
                }
            }
        }
    }

    func fetchRandomPhoto() {
        // Reset state
//        DispatchQueue.main.async {
//            print("Starting fetchRandomPhoto, resetting selectedImage")
//            self.downloadProgress = 0.0
//            self.isDownloading = true
//            self.selectedImage = nil
//            self.isSampleImage = false
//            self.currentAsset = nil
//        }

        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        if assets.count > 0 {
            // Fetch a random photo from the library
            let randomIndex = Int.random(in: 0..<assets.count)
            let asset = assets.object(at: randomIndex)
            self.currentAsset = asset

            // Update history
            if historyIndex < photoHistory.count - 1 {
                photoHistory = Array(photoHistory.prefix(historyIndex + 1))
            }
            photoHistory.append(asset)
            historyIndex += 1

            let manager = PHImageManager.default()
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.isSynchronous = false
            options.isNetworkAccessAllowed = true

            options.progressHandler = { progress, error, stop, info in
                DispatchQueue.main.async {
                    print("Progress handler: progress=\(progress), error=\(String(describing: error))")
                    self.downloadProgress = progress
                    self.isDownloading = true
                    if let error = error {
                        print("iCloud error: \(error)")
                        self.isDownloading = false
                        self.selectedImage = nil
                    }
                }
            }

            manager.requestImage(for: asset,
                                 targetSize: PHImageManagerMaximumSize,
                                 contentMode: .aspectFit,
                                 options: options) { image, info in
                DispatchQueue.main.async {
                    print("Image request completed: image=\(image != nil), info=\(String(describing: info))")
                    self.selectedImage = image
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        self.isDownloading = false
                    }
                    if image == nil {
                        print("Image is nil, info: \(String(describing: info))")
                        // Fallback to sample image if photo fetch fails
                        self.loadSampleImage()
                    }
                }
            }
        } else {
            // No photos in library, load a sample image
            DispatchQueue.main.async {
                print("No assets found in your gallery, loading sample images.")
                print("It will work in restricted mode.")
                self.loadSampleImage()
            }
        }
    }

    func loadSampleImage() {
        // Load a random sample image from the app bundle
        let randomImageName = sampleImageNames.randomElement()!
        if let image = UIImage(named: randomImageName) {
            self.selectedImage = image
            self.isSampleImage = true
            self.isDownloading = false
            self.currentAsset = nil
            // Clear history for sample images to prevent navigation issues
            self.photoHistory.removeAll()
            self.historyIndex = -1
        } else {
            print("Failed to load sample image: \(randomImageName)")
            self.selectedImage = nil
            self.isSampleImage = false
            self.isDownloading = false
        }
    }

    func goBack() {
        guard historyIndex > 0, !isSampleImage else { return }
        historyIndex -= 1
        let previousAsset = photoHistory[historyIndex]
        self.currentAsset = previousAsset

        // Reset state
        DispatchQueue.main.async {
            self.downloadProgress = 0.0
            self.isDownloading = true
            self.selectedImage = nil
        }

        // Fetch previous image
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isSynchronous = false
        options.isNetworkAccessAllowed = true

        options.progressHandler = { progress, error, stop, info in
            DispatchQueue.main.async {
                self.downloadProgress = progress
                self.isDownloading = true
                if let error = error {
                    print("iCloud error: \(error)")
                    self.isDownloading = false
                    self.selectedImage = nil
                }
            }
        }

        manager.requestImage(for: previousAsset,
                             targetSize: PHImageManagerMaximumSize,
                             contentMode: .aspectFit,
                             options: options) { image, info in
            DispatchQueue.main.async {
                self.selectedImage = image
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.isDownloading = false
                }
            }
        }
    }

    func deleteCurrentPhoto() {
        if currentAsset == nil || isSampleImage {
            return
        }
        let asset = currentAsset!

        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets([asset] as NSFastEnumeration)
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    print("Photo deleted, resetting selectedImage")
                    self.photoHistory.remove(at: self.historyIndex)
                    self.historyIndex -= 1
                    self.selectedImage = nil
                    self.currentAsset = nil
                    if self.historyIndex >= 0 {
                        self.goBack()
                    } else {
                        self.fetchRandomPhoto()
                    }
                } else {
                    self.showingDeleteError = true
                }
            }
        }
    }

    func openSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

extension UIDevice {
    static let deviceDidShakeNotification = Notification.Name(rawValue: "UIDeviceDeviceDidShakeNotification")
}

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: UIDevice.deviceDidShakeNotification, object: nil)
        }
    }
}

#Preview {
    ContentView()
}

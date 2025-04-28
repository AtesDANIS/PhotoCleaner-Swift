import SwiftUI
import Photos
import PhotosUI
import CoreMotion // Required for shake detection

struct ContentView: View {
    @State private var selectedImage: UIImage?
    @State private var currentAsset: PHAsset?
    @State private var photoHistory: [PHAsset] = [] // Store history of viewed photos
    @State private var historyIndex: Int = -1 // Track current position in history
    @State private var showingPermissionDenied = false
    @State private var showingDeleteConfirmation = false
    @State private var showingDeleteError = false
    @State private var downloadProgress: Double = 0.0
    @State private var isDownloading: Bool = false

    var body: some View {
        VStack {
            if let image = selectedImage {
                if downloadProgress < 1.0 {
                    // Show progress bar during fetching
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
                    .disabled(historyIndex <= 0) // Disable if no previous photos

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
            } else {
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
        .onChange(of: selectedImage) { _, newValue in
            print("UI: selectedImage changed to \(newValue == nil ? "nil" : "non-nil")")
        }
        .onChange(of: downloadProgress) { _, newValue in
            print("UI: downloadProgress updated to \(newValue)")
        }
        .alert("Permission Denied", isPresented: $showingPermissionDenied) {
            Button("Open Settings", action: openSettings)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable photo access in Settings to use this feature.")
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.deviceDidShakeNotification)) { _ in
            deleteCurrentPhoto()
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
        DispatchQueue.main.async {
            print("Starting fetchRandomPhoto, resetting selectedImage")
            self.downloadProgress = 0.0
            self.isDownloading = true
            self.selectedImage = nil
        }

        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        guard assets.count > 0 else {
            DispatchQueue.main.async {
                print("No assets found")
                self.isDownloading = false
                self.selectedImage = nil
            }
            return
        }

        let randomIndex = Int.random(in: 0..<assets.count)
        let asset = assets.object(at: randomIndex)
        self.currentAsset = asset

        // Update history
        if historyIndex < photoHistory.count - 1 {
            // If navigating forward after going back, truncate future history
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
                }
            }
        }
    }

    func goBack() {
        guard historyIndex > 0 else { return }
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
        guard let asset = currentAsset else { return }

        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets([asset] as NSFastEnumeration)
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    print("Photo deleted, resetting selectedImage")
                    // Remove the deleted asset from history
                    self.photoHistory.remove(at: self.historyIndex)
                    self.historyIndex -= 1
                    self.selectedImage = nil
                    self.currentAsset = nil
                    if self.historyIndex >= 0 {
                        // Show the previous photo if available
                        self.goBack()
                    } else {
                        // Fetch a new random photo if no history remains
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

// Extension to handle shake gesture
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

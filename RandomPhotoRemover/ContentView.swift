import SwiftUI
import Photos

struct ContentView: View {

    @StateObject private var manager = PhotoManager()
    @State private var cardID = UUID()

    var body: some View {
        ZStack {
            backgroundGradient

            switch manager.permissionStatus {
            case .authorized, .limited:
                photoContent
            case .denied, .restricted:
                deniedView
            default:
                permissionRequestView
            }
        }
        .onAppear {
            manager.requestPermission()
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color(white: 0.06), Color(white: 0.12)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Main Photo Content

    private var photoContent: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 8)

            Spacer(minLength: 12)

            cardStack
                .padding(.horizontal)

            Spacer(minLength: 12)

            bottomBar
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Photo Cleaner")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("\(manager.photoCount) photos remaining")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            if manager.deletedCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 12))
                    Text("\(manager.deletedCount)")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.red.opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.15), in: Capsule())
            }
        }
    }

    // MARK: - Card Stack

    private var cardStack: some View {
        GeometryReader { geo in
            ZStack {
                if let nextImage = manager.nextPhoto {
                    Image(uiImage: nextImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width - 32, height: geo.size.height)
                        .clipped()
                        .cornerRadius(20)
                        .scaleEffect(0.95)
                        .opacity(0.5)
                        .allowsHitTesting(false)
                }

                if let currentImage = manager.currentPhoto {
                    CardView(
                        image: currentImage,
                        onSwipeLeft: {
                            manager.deleteCurrentPhoto()
                            cardID = UUID()
                        },
                        onSwipeRight: {
                            manager.keepCurrentPhoto()
                            cardID = UUID()
                        }
                    )
                    .id(cardID)
                } else {
                    loadingView
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            Button {
                manager.undoLastAction()
                cardID = UUID()
            } label: {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(manager.canUndo ? .white.opacity(0.8) : .white.opacity(0.2))
            }
            .disabled(!manager.canUndo)

            Spacer()

            swipeHint

            Spacer()

            // Symmetry spacer matching undo button width
            Color.clear
                .frame(width: 32, height: 32)
        }
    }

    private var swipeHint: some View {
        HStack(spacing: 16) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 12, weight: .semibold))
                Text("Delete")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
            }
            .foregroundColor(.red.opacity(0.6))

            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 1, height: 16)

            HStack(spacing: 4) {
                Text("Keep")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(.green.opacity(0.6))
        }
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
            Text("Loading photo...")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.opacity(0.05))
        .cornerRadius(20)
        .padding(.horizontal)
    }

    // MARK: - Permission Views

    private var permissionRequestView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 80))
                .foregroundColor(.white.opacity(0.6))

            VStack(spacing: 8) {
                Text("Photo Access Needed")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Swipe through your photos and decide\nwhich to keep or delete — Tinder style.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }

            Button {
                manager.requestPermission()
            } label: {
                Text("Grant Access")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 40)

            Spacer()
        }
    }

    private var deniedView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 80))
                .foregroundColor(.white.opacity(0.4))

            VStack(spacing: 8) {
                Text("Access Denied")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Please enable photo access in\nSettings to use Photo Cleaner.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }

            Button {
                openSettings()
            } label: {
                Text("Open Settings")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 40)

            Spacer()
        }
    }

    // MARK: - Helpers

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

#Preview {
    ContentView()
}

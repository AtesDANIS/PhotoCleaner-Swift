import SwiftUI

struct CardView: View {

    let image: UIImage
    let onSwipeLeft: () -> Void
    let onSwipeRight: () -> Void

    @State private var offset: CGSize = .zero
    @State private var isGone = false

    private let swipeThreshold: CGFloat = 150
    private let maxRotation: Double = 12

    var body: some View {
        GeometryReader { geo in
            let dragProgress = offset.width / swipeThreshold

            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width - 32, height: geo.size.height)
                    .clipped()
                    .contentShape(Rectangle())

                // KEEP overlay — right swipe
                VStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 72, weight: .bold))
                    Text("KEEP")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                }
                .foregroundColor(.green)
                .padding(24)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                .opacity(Double(max(0, dragProgress)))
                .scaleEffect(max(0.5, min(1.0, abs(dragProgress))))
                .animation(.interactiveSpring(), value: dragProgress)

                // DELETE overlay — left swipe
                VStack {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 72, weight: .bold))
                    Text("DELETE")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                }
                .foregroundColor(.red)
                .padding(24)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                .opacity(Double(max(0, -dragProgress)))
                .scaleEffect(max(0.5, min(1.0, abs(dragProgress))))
                .animation(.interactiveSpring(), value: dragProgress)
            }
            .frame(width: geo.size.width - 32, height: geo.size.height)
            .background(Color(.systemGray6))
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 6)
            .rotationEffect(.degrees(Double(offset.width / 20) * (maxRotation / 10)))
            .offset(x: offset.width, y: 0)
            .frame(width: geo.size.width, height: geo.size.height)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        offset = value.translation
                    }
                    .onEnded { value in
                        handleSwipeEnd(translation: value.translation, screenWidth: geo.size.width)
                    }
            )
            .opacity(isGone ? 0 : 1)
        }
    }

    private func handleSwipeEnd(translation: CGSize, screenWidth: CGFloat) {
        if translation.width > swipeThreshold {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()

            withAnimation(.easeIn(duration: 0.25)) {
                offset = CGSize(width: screenWidth * 1.5, height: translation.height)
                isGone = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                onSwipeRight()
            }
        } else if translation.width < -swipeThreshold {
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()

            withAnimation(.easeIn(duration: 0.25)) {
                offset = CGSize(width: -screenWidth * 1.5, height: translation.height)
                isGone = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                onSwipeLeft()
            }
        } else {
            withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.7)) {
                offset = .zero
            }
        }
    }
}

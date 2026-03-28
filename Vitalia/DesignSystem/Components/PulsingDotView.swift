import SwiftUI

struct PulsingDotView: View {
    @State private var isAnimating = false

    var body: some View {
        Circle()
            .fill(VColor.accent)
            .frame(width: 8, height: 8)
            .scaleEffect(isAnimating ? 1.3 : 0.8)
            .opacity(isAnimating ? 1.0 : 0.4)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAnimating)
            .onAppear { isAnimating = true }
    }
}

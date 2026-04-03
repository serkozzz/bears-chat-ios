import SwiftUI

struct GradientBackground: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            Image(.gradientBackground)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            content
        }
    }
}

extension View {
    func gradientBackground() -> some View {
        modifier(GradientBackground())
    }
}

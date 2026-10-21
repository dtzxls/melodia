import SwiftUI

extension Color {
    static let melBackground = Color(red: 0.07, green: 0.07, blue: 0.09)
    static let melCard = Color(red: 0.10, green: 0.10, blue: 0.12)
    static let melElevated = Color(red: 0.14, green: 0.14, blue: 0.18)
    static let melAccent = Color(red: 0.114, green: 0.725, blue: 0.331)
    static let melTextPrimary = Color.white
    static let melTextSecondary = Color(red: 0.70, green: 0.70, blue: 0.70)
    static let melTextMuted = Color(red: 0.50, green: 0.50, blue: 0.50)
    static let melDivider = Color(red: 0.20, green: 0.20, blue: 0.22)
}

extension View {
    func cardStyle(corner: CGFloat = 10) -> some View {
        self.background(Color.melCard)
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }

    func elevatedStyle(corner: CGFloat = 14) -> some View {
        self.background(Color.melElevated)
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }
}

struct ScreenBackground: ViewModifier {
    func body(content: Content) -> some View {
        content.background(Color.melBackground.ignoresSafeArea())
    }
}

extension View {
    func screenBackground() -> some View {
        modifier(ScreenBackground())
    }
}
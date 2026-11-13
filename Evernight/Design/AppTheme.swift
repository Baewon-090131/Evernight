import SwiftUI

enum AppTheme {
    static let background = Color(red: 0.031, green: 0.024, blue: 0.039)
    static let surface = Color(red: 0.075, green: 0.051, blue: 0.086)
    static let raisedSurface = Color(red: 0.11, green: 0.075, blue: 0.125)
    static let ink = Color(red: 0.973, green: 0.953, blue: 0.965)
    static let muted = Color(red: 0.706, green: 0.659, blue: 0.702)
    static let red = Color(red: 0.624, green: 0.137, blue: 0.290)
    static let brightRed = Color(red: 0.839, green: 0.365, blue: 0.478)
    static let hairline = Color.white.opacity(0.11)
    static let cardRadius: CGFloat = 26
}

enum AppRelease {
    static let displayVersion = "v0.1-Fall Asleep Beta"
}

enum AppFont {
    static func pingFang(
        _ size: CGFloat,
        weight: Font.Weight = .regular,
        relativeTo style: Font.TextStyle = .body
    ) -> Font {
        .custom("PingFang SC", size: size, relativeTo: style).weight(weight)
    }

    static let body = pingFang(17)
    static let title = pingFang(28, weight: .semibold)
    static let title2 = pingFang(22, weight: .semibold)
    static let title3 = pingFang(20, weight: .semibold)
    static let headline = pingFang(17, weight: .semibold)
    static let subheadline = pingFang(15)
    static let footnote = pingFang(13)
    static let caption = pingFang(12)
    static let caption2 = pingFang(11)
}

struct EvernightBackground: View {
    var body: some View {
        ZStack {
            AppTheme.background

            Circle()
                .stroke(AppTheme.red.opacity(0.22), lineWidth: 1)
                .frame(width: 420, height: 420)
                .offset(x: 170, y: -330)

            Circle()
                .stroke(AppTheme.red.opacity(0.09), lineWidth: 1)
                .frame(width: 280, height: 280)
                .offset(x: -180, y: 350)
        }
        .ignoresSafeArea()
    }
}

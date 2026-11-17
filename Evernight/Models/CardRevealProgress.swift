import CoreGraphics

nonisolated struct CardRevealProgress {
    static let commitDistance: CGFloat = 105

    static func value(for translation: CGSize) -> CGFloat {
        let horizontalForward = max(-translation.width, 0)
        let verticalForward = max(-translation.height, max(translation.height, 0))

        if translation.width > 0, abs(translation.width) >= abs(translation.height) {
            return 0
        }

        return min(
            max(horizontalForward, verticalForward) / commitDistance,
            1
        )
    }
}

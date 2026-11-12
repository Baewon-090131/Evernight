import SwiftUI

struct GlassCapsuleModifier: ViewModifier {
    var tint: Color = .clear

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .glassEffect(
                    .regular.tint(tint).interactive(),
                    in: .capsule
                )
        } else {
            content
                .background(.ultraThinMaterial, in: .capsule)
                .overlay {
                    Capsule().stroke(AppTheme.hairline, lineWidth: 1)
                }
        }
    }
}

struct AdaptivePrimaryButtonStyle: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .buttonStyle(.glassProminent)
                .tint(AppTheme.red)
        } else {
            content
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.red)
        }
    }
}

struct PrimaryActionButton: View {
    let title: String
    let systemImage: String
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
        }
        .disabled(!isEnabled)
        .modifier(AdaptivePrimaryButtonStyle())
    }
}

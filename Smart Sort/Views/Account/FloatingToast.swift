import SwiftUI

struct FloatingToast: View {
    @Binding var message: String?
    private let theme = TrashTheme()

    var body: some View {
        if let text = message {
            Text(text)
                .font(theme.typography.caption)
                .foregroundColor(theme.onAccentForeground)
                .padding(.horizontal, 16)
                .frame(minHeight: theme.components.minimumHitTarget)
                .background(
                    Capsule()
                        .fill(theme.palette.textPrimary.opacity(0.92))
                )
                .padding(.top, 60)
                .padding(.horizontal, theme.components.contentInset)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation {
                            message = nil
                        }
                    }
                }
        }
    }
}

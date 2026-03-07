import SwiftUI

struct TrashCard<Content: View>: View {
    let cornerRadius: CGFloat?
    let content: Content
    private let theme = TrashTheme()

    init(cornerRadius: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: cornerRadius ?? 16, style: .continuous)
                    .fill(theme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius ?? 16, style: .continuous)
                            .stroke(theme.palette.divider.opacity(0.7), lineWidth: 1)
                    )
            )
    }
}

struct TrashButton<Content: View>: View {
    let action: () -> Void
    let baseColor: Color?
    let cornerRadius: CGFloat?
    let content: Content

    @State private var hapticTrigger = false

    init(
        baseColor: Color? = nil,
        cornerRadius: CGFloat? = nil,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.action = action
        self.baseColor = baseColor
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        Button(action: {
            hapticTrigger.toggle()
            action()
        }) {
            content
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(baseColor)
        .compatibleSensoryFeedback(.impactSolid(intensity: 0.6), trigger: hapticTrigger)
    }
}

struct TrashTapArea<Content: View>: View {
    let action: () -> Void
    var haptics: Bool = false
    let content: Content

    @State private var hapticTrigger = false

    init(haptics: Bool = false, action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.action = action
        self.haptics = haptics
        self.content = content()
    }

    var body: some View {
        Button(action: {
            if haptics { hapticTrigger.toggle() }
            action()
        }) {
            content
        }
        .buttonStyle(.plain)
        .compatibleSensoryFeedback(.impactSoft(intensity: 0.4), trigger: hapticTrigger)
    }
}

/// Consolidated: ThemeBackground is an alias for ThemeBackgroundView (defined in ThemeBackgroundView.swift).
/// Both names are supported for backward compatibility.
typealias ThemeBackground = ThemeBackgroundView

// MARK: - View Extensions

extension View {
    func trashCard(cornerRadius: CGFloat? = nil) -> some View {
        TrashCard(cornerRadius: cornerRadius) { self }
    }

    func trashInputStyle(cornerRadius: CGFloat? = nil) -> some View {
        modifier(TrashInputSurface(cornerRadius: cornerRadius))
    }
}

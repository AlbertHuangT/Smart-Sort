import SwiftUI

// MARK: - Legacy Theme Color Aliases
// These read from the shared theme constants directly.
extension Color {
    private static var theme: TrashTheme {
        TrashTheme()
    }

    @available(*, deprecated, renamed: "theme.palette.background", message: "Use @Environment(\\.trashTheme) and theme.palette.background")
    static var neuBackground: Color { theme.palette.background }
    @available(*, deprecated, renamed: "theme.shadows.light", message: "Use @Environment(\\.trashTheme) and theme.shadows.light")
    static var neuLightShadow: Color { theme.shadows.light }
    @available(*, deprecated, renamed: "theme.shadows.dark", message: "Use @Environment(\\.trashTheme) and theme.shadows.dark")
    static var neuDarkShadow: Color { theme.shadows.dark }
    @available(*, deprecated, renamed: "theme.palette.textPrimary", message: "Use @Environment(\\.trashTheme) and theme.palette.textPrimary")
    static var neuText: Color { theme.palette.textPrimary }
    @available(*, deprecated, renamed: "theme.palette.textSecondary", message: "Use @Environment(\\.trashTheme) and theme.palette.textSecondary")
    static var neuSecondaryText: Color { theme.palette.textSecondary }
    @available(*, deprecated, renamed: "theme.accents.blue", message: "Use @Environment(\\.trashTheme) and theme.accents.blue")
    static var neuAccentBlue: Color { theme.accents.blue }
    @available(*, deprecated, renamed: "theme.accents.green", message: "Use @Environment(\\.trashTheme) and theme.accents.green")
    static var neuAccentGreen: Color { theme.accents.green }
    @available(*, deprecated, renamed: "theme.accents.orange", message: "Use @Environment(\\.trashTheme) and theme.accents.orange")
    static var neuAccentOrange: Color { theme.accents.orange }
    @available(*, deprecated, renamed: "theme.accents.purple", message: "Use @Environment(\\.trashTheme) and theme.accents.purple")
    static var neuAccentPurple: Color { theme.accents.purple }
    @available(*, deprecated, renamed: "theme.palette.divider", message: "Use @Environment(\\.trashTheme) and theme.palette.divider")
    static var neuDivider: Color { theme.palette.divider }
}

// MARK: - Card Surface Modifier

struct NeumorphicShadow: ViewModifier {
    var isPressed: Bool = false
    var cornerRadius: CGFloat?
    private let theme = TrashTheme()

    func body(content: Content) -> some View {
        let radius = cornerRadius ?? theme.corners.large
        theme.cardSurface(cornerRadius: radius, content: content)
    }
}

// MARK: - Concave Modifier

struct NeumorphicConcave: ViewModifier {
    var cornerRadius: CGFloat?
    private let theme = TrashTheme()

    func body(content: Content) -> some View {
        let radius = cornerRadius ?? theme.corners.medium
        theme.cardSurface(cornerRadius: radius, content: content)
            .brightness(-0.05)
    }
}

// MARK: - Button Style

struct NeumorphicButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat?
    var color: Color?

    func makeBody(configuration: Configuration) -> some View {
        let theme = TrashTheme()
        let radius = cornerRadius ?? theme.corners.large

        theme.buttonSurface(
            isPressed: configuration.isPressed,
            cornerRadius: radius,
            baseColor: color,
            content: configuration.label
        )
    }
}

// MARK: - View Extensions
extension View {
    func neumorphic(isPressed: Bool = false, cornerRadius: CGFloat? = nil) -> some View {
        self.modifier(NeumorphicShadow(isPressed: isPressed, cornerRadius: cornerRadius))
    }

    func neumorphicConcave(cornerRadius: CGFloat? = nil) -> some View {
        self.modifier(NeumorphicConcave(cornerRadius: cornerRadius))
    }

    func neumorphicCard(padding: CGFloat? = nil) -> some View {
        let paddingValue = padding ?? TrashTheme().spacing.lg
        return self
            .padding(paddingValue)
            .neumorphic()
    }
}

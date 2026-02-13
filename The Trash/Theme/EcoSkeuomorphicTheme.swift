import SwiftUI
import UIKit

struct EcoSkeuomorphicTheme: TrashTheme {
    let name: String = "Eco Skeuomorphism"
    let visualStyle: VisualStyle = .ecoPaper
    let palette: ThemePalette
    let accents: ThemeAccents
    let shadows: ThemeShadowPalette
    let typography: ThemeTypography
    let spacing: ThemeSpacing
    let corners: ThemeCornerRadius
    let gradients: ThemeGradients
    let appearance: ThemeAppearance

    init() {
        palette = ThemePalette(
            background: Color(red: 0.90, green: 0.85, blue: 0.74),
            card: Color(red: 0.94, green: 0.89, blue: 0.78),
            textPrimary: Color(red: 0.13, green: 0.19, blue: 0.12),
            textSecondary: Color(red: 0.34, green: 0.39, blue: 0.30),
            divider: Color(red: 0.66, green: 0.60, blue: 0.50)
        )

        accents = ThemeAccents(
            blue: Color(red: 0.22, green: 0.39, blue: 0.35),
            green: Color(red: 0.21, green: 0.37, blue: 0.20),
            orange: Color(red: 0.62, green: 0.39, blue: 0.24),
            purple: Color(red: 0.41, green: 0.34, blue: 0.33)
        )

        shadows = ThemeShadowPalette(
            light: Color.white.opacity(0.22),
            dark: Color(red: 0.10, green: 0.12, blue: 0.07).opacity(0.24)
        )

        typography = ThemeTypography(
            title: .system(size: 33, weight: .bold, design: .serif),
            headline: .system(size: 22, weight: .semibold, design: .serif),
            subheadline: .system(size: 17, weight: .semibold, design: .serif),
            body: .system(size: 16, weight: .regular, design: .serif),
            caption: .system(size: 12, weight: .medium, design: .monospaced),
            button: .system(size: 16, weight: .semibold, design: .serif),
            heroIcon: .system(size: 48, weight: .semibold, design: .serif)
        )

        spacing = ThemeSpacing(xs: 4, sm: 9, md: 14, lg: 18, xl: 26, xxl: 38)
        corners = ThemeCornerRadius(small: 8, medium: 14, large: 22, pill: 30)

        gradients = ThemeGradients(
            primary: LinearGradient(
                colors: [Color(red: 0.28, green: 0.43, blue: 0.24), Color(red: 0.19, green: 0.31, blue: 0.17)],
                startPoint: .top,
                endPoint: .bottom
            ),
            accent: LinearGradient(
                colors: [accents.orange, accents.blue],
                startPoint: .leading,
                endPoint: .trailing
            )
        )

        let paperColor = UIColor(red: 0.88, green: 0.83, blue: 0.72, alpha: 1)
        let inkColor = UIColor(red: 0.12, green: 0.18, blue: 0.11, alpha: 1)
        appearance = ThemeAppearance(
            tabBarBackground: paperColor,
            tabBarSelectedTint: UIColor(red: 0.18, green: 0.33, blue: 0.18, alpha: 1),
            tabBarUnselectedTint: inkColor.withAlphaComponent(0.55),
            navigationBarBackground: paperColor,
            segmentedControl: ThemeAppearance.SegmentedControlAppearance(
                background: UIColor(red: 0.79, green: 0.74, blue: 0.64, alpha: 1),
                selectedBackground: UIColor(red: 0.20, green: 0.35, blue: 0.19, alpha: 1),
                text: UIColor(red: 0.34, green: 0.37, blue: 0.29, alpha: 1),
                selectedText: UIColor(red: 0.95, green: 0.93, blue: 0.87, alpha: 1)
            ),
            sheetBackground: Color(red: 0.93, green: 0.89, blue: 0.79)
        )
    }

    func backgroundView() -> AnyView {
        AnyView(
            GeometryReader { proxy in
                let width = proxy.size.width
                let height = proxy.size.height
                let maxEdge = max(width, height)

                ZStack {
                    PaperTextureView(baseColor: palette.background)

                    Ellipse()
                        .fill(accents.green.opacity(0.12))
                        .frame(width: maxEdge * 0.90, height: maxEdge * 0.58)
                        .blur(radius: maxEdge * 0.13)
                        .offset(x: -width * 0.35, y: -height * 0.30)

                    Ellipse()
                        .fill(accents.orange.opacity(0.11))
                        .frame(width: maxEdge * 0.78, height: maxEdge * 0.52)
                        .blur(radius: maxEdge * 0.12)
                        .offset(x: width * 0.37, y: height * 0.30)

                    Ellipse()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: maxEdge * 1.08, height: maxEdge * 0.52)
                        .blur(radius: maxEdge * 0.10)
                        .offset(x: 0, y: -height * 0.39)

                    LinearGradient(
                        colors: [Color.black.opacity(0.03), Color.clear, Color.black.opacity(0.11)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .frame(width: width, height: height)
                .clipped()
            }
            .ignoresSafeArea()
        )
    }

    func cardSurface<Content: View>(cornerRadius: CGFloat, content: Content) -> AnyView {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let underLayerShape = RoundedRectangle(cornerRadius: max(cornerRadius - 2, 6), style: .continuous)
        return AnyView(
            content
                .background(
                    ZStack {
                        underLayerShape
                            .fill(palette.divider.opacity(0.55))
                            .offset(y: 3)
                            .blur(radius: 0.2)

                        shape
                            .fill(palette.card)
                            .overlay(
                                PaperTextureView(baseColor: palette.card)
                                    .clipShape(shape)
                                    .opacity(0.38)
                            )
                            .overlay(
                                shape
                                    .stroke(palette.divider.opacity(0.92), lineWidth: 1)
                            )
                            .overlay(
                                shape
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    .padding(1)
                            )
                            .shadow(color: shadows.dark.opacity(0.9), radius: 10, x: 0, y: 4)
                    }
                )
        )
    }

    func buttonSurface<Content: View>(isPressed: Bool, cornerRadius: CGFloat, baseColor: Color?, content: Content) -> AnyView {
        let color = baseColor ?? accents.green
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let underLayerShape = RoundedRectangle(cornerRadius: max(cornerRadius - 2, 6), style: .continuous)
        return AnyView(
            content
                .trashOnAccentForeground()
                .background(
                    ZStack {
                        underLayerShape
                            .fill(color.opacity(0.75))
                            .offset(y: isPressed ? 1 : 2)

                        shape
                            .fill(
                                LinearGradient(
                                    colors: [color.opacity(0.98), color.opacity(0.9)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .overlay(
                                PaperTextureView(baseColor: color)
                                    .clipShape(shape)
                                    .opacity(0.12)
                            )
                            .overlay(
                                shape
                                    .stroke(palette.textPrimary.opacity(0.22), lineWidth: 1)
                            )
                            .overlay(
                                shape
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                    .padding(1)
                            )
                            .shadow(
                                color: Color.black.opacity(isPressed ? 0.12 : 0.22),
                                radius: isPressed ? 2 : 5,
                                x: 0,
                                y: isPressed ? 1 : 3
                            )
                    }
                )
                .scaleEffect(isPressed ? 0.988 : 1.0)
                .animation(.easeInOut(duration: 0.12), value: isPressed)
        )
    }

    func configureAppearance() {
        let paperColor = UIColor(red: 0.88, green: 0.83, blue: 0.72, alpha: 1)
        let inkColor = UIColor(red: 0.12, green: 0.18, blue: 0.11, alpha: 1)
        let selectedColor = UIColor(red: 0.18, green: 0.33, blue: 0.18, alpha: 1)

        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = paperColor
        tabBarAppearance.shadowColor = UIColor.clear
        tabBarAppearance.stackedLayoutAppearance.normal.iconColor = inkColor.withAlphaComponent(0.55)
        tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: inkColor.withAlphaComponent(0.55)]
        tabBarAppearance.stackedLayoutAppearance.selected.iconColor = selectedColor
        tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: selectedColor]
        tabBarAppearance.inlineLayoutAppearance.normal.iconColor = inkColor.withAlphaComponent(0.55)
        tabBarAppearance.inlineLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: inkColor.withAlphaComponent(0.55)]
        tabBarAppearance.inlineLayoutAppearance.selected.iconColor = selectedColor
        tabBarAppearance.inlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: selectedColor]
        tabBarAppearance.compactInlineLayoutAppearance.normal.iconColor = inkColor.withAlphaComponent(0.55)
        tabBarAppearance.compactInlineLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: inkColor.withAlphaComponent(0.55)]
        tabBarAppearance.compactInlineLayoutAppearance.selected.iconColor = selectedColor
        tabBarAppearance.compactInlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: selectedColor]
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        UITabBar.appearance().tintColor = selectedColor
        UITabBar.appearance().unselectedItemTintColor = inkColor.withAlphaComponent(0.55)

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = paperColor
        navAppearance.shadowColor = UIColor.clear
        navAppearance.titleTextAttributes = [.foregroundColor: inkColor]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: inkColor]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
    }
}

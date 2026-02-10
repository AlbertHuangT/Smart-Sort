
import SwiftUI

// MARK: - Neumorphic Colors (Dark Mode Adaptive)
extension Color {
    static let neuBackground = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 44/255, green: 48/255, blue: 62/255, alpha: 1)
            : UIColor(red: 224/255, green: 229/255, blue: 236/255, alpha: 1)
    })

    static let neuLightShadow = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 58/255, green: 63/255, blue: 78/255, alpha: 0.5)
            : UIColor.white.withAlphaComponent(0.7)
    })

    static let neuDarkShadow = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 25/255, green: 28/255, blue: 36/255, alpha: 0.7)
            : UIColor(red: 163/255, green: 177/255, blue: 198/255, alpha: 0.6)
    })

    // Text colors
    static let neuText = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 220/255, green: 225/255, blue: 235/255, alpha: 1)
            : UIColor(red: 77/255, green: 89/255, blue: 102/255, alpha: 1)
    })

    static let neuSecondaryText = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 150/255, green: 160/255, blue: 175/255, alpha: 1)
            : UIColor(red: 128/255, green: 140/255, blue: 153/255, alpha: 1)
    })

    // Accents
    static let neuAccentBlue = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 70/255, green: 130/255, blue: 255/255, alpha: 1)
            : UIColor(red: 50/255, green: 100/255, blue: 250/255, alpha: 1)
    })

    static let neuAccentGreen = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 60/255, green: 210/255, blue: 160/255, alpha: 1)
            : UIColor(red: 50/255, green: 200/255, blue: 150/255, alpha: 1)
    })

    static let neuAccentOrange = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 255/255, green: 159/255, blue: 60/255, alpha: 1)
            : UIColor(red: 240/255, green: 140/255, blue: 40/255, alpha: 1)
    })

    static let neuAccentPurple = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 160/255, green: 100/255, blue: 255/255, alpha: 1)
            : UIColor(red: 140/255, green: 80/255, blue: 230/255, alpha: 1)
    })

    // Card background (same as neuBackground but available as a semantic alias)
    static let neuCardBackground = Color.neuBackground

    // Divider
    static let neuDivider = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 60/255, green: 65/255, blue: 80/255, alpha: 0.5)
            : UIColor(red: 190/255, green: 197/255, blue: 210/255, alpha: 0.5)
    })
}

// MARK: - Neumorphic Shadow Modifier
struct NeumorphicShadow: ViewModifier {
    var isPressed: Bool = false
    var cornerRadius: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .background(
                Group {
                    if isPressed {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(Color.neuBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: cornerRadius)
                                    .stroke(Color.neuBackground, lineWidth: 4)
                                    .shadow(color: .neuDarkShadow, radius: 10, x: 5, y: 5)
                                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                                    .shadow(color: .neuLightShadow, radius: 10, x: -5, y: -5)
                                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                            )
                    } else {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(Color.neuBackground)
                            .shadow(color: .neuDarkShadow, radius: 10, x: 10, y: 10)
                            .shadow(color: .neuLightShadow, radius: 10, x: -5, y: -5)
                    }
                }
            )
    }
}

// MARK: - Neumorphic Concave Modifier (Pressed/Inset Look)
struct NeumorphicConcave: ViewModifier {
    var cornerRadius: CGFloat = 12

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.neuBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.neuBackground, lineWidth: 2)
                            .shadow(color: .neuDarkShadow, radius: 3, x: 3, y: 3)
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                            .shadow(color: .neuLightShadow, radius: 3, x: -3, y: -3)
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    )
            )
    }
}

// MARK: - Neumorphic Button Style
struct NeumorphicButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 20
    var color: Color = .neuBackground

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(
                Group {
                    if configuration.isPressed {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(color)
                            .overlay(
                                RoundedRectangle(cornerRadius: cornerRadius)
                                    .stroke(color, lineWidth: 4)
                                    .shadow(color: Color.neuDarkShadow, radius: 4, x: 5, y: 5)
                                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                                    .shadow(color: Color.neuLightShadow, radius: 4, x: -2, y: -2)
                                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                            )
                    } else {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(color)
                            .shadow(color: Color.neuDarkShadow, radius: 10, x: 10, y: 10)
                            .shadow(color: Color.neuLightShadow, radius: 10, x: -5, y: -5)
                    }
                }
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - View Extensions
extension View {
    func neumorphic(isPressed: Bool = false, cornerRadius: CGFloat = 20) -> some View {
        self.modifier(NeumorphicShadow(isPressed: isPressed, cornerRadius: cornerRadius))
    }

    func neumorphicConcave(cornerRadius: CGFloat = 12) -> some View {
        self.modifier(NeumorphicConcave(cornerRadius: cornerRadius))
    }

    func neumorphicCard(padding: CGFloat = 20) -> some View {
        self
            .padding(padding)
            .background(Color.neuBackground)
            .neumorphic()
    }
}

// MARK: - UIAppearance Configuration
enum NeumorphicAppearance {
    static func configureGlobalAppearance() {
        // Segmented Control
        let segBg = UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 38/255, green: 42/255, blue: 54/255, alpha: 1)
                : UIColor(red: 214/255, green: 219/255, blue: 226/255, alpha: 1)
        }
        let segSelected = UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 54/255, green: 58/255, blue: 72/255, alpha: 1)
                : UIColor.white
        }
        let segText = UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 150/255, green: 160/255, blue: 175/255, alpha: 1)
                : UIColor(red: 128/255, green: 140/255, blue: 153/255, alpha: 1)
        }
        let segSelectedText = UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 220/255, green: 225/255, blue: 235/255, alpha: 1)
                : UIColor(red: 77/255, green: 89/255, blue: 102/255, alpha: 1)
        }

        UISegmentedControl.appearance().backgroundColor = segBg
        UISegmentedControl.appearance().selectedSegmentTintColor = segSelected
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: segText], for: .normal)
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: segSelectedText], for: .selected)

        // Navigation Bar — match neuBackground so NavigationStack views look consistent
        let navBg = UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 44/255, green: 48/255, blue: 62/255, alpha: 1)
                : UIColor(red: 224/255, green: 229/255, blue: 236/255, alpha: 1)
        }
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = navBg
        navAppearance.shadowColor = nil  // Remove bottom separator
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
    }
}

import Combine
import SwiftUI

// MARK: - SWAlertType

enum SWAlertType {
    case info
    case success
    case warning
    case error

    var icon: String {
        switch self {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        }
    }

    var textColor: Color {
        let theme = TrashTheme()
        switch self {
        case .info: return theme.palette.textPrimary
        case .success: return theme.semanticSuccess
        case .warning: return theme.semanticWarning
        case .error: return theme.semanticDanger
        }
    }

    var borderColor: Color {
        let theme = TrashTheme()
        switch self {
        case .info: return theme.palette.divider
        case .success: return theme.semanticSuccess.opacity(0.5)
        case .warning: return theme.semanticWarning.opacity(0.5)
        case .error: return theme.semanticDanger.opacity(0.5)
        }
    }
}

// MARK: - SWAlertManager

@MainActor
final class SWAlertManager: ObservableObject {
    static let shared = SWAlertManager()

    @Published private(set) var isShowing = false
    @Published private(set) var icon = SWAlertType.info.icon
    @Published private(set) var message: String = ""
    @Published private(set) var textColor = SWAlertType.info.textColor
    @Published private(set) var borderColor = SWAlertType.info.borderColor

    private var dismissTask: Task<Void, Never>?

    private init() {}

    func show(_ type: SWAlertType, message: String, duration: Duration = .seconds(2)) {
        showInternal(icon: type.icon, message: message, textColor: type.textColor,
                     borderColor: type.borderColor, duration: duration)
    }

    private func showInternal(icon: String, message: String, textColor: Color,
                               borderColor: Color, duration: Duration) {
        dismissTask?.cancel()
        self.icon = icon
        self.message = message
        self.textColor = textColor
        self.borderColor = borderColor
        withAnimation { isShowing = true }
        dismissTask = Task {
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            withAnimation { isShowing = false }
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        withAnimation { isShowing = false }
    }
}

// MARK: - Alert View

private struct SWAlertView: View {
    @ObservedObject var alertManager = SWAlertManager.shared
    @Environment(\.trashTheme) private var theme

    var body: some View {
        if alertManager.isShowing {
            HStack(spacing: 6) {
                Image(systemName: alertManager.icon)
                    .font(.footnote)
                Text(alertManager.message)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(alertManager.textColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(theme.surfaceBackground, in: Capsule())
            .overlay(Capsule().strokeBorder(alertManager.borderColor, lineWidth: 0.5))
            .transition(.scale.combined(with: .opacity))
            .onTapGesture { alertManager.dismiss() }
        }
    }
}

// MARK: - View Modifier

private struct SWAlertModifier: ViewModifier {
    @ObservedObject var alertManager = SWAlertManager.shared

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                SWAlertView()
                    .padding(.top, 40)
            }
            .animation(.spring(duration: 0.3), value: alertManager.isShowing)
    }
}

// MARK: - View Extension

extension View {
    func swAlert() -> some View {
        modifier(SWAlertModifier())
    }
}

import SwiftUI

// MARK: - Onboarding Page Model

enum OnboardingPage: CaseIterable {
    case scan
    case earn
    case compete

    var icon: String {
        switch self {
        case .scan: "camera.viewfinder"
        case .earn: "flame.fill"
        case .compete: "chart.bar.fill"
        }
    }

    var title: String {
        switch self {
        case .scan: "Scan & Sort"
        case .earn: "Earn Credits"
        case .compete: "Compete & Connect"
        }
    }

    var description: String {
        switch self {
        case .scan: "Point your camera at any item and Smart Sort's on-device AI will instantly identify what type of trash it is."
        case .earn: "Every correct scan earns you credits. Level up, unlock achievements, and build your recycling streak."
        case .compete: "Climb the leaderboard with friends, join local communities, and test your knowledge in Arena mode."
        }
    }

}

// MARK: - Onboarding View

struct SWOnboardingView: View {
    let onComplete: () -> Void
    private let pages = OnboardingPage.allCases
    @State private var currentPage = 0
    @Environment(\.trashTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.element) { index, page in
                    onboardingPage(page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            VStack(spacing: 12) {
                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation { currentPage += 1 }
                    } else {
                        onComplete()
                    }
                } label: {
                    Text(currentPage < pages.count - 1 ? "Continue" : "Get Started")
                        .font(theme.typography.button)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(accentColor(for: pages[currentPage]))
                        .foregroundColor(theme.onAccentForeground)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Button { onComplete() } label: {
                    Text("Skip")
                        .font(theme.typography.subheadline)
                        .foregroundColor(theme.palette.textSecondary)
                }
                .opacity(currentPage < pages.count - 1 ? 1 : 0)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .trashScreenBackground()
    }

    private func onboardingPage(_ page: OnboardingPage) -> some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(accentColor(for: page).opacity(0.12))
                    .frame(width: 140, height: 140)
                Image(systemName: page.icon)
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(accentColor(for: page))
            }

            VStack(spacing: 12) {
                Text(page.title)
                    .font(theme.typography.title)
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(theme.typography.body)
                    .foregroundColor(theme.palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private func accentColor(for page: OnboardingPage) -> Color {
        switch page {
        case .scan:
            return theme.accents.blue
        case .earn:
            return theme.accents.orange
        case .compete:
            return theme.accents.green
        }
    }
}

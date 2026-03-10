import Auth
import Supabase
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject private var appRouter: AppRouter
    @Environment(\.trashTheme) private var theme

    var body: some View {
        ZStack {
            ThemeBackgroundView()

            TabView(selection: $appRouter.selectedTab) {
                NavigationStack {
                    VerifyView()
                }
                .tabItem {
                    Label("Verify", systemImage: "camera")
                }
                .tag(AppRouter.Tab.verify)

                ArenaHubView()
                    .tabItem {
                        Label("Arena", systemImage: "flag.checkered")
                    }
                    .tag(AppRouter.Tab.arena)

                NavigationStack {
                    LeaderboardView()
                }
                .tabItem {
                    Label("Leaderboard", systemImage: "chart.bar")
                }
                .tag(AppRouter.Tab.leaderboard)

                NavigationStack {
                    CommunityView()
                }
                .tabItem {
                    Label("Community", systemImage: "person.3")
                }
                .tag(AppRouter.Tab.community)
            }
            .sheet(item: $appRouter.activeSheet) { sheet in
                switch sheet {
                case .account:
                    AccountView()
                        .environmentObject(authVM)
                        .environmentObject(appRouter)
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                        .presentationBackground(theme.appearance.sheetBackground)

                case .createEvent:
                    CreateEventFormSheet(
                        isPresented: sheetBinding(for: .createEvent),
                        userSettings: UserSettings.shared
                    ) {
                        NotificationCenter.default.post(name: .communityEventsDidChange, object: nil)
                        appRouter.dismissSheet()
                    }
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(theme.appearance.sheetBackground)

                case .createCommunity:
                    CreateCommunitySheet(
                        isPresented: sheetBinding(for: .createCommunity),
                        onCreated: {
                            appRouter.dismissSheet()
                        }
                    )
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(theme.appearance.sheetBackground)
                }
            }
        }
    }

    private func sheetBinding(for sheet: AppRouter.Sheet) -> Binding<Bool> {
        Binding(
            get: { appRouter.activeSheet == sheet },
            set: { isPresented in
                if !isPresented && appRouter.activeSheet == sheet {
                    appRouter.dismissSheet()
                }
            }
        )
    }
}

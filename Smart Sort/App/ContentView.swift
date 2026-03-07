import Auth
import Supabase
import SwiftUI

struct ContentView: View {
    @State private var selectedTab = Tab.verify
    @State private var showAccountSheet = false
    @ObservedObject private var arenaRouter = ArenaRouter.shared
    @EnvironmentObject var authVM: AuthViewModel

    enum Tab: Hashable {
        case verify
        case arena
        case leaderboard
        case community
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                VerifyView()
            }
            .tabItem {
                Label("Verify", systemImage: "camera")
            }
            .tag(Tab.verify)

            ArenaHubView()
                .tabItem {
                    Label("Arena", systemImage: "flag.checkered")
                }
                .tag(Tab.arena)

            NavigationStack {
                LeaderboardView()
            }
            .tabItem {
                Label("Leaderboard", systemImage: "chart.bar")
            }
            .tag(Tab.leaderboard)

            NavigationStack {
                CommunityView()
            }
            .tabItem {
                Label("Community", systemImage: "person.3")
            }
            .tag(Tab.community)
        }
        .sheet(isPresented: $showAccountSheet) {
            AccountView()
                .environmentObject(authVM)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .onReceive(NotificationCenter.default.publisher(for: .showAccountSheet)) { _ in
            showAccountSheet = true
        }
        .onChange(of: arenaRouter.pendingChallengeId) { newValue in
            if newValue != nil {
                selectedTab = .arena
            }
        }
    }
}

import SwiftUI
import Supabase
import Auth

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            VerifyView()
                .tabItem {
                    Label("Verify", systemImage: "camera.viewfinder")
                }
                .tag(0)
            
            ArenaView()
                .tabItem {
                    Label("Arena", systemImage: "flame.fill")
                }
                .tag(1)
            
            LeaderboardView()
                .tabItem {
                    Label("Leaderboard", systemImage: "chart.bar.fill")
                }
                .tag(2)
            
            CommunityTabView()
                .tabItem {
                    Label("Community", systemImage: "person.3.fill")
                }
                .tag(3)
            
            CommunityView()
                .tabItem {
                    Label("Events", systemImage: "calendar.badge.clock")
                }
                .tag(4)
        }
        .tint(.blue)
    }
}

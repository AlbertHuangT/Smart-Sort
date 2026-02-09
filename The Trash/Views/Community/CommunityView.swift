//
//  CommunityView.swift
//  The Trash
//
//  Created by Albert Huang on 2/7/26.
//

import SwiftUI

struct CommunityView: View {
    @State private var selectedTab: CommunityTab = .events
    @State private var showAccountSheet = false
    @EnvironmentObject var authVM: AuthViewModel
    
    enum CommunityTab: String, CaseIterable {
        case events = "Events"
        case groups = "Community"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Shared Header
                appStoreHeader(title: "Community")
                
                // Content
                VStack(spacing: 0) {
                    // Top Segmented Control
                    Picker("Section", selection: $selectedTab) {
                        ForEach(CommunityTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.neuBackground)
                    
                    // Main Content Area
                    TabView(selection: $selectedTab) {
                        EventsView()
                            .tag(CommunityTab.events)
                        
                        GroupsView()
                            .tag(CommunityTab.groups)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never)) // Allow swiping, optional
                    .ignoresSafeArea(edges: .bottom)
                }
            }
            .background(Color.neuBackground)
        }
    }
    
    // MARK: - App Store Style Header
    private func appStoreHeader(title: String) -> some View {
        HStack(alignment: .center) {
            Text(title)
                .font(.system(size: 34, weight: .bold, design: .default))
                .foregroundColor(.neuText)
            
            Spacer()
            
            AccountButton(showAccountSheet: $showAccountSheet)
                .environmentObject(authVM)
        }
        .padding(.leading, 16)
        .padding(.trailing, 20)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Color.neuBackground)
    }
}

#Preview {
    CommunityView()
        .environmentObject(AuthViewModel())
}

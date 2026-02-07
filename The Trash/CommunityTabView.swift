//
//  CommunityTabView.swift
//  The Trash
//
//  Created by Albert Huang on 2/6/26.
//

import SwiftUI
import CoreLocation

// MARK: - Community Tab Sections

enum CommunityTabSection: String, CaseIterable {
    case nearby = "Nearby"
    case joined = "Joined"
    
    var icon: String {
        switch self {
        case .nearby: return "location.fill"
        case .joined: return "checkmark.circle.fill"
        }
    }
}

// MARK: - Main View

struct CommunityTabView: View {
    @ObservedObject private var userSettings = UserSettings.shared
    @EnvironmentObject var authVM: AuthViewModel
    @State private var showAccountSheet = false
    @State private var selectedSection: CommunityTabSection = .nearby
    @State private var searchText = ""
    @State private var showLocationPicker = false
    @State private var showCreateEventSheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 🎨 App Store 风格头部
            appStoreHeader(title: "Communities")
            
            // 匿名用户限制
            if authVM.isAnonymous {
                anonymousRestrictionView
            } else {
                // Section Picker
                sectionPicker
                
                // Content
                switch selectedSection {
                case .nearby:
                    nearbyCommunitiesContent
                case .joined:
                    joinedCommunitiesContent
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showLocationPicker) {
            LocationPickerSheet(isPresented: $showLocationPicker)
        }
        .sheet(isPresented: $showCreateEventSheet) {
            CreateEventSheet(isPresented: $showCreateEventSheet)
        }
    }
    
    // MARK: - 🎨 App Store Style Header
    private func appStoreHeader(title: String) -> some View {
        HStack(alignment: .center) {
            Text(title)
                .font(.system(size: 34, weight: .bold, design: .default))
            
            Spacer()
            
            AccountButton(showAccountSheet: $showAccountSheet)
                .environmentObject(authVM)
        }
        .padding(.leading, 16)
        .padding(.trailing, 20)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
    
    // MARK: - Section Picker
    
    private var sectionPicker: some View {
        Picker("Section", selection: $selectedSection) {
            ForEach(CommunityTabSection.allCases, id: \.self) { section in
                Label(section.rawValue, systemImage: section.icon)
                    .tag(section)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Nearby Communities Content
    
    @ViewBuilder
    private var nearbyCommunitiesContent: some View {
        VStack(spacing: 0) {
            // Location Header
            locationHeader
            
            if userSettings.selectedLocation == nil {
                noLocationView
            } else if userSettings.isLoadingCommunities {
                loadingView
            } else if userSettings.communitiesInCity.isEmpty {
                emptyNearbyView
            } else {
                nearbyCommunitiesList
            }
        }
        .task {
            // 🔥 FIX: 首次进入时，如果已有选择的地点但社区列表为空，则加载社区
            if let location = userSettings.selectedLocation, userSettings.communitiesInCity.isEmpty {
                await userSettings.loadCommunitiesForCity(location.city)
            }
        }
    }
    
    private var locationHeader: some View {
        Button(action: { showLocationPicker = true }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    if let location = userSettings.selectedLocation {
                        Text(location.city)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(location.state)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Select Location")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("Tap to choose your city")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .buttonStyle(.plain)
    }
    
    private var noLocationView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "location.slash.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No Location Set")
                .font(.title2).bold()
            Text("Select a location to discover\ncommunities near you")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button(action: { showLocationPicker = true }) {
                Text("Select Location")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(20)
            }
            Spacer()
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
            Text("Loading communities...")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
    
    private var emptyNearbyView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "building.2.crop.circle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No Communities Yet")
                .font(.title2).bold()
            Text("No communities in this area yet.\nBe the first to start one!")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
    
    private var nearbyCommunitiesList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(userSettings.communitiesInCity) { community in
                    CommunityCardView(community: community)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .refreshable {
            if let location = userSettings.selectedLocation {
                await userSettings.loadCommunitiesForCity(location.city)
            }
        }
    }
    
    // MARK: - Joined Communities Content
    
    @ViewBuilder
    private var joinedCommunitiesContent: some View {
        Group {
            if userSettings.isLoadingCommunities && userSettings.joinedCommunities.isEmpty {
                loadingView
            } else if userSettings.joinedCommunities.isEmpty {
                emptyJoinedView
            } else {
                joinedCommunitiesList
            }
        }
        .task {
            // 只在首次进入或列表为空时加载
            if userSettings.joinedCommunities.isEmpty {
                await userSettings.loadMyCommunities()
            }
        }
    }
    
    private var emptyJoinedView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "person.3.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No Communities Joined")
                .font(.title2).bold()
            Text("Join communities to connect with\npeople in your area")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button(action: { selectedSection = .nearby }) {
                Text("Browse Nearby")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(20)
            }
            Spacer()
        }
    }
    
    private var joinedCommunitiesList: some View {
        List {
            ForEach(userSettings.joinedCommunities) { community in
                JoinedCommunityRowExpanded(
                    community: community,
                    onCreateEvent: {
                        // TODO: 打开创建活动的 sheet，传入社区信息
                        showCreateEventSheet = true
                    }
                )
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await userSettings.loadMyCommunities()
        }
    }
    
    // MARK: - Anonymous Restriction View
    
    private var anonymousRestrictionView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 80))
                .foregroundStyle(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                .padding(.bottom, 10)
            
            Text("Access Restricted")
                .font(.title).bold()
            
            Text("Communities are only available for registered users.\n\nPlease link your Email or Phone in your Account to access this feature.")
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

// MARK: - Joined Community Row with Admin Features

struct JoinedCommunityRowExpanded: View {
    let community: Community
    let onCreateEvent: () -> Void
    @ObservedObject private var userSettings = UserSettings.shared
    @State private var isLoading = false
    @State private var isAdmin = false // TODO: 从后端获取用户在该社区的角色
    
    var body: some View {
        NavigationLink(destination: CommunityDetailView(community: community)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.cyan.opacity(0.15))
                            .frame(width: 50, height: 50)
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.cyan)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(community.name)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            if isAdmin {
                                Text("Admin")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.15))
                                    .cornerRadius(4)
                            }
                        }
                        
                        HStack(spacing: 8) {
                            Label(community.fullLocation, systemImage: "mappin.circle.fill")
                            Label("\(community.memberCount)", systemImage: "person.2.fill")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                if !community.description.isEmpty {
                    Text(community.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                // Action Buttons
                HStack(spacing: 12) {
                    // Admin: Create Event Button
                    if isAdmin {
                        Button(action: onCreateEvent) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Create Event")
                            }
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.green)
                            .cornerRadius(10)
                        }
                    }
                    
                    // Leave Button
                    Button(action: {
                        Task {
                            isLoading = true
                            _ = await userSettings.leaveCommunity(community)
                            isLoading = false
                        }
                    }) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "xmark.circle.fill")
                                Text("Leave")
                            }
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(.red)
                        .frame(maxWidth: isAdmin ? nil : .infinity)
                        .padding(.vertical, 10)
                        .padding(.horizontal, isAdmin ? 20 : 0)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(10)
                    }
                    .disabled(isLoading)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Location Picker Sheet

struct LocationPickerSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject private var userSettings = UserSettings.shared
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search cities...", text: $searchText)
                }
                .padding(12)
                .background(Color(.tertiarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                // Location List
                List {
                    ForEach(PredefinedLocations.search(query: searchText), id: \.city) { location in
                        Button(action: {
                            Task {
                                await userSettings.selectLocation(location)
                                isPresented = false
                            }
                        }) {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(Color.blue.opacity(0.15))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.blue)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(location.city)
                                        .font(.subheadline.bold())
                                        .foregroundColor(.primary)
                                    Text(location.state)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if userSettings.selectedLocation?.city == location.city {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

// MARK: - Create Event Sheet (Placeholder)

struct CreateEventSheet: View {
    @Binding var isPresented: Bool
    @State private var title = ""
    @State private var description = ""
    @State private var eventDate = Date()
    @State private var location = ""
    @State private var category = "cleanup"
    @State private var maxParticipants = 50
    
    let categories = ["cleanup", "workshop", "competition", "education", "other"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Event Details") {
                    TextField("Event Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    DatePicker("Date & Time", selection: $eventDate)
                    TextField("Location", text: $location)
                }
                
                Section("Settings") {
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { cat in
                            Text(cat.capitalized).tag(cat)
                        }
                    }
                    
                    Stepper("Max Participants: \(maxParticipants)", value: $maxParticipants, in: 10...500, step: 10)
                }
            }
            .navigationTitle("Create Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        // TODO: 调用后端 API 创建活动
                        isPresented = false
                    }
                    .disabled(title.isEmpty || location.isEmpty)
                }
            }
        }
    }
}

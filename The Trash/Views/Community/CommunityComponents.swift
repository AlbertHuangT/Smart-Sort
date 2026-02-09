//
//  CommunityComponents.swift
//  The Trash
//
//  Extracted from AccountView.swift and CommunityTabView.swift
//

import SwiftUI

// MARK: - Community Selection Sheet
struct CommunitySelectionSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject private var userSettings = UserSettings.shared
    @State private var searchText = ""
    @State private var selectedTab = 0

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    Text("Location").tag(0)
                    Text("My Communities").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 8)

                if selectedTab == 0 {
                    locationSelectionView
                } else {
                    communitiesView
                }
            }
            .background(Color.neuBackground)
            .navigationTitle("Location & Communities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }

    private var locationSelectionView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.neuSecondaryText)
                TextField("Search cities...", text: $searchText)
                    .foregroundColor(.neuText)
                    .autocapitalization(.none)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.neuSecondaryText)
                    }
                }
            }
            .padding(12)
            .neumorphicConcave(cornerRadius: 12)
            .padding(.horizontal, 16)
            .padding(.top, 12)

            if let location = userSettings.selectedLocation {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.neuAccentBlue)
                    Text("Current: \(location.displayName)")
                        .font(.subheadline)
                        .foregroundColor(.neuText)
                    Spacer()
                    Button("Change") {
                        Task {
                            await userSettings.selectLocation(nil)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.neuAccentBlue)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.neuAccentBlue.opacity(0.1))

                localCommunitiesSection
            } else {
                List {
                    ForEach(PredefinedLocations.search(query: searchText), id: \.city) { location in
                        LocationRowView(location: location) {
                            Task {
                                await userSettings.selectLocation(location)
                            }
                            searchText = ""
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.neuBackground)
            }
        }
        .onAppear {
            if let location = userSettings.selectedLocation, userSettings.communitiesInCity.isEmpty {
                Task {
                    await userSettings.loadCommunitiesForCity(location.city)
                }
            }
        }
    }

    private var localCommunitiesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Communities in \(userSettings.selectedLocation?.city ?? "")")
                .font(.subheadline.bold())
                .foregroundColor(.neuText)
                .padding(.horizontal, 16)
                .padding(.top, 12)

            if userSettings.isLoadingCommunities {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading communities...")
                        .font(.caption)
                        .foregroundColor(.neuSecondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                let localCommunities = userSettings.communitiesInCity

                if localCommunities.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "building.2.crop.circle")
                            .font(.system(size: 40))
                            .foregroundColor(.neuSecondaryText)
                        Text("No communities in this area yet")
                            .font(.subheadline)
                            .foregroundColor(.neuSecondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(localCommunities) { community in
                                CommunityCardView(community: community)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
    }

    private var communitiesView: some View {
        VStack(spacing: 0) {
            if userSettings.isLoadingCommunities {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                    Text("Loading your communities...")
                        .font(.caption)
                        .foregroundColor(.neuSecondaryText)
                    Spacer()
                }
            } else {
                let joinedCommunities = userSettings.joinedCommunities

                if joinedCommunities.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.neuSecondaryText)
                        Text("No Communities Joined")
                            .font(.headline)
                            .foregroundColor(.neuText)
                        Text("Select a location first, then join\ncommunities in your area")
                            .font(.subheadline)
                            .foregroundColor(.neuSecondaryText)
                            .multilineTextAlignment(.center)

                        Button(action: { selectedTab = 0 }) {
                            Text("Select Location")
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.neuAccentBlue)
                                .cornerRadius(20)
                        }
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(joinedCommunities) { community in
                            CommunityCardView(community: community)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.neuBackground)
                }
            }
        }
        .onAppear {
            Task {
                await userSettings.loadMyCommunities()
            }
        }
    }
}

// MARK: - Location Row View
struct LocationRowView: View {
    let location: UserLocation
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.neuBackground)
                        .frame(width: 40, height: 40)
                        .shadow(color: .neuDarkShadow, radius: 3, x: 2, y: 2)
                        .shadow(color: .neuLightShadow, radius: 3, x: -2, y: -2)

                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.neuAccentBlue)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(location.city)
                        .font(.subheadline.bold())
                        .foregroundColor(.neuText)
                    Text(location.state)
                        .font(.caption)
                        .foregroundColor(.neuSecondaryText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.neuSecondaryText)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Community Card View
struct CommunityCardView: View {
    let community: Community
    var onCreateEvent: (() -> Void)? = nil
    @ObservedObject private var userSettings = UserSettings.shared
    @State private var isLoading = false
    @State private var showDetail = false
    @State private var showApprovalAlert = false
    @State private var showAdminDashboard = false

    var isMember: Bool {
        userSettings.isMember(of: community)
    }

    var isAdmin: Bool {
        userSettings.isAdmin(of: community)
    }

    var body: some View {
        Button(action: { showDetail = true }) {
            VStack(alignment: .leading, spacing: 0) {
                // 1. Header — neumorphic concave instead of gradient
                ZStack(alignment: .topLeading) {
                    Color.neuBackground
                        .frame(height: 120)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.neuBackground, lineWidth: 3)
                                .shadow(color: .neuDarkShadow, radius: 4, x: 3, y: 3)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: .neuLightShadow, radius: 4, x: -3, y: -3)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        )
                        .overlay(
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.neuSecondaryText.opacity(0.3))
                        )

                    // Badges
                    HStack {
                        Spacer()

                        if isMember {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Joined")
                            }
                            .font(.caption.bold())
                            .foregroundColor(.neuAccentGreen)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.neuBackground)
                            .cornerRadius(8)
                            .shadow(color: .neuDarkShadow, radius: 2, x: 1, y: 1)
                            .shadow(color: .neuLightShadow, radius: 2, x: -1, y: -1)
                        }

                        if isAdmin {
                            Text("Admin")
                                .font(.caption.bold())
                                .badgeStyle(background: .orange)
                        }
                    }
                    .padding(12)
                }

                // 2. Content
                VStack(alignment: .leading, spacing: 10) {
                    // Title & Member Count
                    HStack(alignment: .top) {
                        Text(community.name)
                            .font(.title3.bold())
                            .lineLimit(2)
                            .foregroundColor(.neuText)

                        Spacer()

                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                                .font(.caption)
                            Text("\(community.memberCount)")
                                .font(.caption.bold())
                        }
                        .foregroundColor(.neuSecondaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .neumorphicConcave(cornerRadius: 6)
                    }

                    // Location
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundColor(.neuSecondaryText)
                        Text(community.fullLocation)
                            .font(.subheadline)
                            .foregroundColor(.neuSecondaryText)
                    }

                    if !community.description.isEmpty {
                        Text(community.description)
                            .font(.subheadline)
                            .foregroundColor(.neuSecondaryText)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Admin Controls
                    if isAdmin {
                        Color.neuDivider.frame(height: 1)
                            .padding(.vertical, 4)

                        HStack(spacing: 12) {
                            if let onCreateEvent = onCreateEvent {
                                Button(action: onCreateEvent) {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Event")
                                    }
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color.neuAccentGreen)
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }

                            Button(action: { showAdminDashboard = true }) {
                                HStack {
                                    Image(systemName: "gearshape.fill")
                                    Text("Manage")
                                }
                                .font(.subheadline.bold())
                                .foregroundColor(.orange)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
                .background(Color.neuBackground)
            }
            .cornerRadius(16)
            .shadow(color: .neuDarkShadow, radius: 8, x: 5, y: 5)
            .shadow(color: .neuLightShadow, radius: 8, x: -4, y: -4)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            CommunityDetailView(community: community)
        }
        .sheet(isPresented: $showAdminDashboard) {
            CommunityAdminDashboard(community: community)
        }
    }
}

// MARK: - Joined Community Row


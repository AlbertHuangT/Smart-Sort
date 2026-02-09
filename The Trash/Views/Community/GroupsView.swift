//
//  GroupsView.swift
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

struct GroupsView: View {
    @ObservedObject private var userSettings = UserSettings.shared
    @EnvironmentObject var authVM: AuthViewModel
    @State private var showAccountSheet = false
    @State private var selectedSection: CommunityTabSection = .nearby
    @State private var searchText = ""
    @State private var showLocationPicker = false
    @State private var showCreateEventSheet = false
    @State private var showCreateCommunitySheet = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header handled by parent

                if authVM.isAnonymous {
                    anonymousRestrictionView
                } else {
                    controlBar

                    switch selectedSection {
                    case .nearby:
                        nearbyCommunitiesContent
                    case .joined:
                        joinedCommunitiesContent
                    }
                }
            }
            .background(Color.neuBackground)

            if !authVM.isAnonymous {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        FloatingActionButton(icon: "plus") {
                            showCreateCommunitySheet = true
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        .sheet(isPresented: $showLocationPicker) {
            LocationPickerSheet(isPresented: $showLocationPicker)
        }
        .sheet(isPresented: $showCreateEventSheet) {
            CreateEventSheet(isPresented: $showCreateEventSheet)
        }
        .sheet(isPresented: $showCreateCommunitySheet) {
            CreateCommunitySheet(isPresented: $showCreateCommunitySheet)
        }
        .task {
            // Eagerly load joined communities to ensure Admin status is known for Nearby list
            if userSettings.joinedCommunities.isEmpty {
                await userSettings.loadMyCommunities()
            }
        }
    }

    // MARK: - Control Bar (Location + Toggle)
    private var controlBar: some View {
        HStack {
            // Location Button
            if let location = userSettings.selectedLocation {
                Button(action: { showLocationPicker = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .font(.caption)
                        Text(location.city)
                            .font(.subheadline.bold())
                    }
                    .foregroundColor(.neuAccentBlue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .neumorphicConcave(cornerRadius: 16)
                }
            } else {
                Button(action: { showLocationPicker = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "location.slash")
                            .font(.caption)
                        Text("Select Location")
                            .font(.subheadline.bold())
                    }
                    .foregroundColor(.neuSecondaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .neumorphic(cornerRadius: 16)
                    .cornerRadius(16)
                }
            }

            Spacer()

            // Toggle Button (Nearby / Joined)
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if selectedSection == .nearby {
                        selectedSection = .joined
                    } else {
                        selectedSection = .nearby
                    }
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: selectedSection == .joined ? "person.3.fill" : "globe")
                        .font(.caption)
                        .frame(width: 14) // Fixed width for icon stability
                    Text(selectedSection == .joined ? "Joined" : "Nearby")
                        .font(.caption.bold())
                        .frame(width: 50, alignment: .center) // Fixed width for text stability
                }
                .foregroundColor(selectedSection == .joined ? .white : .neuSecondaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(selectedSection == .joined ? Color.neuAccentBlue : Color.neuBackground)
                        .shadow(color: .neuDarkShadow, radius: 3, x: 2, y: 2)
                        .shadow(color: .neuLightShadow, radius: 3, x: -2, y: -2)
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Nearby Communities Content
    @ViewBuilder
    private var nearbyCommunitiesContent: some View {
        VStack(spacing: 0) {
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
            if let location = userSettings.selectedLocation, userSettings.communitiesInCity.isEmpty {
                await userSettings.loadCommunitiesForCity(location.city)
            }
        }
    }

    private var noLocationView: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.neuBackground)
                    .frame(width: 120, height: 120)
                    .shadow(color: .neuDarkShadow, radius: 8, x: 6, y: 6)
                    .shadow(color: .neuLightShadow, radius: 8, x: -4, y: -4)
                Image(systemName: "location.slash.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.neuAccentBlue)
            }

            Text("No Location Set")
                .font(.title2).bold()
                .foregroundColor(.neuText)
            Text("Select a location to discover\ncommunities near you")
                .multilineTextAlignment(.center)
                .foregroundColor(.neuSecondaryText)

            Button(action: { showLocationPicker = true }) {
                Text("Select Location")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(colors: [.neuAccentBlue, .cyan], startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(20)
                    .shadow(color: .neuAccentBlue.opacity(0.4), radius: 8, y: 4)
            }
            Spacer()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
                .tint(.neuAccentBlue)
            Text("Loading communities...")
                .font(.subheadline)
                .foregroundColor(.neuSecondaryText)
            Spacer()
        }
    }

    private var emptyNearbyView: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.neuBackground)
                    .frame(width: 100, height: 100)
                    .shadow(color: .neuDarkShadow, radius: 6, x: 4, y: 4)
                    .shadow(color: .neuLightShadow, radius: 6, x: -3, y: -3)
                Image(systemName: "building.2.crop.circle")
                    .font(.system(size: 40))
                    .foregroundColor(.neuSecondaryText)
            }

            Text("No Communities Yet")
                .font(.title2).bold()
                .foregroundColor(.neuText)
            Text("No communities in this area yet.\nBe the first to start one!")
                .multilineTextAlignment(.center)
                .foregroundColor(.neuSecondaryText)
            Spacer()
        }
    }

    private var nearbyCommunitiesList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(userSettings.communitiesInCity) { community in
                    CommunityCardView(
                        community: community,
                        onCreateEvent: {
                            showCreateEventSheet = true
                        }
                    )
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
            if userSettings.joinedCommunities.isEmpty {
                await userSettings.loadMyCommunities()
            }
        }
    }

    private var emptyJoinedView: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.neuBackground)
                    .frame(width: 100, height: 100)
                    .shadow(color: .neuDarkShadow, radius: 6, x: 4, y: 4)
                    .shadow(color: .neuLightShadow, radius: 6, x: -3, y: -3)
                Image(systemName: "person.3.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.neuSecondaryText)
            }

            Text("No Communities Joined")
                .font(.title2).bold()
                .foregroundColor(.neuText)
            Text("Join communities to connect with\npeople in your area")
                .multilineTextAlignment(.center)
                .foregroundColor(.neuSecondaryText)

            Button(action: { selectedSection = .nearby }) {
                Text("Browse Nearby")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(colors: [.neuAccentBlue, .cyan], startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(20)
                    .shadow(color: .neuAccentBlue.opacity(0.4), radius: 8, y: 4)
            }
            Spacer()
        }
    }

    private var joinedCommunitiesList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(userSettings.joinedCommunities) { community in
                    CommunityCardView(
                        community: community,
                        onCreateEvent: {
                            showCreateEventSheet = true
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .refreshable {
            await userSettings.loadMyCommunities()
        }
    }

    // MARK: - Anonymous Restriction View
    private var anonymousRestrictionView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.neuBackground)
                    .frame(width: 120, height: 120)
                    .shadow(color: .neuDarkShadow, radius: 10, x: 8, y: 8)
                    .shadow(color: .neuLightShadow, radius: 10, x: -6, y: -6)

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(colors: [.neuAccentBlue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            }
            .padding(.bottom, 10)

            Text("Access Restricted")
                .font(.title).bold()
                .foregroundColor(.neuText)

            Text("Communities are only available for registered users.\n\nPlease link your Email or Phone in your Account to access this feature.")
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .foregroundColor(.neuSecondaryText)

            Spacer()
        }
    }
}

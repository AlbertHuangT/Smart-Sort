//
//  ManageAchievementsView.swift
//  The Trash
//
//  Created by Albert Huang on 2/8/26.
//

import SwiftUI
import Combine

struct ManageAchievementsView: View {
    let communityId: String
    @StateObject private var service = AchievementService.shared
    @State private var showingCreateSheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            if service.isLoading && service.communityAchievements.isEmpty {
                Spacer()
                ProgressView()
                Spacer()
            } else if service.communityAchievements.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "trophy")
                        .font(.system(size: 50))
                        .foregroundColor(.neuSecondaryText)
                    Text("No achievements created yet")
                        .font(.headline)
                        .foregroundColor(.neuText)
                    Text("Create achievements to reward\nyour community members")
                        .font(.subheadline)
                        .foregroundColor(.neuSecondaryText)
                        .multilineTextAlignment(.center)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(service.communityAchievements) { achievement in
                            NavigationLink(destination: GrantAchievementToMemberView(
                                achievement: achievement,
                                communityId: communityId
                            )) {
                                achievementCard(achievement)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
        .background(Color.neuBackground)
        .navigationTitle("Manage Achievements")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingCreateSheet = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateAchievementView(communityId: communityId, isPresented: $showingCreateSheet)
        }
        .onAppear {
            Task {
                await service.fetchCommunityAchievements(communityId: communityId)
            }
        }
    }

    // MARK: - Achievement Card

    private func achievementCard(_ achievement: Achievement) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: achievement.rarity.gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)

                Image(systemName: achievement.iconName)
                    .font(.title3)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(achievement.name)
                    .font(.headline)
                    .foregroundColor(.neuText)
                if let desc = achievement.description {
                    Text(desc)
                        .font(.caption)
                        .foregroundColor(.neuSecondaryText)
                }
                Text(achievement.rarity.displayName)
                    .font(.caption2.bold())
                    .foregroundColor(achievement.rarity.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(achievement.rarity.color.opacity(0.15))
                    .cornerRadius(4)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.neuSecondaryText)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.neuBackground)
                .shadow(color: .neuDarkShadow, radius: 5, x: 3, y: 3)
                .shadow(color: .neuLightShadow, radius: 5, x: -3, y: -3)
        )
    }
}

private struct CreateAchievementView: View {
    let communityId: String
    @Binding var isPresented: Bool
    @StateObject private var service = AchievementService.shared
    
    @State private var name = ""
    @State private var description = ""
    @State private var selectedIcon = "star.fill"
    @State private var selectedRarity: AchievementRarity = .common
    
    let icons = ["star.fill", "trophy.fill", "medal.fill", "rosette", "flame.fill", "bolt.fill", "leaf.fill", "drop.fill", "globe", "heart.fill", "sparkles", "crown.fill", "flag.fill", "hand.thumbsup.fill"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Details")) {
                    TextField("Achievement Name", text: $name)
                    TextField("Description", text: $description)
                }
                
                Section(header: Text("Rarity")) {
                    Picker("Rarity", selection: $selectedRarity) {
                        ForEach(AchievementRarity.allCases, id: \.self) { rarity in
                            HStack {
                                Circle()
                                    .fill(rarity.color)
                                    .frame(width: 10, height: 10)
                                Text(rarity.displayName)
                            }
                            .tag(rarity)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section(header: Text("Icon")) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 40))], spacing: 10) {
                        ForEach(icons, id: \.self) { icon in
                            Image(systemName: icon)
                                .font(.title2)
                                .padding(8)
                                .background(selectedIcon == icon ? selectedRarity.color.opacity(0.2) : Color.clear)
                                .cornerRadius(8)
                                .foregroundColor(selectedIcon == icon ? selectedRarity.color : .primary)
                                .onTapGesture {
                                    selectedIcon = icon
                                }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("New Achievement")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            let success = await service.createAchievement(
                                communityId: communityId,
                                name: name,
                                description: description,
                                iconName: selectedIcon,
                                rarity: selectedRarity
                            )
                            if success {
                                isPresented = false
                            }
                        }
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

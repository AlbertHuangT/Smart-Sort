//
//  BadgePickerView.swift
//  Smart Sort
//

import SwiftUI

struct BadgePickerView: View {
    var showsNavigationTitle: Bool = true
    @StateObject private var service = AchievementService.shared
    private let theme = TrashTheme()

    private var equippedBadge: UserAchievement? {
        service.myAchievements.first(where: { $0.isEquipped })
    }

    var body: some View {
        VStack(spacing: 0) {
            if service.isLoading {
                Spacer()
                ProgressView("Loading badges...")
                Spacer()
            } else if service.myAchievements.isEmpty {
                CompatibleContentUnavailableView {
                    Label("No Badges Yet", systemImage: "shield")
                } description: {
                    Text("Earn achievements to unlock badges!")
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let equipped = equippedBadge {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Currently Equipped")
                                    .font(.headline)
                                    .foregroundColor(theme.palette.textPrimary)

                                AchievementCard(achievement: equipped) {
                                    Task { await service.unequipAchievement() }
                                }
                            }
                        }

                        Text("All Badges")
                            .font(.headline)
                            .foregroundColor(theme.palette.textPrimary)

                        LazyVStack(spacing: 12) {
                            ForEach(service.myAchievements) { achievement in
                                AchievementCard(achievement: achievement) {
                                    Task {
                                        if achievement.isEquipped {
                                            await service.unequipAchievement()
                                        } else {
                                            await service.equipAchievement(achievementId: achievement.achievementId)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
        }
        .background(theme.palette.background.ignoresSafeArea())
        .optionalNavigationTitle(showsNavigationTitle ? "Badges" : nil)
        .onAppear {
            Task {
                await service.fetchMyAchievements()
            }
        }
    }
}

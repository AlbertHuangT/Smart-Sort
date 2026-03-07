//
//  AchievementsListView.swift
//  Smart Sort
//
//  Created by Albert Huang on 2/8/26.
//

import SwiftUI

struct AchievementsListView: View {
    var showsNavigationTitle: Bool = true
    @StateObject private var service = AchievementService.shared
    @State private var selectedTab = 0 // 0: Official, 1: Community
    private let theme = TrashTheme()

    var body: some View {
        VStack(spacing: theme.spacing.md) {
            TrashSegmentedControl(
                options: [
                    TrashSegmentOption(value: 0, title: "Official", icon: "shield.fill"),
                    TrashSegmentOption(value: 1, title: "Community", icon: "person.3.fill")
                ],
                selection: $selectedTab
            )
            .padding(.horizontal, theme.components.contentInset)
            .padding(.top, theme.spacing.sm + 4)

            if service.isLoading {
                Spacer(minLength: 0)
                ProgressView()
                Spacer(minLength: 0)
            } else if filteredAchievements.isEmpty {
                emptyStateView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: theme.spacing.md) {
                        Text(selectedTab == 0 ? "Official Achievements" : "Community Achievements")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(theme.palette.textSecondary)
                            .textCase(.uppercase)
                            .tracking(0.6)

                        ForEach(filteredAchievements) { achievement in
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
                    .padding(.horizontal, theme.components.contentInset)
                    .padding(.top, theme.spacing.sm + 4)
                    .padding(.bottom, theme.spacing.lg)
                }
            }
        }
        .optionalNavigationTitle(showsNavigationTitle ? "Achievements" : nil)
        .onAppear {
            Task {
                await service.fetchMyAchievements()
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        EmptyStateView(
            icon: selectedTab == 0 ? "trophy.fill" : "person.3.fill",
            title: "No Achievements Yet",
            subtitle: selectedTab == 0
                ? "Start scanning trash to earn your first achievement."
                : "Join communities and participate to earn community achievements."
        )
    }

    var filteredAchievements: [UserAchievement] {
        if selectedTab == 0 {
            return service.myAchievements.filter { $0.isOfficial }
        } else {
            return service.myAchievements.filter { !$0.isOfficial }
        }
    }
}

// MARK: - Achievement Card (Neumorphic)

struct AchievementCard: View {
    let achievement: UserAchievement
    let onToggleEquip: () -> Void
    private let theme = TrashTheme()

    var body: some View {
        HStack(spacing: theme.spacing.sm + 6) {
            // 成就图标
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: achievement.rarity.gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .shadow(color: achievement.rarity.color.opacity(0.3), radius: 6, x: 0, y: 3)

                TrashIcon(systemName: achievement.iconName)
                    .font(.system(size: 22, weight: .semibold))
                    .trashOnAccentForeground()
            }

            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                HStack(spacing: 6) {
                    Text(achievement.name)
                        .font(theme.typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.palette.textPrimary)

                    // 稀有度标签
                    Text(achievement.rarity.displayName)
                        .font(theme.typography.caption)
                        .foregroundColor(achievement.rarity.color)
                        .padding(.horizontal, 8)
                        .frame(minHeight: 24)
                        .background(
                            Capsule(style: .continuous)
                                .fill(achievement.rarity.color.opacity(0.15))
                        )
                }

                if let desc = achievement.description {
                    Text(desc)
                        .font(.caption)
                        .foregroundColor(theme.palette.textSecondary)
                        .lineLimit(2)
                }

                HStack(spacing: theme.spacing.sm) {
                    if let communityName = achievement.communityName {
                        HStack(spacing: 3) {
                            TrashIcon(systemName: "person.3.fill")
                                .font(.system(size: 10, weight: .semibold))
                            Text(communityName)
                                .font(theme.typography.caption)
                        }
                        .foregroundColor(theme.accents.blue)
                    }

                    HStack(spacing: 3) {
                        TrashIcon(systemName: "calendar")
                            .font(.system(size: 10, weight: .semibold))
                        Text(achievement.grantedAt, style: .date)
                            .font(theme.typography.caption)
                    }
                    .foregroundColor(theme.palette.textSecondary)
                }
            }

            Spacer()

            // 装备/取消装备按钮
            TrashTapArea(action: onToggleEquip) {
                if achievement.isEquipped {
                    HStack(spacing: 3) {
                        TrashIcon(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                        Text("Equipped")
                            .font(theme.typography.caption.weight(.bold))
                    }
                    .trashOnAccentForeground()
                    .padding(.horizontal, 12)
                    .frame(minHeight: theme.components.minimumHitTarget)
                    .background(
                        LinearGradient(
                            colors: achievement.rarity.gradient,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: theme.corners.small, style: .continuous))
                } else {
                    Text("Equip")
                        .font(theme.typography.caption.weight(.bold))
                        .foregroundColor(theme.accents.blue)
                        .padding(.horizontal, 12)
                        .frame(minHeight: theme.components.minimumHitTarget)
                        .background(
                            RoundedRectangle(cornerRadius: theme.corners.small, style: .continuous)
                                .fill(theme.surfaceBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: theme.corners.small, style: .continuous)
                                        .stroke(theme.palette.divider.opacity(0.8), lineWidth: 1)
                                )
                        )
                }
            }
        }
        .padding(theme.components.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                .fill(theme.surfaceBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                        .stroke(theme.palette.divider.opacity(0.8), lineWidth: 1)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                .stroke(
                    achievement.isEquipped
                    ? LinearGradient(colors: achievement.rarity.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing),
                    lineWidth: achievement.isEquipped ? 1.5 : 0
                )
        )
    }
}

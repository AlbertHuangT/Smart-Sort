//
//  CurrentUserViewModel.swift
//  Smart Sort
//
//  Extracted from LeaderboardView.swift
//

import SwiftUI
import Supabase
import Combine

@MainActor
class CurrentUserViewModel: ObservableObject {
    @Published var myProfile: UserProfileDTO?
    @Published var equippedAchievementIcon: String?

    private var lastFetchTime: Date?
    private let cacheValidDuration: TimeInterval = 30
    private let profileService = ProfileService.shared

    func fetchMyScore(forceRefresh: Bool = false) async {
        if !forceRefresh,
           myProfile != nil,
           let lastTime = lastFetchTime,
           Date().timeIntervalSince(lastTime) < cacheValidDuration {
            return
        }

        guard SupabaseManager.shared.client.auth.currentUser?.id != nil else { return }

        do {
            let profile = try await profileService.fetchMyProfile()

            self.myProfile = profile
            self.lastFetchTime = Date()

            if let achievementId = profile.selectedAchievementId {
                await fetchEquippedAchievementIcon(achievementId)
            } else {
                self.equippedAchievementIcon = nil
            }
        } catch {
            if !Task.isCancelled {
                print("❌ Failed to fetch my score: \(error)")
            }
        }
    }

    private func fetchEquippedAchievementIcon(_ achievementId: UUID) async {
        do {
            let info = try await profileService.fetchEquippedAchievement(achievementId: achievementId)
            self.equippedAchievementIcon = info.iconName
        } catch {
            self.equippedAchievementIcon = nil
        }
    }
}

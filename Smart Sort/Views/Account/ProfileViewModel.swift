//
//  ProfileViewModel.swift
//  Smart Sort
//
//  Extracted from AccountView.swift
//

import SwiftUI
import Combine
import Supabase

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var credits: Int = 0
    @Published var username: String = ""
    @Published var levelName: String = "Novice Recycler"
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isAppAdmin = false
    
    // Equipped achievement display
    @Published var equippedAchievementIcon: String?
    @Published var equippedAchievementName: String?
    @Published var equippedAchievementRarity: AchievementRarity?

    private var lastFetchTime: Date?
    private let cacheValidDuration: TimeInterval = 30
    private var hasFetchedOnce = false

    private let client = SupabaseManager.shared.client
    private let adminService = AdminService.shared

    func fetchProfile(forceRefresh: Bool = false) async {
        guard client.auth.currentUser?.id != nil else { return }

        if !forceRefresh && hasFetchedOnce,
           let lastTime = lastFetchTime,
           Date().timeIntervalSince(lastTime) < cacheValidDuration {
            return
        }

        if !hasFetchedOnce {
            isLoading = true
        }
        errorMessage = nil
        do {
            let profile: UserProfileDTO = try await client
                .rpc("get_my_profile")
                .single()
                .execute()
                .value

            self.credits = profile.credits ?? 0
            self.username = profile.username ?? ""
            self.lastFetchTime = Date()
            self.hasFetchedOnce = true
            calculateLevel()
            await fetchAdminStatus()
            
            // Load the equipped achievement metadata
            if let achievementId = profile.selectedAchievementId {
                await fetchEquippedAchievement(achievementId)
            } else {
                self.equippedAchievementIcon = nil
                self.equippedAchievementName = nil
                self.equippedAchievementRarity = nil
            }
        } catch {
            print("❌ Fetch profile error: \(error)")
            if !Task.isCancelled {
                self.errorMessage = "Failed to load profile"
            }
        }
        isLoading = false
    }

    private func fetchAdminStatus() async {
        do {
            isAppAdmin = try await adminService.isAppAdmin()
        } catch {
            isAppAdmin = false
        }
    }
    
    private func fetchEquippedAchievement(_ achievementId: UUID) async {
        do {
            struct AchievementInfo: Decodable {
                let iconName: String
                let name: String
                let rarity: AchievementRarity?
                
                enum CodingKeys: String, CodingKey {
                    case iconName = "icon_name"
                    case name, rarity
                }
            }
            
            let info: AchievementInfo = try await client
                .from("achievements")
                .select("icon_name, name, rarity")
                .eq("id", value: achievementId)
                .single()
                .execute()
                .value
            
            self.equippedAchievementIcon = info.iconName
            self.equippedAchievementName = info.name
            self.equippedAchievementRarity = info.rarity
        } catch {
            print("❌ Fetch equipped achievement error: \(error)")
            self.equippedAchievementIcon = nil
            self.equippedAchievementName = nil
            self.equippedAchievementRarity = nil
        }
    }

    func updateUsername(_ newName: String) async {
        guard client.auth.currentUser?.id != nil else { return }
        guard !newName.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let previousName = self.username
        self.username = newName
        errorMessage = nil

        do {
            try await client
                .rpc("update_my_username", params: ["p_username": newName])
                .execute()

            print("✅ Username updated to: \(newName)")
        } catch {
            print("❌ Update username error: \(error)")
            self.username = previousName
            self.errorMessage = "Failed to update username"
        }
    }

    private func calculateLevel() {
        switch credits {
        case 0..<100: levelName = "Novice Recycler 🌱"
        case 100..<500: levelName = "Green Guardian 🌿"
        case 500..<2000: levelName = "Eco Warrior ⚔️"
        default: levelName = "Planet Savior 🌍"
        }
    }
}

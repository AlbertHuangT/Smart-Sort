//
//  ProfileViewModel.swift
//  The Trash
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

    private var lastFetchTime: Date?
    private let cacheValidDuration: TimeInterval = 30
    private var hasFetchedOnce = false

    private let client = SupabaseManager.shared.client

    func fetchProfile(forceRefresh: Bool = false) async {
        guard let userId = client.auth.currentUser?.id else { return }

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
            struct UserProfile: Decodable {
                let credits: Int?
                let username: String?
            }

            let profile: UserProfile = try await client
                .from("profiles")
                .select("credits, username")
                .eq("id", value: userId)
                .single()
                .execute()
                .value

            self.credits = profile.credits ?? 0
            self.username = profile.username ?? ""
            self.lastFetchTime = Date()
            self.hasFetchedOnce = true
            calculateLevel()
        } catch {
            print("❌ Fetch profile error: \(error)")
            if !Task.isCancelled {
                self.errorMessage = "Failed to load profile"
            }
        }
        isLoading = false
    }

    func updateUsername(_ newName: String) async {
        guard let userId = client.auth.currentUser?.id else { return }
        guard !newName.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let previousName = self.username
        self.username = newName
        errorMessage = nil

        do {
            struct UpdateName: Encodable {
                let username: String
            }

            try await client
                .from("profiles")
                .update(UpdateName(username: newName))
                .eq("id", value: userId)
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

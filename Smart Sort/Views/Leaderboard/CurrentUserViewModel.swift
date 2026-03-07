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

    private var lastFetchTime: Date?
    private let cacheValidDuration: TimeInterval = 30

    func fetchMyScore(forceRefresh: Bool = false) async {
        if !forceRefresh,
           myProfile != nil,
           let lastTime = lastFetchTime,
           Date().timeIntervalSince(lastTime) < cacheValidDuration {
            return
        }

        guard SupabaseManager.shared.client.auth.currentUser?.id != nil else { return }

        do {
            let profile: UserProfileDTO = try await SupabaseManager.shared.client
                .rpc("get_my_profile")
                .single()
                .execute()
                .value

            self.myProfile = profile
            self.lastFetchTime = Date()
        } catch {
            if !Task.isCancelled {
                print("❌ Failed to fetch my score: \(error)")
            }
        }
    }
}

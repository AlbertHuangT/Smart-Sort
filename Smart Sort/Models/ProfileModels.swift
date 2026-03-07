//
//  ProfileModels.swift
//  Smart Sort
//
//  Shared profile DTOs used by ProfileViewModel and CurrentUserViewModel.
//

import Foundation

/// Lightweight DTO for reading a user's public profile from the `profiles` table.
struct UserProfileDTO: Decodable {
    let username: String?
    let credits: Int?
    let selectedAchievementId: UUID?

    enum CodingKeys: String, CodingKey {
        case username, credits
        case selectedAchievementId = "selected_achievement_id"
    }
}

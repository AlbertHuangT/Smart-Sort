//
//  ProfileService.swift
//  Smart Sort
//

import Foundation
import Supabase

struct EquippedAchievementInfo: Decodable {
    let iconName: String
    let name: String?
    let rarity: AchievementRarity?

    enum CodingKeys: String, CodingKey {
        case iconName = "icon_name"
        case name, rarity
    }
}

@MainActor
final class ProfileService {
    static let shared = ProfileService()

    private let client = SupabaseManager.shared.client
    private let adminService = AdminService.shared

    private init() {}

    func fetchMyProfile() async throws -> UserProfileDTO {
        try await client
            .rpc("get_my_profile")
            .single()
            .execute()
            .value
    }

    func fetchMyCredits() async throws -> Int {
        let profile = try await fetchMyProfile()
        return profile.credits ?? 0
    }

    func fetchEquippedAchievement(achievementId: UUID) async throws -> EquippedAchievementInfo {
        try await client
            .from("achievements")
            .select("icon_name, name, rarity")
            .eq("id", value: achievementId)
            .single()
            .execute()
            .value
    }

    func fetchScanActivity(days: Int = 90) async throws -> [Date] {
        struct ScanActivityRow: Decodable {
            let scanDate: String
            let scanCount: Int

            enum CodingKeys: String, CodingKey {
                case scanDate = "scan_date"
                case scanCount = "scan_count"
            }
        }

        let rows: [ScanActivityRow] = try await client
            .rpc("get_user_scan_activity", params: ["p_days": days])
            .execute()
            .value

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")

        var dates: [Date] = []
        for row in rows {
            guard let date = formatter.date(from: row.scanDate) else { continue }
            for _ in 0..<row.scanCount {
                dates.append(date)
            }
        }
        return dates
    }

    func updateMyUsername(_ username: String) async throws {
        try await client
            .rpc("update_my_username", params: ["p_username": username])
            .execute()
    }

    func isCurrentUserAppAdmin() async -> Bool {
        do {
            return try await adminService.isAppAdmin()
        } catch {
            return false
        }
    }
}

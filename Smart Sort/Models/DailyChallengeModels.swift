//
//  DailyChallengeModels.swift
//  Smart Sort
//

import Foundation

// MARK: - Daily Challenge Response

struct DailyChallengeResponse: Codable {
    let challengeId: UUID
    let challengeDate: String
    let alreadyPlayed: Bool
    let sessionId: UUID?
    let questions: [QuizQuestion]

    enum CodingKeys: String, CodingKey {
        case challengeId = "challenge_id"
        case challengeDate = "challenge_date"
        case alreadyPlayed = "already_played"
        case sessionId = "session_id"
        case questions
    }
}

// MARK: - Daily Challenge Submit Response

struct DailyChallengeSubmitResponse: Codable {
    let resultId: UUID
    let pointsAwarded: Int
    let score: Int?
    let correctCount: Int?
    let maxCombo: Int?

    enum CodingKeys: String, CodingKey {
        case resultId = "result_id"
        case pointsAwarded = "points_awarded"
        case score
        case correctCount = "correct_count"
        case maxCombo = "max_combo"
    }
}

// MARK: - Daily Challenge Submit Params

struct DailyChallengeSubmitParams: Sendable {
    let p_session_id: UUID
    let p_time_seconds: Double
}

extension DailyChallengeSubmitParams: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(p_session_id, forKey: .p_session_id)
        try container.encode(p_time_seconds, forKey: .p_time_seconds)
    }

    private enum CodingKeys: String, CodingKey {
        case p_session_id, p_time_seconds
    }
}

// MARK: - Daily Leaderboard Entry

struct DailyLeaderboardEntry: Codable, Identifiable {
    let rank: Int
    let userId: UUID
    let displayName: String
    let score: Int
    let correctCount: Int
    let timeSeconds: Double
    let maxCombo: Int

    var id: UUID { userId }

    enum CodingKeys: String, CodingKey {
        case rank
        case userId = "user_id"
        case displayName = "display_name"
        case score
        case correctCount = "correct_count"
        case timeSeconds = "time_seconds"
        case maxCombo = "max_combo"
    }
}

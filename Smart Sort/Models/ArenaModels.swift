//
//  ArenaModels.swift
//  Smart Sort
//

import Foundation

// MARK: - Quiz Question

struct QuizQuestion: Identifiable, Codable {
    let id: UUID
    let imageUrl: String
    let correctCategory: String?
    let itemName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case imageUrl = "image_url"
        case correctCategory = "correct_category"
        case itemName = "item_name"
    }
}

struct SoloQuizSessionResponse: Codable {
    let sessionId: UUID
    let questions: [QuizQuestion]

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case questions
    }
}

struct QuizQuestionsForModeParams: Sendable {
    let p_mode: String
    let p_limit: Int
}

struct QuizQuestionBatchParams: Sendable {
    let p_limit: Int
    let p_session_id: String?
}

struct SoloAnswerResponse: Codable {
    let isCorrect: Bool
    let correctCategory: String
    let questionIndex: Int

    enum CodingKeys: String, CodingKey {
        case isCorrect = "is_correct"
        case correctCategory = "correct_category"
        case questionIndex = "question_index"
    }
}

struct SubmitSoloAnswerParams: Sendable {
    let p_session_id: String
    let p_question_index: Int
    let p_selected_category: String
    let p_answer_time_ms: Int
}

extension QuizQuestionsForModeParams: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(p_mode, forKey: .p_mode)
        try container.encode(p_limit, forKey: .p_limit)
    }

    private enum CodingKeys: String, CodingKey {
        case p_mode, p_limit
    }
}

extension QuizQuestionBatchParams: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(p_limit, forKey: .p_limit)
        try container.encodeIfPresent(p_session_id, forKey: .p_session_id)
    }

    private enum CodingKeys: String, CodingKey {
        case p_limit, p_session_id
    }
}

extension SubmitSoloAnswerParams: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(p_session_id, forKey: .p_session_id)
        try container.encode(p_question_index, forKey: .p_question_index)
        try container.encode(p_selected_category, forKey: .p_selected_category)
        try container.encode(p_answer_time_ms, forKey: .p_answer_time_ms)
    }

    private enum CodingKeys: String, CodingKey {
        case p_session_id, p_question_index, p_selected_category, p_answer_time_ms
    }
}

struct SoloSessionCompletionResponse: Codable {
    let sessionId: UUID?
    let score: Int?
    let correctCount: Int?
    let maxCombo: Int?
    let pointsAwarded: Int?

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case score
        case correctCount = "correct_count"
        case maxCombo = "max_combo"
        case pointsAwarded = "points_awarded"
    }
}

struct StreakSessionCompletionResponse: Codable {
    let sessionId: UUID?
    let streakCount: Int
    let pointsAwarded: Int

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case streakCount = "streak_count"
        case pointsAwarded = "points_awarded"
    }
}

// MARK: - Game Modes

enum ArenaGameMode: String, Hashable, CaseIterable, Identifiable {
    case classic
    case speedSort
    case streak
    case dailyChallenge
    case duel

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: return "Classic Quiz"
        case .speedSort: return "Speed Sort"
        case .streak: return "Streak Mode"
        case .dailyChallenge: return "Daily Challenge"
        case .duel: return "1v1 Duel"
        }
    }

    var subtitle: String {
        switch self {
        case .classic: return "10 questions, test your knowledge"
        case .speedSort: return "Race against the clock!"
        case .streak: return "How far can you go?"
        case .dailyChallenge: return "Same questions for everyone"
        case .duel: return "Challenge your friends"
        }
    }

    var icon: String {
        switch self {
        case .classic: return "flame.fill"
        case .speedSort: return "bolt.fill"
        case .streak: return "arrow.up.right"
        case .dailyChallenge: return "calendar.circle.fill"
        case .duel: return "person.2.fill"
        }
    }

    var gradientColors: [String] {
        switch self {
        case .classic: return ["neuAccentBlue", "cyan"]
        case .speedSort: return ["orange", "yellow"]
        case .streak: return ["purple", "pink"]
        case .dailyChallenge: return ["green", "mint"]
        case .duel: return ["red", "orange"]
        }
    }
}

// MARK: - Streak Models

struct StreakRecord: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let streakCount: Int
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case streakCount = "streak_count"
        case createdAt = "created_at"
    }
}

struct StreakLeaderboardEntry: Codable, Identifiable {
    let userId: UUID
    let displayName: String
    let bestStreak: Int
    let totalGames: Int

    var id: UUID { userId }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case displayName = "display_name"
        case bestStreak = "best_streak"
        case totalGames = "total_games"
    }
}

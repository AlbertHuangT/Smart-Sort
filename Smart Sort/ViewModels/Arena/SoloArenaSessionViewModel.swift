//
//  SoloArenaSessionViewModel.swift
//  Smart Sort
//

import Combine
import Supabase
import SwiftUI

enum SoloArenaSessionError: LocalizedError {
    case missingSession(String)

    var errorDescription: String? {
        switch self {
        case .missingSession(let context):
            return "\(context) session missing"
        }
    }
}

@MainActor
class SoloArenaSessionViewModel: ObservableObject, ArenaImageManaging {
    @Published var questions: [QuizQuestion] = []
    @Published var isLoading = false
    @Published var imageState = ArenaImageState()

    @Published var currentQuestionIndex = 0
    @Published var sessionScore = 0
    @Published var correctCount = 0
    @Published var sessionCompleted = false
    @Published var isSubmitting = false
    @Published var showError = false
    @Published var errorMessage: String?
    @Published var lastCorrectCategory: String?

    let client = SupabaseManager.shared.client
    let imageLogPrefix: String
    var sessionId: UUID?

    init(imageLogPrefix: String) {
        self.imageLogPrefix = imageLogPrefix
    }

    var imageCache: [UUID: UIImage] {
        imageState.cachedImages
    }

    var failedImageIDs: Set<UUID> {
        imageState.failedImageIDs
    }

    var currentQuestion: QuizQuestion? {
        guard currentQuestionIndex < questions.count else { return nil }
        return questions[currentQuestionIndex]
    }

    var progressText: String {
        guard questions.count > 0 else { return "" }
        return "\(min(currentQuestionIndex + 1, questions.count))/\(questions.count)"
    }

    func beginLoadingSession() {
        isLoading = true
        errorMessage = nil
        showError = false
        resetSessionState()
    }

    func finishLoadingSession() {
        isLoading = false
    }

    func presentError(_ message: String) {
        errorMessage = message
        showError = true
    }

    func applySessionResponse(
        _ response: SoloQuizSessionResponse,
        currentIndex: Int = 0,
        prefetchCount: Int = 3
    ) async {
        sessionId = response.sessionId
        questions = response.questions
        _ = await primeArenaImages(
            for: response.questions,
            currentIndex: currentIndex,
            prefetchCount: prefetchCount
        )
    }

    func submitAnswerRequest(
        selectedCategory: String,
        answerTimeMs: Int = 0,
        missingSessionContext: String
    ) async throws -> SoloAnswerResponse {
        guard let sessionId else {
            throw SoloArenaSessionError.missingSession(missingSessionContext)
        }

        let params = SubmitSoloAnswerParams(
            p_session_id: sessionId.uuidString,
            p_question_index: currentQuestionIndex,
            p_selected_category: selectedCategory,
            p_answer_time_ms: answerTimeMs
        )

        return try await client
            .rpc("submit_solo_answer", params: params)
            .execute()
            .value
    }

    func completeFiniteSession(rpcName: String, missingSessionContext: String)
        async throws -> SoloSessionCompletionResponse
    {
        guard let sessionId else {
            throw SoloArenaSessionError.missingSession(missingSessionContext)
        }

        return try await client
            .rpc(rpcName, params: ["p_session_id": sessionId.uuidString])
            .execute()
            .value
    }

    func completeClassicSession() async throws -> SoloSessionCompletionResponse {
        guard let sessionId else {
            throw SoloArenaSessionError.missingSession("Classic Arena")
        }

        return try await client
            .rpc("complete_classic_session", params: ["p_session_id": sessionId.uuidString])
            .execute()
            .value
    }

    func completeSpeedSortSession() async throws -> SoloSessionCompletionResponse {
        guard let sessionId else {
            throw SoloArenaSessionError.missingSession("Speed Sort")
        }

        return try await client
            .rpc("complete_speed_sort_session", params: ["p_session_id": sessionId.uuidString])
            .execute()
            .value
    }

    func advanceToNextQuestion(prefetchCount: Int = 3) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentQuestionIndex += 1
        }
        scheduleUpcomingArenaImages(
            for: questions,
            startingAt: currentQuestionIndex,
            prefetchCount: prefetchCount
        )
    }

    func resetSessionState() {
        cancelArenaImageLoads()
        currentQuestionIndex = 0
        sessionScore = 0
        correctCount = 0
        sessionCompleted = false
        sessionId = nil
        lastCorrectCategory = nil
        imageState.reset()
        questions.removeAll()
        resetModeState()
    }

    func resetModeState() {}
}

@MainActor
class FeedbackSoloArenaSessionViewModel: SoloArenaSessionViewModel {
    @Published var showCorrectFeedback = false
    @Published var showWrongFeedback = false

    func playFeedback(
        isCorrect: Bool,
        correctDelay: UInt64 = 800_000_000,
        wrongDelay: UInt64 = 800_000_000
    ) async {
        withAnimation(.easeInOut(duration: 0.3)) {
            showCorrectFeedback = isCorrect
            showWrongFeedback = !isCorrect
        }

        try? await Task.sleep(nanoseconds: isCorrect ? correctDelay : wrongDelay)

        withAnimation(.easeOut(duration: 0.2)) {
            showCorrectFeedback = false
            showWrongFeedback = false
        }
    }

    override func resetModeState() {
        super.resetModeState()
        showCorrectFeedback = false
        showWrongFeedback = false
    }
}

@MainActor
class ComboSoloArenaSessionViewModel: FeedbackSoloArenaSessionViewModel {
    @Published var comboCount = 0
    @Published var maxCombo = 0
    @Published var showComboAnimation = false
    @Published var showComboBreak = false

    @discardableResult
    func applyComboAnswer(
        _ response: SoloAnswerResponse,
        basePoints: Int = 20,
        bonusPoints: Int = 0,
        feedbackDelay: UInt64 = 800_000_000,
        onCorrect: ((Int) -> Void)? = nil,
        onWrong: (() -> Void)? = nil
    ) async -> Bool {
        let isCorrect = response.isCorrect
        lastCorrectCategory = response.correctCategory

        if isCorrect {
            comboCount += 1
            correctCount += 1
            maxCombo = max(maxCombo, comboCount)

            var pointsEarned = basePoints + bonusPoints
            if comboCount >= 3 {
                pointsEarned += (comboCount - 2) * 5
            }
            sessionScore += pointsEarned

            withAnimation(.easeInOut(duration: 0.3)) {
                if comboCount >= 3 {
                    showComboAnimation = true
                }
            }
            onCorrect?(pointsEarned)
        } else {
            let hadCombo = comboCount >= 3
            comboCount = 0

            withAnimation(.easeInOut(duration: 0.3)) {
                if hadCombo {
                    showComboBreak = true
                }
            }
            onWrong?()
        }

        await playFeedback(
            isCorrect: isCorrect,
            correctDelay: feedbackDelay,
            wrongDelay: feedbackDelay
        )

        withAnimation(.easeOut(duration: 0.2)) {
            showComboAnimation = false
            showComboBreak = false
        }

        return isCorrect
    }

    override func resetModeState() {
        super.resetModeState()
        comboCount = 0
        maxCombo = 0
        showComboAnimation = false
        showComboBreak = false
    }
}

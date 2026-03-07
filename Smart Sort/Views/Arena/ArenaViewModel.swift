//
//  ArenaViewModel.swift
//  Smart Sort
//
//  Extracted from ArenaView.swift
//

import Combine
import Supabase
import SwiftUI

// MARK: - ViewModel

@MainActor
class ArenaViewModel: ObservableObject, ArenaImageManaging {
    @Published var questions: [QuizQuestion] = []
    @Published var isLoading = false
    @Published var totalCredits = 0
    @Published var imageCache: [UUID: UIImage] = [:]
    @Published var failedImageIDs: Set<UUID> = []

    // Quiz Session State
    @Published var currentQuestionIndex = 0
    @Published var sessionScore = 0
    @Published var comboCount = 0
    @Published var maxCombo = 0
    @Published var correctCount = 0
    @Published var sessionCompleted = false

    // Animation States
    @Published var showPointAnimation = false
    @Published var pointAnimationText = ""
    @Published var showComboAnimation = false
    @Published var showCorrectFeedback = false
    @Published var showWrongFeedback = false
    @Published var showComboBreak = false

    @Published var isSubmitting = false

    @Published var showError = false
    @Published var errorMessage: String?
    @Published var lastCorrectCategory: String?

    private let client = SupabaseManager.shared.client
    private var sessionId: UUID?
    var imageLoadHandles: [UUID: ArenaImageLoadHandle] = [:]
    let imageLogPrefix = "Arena"

    var currentQuestion: QuizQuestion? {
        guard currentQuestionIndex < questions.count else { return nil }
        return questions[currentQuestionIndex]
    }

    var progressText: String {
        guard questions.count > 0 else { return "" }
        return "\(min(currentQuestionIndex + 1, questions.count))/\(questions.count)"
    }

    var isCurrentImageReady: Bool {
        guard let question = currentQuestion else { return false }
        return imageCache[question.id] != nil
    }

    init() {}

    func fetchUserCredits() async {
        do {
            struct ProfileCredits: Decodable {
                let id: UUID?
                let credits: Int
            }

            let profile: ProfileCredits =
                try await client
                .rpc("get_my_profile")
                .single()
                .execute()
                .value

            self.totalCredits = profile.credits
        } catch {
            print("❌ [Arena] Failed to fetch credits: \(error)")
        }
    }

    func fetchQuestions() async {
        isLoading = true
        errorMessage = nil
        showError = false
        resetSession()

        do {
            let response: SoloQuizSessionResponse =
                try await client
                .rpc("get_quiz_questions")
                .execute()
                .value

            self.sessionId = response.sessionId
            self.questions = response.questions
            await fetchUserCredits()
            _ = await primeArenaImages(for: response.questions)

        } catch {
            print("❌ [Arena] Fetch Error: \(error)")
            errorMessage = "Failed to load quiz: \(error.localizedDescription)"
            showError = true
        }
        isLoading = false
    }

    private func resetSession() {
        cancelArenaImageLoads()
        currentQuestionIndex = 0
        sessionScore = 0
        comboCount = 0
        maxCombo = 0
        correctCount = 0
        sessionCompleted = false
        sessionId = nil
        lastCorrectCategory = nil
        showCorrectFeedback = false
        showWrongFeedback = false
        showComboBreak = false
        imageCache.removeAll()
        failedImageIDs.removeAll()
        questions.removeAll()
    }

    func submitAnswer(selectedCategory: String) async {
        guard !isSubmitting else { return }
        guard currentQuestion != nil else { return }
        guard let sessionId else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        let answerResponse: SoloAnswerResponse
        do {
            let params = SubmitSoloAnswerParams(
                p_session_id: sessionId.uuidString,
                p_question_index: currentQuestionIndex,
                p_selected_category: selectedCategory,
                p_answer_time_ms: 0
            )
            answerResponse = try await client
                .rpc("submit_solo_answer", params: params)
                .execute()
                .value
        } catch {
            errorMessage = "Failed to submit answer: \(error.localizedDescription)"
            showError = true
            return
        }

        let isCorrect = answerResponse.isCorrect
        lastCorrectCategory = answerResponse.correctCategory

        if isCorrect {
            comboCount += 1
            correctCount += 1
            maxCombo = max(maxCombo, comboCount)

            var pointsEarned = 20
            if comboCount >= 3 {
                let comboBonus = (comboCount - 2) * 5
                pointsEarned += comboBonus
            }

            sessionScore += pointsEarned

            withAnimation(.easeInOut(duration: 0.3)) {
                showCorrectFeedback = true
                pointAnimationText = "+\(pointsEarned)"
                showPointAnimation = true

                if comboCount >= 3 {
                    showComboAnimation = true
                }
            }
        } else {
            let hadCombo = comboCount >= 3
            comboCount = 0

            withAnimation(.easeInOut(duration: 0.3)) {
                showWrongFeedback = true
                if hadCombo {
                    showComboBreak = true
                }
            }
        }

        try? await Task.sleep(nanoseconds: 800_000_000)

        withAnimation(.easeOut(duration: 0.2)) {
            showCorrectFeedback = false
            showWrongFeedback = false
            showPointAnimation = false
            showComboAnimation = false
            showComboBreak = false
        }

        if currentQuestionIndex + 1 >= questions.count {
            do {
                let result: SoloSessionCompletionResponse = try await client
                    .rpc("complete_classic_session", params: ["p_session_id": sessionId.uuidString])
                    .execute()
                    .value

                if let syncedScore = result.score {
                    sessionScore = syncedScore
                }
                if let syncedCorrectCount = result.correctCount {
                    correctCount = syncedCorrectCount
                }
                if let syncedMaxCombo = result.maxCombo {
                    maxCombo = syncedMaxCombo
                }
                if result.pointsAwarded != nil {
                    await fetchUserCredits()
                }

                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    sessionCompleted = true
                }
            } catch {
                errorMessage = "Failed to finalize session: \(error.localizedDescription)"
                showError = true
            }
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentQuestionIndex += 1
            }
            scheduleUpcomingArenaImages(for: questions, startingAt: currentQuestionIndex)
        }
    }

    func startNewSession() async {
        await fetchQuestions()
    }

    func retryCurrentImage() {
        guard let question = currentQuestion else { return }
        scheduleArenaImageLoad(for: question, forceReload: true)
    }
}

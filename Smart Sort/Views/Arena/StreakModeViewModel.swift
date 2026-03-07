//
//  StreakModeViewModel.swift
//  Smart Sort
//
//  Streak Mode: infinite questions until you get one wrong.
//

import Combine
import Supabase
import SwiftUI

@MainActor
class StreakModeViewModel: ObservableObject, ArenaImageManaging {
    @Published var questions: [QuizQuestion] = []
    @Published var isLoading = false
    @Published var imageCache: [UUID: UIImage] = [:]
    @Published var failedImageIDs: Set<UUID> = []

    @Published var currentQuestionIndex = 0
    @Published var sessionScore = 0
    @Published var streakCount = 0
    @Published var sessionCompleted = false

    @Published var showCorrectFeedback = false
    @Published var showWrongFeedback = false
    @Published var isSubmitting = false

    @Published var showError = false
    @Published var errorMessage: String?
    @Published var lastCorrectCategory: String?

    private var seenQuestionIds: Set<UUID> = []
    private var isFetchingMore = false

    private let batchSize = 20
    private let prefetchThreshold = 5

    private let client = SupabaseManager.shared.client
    private var sessionId: UUID?
    var imageLoadHandles: [UUID: ArenaImageLoadHandle] = [:]
    let imageLogPrefix = "Streak"

    var currentQuestion: QuizQuestion? {
        guard currentQuestionIndex < questions.count else { return nil }
        return questions[currentQuestionIndex]
    }

    var questionsRemaining: Int {
        max(0, questions.count - currentQuestionIndex)
    }

    init() {}

    func fetchInitialQuestions() async {
        isLoading = true
        errorMessage = nil
        showError = false
        resetSession()

        do {
            let response: SoloQuizSessionResponse = try await client
                .rpc(
                    "get_quiz_questions_batch",
                    params: QuizQuestionBatchParams(p_limit: batchSize, p_session_id: nil)
                )
                .execute()
                .value

            sessionId = response.sessionId
            let newQuestions = registerQuestionsForSession(response.questions)
            questions = newQuestions
            _ = await primeArenaImages(for: newQuestions)
        } catch {
            errorMessage = "Failed to load questions: \(error.localizedDescription)"
            showError = true
        }
        isLoading = false
    }

    private func fetchMoreQuestions() async {
        guard !isFetchingMore else { return }
        guard let sessionId else { return }

        isFetchingMore = true
        defer { isFetchingMore = false }

       do {
           let params = QuizQuestionBatchParams(
               p_limit: batchSize,
               p_session_id: sessionId.uuidString
           )
           let response: SoloQuizSessionResponse = try await client
               .rpc("get_quiz_questions_batch", params: params)
               .execute()
               .value

            let newQuestions = registerQuestionsForSession(response.questions)
            if !newQuestions.isEmpty {
                questions.append(contentsOf: newQuestions)
                scheduleUpcomingArenaImages(
                    for: questions,
                    startingAt: currentQuestionIndex,
                    prefetchCount: prefetchThreshold
                )
            }
        } catch {
            errorMessage = "Failed to load more streak questions: \(error.localizedDescription)"
            showError = true
        }
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
            errorMessage = "Failed to submit streak answer: \(error.localizedDescription)"
            showError = true
            return
        }

        let isCorrect = answerResponse.isCorrect
        lastCorrectCategory = answerResponse.correctCategory

        if isCorrect {
            streakCount += 1
            sessionScore += 5

            withAnimation(.easeInOut(duration: 0.3)) {
                showCorrectFeedback = true
            }

            try? await Task.sleep(nanoseconds: 600_000_000)

            withAnimation(.easeOut(duration: 0.2)) {
                showCorrectFeedback = false
            }

            withAnimation(.easeInOut(duration: 0.3)) {
                currentQuestionIndex += 1
            }
            scheduleUpcomingArenaImages(
                for: questions,
                startingAt: currentQuestionIndex,
                prefetchCount: prefetchThreshold
            )

            if questionsRemaining <= prefetchThreshold {
                Task { await fetchMoreQuestions() }
            }
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                showWrongFeedback = true
            }

            try? await Task.sleep(nanoseconds: 1_000_000_000)

            withAnimation(.easeOut(duration: 0.2)) {
                showWrongFeedback = false
            }

            if await submitStreakRecord() {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    sessionCompleted = true
                }
            }
        }
    }

    private func submitStreakRecord() async -> Bool {
        guard let sessionId else {
            errorMessage = "Streak session missing"
            showError = true
            return false
        }

        do {
            let response: StreakSessionCompletionResponse = try await client
                .rpc("submit_streak_record", params: ["p_session_id": sessionId.uuidString])
                .execute()
                .value

            streakCount = response.streakCount
            sessionScore = response.pointsAwarded
            return true
        } catch {
            errorMessage = "Streak result could not be saved: \(error.localizedDescription)"
            showError = true
            return false
        }
    }

    private func registerQuestionsForSession(_ fetched: [QuizQuestion]) -> [QuizQuestion] {
        let uniqueQuestions = fetched.filter { !seenQuestionIds.contains($0.id) }
        if !uniqueQuestions.isEmpty {
            for question in uniqueQuestions {
                seenQuestionIds.insert(question.id)
            }
            return uniqueQuestions
        }

        seenQuestionIds = Set(fetched.map(\.id))
        return fetched
    }

    private func resetSession() {
        cancelArenaImageLoads()
        currentQuestionIndex = 0
        sessionScore = 0
        streakCount = 0
        sessionId = nil
        sessionCompleted = false
        lastCorrectCategory = nil
        showCorrectFeedback = false
        showWrongFeedback = false
        seenQuestionIds.removeAll()
        imageCache.removeAll()
        failedImageIDs.removeAll()
        questions.removeAll()
    }

    func startNewSession() async {
        await fetchInitialQuestions()
    }

    func retryCurrentImage() {
        guard let question = currentQuestion else { return }
        scheduleArenaImageLoad(for: question, forceReload: true)
    }
}

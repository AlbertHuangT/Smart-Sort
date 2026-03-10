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
class StreakModeViewModel: FeedbackSoloArenaSessionViewModel {
    @Published var streakCount = 0

    private var seenQuestionIds: Set<UUID> = []
    private var isFetchingMore = false

    private let batchSize = 20
    private let prefetchThreshold = 5

    init() {
        super.init(imageLogPrefix: "Streak")
    }

    var questionsRemaining: Int {
        max(0, questions.count - currentQuestionIndex)
    }

    func fetchInitialQuestions() async {
        beginLoadingSession()

        do {
            let response: SoloQuizSessionResponse = try await client
                .rpc(
                    "get_quiz_questions_batch",
                    params: QuizQuestionBatchParams(p_limit: batchSize, p_session_id: nil)
                )
                .execute()
                .value

            let newQuestions = registerQuestionsForSession(response.questions)
            let preparedResponse = SoloQuizSessionResponse(sessionId: response.sessionId, questions: newQuestions)
            await applySessionResponse(preparedResponse, prefetchCount: prefetchThreshold)
        } catch {
            presentError("Failed to load questions: \(error.localizedDescription)")
        }
        finishLoadingSession()
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
            presentError("Failed to load more streak questions: \(error.localizedDescription)")
        }
    }

    func submitAnswer(selectedCategory: String) async {
        guard !isSubmitting else { return }
        guard currentQuestion != nil else { return }

        isSubmitting = true
        defer { isSubmitting = false }

       do {
           let answerResponse = try await submitAnswerRequest(
               selectedCategory: selectedCategory,
               missingSessionContext: "Streak"
           )

            let isCorrect = answerResponse.isCorrect
            lastCorrectCategory = answerResponse.correctCategory

            if isCorrect {
                streakCount += 1
                correctCount += 1
                sessionScore += 5

                await playFeedback(isCorrect: true, correctDelay: 600_000_000, wrongDelay: 600_000_000)

                advanceToNextQuestion(prefetchCount: prefetchThreshold)

                if questionsRemaining <= prefetchThreshold {
                    Task { await fetchMoreQuestions() }
                }
            } else {
                await playFeedback(isCorrect: false, correctDelay: 1_000_000_000, wrongDelay: 1_000_000_000)

                if await submitStreakRecord() {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        sessionCompleted = true
                    }
                }
            }
        } catch {
            presentError("Failed to submit streak answer: \(error.localizedDescription)")
        }
    }

    private func submitStreakRecord() async -> Bool {
        guard let sessionId else {
            presentError("Streak session missing")
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
            presentError("Streak result could not be saved: \(error.localizedDescription)")
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

    override func resetModeState() {
        super.resetModeState()
        streakCount = 0
        seenQuestionIds.removeAll()
    }

    func startNewSession() async {
        await fetchInitialQuestions()
    }

    func retryCurrentImage() {
        guard let question = currentQuestion else { return }
        scheduleArenaImageLoad(for: question, forceReload: true)
    }
}

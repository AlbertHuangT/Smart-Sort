//
//  DailyChallengeViewModel.swift
//  Smart Sort
//
//  Daily Challenge: same 10 questions for everyone, once per day, timed.
//

import Combine
import Supabase
import SwiftUI

@MainActor
class DailyChallengeViewModel: ObservableObject, ArenaImageManaging {
    @Published var challengeResponse: DailyChallengeResponse?
    @Published var questions: [QuizQuestion] = []
    @Published var isLoading = false
    @Published var imageCache: [UUID: UIImage] = [:]
    @Published var failedImageIDs: Set<UUID> = []

    @Published var currentQuestionIndex = 0
    @Published var sessionScore = 0
    @Published var comboCount = 0
    @Published var maxCombo = 0
    @Published var correctCount = 0
    @Published var sessionCompleted = false
    @Published var alreadyPlayed = false

    @Published var elapsedSeconds: Double = 0
    private var timerCancellable: AnyCancellable?

    @Published var showCorrectFeedback = false
    @Published var showWrongFeedback = false
    @Published var showComboAnimation = false
    @Published var showComboBreak = false
    @Published var isSubmitting = false

    @Published var showError = false
    @Published var errorMessage: String?
    @Published var lastCorrectCategory: String?
    @Published var pointsAwarded = 0

    private let client = SupabaseManager.shared.client
    private var sessionId: UUID?
    var imageLoadHandles: [UUID: ArenaImageLoadHandle] = [:]
    let imageLogPrefix = "Daily"

    var currentQuestion: QuizQuestion? {
        guard currentQuestionIndex < questions.count else { return nil }
        return questions[currentQuestionIndex]
    }

    var progressText: String {
        guard questions.count > 0 else { return "" }
        return "\(min(currentQuestionIndex + 1, questions.count))/\(questions.count)"
    }

    var formattedTime: String {
        let mins = Int(elapsedSeconds) / 60
        let secs = Int(elapsedSeconds) % 60
        let tenths = Int(elapsedSeconds * 10) % 10
        if mins > 0 {
            return String(format: "%d:%02d.%d", mins, secs, tenths)
        }
        return String(format: "%d.%d", secs, tenths)
    }

    func fetchChallenge() async {
        isLoading = true
        errorMessage = nil
        showError = false
        resetSession()

        do {
            let response: DailyChallengeResponse = try await client
                .rpc("get_daily_challenge")
                .execute()
                .value

            challengeResponse = response
            alreadyPlayed = response.alreadyPlayed
            sessionId = response.sessionId
            questions = response.questions

            if !response.alreadyPlayed {
                _ = await primeArenaImages(for: response.questions)
                startTimer()
            }
        } catch {
            errorMessage = "Failed to load daily challenge: \(error.localizedDescription)"
            showError = true
        }
        isLoading = false
    }

    private func startTimer() {
        elapsedSeconds = 0
        timerCancellable?.cancel()
        timerCancellable = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.elapsedSeconds += 0.1
            }
    }

    func stopTimer() {
        timerCancellable?.cancel()
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
                pointsEarned += (comboCount - 2) * 5
            }
            sessionScore += pointsEarned

            withAnimation(.easeInOut(duration: 0.3)) {
                showCorrectFeedback = true
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
            showComboAnimation = false
            showComboBreak = false
        }

        if currentQuestionIndex + 1 >= questions.count {
            stopTimer()
            if await submitResult() {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    sessionCompleted = true
                }
            }
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentQuestionIndex += 1
            }
            scheduleUpcomingArenaImages(for: questions, startingAt: currentQuestionIndex)
        }
    }

    private func submitResult() async -> Bool {
        guard let sessionId else {
            errorMessage = "Daily Challenge session missing"
            showError = true
            return false
        }

        do {
            let response: DailyChallengeSubmitResponse = try await client
                .rpc(
                    "submit_daily_challenge",
                    params: DailyChallengeSubmitParams(
                        p_session_id: sessionId,
                        p_time_seconds: elapsedSeconds
                    )
                )
                .execute()
                .value

            pointsAwarded = response.pointsAwarded
            if let score = response.score {
                sessionScore = score
            }
            if let correctCount = response.correctCount {
                self.correctCount = correctCount
            }
            if let maxCombo = response.maxCombo {
                self.maxCombo = maxCombo
            }
            alreadyPlayed = true
            return true
        } catch {
            errorMessage = "Daily result could not be saved: \(error.localizedDescription)"
            showError = true
            return false
        }
    }

    private func resetSession() {
        cancelArenaImageLoads()
        currentQuestionIndex = 0
        sessionScore = 0
        comboCount = 0
        maxCombo = 0
        correctCount = 0
        sessionCompleted = false
        alreadyPlayed = false
        sessionId = nil
        showCorrectFeedback = false
        showWrongFeedback = false
        showComboAnimation = false
        showComboBreak = false
        elapsedSeconds = 0
        pointsAwarded = 0
        lastCorrectCategory = nil
        imageCache.removeAll()
        failedImageIDs.removeAll()
        questions.removeAll()
        challengeResponse = nil
        stopTimer()
    }

    func retryCurrentImage() {
        guard let question = currentQuestion else { return }
        scheduleArenaImageLoad(for: question, forceReload: true)
    }
}

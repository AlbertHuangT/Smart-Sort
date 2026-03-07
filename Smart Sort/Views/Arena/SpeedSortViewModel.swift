//
//  SpeedSortViewModel.swift
//  Smart Sort
//
//  Speed Sort: 10 questions with 5-second countdown per question.
//  Time bonus: max(0, timeRemaining) x 4 extra points.
//

import Combine
import Supabase
import SwiftUI

@MainActor
class SpeedSortViewModel: ObservableObject, ArenaImageManaging {
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

    @Published var timeRemaining: Double = 5.0
    let timePerQuestion: Double = 5.0
    private var timerCancellable: AnyCancellable?
    private var timeoutTask: Task<Void, Never>?
    private var timerStartTask: Task<Void, Never>?
    private var questionStartedAt: Date?

    @Published var countdownValue: Int? = nil
    @Published var isCountingDown = false

    @Published var showCorrectFeedback = false
    @Published var showWrongFeedback = false
    @Published var showComboAnimation = false
    @Published var showComboBreak = false
    @Published var isSubmitting = false

    @Published var showError = false
    @Published var errorMessage: String?
    @Published var lastCorrectCategory: String?
    @Published var lastTimeBonus = 0

    private let client = SupabaseManager.shared.client
    private var sessionId: UUID?
    var imageLoadHandles: [UUID: ArenaImageLoadHandle] = [:]
    let imageLogPrefix = "SpeedSort"

    var currentQuestion: QuizQuestion? {
        guard currentQuestionIndex < questions.count else { return nil }
        return questions[currentQuestionIndex]
    }

    var progressText: String {
        guard questions.count > 0 else { return "" }
        return "\(min(currentQuestionIndex + 1, questions.count))/\(questions.count)"
    }

    init() {}

    func fetchQuestions() async {
        isLoading = true
        errorMessage = nil
        showError = false
        resetSession()

        do {
            let params = QuizQuestionsForModeParams(p_mode: "speed_sort", p_limit: 10)
            let response: SoloQuizSessionResponse = try await client
                .rpc("get_quiz_questions_for_mode", params: params)
                .execute()
                .value

            sessionId = response.sessionId
            questions = response.questions
            _ = await primeArenaImages(for: response.questions)
            await startCountdown()
        } catch {
            errorMessage = "Failed to load quiz: \(error.localizedDescription)"
            showError = true
        }
        isLoading = false
    }

    private func startCountdown() async {
        isCountingDown = true
        for i in stride(from: 3, through: 1, by: -1) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                countdownValue = i
            }
            try? await Task.sleep(nanoseconds: 800_000_000)
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            countdownValue = 0
        }
        try? await Task.sleep(nanoseconds: 500_000_000)
        withAnimation {
            countdownValue = nil
            isCountingDown = false
        }
        queueTimerStart()
    }

    private func startTimer() {
        timeRemaining = timePerQuestion
        timerCancellable?.cancel()
        questionStartedAt = Date()
        timerCancellable = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                if self.timeRemaining > 0 {
                    self.timeRemaining -= 0.1
                    if self.timeRemaining < 0 {
                        self.timeRemaining = 0
                    }
                } else {
                    self.timerCancellable?.cancel()
                    self.timeoutTask = Task { await self.handleTimeout() }
                }
            }
    }

    func stopTimer() {
        timerCancellable?.cancel()
        timeoutTask?.cancel()
        timerStartTask?.cancel()
    }

    private func queueTimerStart() {
        timerStartTask?.cancel()
        timerStartTask = Task { @MainActor [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                guard let question = self.currentQuestion else { return }

                if self.imageCache[question.id] != nil {
                    self.startTimer()
                    return
                }

                if self.failedImageIDs.contains(question.id) {
                    self.errorMessage = "Image unavailable. Retry the image to continue."
                    self.showError = true
                    return
                }

                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }

    func submitAnswer(selectedCategory: String) async {
        guard !isSubmitting else { return }
        guard currentQuestion != nil else { return }
        guard let sessionId else { return }

        isSubmitting = true
        stopTimer()
        defer { isSubmitting = false }

        let elapsedMs = max(
            0,
            Int((Date().timeIntervalSince(questionStartedAt ?? Date())) * 1000)
        )

        let answerResponse: SoloAnswerResponse
        do {
            let params = SubmitSoloAnswerParams(
                p_session_id: sessionId.uuidString,
                p_question_index: currentQuestionIndex,
                p_selected_category: selectedCategory,
                p_answer_time_ms: elapsedMs
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

            let timeBonus = Int(max(0, timeRemaining) * 4)
            pointsEarned += timeBonus
            lastTimeBonus = timeBonus
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
            lastTimeBonus = 0

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

        await advanceToNext()
    }

    private func handleTimeout() async {
        guard !isSubmitting, !Task.isCancelled else { return }
        await submitAnswer(selectedCategory: "__timeout__")
    }

    private func advanceToNext() async {
        if currentQuestionIndex + 1 >= questions.count {
            await completeSession()
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentQuestionIndex += 1
            }
            scheduleUpcomingArenaImages(for: questions, startingAt: currentQuestionIndex)
            queueTimerStart()
        }
    }

    private func completeSession() async {
        guard let sessionId else {
            errorMessage = "Speed Sort session missing"
            showError = true
            return
        }

        do {
            let result: SoloSessionCompletionResponse = try await client
                .rpc("complete_speed_sort_session", params: ["p_session_id": sessionId.uuidString])
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

            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                sessionCompleted = true
            }
        } catch {
            errorMessage = "Failed to finalize Speed Sort: \(error.localizedDescription)"
            showError = true
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
        sessionId = nil
        showCorrectFeedback = false
        showWrongFeedback = false
        showComboBreak = false
        showComboAnimation = false
        timeRemaining = timePerQuestion
        lastTimeBonus = 0
        lastCorrectCategory = nil
        countdownValue = nil
        isCountingDown = false
        questionStartedAt = nil
        imageCache.removeAll()
        failedImageIDs.removeAll()
        questions.removeAll()
        stopTimer()
    }

    func startNewSession() async {
        await fetchQuestions()
    }

    func retryCurrentImage() {
        guard let question = currentQuestion else { return }
        scheduleArenaImageLoad(for: question, forceReload: true)
        if !isCountingDown {
            queueTimerStart()
        }
    }
}

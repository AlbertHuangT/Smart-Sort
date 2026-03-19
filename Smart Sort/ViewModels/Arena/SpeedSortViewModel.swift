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
class SpeedSortViewModel: ComboSoloArenaSessionViewModel {
    @Published var timeRemaining: Double = 5.0
    let timePerQuestion: Double = 5.0
    private var timerCancellable: AnyCancellable?
    private var timeoutTask: Task<Void, Never>?
    private var questionStartedAt: Date?

    @Published var countdownValue: Int? = nil
    @Published var isCountingDown = false

    @Published var lastTimeBonus = 0

    init() {
        super.init(imageLogPrefix: "SpeedSort")
    }

    func fetchQuestions() async {
        beginLoadingSession()

        do {
            let params = QuizQuestionsForModeParams(p_mode: "speed_sort", p_limit: 10)
            let response: SoloQuizSessionResponse = try await client
                .rpc("get_quiz_questions_for_mode", params: params)
                .execute()
                .value

            await applySessionResponse(response)
            await startCountdown()
        } catch {
            presentError("Failed to load quiz: \(error.localizedDescription)")
        }
        finishLoadingSession()
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
        await startTimerForCurrentQuestionIfReady()
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
    }

    private func startTimerForCurrentQuestionIfReady(forceReload: Bool = false) async {
        guard let question = currentQuestion else { return }

        let imageReady = await loadArenaImage(for: question, forceReload: forceReload)
        guard currentQuestion?.id == question.id else { return }
        guard imageReady else {
            errorMessage = "Image unavailable. Retry the image to continue."
            showError = true
            return
        }

        startTimer()
    }

    func submitAnswer(selectedCategory: String) async {
        guard !isSubmitting else { return }
        guard currentQuestion != nil else { return }

        isSubmitting = true
        stopTimer()
        defer { isSubmitting = false }

        let elapsedMs = max(
            0,
            Int((Date().timeIntervalSince(questionStartedAt ?? Date())) * 1000)
        )

        do {
            let answerResponse = try await submitAnswerRequest(
                selectedCategory: selectedCategory,
                answerTimeMs: elapsedMs,
                missingSessionContext: "Speed Sort"
            )
            let timeBonus = Int(max(0, timeRemaining) * 4)
            _ = await applyComboAnswer(
                answerResponse,
                bonusPoints: timeBonus,
                onCorrect: { [self] _ in
                    self.lastTimeBonus = timeBonus
                },
                onWrong: { [self] in
                    self.lastTimeBonus = 0
                }
            )

            await advanceToNext()
        } catch {
            presentError("Failed to submit answer: \(error.localizedDescription)")
        }
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
            await startTimerForCurrentQuestionIfReady()
        }
    }

    private func completeSession() async {
        do {
            let result = try await completeSpeedSortSession()

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
            presentError("Failed to finalize Speed Sort: \(error.localizedDescription)")
        }
    }

    func startNewSession() async {
        await fetchQuestions()
    }

    func retryCurrentImage() {
        guard let question = currentQuestion else { return }
        showError = false
        errorMessage = nil
        Task { [weak self] in
            guard let self else { return }
            if !self.isCountingDown {
                await self.startTimerForCurrentQuestionIfReady(forceReload: true)
            } else {
                _ = await self.loadArenaImage(for: question, forceReload: true)
            }
        }
    }

    override func resetModeState() {
        super.resetModeState()
        timeRemaining = timePerQuestion
        lastTimeBonus = 0
        countdownValue = nil
        isCountingDown = false
        questionStartedAt = nil
        stopTimer()
    }
}

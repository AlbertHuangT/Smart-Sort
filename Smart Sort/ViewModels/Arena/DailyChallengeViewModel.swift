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
class DailyChallengeViewModel: ComboSoloArenaSessionViewModel {
    @Published var challengeResponse: DailyChallengeResponse?
    @Published var alreadyPlayed = false

    @Published var elapsedSeconds: Double = 0
    private var timerCancellable: AnyCancellable?

    @Published var pointsAwarded = 0

    init() {
        super.init(imageLogPrefix: "Daily")
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
        beginLoadingSession()

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
            presentError("Failed to load daily challenge: \(error.localizedDescription)")
        }
        finishLoadingSession()
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

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let answerResponse = try await submitAnswerRequest(
                selectedCategory: selectedCategory,
                missingSessionContext: "Daily Challenge"
            )
            _ = await applyComboAnswer(answerResponse)

            if currentQuestionIndex + 1 >= questions.count {
                stopTimer()
                if await submitResult() {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        sessionCompleted = true
                    }
                }
            } else {
                advanceToNextQuestion()
            }
        } catch {
            presentError("Failed to submit answer: \(error.localizedDescription)")
        }
    }

    private func submitResult() async -> Bool {
        guard let sessionId else {
            presentError("Daily Challenge session missing")
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
            presentError("Daily result could not be saved: \(error.localizedDescription)")
            return false
        }
    }

    func retryCurrentImage() {
        guard let question = currentQuestion else { return }
        scheduleArenaImageLoad(for: question, forceReload: true)
    }

    override func resetModeState() {
        super.resetModeState()
        alreadyPlayed = false
        elapsedSeconds = 0
        pointsAwarded = 0
        challengeResponse = nil
        stopTimer()
    }
}

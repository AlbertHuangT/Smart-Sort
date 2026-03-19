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
class ArenaViewModel: ComboSoloArenaSessionViewModel {
    @Published var totalCredits = 0
    @Published var pointAnimationText = ""
    private let profileService = ProfileService.shared

    var isCurrentImageReady: Bool {
        isArenaImageReady(for: currentQuestion)
    }

    init() {
        super.init(imageLogPrefix: "Arena")
    }

    func fetchUserCredits() async {
        do {
            totalCredits = try await profileService.fetchMyCredits()
        } catch {
            print("❌ [Arena] Failed to fetch credits: \(error)")
        }
    }

    func fetchQuestions() async {
        beginLoadingSession()

        do {
            let response: SoloQuizSessionResponse =
                try await client
                .rpc("get_quiz_questions")
                .execute()
                .value

            await applySessionResponse(response)
            await fetchUserCredits()
        } catch {
            print("❌ [Arena] Fetch Error: \(error)")
            presentError("Failed to load quiz: \(error.localizedDescription)")
        }
        finishLoadingSession()
    }

    func submitAnswer(selectedCategory: String) async {
        guard !isSubmitting else { return }
        guard currentQuestion != nil else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let answerResponse = try await submitAnswerRequest(
                selectedCategory: selectedCategory,
                missingSessionContext: "Classic Arena"
            )
            _ = await applyComboAnswer(answerResponse) { [self] pointsEarned in
                self.pointAnimationText = "+\(pointsEarned)"
            }

            if currentQuestionIndex + 1 >= questions.count {
                let result = try await completeClassicSession()
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
            } else {
                advanceToNextQuestion()
            }
        } catch {
            presentError("Failed to submit answer: \(error.localizedDescription)")
        }
    }

    func startNewSession() async {
        await fetchQuestions()
    }

    func retryCurrentImage() {
        guard let question = currentQuestion else { return }
        scheduleArenaImageLoad(for: question, forceReload: true)
    }

    override func resetModeState() {
        super.resetModeState()
        pointAnimationText = ""
    }
}

//
//  StreakModeView.swift
//  Smart Sort
//
//  Streak Mode: answer as many as you can. One wrong answer ends the run.
//

import SwiftUI

struct StreakModeView: View {
    @StateObject private var viewModel = StreakModeViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    private let theme = TrashTheme()
    @State private var pulseAnimation = false
    // showAccountSheet managed by ContentView via environment
    @State private var showLeaderboard = false

    let categories = ["Recyclable", "Compostable", "Landfill", "Hazardous"]

    var body: some View {
        ZStack {
            ThemeBackgroundView()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if viewModel.sessionCompleted {
                    streakSummary
                } else {
                    mainContent
                }
            }
        }
        .sheet(isPresented: $showLeaderboard) {
            StreakLeaderboardView()
        }
        .navigationTitle("Streak Mode")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                AccountButton()
            }
        }
        .task {
            pulseAnimation = true
            await viewModel.fetchInitialQuestions()
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
            // Status bar
            HStack(spacing: 12) {
                // Streak count pill
                HStack(spacing: 6) {
                    TrashIcon(systemName: "arrow.up.right")
                        .font(.caption.bold())
                    Text("Streak: \(viewModel.streakCount)")
                        .font(.subheadline.bold())
                }
                .foregroundColor(theme.accents.purple)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .neumorphicConcave(cornerRadius: 20)

                // Points pill
                HStack(spacing: 4) {
                    TrashIcon(systemName: "flame.fill")
                    Text("+\(viewModel.sessionScore)")
                        .fontWeight(.black)
                }
                .font(.subheadline)
                .foregroundColor(theme.accents.orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .neumorphicConcave(cornerRadius: 20)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)

            if viewModel.showError {
                errorBanner
            }

            Spacer()

            // Quiz card area
            quizCardArea

            Spacer()
        }
    }

    private var quizCardArea: some View {
        ZStack {
            if viewModel.questions.isEmpty {
                if viewModel.isLoading {
                    EnhancedLoadingView()
                } else {
                    EnhancedEmptyStateView(onRefresh: {
                        Task { await viewModel.fetchInitialQuestions() }
                    })
                }
            } else if let question = viewModel.currentQuestion {
                SharedQuizCard(
                    question: question,
                    image: viewModel.imageCache[question.id],
                    categories: categories,
                    showCorrect: viewModel.showCorrectFeedback,
                    showWrong: viewModel.showWrongFeedback,
                    isSubmitting: viewModel.isSubmitting,
                    onAnswer: { category in
                        Task { await viewModel.submitAnswer(selectedCategory: category) }
                    }
                )
                .id(question.id)
            } else {
                // Ran out of questions (unlikely but handle)
                VStack(spacing: 16) {
                    TrashIcon(systemName: "trophy.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom)
                        )
                    Text("No more questions!")
                        .font(.title2.bold())
                        .foregroundColor(theme.palette.textPrimary)
                    Text("Incredible streak of \(viewModel.streakCount)!")
                        .foregroundColor(theme.palette.textSecondary)
                }
            }
        }
        .frame(height: 540)
        .padding(.horizontal, 16)
    }

    private var errorBanner: some View {
        HStack(spacing: 12) {
            TrashIcon(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(theme.semanticWarning)
            Text(viewModel.errorMessage ?? "")
                .font(.subheadline)
                .foregroundColor(theme.palette.textPrimary)
            Spacer()
            TrashIconButton(icon: "xmark", action: { viewModel.showError = false })
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.palette.background)
                .shadow(color: theme.shadows.dark, radius: 6, x: 4, y: 4)
                .shadow(color: theme.shadows.light, radius: 6, x: -3, y: -3)
        )
        .padding(.horizontal)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Summary

    private var streakSummary: some View {
        GenericSessionSummaryView(
            title: "Streak Over!",
            icon: "arrow.up.right",
            isGoodResult: viewModel.streakCount >= 5,
            stats: [
                (
                    icon: "arrow.up.right", title: "Streak", value: "\(viewModel.streakCount)",
                    color: theme.accents.purple
                ),
                (
                    icon: "flame.fill", title: "Points Earned", value: "+\(viewModel.sessionScore)",
                    color: theme.accents.orange
                ),
            ],
            onPlayAgain: {
                Task { await viewModel.startNewSession() }
            },
            onViewLeaderboard: {
                showLeaderboard = true
            }
        )
    }
}

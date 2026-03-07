//
//  ArenaView.swift
//  Smart Sort
//
//  Created by Albert Huang on 2/3/26.
//

import Combine
import Supabase
import SwiftUI

// MARK: - Main View
struct ArenaView: View {
    @StateObject private var viewModel = ArenaViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    private let theme = TrashTheme()
    @State private var pulseAnimation = false
    // showAccountSheet managed by ContentView via environment

    let categories = ["Recyclable", "Compostable", "Landfill", "Hazardous"]

    var body: some View {
        ZStack {

            VStack(spacing: 0) {
                if authViewModel.isAnonymous {
                    EnhancedAnonymousRestrictionView()
                } else {
                    mainArenaContent
                }
            }
        }
        .navigationTitle("Classic Arena")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                AccountButton()
                    .environmentObject(authViewModel)
            }
        }
        .task {
            pulseAnimation = true
            if !authViewModel.isAnonymous && viewModel.questions.isEmpty
                && !viewModel.sessionCompleted
            {
                await viewModel.fetchQuestions()
            }
        }
        .onReceive(authViewModel.$session) { _ in
            if !authViewModel.isAnonymous && viewModel.questions.isEmpty
                && !viewModel.sessionCompleted
            {
                Task { await viewModel.fetchQuestions() }
            }
        }
    }

    var mainArenaContent: some View {
        ZStack {
            VStack(spacing: 0) {
                // Status bar
                statusBar

                // Error banner
                if viewModel.showError, viewModel.errorMessage != nil {
                    errorBanner
                }

                Spacer()

                // Main content
                if viewModel.sessionCompleted {
                    EnhancedSessionSummaryView(viewModel: viewModel)
                } else {
                    enhancedQuizCardArea
                }

                Spacer()
            }

            // Combo Animation Overlay
            if viewModel.showComboAnimation {
                EnhancedComboOverlay(comboCount: viewModel.comboCount)
                    .transition(.scale.combined(with: .opacity))
            }

            // Combo Break Animation
            if viewModel.showComboBreak {
                EnhancedComboBreakOverlay()
                    .transition(.opacity)
            }
        }
    }

    // Status bar (progress, combo)
    var statusBar: some View {
        ArenaStatusBar(
            progressText: !viewModel.questions.isEmpty && !viewModel.sessionCompleted ? viewModel.progressText : nil,
            comboCount: viewModel.comboCount,
            showProgress: true,
            pulseAnimation: $pulseAnimation
        )
    }

    // Error banner
    var errorBanner: some View {
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
            RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                .fill(theme.surfaceBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                        .stroke(theme.palette.divider.opacity(0.85), lineWidth: 1)
                )
        )
        .padding(.horizontal)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // Quiz card area
    var enhancedQuizCardArea: some View {
        ZStack {
            if viewModel.questions.isEmpty {
                if viewModel.isLoading {
                    EnhancedLoadingView()
                } else {
                    EnhancedEmptyStateView(onRefresh: {
                        Task { await viewModel.fetchQuestions() }
                    })
                }
            } else if let question = viewModel.currentQuestion {
                SharedQuizCard(
                    question: question,
                    image: viewModel.imageCache[question.id],
                    imageFailed: viewModel.isArenaImageFailed(for: question),
                    correctAnswer: viewModel.lastCorrectCategory,
                    categories: categories,
                    showCorrect: viewModel.showCorrectFeedback,
                    showWrong: viewModel.showWrongFeedback,
                    isSubmitting: viewModel.isSubmitting,
                    pointsText: viewModel.pointAnimationText.isEmpty ? "+20" : viewModel.pointAnimationText,
                    onRetryImage: { viewModel.retryCurrentImage() }
                ) { selectedCategory in
                    Task { await viewModel.submitAnswer(selectedCategory: selectedCategory) }
                }
                .id(question.id)
            }
        }
        .frame(height: min(540, UIScreen.main.bounds.height * 0.62))
        .padding(.horizontal, theme.components.contentInset)
    }
}

// MARK: - Enhanced Subviews

// Anonymous restriction view
struct EnhancedAnonymousRestrictionView: View {
    var body: some View {
        EmptyStateView(
            icon: "lock.shield.fill",
            title: "Access Restricted",
            subtitle: "Trash Arena is only available for registered users. Link your email or phone in Account to participate and earn rewards."
        )
    }
}

// Loading view
struct EnhancedLoadingView: View {
    private let theme = TrashTheme()

    var body: some View {
        VStack(spacing: 24) {
            ProgressView()
                .controlSize(.large)
                .tint(theme.accents.blue)

            Text("Loading Arena...")
                .font(.headline)
                .foregroundColor(theme.palette.textSecondary)
        }
    }
}

// Empty state view
struct EnhancedEmptyStateView: View {
    var onRefresh: () -> Void
    private let theme = TrashTheme()

    var body: some View {
        VStack(spacing: 20) {
            EmptyStateView(
                icon: "trophy.circle.fill",
                title: "All Caught Up",
                subtitle: "No quiz questions available right now. Check back later for more challenges."
            )

            TrashButton(baseColor: theme.accents.blue, action: onRefresh) {
                HStack(spacing: 8) {
                    TrashIcon(systemName: "arrow.clockwise")
                    Text("Refresh Quiz")
                }
            }
        }
    }
}

// MARK: - Enhanced Quiz Card
struct EnhancedQuizCard: View {
    let question: QuizQuestion
    let image: UIImage?
    let imageFailed: Bool
    let correctAnswer: String?
    let categories: [String]
    let showCorrect: Bool
    let showWrong: Bool
    let isSubmitting: Bool
    let pointsText: String
    let onRetryImage: (() -> Void)?
    let onAnswer: (String) -> Void
    var body: some View {
        SharedQuizCard(
            question: question,
            image: image,
            imageFailed: imageFailed,
            correctAnswer: correctAnswer,
            categories: categories,
            showCorrect: showCorrect,
            showWrong: showWrong,
            isSubmitting: isSubmitting,
            pointsText: pointsText,
            onRetryImage: onRetryImage,
            onAnswer: onAnswer
        )
    }
}

// Category answer button
struct CategoryAnswerButton: View {
    let category: String
    let isDisabled: Bool
    let onTap: () -> Void
    private let theme = TrashTheme()

    var categoryColor: Color {
        switch category {
        case "Recyclable": return theme.categoryRecyclable
        case "Compostable": return theme.categoryCompostable
        case "Hazardous": return theme.categoryHazardous
        case "Landfill": return theme.categoryLandfill
        default: return theme.palette.textPrimary
        }
    }

    var categoryIcon: String {
        switch category {
        case "Recyclable": return "arrow.3.trianglepath"
        case "Compostable": return "leaf.fill"
        case "Hazardous": return "exclamationmark.triangle.fill"
        case "Landfill": return "trash.fill"
        default: return "circle.fill"
        }
    }

    var body: some View {
        TrashTapArea(
            haptics: true,
            action: onTap
        ) {
            HStack(spacing: 8) {
                TrashIcon(systemName: categoryIcon)
                    .font(.system(size: 17, weight: .semibold))
                Text(category)
                    .font(theme.typography.subheadline.weight(.bold))
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: theme.components.buttonHeight)
            .background(
                RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                    .fill(theme.palette.card.opacity(isDisabled ? 0.5 : 0.95))
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                    .stroke(categoryColor.opacity(isDisabled ? 0.2 : 0.4), lineWidth: 1.5)
            )
            .foregroundColor(categoryColor)
        }
        .disabled(isDisabled)
        .scaleEffect(isDisabled ? 0.97 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isDisabled)
        .accessibilityLabel("Category: \(category)")
        .accessibilityHint("Tap to select \(category) as your answer")
    }
}

// Correct feedback
struct EnhancedCorrectFeedback: View {
    let pointsText: String
    @State private var animate = false
    private let theme = TrashTheme()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [theme.semanticSuccess.opacity(0.92), theme.accents.green.opacity(0.92)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: theme.spacing.sm + 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .compatibleBounceEffect(value: animate)
                Text("Correct!")
                    .font(theme.typography.title.weight(.heavy))
                Text(pointsText)
                    .font(theme.typography.headline)
                    .opacity(0.8)
            }
            .trashOnAccentForeground()
            .onAppear { animate = true }
        }
        .clipShape(RoundedRectangle(cornerRadius: theme.corners.large + 4))
        .transition(.opacity)
    }
}

// Wrong feedback
struct EnhancedWrongFeedback: View {
    let correctAnswer: String
    @State private var animate = false
    private let theme = TrashTheme()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [theme.semanticDanger.opacity(0.92), theme.semanticWarning.opacity(0.92)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: theme.spacing.sm + 4) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 64))
                    .compatibleWiggleEffect(value: animate)
                Text("Wrong!")
                    .font(theme.typography.title.weight(.heavy))
                Text("Correct: \(correctAnswer)")
                    .font(theme.typography.headline)
                    .opacity(0.9)
            }
            .trashOnAccentForeground()
            .onAppear { animate = true }
        }
        .clipShape(RoundedRectangle(cornerRadius: theme.corners.large + 4))
        .transition(.opacity)
    }
}

// Combo overlay
struct EnhancedComboOverlay: View {
    let comboCount: Int
    @State private var scale: CGFloat = 0.5
    private let theme = TrashTheme()

    var body: some View {
        VStack(spacing: theme.spacing.sm + 4) {
            Image(systemName: "flame.fill")
                .font(.system(size: 64, weight: .bold))
                .compatibleVariableColorEffect(isActive: true)
                .foregroundStyle(
                    LinearGradient(
                        colors: [theme.accents.orange, theme.semanticDanger, theme.semanticHighlight],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .scaleEffect(scale)
                .shadow(color: theme.accents.orange.opacity(0.45), radius: 10)
            Text("\(comboCount)x COMBO!")
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [theme.accents.orange, theme.semanticDanger, theme.semanticHighlight],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .padding(theme.spacing.xxl + 10)
        .background(
            RoundedRectangle(cornerRadius: theme.corners.large + 12, style: .continuous)
                .fill(theme.surfaceBackground.opacity(0.97))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.corners.large + 12, style: .continuous)
                        .stroke(theme.palette.divider.opacity(0.85), lineWidth: 1)
                )
        )
        .shadow(color: theme.accents.orange.opacity(0.35), radius: 24)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                scale = 1.2
            }
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6).delay(0.15)) {
                scale = 1.0
            }
        }
    }
}

// Combo break overlay
struct EnhancedComboBreakOverlay: View {
    @State private var opacity: Double = 1
    private let theme = TrashTheme()

    var body: some View {
        VStack(spacing: theme.spacing.sm + 4) {
            Image(systemName: "heart.slash.fill")
                .font(.system(size: 52, weight: .bold))
                .foregroundColor(theme.semanticDanger)
                .compatibleBounceEffect(value: opacity)
            Text("Combo Lost!")
                .font(.title.bold())
                .foregroundColor(theme.semanticDanger)
        }
        .padding(theme.spacing.xxl)
        .background(
            RoundedRectangle(cornerRadius: theme.corners.large, style: .continuous)
                .fill(theme.surfaceBackground.opacity(0.97))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.corners.large, style: .continuous)
                        .stroke(theme.palette.divider.opacity(0.85), lineWidth: 1)
                )
        )
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                opacity = 0
            }
        }
    }
}

// Session summary
struct EnhancedSessionSummaryView: View {
    @ObservedObject var viewModel: ArenaViewModel
    private let theme = TrashTheme()

    var accuracy: Int {
        guard viewModel.questions.count > 0 else { return 0 }
        return Int(Double(viewModel.correctCount) / Double(viewModel.questions.count) * 100)
    }

    var body: some View {
        GenericSessionSummaryView(
            title: "Quiz Complete!",
            icon: accuracy >= 70 ? "trophy.fill" : "flag.checkered",
            isGoodResult: accuracy >= 70,
            stats: [
                (icon: "flame.fill", title: "Points Earned", value: "+\(viewModel.sessionScore)", color: theme.accents.orange),
                (icon: "checkmark.circle.fill", title: "Correct Answers", value: "\(viewModel.correctCount)/\(viewModel.questions.count)", color: theme.accents.green),
                (icon: "percent", title: "Accuracy", value: "\(accuracy)%", color: theme.accents.blue),
                (icon: "bolt.fill", title: "Best Combo", value: "\(viewModel.maxCombo)x", color: theme.accents.purple)
            ],
            onPlayAgain: {
                Task { await viewModel.startNewSession() }
            }
        )
    }
}

struct EnhancedStatRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    private let theme = TrashTheme()

    var body: some View {
        HStack(spacing: theme.spacing.md) {
            TrashIcon(systemName: icon)
                .font(theme.typography.subheadline)
                .trashOnAccentForeground()
                .frame(width: theme.spacing.xl, height: theme.spacing.xl)
                .background(color)
                .cornerRadius(theme.corners.small)

            Text(title)
                .font(theme.typography.body)
                .foregroundColor(theme.palette.textSecondary)

            Spacer()

            Text(value)
                .font(theme.typography.headline)
                .fontWeight(.bold)
                .foregroundColor(theme.palette.textPrimary)
        }
    }
}

// Backward compatibility wrappers
struct AnonymousRestrictionView: View {
    var body: some View {
        EnhancedAnonymousRestrictionView()
    }
}

private struct ArenaEmptyStateView: View {
    var onRefresh: () -> Void
    var body: some View {
        EnhancedEmptyStateView(onRefresh: onRefresh)
    }
}

struct QuizCard: View {
    let question: QuizQuestion
    let image: UIImage?
    let categories: [String]
    let showCorrect: Bool
    let showWrong: Bool
    let isSubmitting: Bool
    let pointsText: String
    let onAnswer: (String) -> Void

    var body: some View {
        EnhancedQuizCard(
            question: question,
            image: image,
            imageFailed: false,
            correctAnswer: nil,
            categories: categories,
            showCorrect: showCorrect,
            showWrong: showWrong,
            isSubmitting: isSubmitting,
            pointsText: pointsText,
            onRetryImage: nil,
            onAnswer: onAnswer
        )
    }
}

struct CorrectFeedbackOverlay: View {
    let pointsText: String
    var body: some View {
        EnhancedCorrectFeedback(pointsText: pointsText)
    }
}

struct WrongFeedbackOverlay: View {
    let correctAnswer: String
    var body: some View {
        EnhancedWrongFeedback(correctAnswer: correctAnswer)
    }
}

struct ComboOverlay: View {
    let comboCount: Int
    var body: some View {
        EnhancedComboOverlay(comboCount: comboCount)
    }
}

struct ComboBreakOverlay: View {
    var body: some View {
        EnhancedComboBreakOverlay()
    }
}

struct SessionSummaryView: View {
    @ObservedObject var viewModel: ArenaViewModel
    var body: some View {
        EnhancedSessionSummaryView(viewModel: viewModel)
    }
}

struct StatRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        EnhancedStatRow(icon: icon, title: title, value: value, color: color)
    }
}

//
//  VerifyView.swift
//  Smart Sort
//
//  Created by Albert Huang on 2/4/26.
//

import SwiftUI

struct VerifyView: View {
    @EnvironmentObject var viewModel: TrashViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var cameraManager = CameraManager()
    private let theme = TrashTheme()

    // UI State
    @State private var cardOffset: CGSize = .zero
    @State private var showingFeedbackForm = false
    @State private var isCameraActive = false
    @State private var isTorchOn = false
    @State private var pulseAnimation = false
    // showAccountSheet is managed by ContentView via environment

    // Form Data
    @State private var feedbackItemName = ""
    @State private var isSubmittingFeedback = false
    @State private var swipeSuccessTrigger = false
    @State private var swipeWarningTrigger = false

    var showFeedbackForm: Bool {
        if case .collectingFeedback = viewModel.appState, showingFeedbackForm { return true }
        return false
    }

    var isPreviewState: Bool {
        cameraManager.capturedImage == nil && viewModel.appState == .idle
    }

    private var isEcoCameraCaptureMode: Bool {
        isCameraActive && isPreviewState && !showFeedbackForm
    }

    var body: some View {
        ZStack {
            ThemeBackgroundView()

            VStack(spacing: 0) {
                aiStatusIndicator

                cameraArea

                interactionArea

                Spacer(minLength: 10)

                mainActionButton
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .clipped()

            if viewModel.appState == .analyzing {
                analyzingOverlay
            }
        }
        .navigationTitle("Verify")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                AccountButton()
            }
        }
        .onAppear {
            if isCameraActive && cameraManager.capturedImage == nil {
                cameraManager.start()
            }
        }
        .onDisappear {
            isTorchOn = false
            cameraManager.stop()
        }
        .onReceive(cameraManager.$capturedImage) { img in
            if let img = img, viewModel.appState == .idle {
                viewModel.analyzeImage(image: img)
            }
        }
        .onReceive(cameraManager.$isTorchOn) { isOn in
            isTorchOn = isOn
        }
        .compatibleSensoryFeedback(.success, trigger: swipeSuccessTrigger)
        .compatibleSensoryFeedback(.warning, trigger: swipeWarningTrigger)
    }

    private var aiStatusIndicator: some View {
        HStack {
            Spacer()
            HStack(spacing: 6) {
                Circle()
                    .fill(
                        RealClassifierService.shared.isReady ? theme.accents.green : Color.orange
                    )
                    .frame(width: 8, height: 8)
                    .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                    .shadow(
                        color: RealClassifierService.shared.isReady
                            ? theme.accents.green.opacity(0.6) : Color.orange.opacity(0.6),
                        radius: 4, x: 0, y: 0
                    )
                    .animation(
                        theme.animations.pulse,
                        value: pulseAnimation)
                Text(RealClassifierService.shared.isReady ? "Ready" : "Loading")
                    .font(.caption2)
                    .foregroundColor(theme.palette.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .trashCard(cornerRadius: 16)
            .onAppear { pulseAnimation = true }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var cameraArea: some View {
        GeometryReader { geo in
            ecoCameraArea(size: geo.size)
        }
        .frame(maxHeight: min(340, UIScreen.main.bounds.height * 0.4))
        .padding(.horizontal, theme.spacing.md)
        .padding(.top, theme.spacing.sm)
    }

    @ViewBuilder
    private func legacyCameraArea(size: CGSize) -> some View {
        ZStack {
            Color.clear
                .trashCard(cornerRadius: 28)

            if let image = cameraManager.capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width - 16, height: size.height - 16)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    .transition(.scale.combined(with: .opacity))
            } else if isCameraActive {
                CameraPreview(cameraManager: cameraManager)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .padding(8)
                    .overlay(
                        ScanLineOverlay()
                            .padding(8)
                    )
            } else {
                VStack(spacing: 20) {
                    paperIconCircle

                    VStack(spacing: 6) {
                        Text("Identify Trash")
                            .font(theme.typography.headline)
                            .foregroundColor(theme.palette.textPrimary)
                        Text("Point your camera at any item")
                            .font(theme.typography.caption)
                            .foregroundColor(theme.palette.textSecondary)
                    }
                }
            }
        }
    }

    private func ecoCameraArea(size: CGSize) -> some View {
        let outerRadius: CGFloat = 30
        let innerRadius: CGFloat = 24
        let inset: CGFloat = 18

        return ZStack {
            RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                .fill(theme.palette.card)
                .overlay(
                    RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                        .stroke(theme.palette.divider, lineWidth: 1)
                )
                .shadow(color: theme.shadows.dark.opacity(0.3), radius: 6, x: 0, y: 3)

            RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                .fill(Color.black.opacity(0.22))
                .padding(inset)
                .blendMode(.multiply)

            Group {
                if let image = cameraManager.capturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else if isCameraActive {
                    CameraPreview(cameraManager: cameraManager)
                        .overlay(ScanLineOverlay())
                } else {
                    VStack(spacing: 12) {
                        StampedIcon(
                            systemName: "camera.viewfinder",
                            size: 40,
                            weight: .semibold,
                            color: theme.palette.textPrimary.opacity(0.62)
                        )
                        Text("Cardboard Viewfinder")
                            .font(theme.typography.subheadline)
                            .foregroundColor(theme.palette.textPrimary.opacity(0.85))
                        Text("Point at an item to scan")
                            .font(theme.typography.caption)
                            .foregroundColor(theme.palette.textSecondary)
                    }
                    .padding(20)
                }
            }
            .frame(width: size.width - inset * 2, height: size.height - inset * 2)
            .clipShape(RoundedRectangle(cornerRadius: innerRadius, style: .continuous))

            RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                .stroke(theme.palette.divider.opacity(0.78), lineWidth: 1.8)
                .padding(inset)
                .shadow(color: Color.black.opacity(0.28), radius: 2, x: 0, y: 1)

            if isCameraActive {
                cameraOverlayControls
                    .padding(.horizontal, inset + 8)
                    .padding(.top, inset + 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }

    // MARK: - 🎨 Interaction Area
    private var interactionArea: some View {
        ZStack {
            if case .finished(let result) = viewModel.appState, !showingFeedbackForm {
                EnhancedSwipeableCard(result: result, offset: $cardOffset) { direction in
                    handleSwipe(direction: direction, result: result)
                }
                .transition(
                    .asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .opacity
                    ))
            }

            if case .error(let message) = viewModel.appState {
                ErrorCard(message: message) {
                    finishFlowAndReset(closeCamera: false)
                    cameraManager.start()
                }
                .transition(.scale.combined(with: .opacity))
            }

            if showFeedbackForm {
                EnhancedFeedbackForm(itemName: $feedbackItemName)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(height: isEcoCameraCaptureMode ? 84 : 170)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.appState)
    }

    // MARK: - 🎨 Main Action Button
    private var mainActionButton: some View {
        Group {
            if isEcoCameraCaptureMode {
                Button(action: handleMainButtonTap) {
                    ZStack {
                        Circle()
                            .fill(theme.accents.green.opacity(0.7))
                            .frame(width: 86, height: 86)
                            .offset(y: 3)

                        Circle()
                            .fill(theme.accents.green)
                            .frame(width: 88, height: 88)
                            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 3)

                        StampedIcon(
                            systemName: "camera.fill",
                            size: 24,
                            weight: .bold,
                            color: theme.onAccentForeground
                        )
                    }
                }
                .buttonStyle(.plain)
            } else {
                TrashButton(
                    baseColor: showFeedbackForm ? theme.accents.green : theme.accents.blue,
                    cornerRadius: 27,
                    action: handleMainButtonTap
                ) {
                    HStack(spacing: 12) {
                        TrashIcon(systemName: buttonIcon)
                            .font(.system(size: 18, weight: .semibold))
                        Text(buttonText)
                            .font(.system(size: 17, weight: .bold))
                    }
                    .trashOnAccentForeground()
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                }
                .padding(.horizontal, 24)
            }
        }
        .padding(.bottom, 8)
        .disabled(viewModel.appState == .analyzing || isSubmittingFeedback)
    }

    // MARK: - 🎨 Analyzing Overlay
    private var analyzingOverlay: some View {
        ZStack {
            Color.black.opacity(0.15)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // 🎨 动态加载动画
                ZStack {
                    paperIconCircle
                        .frame(width: 100, height: 100)
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(
                            theme.gradients.primary,
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(pulseAnimation ? 360 : 0))
                        .animation(
                            .linear(duration: 1).repeatForever(autoreverses: false),
                            value: pulseAnimation)

                    TrashIcon(systemName: "brain")
                        .font(.system(size: 30))
                        .foregroundColor(theme.accents.blue)
                }

                Text("Analyzing...")
                    .font(theme.typography.headline)
                    .foregroundColor(theme.palette.textPrimary)

                Text("AI is identifying the item")
                    .font(theme.typography.caption)
                    .foregroundColor(theme.palette.textSecondary)
            }
            .padding(40)
            .trashCard(cornerRadius: 30)
        }
        .transition(.opacity)
    }

    // MARK: - Button State
    private var cameraOverlayControls: some View {
        HStack {
            stampedOverlayButton(systemName: "xmark") {
                finishFlowAndReset(closeCamera: true)
            }

            Spacer()

            stampedOverlayButton(systemName: isTorchOn ? "bolt.fill" : "bolt.slash.fill") {
                cameraManager.setTorch(enabled: !isTorchOn)
            }
        }
    }

    private func stampedOverlayButton(systemName: String, action: @escaping () -> Void) -> some View
    {
        Button(action: action) {
            StampedIcon(
                systemName: systemName,
                size: 17,
                weight: .bold,
                color: theme.onAccentForeground.opacity(0.94)
            )
            .padding(8)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    private var buttonIcon: String {
        if showFeedbackForm { return "paperplane.fill" }
        if isCameraActive && !isPreviewState { return "arrow.clockwise" }
        return isCameraActive ? "camera.shutter.button.fill" : "camera.fill"
    }

    private var buttonText: String {
        if showFeedbackForm { return "Submit Correction" }
        if isCameraActive && !isPreviewState { return "Retake Photo" }
        return isCameraActive ? "Capture & Identify" : "Open Camera"
    }

    // MARK: - Handlers
    private func handleSwipe(direction: SwipeDirection, result: TrashAnalysisResult) {
        if direction == .right {
            swipeSuccessTrigger.toggle()
            viewModel.handleCorrectFeedback()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                cardOffset.width = 500
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                finishFlowAndReset(closeCamera: true)
            }
        } else {
            swipeWarningTrigger.toggle()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                cardOffset.width = -500
            }
            viewModel.prepareForIncorrectFeedback(wrongResult: result)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    self.showingFeedbackForm = true
                    self.cardOffset = .zero
                }
            }
        }
    }

    private func handleMainButtonTap() {
        if showFeedbackForm {
            submitFeedback()
        } else if !isCameraActive {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isCameraActive = true
            }
            cameraManager.start()
        } else if isPreviewState {
            cameraManager.takePhoto()
        } else {
            finishFlowAndReset(closeCamera: false)
            cameraManager.start()
        }
    }

    private func submitFeedback() {
        guard !isSubmittingFeedback else { return }
        guard case .collectingFeedback(let originalResult) = viewModel.appState,
            let currentImage = cameraManager.capturedImage
        else { return }
        isSubmittingFeedback = true
        Task {
            await viewModel.submitCorrection(
                image: currentImage,
                originalResult: originalResult,
                correctedName: feedbackItemName
            )
            isSubmittingFeedback = false
            if viewModel.appState == .idle {
                finishFlowAndReset(closeCamera: true)
            } else if case .error = viewModel.appState {
                withAnimation {
                    showingFeedbackForm = false
                    cardOffset = .zero
                }
            }
        }
    }

    private func finishFlowAndReset(closeCamera: Bool = true) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showingFeedbackForm = false
            cardOffset = .zero
            feedbackItemName = ""
            if closeCamera {
                isCameraActive = false
            }
        }

        if closeCamera {
            isTorchOn = false
            cameraManager.setTorch(enabled: false)
            cameraManager.stop()
        }

        viewModel.reset()
        cameraManager.reset()
    }
}

// MARK: - Helpers
extension VerifyView {
    private var paperIconCircle: some View {
        ZStack {
            Circle()
                .frame(width: 100, height: 100)
                .trashCard(cornerRadius: 50)

            TrashIcon(systemName: "camera.viewfinder")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(theme.palette.textSecondary)
        }
    }
}

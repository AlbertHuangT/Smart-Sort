//
//  VerifyComponents.swift
//  The Trash
//
//  Extracted from VerifyView.swift
//

import SwiftUI

// MARK: - Swipe Direction

enum SwipeDirection {
    case left
    case right
}

// MARK: - Scan Line Overlay

struct ScanLineOverlay: View {
    @State private var offset: CGFloat = -200

    var body: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, .neuAccentBlue.opacity(0.3), .cyan.opacity(0.5), .neuAccentBlue.opacity(0.3), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 3)
                .offset(y: offset)
                .onAppear {
                    withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                        offset = geo.size.height + 200
                    }
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }
}

// MARK: - Enhanced Swipeable Card

struct EnhancedSwipeableCard: View {
    let result: TrashAnalysisResult
    @Binding var offset: CGSize
    var onSwiped: (SwipeDirection) -> Void

    var body: some View {
        EnhancedResultCard(result: result)
            .background(Color.neuBackground)
            // Neumorphic Shadow (Extruded)
            .cornerRadius(20)
            .shadow(color: .neuDarkShadow, radius: 10, x: 8, y: 8)
            .shadow(color: .neuLightShadow, radius: 10, x: -5, y: -5)
            .overlay(
                ZStack {
                    if offset.width > 0 {
                        EnhancedCorrectOverlay()
                            .opacity(Double(offset.width / 150))
                    } else if offset.width < 0 {
                        EnhancedIncorrectOverlay()
                            .opacity(Double(-offset.width / 150))
                    }
                }
                .allowsHitTesting(false)
                .clipShape(RoundedRectangle(cornerRadius: 20))
            )
            .offset(x: offset.width)
            .rotationEffect(.degrees(Double(offset.width / 20)))
            .padding(.horizontal, 16)
            .gesture(DragGesture()
                .onChanged { gesture in
                    offset = gesture.translation
                }
                .onEnded { gesture in
                    if gesture.translation.width < -100 { onSwiped(.left) }
                    else if gesture.translation.width > 100 { onSwiped(.right) }
                    else { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { offset = .zero } }
                }
            )
    }
}

// MARK: - Enhanced Result Card

struct EnhancedResultCard: View {
    let result: TrashAnalysisResult

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                // Determine icon color based on result or palette?
                // Using result.color but adapting background
                Circle()
                    // Neumorphic Concave for Icon Background? Or just flat?
                    // Let's do a soft concave recess
                    .fill(Color.neuBackground)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle()
                            .stroke(Color.neuBackground, lineWidth: 2)
                            .shadow(color: .neuDarkShadow, radius: 3, x: 3, y: 3)
                            .clipShape(Circle())
                            .shadow(color: .neuLightShadow, radius: 3, x: -3, y: -3)
                            .clipShape(Circle())
                    )

                Image(systemName: iconForCategory(result.category))
                    .font(.system(size: 26))
                    .foregroundColor(result.color)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(result.category)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(result.color)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        // Soft pill background (flat or pressed)
                        .background(
                            Capsule().fill(result.color.opacity(0.1))
                        )

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "brain.head.profile")
                            .font(.caption2)
                        Text("\(Int(result.confidence * 100))%")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(.neuSecondaryText)
                }

                Text(result.itemName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.neuText)

                Text(result.actionTip)
                    .font(.caption)
                    .foregroundColor(.neuSecondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(minHeight: 150)
        // Background handles broadly by parent for shadow purposes
    }

    private func iconForCategory(_ category: String) -> String {
        switch category {
        case _ where category.contains("Recycl") || category.contains("Blue"): return "arrow.3.trianglepath"
        case _ where category.contains("Compost") || category.contains("Green"): return "leaf.fill"
        case _ where category.contains("Hazard"): return "exclamationmark.triangle.fill"
        case _ where category.contains("Electronic"): return "bolt.fill"
        default: return "trash.fill"
        }
    }
}

// MARK: - Correct Overlay

struct EnhancedCorrectOverlay: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [.neuAccentGreen.opacity(0.9), .mint.opacity(0.9)], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                Text("Correct!")
                    .font(.headline.bold())
                Text("Swipe right to confirm")
                    .font(.caption2)
                    .opacity(0.8)
            }
            .foregroundColor(.white)
        }
    }
}

// MARK: - Incorrect Overlay

struct EnhancedIncorrectOverlay: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [.red.opacity(0.9), .orange.opacity(0.9)], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 8) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 44))
                Text("Incorrect?")
                    .font(.headline.bold())
                Text("Swipe left to correct")
                    .font(.caption2)
                    .opacity(0.8)
            }
            .foregroundColor(.white)
        }
    }
}

// MARK: - Error Card

struct ErrorCard: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(
                    LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom)
                )

            Text("Something went wrong")
                .font(.headline)
                .foregroundColor(.neuText)

            Text(message)
                .font(.caption)
                .foregroundColor(.neuSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: onRetry) {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.neuAccentBlue)
                    .cornerRadius(20)
                    .shadow(color: .neuAccentBlue.opacity(0.4), radius: 5, x: 0, y: 3)
            }
        }
        .padding(24)
        .background(Color.neuBackground)
        .cornerRadius(20)
        .shadow(color: .neuDarkShadow, radius: 10, x: 5, y: 5)
        .shadow(color: .neuLightShadow, radius: 10, x: -5, y: -5)
        .padding(.horizontal, 16)
    }
}

// MARK: - Enhanced Feedback Form

struct EnhancedFeedbackForm: View {
    @Binding var itemName: String

    var body: some View {
        VStack(spacing: 16) {
            Text("What is this item?")
                .font(.subheadline.bold())
                .foregroundColor(.neuSecondaryText)

            HStack {
                Image(systemName: "tag.fill")
                    .foregroundColor(.neuSecondaryText)
                TextField("e.g. Plastic bottle, Battery...", text: $itemName)
                    .foregroundColor(.neuText)
            }
            .padding(12)
            // Neumorphic Concave (Input field)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.neuBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.neuBackground, lineWidth: 2)
                            .shadow(color: .neuDarkShadow, radius: 3, x: 3, y: 3)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .neuLightShadow, radius: 3, x: -3, y: -3)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    )
            )
        }
        .padding(20)
        .background(Color.neuBackground)
        .cornerRadius(20)
        .shadow(color: .neuDarkShadow, radius: 10, x: 5, y: 5)
        .shadow(color: .neuLightShadow, radius: 10, x: -5, y: -5)
        .padding(.horizontal, 16)
    }
}

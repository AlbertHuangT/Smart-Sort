//
//  AccountComponents.swift
//  The Trash
//
//  Extracted from AccountView.swift
//

import SwiftUI

// MARK: - Enhanced Stat Card (Neumorphic)
struct EnhancedStatCard: View {
    let title: String
    let value: String
    let icon: String
    let gradient: [Color]

    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                    .shadow(color: gradient[0].opacity(0.4), radius: 6, y: 2)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3.bold())
                    .foregroundColor(.neuText)
                    .frame(minWidth: 50, alignment: .leading)
                    .animation(.none, value: value)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.neuSecondaryText)
            }

            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .frame(height: 72)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.neuBackground)
                .shadow(color: .neuDarkShadow, radius: 6, x: 4, y: 4)
                .shadow(color: .neuLightShadow, radius: 6, x: -3, y: -3)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Enhanced Account Row (Neumorphic)
struct EnhancedAccountRow: View {
    let icon: String
    let gradient: [Color]
    let title: String
    let status: String
    let isLinked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                        .shadow(color: gradient[0].opacity(0.3), radius: 4, y: 2)

                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }

                Text(title)
                    .font(.body)
                    .foregroundColor(.neuText)

                Spacer()

                HStack(spacing: 6) {
                    if isLinked {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.neuAccentGreen)
                    }

                    Text(status)
                        .font(.caption.bold())
                        .foregroundColor(isLinked ? .neuAccentGreen : .neuAccentBlue)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .neumorphicConcave(cornerRadius: 10)

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundColor(.neuSecondaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Enhanced Settings Row (Neumorphic)
struct EnhancedSettingsRow: View {
    let icon: String
    let gradient: [Color]
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                    .shadow(color: gradient[0].opacity(0.3), radius: 4, y: 2)

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }

            Text(title)
                .font(.body)
                .foregroundColor(.neuText)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundColor(.neuSecondaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

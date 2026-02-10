//
//  AchievementToastView.swift
//  The Trash
//
//  成就解锁浮动通知
//

import SwiftUI

struct AchievementToastView: View {
    let result: AchievementGrantResult
    let onDismiss: () -> Void

    @State private var isVisible = false

    var rarity: AchievementRarity {
        result.rarity ?? .common
    }

    var body: some View {
        VStack {
            if isVisible {
                HStack(spacing: 14) {
                    // 成就图标
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: rarity.gradient,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)

                        Image(systemName: result.iconName ?? "trophy.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("🎉 Achievement Unlocked!")
                            .font(.caption.bold())
                            .foregroundColor(.neuSecondaryText)

                        Text(result.name ?? "Unknown")
                            .font(.subheadline.bold())
                            .foregroundColor(.neuText)

                        Text(rarity.displayName)
                            .font(.caption2.bold())
                            .foregroundColor(rarity.color)
                    }

                    Spacer()

                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            isVisible = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onDismiss()
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.neuSecondaryText)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.neuBackground)
                        .shadow(color: .neuDarkShadow, radius: 8, x: 5, y: 5)
                        .shadow(color: .neuLightShadow, radius: 8, x: -4, y: -4)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: rarity.gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .padding(.horizontal, 20)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                isVisible = true
            }
            // 3秒后自动消失
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation(.spring(response: 0.3)) {
                    isVisible = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onDismiss()
                }
            }
        }
    }
}

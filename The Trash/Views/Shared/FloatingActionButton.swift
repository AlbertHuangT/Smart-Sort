//
//  FloatingActionButton.swift
//  The Trash
//
//  Extracted from CommunityTabView.swift
//

import SwiftUI

struct FloatingActionButton: View {
    let icon: String
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            action()
        }) {
            ZStack {
                Circle()
                    .fill(Color.neuAccentBlue)
                    .frame(width: 60, height: 60)
                    .shadow(color: .neuAccentBlue.opacity(0.4), radius: 10, x: 5, y: 5)
                    .shadow(color: .neuLightShadow, radius: 6, x: -3, y: -3)

                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
    }
}

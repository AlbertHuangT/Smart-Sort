//
//  AccountButton.swift
//  The Trash
//
//  Extracted from AccountView.swift
//

import SwiftUI

// MARK: - Account Button (App Store Style with Depth Effect)
struct AccountButton: View {
    @Binding var showAccountSheet: Bool
    @EnvironmentObject var authVM: AuthViewModel

    var body: some View {
        Button {
            showAccountSheet = true
        } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
                    .blur(radius: 4)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 45, height: 45)
                    .shadow(color: .purple.opacity(0.4), radius: 8, x: 0, y: 4)

                Image(systemName: authVM.isAnonymous ? "person.fill" : "person.crop.circle.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .sheet(isPresented: $showAccountSheet) {
            AccountView()
                .environmentObject(authVM)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(32)
                .presentationBackground(.regularMaterial)
                .presentationBackgroundInteraction(.enabled(upThrough: .large))
        }
    }
}

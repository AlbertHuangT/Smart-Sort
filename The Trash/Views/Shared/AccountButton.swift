//
//  AccountButton.swift
//  The Trash
//
//  Extracted from AccountView.swift
//

import SwiftUI

// MARK: - Account Button (Neumorphic Style)
struct AccountButton: View {
    @Binding var showAccountSheet: Bool
    @EnvironmentObject var authVM: AuthViewModel

    var body: some View {
        Button {
            showAccountSheet = true
        } label: {
            ZStack {
                Circle()
                    .fill(Color.neuBackground)
                    .frame(width: 45, height: 45)
                    .shadow(color: .neuDarkShadow, radius: 5, x: 4, y: 4)
                    .shadow(color: .neuLightShadow, radius: 5, x: -3, y: -3)

                Image(systemName: authVM.isAnonymous ? "person.fill" : "person.crop.circle.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.neuAccentBlue)
            }
        }
        .sheet(isPresented: $showAccountSheet) {
            AccountView()
                .environmentObject(authVM)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(32)
                .presentationBackground(Color.neuBackground)
                .presentationBackgroundInteraction(.enabled(upThrough: .large))
        }
    }
}

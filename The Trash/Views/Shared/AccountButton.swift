//
//  AccountButton.swift
//  The Trash
//
//  Extracted from AccountView.swift
//

import SwiftUI

// MARK: - Environment Key for shared account sheet state
private struct AccountSheetKey: EnvironmentKey {
    static let defaultValue: Binding<Bool> = .constant(false)
}

extension EnvironmentValues {
    var showAccountSheet: Binding<Bool> {
        get { self[AccountSheetKey.self] }
        set { self[AccountSheetKey.self] = newValue }
    }
}

// MARK: - Account Button (Neumorphic Style)
struct AccountButton: View {
    @Environment(\.showAccountSheet) private var showAccountSheet
    @EnvironmentObject var authVM: AuthViewModel

    var body: some View {
        Button {
            showAccountSheet.wrappedValue = true
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
    }
}

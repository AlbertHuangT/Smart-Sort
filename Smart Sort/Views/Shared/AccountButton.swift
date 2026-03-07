//
//  AccountButton.swift
//  Smart Sort
//

import SwiftUI

extension Notification.Name {
    static let showAccountSheet = Notification.Name("showAccountSheet")
}

struct AccountButton: View {
    @EnvironmentObject var authVM: AuthViewModel

    var body: some View {
        Button {
            NotificationCenter.default.post(name: .showAccountSheet, object: nil)
        } label: {
            Image(systemName: authVM.isAnonymous ? "person.fill" : "person.crop.circle")
                .font(.title3)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Account")
    }
}

//
//  BindEmailSheet.swift
//  Smart Sort
//
//  Extracted from AccountView.swift
//

import SwiftUI

struct BindEmailSheet: View {
    @Binding var inputEmail: String
    @ObservedObject var authVM: AuthViewModel
    @Binding var isPresented: Bool
    private let theme = TrashTheme()

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TrashFormTextField(
                        title: "Email",
                        text: $inputEmail,
                        keyboardType: .emailAddress
                    )
                    TrashTextButton(title: "Send Link", variant: .accent) {
                        Task {
                            await authVM.updateEmail(email: inputEmail)
                            if authVM.errorMessage == nil && authVM.showCheckEmailAlert {
                                isPresented = false
                            }
                        }
                    }
                }

                if let error = authVM.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(theme.semanticDanger)
                            .font(theme.typography.caption)
                    }
                }
            }
            .navigationTitle("Bind Email")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    TrashTextButton(title: "Cancel") {
                        authVM.errorMessage = nil
                        isPresented = false
                    }
                }
            }
        }
    }
}

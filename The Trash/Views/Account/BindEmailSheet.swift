//
//  BindEmailSheet.swift
//  The Trash
//
//  Extracted from AccountView.swift
//

import SwiftUI

struct BindEmailSheet: View {
    @Binding var inputEmail: String
    @ObservedObject var authVM: AuthViewModel
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Email", text: $inputEmail).keyboardType(.emailAddress).autocapitalization(.none)
                    Button("Send Link") {
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
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Bind Email")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        authVM.errorMessage = nil
                        isPresented = false
                    }
                }
            }
        }
    }
}

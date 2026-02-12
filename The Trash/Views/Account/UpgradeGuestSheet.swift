//
//  UpgradeGuestSheet.swift
//  The Trash
//

import SwiftUI

struct UpgradeGuestSheet: View {
    @ObservedObject var authVM: AuthViewModel
    @Binding var email: String
    @Binding var password: String
    @Binding var confirmPassword: String
    @Binding var isPresented: Bool
    @State private var localError: String?

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Email")) {
                    TextField("you@example.com", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }

                Section(header: Text("Password")) {
                    SecureField("Password (min 6 characters)", text: $password)
                    SecureField("Confirm Password", text: $confirmPassword)
                }

                Section {
                    Button {
                        Task { await upgradeGuest() }
                    } label: {
                        if authVM.isLoading {
                            HStack {
                                ProgressView()
                                Text("Upgrading…")
                            }
                        } else {
                            Text("Create Account")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(authVM.isLoading)
                }

                if let message = localError ?? authVM.errorMessage {
                    Section {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Link Your Account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        resetState()
                        isPresented = false
                    }
                }
            }
        }
    }

    private func upgradeGuest() async {
        localError = nil

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedEmail.isEmpty else {
            localError = "Please enter an email address."
            return
        }

        guard password.count >= 6 else {
            localError = "Password must be at least 6 characters."
            return
        }

        guard password == confirmPassword else {
            localError = "Passwords do not match."
            return
        }

        await authVM.upgradeGuestAccount(email: trimmedEmail, password: password)

        if authVM.errorMessage == nil {
            resetState()
            isPresented = false
        }
    }

    private func resetState() {
        localError = nil
        authVM.errorMessage = nil
        email = ""
        password = ""
        confirmPassword = ""
    }
}

//
//  LoginView.swift
//  Smart Sort
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authVM: AuthViewModel

    @State private var loginMethod = 0
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var phoneNumber = "+1"
    @State private var otpCode = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Smart Sort")
                            .font(.largeTitle.bold())
                        Text("Use the camera, earn points, and join community challenges.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)

                Section {
                    Picker("Login Method", selection: $loginMethod) {
                        Text("Email").tag(0)
                        Text("Phone").tag(1)
                    }
                    .pickerStyle(.segmented)

                    if let error = authVM.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                if loginMethod == 0 {
                    emailSection
                } else {
                    phoneSection
                }

                Section {
                    Button("Continue as Guest") {
                        Task { await authVM.signInAnonymously() }
                    }
                    .disabled(authVM.isLoading)
                }
            }
            .navigationBarHidden(true)
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(ThemeBackgroundView())
            .alert("Check your email", isPresented: $authVM.showCheckEmailAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("We sent a verification link to your email address.")
            }
        }
    }

    private var emailSection: some View {
        Section(isSignUp ? "Create Account" : "Sign In") {
            TextField("Email", text: $email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()

            SecureField("Password", text: $password)

            Button {
                Task {
                    if isSignUp {
                        await authVM.signUp(email: email, password: password)
                    } else {
                        await authVM.signIn(email: email, password: password)
                    }
                }
            } label: {
                if authVM.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text(isSignUp ? "Create Account" : "Sign In")
                        .frame(maxWidth: .infinity)
                }
            }
            .disabled(authVM.isLoading || email.isEmpty || password.isEmpty)

            Button(isSignUp ? "Already have an account? Sign In" : "Need an account? Sign Up") {
                isSignUp.toggle()
            }
        }
    }

    private var phoneSection: some View {
        Section {
            if authVM.showOTPInput {
                Text(phoneNumber)
                    .foregroundStyle(.secondary)

                TextField("6-digit code", text: $otpCode)
                    .keyboardType(.numberPad)

                Button {
                    Task {
                        await authVM.verifyOTP(phone: phoneNumber, token: otpCode)
                        if authVM.session != nil {
                            otpCode = ""
                        }
                    }
                } label: {
                    if authVM.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Verify and Continue")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(authVM.isLoading || otpCode.isEmpty)

                Button("Use a different number", role: .cancel) {
                    authVM.showOTPInput = false
                    authVM.errorMessage = nil
                    otpCode = ""
                }
            } else {
                TextField("Phone number", text: $phoneNumber)
                    .keyboardType(.phonePad)

                Button {
                    Task { await authVM.sendOTP(phone: phoneNumber) }
                } label: {
                    if authVM.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Send Verification Code")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(authVM.isLoading || phoneNumber.isEmpty)
            }
        } header: {
            Text(authVM.showOTPInput ? "Verify Phone" : "Phone Login")
        } footer: {
            Text("Phone auth supports both sign in and sign up.")
        }
    }
}

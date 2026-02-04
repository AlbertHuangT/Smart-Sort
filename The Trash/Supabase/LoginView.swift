//
//  LoginView.swift
//  The Trash
//
//  Created by Albert Huang on 2/3/26.
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
    
    // Logo animation state
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // 1. Background layer: Dynamic gradient
            LinearGradient(
                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .overlay(Color(.systemBackground).opacity(0.2)) // Blend system background for dark mode compatibility
            
            // 2. Content layer
            ScrollView {
                VStack(spacing: 30) {
                    
                    // --- Top Logo ---
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color(.secondarySystemGroupedBackground))
                                .frame(width: 120, height: 120)
                                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                            
                            Image(systemName: "trash.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 100, height: 100)
                                .foregroundColor(.blue)
                                .scaleEffect(isAnimating ? 1.05 : 1.0)
                                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isAnimating)
                        }
                        
                        Text("The Trash")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    .padding(.top, 60)
                    .onAppear { isAnimating = true }
                    
                    // --- Main Card Area ---
                    VStack(spacing: 25) {
                        // Segment Control
                        Picker("Method", selection: $loginMethod) {
                            Text("Email").tag(0)
                            Text("Phone").tag(1)
                        }
                        .pickerStyle(.segmented)
                        
                        // Error Message
                        if let error = authVM.errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text(error)
                                    .font(.caption)
                                    .multilineTextAlignment(.leading)
                            }
                            .foregroundColor(.red)
                            .padding(10)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                            .transition(.opacity)
                        }
                        
                        // Forms
                        Group {
                            if loginMethod == 0 {
                                emailFormContent
                            } else {
                                phoneFormContent
                            }
                        }
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                    .padding(30)
                    .background(.regularMaterial) // iOS frosted glass effect, adapts to dark/light mode
                    .cornerRadius(24)
                    .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
                    .padding(.horizontal)
                    
                    // --- Guest Access Button ---
                    Button(action: {
                        Task { await authVM.signInAnonymously() }
                    }) {
                        HStack {
                            Image(systemName: "person.and.arrow.left.and.arrow.right")
                            Text("Continue as Guest")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(14)
                    }
                    .padding(.horizontal)
                    .padding(.top, -10)
                    
                    Spacer()
                }
            }
        }
        .animation(.spring(), value: loginMethod)
        .animation(.easeInOut, value: authVM.showOTPInput)
    }
    
    // MARK: - Email Form
    var emailFormContent: some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                // Fixed: CustomTextField is now defined below
                CustomTextField(
                    icon: "envelope.fill",
                    placeholder: "Email Address",
                    text: $email,
                    keyboardType: .emailAddress
                )
                
                CustomTextField(
                    icon: "lock.fill",
                    placeholder: "Password",
                    text: $password,
                    isSecure: true
                )
            }
            
            if authVM.isLoading {
                ProgressView().padding()
            } else {
                Button(action: {
                    Task {
                        if isSignUp {
                            await authVM.signUp(email: email, password: password)
                        } else {
                            await authVM.signIn(email: email, password: password)
                        }
                    }
                }) {
                    Text(isSignUp ? "Sign Up" : "Login")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                }
            }
            
            Button(action: { withAnimation { isSignUp.toggle() } }) {
                HStack {
                    Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                        .foregroundColor(.secondary)
                    Text(isSignUp ? "Login Now" : "Sign Up Now")
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                .font(.footnote)
            }
        }
    }
    
    // MARK: - Phone Form
    var phoneFormContent: some View {
        VStack(spacing: 20) {
            if !authVM.showOTPInput {
                VStack(spacing: 8) {
                    CustomTextField(
                        icon: "phone.fill",
                        placeholder: "+1 555 000 1234",
                        text: $phoneNumber,
                        keyboardType: .phonePad
                    )
                    Text("Supports both Sign Up and Login")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 8)
                }
                
                if authVM.isLoading {
                    ProgressView().padding()
                } else {
                    Button(action: {
                        Task { await authVM.sendOTP(phone: phoneNumber) }
                    }) {
                        HStack {
                            Image(systemName: "paperplane.fill")
                            Text("Send OTP")
                        }
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                        .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                }
            } else {
                VStack(spacing: 16) {
                    Text("OTP has been sent to")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(phoneNumber)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    CustomTextField(
                        icon: "key.fill",
                        placeholder: "6-digit OTP Code",
                        text: $otpCode,
                        keyboardType: .numberPad
                    )
                    
                    if authVM.isLoading {
                        ProgressView().padding()
                    } else {
                        Button(action: {
                            Task { await authVM.verifyOTP(phone: phoneNumber, token: otpCode) }
                        }) {
                            Text("Verify and Login")
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(14)
                        }
                    }
                    
                    Button("Wrong number?") {
                        withAnimation {
                            authVM.showOTPInput = false
                            otpCode = ""
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
            }
        }
    }
}

// MARK: - Reusable Custom TextField
// This was missing in the previous version!
struct CustomTextField: View {
    var icon: String
    var placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .autocapitalization(.none)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

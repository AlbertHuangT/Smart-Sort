//
//  LoginView.swift
//  The Trash
//
//  Created by Albert Huang on 2/3/26.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    
    var body: some View {
        VStack(spacing: 25) {
            Image(systemName: "trash.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)
            
            Text(isSignUp ? "Create Account" : "Welcome Back")
                .font(.largeTitle)
                .bold()
            
            VStack(spacing: 15) {
                TextField("UCSD Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal)
            
            if let error = authVM.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            if authVM.isLoading {
                ProgressView()
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
                    Text(isSignUp ? "Sign Up" : "Log In")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            
            Button(action: { isSignUp.toggle() }) {
                Text(isSignUp ? "Already have an account? Log In" : "New here? Sign Up")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        // 🔥 新增：注册成功的弹窗提示
        .alert("Check your Inbox", isPresented: $authVM.showCheckEmailAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("We've sent a confirmation link to \(email). Please click it to verify your account.")
        }
    }
}

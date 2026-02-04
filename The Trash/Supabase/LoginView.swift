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
    
    // Logo 动画状态
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // 1. 背景层：动态渐变
            LinearGradient(
                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .overlay(Color(.systemBackground).opacity(0.2)) // 混合系统背景色以适配暗色模式
            
            // 2. 内容层
            ScrollView {
                VStack(spacing: 30) {
                    
                    // --- 顶部 Logo ---
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
                    
                    // --- 主卡片区域 ---
                    VStack(spacing: 25) {
                        // Segment Control
                        Picker("Method", selection: $loginMethod) {
                            Text("email address").tag(0)
                            Text("phone number").tag(1)
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
                    .background(.regularMaterial) // iOS 毛玻璃材质，完美适配暗色/浅色
                    .cornerRadius(24)
                    .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
                    .padding(.horizontal)
                    
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
                CustomTextField(
                    icon: "envelope.fill",
                    placeholder: "email address",
                    text: $email,
                    keyboardType: .emailAddress
                )
                
                CustomTextField(
                    icon: "lock.fill",
                    placeholder: "password",
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
                    Text(isSignUp ? "注册" : "登录")
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
                    Text(isSignUp ? "already has an account?" : "no account?")
                        .foregroundColor(.secondary)
                    Text(isSignUp ? "直接登录" : "立即注册")
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
                    Text("支持注册与登录")
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
                            Text("发送验证码")
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
                    Text("验证码已发送至")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(phoneNumber)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    CustomTextField(
                        icon: "key.fill",
                        placeholder: "6 位数字验证码",
                        text: $otpCode,
                        keyboardType: .numberPad
                    )
                    
                    if authVM.isLoading {
                        ProgressView().padding()
                    } else {
                        Button(action: {
                            Task { await authVM.verifyOTP(phone: phoneNumber, token: otpCode) }
                        }) {
                            Text("验证并登录")
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(14)
                        }
                    }
                    
                    Button("号码填错了?") {
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

// MARK: - Custom TextField (适配暗色模式)
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
        // 使用 secondarySystemBackground 确保在任何模式下都有区分度
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

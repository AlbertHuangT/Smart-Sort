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
    
    // Animation states
    @State private var isAnimating = false
    @State private var logoRotation: Double = 0
    @State private var showContent = false
    
    var body: some View {
        ZStack {
            // 🎨 动态渐变背景
            AnimatedGradientBackground()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // 🎨 Logo 区域
                    logoSection
                    
                    // 🎨 主卡片区域
                    mainCard
                    
                    // 🎨 访客入口
                    guestButton
                    
                    // 底部留白
                    Spacer().frame(height: 50)
                }
                .padding(.top, 60)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                showContent = true
            }
            isAnimating = true
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: loginMethod)
        .animation(.easeInOut(duration: 0.3), value: authVM.showOTPInput)
    }
    
    // MARK: - 🎨 Logo Section
    private var logoSection: some View {
        VStack(spacing: 16) {
            // 🎨 带光晕效果的 Logo
            ZStack {
                // 光晕效果
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.blue.opacity(0.3), .clear],
                            center: .center,
                            startRadius: 40,
                            endRadius: 100
                        )
                    )
                    .frame(width: 160, height: 160)
                    .scaleEffect(isAnimating ? 1.1 : 0.9)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isAnimating)
                
                // 主 Logo
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 110, height: 110)
                        .shadow(color: .blue.opacity(0.3), radius: 20, y: 10)
                    
                    Image(systemName: "leaf.arrow.triangle.circlepath")
                        .font(.system(size: 50, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .cyan, .green],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .rotationEffect(.degrees(logoRotation))
                        .onAppear {
                            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                                logoRotation = 360
                            }
                        }
                }
            }
            
            VStack(spacing: 8) {
                Text("The Trash")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.primary, .primary.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                Text("Smart Waste Sorting")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : -30)
    }
    
    // MARK: - 🎨 Main Card
    private var mainCard: some View {
        VStack(spacing: 24) {
            // 🎨 分段选择器
            Picker("Method", selection: $loginMethod) {
                HStack {
                    Image(systemName: "envelope.fill")
                    Text("Email")
                }.tag(0)
                HStack {
                    Image(systemName: "phone.fill")
                    Text("Phone")
                }.tag(1)
            }
            .pickerStyle(.segmented)
            
            // 错误信息
            if let error = authVM.errorMessage {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.primary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
                .transition(.scale.combined(with: .opacity))
            }
            
            // 表单内容
            if loginMethod == 0 {
                emailFormContent
            } else {
                phoneFormContent
            }
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 30, y: 15)
        )
        .padding(.horizontal, 20)
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 50)
    }
    
    // MARK: - 🎨 Guest Button
    private var guestButton: some View {
        Button(action: {
            Task { await authVM.signInAnonymously() }
        }) {
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.title3)
                Text("Continue as Guest")
                    .fontWeight(.medium)
            }
            .foregroundColor(.secondary)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground).opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .padding(.horizontal, 20)
        .opacity(showContent ? 1 : 0)
    }
    
    // MARK: - Email Form
    private var emailFormContent: some View {
        VStack(spacing: 20) {
            VStack(spacing: 14) {
                EnhancedTextField(
                    icon: "envelope.fill",
                    placeholder: "Email Address",
                    text: $email,
                    keyboardType: .emailAddress
                )
                
                EnhancedTextField(
                    icon: "lock.fill",
                    placeholder: "Password",
                    text: $password,
                    isSecure: true
                )
            }
            
            if authVM.isLoading {
                LoadingButton()
            } else {
                GradientButton(
                    title: isSignUp ? "Create Account" : "Sign In",
                    colors: [.blue, .cyan],
                    icon: isSignUp ? "person.badge.plus" : "arrow.right.circle.fill"
                ) {
                    Task {
                        if isSignUp {
                            await authVM.signUp(email: email, password: password)
                        } else {
                            await authVM.signIn(email: email, password: password)
                        }
                    }
                }
            }
            
            // 切换登录/注册
            Button(action: { withAnimation { isSignUp.toggle() } }) {
                HStack(spacing: 4) {
                    Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                        .foregroundColor(.secondary)
                    Text(isSignUp ? "Sign In" : "Sign Up")
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                .font(.subheadline)
            }
        }
    }
    
    // MARK: - Phone Form
    private var phoneFormContent: some View {
        VStack(spacing: 20) {
            if !authVM.showOTPInput {
                VStack(spacing: 12) {
                    EnhancedTextField(
                        icon: "phone.fill",
                        placeholder: "+1 555 000 1234",
                        text: $phoneNumber,
                        keyboardType: .phonePad
                    )
                    
                    Text("Works for both sign up and login")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                if authVM.isLoading {
                    LoadingButton()
                } else {
                    GradientButton(
                        title: "Send Verification Code",
                        colors: [.green, .mint],
                        icon: "paperplane.fill"
                    ) {
                        Task { await authVM.sendOTP(phone: phoneNumber) }
                    }
                }
            } else {
                // OTP 输入界面
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Image(systemName: "ellipsis.message.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(
                                LinearGradient(colors: [.green, .mint], startPoint: .top, endPoint: .bottom)
                            )
                        
                        Text("Verification Code Sent")
                            .font(.headline)
                        
                        Text(phoneNumber)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    EnhancedTextField(
                        icon: "key.fill",
                        placeholder: "Enter 6-digit code",
                        text: $otpCode,
                        keyboardType: .numberPad
                    )
                    
                    if authVM.isLoading {
                        LoadingButton()
                    } else {
                        GradientButton(
                            title: "Verify & Continue",
                            colors: [.blue, .purple],
                            icon: "checkmark.circle.fill"
                        ) {
                            Task {
                                await authVM.verifyOTP(phone: phoneNumber, token: otpCode)
                                if authVM.session != nil {
                                    otpCode = ""
                                }
                            }
                        }
                    }
                    
                    Button("Use a different number") {
                        withAnimation(.spring()) {
                            authVM.showOTPInput = false
                            authVM.errorMessage = nil
                            otpCode = ""
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.red)
                }
            }
        }
    }
}

// MARK: - 🎨 Animated Gradient Background
struct AnimatedGradientBackground: View {
    @State private var animateGradient = false
    
    var body: some View {
        LinearGradient(
            colors: [
                Color.blue.opacity(0.15),
                Color.cyan.opacity(0.1),
                Color.purple.opacity(0.1),
                Color.blue.opacity(0.15)
            ],
            startPoint: animateGradient ? .topLeading : .bottomLeading,
            endPoint: animateGradient ? .bottomTrailing : .topTrailing
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
        }
    }
}

// MARK: - 🎨 Enhanced TextField
struct EnhancedTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isFocused ? .blue : .secondary)
                .frame(width: 24)
            
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .autocapitalization(.none)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isFocused ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 2)
                )
        )
        .focused($isFocused)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

// MARK: - 🎨 Gradient Button
struct GradientButton: View {
    let title: String
    let colors: [Color]
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(title)
                    .fontWeight(.bold)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: colors.first?.opacity(0.4) ?? .blue.opacity(0.4), radius: 10, y: 5)
        }
    }
}

// MARK: - 🎨 Loading Button
struct LoadingButton: View {
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(.white)
            Text("Please wait...")
                .fontWeight(.medium)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.gray.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// Keep the old CustomTextField for backward compatibility
struct CustomTextField: View {
    var icon: String
    var placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    
    var body: some View {
        EnhancedTextField(
            icon: icon,
            placeholder: placeholder,
            text: $text,
            isSecure: isSecure,
            keyboardType: keyboardType
        )
    }
}

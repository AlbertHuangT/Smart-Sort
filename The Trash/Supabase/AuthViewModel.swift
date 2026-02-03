//
//  AuthViewModel.swift
//  The Trash
//
//  Created by Albert Huang on 2/3/26.
//

import SwiftUI
import Combine  // ✅ 修复 1: 必须显式导入 Combine，否则 @Published 和 ObservableObject 会报错
import Supabase
import Auth     // ✅ 修复 2: 必须显式导入 Auth，否则编译器找不到 Session.user.id

@MainActor
class AuthViewModel: ObservableObject {
    @Published var session: Session?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let client = SupabaseManager.shared.client
    
    init() {
        // 自动登录：监听 Session 变化
        Task {
            // 注意：client.auth.authStateChanges 是一个 AsyncSequence
            for await state in client.auth.authStateChanges {
                self.session = state.session
            }
        }
    }
    
    // 登录
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await client.auth.signIn(email: email, password: password)
        } catch {
            errorMessage = "Login failed: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    // 注册
    func signUp(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await client.auth.signUp(email: email, password: password)
        } catch {
            errorMessage = "Signup failed: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    // 登出
    func signOut() async {
        do {
            try await client.auth.signOut()
        } catch {
            print("Sign out error: \(error)")
        }
    }
}

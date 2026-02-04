//
//  AuthViewModel.swift
//  The Trash
//
//  Created by Albert Huang on 2/3/26.
//

import SwiftUI
import Combine
import Supabase
import Auth

// 1. 定义 Deep Link 的验证状态
enum AuthDeepLinkStatus: Equatable {
    case idle           // 空闲
    case verifying      // 正在验证
    case success        // 验证成功
    case failure(String)// 验证失败
}

@MainActor
class AuthViewModel: ObservableObject {
    @Published var session: Session?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // 2. 新增：控制 UI 显示的状态变量
    @Published var deepLinkStatus: AuthDeepLinkStatus = .idle
    @Published var showCheckEmailAlert = false // 注册成功后提示查收邮件
    
    private let client = SupabaseManager.shared.client
    
    init() {
        Task {
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
    
    // 注册 (优化版)
    func signUp(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await client.auth.signUp(email: email, password: password)
            // 3. 注册成功，设置标记以弹窗提示
            showCheckEmailAlert = true
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
    
    // 4. 新增：专门处理 Deep Link 的逻辑
    func handleIncomingURL(_ url: URL) async {
        // 设置状态为“正在验证”，UI 会显示转圈圈
        deepLinkStatus = .verifying
        
        do {
            // 把 Token 喂给 Supabase
            _ = try await client.auth.session(from: url)
            
            // 成功：显示绿勾提示
            deepLinkStatus = .success
            
            // 延迟 2 秒，让用户看清楚“验证成功”的提示，再消失
            try? await Task.sleep(nanoseconds: 2 * 1_000_000_000)
            
            // 重置状态 (此时 Session 应该已经更新，View 会自动切换到 ContentView)
            deepLinkStatus = .idle
            
        } catch {
            print("❌ Deep Link Error: \(error)")
            deepLinkStatus = .failure("Link invalid or expired: \(error.localizedDescription)")
        }
    }
}

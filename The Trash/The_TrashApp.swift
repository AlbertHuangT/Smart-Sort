//
//  The_TrashApp.swift
//  The Trash
//
//  Created by Albert Huang on 1/21/26.
//

import SwiftUI
import Supabase

@main
struct The_TrashApp: App {
    @StateObject private var authVM = AuthViewModel()
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authVM.session != nil {
                    ContentView()
                } else {
                    LoginView()
                }
            }
            .environmentObject(authVM)
            // 🔥 新增：监听 Deep Link
            .onOpenURL { url in
                print("🔗 收到 Deep Link: \(url)")
                Task {
                    do {
                        // 把 URL 里的 Token 喂给 Supabase，它会自动解析并登录
                        try await SupabaseManager.shared.client.auth.session(from: url)
                        print("✅ 验证成功，已自动登录！")
                    } catch {
                        print("❌ 验证失败: \(error)")
                    }
                }
            }
        }
    }
}

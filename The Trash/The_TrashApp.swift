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
            ZStack {
                // --- 1. 核心页面层 ---
                Group {
                    if authVM.session != nil {
                        ContentView()
                            .transition(.opacity) // 淡入淡出效果
                    } else {
                        LoginView()
                            .transition(.opacity)
                    }
                }
                
                // --- 2. 全局验证状态提示层 (Overlay) ---
                // 只有当状态不是 idle (空闲) 时才显示
                if authVM.deepLinkStatus != .idle {
                    DeepLinkOverlay(status: authVM.deepLinkStatus)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(100) // 确保永远在最上面
                }
            }
            .environmentObject(authVM)
            // 监听 URL
            .onOpenURL { url in
                print("🔗 Received Deep Link: \(url)")
                Task {
                    // 交给 ViewModel 处理，触发 Overlay 动画
                    await authVM.handleIncomingURL(url)
                }
            }
            // 加上动画，让提示框和页面切换更丝滑
            .animation(.easeInOut, value: authVM.session)
            .animation(.spring(), value: authVM.deepLinkStatus)
        }
    }
}

// --- 3. 提取出来的美观提示框组件 ---
struct DeepLinkOverlay: View {
    let status: AuthDeepLinkStatus
    
    var body: some View {
        VStack {
            HStack(spacing: 12) {
                switch status {
                case .verifying:
                    ProgressView()
                    Text("Verifying email...")
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                case .success:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                    Text("Verified! Logging you in...")
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                case .failure(let msg):
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.title2)
                    VStack(alignment: .leading) {
                        Text("Verification Failed")
                            .fontWeight(.bold)
                        Text(msg)
                            .font(.caption)
                            .lineLimit(2)
                    }
                    .foregroundColor(.primary)
                    
                case .idle:
                    EmptyView()
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(.ultraThinMaterial) // 毛玻璃背景
            .cornerRadius(30)
            .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
        }
        .frame(maxHeight: .infinity, alignment: .top) // 固定在屏幕顶部
        .padding(.top, 60) // 避开刘海区域
    }
}

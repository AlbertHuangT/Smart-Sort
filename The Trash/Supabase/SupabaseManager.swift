//
//  SupabaseManager.swift
//  The Trash
//
//  Created by Albert Huang on 2/3/26.
//


import Foundation
import Supabase

class SupabaseManager {
    static let shared = SupabaseManager()
    
    let client: SupabaseClient
    
    private init() {
        // ⚠️ 请确保这里是你自己的 Supabase URL 和 Key
        // (如果你之前已经填好了，请把那两行复制回来，不要用下面的示例占位符)
        let projectURL = URL(string: "https://nwhdqiaepwhxepcygsmm.supabase.co")!
        let apiKey = "sb_publishable_0ZwU2enz0hgtSYh72sVuwA_8ALK4tGd"
        
        // 🔥 修复：显式开启本地 Session 恢复，解决 AuthClient 警告
        let options = SupabaseClientOptions(
            auth: AuthClientOptions(emitLocalSessionAsInitialSession: true)
        )
        
        self.client = SupabaseClient(
            supabaseURL: projectURL,
            supabaseKey: apiKey,
            options: options
        )
    }
}

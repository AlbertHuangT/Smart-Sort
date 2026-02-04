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
        let projectURL = URL(string: "https://nwhdqiaepwhxepcygsmm.supabase.co")!
        let apiKey = "sb_publishable_0ZwU2enz0hgtSYh72sVuwA_8ALK4tGd"
        
        // 不需要显式设置 AuthClientOptions 或 emitLocalSessionAsInitialSession。
        // 直接使用默认初始化即可，它会自动使用 Keychain/UserDefaults 存储 Session。
        self.client = SupabaseClient(
            supabaseURL: projectURL,
            supabaseKey: apiKey,
            options: SupabaseClientOptions(
                auth: .init(
                    // 如果需要调试，可以在这里自定义 storage 或 flowType
                    // storage: nil,
                    // flowType: .pkce
                )
            )
        )
    }
}

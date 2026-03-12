//
//  SupabaseManager.swift
//  Smart Sort
//
//  Created by Albert Huang on 2/3/26.
//

import Foundation
import Supabase

final class SupabaseManager: @unchecked Sendable {
    static let shared = SupabaseManager()
    
    let client: SupabaseClient
    let baseURL: URL
    
    private init() {
        self.baseURL = AppConfig.supabaseUrl
        self.client = SupabaseClient(
            supabaseURL: AppConfig.supabaseUrl,
            supabaseKey: AppConfig.supabaseAnonKey,
            options: SupabaseClientOptions(
                auth: .init(
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }
}

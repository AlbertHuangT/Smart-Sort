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
        self.baseURL = Secrets.supabaseUrl
        self.client = SupabaseClient(
            supabaseURL: Secrets.supabaseUrl,
            supabaseKey: Secrets.supabaseAnonKey,
            options: SupabaseClientOptions(
                auth: .init(
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }
}

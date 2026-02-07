//
//  SupabaseManager.swift
//  The Trash
//
//  Created by Albert Huang on 2/3/26.
//

import Foundation
import Supabase

final class SupabaseManager: @unchecked Sendable {
    static let shared = SupabaseManager()
    
    let client: SupabaseClient
    
    private init() {
        let projectURL = URL(string: "https://nwhdqiaepwhxepcygsmm.supabase.co")!
        let apiKey = "sb_publishable_0ZwU2enz0hgtSYh72sVuwA_8ALK4tGd"
        
        self.client = SupabaseClient(
            supabaseURL: projectURL,
            supabaseKey: apiKey,
            options: SupabaseClientOptions(
                auth: .init(
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }
}

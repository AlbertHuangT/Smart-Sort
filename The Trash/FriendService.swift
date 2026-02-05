//
//  FriendService.swift
//  The Trash
//
//  Created by Albert Huang on 2/3/26.
//

import Contacts
import Supabase
import SwiftUI
import Combine

// MARK: - Models

// FriendUser 依然保留，确保它是 Sendable 的
struct FriendUser: Decodable, Identifiable, Sendable {
    let id: UUID
    let username: String
    let credits: Int
    let email: String?
    let phone: String?
}

// MARK: - Service

@MainActor
class FriendService: ObservableObject {
    @Published var friends: [FriendUser] = []
    @Published var permissionStatus: CNAuthorizationStatus = .notDetermined
    @Published var isLoading = false
    
    private let contactStore = CNContactStore()
    private let client = SupabaseManager.shared.client
    
    init() {
        checkPermission()
    }
    
    func checkPermission() {
        permissionStatus = CNContactStore.authorizationStatus(for: .contacts)
    }
    
    func requestAccessAndFetch() async {
        do {
            let granted = try await contactStore.requestAccess(for: .contacts)
            if granted {
                self.permissionStatus = .authorized
                await fetchContactsAndSync()
            }
        } catch {
            print("❌ Contact access denied: \(error)")
        }
    }
    
    func fetchContactsAndSync() async {
        self.isLoading = true
        
        // 1. 读取本地通讯录 (使用 Task.detached 在后台线程执行)
        let (emails, phones) = await Task.detached { () -> ([String], [String]) in
            let store = CNContactStore()
            let keys = [CNContactPhoneNumbersKey, CNContactEmailAddressesKey] as [CNKeyDescriptor]
            let request = CNContactFetchRequest(keysToFetch: keys)
            
            var emails: [String] = []
            var phones: [String] = []
            
            try? store.enumerateContacts(with: request) { contact, _ in
                // 提取邮箱
                for email in contact.emailAddresses {
                    emails.append(email.value as String)
                }
                // 提取手机号 (清洗非数字字符)
                for phone in contact.phoneNumbers {
                    let raw = phone.value.stringValue
                    // 仅保留数字
                    let clean = raw.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                    
                    if !clean.isEmpty {
                        phones.append(clean)
                        // 如果包含加号 (如 +1)，也保留原始格式作为备选
                        if raw.contains("+") {
                            phones.append(raw)
                        }
                    }
                }
            }
            return (emails, phones)
        }.value
            
        // 2. 调用 Supabase RPC 获取匹配的好友
        do {
            let params: [String: [String]] = [
                "p_emails": emails,
                "p_phones": phones
            ]
            
            let matchedFriends: [FriendUser] = try await client
                .rpc("find_friends_leaderboard", params: params)
                .execute()
                .value
            
            self.friends = matchedFriends
        } catch {
            print("❌ Failed to sync contacts: \(error)")
        }
        
        self.isLoading = false
    }
}

//
//  FriendService.swift
//  Smart Sort
//
//  Created by Albert Huang on 2/3/26.
//

import Contacts
import Supabase
import SwiftUI
import Combine

// MARK: - Models

// FriendUser remains separate so it stays Sendable
struct FriendUser: Decodable, Identifiable, Sendable {
    let id: UUID
    let username: String
    let credits: Int
}

// MARK: - Service

@MainActor
class FriendService: ObservableObject {
    @Published var friends: [FriendUser] = []
    @Published var permissionStatus: CNAuthorizationStatus = .notDetermined
    @Published var isLoading = false
    // Error surface for the UI
    @Published var errorMessage: String?

    // Add caching and request throttling
    private var lastFetchTime: Date?
    private let cacheValidDuration: TimeInterval = 60 // Cache remains valid for 60 seconds
    private var fetchTask: Task<Void, Never>?

    private let contactStore = CNContactStore()
    private let client = SupabaseManager.shared.client

    init() {
        checkPermission()
    }

    func checkPermission() {
        // Re-check each time in case the user changed permissions in Settings
        permissionStatus = CNContactStore.authorizationStatus(for: .contacts)
    }

    func requestAccessAndFetch() async {
        // Refresh permission state first
        checkPermission()

        // If already authorized, fetch contacts immediately
        if permissionStatus == .authorized {
            await fetchContactsAndSync()
            return
        }

        do {
            let granted = try await contactStore.requestAccess(for: .contacts)
            // Refresh permission state
            checkPermission()

            if granted {
                await fetchContactsAndSync()
            }
        } catch {
            print("❌ Contact access denied: \(error)")
            errorMessage = "Contact access denied"
            // Refresh permission state
            checkPermission()
        }
    }

    func fetchContactsAndSync(forceRefresh: Bool = false) async {
        // Check permission first
        checkPermission()
        guard permissionStatus == .authorized else {
            errorMessage = "Contact permission not granted"
            return
        }

        // Reuse cached results when still valid
        if !forceRefresh,
           !friends.isEmpty,
           let lastTime = lastFetchTime,
           Date().timeIntervalSince(lastTime) < cacheValidDuration {
            return // Use cached data
        }

        // Cancel the previous in-flight request
        fetchTask?.cancel()

        let task = Task { @MainActor in
            guard !Task.isCancelled else { return }

            self.isLoading = true
            self.errorMessage = nil

            // 1. Read local contacts on a background thread
            let (emails, phones) = await Task.detached { () -> ([String], [String]) in
                let store = CNContactStore()
                let keys = [CNContactPhoneNumbersKey, CNContactEmailAddressesKey] as [CNKeyDescriptor]
                let request = CNContactFetchRequest(keysToFetch: keys)

                var emails: [String] = []
                var phones: [String] = []

                try? store.enumerateContacts(with: request) { contact, _ in
                    // Extract emails
                    for email in contact.emailAddresses {
                        emails.append(email.value as String)
                    }
                    // Extract phone numbers and strip non-digits
                    for phone in contact.phoneNumbers {
                        let raw = phone.value.stringValue
                        // Keep digits only
                        let clean = raw.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()

                        if !clean.isEmpty {
                            phones.append(clean)
                            // Preserve the original +country-code format as a fallback
                            if raw.contains("+") {
                                phones.append(raw)
                            }
                        }
                    }
                }
                return (emails, phones)
            }.value

            guard !Task.isCancelled else {
                self.isLoading = false
                return
            }

            // 2. Call the Supabase RPC to find matching friends
            do {
                let params: [String: [String]] = [
                    "p_emails": emails,
                    "p_phones": phones
                ]

                let matchedFriends: [FriendUser] = try await client
                    .rpc("find_friends_leaderboard", params: params)
                    .execute()
                    .value

                guard !Task.isCancelled else {
                    self.isLoading = false
                    return
                }

                self.friends = matchedFriends
                self.lastFetchTime = Date() // Refresh cache timestamp
                self.isLoading = false
            } catch {
                guard !Task.isCancelled else {
                    self.isLoading = false
                    return
                }
                print("❌ Failed to sync contacts: \(error)")
                self.errorMessage = "Failed to load friends: \(error.localizedDescription)"
                self.isLoading = false
            }
        }

        fetchTask = task
        _ = await task.result
    }
}

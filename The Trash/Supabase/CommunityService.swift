//
//  CommunityService.swift
//  The Trash
//
//  Created by Albert Huang on 2/6/26.
//

import Foundation
import Supabase
import Combine

// MARK: - API Response Models

struct CommunityResponse: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let city: String
    let state: String?
    let description: String?
    let memberCount: Int
    let latitude: Double?
    let longitude: Double?
    let isMember: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id, name, city, state, description, latitude, longitude
        case memberCount = "member_count"
        case isMember = "is_member"
    }
}

struct EventResponse: Codable, Identifiable {
    let id: UUID
    let title: String
    let description: String?
    let organizer: String
    let category: String
    let eventDate: Date
    let location: String
    let latitude: Double
    let longitude: Double
    let iconName: String?
    let maxParticipants: Int
    let participantCount: Int
    let communityId: String
    let communityName: String?
    let distanceKm: Double?
    let isRegistered: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, organizer, category, location, latitude, longitude
        case eventDate = "event_date"
        case iconName = "icon_name"
        case maxParticipants = "max_participants"
        case participantCount = "participant_count"
        case communityId = "community_id"
        case communityName = "community_name"
        case distanceKm = "distance_km"
        case isRegistered = "is_registered"
    }
}

struct MyRegistrationResponse: Codable, Identifiable {
    let registrationId: UUID
    let eventId: UUID
    let eventTitle: String
    let eventDate: Date
    let eventLocation: String
    let eventCategory: String
    let communityName: String
    let registrationStatus: String
    let registeredAt: Date
    
    var id: UUID { registrationId }
    
    enum CodingKeys: String, CodingKey {
        case registrationId = "registration_id"
        case eventId = "event_id"
        case eventTitle = "event_title"
        case eventDate = "event_date"
        case eventLocation = "event_location"
        case eventCategory = "event_category"
        case communityName = "community_name"
        case registrationStatus = "registration_status"
        case registeredAt = "registered_at"
    }
}

struct MyCommunityResponse: Codable, Identifiable {
    let id: String
    let name: String
    let city: String
    let state: String?
    let description: String?
    let memberCount: Int
    let joinedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, name, city, state, description
        case memberCount = "member_count"
        case joinedAt = "joined_at"
    }
}

struct APIResult: Codable {
    let success: Bool
    let message: String
}

// MARK: - RPC Parameter Structs (Sendable for safe cross-actor usage)

private struct NearbyEventsParams: Sendable {
    let p_latitude: Double
    let p_longitude: Double
    let p_max_distance_km: Double
    let p_category: String?
    let p_only_joined_communities: Bool
    let p_sort_by: String
}

extension NearbyEventsParams: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(p_latitude, forKey: .p_latitude)
        try container.encode(p_longitude, forKey: .p_longitude)
        try container.encode(p_max_distance_km, forKey: .p_max_distance_km)
        try container.encodeIfPresent(p_category, forKey: .p_category)
        try container.encode(p_only_joined_communities, forKey: .p_only_joined_communities)
        try container.encode(p_sort_by, forKey: .p_sort_by)
    }
    
    private enum CodingKeys: String, CodingKey {
        case p_latitude, p_longitude, p_max_distance_km, p_category, p_only_joined_communities, p_sort_by
    }
}

private struct LocationParams: Sendable {
    let p_city: String
    let p_state: String
    let p_latitude: Double
    let p_longitude: Double
}

extension LocationParams: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(p_city, forKey: .p_city)
        try container.encode(p_state, forKey: .p_state)
        try container.encode(p_latitude, forKey: .p_latitude)
        try container.encode(p_longitude, forKey: .p_longitude)
    }
    
    private enum CodingKeys: String, CodingKey {
        case p_city, p_state, p_latitude, p_longitude
    }
}

// MARK: - Nonisolated RPC Helpers

/// Helper to call RPC for nearby events outside of @MainActor context
private func fetchNearbyEventsRPC(
    client: SupabaseClient,
    latitude: Double,
    longitude: Double,
    maxDistanceKm: Double,
    category: String?,
    onlyJoinedCommunities: Bool,
    sortBy: String
) async throws -> [EventResponse] {
    let params = NearbyEventsParams(
        p_latitude: latitude,
        p_longitude: longitude,
        p_max_distance_km: maxDistanceKm,
        p_category: category,
        p_only_joined_communities: onlyJoinedCommunities,
        p_sort_by: sortBy
    )
    return try await client
        .rpc("get_nearby_events", params: params)
        .execute()
        .value
}

/// Helper to call RPC for updating location outside of @MainActor context
private func updateLocationRPC(
    client: SupabaseClient,
    city: String,
    state: String,
    latitude: Double,
    longitude: Double
) async throws -> APIResult {
    let params = LocationParams(
        p_city: city,
        p_state: state,
        p_latitude: latitude,
        p_longitude: longitude
    )
    return try await client
        .rpc("update_user_location", params: params)
        .execute()
        .value
}

private struct SimpleCommunity: Codable, Sendable {
    let id: String
    let name: String
    let city: String
    let state: String?
    let description: String?
    let memberCount: Int
    let latitude: Double?
    let longitude: Double?
    
    enum CodingKeys: String, CodingKey {
        case id, name, city, state, description, latitude, longitude
        case memberCount = "member_count"
    }
}

// MARK: - Community Service

@MainActor
class CommunityService: ObservableObject {
    static let shared = CommunityService()
    
    private var client: SupabaseClient {
        SupabaseManager.shared.client
    }
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private init() {}
    
    // MARK: - Community Methods
    
    /// 获取指定城市的社区列表
    func getCommunitiesByCity(_ city: String) async -> [CommunityResponse] {
        do {
            let response: [CommunityResponse] = try await client
                .rpc("get_communities_by_city", params: ["p_city": city])
                .execute()
                .value
            return response
        } catch {
            print("❌ Get communities error: \(error)")
            return []
        }
    }
    
    /// 获取用户已加入的社区
    func getMyCommunities() async -> [MyCommunityResponse] {
        do {
            let response: [MyCommunityResponse] = try await client
                .rpc("get_my_communities")
                .execute()
                .value
            return response
        } catch {
            print("❌ Get my communities error: \(error)")
            return []
        }
    }
    
    /// 加入社区
    func joinCommunity(_ communityId: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let result: APIResult = try await client
                .rpc("join_community", params: ["p_community_id": communityId])
                .execute()
                .value
            
            if !result.success {
                errorMessage = result.message
            }
            return result.success
        } catch {
            print("❌ Join community error: \(error)")
            errorMessage = "Failed to join community"
            return false
        }
    }
    
    /// 离开社区
    func leaveCommunity(_ communityId: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let result: APIResult = try await client
                .rpc("leave_community", params: ["p_community_id": communityId])
                .execute()
                .value
            
            if !result.success {
                errorMessage = result.message
            }
            return result.success
        } catch {
            print("❌ Leave community error: \(error)")
            errorMessage = "Failed to leave community"
            return false
        }
    }
    
    // MARK: - Event Methods
    
    /// 获取附近活动
    func getNearbyEvents(
        latitude: Double,
        longitude: Double,
        maxDistanceKm: Double = 50,
        category: String? = nil,
        onlyJoinedCommunities: Bool = false,
        sortBy: String = "date"
    ) async -> [EventResponse] {
        do {
            return try await fetchNearbyEventsRPC(
                client: client,
                latitude: latitude,
                longitude: longitude,
                maxDistanceKm: maxDistanceKm,
                category: category,
                onlyJoinedCommunities: onlyJoinedCommunities,
                sortBy: sortBy
            )
        } catch {
            print("❌ Get nearby events error: \(error)")
            return []
        }
    }
    
    /// 报名活动
    func registerForEvent(_ eventId: UUID) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let result: APIResult = try await client
                .rpc("register_for_event", params: ["p_event_id": eventId.uuidString])
                .execute()
                .value
            
            if !result.success {
                errorMessage = result.message
            }
            return result.success
        } catch {
            print("❌ Register for event error: \(error)")
            errorMessage = "Failed to register for event"
            return false
        }
    }
    
    /// 取消报名
    func cancelEventRegistration(_ eventId: UUID) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let result: APIResult = try await client
                .rpc("cancel_event_registration", params: ["p_event_id": eventId.uuidString])
                .execute()
                .value
            
            if !result.success {
                errorMessage = result.message
            }
            return result.success
        } catch {
            print("❌ Cancel registration error: \(error)")
            errorMessage = "Failed to cancel registration"
            return false
        }
    }
    
    /// 获取用户已报名的活动
    func getMyRegistrations() async -> [MyRegistrationResponse] {
        do {
            let response: [MyRegistrationResponse] = try await client
                .rpc("get_my_registrations")
                .execute()
                .value
            return response
        } catch {
            print("❌ Get my registrations error: \(error)")
            return []
        }
    }
    
    // MARK: - Location Methods
    
    /// 更新用户位置
    func updateUserLocation(city: String, state: String, latitude: Double, longitude: Double) async -> Bool {
        do {
            let result = try await updateLocationRPC(
                client: client,
                city: city,
                state: state,
                latitude: latitude,
                longitude: longitude
            )
            return result.success
        } catch {
            print("❌ Update location error: \(error)")
            return false
        }
    }
    
    // MARK: - Direct Table Access (for communities list)
    
    /// 获取指定社区的活动（包括过去和将来的）
    func getCommunityEvents(communityId: String) async -> [EventResponse] {
        do {
            let response: [EventResponse] = try await client
                .rpc("get_community_events", params: ["p_community_id": communityId])
                .execute()
                .value
            return response
        } catch {
            print("❌ Get community events error: \(error)")
            return []
        }
    }
    
    /// 获取所有社区列表
    func getAllCommunities() async -> [CommunityResponse] {
        do {
            let communities: [SimpleCommunity] = try await client
                .from("communities")
                .select()
                .eq("is_active", value: true)
                .order("member_count", ascending: false)
                .execute()
                .value
            
            return communities.map {
                CommunityResponse(
                    id: $0.id,
                    name: $0.name,
                    city: $0.city,
                    state: $0.state,
                    description: $0.description,
                    memberCount: $0.memberCount,
                    latitude: $0.latitude,
                    longitude: $0.longitude,
                    isMember: nil
                )
            }
        } catch {
            print("❌ Get all communities error: \(error)")
            return []
        }
    }
}

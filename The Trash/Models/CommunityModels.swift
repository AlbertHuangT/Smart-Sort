//
//  CommunityModels.swift
//  The Trash
//
//  Extracted from CommunityService.swift
//

import Foundation
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
    let communityId: String?
    let communityName: String?
    let distanceKm: Double?
    let isRegistered: Bool?
    let isPersonal: Bool?

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
        case isPersonal = "is_personal"
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
    let status: String

    var isAdmin: Bool {
        status == "admin"
    }

    enum CodingKeys: String, CodingKey {
        case id, name, city, state, description, status
        case memberCount = "member_count"
        case joinedAt = "joined_at"
    }
}

struct APIResult: Codable {
    let success: Bool
    let message: String
}

struct CanCreateResult: Codable {
    let allowed: Bool
    let reason: String?
    let currentCount: Int
    let maxAllowed: Int

    enum CodingKeys: String, CodingKey {
        case allowed, reason
        case currentCount = "current_count"
        case maxAllowed = "max_allowed"
    }
}

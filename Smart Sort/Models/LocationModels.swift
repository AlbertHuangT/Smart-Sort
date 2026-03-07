//
//  LocationModels.swift
//  Smart Sort
//
//  Extracted from UserSettings.swift
//

import Foundation
import CoreLocation

// MARK: - Location Model

struct UserLocation: Codable, Equatable {
    let city: String
    let state: String
    let country: String
    let latitude: Double
    let longitude: Double

    var displayName: String {
        "\(city), \(state)"
    }

    func distance(to other: UserLocation) -> Double {
        let location1 = CLLocation(latitude: latitude, longitude: longitude)
        let location2 = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return location1.distance(from: location2) / 1000.0
    }
}

// MARK: - Predefined Locations

struct PredefinedLocations {
    static let all: [UserLocation] = [
        UserLocation(city: "San Diego", state: "CA", country: "US", latitude: 32.7157, longitude: -117.1611),
        UserLocation(city: "Los Angeles", state: "CA", country: "US", latitude: 34.0522, longitude: -118.2437),
        UserLocation(city: "San Francisco", state: "CA", country: "US", latitude: 37.7749, longitude: -122.4194),
        UserLocation(city: "Seattle", state: "WA", country: "US", latitude: 47.6062, longitude: -122.3321),
        UserLocation(city: "Portland", state: "OR", country: "US", latitude: 45.5152, longitude: -122.6784),
        UserLocation(city: "Denver", state: "CO", country: "US", latitude: 39.7392, longitude: -104.9903),
        UserLocation(city: "Austin", state: "TX", country: "US", latitude: 30.2672, longitude: -97.7431),
        UserLocation(city: "New York", state: "NY", country: "US", latitude: 40.7128, longitude: -74.0060),
        UserLocation(city: "Boston", state: "MA", country: "US", latitude: 42.3601, longitude: -71.0589),
        UserLocation(city: "Chicago", state: "IL", country: "US", latitude: 41.8781, longitude: -87.6298)
    ]

    static func search(query: String) -> [UserLocation] {
        if query.isEmpty { return all }
        let q = query.lowercased()
        return all.filter {
            $0.city.lowercased().contains(q) ||
            $0.state.lowercased().contains(q)
        }
    }
}

// Note: struct Community and MembershipStatus have been moved to CommunityModels.swift

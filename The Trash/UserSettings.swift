//
//  UserSettings.swift
//  The Trash
//
//  Created by Albert Huang on 2/6/26.
//

import SwiftUI
import Combine
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
    
    // 计算与另一个位置的距离（公里）
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

// MARK: - Community Model (本地缓存用)

struct Community: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let city: String
    let state: String
    let description: String
    let memberCount: Int
    let latitude: Double
    let longitude: Double
    var isMember: Bool = false
    
    var displayName: String { name }
    var fullLocation: String { "\(city), \(state)" }
    
    // 从 API 响应转换
    init(from response: CommunityResponse) {
        self.id = response.id
        self.name = response.name
        self.city = response.city
        self.state = response.state ?? ""
        self.description = response.description ?? ""
        self.memberCount = response.memberCount
        self.latitude = response.latitude ?? 0
        self.longitude = response.longitude ?? 0
        self.isMember = response.isMember ?? false
    }
    
    init(id: String, name: String, city: String, state: String, description: String, memberCount: Int, latitude: Double, longitude: Double, isMember: Bool = false) {
        self.id = id
        self.name = name
        self.city = city
        self.state = state
        self.description = description
        self.memberCount = memberCount
        self.latitude = latitude
        self.longitude = longitude
        self.isMember = isMember
    }
}

// MARK: - Membership Status

enum MembershipStatus: String, Codable {
    case none = "none"
    case pending = "pending"
    case member = "member"
}

// MARK: - User Settings Manager

@MainActor
class UserSettings: ObservableObject {
    static let shared = UserSettings()
    
    // 用户选择的位置
    @Published var selectedLocation: UserLocation?
    
    // 用户已加入的社区 ID 集合 (本地缓存)
    @Published var joinedCommunityIds: Set<String> = []
    
    // 当前城市的社区列表 (从后端获取)
    @Published var communitiesInCity: [Community] = []
    
    // 用户已加入的社区列表 (从后端获取)
    @Published var joinedCommunities: [Community] = []
    
    // 加载状态
    @Published var isLoadingCommunities = false
    
    private let locationKey = "selectedLocation"
    private let joinedCommunitiesKey = "joinedCommunityIds"
    
    private var communityService: CommunityService {
        CommunityService.shared
    }
    
    private init() {
        loadSavedData()
    }
    
    private func loadSavedData() {
        // 加载位置
        if let data = UserDefaults.standard.data(forKey: locationKey),
           let location = try? JSONDecoder().decode(UserLocation.self, from: data) {
            selectedLocation = location
        }
        
        // 加载已加入的社区 ID (本地缓存)
        if let ids = UserDefaults.standard.array(forKey: joinedCommunitiesKey) as? [String] {
            joinedCommunityIds = Set(ids)
        }
    }
    
    // MARK: - Location Methods
    
    func selectLocation(_ location: UserLocation?) async {
        selectedLocation = location
        
        if let location = location {
            // 保存到本地
            if let data = try? JSONEncoder().encode(location) {
                UserDefaults.standard.set(data, forKey: locationKey)
            }
            
            // 同步到后端
            _ = await communityService.updateUserLocation(
                city: location.city,
                state: location.state,
                latitude: location.latitude,
                longitude: location.longitude
            )
            
            // 加载该城市的社区
            await loadCommunitiesForCity(location.city)
        } else {
            UserDefaults.standard.removeObject(forKey: locationKey)
            communitiesInCity = []
        }
    }
    
    // 同步版本 (用于 UI 绑定)
    func selectLocationSync(_ location: UserLocation?) {
        Task {
            await selectLocation(location)
        }
    }
    
    // MARK: - Community Methods
    
    /// 加载指定城市的社区
    func loadCommunitiesForCity(_ city: String) async {
        isLoadingCommunities = true
        let response = await communityService.getCommunitiesByCity(city)
        communitiesInCity = response.map { Community(from: $0) }
        
        // 更新本地缓存
        for community in communitiesInCity where community.isMember {
            joinedCommunityIds.insert(community.id)
        }
        saveJoinedCommunities()
        
        isLoadingCommunities = false
    }
    
    /// 加载用户已加入的社区
    func loadMyCommunities() async {
        // 只在列表为空时显示 loading 状态，避免刷新时闪烁
        let showLoading = joinedCommunities.isEmpty
        if showLoading {
            isLoadingCommunities = true
        }
        
        let response = await communityService.getMyCommunities()
        joinedCommunities = response.map { resp in
            Community(
                id: resp.id,
                name: resp.name,
                city: resp.city,
                state: resp.state ?? "",
                description: resp.description ?? "",
                memberCount: resp.memberCount,
                latitude: 0,
                longitude: 0,
                isMember: true
            )
        }
        
        // 更新本地缓存
        joinedCommunityIds = Set(joinedCommunities.map { $0.id })
        saveJoinedCommunities()
        
        isLoadingCommunities = false
    }
    
    /// 加入社区
    func joinCommunity(_ community: Community) async -> Bool {
        let success = await communityService.joinCommunity(community.id)
        if success {
            joinedCommunityIds.insert(community.id)
            saveJoinedCommunities()
            
            // 更新本地列表
            if let index = communitiesInCity.firstIndex(where: { $0.id == community.id }) {
                communitiesInCity[index].isMember = true
            }
            
            // 添加到已加入列表
            var updatedCommunity = community
            updatedCommunity.isMember = true
            joinedCommunities.append(updatedCommunity)
        }
        return success
    }
    
    /// 离开社区
    func leaveCommunity(_ community: Community) async -> Bool {
        let success = await communityService.leaveCommunity(community.id)
        if success {
            joinedCommunityIds.remove(community.id)
            saveJoinedCommunities()
            
            // 更新本地列表
            if let index = communitiesInCity.firstIndex(where: { $0.id == community.id }) {
                communitiesInCity[index].isMember = false
            }
            
            // 从已加入列表移除
            joinedCommunities.removeAll { $0.id == community.id }
        }
        return success
    }
    
    /// 检查是否是社区成员
    func isMember(of community: Community) -> Bool {
        joinedCommunityIds.contains(community.id)
    }
    
    /// 获取已加入的社区 (本地缓存)
    func getJoinedCommunities() -> [Community] {
        joinedCommunities
    }
    
    /// 获取当前城市的社区
    func getCommunitiesNearLocation(_ location: UserLocation? = nil) -> [Community] {
        communitiesInCity
    }
    
    private func saveJoinedCommunities() {
        UserDefaults.standard.set(Array(joinedCommunityIds), forKey: joinedCommunitiesKey)
    }
    
    // MARK: - Search (本地)
    
    func searchCommunities(query: String, inCity: String? = nil) -> [Community] {
        var results = communitiesInCity
        
        if !query.isEmpty {
            let q = query.lowercased()
            results = results.filter {
                $0.name.lowercased().contains(q) ||
                $0.description.lowercased().contains(q)
            }
        }
        
        return results
    }
}

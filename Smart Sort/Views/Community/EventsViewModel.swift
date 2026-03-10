//
//  EventsViewModel.swift
//  Smart Sort
//
//  Created by OpenAI Codex on 3/6/26.
//

import Combine
import CoreLocation
import Foundation

@MainActor
final class EventsViewModel: ObservableObject {
    @Published var events: [CommunityEvent] = []
    @Published var isLoading = false
    @Published var selectedCategory: CommunityEvent.EventCategory?
    @Published var sortOption: EventSortOption = .distance
    @Published var showOnlyJoinedCommunities = false
    @Published var errorMessage: String?

    private var scheduledRefreshTask: Task<Void, Never>?
    private var activeLoadTask: Task<Void, Never>?
    private var activeRequestID = UUID()
    private let refreshDebounceNanoseconds: UInt64 = 250_000_000

    private var userSettings: UserSettings {
        UserSettings.shared
    }

    private var eventService: EventService {
        EventService.shared
    }

    var hasLocation: Bool {
        userSettings.selectedLocation != nil
    }

    var locationName: String {
        userSettings.selectedLocation?.city ?? ""
    }

    private var currentCoordinates: (latitude: Double, longitude: Double)? {
        if let preciseLocation = userSettings.preciseLocation {
            return (preciseLocation.coordinate.latitude, preciseLocation.coordinate.longitude)
        }

        if let location = userSettings.selectedLocation {
            return (location.latitude, location.longitude)
        }

        return nil
    }

    func requestPreciseLocation() {
        if userSettings.hasLocationPermission {
            userSettings.requestCurrentLocation()
        } else if userSettings.locationPermissionStatus == .notDetermined {
            userSettings.requestLocationPermission()
        }
    }

    func sortEventsByPreciseDistance() {
        guard sortOption == .distance, let preciseLocation = userSettings.preciseLocation else { return }

        events.sort { event1, event2 in
            let distance1 = event1.distance(
                from: userSettings.selectedLocation,
                preciseLocation: preciseLocation
            )
            let distance2 = event2.distance(
                from: userSettings.selectedLocation,
                preciseLocation: preciseLocation
            )
            return distance1 < distance2
        }
    }

    func scheduleRefresh(immediate: Bool = false) {
        scheduledRefreshTask?.cancel()
        scheduledRefreshTask = Task { [weak self] in
            guard let self else { return }
            if !immediate {
                try? await Task.sleep(nanoseconds: refreshDebounceNanoseconds)
            }
            guard !Task.isCancelled else { return }
            await self.performRefresh()
        }
    }

    func loadEvents() async {
        scheduledRefreshTask?.cancel()
        await performRefresh()
    }

    private func performRefresh() async {
        scheduledRefreshTask = nil
        activeLoadTask?.cancel()
        guard let currentCoordinates else {
            events = []
            isLoading = false
            errorMessage = nil
            return
        }

        if events.isEmpty {
            isLoading = true
        }
        errorMessage = nil
        let requestID = UUID()
        activeRequestID = requestID

        let categoryParam = selectedCategory?.rawValue.lowercased()
        let sortByParam: String
        switch sortOption {
        case .date: sortByParam = "date"
        case .distance: sortByParam = "distance"
        case .participants: sortByParam = "popularity"
        }
        let preciseLocation = userSettings.preciseLocation
        let joinedOnly = showOnlyJoinedCommunities

        let task = Task { [weak self] in
            guard let self else { return }

            do {
                let response = try await eventService.getNearbyEvents(
                    latitude: currentCoordinates.latitude,
                    longitude: currentCoordinates.longitude,
                    maxDistanceKm: 50,
                    category: categoryParam,
                    onlyJoinedCommunities: joinedOnly,
                    sortBy: sortByParam
                )

                guard !Task.isCancelled else { return }
                let mappedEvents = response.map(CommunityEvent.init(from:))

                await MainActor.run {
                    guard self.activeRequestID == requestID else { return }
                    self.events = mappedEvents
                    if self.sortOption == .distance, preciseLocation != nil {
                        self.sortEventsByPreciseDistance()
                    }
                    self.isLoading = false
                    self.activeLoadTask = nil
                }
            } catch is CancellationError {
                await MainActor.run {
                    if self.activeRequestID == requestID {
                        self.activeLoadTask = nil
                    }
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard self.activeRequestID == requestID else { return }
                    print("❌ Get nearby events error: \(error)")
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    self.activeLoadTask = nil
                }
            }
        }

        activeLoadTask = task
        await task.value
    }

    func registerForEvent(_ event: CommunityEvent) async -> Bool {
        do {
            let success = try await eventService.registerForEvent(event.id)
            if success, let index = events.firstIndex(where: { $0.id == event.id }) {
                events[index].isRegistered = true
                events[index].participantCount += 1
            }
            return success
        } catch {
            print("❌ Register for event error: \(error)")
            return false
        }
    }

    func cancelRegistration(_ event: CommunityEvent) async -> Bool {
        do {
            let success = try await eventService.cancelEventRegistration(event.id)
            if success, let index = events.firstIndex(where: { $0.id == event.id }) {
                events[index].isRegistered = false
                events[index].participantCount = max(0, events[index].participantCount - 1)
            }
            return success
        } catch {
            print("❌ Cancel registration error: \(error)")
            return false
        }
    }

    func toggleRegistration(for event: CommunityEvent) async {
        if event.isRegistered {
            _ = await cancelRegistration(event)
        } else {
            _ = await registerForEvent(event)
        }
    }
}

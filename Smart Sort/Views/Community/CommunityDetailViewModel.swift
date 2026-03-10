//
//  CommunityDetailViewModel.swift
//  Smart Sort
//

import Combine
import Foundation

@MainActor
class CommunityDetailViewModel: ObservableObject {
    @Published var allEvents: [CommunityEvent] = []
    @Published var isLoading = false

    private var eventService: EventService {
        EventService.shared
    }

    var upcomingEvents: [CommunityEvent] {
        allEvents
            .filter { $0.date >= Date() }
            .sorted { $0.date < $1.date }
    }

    var pastEvents: [CommunityEvent] {
        allEvents
            .filter { $0.date < Date() }
            .sorted { $0.date > $1.date }
    }

    func loadEvents(communityId: String) async {
        isLoading = true
        do {
            let response = try await eventService.getCommunityEvents(communityId: communityId)
            allEvents = response.map { CommunityEvent(from: $0) }
        } catch {
            print("❌ Get community events error: \(error)")
        }
        isLoading = false
    }

    func registerForEvent(_ event: CommunityEvent) async -> Bool {
        do {
            let success = try await eventService.registerForEvent(event.id)
            if success, let index = allEvents.firstIndex(where: { $0.id == event.id }) {
                allEvents[index].isRegistered = true
                allEvents[index].participantCount += 1
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
            if success, let index = allEvents.firstIndex(where: { $0.id == event.id }) {
                allEvents[index].isRegistered = false
                allEvents[index].participantCount = max(0, allEvents[index].participantCount - 1)
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

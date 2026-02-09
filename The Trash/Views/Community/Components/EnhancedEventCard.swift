//
//  EnhancedEventCard.swift
//  The Trash
//
//  Created by Albert Huang on 2/6/26.
//

import SwiftUI
import CoreLocation
import Combine

struct EnhancedEventCard: View {
    let event: CommunityEvent
    let userLocation: UserLocation?
    let preciseLocation: CLLocation?
    let onTap: () -> Void

    @State private var imageURL: URL? // For future image loading

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter
    }

    private var isAlmostFull: Bool {
        event.participantCount >= Int(Double(event.maxParticipants) * 0.8) && event.participantCount < event.maxParticipants
    }

    private var isFull: Bool {
        event.participantCount >= event.maxParticipants
    }

    private var distanceText: String {
        let dist = event.distance(from: userLocation, preciseLocation: preciseLocation)
        if dist <= 0 { return "" }
        if dist < 1 {
            return String(format: "%.0f m", dist * 1000)
        } else {
            return String(format: "%.1f km", dist)
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Header — neumorphic concave with category accent
                ZStack(alignment: .topLeading) {
                    Color.neuBackground
                        .frame(height: 140)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.neuBackground, lineWidth: 3)
                                .shadow(color: .neuDarkShadow, radius: 4, x: 3, y: 3)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: .neuLightShadow, radius: 4, x: -3, y: -3)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        )
                        .overlay(
                            Image(systemName: event.imageSystemName)
                                .font(.system(size: 60))
                                .foregroundColor(.neuSecondaryText.opacity(0.3))
                        )

                    // Badges
                    HStack {
                        Text(event.category.rawValue)
                            .font(.caption.bold())
                            .foregroundColor(event.category.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.neuBackground)
                            .cornerRadius(8)
                            .shadow(color: .neuDarkShadow, radius: 2, x: 1, y: 1)
                            .shadow(color: .neuLightShadow, radius: 2, x: -1, y: -1)

                        Spacer()

                        if isAlmostFull {
                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill")
                                Text("Filling Fast")
                            }
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange)
                            .cornerRadius(8)
                        } else if isFull {
                            Text("Full")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.red)
                                .cornerRadius(8)
                        }
                    }
                    .padding(12)
                }

                // Content
                VStack(alignment: .leading, spacing: 10) {
                    // Title & Distance
                    HStack(alignment: .top) {
                        Text(event.title)
                            .font(.title3.bold())
                            .lineLimit(2)
                            .foregroundColor(.neuText)

                        Spacer()

                        if !distanceText.isEmpty {
                            Label(distanceText, systemImage: "location.fill")
                                .font(.caption)
                                .foregroundColor(.neuSecondaryText)
                        }
                    }

                    // Info Rows
                    HStack(spacing: 16) {
                        Label(dateFormatter.string(from: event.date), systemImage: "calendar")
                        Spacer()
                        Label(event.location, systemImage: "mappin.and.ellipse")
                            .lineLimit(1)
                    }
                    .font(.subheadline)
                    .foregroundColor(.neuSecondaryText)

                    Color.neuDivider.frame(height: 1)
                        .padding(.vertical, 4)

                    // Footer
                    HStack {
                        // Organizer
                        HStack(spacing: 6) {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.neuSecondaryText)
                            Text(event.organizer)
                                .font(.caption)
                                .foregroundColor(.neuSecondaryText)
                        }

                        Spacer()

                        // Participants
                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                                .font(.caption)
                            Text("\(event.participantCount)/\(event.maxParticipants)")
                                .font(.caption.bold())
                        }
                        .foregroundColor(isFull ? .red : .neuAccentBlue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .neumorphicConcave(cornerRadius: 6)

                        if event.isRegistered {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.neuAccentGreen)
                                .font(.title3)
                                .padding(.leading, 8)
                        }
                    }
                }
                .padding(16)
                .background(Color.neuBackground)
            }
            .cornerRadius(16)
            .shadow(color: .neuDarkShadow, radius: 8, x: 5, y: 5)
            .shadow(color: .neuLightShadow, radius: 8, x: -4, y: -4)
        }
        .buttonStyle(.plain)
    }
}

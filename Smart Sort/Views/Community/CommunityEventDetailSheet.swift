import SwiftUI

struct CommunityEventDetailSheet: View {
    let event: CommunityEvent
    let userLocation: UserLocation?
    let resolveCurrentEvent: (CommunityEvent) -> CommunityEvent
    let onToggleRegistration: (CommunityEvent) async -> Void

    @ObservedObject private var userSettings = UserSettings.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.trashTheme) private var theme

    private var currentEvent: CommunityEvent {
        resolveCurrentEvent(event)
    }

    private var isPast: Bool {
        currentEvent.date < Date()
    }

    private var distanceText: String? {
        let distance = currentEvent.distance(
            from: userLocation,
            preciseLocation: userSettings.preciseLocation
        )

        guard distance > 0 else { return nil }
        if distance < 1 {
            return String(format: "%.0f meters away", distance * 1000)
        }
        return String(format: "%.1f km away", distance)
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: theme.layout.sectionSpacing) {
                    header
                    titleSection
                    detailsSection
                    descriptionSection
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, theme.layout.screenInset)
                .padding(.top, theme.layout.screenInset)
                .padding(.bottom, theme.spacing.xxl)
            }
            .trashScreenBackground()
            .navigationTitle("Event Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    TrashTextButton(title: "Close", variant: .accent) {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !isPast {
                    actionBar
                }
            }
        }
        .presentationBackground(theme.appearance.sheetBackground)
    }

    private var header: some View {
        ZStack {
            LinearGradient(
                colors: [
                    currentEvent.category.color.opacity(0.78),
                    currentEvent.category.color
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: theme.layout.elementSpacing) {
                TrashIcon(systemName: currentEvent.imageSystemName)
                    .font(.system(size: 42, weight: .semibold))
                    .trashOnAccentForeground()

                Text(currentEvent.category.rawValue.capitalized)
                    .font(theme.typography.subheadline)
                    .foregroundColor(theme.onAccentForeground.opacity(0.92))

                if isPast {
                    TrashPill(
                        title: "Past Event",
                        color: theme.palette.textPrimary.opacity(0.45),
                        isSelected: true
                    )
                }
            }
            .padding(.vertical, theme.spacing.xl)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 168)
        .clipShape(RoundedRectangle(cornerRadius: theme.corners.large, style: .continuous))
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            Text(currentEvent.title)
                .font(theme.typography.title)
                .foregroundColor(theme.palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: theme.spacing.sm) {
                TrashIcon(systemName: "building.2.fill")
                    .foregroundColor(theme.palette.textSecondary)
                Text(currentEvent.organizer)
                    .font(theme.typography.subheadline)
                    .foregroundColor(theme.palette.textSecondary)
            }
        }
    }

    private var detailsSection: some View {
        VStack(spacing: theme.layout.elementSpacing) {
            CommunityEventInfoRow(
                icon: "calendar",
                title: "Date & Time",
                value: dateFormatter.string(from: currentEvent.date)
            )
            CommunityEventInfoRow(
                icon: "mappin.circle.fill",
                title: "Location",
                value: currentEvent.location
            )
            if let distanceText {
                CommunityEventInfoRow(
                    icon: "location.fill",
                    title: "Distance",
                    value: distanceText
                )
            }
            CommunityEventInfoRow(
                icon: "person.2.fill",
                title: "Participants",
                value: "\(currentEvent.participantCount) / \(currentEvent.maxParticipants)"
            )
        }
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
            Text("About")
                .font(theme.typography.subheadline)
                .fontWeight(.bold)
                .foregroundColor(theme.palette.textPrimary)

            Text(
                currentEvent.description.isEmpty
                    ? "No description available."
                    : currentEvent.description
            )
            .font(theme.typography.body)
            .foregroundColor(theme.palette.textSecondary)
        }
        .padding(theme.components.cardPadding)
        .surfaceCard(cornerRadius: theme.corners.large)
    }

    private var actionBar: some View {
        VStack {
            TrashButton(
                baseColor: currentEvent.isRegistered
                    ? theme.accents.green
                    : (
                        currentEvent.participantCount >= currentEvent.maxParticipants
                            ? theme.palette.textSecondary
                            : currentEvent.category.color
                    ),
                cornerRadius: theme.corners.medium,
                action: {
                    Task {
                        await onToggleRegistration(currentEvent)
                    }
                }
            ) {
                HStack(spacing: theme.spacing.sm) {
                    TrashIcon(
                        systemName: currentEvent.isRegistered
                            ? "checkmark.circle.fill"
                            : "plus.circle.fill"
                    )
                    Text(currentEvent.isRegistered ? "Registered" : "Register Now")
                }
                .font(theme.typography.button)
                .trashOnAccentForeground()
                .frame(maxWidth: .infinity)
            }
            .disabled(
                currentEvent.participantCount >= currentEvent.maxParticipants
                    && !currentEvent.isRegistered
            )
            .padding(.horizontal, theme.layout.screenInset)
            .padding(.top, theme.layout.elementSpacing)
            .padding(.bottom, theme.layout.elementSpacing)
        }
        .background(theme.appBackground)
    }
}

private struct CommunityEventInfoRow: View {
    let icon: String
    let title: String
    let value: String

    @Environment(\.trashTheme) private var theme

    var body: some View {
        HStack(spacing: theme.layout.rowContentSpacing) {
            TrashIcon(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(theme.accents.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(theme.typography.caption)
                    .foregroundColor(theme.palette.textSecondary)
                Text(value)
                    .font(theme.typography.subheadline)
                    .foregroundColor(theme.palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(theme.components.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                .fill(theme.surfaceBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                        .stroke(theme.palette.divider.opacity(0.82), lineWidth: 1)
                )
        )
    }
}

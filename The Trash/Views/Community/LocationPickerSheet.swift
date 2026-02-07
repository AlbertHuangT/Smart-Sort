//
//  LocationPickerSheet.swift
//  The Trash
//
//  Extracted from CommunityTabView.swift
//

import SwiftUI
import CoreLocation

// MARK: - Location Picker Sheet
struct LocationPickerSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject private var userSettings = UserSettings.shared
    @State private var searchText = ""
    @State private var isSelecting = false
    @State private var showLocationPermissionAlert = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if userSettings.locationPermissionStatus != .denied && userSettings.locationPermissionStatus != .restricted {
                    useCurrentLocationSection
                }

                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search cities...", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .padding(12)
                .background(Color(.tertiarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                HStack {
                    Text("Or select a city")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

                List {
                    ForEach(PredefinedLocations.search(query: searchText), id: \.city) { location in
                        LocationRow(
                            location: location,
                            isSelected: userSettings.selectedLocation?.city == location.city,
                            isDisabled: isSelecting
                        ) {
                            guard !isSelecting else { return }
                            isSelecting = true
                            Task {
                                await userSettings.selectLocation(location)
                                isPresented = false
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .alert("Enable Location Services", isPresented: $showLocationPermissionAlert) {
                Button("Not Now", role: .cancel) { }
                Button("Enable") {
                    userSettings.requestLocationPermission()
                }
            } message: {
                Text("Allow location access to enable distance-based sorting for nearby events. This helps you find events closest to you.")
            }
            .onChange(of: userSettings.locationPermissionStatus) { newStatus in
                if newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways {
                    userSettings.requestCurrentLocation()
                }
            }
            .onChange(of: userSettings.preciseLocation) { newLocation in
                if let location = newLocation, !isSelecting {
                    isSelecting = true
                    Task {
                        let nearestCity = findNearestCity(to: location)
                        await userSettings.selectLocation(nearestCity)
                        isPresented = false
                    }
                }
            }
        }
    }

    private var useCurrentLocationSection: some View {
        VStack(spacing: 0) {
            Button(action: handleUseCurrentLocation) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)

                        if userSettings.isRequestingLocation {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "location.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Use Current Location")
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text(locationSubtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if userSettings.hasLocationPermission {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Enable")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                }
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(16)
            }
            .buttonStyle(.plain)
            .disabled(userSettings.isRequestingLocation)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)

            Divider()
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        }
    }

    private var locationSubtitle: String {
        switch userSettings.locationPermissionStatus {
        case .notDetermined:
            return "Enable for distance-based event sorting"
        case .authorizedWhenInUse, .authorizedAlways:
            return "Find the nearest city automatically"
        case .denied, .restricted:
            return "Location access denied"
        @unknown default:
            return "Enable for better experience"
        }
    }

    private func handleUseCurrentLocation() {
        if userSettings.hasLocationPermission {
            userSettings.requestCurrentLocation()
        } else if userSettings.locationPermissionStatus == .notDetermined {
            showLocationPermissionAlert = true
        }
    }

    private func findNearestCity(to location: CLLocation) -> UserLocation {
        var nearestCity = PredefinedLocations.all[0]
        var minDistance = Double.infinity

        for city in PredefinedLocations.all {
            let cityLocation = CLLocation(latitude: city.latitude, longitude: city.longitude)
            let distance = location.distance(from: cityLocation)
            if distance < minDistance {
                minDistance = distance
                nearestCity = city
            }
        }

        return nearestCity
    }
}

// MARK: - Location Row
private struct LocationRow: View {
    let location: UserLocation
    let isSelected: Bool
    let isDisabled: Bool
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(location.city)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                Text(location.state)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .opacity(isDisabled ? 0.6 : 1.0)
    }
}

//
//  CreateCommunitySheet.swift
//  The Trash
//
//  Extracted from CommunityTabView.swift
//

import SwiftUI

struct CreateCommunitySheet: View {
    @Binding var isPresented: Bool
    @ObservedObject private var userSettings = UserSettings.shared

    @State private var name = ""
    @State private var description = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccessAlert = false

    private var selectedCity: String {
        userSettings.selectedLocation?.city ?? ""
    }

    private var selectedState: String {
        userSettings.selectedLocation?.state ?? ""
    }

    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !selectedCity.isEmpty
    }

    private var communityId: String {
        let slug = name.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-")).inverted)
            .joined()
        return "\(slug)-\(selectedCity.lowercased())"
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    if userSettings.selectedLocation != nil {
                        HStack(spacing: 12) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(selectedCity)
                                    .font(.headline)
                                Text(selectedState)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    } else {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Please select a location first")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Location")
                } footer: {
                    Text("Your community will be created in this city")
                }

                Section("Community Details") {
                    TextField("Community Name", text: $name)
                        .textInputAutocapitalization(.words)

                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text("You can create up to 3 communities. You will automatically become the admin of this community.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if let error = errorMessage {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("Create Community")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .disabled(isLoading)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: createCommunity) {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("Create")
                        }
                    }
                    .disabled(!canCreate || isLoading)
                }
            }
            .alert("Community Created!", isPresented: $showSuccessAlert) {
                Button("OK") {
                    isPresented = false
                }
            } message: {
                Text("Your community \"\(name)\" has been created. You are now the admin!")
            }
        }
    }

    private func createCommunity() {
        guard canCreate else { return }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let result = try await CommunityService.shared.createCommunity(
                    id: communityId,
                    name: name.trimmingCharacters(in: .whitespaces),
                    city: selectedCity,
                    state: selectedState,
                    description: description.isEmpty ? nil : description,
                    latitude: userSettings.selectedLocation?.latitude,
                    longitude: userSettings.selectedLocation?.longitude
                )

                isLoading = false
                if result.success {
                    showSuccessAlert = true
                    Task {
                        await userSettings.loadCommunitiesForCity(selectedCity)
                        await userSettings.loadMyCommunities()
                    }
                } else {
                    errorMessage = result.message
                }
            } catch {
                isLoading = false
                errorMessage = "Failed to create community: \(error.localizedDescription)"
            }
        }
    }
}

//
//  CreateEventSheet.swift
//  The Trash
//
//  Extracted from CommunityTabView.swift
//

import SwiftUI

struct CreateEventSheet: View {
    @Binding var isPresented: Bool
    @State private var title = ""
    @State private var description = ""
    @State private var eventDate = Date()
    @State private var location = ""
    @State private var category = "cleanup"
    @State private var maxParticipants = 50

    let categories = ["cleanup", "workshop", "competition", "education", "other"]

    var body: some View {
        NavigationView {
            Form {
                Section("Event Details") {
                    TextField("Event Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    DatePicker("Date & Time", selection: $eventDate)
                    TextField("Location", text: $location)
                }

                Section("Settings") {
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { cat in
                            Text(cat.capitalized).tag(cat)
                        }
                    }

                    Stepper("Max Participants: \(maxParticipants)", value: $maxParticipants, in: 10...500, step: 10)
                }
            }
            .navigationTitle("Create Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        // TODO: Call backend API to create event
                        isPresented = false
                    }
                    .disabled(title.isEmpty || location.isEmpty)
                }
            }
        }
    }
}

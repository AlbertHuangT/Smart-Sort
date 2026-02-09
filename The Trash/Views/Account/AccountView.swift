//
//  AccountView.swift
//  The Trash
//
//  Created by Albert Huang on 2/5/26.
//

import SwiftUI
import Supabase

// MARK: - Main View
struct AccountView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var profileVM = ProfileViewModel()
    @ObservedObject private var userSettings = UserSettings.shared

    // Sheets & Alerts
    @State private var showBindPhoneSheet = false
    @State private var showBindEmailSheet = false
    @State private var showEditNameAlert = false
    @State private var newNameInput = ""
    @State private var inputPhone = "+1"
    @State private var inputEmail = ""
    @State private var inputOTP = ""
    @State private var showDeleteAlert = false
    @State private var showDeleteNotAvailableAlert = false
    @State private var showProfileError = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Error banner
                if let error = profileVM.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.neuText)
                        Spacer()
                        Button(action: { profileVM.errorMessage = nil }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.neuSecondaryText)
                        }
                    }
                    .padding(10)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.2), value: profileVM.errorMessage)
                }

                // 1. Header
                compactHeaderView

                // 2. Stats dashboard
                if !authVM.isAnonymous {
                    compactStatsView
                } else {
                    compactGuestTeaserView
                }

                // 3. Menu
                compactMenuSection

                Spacer()

                // 4. Logout & version
                VStack(spacing: 12) {
                    Button(action: { Task { await authVM.signOut() } }) {
                        HStack(spacing: 8) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.subheadline.bold())
                            Text("Log Out")
                                .font(.subheadline.bold())
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.neuBackground)
                                .shadow(color: .neuDarkShadow, radius: 6, x: 4, y: 4)
                                .shadow(color: .neuLightShadow, radius: 6, x: -3, y: -3)
                        )
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "leaf.fill")
                            .font(.caption2)
                            .foregroundColor(.neuAccentGreen)
                        Text("The Trash")
                            .font(.caption2.bold())
                            .foregroundColor(.neuText)
                        Text("• Version 1.0.0")
                            .font(.caption2)
                            .foregroundColor(.neuSecondaryText)
                    }
                    .padding(.bottom, 4)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .background(Color.neuBackground)
            .navigationBarHidden(true)
            .task {
                await profileVM.fetchProfile()
            }
            .sheet(isPresented: $showBindPhoneSheet) {
                BindPhoneSheet(inputPhone: $inputPhone, inputOTP: $inputOTP, authVM: authVM, isPresented: $showBindPhoneSheet)
            }
            .sheet(isPresented: $showBindEmailSheet) {
                BindEmailSheet(inputEmail: $inputEmail, authVM: authVM, isPresented: $showBindEmailSheet)
            }
            .alert("Change Username", isPresented: $showEditNameAlert) {
                TextField("Enter new name", text: $newNameInput)
                Button("Cancel", role: .cancel) { }
                Button("Save") {
                    Task { await profileVM.updateUsername(newNameInput) }
                }
            } message: {
                Text("Pick a cool name to show to your friends!")
            }
            .alert("Delete Account?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    showDeleteNotAvailableAlert = true
                }
            } message: {
                Text("This action cannot be undone. All your data and credits will be permanently removed.")
            }
            .alert("Contact Support", isPresented: $showDeleteNotAvailableAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Account deletion requires verification. Please contact support@thetrash.app to request account deletion.")
            }
        }
    }

    // MARK: - Header View
    var compactHeaderView: some View {
        ZStack {
            // Neumorphic flat header
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.neuBackground)
                .shadow(color: .neuDarkShadow, radius: 10, x: 5, y: 5)
                .shadow(color: .neuLightShadow, radius: 10, x: -5, y: -5)
                .frame(height: 160)
                .padding(.horizontal, 4)

            VStack(spacing: 16) {
                HStack(spacing: 20) {
                    // Neumorphic embossed avatar circle
                    ZStack {
                        Circle()
                            .fill(Color.neuBackground)
                            .frame(width: 68, height: 68)
                            .shadow(color: .neuDarkShadow, radius: 6, x: 5, y: 5)
                            .shadow(color: .neuLightShadow, radius: 6, x: -4, y: -4)

                        Image(systemName: authVM.isAnonymous ? "person.fill" : "person.crop.circle.fill")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundColor(.neuAccentBlue)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Group {
                                if !profileVM.username.isEmpty {
                                    Text(profileVM.username)
                                } else if let email = authVM.session?.user.email, !email.isEmpty {
                                    Text(email)
                                        .lineLimit(1)
                                } else if let phone = authVM.session?.user.phone, !phone.isEmpty {
                                    Text(phone)
                                } else {
                                    Text("Guest")
                                }
                            }
                            .font(.title3.bold())
                            .foregroundColor(.neuText)
                            .lineLimit(1)
                            .frame(minWidth: 60, alignment: .leading)

                            if !authVM.isAnonymous {
                                Button(action: {
                                    newNameInput = profileVM.username
                                    showEditNameAlert = true
                                }) {
                                    Image(systemName: "pencil.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(.neuAccentBlue)
                                }
                            }
                        }

                        if !authVM.isAnonymous {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                Text(profileVM.levelName)
                                    .font(.caption.bold())
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .foregroundColor(.neuAccentBlue)
                            .neumorphicConcave(cornerRadius: 13)
                            .frame(height: 26)
                        }
                    }
                    .animation(.none, value: profileVM.username)
                    .animation(.none, value: profileVM.levelName)

                    Spacer()
                }
                .padding(.horizontal, 24)
            }
            .padding(.top, 24)
        }
    }

    // MARK: - Stats View
    var compactStatsView: some View {
        HStack(spacing: 12) {
            EnhancedStatCard(
                title: "Credits",
                value: "\(profileVM.credits)",
                icon: "flame.fill",
                gradient: [Color.orange, Color.red]
            )
            EnhancedStatCard(
                title: "Status",
                value: "Active",
                icon: "checkmark.shield.fill",
                gradient: [Color.neuAccentGreen, Color.mint]
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    // MARK: - Guest Teaser View
    var compactGuestTeaserView: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.neuBackground)
                    .frame(width: 44, height: 44)
                    .shadow(color: .neuDarkShadow, radius: 4, x: 3, y: 3)
                    .shadow(color: .neuLightShadow, radius: 4, x: -2, y: -2)

                Image(systemName: "link.circle.fill")
                    .font(.title2)
                    .foregroundColor(.neuAccentBlue)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Link Account to Save Progress")
                    .font(.subheadline.bold())
                    .foregroundColor(.neuText)
                Text("Don't lose your hard-earned credits!")
                    .font(.caption)
                    .foregroundColor(.neuSecondaryText)
            }

            Spacer()

            Image(systemName: "chevron.right.circle.fill")
                .font(.title2)
                .foregroundColor(.neuAccentBlue)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.neuBackground)
                .shadow(color: .neuDarkShadow, radius: 6, x: 4, y: 4)
                .shadow(color: .neuLightShadow, radius: 6, x: -3, y: -3)
        )
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    // MARK: - Menu Section
    var compactMenuSection: some View {
        VStack(spacing: 16) {
            // Security Section
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.neuAccentBlue, .cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 28, height: 28)

                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    Text("Security")
                        .font(.headline)
                        .foregroundColor(.neuText)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

                VStack(spacing: 0) {
                    EnhancedAccountRow(
                        icon: "envelope.fill",
                        gradient: [.blue, .indigo],
                        title: "Email",
                        status: authVM.session?.user.email != nil ? "Linked" : "Link Now",
                        isLinked: authVM.session?.user.email != nil
                    ) { showBindEmailSheet = true }

                    Color.neuDivider.frame(height: 1).padding(.leading, 52)

                    EnhancedAccountRow(
                        icon: "phone.fill",
                        gradient: [.green, .mint],
                        title: "Phone",
                        status: authVM.session?.user.phone != nil ? "Linked" : "Link Now",
                        isLinked: authVM.session?.user.phone != nil
                    ) { showBindPhoneSheet = true }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.neuBackground)
                    .shadow(color: .neuDarkShadow, radius: 6, x: 4, y: 4)
                    .shadow(color: .neuLightShadow, radius: 6, x: -3, y: -3)
            )

            // General Section
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.gray, .neuSecondaryText],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 28, height: 28)

                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    Text("General")
                        .font(.headline)
                        .foregroundColor(.neuText)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

                VStack(spacing: 0) {
                    NavigationLink(destination: AchievementsListView()) {
                        EnhancedSettingsRow(icon: "trophy.fill", gradient: [.purple, .indigo], title: "Achievements")
                    }

                    Color.neuDivider.frame(height: 1).padding(.leading, 52)

                    NavigationLink(destination: RewardView()) {
                        EnhancedSettingsRow(icon: "gift.fill", gradient: [.orange, .yellow], title: "Rewards")
                    }

                    Color.neuDivider.frame(height: 1).padding(.leading, 52)

                    NavigationLink(destination: TrashHistoryView()) {
                        EnhancedSettingsRow(icon: "trash.fill", gradient: [.purple, .pink], title: "My Trash History")
                    }

                    Color.neuDivider.frame(height: 1).padding(.leading, 52)

                    Button(action: { showDeleteAlert = true }) {
                        EnhancedSettingsRow(icon: "xmark.bin.fill", gradient: [.red, .orange], title: "Delete Account")
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.neuBackground)
                    .shadow(color: .neuDarkShadow, radius: 6, x: 4, y: 4)
                    .shadow(color: .neuLightShadow, radius: 6, x: -3, y: -3)
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
}

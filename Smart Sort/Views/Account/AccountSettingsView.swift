//
//  AccountSettingsView.swift
//  Smart Sort
//

import SwiftUI
import Auth

struct AccountSettingsView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.trashTheme) private var theme
    @State private var activeSheet: AccountSheetRoute?
    @State private var sheetInputs = AccountSheetInputs()
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: theme.layout.sectionSpacing) {
                identitySection
                securitySection
                InfoCard(content: "Linking your email or phone allows you to access your account and credits from any device.")
            }
            .padding(.horizontal, theme.layout.screenInset)
            .padding(.top, theme.layout.screenInset)
            .padding(.bottom, theme.spacing.xxl)
        }
        .trashScreenBackground()
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $activeSheet) { route in
            switch route {
            case .bindPhone:
                BindPhoneSheet(
                    inputPhone: $sheetInputs.phone,
                    inputOTP: $sheetInputs.otp,
                    authVM: authVM,
                    isPresented: routeBinding(.bindPhone)
                )
            case .bindEmail:
                BindEmailSheet(
                    inputEmail: $sheetInputs.email,
                    authVM: authVM,
                    isPresented: routeBinding(.bindEmail)
                )
            case .changePassword:
                ChangePasswordSheet(
                    authVM: authVM,
                    isPresented: routeBinding(.changePassword)
                )
            case .upgradeGuest, .editUsername:
                EmptyView()
            }
        }
    }

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
            SectionHeader(title: "Identity")
            SettingsRow(icon: "envelope.fill", title: "Email", subtitle: authVM.session?.user.email ?? "Not linked") {
                sheetInputs.email = authVM.session?.user.email ?? ""
                activeSheet = .bindEmail
            }
            SettingsRow(icon: "phone.fill", title: "Phone", subtitle: authVM.session?.user.phone ?? "Not linked") {
                sheetInputs.phone = authVM.session?.user.phone ?? "+1"
                sheetInputs.otp = ""
                activeSheet = .bindPhone
            }
        }
    }

    private var securitySection: some View {
        VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
            SectionHeader(title: "Security")
            SettingsRow(icon: "key.fill", title: "Change Password") {
                activeSheet = .changePassword
            }
        }
    }

    private func routeBinding(_ route: AccountSheetRoute) -> Binding<Bool> {
        Binding(
            get: { activeSheet == route },
            set: { isPresented in
                if isPresented {
                    activeSheet = route
                } else if activeSheet == route {
                    activeSheet = nil
                }
            }
        )
    }
}

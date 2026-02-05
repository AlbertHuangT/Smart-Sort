//
//  AccountView.swift
//  The Trash
//
//  Created by Albert Huang on 2/5/26.
//

import SwiftUI
import Supabase
import Combine

// MARK: - Profile ViewModel
@MainActor
class ProfileViewModel: ObservableObject {
    @Published var credits: Int = 0
    @Published var username: String = ""
    @Published var levelName: String = "Novice Recycler"
    @Published var isLoading = false
    
    private let client = SupabaseManager.shared.client
    
    func fetchProfile() async {
        guard let userId = client.auth.currentUser?.id else { return }
        isLoading = true
        do {
            struct UserProfile: Decodable {
                let credits: Int?
                let username: String?
            }
            
            let profile: UserProfile = try await client
                .from("profiles")
                .select("credits, username")
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            
            self.credits = profile.credits ?? 0
            self.username = profile.username ?? ""
            calculateLevel()
        } catch {
            print("❌ Fetch profile error: \(error)")
        }
        isLoading = false
    }
    
    // 更新用户名
    func updateUsername(_ newName: String) async {
        guard let userId = client.auth.currentUser?.id else { return }
        guard !newName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        do {
            struct UpdateName: Encodable {
                let username: String
            }
            
            try await client
                .from("profiles")
                .update(UpdateName(username: newName))
                .eq("id", value: userId)
                .execute()
            
            self.username = newName
            print("✅ Username updated to: \(newName)")
        } catch {
            print("❌ Update username error: \(error)")
        }
    }
    
    private func calculateLevel() {
        switch credits {
        case 0..<100: levelName = "Novice Recycler 🌱"
        case 100..<500: levelName = "Green Guardian 🌿"
        case 500..<2000: levelName = "Eco Warrior ⚔️"
        default: levelName = "Planet Savior 🌍"
        }
    }
}

// MARK: - Main View
struct AccountView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var profileVM = ProfileViewModel()
    
    // Sheets & Alerts
    @State private var showBindPhoneSheet = false
    @State private var showBindEmailSheet = false
    @State private var showEditNameAlert = false
    @State private var newNameInput = ""
    @State private var inputPhone = "+1"
    @State private var inputEmail = ""
    @State private var inputOTP = ""
    @State private var showDeleteAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 1. 头部卡片 (Header Card)
                    headerView
                    
                    // 2. 数据仪表盘
                    if !authVM.isAnonymous {
                        statsGridView
                    } else {
                        guestTeaserView
                    }
                    
                    // 3. 功能菜单
                    menuSection
                    
                    // 4. 退出与版本信息
                    VStack(spacing: 16) {
                        Button(action: { Task { await authVM.signOut() } }) {
                            Text("Log Out")
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(12)
                        }
                        
                        Text("Version 1.0.0 (Build 1)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
            .refreshable {
                await profileVM.fetchProfile()
            }
            .onAppear {
                Task { await profileVM.fetchProfile() }
            }
            // Sheets
            .sheet(isPresented: $showBindPhoneSheet) {
                BindPhoneSheet(inputPhone: $inputPhone, inputOTP: $inputOTP, authVM: authVM, isPresented: $showBindPhoneSheet)
            }
            .sheet(isPresented: $showBindEmailSheet) {
                BindEmailSheet(inputEmail: $inputEmail, authVM: authVM, isPresented: $showBindEmailSheet)
            }
            // 修改用户名的弹窗
            .alert("Change Username", isPresented: $showEditNameAlert) {
                TextField("Enter new name", text: $newNameInput)
                Button("Cancel", role: .cancel) { }
                Button("Save") {
                    Task { await profileVM.updateUsername(newNameInput) }
                }
            } message: {
                Text("Pick a cool name to show to your friends!")
            }
            // 删除账号的弹窗
            .alert("Delete Account?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    // TODO: Call delete account API here
                    print("Delete account logic placeholder")
                }
            } message: {
                Text("This action cannot be undone. All your data and credits will be permanently removed.")
            }
        }
    }
    
    // MARK: - Subviews
    
    // 1. 头部视图
    var headerView: some View {
        ZStack {
            LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                .frame(height: 220)
                .cornerRadius(30, corners: [.bottomLeft, .bottomRight])
                .ignoresSafeArea()
            
            VStack(spacing: 12) {
                // Avatar
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 90, height: 90)
                    .overlay(
                        Image(systemName: authVM.isAnonymous ? "person.fill" : "person.crop.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50)
                            .foregroundColor(.white)
                    )
                    .overlay(
                        Circle().stroke(Color.white, lineWidth: 3)
                    )
                    .shadow(radius: 10)
                
                // Name & Edit Button & Level
                VStack(spacing: 4) {
                    HStack(alignment: .center, spacing: 8) {
                        // 优先显示用户名
                        if !profileVM.username.isEmpty {
                            Text(profileVM.username)
                                .font(.title2).bold()
                                .foregroundColor(.white)
                        } else {
                            Text(authVM.session?.user.email ?? authVM.session?.user.phone ?? "Guest User")
                                .font(.title2).bold()
                                .foregroundColor(.white)
                        }
                        
                        // 编辑按钮 (非匿名用户可见)
                        if !authVM.isAnonymous {
                            Button(action: {
                                newNameInput = profileVM.username
                                showEditNameAlert = true
                            }) {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                    }
                    
                    if !authVM.isAnonymous {
                        Text(profileVM.levelName)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(20)
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.top, 40)
        }
    }
    
    // 2. 统计数据网格
    var statsGridView: some View {
        HStack(spacing: 16) {
            StatCard(title: "Credits", value: "\(profileVM.credits)", icon: "flame.fill", color: .orange)
            StatCard(title: "Status", value: "Active", icon: "checkmark.shield.fill", color: .green)
        }
        .padding(.horizontal)
        .offset(y: -30)
    }
    
    // 匿名用户引导
    var guestTeaserView: some View {
        VStack(spacing: 12) {
            Text("Link Account to Save Progress")
                .font(.headline)
            Text("Don't lose your hard-earned credits!")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .padding(.horizontal)
        .offset(y: -30)
    }
    
    // 3. 菜单区域 (🔥 已移除 Leaderboard 链接)
    var menuSection: some View {
        VStack(spacing: 20) {
            // Account Security Group
            GroupBox(label: Label("Security", systemImage: "lock.shield.fill")) {
                VStack(spacing: 0) {
                    AccountRow(
                        icon: "envelope.fill",
                        color: .blue,
                        title: "Email",
                        status: authVM.session?.user.email != nil ? "Linked" : "Link Now",
                        isLinked: authVM.session?.user.email != nil
                    ) { showBindEmailSheet = true }
                    
                    Divider().padding(.leading, 40)
                    
                    AccountRow(
                        icon: "phone.fill",
                        color: .green,
                        title: "Phone",
                        status: authVM.session?.user.phone != nil ? "Linked" : "Link Now",
                        isLinked: authVM.session?.user.phone != nil
                    ) { showBindPhoneSheet = true }
                }
            }
            .groupBoxStyle(CustomGroupBoxStyle())
            
            // General Settings Group
            GroupBox(label: Label("General", systemImage: "gearshape.fill")) {
                VStack(spacing: 0) {
                    
                    // 跳转：历史记录
                    NavigationLink(destination: TrashHistoryView()) {
                        SettingsRow(icon: "trash.fill", color: .purple, title: "My Trash History")
                    }
                    
                    Divider().padding(.leading, 40)
                    
                    // 删除账号
                    Button(action: { showDeleteAlert = true }) {
                        HStack {
                            Image(systemName: "xmark.bin.fill")
                                .foregroundColor(.white)
                                .frame(width: 30, height: 30)
                                .background(Color.red)
                                .cornerRadius(8)
                            Text("Delete Account")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 12)
                    }
                }
            }
            .groupBoxStyle(CustomGroupBoxStyle())
        }
        .padding(.horizontal)
    }
}

// MARK: - Components

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct AccountRow: View {
    let icon: String
    let color: Color
    let title: String
    let status: String
    let isLinked: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: { if !isLinked { action() } }) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(color)
                    .cornerRadius(8)
                
                Text(title)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(status)
                    .font(.caption)
                    .fontWeight(isLinked ? .semibold : .regular)
                    .foregroundColor(isLinked ? .green : .blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isLinked ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
                    .cornerRadius(8)
                
                if !isLinked {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(.vertical, 12)
        }
        .disabled(isLinked)
    }
}

struct SettingsRow: View {
    let icon: String
    let color: Color
    let title: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(color)
                .cornerRadius(8)
            Text(title)
                .foregroundColor(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle()) // 确保整个区域可点击
    }
}

// 自定义 GroupBox 样式
struct CustomGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading) {
            configuration.label
                .font(.headline)
                .padding(.bottom, 8)
            
            VStack(alignment: .leading) {
                configuration.content
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
        }
    }
}

// 用于 RoundedCorner
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// MARK: - Binding Sheets (底部弹窗)

struct BindPhoneSheet: View {
    @Binding var inputPhone: String
    @Binding var inputOTP: String
    @ObservedObject var authVM: AuthViewModel
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            Form {
                if !authVM.showOTPInput {
                    Section {
                        TextField("Phone (+1...)", text: $inputPhone).keyboardType(.phonePad)
                        Button("Send Code") { Task { await authVM.bindPhone(phone: inputPhone) } }
                    }
                } else {
                    Section {
                        TextField("Code", text: $inputOTP).keyboardType(.numberPad)
                        Button("Verify & Link") {
                            Task {
                                await authVM.confirmBindPhone(phone: inputPhone, token: inputOTP)
                                isPresented = false
                            }
                        }
                    }
                }
            }
            .navigationTitle("Bind Phone")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
        }
    }
}

struct BindEmailSheet: View {
    @Binding var inputEmail: String
    @ObservedObject var authVM: AuthViewModel
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Email", text: $inputEmail).keyboardType(.emailAddress).autocapitalization(.none)
                    Button("Send Link") {
                        Task {
                            await authVM.bindEmail(email: inputEmail)
                            isPresented = false
                        }
                    }
                }
            }
            .navigationTitle("Bind Email")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
        }
    }
}

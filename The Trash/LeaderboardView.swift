//
//  LeaderboardView.swift
//  The Trash
//
//  Created by Albert Huang on 2/5/26.
//

import SwiftUI
import Supabase
import Combine
import Contacts

// MARK: - Main View
struct LeaderboardView: View {
    @StateObject private var friendService = FriendService()
    @StateObject private var currentUserVM = CurrentUserViewModel()
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color(.systemGroupedBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerSection
                
                // Content
                if friendService.permissionStatus != .authorized {
                    // 1. 未授权状态
                    permissionRequestView
                } else if friendService.isLoading {
                    // 2. 加载中
                    Spacer()
                    ProgressView("Finding your friends...")
                    Spacer()
                } else if friendService.friends.isEmpty {
                    // 3. 已授权但没有朋友在玩
                    noFriendsState
                } else {
                    // 4. 好友列表
                    List {
                        // 将自己合并进列表并排序 (如果后端没返回自己，手动插入)
                        let allUsers = mergeCurrentUser(friends: friendService.friends)
                        
                        ForEach(Array(allUsers.enumerated()), id: \.element.id) { index, user in
                            LeaderboardRow(
                                rank: index + 1,
                                username: user.username,
                                credits: user.credits,
                                isMe: isMe(user.id)
                            )
                        }
                    }
                    .listStyle(.insetGrouped)
                    .refreshable {
                        await friendService.fetchContactsAndSync()
                        await currentUserVM.fetchMyScore()
                    }
                }
            }
            .padding(.bottom, 80) // 留出底部空间
            
            // 底部悬浮：显示自己的实时排名
            if friendService.permissionStatus == .authorized, let me = currentUserVM.myProfile {
                let myRank = calculateMyRank(friends: friendService.friends, myScore: me.credits)
                MyRankBar(rank: myRank, username: me.username ?? "You", credits: me.credits)
            }
        }
        .navigationTitle("Friends Arena")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if friendService.permissionStatus == .authorized {
                Task {
                    await friendService.fetchContactsAndSync()
                    await currentUserVM.fetchMyScore()
                }
            }
        }
    }
    
    // MARK: - Logic Helpers
    
    func isMe(_ id: UUID) -> Bool {
        return SupabaseManager.shared.client.auth.currentUser?.id == id
    }
    
    // 将自己加入列表并重新排序
    func mergeCurrentUser(friends: [FriendUser]) -> [FriendUser] {
        guard let me = currentUserVM.myProfile, let myId = SupabaseManager.shared.client.auth.currentUser?.id else {
            return friends
        }
        
        var combined = friends
        // 避免重复添加自己
        if !combined.contains(where: { $0.id == myId }) {
            let myEntry = FriendUser(id: myId, username: me.username ?? "Me", credits: me.credits, email: nil, phone: nil)
            combined.append(myEntry)
        }
        
        return combined.sorted { $0.credits > $1.credits }
    }
    
    func calculateMyRank(friends: [FriendUser], myScore: Int) -> Int {
        // 简单算法：比我分高的人数 + 1
        // 注意：friends 列表里可能已经包含自己，也可能不包含，最稳妥是过滤掉自己再算
        let betterPlayers = friends.filter { $0.credits > myScore && !isMe($0.id) }
        return betterPlayers.count + 1
    }
    
    // MARK: - Subviews
    
    var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 50))
                .foregroundStyle(LinearGradient(colors: [.blue, .cyan], startPoint: .top, endPoint: .bottom))
                .padding(.top, 20)
            Text("Friends Leaderboard")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 10)
        .background(Color(.systemGroupedBackground))
    }
    
    var permissionRequestView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 70))
                .foregroundColor(.orange)
            
            Text("See Who's Winning")
                .font(.title2).bold()
            
            Text("Sync your contacts to find friends playing The Trash and compete for the top spot!")
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .foregroundColor(.secondary)
            
            Button(action: {
                Task { await friendService.requestAccessAndFetch() }
            }) {
                Text("Sync Contacts")
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(14)
                    .padding(.horizontal, 40)
            }
            Spacer()
        }
    }
    
    var noFriendsState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "hand.wave")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("No Friends Found Yet")
                .font(.title3).bold()
            Text("None of your contacts are playing The Trash yet.\nInvite them to join the challenge!")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .foregroundColor(.secondary)
            
            // Share Button
            ShareLink(item: URL(string: "https://yourappurl.com")!, subject: Text("Join me on The Trash!"), message: Text("Come verify trash and earn credits with me!")) {
                Label("Invite Friends", systemImage: "square.and.arrow.up")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(20)
            }
            Spacer()
        }
    }
}

// MARK: - Row & Bar Components

struct LeaderboardRow: View {
    let rank: Int
    let username: String
    let credits: Int
    let isMe: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            rankView(rank: rank)
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(username)
                    .fontWeight(isMe ? .bold : .medium)
                    .foregroundColor(isMe ? .blue : .primary)
                if isMe {
                    Text("You")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text("\(credits)")
                .font(.system(.body, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    func rankView(rank: Int) -> some View {
        switch rank {
        case 1: Image(systemName: "crown.fill").foregroundColor(.yellow)
        case 2: Image(systemName: "medal.fill").foregroundColor(.gray)
        case 3: Image(systemName: "medal.fill").foregroundColor(.brown)
        default: Text("\(rank)").font(.subheadline).bold().foregroundColor(.secondary)
        }
    }
}

struct MyRankBar: View {
    let rank: Int
    let username: String
    let credits: Int
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Your Rank")
                    .font(.caption).foregroundColor(.white.opacity(0.8))
                HStack {
                    Text("#\(rank)").font(.title2).bold().foregroundColor(.white)
                    Text(username).font(.caption).bold().foregroundColor(.white)
                }
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text("Credits").font(.caption).foregroundColor(.white.opacity(0.8))
                Text("\(credits)").font(.title2).bold().foregroundColor(.white)
            }
        }
        .padding()
        .background(Color.blue.shadow(radius: 8))
        .cornerRadius(20, corners: [.topLeft, .topRight])
        .padding(.horizontal)
        .background(Color.blue.ignoresSafeArea(edges: .bottom))
    }
}

// 辅助 VM：获取自己的分数
@MainActor
class CurrentUserViewModel: ObservableObject {
    @Published var myProfile: UserProfile?
    struct UserProfile: Decodable {
        let username: String?
        let credits: Int
    }
    
    func fetchMyScore() async {
        guard let uid = SupabaseManager.shared.client.auth.currentUser?.id else { return }
        try? self.myProfile = await SupabaseManager.shared.client
            .from("profiles").select("username, credits").eq("id", value: uid).single().execute().value
    }
}

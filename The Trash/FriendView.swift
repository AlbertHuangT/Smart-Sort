//
//  FriendView.swift
//  The Trash
//
//  Created by Albert Huang on 2/4/26.
//

import SwiftUI
import Contacts

struct FriendView: View {
    // 使用新的 FriendService (RPC 版本)
    @StateObject private var friendService = FriendService()
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                if friendService.isLoading {
                    ProgressView("Syncing friends...")
                } else if friendService.permissionStatus != .authorized {
                    // 1. 未授权状态：显示同步按钮
                    permissionView
                } else if friendService.friends.isEmpty {
                    // 2. 已授权但没朋友：显示空状态
                    emptyStateView
                } else {
                    // 3. 好友列表 (带排名)
                    List {
                        ForEach(Array(friendService.friends.enumerated()), id: \.element.id) { index, friend in
                            HStack {
                                // 排名 (索引 + 1)
                                rankView(rank: index + 1)
                                    .frame(width: 35)
                                
                                VStack(alignment: .leading) {
                                    Text(friend.username)
                                        .font(.headline)
                                    // 如果有手机号匹配，显示一个小标识 (可选)
                                    if friend.phone != nil {
                                        Text("Contact")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 4)
                                            .background(Color.gray.opacity(0.1))
                                            .cornerRadius(4)
                                    }
                                }
                                
                                Spacer()
                                
                                Text("\(friend.credits)")
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                                Text("pts")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .refreshable {
                        await friendService.requestAccessAndFetch()
                    }
                }
            }
            .navigationTitle("Friend Leaderboard")
            .onAppear {
                // 视图出现时自动尝试同步
                if friendService.permissionStatus == .authorized {
                    Task { await friendService.fetchContactsAndSync() }
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    var permissionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            Text("Find Your Friends")
                .font(.title2).bold()
            Text("Sync contacts to see who else is playing The Trash!")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .foregroundColor(.secondary)
            
            Button("Sync Contacts") {
                Task { await friendService.requestAccessAndFetch() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
    
    var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2.slash.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No Friends Found")
                .font(.title2).bold()
            Text("None of your contacts are on the leaderboard yet.\nInvite them to join!")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    func rankView(rank: Int) -> some View {
        switch rank {
        case 1: Image(systemName: "crown.fill").foregroundColor(.yellow).font(.title2)
        case 2: Image(systemName: "medal.fill").foregroundColor(.gray).font(.title2)
        case 3: Image(systemName: "medal.fill").foregroundColor(.brown).font(.title2)
        default: Text("\(rank)").font(.headline).foregroundColor(.secondary)
        }
    }
}

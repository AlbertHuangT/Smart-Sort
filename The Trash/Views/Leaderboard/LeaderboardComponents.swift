//
//  LeaderboardComponents.swift
//  The Trash
//
//  Extracted from LeaderboardView.swift
//

import SwiftUI

// MARK: - Leaderboard Row

struct LeaderboardRow: View {
    let rank: Int
    let username: String
    let credits: Int
    let isMe: Bool

    var body: some View {
        HStack(spacing: 16) {
            rankViewHelper(rank: rank)
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
    func rankViewHelper(rank: Int) -> some View {
        switch rank {
        case 1: Image(systemName: "crown.fill").foregroundColor(.yellow)
        case 2: Image(systemName: "medal.fill").foregroundColor(.gray)
        case 3: Image(systemName: "medal.fill").foregroundColor(.brown)
        default: Text("\(rank)").font(.subheadline).bold().foregroundColor(.secondary)
        }
    }
}

// MARK: - My Rank Bar

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

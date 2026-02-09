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
                .frame(width: 40) // Slightly wider for shadows

            VStack(alignment: .leading) {
                Text(username)
                    .fontWeight(isMe ? .bold : .medium)
                    .foregroundColor(isMe ? .neuAccentBlue : .neuText)
                if isMe {
                    Text("You")
                        .font(.caption2)
                        .foregroundColor(.neuSecondaryText)
                }
            }

            Spacer()

            Text("\(credits)")
                .font(.system(.body, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(.neuText)
        }
        .padding(16)
        .background(Color.neuBackground)
        .cornerRadius(20)
        .shadow(color: .neuDarkShadow, radius: 8, x: 5, y: 5)
        .shadow(color: .neuLightShadow, radius: 8, x: -5, y: -5)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isMe ? Color.neuAccentBlue.opacity(0.3) : Color.clear, lineWidth: 2)
        )
        .padding(.vertical, 8) // Spacing between rows
    }

    @ViewBuilder
    func rankViewHelper(rank: Int) -> some View {
        switch rank {
        case 1: 
            Image(systemName: "crown.fill")
                .foregroundColor(.yellow)
                .font(.title2)
                .shadow(color: .orange.opacity(0.5), radius: 2)
        case 2: 
            Image(systemName: "medal.fill")
                .foregroundColor(.gray)
                .font(.title2)
                .shadow(color: .black.opacity(0.2), radius: 2)
        case 3: 
            Image(systemName: "medal.fill")
                .foregroundColor(.brown)
                .font(.title2)
                .shadow(color: .black.opacity(0.2), radius: 2)
        default: 
            Text("\(rank)")
                .font(.subheadline)
                .bold()
                .foregroundColor(.neuSecondaryText)
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
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                HStack {
                    Text("#\(rank)")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.white)
                    Text(username)
                        .font(.caption)
                        .bold()
                        .foregroundColor(.white)
                }
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text("Credits")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                Text("\(credits)")
                    .font(.title2)
                    .bold()
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(
            ZStack {
                LinearGradient(colors: [.neuAccentBlue, .cyan], startPoint: .leading, endPoint: .trailing)
                // Inner glow
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            }
        )
        .cornerRadius(20, corners: [.topLeft, .topRight])
        .shadow(color: .neuAccentBlue.opacity(0.4), radius: 10, y: -5)
        .padding(.horizontal)
    }
}



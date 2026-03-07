//
//  ChallengeInviteSheet.swift
//  Smart Sort
//
//  Select a friend or community member to challenge to a duel.
//

import Combine
import Supabase
import SwiftUI

struct ChallengeInviteSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let theme = TrashTheme()
    @StateObject private var viewModel = ChallengeInviteViewModel()
    let onChallenge: (UUID) -> Void

    init(onChallenge: @escaping (UUID) -> Void = { _ in }) {
        self.onChallenge = onChallenge
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading {
                    EnhancedLoadingView()
                } else if viewModel.members.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(viewModel.members) { member in
                                InviteMemberRow(member: member) {
                                    onChallenge(member.id)
                                    dismiss()
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                }
            }
            .navigationTitle("Challenge Someone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    TrashTextButton(title: "Cancel", variant: .accent) { dismiss() }
                }
            }
            .task {
                await viewModel.fetchMembers()
            }
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            icon: "person.crop.circle.badge.questionmark",
            title: "No Members Found",
            subtitle: "Join a community to find opponents."
        )
    }
}

// MARK: - Member Row

struct InviteMemberRow: View {
    let member: InvitableMember
    let onChallenge: () -> Void
    private let theme = TrashTheme()

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(theme.surfaceBackground)
                .frame(width: theme.components.minimumHitTarget, height: theme.components.minimumHitTarget)
                .overlay(
                    Text(String(member.displayName.prefix(1)).uppercased())
                        .font(.headline.bold())
                        .foregroundColor(theme.accents.blue)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(member.displayName)
                    .font(.subheadline.bold())
                    .foregroundColor(theme.palette.textPrimary)
            }

            Spacer()

            TrashButton(baseColor: theme.semanticDanger, cornerRadius: 999, action: onChallenge) {
                HStack(spacing: 4) {
                    TrashIcon(systemName: "bolt.fill")
                    Text("Challenge")
                }
                .font(.caption.bold())
                .trashOnAccentForeground()
            }
        }
        .padding(.horizontal, theme.components.contentInset)
        .padding(.vertical, 12)
        .frame(minHeight: theme.components.rowHeight)
        .background(
            RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                .fill(theme.surfaceBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                        .stroke(theme.palette.divider.opacity(0.8), lineWidth: 1)
                )
        )
    }
}

// MARK: - Models & ViewModel

struct InvitableMember: Identifiable, Codable {
    let id: UUID
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
    }
}

@MainActor
class ChallengeInviteViewModel: ObservableObject {
    @Published var members: [InvitableMember] = []
    @Published var isLoading = false

    private let client = SupabaseManager.shared.client

    func fetchMembers() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let raw: [InvitableMember] =
                try await client
                .rpc("get_invitable_members", params: ["p_limit": 50])
                .execute()
                .value

            self.members = raw.filter { !$0.displayName.isEmpty }
        } catch {
            print("❌ [ChallengeInvite] Failed: \(error)")
        }
    }
}

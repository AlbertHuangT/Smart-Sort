//
//  AdminService.swift
//  Smart Sort
//

import Foundation
import Supabase

@MainActor
final class AdminService {
    static let shared = AdminService()

    private var client: SupabaseClient {
        SupabaseManager.shared.client
    }

    private init() {}

    // MARK: - Admin Methods

    /// Check if current user is admin of a community
    func isAdmin(communityId: String) async throws -> Bool {
        return try await client
            .rpc("is_community_admin", params: ["p_community_id": communityId])
            .execute()
            .value
    }

    /// Get pending join applications (admin only)
    func getPendingApplications(communityId: String) async throws -> [JoinApplicationResponse] {
        return try await client
            .rpc("get_pending_applications", params: ["p_community_id": communityId])
            .execute()
            .value
    }

    /// Review a join application (admin only)
    func reviewApplication(
        applicationId: UUID,
        approve: Bool,
        rejectionReason: String? = nil
    ) async throws -> APIResult {
        let params = ReviewApplicationParams(
            p_application_id: applicationId.uuidString,
            p_approve: approve,
            p_rejection_reason: rejectionReason
        )
        return try await client
            .rpc("review_join_application", params: params)
            .execute()
            .value
    }

    /// Update community info (admin only)
    func updateCommunityInfo(
        communityId: String,
        description: String? = nil,
        welcomeMessage: String? = nil,
        rules: String? = nil,
        requiresApproval: Bool? = nil
    ) async throws -> APIResult {
        let params = UpdateCommunityInfoParams(
            p_community_id: communityId,
            p_description: description,
            p_welcome_message: welcomeMessage,
            p_rules: rules,
            p_requires_approval: requiresApproval
        )
        return try await client
            .rpc("update_community_info", params: params)
            .execute()
            .value
    }

    /// Get community members list (admin only)
    func getCommunityMembersAdmin(communityId: String) async throws -> [CommunityMemberResponse] {
        return try await client
            .rpc("get_community_members_admin", params: ["p_community_id": communityId])
            .execute()
            .value
    }

    /// Remove a member from community (admin only)
    func removeMember(communityId: String, userId: UUID, reason: String? = nil) async throws -> APIResult {
        let params = RemoveMemberParams(
            p_community_id: communityId,
            p_user_id: userId.uuidString,
            p_reason: reason
        )
        return try await client
            .rpc("remove_community_member", params: params)
            .execute()
            .value
    }

    /// Get admin action logs (admin only)
    func getAdminLogs(communityId: String, limit: Int = 50) async throws -> [AdminActionLogResponse] {
        let params = GetAdminLogsParams(p_community_id: communityId, p_limit: limit)
        return try await client
            .rpc("get_admin_action_logs", params: params)
            .execute()
            .value
    }

    /// Get community settings (for admin edit view)
    func getCommunitySettings(communityId: String) async throws -> CommunitySettingsResponse? {
        return try await client
            .rpc("get_community_settings", params: ["p_community_id": communityId])
            .single()
            .execute()
            .value
    }

    func isAppAdmin() async throws -> Bool {
        try await client
            .rpc("get_app_admin_status")
            .execute()
            .value
    }

    func getQuizQuestionCandidates(
        status: String? = "pending",
        limit: Int = 100
    ) async throws -> [QuizQuestionCandidateResponse] {
        let params = QuizCandidateQueryParams(p_status: status, p_limit: limit)
        return try await client
            .rpc("get_quiz_question_candidates", params: params)
            .execute()
            .value
    }

    func createQuizCandidatePreviewURL(path: String) async throws -> URL {
        try await client.storage
            .from("quiz-candidate-images")
            .createSignedURL(path: path, expiresIn: 3600)
    }

    func publishQuizCandidateImage(
        candidateId: UUID,
        sourcePath: String
    ) async throws -> (path: String, publicURL: URL) {
        let fileExtension = URL(fileURLWithPath: sourcePath).pathExtension
        let normalizedExtension = fileExtension.isEmpty ? "jpg" : fileExtension
        let destinationPath = "approved/\(candidateId.uuidString).\(normalizedExtension)"

        _ = try await client.storage
            .from("quiz-candidate-images")
            .copy(
                from: sourcePath,
                to: destinationPath,
                options: DestinationOptions(destinationBucket: "quiz-images")
            )

        let publicURL = try client.storage
            .from("quiz-images")
            .getPublicURL(path: destinationPath)

        return (destinationPath, publicURL)
    }

    func deletePublishedQuizCandidateImage(path: String) async {
        do {
            _ = try await client.storage
                .from("quiz-images")
                .remove(paths: [path])
        } catch {
            print("❌ Delete published quiz image error: \(error)")
        }
    }

    func reviewQuizQuestionCandidate(
        candidateId: UUID,
        decision: String,
        reviewNotes: String? = nil,
        itemName: String? = nil,
        category: String? = nil,
        publicImageURL: URL? = nil
    ) async throws -> QuizCandidateReviewResult {
        let params = ReviewQuizQuestionCandidateParams(
            p_candidate_id: candidateId.uuidString,
            p_decision: decision,
            p_review_notes: reviewNotes,
            p_item_name: itemName,
            p_category: category,
            p_public_image_url: publicImageURL?.absoluteString
        )
        return try await client
            .rpc("review_quiz_question_candidate", params: params)
            .execute()
            .value
    }
}

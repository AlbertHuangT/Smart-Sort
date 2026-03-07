//
//  TrashHistoryView.swift
//  Smart Sort
//
//  Created by Albert Huang on 2/5/26.
//

import SwiftUI
import Supabase
import Combine

// MARK: - Models
struct HistoryItem: Decodable, Identifiable {
    let id: Int // feedback_logs 使用 int8
    let createdAt: Date
    let predictedLabel: String
    let predictedCategory: String
    let userCorrection: String
    let imagePath: String
    let userComment: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case predictedLabel = "predicted_label"
        case predictedCategory = "predicted_category"
        case userCorrection = "user_correction"
        case imagePath = "image_path"
        case userComment = "user_comment"
    }
    
    // 生成 Supabase Storage 的公开链接
    var publicImageUrl: URL? {
        // 你的 Project URL
        let projectURL = "https://nwhdqiaepwhxepcygsmm.supabase.co"
        // 你的 Bucket 名字 (在 FeedbackService 中定义为 feedback_images)
        let bucket = "feedback_images"
        
        // 拼接 URL: https://[project].supabase.co/storage/v1/object/public/[bucket]/[path]
        return URL(string: "\(projectURL)/storage/v1/object/public/\(bucket)/\(imagePath)")
    }
}

// MARK: - ViewModel
@MainActor
class TrashHistoryViewModel: ObservableObject {
    @Published var historyItems: [HistoryItem] = []
    @Published var isLoading = false
    // 🔥 添加错误状态
    @Published var errorMessage: String?
    
    private let client = SupabaseManager.shared.client
    
    func fetchHistory() async {
        guard let userId = client.auth.currentUser?.id else {
            errorMessage = "Please log in to view history"
            return
        }
        isLoading = true
        errorMessage = nil
        
        do {
            let items: [HistoryItem] = try await client
                .from("feedback_logs")
                .select()
                .eq("user_id", value: userId)
                .order("created_at", ascending: false) // 最新优先
                .limit(50) // 限制最近50条
                .execute()
                .value
            
            self.historyItems = items
        } catch {
            print("❌ Fetch history error: \(error)")
            // 🔥 向用户显示错误
            errorMessage = "Failed to load history"
        }
        
        isLoading = false
    }
}

// MARK: - Main View
struct TrashHistoryView: View {
    @StateObject private var viewModel = TrashHistoryViewModel()
    private let theme = TrashTheme()
    
    var body: some View {
        ZStack {
            theme.palette.background.ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.historyItems.isEmpty {
                ProgressView("Loading history...")
            } else if viewModel.historyItems.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.historyItems) { item in
                            HistoryRow(item: item)
                        }
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 20)
                }
                .refreshable {
                    await viewModel.fetchHistory()
                }
            }
        }
        .navigationTitle("Trash History")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task { await viewModel.fetchHistory() }
        }
    }
    
    // 空状态视图
    var emptyState: some View {
        CompatibleContentUnavailableView {
            Label("No History Yet", systemImage: "clock.arrow.circlepath")
        } description: {
            Text("Items you identify and correct will appear here.")
        }
    }
}

// MARK: - Subviews
struct HistoryRow: View {
    let item: HistoryItem
    private let theme = TrashTheme()
    
    var body: some View {
        // Neumorphic Card
        HStack(spacing: 12) {
            // 1. 图片缩略图
            AsyncImage(url: item.publicImageUrl) { phase in
                switch phase {
                case .empty:
                    Rectangle().fill(theme.palette.background)
                        .overlay(ProgressView())
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    Rectangle().fill(Color.red.opacity(0.1))
                        .overlay(TrashIcon(systemName: "photo.badge.exclamationmark").foregroundColor(.red))
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 80, height: 80)
            .cornerRadius(12)
            .clipped()
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(theme.palette.background, lineWidth: 2)
                    .shadow(color: theme.shadows.dark, radius: 3, x: 2, y: 2)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            )
            
            // 2. 文字信息
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.predictedLabel.capitalized)
                        .font(.headline)
                        .foregroundColor(theme.palette.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text(item.createdAt.formatted(.dateTime.month().day()))
                        .font(.caption2)
                        .foregroundColor(theme.palette.textSecondary)
                }
                
                // 显示用户的修正行为
                if item.userCorrection != item.predictedCategory {
                    HStack(spacing: 4) {
                        Text(item.predictedCategory)
                            .strikethrough()
                            .foregroundColor(theme.semanticDanger.opacity(0.7))
                        TrashIcon(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundColor(theme.palette.textSecondary)
                        Text(item.userCorrection)
                            .fontWeight(.semibold)
                            .foregroundColor(theme.semanticSuccess)
                    }
                    .font(.caption)
                } else {
                    Text(item.predictedCategory)
                        .font(.caption)
                        .foregroundColor(theme.palette.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(theme.palette.background)
                                .shadow(color: theme.shadows.light, radius: 2, x: -1, y: -1)
                                .shadow(color: theme.shadows.dark, radius: 2, x: 1, y: 1)
                        )
                }
                
                if let comment = item.userComment, !comment.isEmpty {
                    Text("\"\(comment)\"")
                        .font(.caption2)
                        .italic()
                        .foregroundColor(theme.palette.textSecondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
        .padding(16)
        .background(theme.palette.background)
        .cornerRadius(20)
        .shadow(color: theme.shadows.dark, radius: 8, x: 5, y: 5)
        .shadow(color: theme.shadows.light, radius: 8, x: -5, y: -5)
        .padding(.horizontal, 16)
    }
}

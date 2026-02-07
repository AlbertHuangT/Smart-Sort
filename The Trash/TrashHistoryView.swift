//
//  TrashHistoryView.swift
//  The Trash
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
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.historyItems.isEmpty {
                ProgressView("Loading history...")
            } else if viewModel.historyItems.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(viewModel.historyItems) { item in
                        HistoryRow(item: item)
                            .listRowInsets(EdgeInsets()) // 让卡片撑满
                            .listRowBackground(Color.clear)
                            .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)
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
        VStack(spacing: 20) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            Text("No History Yet")
                .font(.title3).bold()
                .foregroundColor(.secondary)
            Text("Items you identify and correct will appear here.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Subviews
struct HistoryRow: View {
    let item: HistoryItem
    
    var body: some View {
        HStack(spacing: 12) {
            // 1. 图片缩略图
            AsyncImage(url: item.publicImageUrl) { phase in
                switch phase {
                case .empty:
                    Rectangle().fill(Color.gray.opacity(0.2))
                        .overlay(ProgressView())
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    Rectangle().fill(Color.red.opacity(0.1))
                        .overlay(Image(systemName: "photo.badge.exclamationmark").foregroundColor(.red))
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 80, height: 80)
            .cornerRadius(12)
            .clipped()
            
            // 2. 文字信息
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.predictedLabel.capitalized)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Text(item.createdAt.formatted(.dateTime.month().day()))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // 显示用户的修正行为
                if item.userCorrection != item.predictedCategory {
                    HStack(spacing: 4) {
                        Text(item.predictedCategory)
                            .strikethrough()
                            .foregroundColor(.red.opacity(0.7))
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(item.userCorrection)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                    .font(.caption)
                } else {
                    Text(item.predictedCategory)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                }
                
                if let comment = item.userComment, !comment.isEmpty {
                    Text("\"\(comment)\"")
                        .font(.caption2)
                        .italic()
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .padding(.horizontal)
    }
}

//
//  ArenaView.swift
//  The Trash
//
//  Created by Albert Huang on 2/3/26.
//

import SwiftUI
import Supabase
import Combine

// MARK: - Models
struct ArenaTask: Identifiable, Codable {
    let id: UUID
    let imageUrl: String
    let originalAiPrediction: String // AI 之前猜错的答案
}

// MARK: - ViewModel
@MainActor
class ArenaViewModel: ObservableObject {
    @Published var tasks: [ArenaTask] = []
    @Published var isLoading = false
    @Published var earnedPoints = 0
    @Published var showPointAnimation = false // 控制得分动画
    
    // 简单的内存图片缓存
    @Published var imageCache: [UUID: UIImage] = [:]
    
    private let client = SupabaseManager.shared.client
    
    func fetchTasks() async {
        isLoading = true
        do {
            // 这里从 correction_tasks 表拉取数据
            // 实际逻辑中，应该排除掉 current_user 已经投过票的 task
            let tasks: [ArenaTask] = try await client
                .from("correction_tasks")
                .select("id, image_url, original_ai_prediction")
                .eq("status", value: "open") // 只拉取未解决的任务
                .limit(10)
                .execute()
                .value
            
            self.tasks = tasks
            await preloadImages()
        } catch {
            print("Arena Fetch Error: \(error)")
        }
        isLoading = false
    }
    
    private func preloadImages() async {
        for task in tasks {
            // 简单防抖，已有缓存则不下载
            if imageCache[task.id] != nil { continue }
            
            if let url = URL(string: task.imageUrl),
               let (data, _) = try? await URLSession.shared.data(from: url),
               let image = UIImage(data: data) {
                imageCache[task.id] = image
            }
        }
    }
    
    // 提交投票
    func submitVote(task: ArenaTask, category: String) async {
        // 1. UI 立即响应：移除卡片
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks.remove(at: index)
        }
        
        // 2. 播放得分动画 (+25)
        withAnimation {
            earnedPoints += 25
            showPointAnimation = true
        }
        // 1秒后隐藏动画
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation { self.showPointAnimation = false }
        }
        
        // 3. 后台提交数据
        do {
            guard let userId = client.auth.currentUser?.id else { return }
            
            struct VoteInsert: Encodable {
                let task_id: UUID
                let user_id: UUID
                let voted_category: String
            }
            
            try await client.from("correction_votes").insert(VoteInsert(
                task_id: task.id,
                user_id: userId,
                voted_category: category
            )).execute()
            
            // 注意：这里我们前端先“假装”加了分。
            // 实际项目中，你需要调用一个 RPC (stored procedure) 来安全地增加用户积分
            // await client.rpc("increment_credits", params: ["amount": 25]).execute()
            
        } catch {
            print("Vote Submission Error: \(error)")
        }
    }
}

// MARK: - Main View
struct ArenaView: View {
    @StateObject private var viewModel = ArenaViewModel()
    
    // 分类选项
    let categories = ["Recyclable", "Compostable", "Landfill", "Hazardous"]
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // --- 头部 Header ---
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Trash Arena")
                                .font(.system(size: 34, weight: .heavy, design: .rounded))
                                .foregroundColor(.primary)
                            Text("Validate trash to train the AI")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // 积分牌
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                                .font(.title2)
                            
                            // 滚动数字效果可以后续优化，这里先直接显示
                            Text("\(viewModel.earnedPoints)")
                                .font(.title2)
                                .fontWeight(.black)
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                        .overlay(
                            Group {
                                if viewModel.showPointAnimation {
                                    Text("+25")
                                        .font(.title)
                                        .fontWeight(.heavy)
                                        .foregroundColor(.green)
                                        .offset(y: -40)
                                        .transition(.move(edge: .bottom).combined(with: .opacity))
                                }
                            }
                        )
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    .padding(.bottom, 20)
                    
                    Spacer()
                    
                    // --- 卡片堆叠区域 ---
                    ZStack {
                        if viewModel.tasks.isEmpty {
                            if viewModel.isLoading {
                                ProgressView("Loading challenges...")
                                    .scaleEffect(1.2)
                            } else {
                                EmptyStateView(onRefresh: {
                                    Task { await viewModel.fetchTasks() }
                                })
                            }
                        } else {
                            // 倒序显示，确保 index 0 在最上面
                            ForEach(Array(viewModel.tasks.enumerated()).reversed(), id: \.element.id) { index, task in
                                ArenaCard(
                                    task: task,
                                    image: viewModel.imageCache[task.id],
                                    categories: categories,
                                    isTopCard: index == 0 // 只有最上面的卡片能交互
                                ) { selectedCategory in
                                    Task { await viewModel.submitVote(task: task, category: selectedCategory) }
                                }
                                .offset(y: CGFloat(index * 4)) // 堆叠视觉差
                                .scaleEffect(1.0 - CGFloat(index) * 0.03) // 后面的卡片稍微变小
                                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                            }
                        }
                    }
                    .frame(height: 520) // 卡片区域高度
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                if viewModel.tasks.isEmpty {
                    Task { await viewModel.fetchTasks() }
                }
            }
        }
    }
}

// MARK: - Subviews

struct EmptyStateView: View {
    var onRefresh: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "trophy.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(radius: 10)
            
            Text("All Caught Up!")
                .font(.title2)
                .bold()
            
            Text("You've verified all pending images.\nCheck back later for more points.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button(action: onRefresh) {
                Label("Refresh Arena", systemImage: "arrow.clockwise")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(20)
            }
            .padding(.top, 10)
        }
    }
}

struct ArenaCard: View {
    let task: ArenaTask
    let image: UIImage?
    let categories: [String]
    let isTopCard: Bool
    let onVote: (String) -> Void
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // 图片层
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color(.secondarySystemBackground))
                        .overlay(
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                        )
                }
                
                // 渐变遮罩 + 按钮层
                VStack(spacing: 12) {
                    // 提示文案
                    HStack {
                        Image(systemName: "questionmark.circle.fill")
                        Text("What is this item?")
                            .font(.headline)
                        Spacer()
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal)
                    .shadow(radius: 2)
                    
                    // 投票按钮网格
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(categories, id: \.self) { category in
                            Button(action: {
                                if isTopCard { onVote(category) }
                            }) {
                                Text(category)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.white.opacity(0.95))
                                    .foregroundColor(colorForCategory(category))
                                    .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
                .background(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .allowsHitTesting(isTopCard) // 只有顶层卡片可以点击
    }
    
    func colorForCategory(_ cat: String) -> Color {
        switch cat {
        case "Recyclable": return .blue
        case "Compostable": return .green
        case "Hazardous": return .red
        case "Landfill": return .gray
        default: return .primary
        }
    }
}

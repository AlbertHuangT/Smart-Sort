//
//  TrashViewModel.swift
//  The Trash
//
//  Created by Albert Huang on 1/20/26.
//

import Foundation
import SwiftUI
import Combine

// MARK: - 1. 分类服务协议 (Protocol)
// 定义了所有 AI 服务（无论是真 AI 还是测试用的假 AI）必须具备的能力
protocol TrashClassifierService {
    /// 接收一张图片，并通过闭包返回分析结果
    func classifyImage(image: UIImage, completion: @escaping (TrashAnalysisResult) -> Void)
}

// MARK: - 2. 模拟服务 (Mock Service)
// 用于在没有真机或不加载大模型时的快速测试
class MockClassifierService: TrashClassifierService {
    func classifyImage(image: UIImage, completion: @escaping (TrashAnalysisResult) -> Void) {
        // 模拟 1.5 秒的网络/思考延迟
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let mockData = [
                TrashAnalysisResult(
                    itemName: "Mock-Soda Can",
                    category: "Recycle (Blue Bin)",
                    confidence: 0.98,
                    actionTip: "Empty liquids. Flatten to save space.",
                    color: .blue
                ),
                TrashAnalysisResult(
                    itemName: "Mock-Pizza Box",
                    category: "Compost (Green Bin)",
                    confidence: 0.85,
                    actionTip: "Greasy paper cannot be recycled. Compost it.",
                    color: .green
                )
            ]
            // 随机返回一个结果
            completion(mockData.randomElement()!)
        }
    }
}

// MARK: - 3. 视图模型 (ViewModel)
// 负责连接 UI 和 AI 服务，管理 App 的状态
class TrashViewModel: ObservableObject {
    // App 的当前状态：空闲 -> 分析中 -> 完成
    @Published var appState: AppState = .idle
    
    // 持有具体的分类服务（可能是 Real 或 Mock）
    private let classifier: TrashClassifierService
    
    // 初始化时注入具体的服务
    // 默认使用 Mock，但在 ContentView 中我们会传入 RealClassifierService.shared
    init(classifier: TrashClassifierService = MockClassifierService()) {
        self.classifier = classifier
    }
    
    /// 核心方法：处理图片并更新状态
    func analyzeImage(image: UIImage) {
        // 1. 先将状态设为“分析中”，让 UI 显示转圈圈
        self.appState = .analyzing
        
        // 2. 使用 autoreleasepool 强制内存管理
        // 在处理高分辨率图片时，这能帮助系统更快地回收临时内存，防止 OOM 崩溃
        autoreleasepool {
            // 调用 AI 服务进行识别
            classifier.classifyImage(image: image) { [weak self] result in
                // 3. 确保 UI 更新发生在主线程 (Main Thread)
                DispatchQueue.main.async {
                    self?.appState = .finished(result)
                }
            }
        }
    }
    
    /// 重置回初始状态（例如用户点击了“再拍一张”）
    func reset() {
        self.appState = .idle
    }
}

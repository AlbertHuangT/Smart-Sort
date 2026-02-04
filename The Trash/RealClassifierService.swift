//
//  RealClassifierService.swift
//  The Trash
//
//  Created by Albert Huang on 1/20/26.
//

import CoreML
import Vision
import UIKit
import SwiftUI
import Accelerate

// 1. 定义知识库的数据结构
struct TrashItem: Decodable {
    let label: String
    let category: String
    let embedding: [Float]
}

class RealClassifierService: TrashClassifierService {
    static let shared = RealClassifierService()
    
    // 视觉模型 (The Eye)
    private var model: VNCoreMLModel?
    
    // 🔥 Fix 1: 线程安全锁 (防止 Crash)
    // 使用并发队列实现“多读单写”模式
    private let accessQueue = DispatchQueue(label: "com.trash.knowledgeBase", attributes: .concurrent)
    
    // 内部存储
    private var _knowledgeBase: [TrashItem] = []
    
    // 线程安全的访问入口
    private var knowledgeBase: [TrashItem] {
        get {
            accessQueue.sync { _knowledgeBase }
        }
        set {
            accessQueue.async(flags: .barrier) {
                self._knowledgeBase = newValue
            }
        }
    }
    
    private init() {
        // 🔥 Fix 2: 启动性能优化
        // 将模型加载和 JSON 解析全部移到后台，避免阻塞主线程导致 App 启动卡顿
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.setupModel()
            self?.loadKnowledgeBase()
        }
    }
    
    // 加载模型 (耗时操作)
    private func setupModel() {
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all // 使用 NPU 加速
            
            // MobileCLIPImage 初始化可能耗时 200ms+
            let coreModel = try MobileCLIPImage(configuration: config)
            self.model = try VNCoreMLModel(for: coreModel.model)
            print("✅ [System] MobileCLIP S2 视觉系统就绪")
        } catch {
            print("❌ [Error] 模型加载失败: \(error)")
        }
    }
    
    // 加载知识库
    private func loadKnowledgeBase() {
        guard let url = Bundle.main.url(forResource: "trash_knowledge", withExtension: "json") else {
            print("❌ [Error] 严重错误: 找不到 trash_knowledge.json 文件！")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let items = try JSONDecoder().decode([TrashItem].self, from: data)
            
            // 使用线程安全的 setter
            self.knowledgeBase = items
            print("✅ [System] 成功加载知识库: \(items.count) 个物体向量")
        } catch {
            print("❌ [Error] JSON 解析失败: \(error)")
        }
    }
    
    // MARK: - Classification Logic
    
    func classifyImage(image: UIImage, completion: @escaping (TrashAnalysisResult) -> Void) {
        // 🔥 Fix 3: 启动保护 (Race to Start)
        // 如果用户在 App 刚启动还没加载完数据时就拍照，给一个友好的提示，而不是返回 "Unknown"
        if knowledgeBase.isEmpty {
            print("⚠️ 系统尚未准备就绪")
            let loadingResult = TrashAnalysisResult(
                itemName: "System Initializing...",
                category: "Please Wait",
                confidence: 0.0,
                actionTip: "The AI brain is waking up. Please try again in a few seconds.",
                color: .gray
            )
            completion(loadingResult)
            return
        }
        
        guard let model = self.model, let ciImage = CIImage(image: image) else {
            print("⚠️ [Warning] 模型未初始化或图片无效")
            return
        }
        
        // MobileCLIP S2 训练时使用的是 CenterCrop
        let request = VNCoreMLRequest(model: model) { [weak self] request, error in
            guard let self = self else { return }
            
            // 1. 获取图片向量 (Image Embedding)
            if let results = request.results as? [VNCoreMLFeatureValueObservation],
               let featureValue = results.first?.featureValue,
               let multiArray = featureValue.multiArrayValue {
                
                // 2. 将 MultiArray 转为高性能 Float 数组
                let imageEmbedding = self.convertMultiArray(multiArray)
                
                // 3. 计算所有分数并找出最佳匹配
                let bestMatch = self.findBestMatchAndDebug(imageVector: imageEmbedding)
                
                if let match = bestMatch {
                    let result = TrashAnalysisResult(
                        itemName: match.item.label.capitalized,
                        category: match.item.category,
                        confidence: Double(match.score),
                        actionTip: self.getTipForCategory(match.item.category),
                        color: self.getColorForCategory(match.item.category)
                    )
                    completion(result)
                } else {
                    // 4. 兜底逻辑
                    let failResult = TrashAnalysisResult(
                        itemName: "Unknown Object",
                        category: "Try Closer",
                        confidence: 0.0,
                        actionTip: "I can't recognize this clearly. Try moving closer or improving lighting.",
                        color: .orange
                    )
                    completion(failResult)
                }
            }
        }
        
        request.imageCropAndScaleOption = .centerCrop
        let handler = VNImageRequestHandler(ciImage: ciImage, orientation: .up)
        
        // 在后台线程执行推理
        DispatchQueue.global(qos: .userInitiated).async {
            // 🔥 Fix 4: 内存优化 (Autoreleasepool)
            // 必须包裹在真正执行繁重图像任务的地方，才能及时释放 CoreML 产生的临时内存
            autoreleasepool {
                do {
                    try handler.perform([request])
                } catch {
                    print("❌ [Error] Vision 请求失败: \(error)")
                }
            }
        }
    }
    
    // MARK: - Math Kernels
    
    private func findBestMatchAndDebug(imageVector: [Float]) -> (item: TrashItem, score: Float)? {
        // 获取当前的知识库快照 (线程安全)
        let currentKnowledge = self.knowledgeBase
        
        // 1. 归一化图片向量
        let imageNorm = sqrt(imageVector.reduce(0) { $0 + $1 * $1 })
        let normalizedImage = imageVector.map { $0 / imageNorm }
        
        var allScores: [(item: TrashItem, score: Float)] = []
        
        // 2. 遍历知识库计算点积
        for item in currentKnowledge {
            guard item.embedding.count == normalizedImage.count else { continue }
            
            var score: Float = 0.0
            vDSP_dotpr(normalizedImage, 1, item.embedding, 1, &score, vDSP_Length(normalizedImage.count))
            allScores.append((item, score))
        }
        
        // 3. 排序 (Desc)
        let sortedMatches = allScores.sorted { $0.score > $1.score }
        
        // 4. 打印 Debug 信息
        print("\n-------- 🧠 AI 思考过程 (Top 5) --------")
        for (index, match) in sortedMatches.prefix(5).enumerated() {
             print("👉 #\(index + 1) [\(match.item.label)] 得分: \(match.score)")
        }
        print("---------------------------------------\n")
        
        // 5. 返回最佳结果 (阈值 0.10)
        if let best = sortedMatches.first, best.score >= 0.10 {
            return best
        }
        
        return nil
    }
    
    // 辅助工具：MultiArray -> [Float]
    private func convertMultiArray(_ multiArray: MLMultiArray) -> [Float] {
        let count = multiArray.count
        var array = [Float](repeating: 0, count: count)
        let ptr = multiArray.dataPointer.bindMemory(to: Float.self, capacity: count)
        for i in 0..<count {
            array[i] = ptr[i]
        }
        return array
    }
    
    // MARK: - UI Logic
    
    private func getColorForCategory(_ category: String) -> Color {
        if category == "IGNORE" { return .gray.opacity(0.5) }
        if category.contains("Blue") { return .blue }
        if category.contains("Green") { return .green }
        if category.contains("Black") { return .gray }
        if category.contains("HAZARDOUS") { return .red }
        return .orange
    }
    
    private func getTipForCategory(_ category: String) -> String {
        if category == "IGNORE" { return "please point at trash." }
        if category.contains("Blue") { return "Empty liquids. Flatten boxes. Check for CRV!" }
        if category.contains("Green") { return "Food scraps & soiled paper only." }
        if category.contains("Black") { return "Wrappers & styrofoam go here." }
        if category.contains("HAZARDOUS") { return "Do NOT bin! Take to E-waste center." }
        return "Check local guidelines."
    }
}

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
import Accelerate // Math-CS: 用于高性能向量计算 (DSP)

// 1. 定义知识库的数据结构 (对应 JSON)
struct TrashItem: Decodable {
    let label: String
    let category: String
    let embedding: [Float]
}

class RealClassifierService: TrashClassifierService {
    static let shared = RealClassifierService()
    
    // 视觉模型 (The Eye)
    private let model: VNCoreMLModel?
    // 知识库 (The Brain) - 注意线程安全，虽然这里主要是读取
    private var knowledgeBase: [TrashItem] = []
    
    private init() {
        // ------------------------------------------------------------------
        // A. 加载视觉模型 (MobileCLIPImage) - 这是轻量级操作，可以同步
        // ------------------------------------------------------------------
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all // 使用 NPU 加速
            
            let coreModel = try MobileCLIPImage(configuration: config)
            self.model = try VNCoreMLModel(for: coreModel.model)
            print("✅ [System] MobileCLIP S2 视觉系统就绪")
        } catch {
            print("❌ [Error] 模型加载失败: \(error)")
            self.model = nil
        }
        
        // ------------------------------------------------------------------
        // B. 异步加载知识库 (避免卡死主线程)
        // ------------------------------------------------------------------
        loadKnowledgeBase()
    }
    
    private func loadKnowledgeBase() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let url = Bundle.main.url(forResource: "trash_knowledge", withExtension: "json") else {
                print("❌ [Error] 严重错误: 找不到 trash_knowledge.json 文件！")
                return
            }
            
            do {
                let data = try Data(contentsOf: url)
                let items = try JSONDecoder().decode([TrashItem].self, from: data)
                
                // 简单的赋值，实际生产中可加锁，但此处单例初始化后基本只读
                self?.knowledgeBase = items
                print("✅ [System] 成功加载知识库: \(items.count) 个物体向量")
            } catch {
                print("❌ [Error] JSON 解析失败: \(error)")
            }
        }
    }
    
    // MARK: - Classification Logic
    
    func classifyImage(image: UIImage, completion: @escaping (TrashAnalysisResult) -> Void) {
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
                
                // 3. 计算所有分数并找出最佳匹配 (合并计算逻辑，避免重复运算)
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
                    // 4. 兜底逻辑 (未达到阈值)
                    print("⚠️ [Result] 没有任何物体超过阈值 (0.10)")
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
        
        // 图片预处理设置
        request.imageCropAndScaleOption = .centerCrop
        
        let handler = VNImageRequestHandler(ciImage: ciImage, orientation: .up)
        
        // 在后台线程执行推理，不阻塞 UI
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                print("❌ [Error] Vision 请求失败: \(error)")
            }
        }
    }
    
    // MARK: - Math Kernels (Math-CS Core)
    
    // 计算分数、打印 Debug 信息并返回最佳结果
    private func findBestMatchAndDebug(imageVector: [Float]) -> (item: TrashItem, score: Float)? {
        guard !knowledgeBase.isEmpty else {
            print("⚠️ 知识库尚未加载完毕")
            return nil
        }

        // 1. 归一化图片向量
        let imageNorm = sqrt(imageVector.reduce(0) { $0 + $1 * $1 })
        let normalizedImage = imageVector.map { $0 / imageNorm }
        
        var allScores: [(item: TrashItem, score: Float)] = []
        
        // 2. 遍历知识库计算点积
        for item in knowledgeBase {
            // 🔥 Crash Fix: 确保维度一致
            guard item.embedding.count == normalizedImage.count else {
                continue
            }
            
            var score: Float = 0.0
            vDSP_dotpr(normalizedImage, 1, item.embedding, 1, &score, vDSP_Length(normalizedImage.count))
            allScores.append((item, score))
        }
        
        // 3. 排序 (Desc)
        let sortedMatches = allScores.sorted { $0.score > $1.score }
        
        // 4. 打印 Debug 信息 (Top 5)
        print("\n-------- 🧠 AI 思考过程 (Top 5) --------")
        for (index, match) in sortedMatches.prefix(5).enumerated() {
             print("👉 #\(index + 1) [\(match.item.label)] 得分: \(match.score)")
        }
        print("---------------------------------------\n")
        
        // 5. 返回最佳结果 (阈值过滤)
        if let best = sortedMatches.first, best.score >= 0.10 {
            return best
        }
        
        return nil
    }
    
    // 辅助工具：MultiArray -> [Float]
    private func convertMultiArray(_ multiArray: MLMultiArray) -> [Float] {
        let count = multiArray.count
        var array = [Float](repeating: 0, count: count)
        // 直接内存指针拷贝，性能最高
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

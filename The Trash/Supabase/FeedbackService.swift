//
//  FeedbackService.swift
//  The Trash
//
//  Created by Albert Huang on 2/3/26.
//

import Foundation
import UIKit
import Supabase

// 数据结构定义
struct FeedbackRecord: Encodable {
    let user_id: UUID?
    let predicted_label: String
    let predicted_category: String
    let user_correction: String
    let user_comment: String
    let image_path: String
}

class FeedbackService {
    static let shared = FeedbackService()
    
    // 获取客户端实例
    private let client = SupabaseManager.shared.client
    
    private init() {}
    
    func submitFeedback(
        image: UIImage,
        predictedLabel: String,
        predictedCategory: String,
        correctCategory: String,
        comment: String,
        userId: UUID?
    ) async throws {
        
        print("🚀 [FeedbackService] 开始提交反馈...")
        
        // 1. 图片处理
        guard let imageData = image.jpegData(compressionQuality: 0.5) else {
            throw NSError(
                domain: "FeedbackService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "图片处理失败"]
            )
        }
        
        // 2. 生成路径
        let fileName = "\(UUID().uuidString).jpg"
        let filePath = "uploads/\(fileName)"
        
        let fileOptions = FileOptions(
            cacheControl: "3600",
            contentType: "image/jpeg",
            upsert: false
        )
        
        // 🔥 修复：upload 方法更新
        // 旧写法: .upload(path: filePath, file: imageData, ...)
        // 新写法: .upload(filePath, data: imageData, ...)
        _ = try await client.storage
            .from("feedback_images")
            .upload(
                filePath,           // 第一个参数是路径，不需要标签
                data: imageData,    // 第二个参数改名为 data
                options: fileOptions
            )
        
        print("✅ [FeedbackService] 图片上传成功")
        
        // 3. 写入数据库
        let record = FeedbackRecord(
            user_id: userId,
            predicted_label: predictedLabel,
            predicted_category: predictedCategory,
            user_correction: correctCategory,
            user_comment: comment,
            image_path: filePath
        )
        
        try await client
            .from("feedback_logs")
            .insert(record)
            .execute()
            
        print("✅ [FeedbackService] 数据库写入成功")
    }
}

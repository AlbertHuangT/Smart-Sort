//
//  FeedbackRecord.swift
//  The Trash
//
//  Created by Albert Huang on 2/3/26.
//


import Foundation
import UIKit
import Supabase // 确保你已经添加了 Supabase 包

// 1. 定义上传到数据库的数据结构
// 对应 Supabase SQL 表中的字段
struct FeedbackRecord: Encodable {
    let user_id: UUID?
    let predicted_label: String
    let predicted_category: String
    let user_correction: String
    let user_comment: String
    let image_path: String
}

class FeedbackService {
    // 单例模式，全局共享
    static let shared = FeedbackService()
    
    // 从 SupabaseManager 获取客户端实例
    private let client = SupabaseManager.shared.client
    
    private init() {}
    
    /// 提交反馈的核心功能
    /// - Parameters:
    ///   - image: 用户拍摄的照片
    ///   - predictedLabel: AI 识别出的名字 (如 "Banana")
    ///   - predictedCategory: AI 识别出的分类 (如 "Compost")
    ///   - correctCategory: 用户纠正的分类
    ///   - comment: 用户填写的备注
    ///   - userId: 当前用户的 ID (如果未登录则为 nil)
    func submitFeedback(
        image: UIImage,
        predictedLabel: String,
        predictedCategory: String,
        correctCategory: String,
        comment: String,
        userId: UUID?
    ) async throws {
        
        print("🚀 [FeedbackService] 开始提交反馈...")
        
        // -------------------------------------------------------
        // 步骤 1: 图片处理
        // -------------------------------------------------------
        // 将 UIImage 压缩为 JPEG Data (0.5 的质量既省流量又能看清细节)
        guard let imageData = image.jpegData(compressionQuality: 0.5) else {
            throw NSError(
                domain: "FeedbackService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "图片处理失败：无法转换为 Data"]
            )
        }
        
        // -------------------------------------------------------
        // 步骤 2: 上传图片到 Storage
        // -------------------------------------------------------
        // 生成唯一文件名，防止覆盖: "UUID.jpg"
        let fileName = "\(UUID().uuidString).jpg"
        let filePath = "uploads/\(fileName)"
        
        // 配置上传选项
        let fileOptions = FileOptions(
            cacheControl: "3600",
            contentType: "image/jpeg",
            upsert: false
        )
        
        // 上传到 "feedback_images" 存储桶 (Bucket)
        // 注意：Bucket 名字必须和你在 Supabase 后台创建的完全一致
        _ = try await client.storage
            .from("feedback_images")
            .upload(
                path: filePath,
                file: imageData,
                options: fileOptions
            )
        
        print("✅ [FeedbackService] 图片上传成功: \(filePath)")
        
        // -------------------------------------------------------
        // 步骤 3: 写入记录到 Database
        // -------------------------------------------------------
        // 准备要写入的数据
        let record = FeedbackRecord(
            user_id: userId,
            predicted_label: predictedLabel,
            predicted_category: predictedCategory,
            user_correction: correctCategory,
            user_comment: comment,
            image_path: filePath
        )
        
        // 写入 "feedback_logs" 表
        try await client
            .from("feedback_logs") // 直接使用 .from 访问表
            .insert(record)
            .execute()
            
        print("✅ [FeedbackService] 数据库记录写入成功！反馈完成。")
    }
}
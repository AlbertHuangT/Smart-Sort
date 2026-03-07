//
//  BugReportService.swift
//  Smart Sort
//
//  Created by Albert Huang on 3/5/26.
//

import Foundation
import UIKit
import Supabase

/// Record inserted into the `bug_reports` table
struct BugReportRecord: Encodable {
    let user_id: UUID
    let title: String
    let description: String
    let log_path: String?
    let device_info: DeviceInfo
    let app_version: String
}

/// Device information stored as JSONB
struct DeviceInfo: Encodable {
    let model: String
    let system_name: String
    let system_version: String
}

@MainActor
class BugReportService {
    static let shared = BugReportService()

    private let client = SupabaseManager.shared.client

    private init() {}

    /// Submit a bug report with an optional log attachment
    func submitReport(
        title: String,
        description: String,
        attachLog: Bool
    ) async throws {
        guard let userId = client.auth.currentUser?.id else {
            throw NSError(
                domain: "BugReportService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No authenticated user"]
            )
        }

        LogManager.shared.log("Submitting bug report: \(title)", level: .info, category: "BugReport")

        // 1. Collect device information
        let device = UIDevice.current
        let deviceInfo = DeviceInfo(
            model: device.model,
            system_name: device.systemName,
            system_version: device.systemVersion
        )

        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"

        // 2. Upload the log file if requested
        var logPath: String? = nil

        if attachLog, let logData = LogManager.shared.getLogData() {
            let timestamp = ISO8601DateFormatter().string(from: Date())
                .replacingOccurrences(of: ":", with: "-")
            let filePath = "\(userId.uuidString)/\(timestamp).log"

            let fileOptions = FileOptions(
                cacheControl: "3600",
                contentType: "text/plain",
                upsert: false
            )

            _ = try await client.storage
                .from("bug-report-logs")
                .upload(
                    filePath,
                    data: logData,
                    options: fileOptions
                )

            logPath = filePath
            LogManager.shared.log("Log file uploaded: \(filePath)", level: .info, category: "BugReport")
        }

        // 3. Insert the record into bug_reports
        let record = BugReportRecord(
            user_id: userId,
            title: title,
            description: description,
            log_path: logPath,
            device_info: deviceInfo,
            app_version: appVersion
        )

        do {
            try await client
                .from("bug_reports")
                .insert(record)
                .execute()
        } catch {
            if let logPath {
                do {
                    _ = try await client.storage
                        .from("bug-report-logs")
                        .remove(paths: [logPath])
                } catch {
                    LogManager.shared.log(
                        "Failed to clean up orphaned bug report log \(logPath): \(error)",
                        level: .warning,
                        category: "BugReport"
                    )
                }
            }
            throw error
        }

        LogManager.shared.log("Bug report submitted successfully", level: .info, category: "BugReport")
    }
}

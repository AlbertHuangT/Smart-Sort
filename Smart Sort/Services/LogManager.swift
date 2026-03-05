//
//  LogManager.swift
//  Smart Sort
//
//  Created by Albert Huang on 3/5/26.
//

import Foundation
import os

/// 日志级别
enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"
}

/// 全局日志管理器：同时输出到系统控制台（os.Logger）和本地滚动日志文件
final class LogManager: @unchecked Sendable {
    static let shared = LogManager()

    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.smartsort.logmanager", qos: .utility)
    private let maxFileSize: UInt64 = 2 * 1024 * 1024 // 2 MB
    private let maxAge: TimeInterval = 7 * 24 * 3600   // 7 天
    private let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.fileURL = docs.appendingPathComponent("app.log")

        // 启动时清理超过 7 天的旧日志
        queue.async { [weak self] in
            self?.cleanupIfNeeded()
        }
    }

    // MARK: - Public API

    /// 写入一条日志
    func log(_ message: String, level: LogLevel = .info, category: String = "App") {
        let timestamp = dateFormatter.string(from: Date())
        let line = "[\(timestamp)] [\(level.rawValue)] [\(category)] \(message)\n"

        // 1. 输出到系统控制台
        let osLog = Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "com.Albert.Smart-Sort",
            category: category
        )
        switch level {
        case .debug:   osLog.debug("\(message, privacy: .public)")
        case .info:    osLog.info("\(message, privacy: .public)")
        case .warning: osLog.warning("\(message, privacy: .public)")
        case .error:   osLog.error("\(message, privacy: .public)")
        }

        // 2. 写入文件
        queue.async { [weak self] in
            self?.appendToFile(line)
        }
    }

    /// 获取日志文件 URL（文件不存在时返回 nil）
    func getLogFileURL() -> URL? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return fileURL
    }

    /// 获取日志文件原始数据
    func getLogData() -> Data? {
        return try? Data(contentsOf: fileURL)
    }

    // MARK: - Private

    private func appendToFile(_ line: String) {
        let fm = FileManager.default

        // 如果文件不存在则创建
        if !fm.fileExists(atPath: fileURL.path) {
            fm.createFile(atPath: fileURL.path, contents: nil)
        }

        // 检查文件大小，超出则截断保留后半部分
        if let attrs = try? fm.attributesOfItem(atPath: fileURL.path),
           let size = attrs[.size] as? UInt64,
           size > maxFileSize {
            truncateFile()
        }

        // Append 写入
        guard let data = line.data(using: .utf8),
              let handle = try? FileHandle(forWritingTo: fileURL) else { return }
        handle.seekToEndOfFile()
        handle.write(data)
        handle.closeFile()
    }

    /// 截断日志文件：保留后半部分，从完整行开始
    private func truncateFile() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let keepFrom = data.count / 2
        let trimmed = data.subdata(in: keepFrom..<data.count)
        if let newlineIndex = trimmed.firstIndex(of: UInt8(ascii: "\n")) {
            let clean = trimmed.subdata(in: trimmed.index(after: newlineIndex)..<trimmed.endIndex)
            try? clean.write(to: fileURL)
        } else {
            try? trimmed.write(to: fileURL)
        }
    }

    /// 如果日志文件超过 7 天未修改则删除
    private func cleanupIfNeeded() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path),
              let attrs = try? fm.attributesOfItem(atPath: fileURL.path),
              let modDate = attrs[.modificationDate] as? Date else { return }

        if Date().timeIntervalSince(modDate) > maxAge {
            try? fm.removeItem(at: fileURL)
        }
    }
}

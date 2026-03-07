//
//  ArenaImageLoader.swift
//  Smart Sort
//
//  Shared image loader for Arena modes with caching, deduplication,
//  connection limiting, and response validation.
//

import Foundation
import UIKit

actor ArenaImageLoader {
    static let shared = ArenaImageLoader()

    private enum LoaderError: LocalizedError {
        case invalidURL
        case invalidResponse
        case httpStatus(Int)
        case invalidContentType(String?)
        case invalidImageData

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid image URL."
            case .invalidResponse:
                return "Image request returned an invalid response."
            case .httpStatus(let status):
                return "Image request failed with status \(status)."
            case .invalidContentType(let contentType):
                return "Unexpected image content type: \(contentType ?? "unknown")."
            case .invalidImageData:
                return "Image data could not be decoded."
            }
        }
    }

    private let session: URLSession
    private var decodedCache: [String: UIImage] = [:]
    private var inFlightTasks: [String: Task<UIImage, Error>] = [:]

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 20
        configuration.waitsForConnectivity = false
        configuration.httpMaximumConnectionsPerHost = 4
        configuration.urlCache = URLCache(
            memoryCapacity: 32 * 1024 * 1024,
            diskCapacity: 128 * 1024 * 1024,
            diskPath: "arena-image-cache"
        )
        self.session = URLSession(configuration: configuration)
    }

    func loadImage(from urlString: String) async throws -> UIImage {
        if let cached = decodedCache[urlString] {
            return cached
        }

        if let task = inFlightTasks[urlString] {
            return try await task.value
        }

        guard let url = URL(string: urlString) else {
            throw LoaderError.invalidURL
        }

        let task = Task<UIImage, Error> {
            var request = URLRequest(url: url)
            request.cachePolicy = .returnCacheDataElseLoad

            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw LoaderError.invalidResponse
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                throw LoaderError.httpStatus(httpResponse.statusCode)
            }

            let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type")?.lowercased()
            if let contentType, !contentType.hasPrefix("image/") {
                throw LoaderError.invalidContentType(contentType)
            }

            let decodedImage = await Task.detached(priority: .userInitiated) {
                UIImage(data: data)?.preparingForDisplay() ?? UIImage(data: data)
            }.value

            guard let image = decodedImage else {
                throw LoaderError.invalidImageData
            }

            return image
        }

        inFlightTasks[urlString] = task

        do {
            let image = try await task.value
            decodedCache[urlString] = image
            inFlightTasks[urlString] = nil
            return image
        } catch {
            inFlightTasks[urlString] = nil
            throw error
        }
    }
}

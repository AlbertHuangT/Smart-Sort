//
//  ArenaImageManaging.swift
//  Smart Sort
//
//  Shared image state helpers for Arena view models.
//

import Foundation
import UIKit

struct ArenaImageLoadHandle {
    let token: UUID
    let task: Task<Void, Never>
}

@MainActor
protocol ArenaImageManaging: AnyObject {
    var imageCache: [UUID: UIImage] { get set }
    var failedImageIDs: Set<UUID> { get set }
    var imageLoadHandles: [UUID: ArenaImageLoadHandle] { get set }
    var imageLogPrefix: String { get }
}

@MainActor
extension ArenaImageManaging {
    func cancelArenaImageLoads() {
        for handle in imageLoadHandles.values {
            handle.task.cancel()
        }
        imageLoadHandles.removeAll()
    }

    @discardableResult
    func loadArenaImage(for question: QuizQuestion, forceReload: Bool = false) async -> Bool {
        if !forceReload {
            if imageCache[question.id] != nil {
                return true
            }
            if let existing = imageLoadHandles[question.id] {
                await existing.task.value
                return imageCache[question.id] != nil
            }
        } else {
            imageLoadHandles[question.id]?.task.cancel()
            imageLoadHandles[question.id] = nil
            imageCache[question.id] = nil
            failedImageIDs.remove(question.id)
        }

        let token = UUID()
        let task = Task { [weak self] in
            guard let self else { return }

            do {
                let image = try await ArenaImageLoader.shared.loadImage(from: question.imageUrl)
                guard !Task.isCancelled else { return }
                self.imageCache[question.id] = image
                self.failedImageIDs.remove(question.id)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self.failedImageIDs.insert(question.id)
                print(
                    "⚠️ [\(self.imageLogPrefix)] Failed to load image for \(question.id): \(error.localizedDescription)"
                )
            }

            if self.imageLoadHandles[question.id]?.token == token {
                self.imageLoadHandles[question.id] = nil
            }
        }

        imageLoadHandles[question.id] = ArenaImageLoadHandle(token: token, task: task)
        await task.value
        return imageCache[question.id] != nil
    }

    func scheduleArenaImageLoad(for question: QuizQuestion, forceReload: Bool = false) {
        guard forceReload
            || (imageCache[question.id] == nil
                && !failedImageIDs.contains(question.id)
                && imageLoadHandles[question.id] == nil)
        else {
            return
        }

        Task { [weak self] in
            guard let self else { return }
            _ = await self.loadArenaImage(for: question, forceReload: forceReload)
        }
    }

    func scheduleUpcomingArenaImages(
        for questions: [QuizQuestion],
        startingAt index: Int,
        prefetchCount: Int = 3
    ) {
        guard index < questions.count else { return }

        let upperBound = min(questions.count, index + prefetchCount + 1)
        for question in questions[index..<upperBound] {
            scheduleArenaImageLoad(for: question)
        }
    }

    @discardableResult
    func primeArenaImages(
        for questions: [QuizQuestion],
        currentIndex: Int = 0,
        prefetchCount: Int = 3
    ) async -> Bool {
        guard questions.indices.contains(currentIndex) else { return false }
        let currentQuestion = questions[currentIndex]
        let currentReady = await loadArenaImage(for: currentQuestion)
        scheduleUpcomingArenaImages(
            for: questions,
            startingAt: currentIndex + 1,
            prefetchCount: prefetchCount
        )
        return currentReady
    }

    func isArenaImageFailed(for question: QuizQuestion?) -> Bool {
        guard let question else { return false }
        return failedImageIDs.contains(question.id)
    }
}

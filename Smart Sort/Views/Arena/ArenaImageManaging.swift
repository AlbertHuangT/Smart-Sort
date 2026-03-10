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

struct ArenaImageState {
    var cachedImages: [UUID: UIImage] = [:]
    var failedImageIDs: Set<UUID> = []
    var loadHandles: [UUID: ArenaImageLoadHandle] = [:]

    mutating func reset() {
        cachedImages.removeAll()
        failedImageIDs.removeAll()
        loadHandles.removeAll()
    }
}

@MainActor
protocol ArenaImageManaging: AnyObject {
    var imageState: ArenaImageState { get set }
    var imageLogPrefix: String { get }
}

@MainActor
extension ArenaImageManaging {
    func cancelArenaImageLoads() {
        for handle in imageState.loadHandles.values {
            handle.task.cancel()
        }
        imageState.loadHandles.removeAll()
    }

    @discardableResult
    func loadArenaImage(for question: QuizQuestion, forceReload: Bool = false) async -> Bool {
        if !forceReload {
            if imageState.cachedImages[question.id] != nil {
                return true
            }
            if let existing = imageState.loadHandles[question.id] {
                await existing.task.value
                return imageState.cachedImages[question.id] != nil
            }
        } else {
            imageState.loadHandles[question.id]?.task.cancel()
            imageState.loadHandles[question.id] = nil
            imageState.cachedImages[question.id] = nil
            imageState.failedImageIDs.remove(question.id)
        }

        let token = UUID()
        let task = Task { [weak self] in
            guard let self else { return }

            do {
                let image = try await ArenaImageLoader.shared.loadImage(from: question.imageUrl)
                guard !Task.isCancelled else { return }
                self.imageState.cachedImages[question.id] = image
                self.imageState.failedImageIDs.remove(question.id)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self.imageState.failedImageIDs.insert(question.id)
                print(
                    "⚠️ [\(self.imageLogPrefix)] Failed to load image for \(question.id): \(error.localizedDescription)"
                )
            }

            if self.imageState.loadHandles[question.id]?.token == token {
                self.imageState.loadHandles[question.id] = nil
            }
        }

        imageState.loadHandles[question.id] = ArenaImageLoadHandle(token: token, task: task)
        await task.value
        return imageState.cachedImages[question.id] != nil
    }

    func scheduleArenaImageLoad(for question: QuizQuestion, forceReload: Bool = false) {
        guard forceReload
            || (imageState.cachedImages[question.id] == nil
                && !imageState.failedImageIDs.contains(question.id)
                && imageState.loadHandles[question.id] == nil)
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
        return imageState.failedImageIDs.contains(question.id)
    }

    func arenaImage(for question: QuizQuestion?) -> UIImage? {
        guard let question else { return nil }
        return imageState.cachedImages[question.id]
    }

    func isArenaImageReady(for question: QuizQuestion?) -> Bool {
        arenaImage(for: question) != nil
    }
}

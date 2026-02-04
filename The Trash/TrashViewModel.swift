//
//  TrashViewModel.swift
//  The Trash
//
//  Created by Albert Huang on 1/20/26.
//

import Foundation
import SwiftUI
import Combine
import Supabase
import UIKit

// MARK: - 1. Protocol
protocol TrashClassifierService {
    func classifyImage(image: UIImage, completion: @escaping (TrashAnalysisResult) -> Void)
}

// MARK: - 2. Mock Service
// Explicitly marked as nonisolated implicitly since it's a plain class,
// but let's make it Sendable-compliant if possible, or just a simple class.
class MockClassifierService: TrashClassifierService {
    func classifyImage(image: UIImage, completion: @escaping (TrashAnalysisResult) -> Void) {
        // Run on global queue to simulate background work
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
            let mockData = [
                TrashAnalysisResult(
                    itemName: "Mock-Soda Can",
                    category: "Recycle (Blue Bin)",
                    confidence: 0.98,
                    actionTip: "Empty liquids. Flatten to save space.",
                    color: .blue
                ),
                TrashAnalysisResult(
                    itemName: "Mock-Banana Peel",
                    category: "Compost (Green Bin)",
                    confidence: 0.95,
                    actionTip: "Organic waste.",
                    color: .green
                )
            ]
            let result = mockData.randomElement()!
            completion(result)
        }
    }
}

// MARK: - 3. ViewModel
@MainActor
class TrashViewModel: ObservableObject {
    @Published var appState: AppState = .idle
    
    private let classifier: TrashClassifierService
    private let client = SupabaseManager.shared.client
    
    // FIX: Removed default parameter from init to avoid "Main actor-isolated initializer" error
    // when default argument is evaluated in a non-isolated context.
    init(classifier: TrashClassifierService? = nil) {
        self.classifier = classifier ?? MockClassifierService()
    }
    
    func analyzeImage(image: UIImage) {
        guard appState != .analyzing else { return }
        
        self.appState = .analyzing
        let startTime = Date()
        
        classifier.classifyImage(image: image) { [weak self] result in
            // Calculate delay on whatever thread we are on
            let elapsedTime = Date().timeIntervalSince(startTime)
            let delay = max(0, 0.5 - elapsedTime)
            
            // Explicitly jump back to MainActor to update UI
            Task { @MainActor [weak self] in
                // Add artificial delay if needed
                if delay > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
                
                self?.appState = .finished(result)
                
                if result.confidence > 0.8 {
                    self?.grantPoints(amount: 10)
                }
            }
        }
    }
    
    // MARK: - Feedback Logic
    
    func handleCorrectFeedback() {
        print("✅ User confirmed result.")
        grantPoints(amount: 5)
        self.reset()
    }
    
    func prepareForIncorrectFeedback(wrongResult: TrashAnalysisResult) {
        appState = .collectingFeedback(wrongResult)
    }

    func submitCorrection(
        image: UIImage,
        originalResult: TrashAnalysisResult,
        correctedCategory: String,
        correctedName: String?
    ) async {
        print("--- 📤 SUBMITTING REPORT ---")
        
        do {
            try await FeedbackService.shared.submitFeedback(
                image: image,
                predictedLabel: originalResult.itemName,
                predictedCategory: originalResult.category,
                correctCategory: correctedCategory,
                comment: correctedName ?? "",
                userId: client.auth.currentUser?.id
            )
            print("✅ Report uploaded successfully")
            grantPoints(amount: 20)
        } catch {
            print("❌ Upload failed: \(error)")
        }
        
        self.reset()
    }
    
    func reset() {
        self.appState = .idle
    }
    
    // MARK: - Gamification
    
    func grantPoints(amount: Int) {
        Task {
            do {
                _ = try await client.rpc("increment_credits", params: ["amount": amount]).execute()
                print("🎉 Points granted: \(amount)")
            } catch {
                print("❌ [Gamification] Error: \(error)")
            }
        }
    }
}

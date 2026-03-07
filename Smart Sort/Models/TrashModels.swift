//
//  TrashModels.swift
//  Smart Sort
//
//  Created by Albert Huang on 1/20/26.
//

import Foundation
import SwiftUI

// 1. Trash analysis result
struct TrashAnalysisResult: Identifiable, Equatable {
    let id = UUID()
    let itemName: String
    let category: String
    let confidence: Double
    let actionTip: String
    let color: Color
}

// 2. App state (centralized here)
// Note: removed the duplicate definition from TrashViewModel.swift
enum AppState: Equatable {
    case idle
    case analyzing
    case finished(TrashAnalysisResult)
    // Additional states for the swipe-style feedback flow
    case collectingFeedback(TrashAnalysisResult)
    case submittingFeedback(TrashAnalysisResult)
    case error(String)
}

extension TrashAnalysisResult {
    var representsClassifierFailure: Bool {
        switch category {
        case "Error", "Retry", "Please Wait":
            return true
        default:
            return itemName == "System Error"
                || itemName == "AI Warming Up..."
                || itemName == "Analysis Failed"
                || itemName == "Image Error"
                || itemName == "Processing Error"
        }
    }
}

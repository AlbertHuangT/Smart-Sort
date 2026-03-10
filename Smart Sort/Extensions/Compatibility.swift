//
//  Compatibility.swift
//  Smart Sort
//
//  Backwards-compatibility wrappers for iOS 17+ / 18+ APIs
//  so the app can still deploy to iOS 16.6.
//

import SwiftUI

// MARK: - sensoryFeedback Replacement

extension View {
    /// Applies `.sensoryFeedback` on iOS 17+; no-op on older versions.
    @ViewBuilder
    func compatibleSensoryFeedback<T: Equatable>(
        _ feedback: SensoryFeedbackCompat,
        trigger: T
    ) -> some View {
        if #available(iOS 17.0, *) {
            self.sensoryFeedback(feedback.resolved, trigger: trigger)
        } else {
            self
        }
    }
}

/// A mirror of `SensoryFeedback` cases we use, so the call site
/// doesn't need its own `#available` checks.
enum SensoryFeedbackCompat {
    case success
    case warning
    case impactSolid(intensity: Double)
    case impactSoft(intensity: Double)

    @available(iOS 17.0, *)
    var resolved: SensoryFeedback {
        switch self {
        case .success:
            return .success
        case .warning:
            return .warning
        case .impactSolid(let intensity):
            return .impact(flexibility: .solid, intensity: intensity)
        case .impactSoft(let intensity):
            return .impact(flexibility: .soft, intensity: intensity)
        }
    }
}

// MARK: - symbolEffect Replacements

extension View {
    /// `.symbolEffect(.bounce, value:)` on iOS 17+; no-op on older.
    @ViewBuilder
    func compatibleBounceEffect<V: Equatable>(value: V) -> some View {
        if #available(iOS 17.0, *) {
            self.symbolEffect(.bounce, value: value)
        } else {
            self
        }
    }

    /// `.symbolEffect(.variableColor.iterative, isActive:)` on iOS 17+; no-op on older.
    @ViewBuilder
    func compatibleVariableColorEffect(isActive: Bool) -> some View {
        if #available(iOS 17.0, *) {
            self.symbolEffect(.variableColor.iterative, isActive: isActive)
        } else {
            self
        }
    }

    /// `.symbolEffect(.wiggle, value:)` on iOS 18+; bounces on iOS 17; no-op on older.
    @ViewBuilder
    func compatibleWiggleEffect<V: Equatable>(value: V) -> some View {
        if #available(iOS 18.0, *) {
            self.symbolEffect(.wiggle, value: value)
        } else if #available(iOS 17.0, *) {
            self.symbolEffect(.bounce, value: value)
        } else {
            self
        }
    }
}

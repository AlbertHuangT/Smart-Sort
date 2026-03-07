//
//  Compatibility.swift
//  Smart Sort
//
//  Backwards-compatibility wrappers for iOS 17+ / 18+ APIs
//  so the app can still deploy to iOS 16.6.
//

import SwiftUI

// MARK: - ContentUnavailableView Replacement

/// Drop-in replacement for `ContentUnavailableView` that falls back
/// to a simple VStack on iOS 16.
struct CompatibleContentUnavailableView<Label: View, Description: View, Actions: View>: View {
    let label: Label
    let description: Description
    let actions: Actions

    init(
        @ViewBuilder label: () -> Label,
        @ViewBuilder description: () -> Description = { EmptyView() },
        @ViewBuilder actions: () -> Actions = { EmptyView() }
    ) {
        self.label = label()
        self.description = description()
        self.actions = actions()
    }

    var body: some View {
        if #available(iOS 17.0, *) {
            ContentUnavailableView {
                label
            } description: {
                description
            } actions: {
                actions
            }
        } else {
            VStack(spacing: 12) {
                label
                    .font(.title2)
                    .foregroundColor(.secondary)
                description
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                actions
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
    }
}

extension CompatibleContentUnavailableView where Label == SwiftUI.Label<Text, Image>, Description == Text?, Actions == EmptyView {
    /// Equivalent to `ContentUnavailableView.search(text:)`
    static func search(text: String) -> some View {
        CompatibleContentUnavailableView<SwiftUI.Label<Text, Image>, Text, EmptyView>(
            label: { Label("No Results for \"\(text)\"", systemImage: "magnifyingglass") },
            description: { Text("Check the spelling or try a new search.") }
        )
    }
}

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

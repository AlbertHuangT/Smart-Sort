import SwiftUI
import UIKit

enum ThemeIconResolver {
    static let ecoMap: [String: String] = [
        "camera.viewfinder": "camera",
        "flame.fill": "leaf.fill",
        "chart.bar.fill": "chart.bar",
        "chart.bar.xaxis": "chart.bar",
        "person.3.fill": "person.3",
        "calendar.badge.clock": "calendar",
        "calendar.circle.fill": "calendar.circle",
        "building.2.fill": "building.2",
        "building.2.crop.circle": "building.2",
        "location.fill": "location",
        "location.slash.fill": "location.slash",
        "mappin.circle.fill": "mappin",
        "checkmark.circle.fill": "checkmark.circle",
        "xmark.circle.fill": "xmark.circle",
        "plus.circle.fill": "plus.circle",
        "lock.shield.fill": "lock.shield",
        "person.crop.circle.fill": "person.crop.circle",
        "shield.fill": "shield",
        "gift.fill": "gift",
    ]

    static func resolve(systemName: String) -> String {
        if let mapped = ecoMap[systemName] {
            return mapped
        }
        if let plain = inferredPlainVariant(for: systemName) {
            return plain
        }
        return systemName
    }

    private static func inferredPlainVariant(for systemName: String) -> String? {
        guard systemName.contains(".fill") else { return nil }
        let candidate = systemName.replacingOccurrences(of: ".fill", with: "")
        guard candidate != systemName else { return nil }
        return UIImage(systemName: candidate) == nil ? nil : candidate
    }
}

struct TrashIcon: View {
    let systemName: String
    private let theme = TrashTheme()

    var body: some View {
        let resolvedName = ThemeIconResolver.resolve(systemName: systemName)
        Image(systemName: resolvedName)
    }
}

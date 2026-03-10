import SwiftUI

// MARK: - SWShimmer

struct SWShimmer<Content: View>: View {
    @State private var animate = false

    var duration: Double = 2.0
    var delay: Double = 1.0

    @ViewBuilder let content: () -> Content

    init(
        duration: Double = 2.0,
        delay: Double = 1.0,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.duration = duration
        self.delay = delay
        self.content = content
    }

    private var gradient: LinearGradient {
        LinearGradient(
            colors: [.clear, .clear, .white.opacity(0.2), .clear, .clear],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        content()
            .overlay {
                GeometryReader { geo in
                    let bandWidth = geo.size.width * 0.5
                    gradient
                        .frame(width: bandWidth)
                        .offset(x: animate ? geo.size.width + bandWidth : -bandWidth * 1.5)
                        .animation(
                            .linear(duration: duration)
                                .delay(delay)
                                .repeatForever(autoreverses: false),
                            value: animate
                        )
                }
                .clipped()
            }
            .task {
                try? await Task.sleep(nanoseconds: 100_000_000)
                animate = true
            }
    }
}

// MARK: - Skeleton Row

/// 通用骨架行，用于列表加载占位
struct ShimmerSkeletonRow: View {
    var showAvatar: Bool = true
    private let theme = TrashTheme()

    var body: some View {
        SWShimmer {
            HStack(spacing: theme.layout.rowContentSpacing) {
                if showAvatar {
                    Circle()
                        .fill(theme.palette.divider.opacity(0.5))
                        .frame(width: 36, height: 36)
                }
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(theme.palette.divider.opacity(0.5))
                        .frame(width: 120, height: 12)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(theme.palette.divider.opacity(0.3))
                        .frame(width: 80, height: 10)
                }
                Spacer()
                RoundedRectangle(cornerRadius: 4)
                    .fill(theme.palette.divider.opacity(0.4))
                    .frame(width: 40, height: 12)
            }
            .padding(.horizontal, theme.layout.screenInset)
            .padding(.vertical, theme.spacing.sm + 2)
        }
    }
}

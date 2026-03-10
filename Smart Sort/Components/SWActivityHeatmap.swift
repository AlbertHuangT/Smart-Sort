import SwiftUI

/// GitHub-style activity heatmap with streak tracking.
/// Sub-components: StreakCard, HeatmapGrid, HeatmapLegend.
enum SWActivityHeatmap {

    // MARK: - Streak Info

    struct StreakInfo {
        let currentStreak: Int
        let startDate: Date?

        func displayText(
            noRecordsText: String = "No records yet. Start today!",
            startedTodayText: String = "Started today. Keep it up!",
            recordedYesterdayText: String = "You recorded yesterday. Continue today!"
        ) -> String {
            guard currentStreak > 0 else { return noRecordsText }
            if currentStreak == 1 {
                let calendar = Calendar.current
                if let startDate, calendar.isDateInToday(startDate) { return startedTodayText }
                return recordedYesterdayText
            }
            guard let startDate else { return "Current streak started \(currentStreak) days ago." }
            let calendar = Calendar.current
            let days = calendar.dateComponents([.day], from: startDate, to: Date()).day ?? 0
            if days == 0 { return "Current streak started today." }
            if days == 1 { return "Current streak started yesterday." }
            if days < 7 { return "Current streak started \(days) days ago." }
            if days < 30 { let w = days / 7; return "Current streak started \(w) week\(w == 1 ? "" : "s") ago." }
            let m = days / 30; return "Current streak started \(m) month\(m == 1 ? "" : "s") ago."
        }
    }

    // MARK: - Streak Calculation

    static func calculateStreak(from timestamps: [Date]) -> StreakInfo {
        guard !timestamps.isEmpty else { return StreakInfo(currentStreak: 0, startDate: nil) }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var recordsByDay = Set<Date>()
        for t in timestamps { recordsByDay.insert(calendar.startOfDay(for: t)) }
        let sortedDays = recordsByDay.sorted(by: >).filter { $0 <= today }
        guard let mostRecentDay = sortedDays.first else { return StreakInfo(currentStreak: 0, startDate: nil) }
        let daysSince = calendar.dateComponents([.day], from: mostRecentDay, to: today).day ?? 0
        if daysSince > 1 { return StreakInfo(currentStreak: 0, startDate: nil) }
        var streak = 1
        var streakStart = mostRecentDay
        var expected = calendar.date(byAdding: .day, value: -1, to: mostRecentDay)!
        for day in sortedDays.dropFirst() {
            if calendar.dateComponents([.day], from: expected, to: day).day == 0 {
                streak += 1; streakStart = day
                expected = calendar.date(byAdding: .day, value: -1, to: expected)!
            } else { break }
        }
        return StreakInfo(currentStreak: streak, startDate: streakStart)
    }

    // MARK: - Streak Card

    struct StreakCard: View {
        let streaks: [Date]
        let currentStreakTitle: String
        let colors: [Color]
        @Environment(\.trashTheme) private var theme

        init(streaks: [Date], currentStreakTitle: String = "Scan Streak", colors: [Color] = [.green, .teal]) {
            self.streaks = streaks; self.currentStreakTitle = currentStreakTitle; self.colors = colors
        }

        private var info: StreakInfo { calculateStreak(from: streaks) }

        var body: some View {
            HStack {
                Spacer()
                VStack {
                    Text(currentStreakTitle)
                        .font(theme.typography.headline)
                        .foregroundColor(theme.onAccentForeground)
                    VStack(spacing: -10) {
                        Text("\(info.currentStreak)").fontWeight(.bold).font(.system(size: 80))
                        Text(info.currentStreak == 1 ? "Day" : "Days").font(.title2).fontWeight(.semibold)
                    }
                    .foregroundColor(theme.onAccentForeground)
                    Text(info.displayText())
                        .font(theme.typography.caption)
                        .foregroundColor(theme.onAccentForeground.opacity(0.92))
                        .multilineTextAlignment(.center)
                }
                Spacer()
            }
            .padding(.vertical)
            .background(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
        }
    }

    // MARK: - Heatmap Grid

    struct HeatmapGrid: View {
        let timestamps: [Date]
        let days: Int
        let baseColor: Color
        let itemSize: CGFloat
        let spacing: CGFloat
        private let calendar = Calendar.current

        init(timestamps: [Date], days: Int = 60, baseColor: Color = .green, itemSize: CGFloat = 20, spacing: CGFloat = 3) {
            self.timestamps = timestamps; self.days = days
            self.baseColor = baseColor; self.itemSize = itemSize; self.spacing = spacing
        }

        private var countByDay: [Date: Int] {
            var counts = [Date: Int]()
            for t in timestamps { counts[calendar.startOfDay(for: t), default: 0] += 1 }
            return counts
        }

        private var targetDays: [Date] {
            let today = calendar.startOfDay(for: Date())
            return (0..<days).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
        }

        private func color(for count: Int) -> Color {
            switch count {
            case 0: baseColor.opacity(0.15)
            case 1: baseColor.opacity(0.4)
            case 2: baseColor.opacity(0.7)
            default: baseColor
            }
        }

        var body: some View {
            HStack {
                Spacer()
                FlowLayout(spacing: spacing) {
                    ForEach(targetDays, id: \.self) { date in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color(for: countByDay[date] ?? 0))
                            .frame(width: itemSize, height: itemSize)
                    }
                }
                Spacer()
            }
        }
    }

    // MARK: - Heatmap Legend

    struct HeatmapLegend: View {
        let baseColor: Color
        @Environment(\.trashTheme) private var theme
        init(baseColor: Color = .green) { self.baseColor = baseColor }

        var body: some View {
            HStack {
                Spacer()
                Text("Less")
                HStack(spacing: 3) {
                    ForEach([0.15, 0.4, 0.7, 1.0], id: \.self) { opacity in
                        RoundedRectangle(cornerRadius: 2).fill(baseColor.opacity(opacity)).frame(width: 12, height: 12)
                    }
                }
                Text("More")
            }
            .font(.caption)
            .foregroundColor(theme.palette.textSecondary)
        }
    }

    // MARK: - Flow Layout

    struct FlowLayout: Layout {
        let spacing: CGFloat
        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
            let r = FlowResult(in: proposal.width ?? .infinity, subviews: subviews, spacing: spacing)
            return r.size
        }
        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
            let r = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
            for (i, sv) in subviews.enumerated() {
                sv.place(at: CGPoint(x: bounds.minX + r.positions[i].x, y: bounds.minY + r.positions[i].y),
                         proposal: ProposedViewSize(r.sizes[i]))
            }
        }
        struct FlowResult {
            let size: CGSize; let positions: [CGPoint]; let sizes: [CGSize]
            init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
                var positions = [CGPoint](); var sizes = [CGSize]()
                var x: CGFloat = 0; var y: CGFloat = 0; var lineH: CGFloat = 0; var maxX: CGFloat = 0
                for sv in subviews {
                    let s = sv.sizeThatFits(.unspecified); sizes.append(s)
                    if x + s.width > maxWidth && x > 0 { x = 0; y += lineH + spacing; lineH = 0 }
                    positions.append(CGPoint(x: x, y: y))
                    lineH = max(lineH, s.height); x += s.width + spacing; maxX = max(maxX, x - spacing)
                }
                self.size = CGSize(width: maxX, height: y + lineH)
                self.positions = positions; self.sizes = sizes
            }
        }
    }
}

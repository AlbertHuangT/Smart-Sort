import SwiftUI

/// Apple Watch Activity Rings style concentric progress chart.
struct SWRingChart<Center: View>: View {

    struct DataPoint: Identifiable {
        let id = UUID()
        let label: String
        let value: Double
        let color: Color
    }

    let data: [DataPoint]
    var maxValue: Double = 100
    var size: CGFloat = 200
    var ringWidth: CGFloat = 22
    var spacing: CGFloat = 8
    @ViewBuilder let center: () -> Center
    @State private var animatedValues: [Double]

    init(data: [DataPoint], maxValue: Double = 100, size: CGFloat = 200,
         ringWidth: CGFloat = 22, spacing: CGFloat = 8,
         @ViewBuilder center: @escaping () -> Center) {
        self.data = data; self.maxValue = maxValue; self.size = size
        self.ringWidth = ringWidth; self.spacing = spacing; self.center = center
        self._animatedValues = State(initialValue: Array(repeating: 0, count: data.count))
    }

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                ForEach(Array(data.enumerated()), id: \.element.id) { index, item in
                    let ringIndex = CGFloat(data.count - 1 - index)
                    let ringSize = size - ringIndex * (ringWidth + spacing) * 2
                    Circle()
                        .stroke(item.color.opacity(0.15),
                                style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                        .frame(width: ringSize, height: ringSize)
                    Circle()
                        .trim(from: 0, to: min(animatedValues[index] / maxValue, 1.0))
                        .stroke(item.color,
                                style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: ringSize, height: ringSize)
                }
                center()
            }
            HStack(spacing: 16) {
                ForEach(data) { item in
                    HStack(spacing: 4) {
                        Capsule().fill(item.color).frame(width: 3, height: 10)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.label).font(.caption2).foregroundStyle(.secondary)
                            Text("\(Int(item.value))").font(.caption.bold()).foregroundStyle(.primary)
                        }
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2).delay(0.2)) {
                for i in data.indices { animatedValues[i] = data[i].value }
            }
        }
    }
}

extension SWRingChart where Center == EmptyView {
    init(data: [DataPoint], maxValue: Double = 100, size: CGFloat = 200,
         ringWidth: CGFloat = 22, spacing: CGFloat = 8) {
        self.init(data: data, maxValue: maxValue, size: size,
                  ringWidth: ringWidth, spacing: spacing) { EmptyView() }
    }
}

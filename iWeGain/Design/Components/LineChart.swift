import SwiftUI

struct LineChartPoint: Equatable {
    let slot: Int
    let value: Double
}

struct LineChartTick: Equatable {
    let slot: Int
    let label: String
}

/// Data for [LineChart]: [slotCount] equal slots (days or months); each point sits in the middle of its
/// slot. [grid] holds three values, top first, with their [gridLabels].
struct LineChartUi: Equatable {
    let slotCount: Int
    let points: [LineChartPoint]
    let grid: [Double]
    let gridLabels: [String]
    let ticks: [LineChartTick]
    let description: String
}

/// Progress line with a soft fill, a dot per value, gridlines with labels and x-axis labels (Figma "Line Chart").
struct LineChart: View {
    let chart: LineChartUi

    private static let left: CGFloat = 28
    private static let top: CGFloat = 8
    private static let bottom: CGFloat = 118
    private static let labelY: CGFloat = 134

    var body: some View {
        Canvas { context, size in
            guard chart.grid.count == 3, chart.grid[0] > chart.grid[2] else { return }
            let plotWidth = size.width - Self.left
            let x = { (slot: Int) in Self.left + plotWidth * (CGFloat(slot) + 0.5) / CGFloat(chart.slotCount) }
            let y = { (value: Double) in
                Self.top + (Self.bottom - Self.top) * CGFloat((chart.grid[0] - value) / (chart.grid[0] - chart.grid[2]))
            }

            for (index, label) in chart.gridLabels.enumerated() {
                let lineY = Self.top + (Self.bottom - Self.top) * CGFloat(index) / 2
                var line = Path()
                line.move(to: CGPoint(x: Self.left, y: lineY))
                line.addLine(to: CGPoint(x: size.width, y: lineY))
                context.stroke(line, with: .color(.borderDefault), lineWidth: 1)
                context.draw(context.resolve(Self.label(label)), at: CGPoint(x: 0, y: lineY), anchor: .leading)
            }

            let points = chart.points.map { CGPoint(x: x($0.slot), y: y($0.value)) }
            if let first = points.first, let last = points.last, points.count > 1 {
                var line = Path()
                line.addLines(points)
                var area = line
                area.addLine(to: CGPoint(x: last.x, y: Self.bottom))
                area.addLine(to: CGPoint(x: first.x, y: Self.bottom))
                area.closeSubpath()
                context.fill(area, with: .color(.accentPrimary.opacity(0.14)))
                context.stroke(line, with: .color(.accentPrimary), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }
            for (index, point) in points.enumerated() {
                if index == points.count - 1 {
                    // The latest value: a larger dot with a ring in the card color.
                    context.fill(Self.circle(point, 9), with: .color(.bgSurface))
                    context.fill(Self.circle(point, 6), with: .color(.accentPrimary))
                } else {
                    context.fill(Self.circle(point, 3), with: .color(.accentPrimary))
                }
            }

            for tick in chart.ticks {
                let text = context.resolve(Self.label(tick.label))
                let width = text.measure(in: size).width
                let labelX = min(max(x(tick.slot) - width / 2, Self.left), size.width - width)
                context.draw(text, at: CGPoint(x: labelX, y: Self.labelY), anchor: .topLeading)
            }
        }
        .frame(height: 150)
        .accessibilityElement()
        .accessibilityLabel(chart.description)
    }

    private static func label(_ text: String) -> Text {
        Text(text).font(AppTextStyle.tabLabel.font).foregroundColor(.textTertiary)
    }

    private static func circle(_ center: CGPoint, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }
}

#Preview {
    LineChart(chart: LineChartUi(
        slotCount: 30,
        points: [LineChartPoint(slot: 0, value: 92.5), LineChartPoint(slot: 14, value: 97.5), LineChartPoint(slot: 28, value: 100)],
        grid: [100, 95, 90],
        gridLabels: ["100", "95", "90"],
        ticks: [LineChartTick(slot: 0, label: "1"), LineChartTick(slot: 14, label: "15"), LineChartTick(slot: 28, label: "29")],
        description: ""
    ))
    .padding()
    .background(Color.bgSurface)
}

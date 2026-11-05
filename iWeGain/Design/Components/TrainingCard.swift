import SwiftUI

/// Training summary card used on Home and Calendar: icon, name, then a row of [Metric]s.
struct TrainingCard: View {
    let title: String
    let icon: String
    var subtitle: String?
    let metrics: [Metric]
    /// Shown at the end of the metrics row, e.g. "Completed" on the calendar.
    var trailing: StatusChip?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Spacing.x12) {
                HStack(spacing: Spacing.x12) {
                    IconBadge(asset: icon)
                    VStack(alignment: .leading, spacing: Spacing.x2) {
                        Text(title).textStyle(.headline).foregroundStyle(Color.textPrimary).lineLimit(1)
                        if let subtitle {
                            Text(subtitle).textStyle(.footnote).foregroundStyle(Color.textSecondary).lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image("ic_chevron_right")
                        .resizable()
                        .frame(width: 20, height: 20)
                        .foregroundStyle(Color.textTertiary)
                }
                Rectangle().fill(Color.borderDefault).frame(height: 1)
                HStack(spacing: Spacing.x16) {
                    ForEach(metrics, id: \.self) { MetricView(metric: $0) }
                    if let trailing {
                        Spacer(minLength: 0)
                        trailing
                    }
                }
            }
            .padding(Spacing.x16)
            .background(Color.bgSurface, in: .rect(cornerRadius: Radius.lg))
            .contentShape(.rect(cornerRadius: Radius.lg))
        }
        .buttonStyle(.pressable)
    }
}

/// Small icon + value pair, e.g. "6 exercises".
struct Metric: Hashable {
    let icon: String
    let text: String
}

private struct MetricView: View {
    let metric: Metric

    var body: some View {
        HStack(spacing: Spacing.x4) {
            Image(metric.icon).resizable().frame(width: 16, height: 16).foregroundStyle(Color.textSecondary)
            Text(metric.text).textStyle(.footnote).foregroundStyle(Color.textSecondary)
        }
    }
}

#Preview {
    TrainingCard(
        title: "Push Day", icon: "ic_dumbbell",
        metrics: [Metric(icon: "ic_dumbbell", text: "6 exercises"), Metric(icon: "ic_check", text: "24 sets")],
        action: {}
    )
    .padding()
    .background(Color.bgBase)
}

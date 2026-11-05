import SwiftUI

/// Scheduled training on the calendar (Figma "Planned Training Card"): the training's icon on a blue
/// tile (planned, as opposed to the green tiles of done workouts), name, time range and status.
/// [repeats] adds a repeat icon after the time for a weekly series.
struct PlannedTrainingCard: View {
    let icon: String
    let title: String
    let time: String
    var repeats = false
    let status: StatusChip
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Spacing.x12) {
                HStack(spacing: Spacing.x12) {
                    IconBadge(asset: icon, foreground: .dataBlue, background: .dataBlueSoft)
                    Text(title)
                        .textStyle(.headline)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image("ic_chevron_right")
                        .resizable()
                        .frame(width: 20, height: 20)
                        .foregroundStyle(Color.textTertiary)
                }
                Rectangle().fill(Color.borderDefault).frame(height: 1)
                HStack(spacing: Spacing.x4) {
                    Image("ic_clock").resizable().frame(width: 16, height: 16).foregroundStyle(Color.textPrimary)
                    Text(time).textStyle(.footnote).foregroundStyle(Color.textPrimary)
                    if repeats {
                        Image("ic_repeat")
                            .resizable()
                            .frame(width: 16, height: 16)
                            .foregroundStyle(Color.textSecondary)
                            .padding(.leading, Spacing.x4)
                            .accessibilityLabel(Text("calendar_repeats_weekly"))
                    }
                    Spacer(minLength: Spacing.x8)
                    status
                }
            }
            .padding(Spacing.x16)
            .background(Color.bgSurface, in: .rect(cornerRadius: Radius.lg))
            .contentShape(.rect(cornerRadius: Radius.lg))
        }
        .buttonStyle(.pressable)
    }
}

#Preview {
    PlannedTrainingCard(icon: "ic_zap", title: "Pull Day", time: "18:00 – 19:00", repeats: true, status: .scheduled, action: {})
        .padding()
        .background(Color.bgBase)
}

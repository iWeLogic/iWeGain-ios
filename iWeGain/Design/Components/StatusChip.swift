import SwiftUI

/// Training status pill (Figma "Status Chip"): colored dot + label on a soft tint.
struct StatusChip: View {
    let label: LocalizedStringKey
    let color: Color
    let background: Color

    var body: some View {
        HStack(spacing: Spacing.x4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).textStyle(.caption).foregroundStyle(color).lineLimit(1)
        }
        .padding(.horizontal, Spacing.x8)
        .padding(.vertical, Spacing.x4)
        .background(background, in: .capsule)
    }
}

extension StatusChip {
    static var completed: StatusChip { StatusChip(label: "calendar_status_completed", color: .accentPrimary, background: .accentSoft) }
    static var scheduled: StatusChip { StatusChip(label: "calendar_status_scheduled", color: .dataBlue, background: .dataBlueSoft) }
    static var missed: StatusChip { StatusChip(label: "calendar_status_missed", color: .statusDanger, background: .statusDangerSoft) }
}

#Preview {
    HStack {
        StatusChip.completed
        StatusChip.scheduled
        StatusChip.missed
    }
    .padding()
    .background(Color.bgBase)
}

import SwiftUI

/// Small uppercase group label, e.g. "EXERCISES · 3", with an optional hint on the right.
struct SectionLabel: View {
    let text: String
    var trailing: String?

    var body: some View {
        HStack {
            Text(text.uppercased())
            Spacer(minLength: Spacing.x8)
            if let trailing { Text(trailing) }
        }
        .textStyle(.caption)
        .foregroundStyle(Color.textTertiary)
        .accessibilityAddTraits(.isHeader)
    }
}

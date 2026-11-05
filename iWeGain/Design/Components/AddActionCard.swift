import SwiftUI

/// Dashed card with a "+" badge, placed as the last item of a list to create a new item.
struct AddActionCard: View {
    let title: LocalizedStringResource
    let subtitle: LocalizedStringResource
    let action: () -> Void
    /// Something has to be added first: red border.
    var isError = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.x12) {
                IconBadge(asset: "ic_plus", foreground: .accentOn, background: .accentPrimary)
                VStack(alignment: .leading, spacing: Spacing.x2) {
                    Text(title).textStyle(.headline).foregroundStyle(Color.textPrimary)
                    Text(subtitle).textStyle(.footnote).foregroundStyle(Color.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Spacing.x16)
            .background(Color.addCardBackground, in: .rect(cornerRadius: Radius.lg))
            .modifier(AddCardBorder(isError: isError))
            .contentShape(.rect(cornerRadius: Radius.lg))
        }
        .buttonStyle(.pressable)
    }
}

private struct AddCardBorder: ViewModifier {
    let isError: Bool

    func body(content: Content) -> some View {
        if isError {
            content.insideBorder(.statusDanger, cornerRadius: Radius.lg)
        } else {
            content.dashedBorder(.addCardBorder, cornerRadius: Radius.lg)
        }
    }
}

#Preview {
    VStack {
        AddActionCard(title: "Add training", subtitle: "Log a workout or plan a new one", action: {})
        AddActionCard(title: "Add exercise", subtitle: "Choose from the exercise library", action: {}, isError: true)
    }
    .padding()
    .background(Color.bgBase)
}

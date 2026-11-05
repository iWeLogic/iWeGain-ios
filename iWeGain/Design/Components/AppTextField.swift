import SwiftUI

/// Single-line text field. Shows an accent border while focused; with [dashedWhenEmpty], a dashed border
/// while it is empty and not focused. When not [isEnabled] it only displays the text (read-only screens).
struct AppTextField: View {
    let placeholder: LocalizedStringResource
    let text: String
    let onTextChange: (String) -> Void
    var dashedWhenEmpty = false
    var isEnabled = true
    /// A required field left empty: red border until it's filled.
    var isError = false
    var background: Color = .bgSurface

    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(text: Binding(get: { text }, set: { onTextChange($0) }), prompt: Text(placeholder).foregroundStyle(Color.textTertiary)) {
            Text(placeholder)
        }
        .textStyle(.body)
        .foregroundStyle(Color.textPrimary)
        .tint(Color.accentPrimary)
        .submitLabel(.done)
        .focused($isFocused)
        .disabled(!isEnabled)
        .padding(.horizontal, Spacing.x16)
        .padding(.vertical, Spacing.x12)
        .background(background, in: .rect(cornerRadius: Radius.md))
        .modifier(FieldBorder(style: borderStyle))
        .animation(.easeOut(duration: 0.15), value: isFocused)
    }

    private var borderStyle: FieldBorder.Style {
        if isError { return .error }
        if isFocused { return .focused }
        if isEnabled && dashedWhenEmpty && text.isEmpty { return .dashed }
        return .none
    }
}

private struct FieldBorder: ViewModifier {
    enum Style { case none, dashed, focused, error }
    let style: Style

    func body(content: Content) -> some View {
        switch style {
        case .none: content
        case .dashed: content.dashedBorder(.borderDefault, cornerRadius: Radius.md, dash: 4, gap: 3)
        case .focused: content.insideBorder(.accentPrimary, cornerRadius: Radius.md)
        case .error: content.insideBorder(.statusDanger, cornerRadius: Radius.md)
        }
    }
}

/// Search box with a magnifier.
struct SearchField: View {
    let placeholder: LocalizedStringResource
    let text: String
    let onTextChange: (String) -> Void

    var body: some View {
        HStack(spacing: Spacing.x8) {
            Image("ic_search").resizable().frame(width: 20, height: 20).foregroundStyle(Color.textTertiary)
            TextField(text: Binding(get: { text }, set: { onTextChange($0) }), prompt: Text(placeholder).foregroundStyle(Color.textTertiary)) {
                Text(placeholder)
            }
            .textStyle(.body)
            .foregroundStyle(Color.textPrimary)
            .tint(Color.accentPrimary)
            .submitLabel(.search)
            .autocorrectionDisabled()
            if !text.isEmpty {
                Button { onTextChange("") } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Color.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("action_close"))
            }
        }
        .padding(Spacing.x12)
        .background(Color.bgSurface, in: .rect(cornerRadius: Radius.md))
    }
}

#Preview {
    VStack(spacing: Spacing.x12) {
        AppTextField(placeholder: "Training name", text: "", onTextChange: { _ in }, dashedWhenEmpty: true)
        AppTextField(placeholder: "Training name", text: "Push Day", onTextChange: { _ in })
        AppTextField(placeholder: "Training name", text: "", onTextChange: { _ in }, isError: true)
        SearchField(placeholder: "Search exercises", text: "", onTextChange: { _ in })
    }
    .padding()
    .background(Color.bgBase)
}

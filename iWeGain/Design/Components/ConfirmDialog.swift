import SwiftUI

/// Centered card dialog (Figma "Join Team", "Remove Member"): optional [header] such as an avatar, title,
/// message, a main button ([isDestructive] makes it red) and a text button to dismiss.
struct ConfirmDialog<Header: View>: View {
    let title: String
    let message: String
    let confirmText: String
    let dismissText: String
    var isDestructive = false
    var isWorking = false
    var isConfirmEnabled = true
    let onConfirm: () -> Void
    let onDismiss: () -> Void
    @ViewBuilder var header: Header

    var body: some View {
        let isEnabled = isConfirmEnabled && !isWorking
        VStack(spacing: Spacing.x12) {
            header
            Text(title)
                .textStyle(.title2)
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)
            Text(message)
                .textStyle(.callout)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
            Button(action: onConfirm) {
                Text(confirmText)
                    .textStyle(.headline)
                    .foregroundStyle(!isEnabled ? Color.textTertiary : isDestructive ? Color.textPrimary : Color.accentOn)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(!isEnabled ? Color.bgSurface2 : isDestructive ? Color.statusDanger : Color.accentPrimary, in: .rect(cornerRadius: Radius.md))
                    .contentShape(.rect(cornerRadius: Radius.md))
            }
            .buttonStyle(.pressable)
            .disabled(!isEnabled)
            .padding(.top, Spacing.x8)
            Button(action: onDismiss) {
                Text(dismissText)
                    .textStyle(.headline)
                    .foregroundStyle(Color.textSecondary)
                    .padding(.horizontal, Spacing.x16)
                    .padding(.vertical, Spacing.x8)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.x20)
        .padding(.vertical, Spacing.x24)
        .background(Color.bgSurface, in: .rect(cornerRadius: Radius.xl))
        .padding(.horizontal, Spacing.x24)
        .frame(maxWidth: 440)
    }
}

extension ConfirmDialog where Header == EmptyView {
    init(title: String, message: String, confirmText: String, dismissText: String, isDestructive: Bool = false, isWorking: Bool = false,
         isConfirmEnabled: Bool = true, onConfirm: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        self.init(title: title, message: message, confirmText: confirmText, dismissText: dismissText, isDestructive: isDestructive, isWorking: isWorking,
                  isConfirmEnabled: isConfirmEnabled, onConfirm: onConfirm, onDismiss: onDismiss, header: { EmptyView() })
    }
}

extension View {
    /// Shows [content] centered above everything else, the tab bar included, on a dimmed background.
    func centeredDialog<Dialog: View>(isPresented: Bool, onDismiss: @escaping () -> Void, @ViewBuilder content: @escaping () -> Dialog) -> some View {
        let binding = Binding(get: { isPresented }, set: { if !$0 { onDismiss() } })
        #if os(iOS)
        return fullScreenCover(isPresented: binding) {
            ZStack {
                Color.black.opacity(0.5).ignoresSafeArea().onTapGesture(perform: onDismiss)
                content()
            }
            .presentationBackground(.clear)
        }
        .transaction { $0.disablesAnimations = true }
        #else
        return sheet(isPresented: binding) { content().padding() }
        #endif
    }
}

#Preview {
    ConfirmDialog(
        title: "Delete account?", message: "This can't be undone.", confirmText: "Delete account (8)", dismissText: "Cancel",
        isDestructive: true, isConfirmEnabled: false, onConfirm: {}, onDismiss: {}
    )
    .frame(maxHeight: .infinity)
    .background(Color.bgBase)
}

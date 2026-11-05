import SwiftUI

extension View {
    /// Shows [message] in an alert while it isn't nil; dismissing it sets it back to nil.
    func errorAlert(_ message: Binding<LocalizedStringResource?>) -> some View {
        alert(
            "error_title",
            isPresented: Binding(get: { message.wrappedValue != nil }, set: { if !$0 { message.wrappedValue = nil } }),
            actions: { Button("action_ok") {} },
            message: { if let text = message.wrappedValue { Text(text) } }
        )
    }
}

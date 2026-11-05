import SwiftUI

struct SignInRoot: View {
    @State private var viewModel: SignInViewModel
    @State private var message: String?
    private let onClose: () -> Void

    init(viewModel: @autoclosure () -> SignInViewModel, onClose: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel())
        self.onClose = onClose
    }

    var body: some View {
        SignInScreen(state: viewModel.state, onAction: viewModel.onAction)
            .onEvents(of: viewModel) { event in
                switch event {
                case .close: onClose()
                case .showMessage(let text): message = text
                }
            }
            .alert(
                Text(message ?? ""),
                isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } }),
                actions: { Button("action_ok") {} }
            )
    }
}

struct SignInScreen: View {
    let state: SignInState
    let onAction: (SignInAction) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.x16) {
                IconBadge(asset: "ic_dumbbell", size: 88, iconSize: 44, cornerRadius: 24, foreground: .accentOn, background: .accentPrimary)
                Text("iWeGain").textStyle(.largeTitle).foregroundStyle(Color.textPrimary)
                Text("sign_in_message")
                    .textStyle(.callout)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Spacing.x24)
            .padding(.vertical, Spacing.x40)
            VStack(spacing: Spacing.x12) {
                Button { onAction(.onGoogleTap) } label: {
                    HStack(spacing: Spacing.x12) {
                        if state.isGoogleLoading {
                            ProgressView()
                        } else {
                            Image("ic_google").renderingMode(.original).resizable().frame(width: 20, height: 20)
                        }
                        Text("sign_in_google")
                    }
                }
                .buttonStyle(.appSecondary)
                .disabled(state.isGoogleLoading)
                LegalConsentText()
            }
            .padding(Spacing.x16)
            .padding(.top, 84)
        }
        .background(Color.bgBase)
        .navigationTitle("")
        .navigationBarBackButtonHidden()
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button(role: .close) { onAction(.onCloseTap) } }
        }
    }
}

/// "By continuing you agree to the Terms and Privacy Policy", with both as links.
struct LegalConsentText: View {
    var body: some View {
        Text(Self.text)
            .textStyle(.footnote)
            .foregroundStyle(Color.textTertiary)
            .multilineTextAlignment(.center)
            .tint(Color.textSecondary)
    }

    private static var text: AttributedString {
        let terms = Strings.text("sign_in_terms_link")
        let privacy = Strings.text("sign_in_privacy_link")
        var result = AttributedString(Strings.format("sign_in_terms", terms, privacy))
        if let range = result.range(of: terms) { result[range].link = LegalLinks.terms }
        if let range = result.range(of: privacy) { result[range].link = LegalLinks.privacy }
        return result
    }
}

#Preview {
    NavigationStack { SignInScreen(state: SignInState(), onAction: { _ in }) }
}

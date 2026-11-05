import SwiftUI

struct AddPersonChoiceRoot: View {
    @State private var viewModel: AddPersonChoiceViewModel
    private let onNavigateToCreateProfile: () -> Void
    private let onNavigateToInvite: () -> Void
    private let onNavigateToSignIn: () -> Void
    private let onClose: () -> Void

    init(
        viewModel: @autoclosure () -> AddPersonChoiceViewModel,
        onNavigateToCreateProfile: @escaping () -> Void,
        onNavigateToInvite: @escaping () -> Void,
        onNavigateToSignIn: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: viewModel())
        self.onNavigateToCreateProfile = onNavigateToCreateProfile
        self.onNavigateToInvite = onNavigateToInvite
        self.onNavigateToSignIn = onNavigateToSignIn
        self.onClose = onClose
    }

    var body: some View {
        AddPersonChoiceScreen(state: viewModel.state, onAction: viewModel.onAction)
            .onEvents(of: viewModel) { event in
                switch event {
                case .close: onClose()
                case .navigateToCreateProfile: onNavigateToCreateProfile()
                case .navigateToInvite: onNavigateToInvite()
                case .navigateToSignIn: onNavigateToSignIn()
                }
            }
            .task { viewModel.onAction(.onAppear) }
    }
}

/// Figma "21a · Add Person · Choose" and, signed out, "21e · Add Person · Signed Out".
struct AddPersonChoiceScreen: View {
    let state: AddPersonChoiceState
    let onAction: (AddPersonChoiceAction) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.x16) {
                AvatarPair(me: state.me)
                Text("add_person_heading").textStyle(.title2).foregroundStyle(Color.textPrimary)
                Text("add_person_choice_message")
                    .textStyle(.callout)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                VStack(spacing: Spacing.x12) {
                    if !state.isSignedIn { SignInNote() }
                    OptionCard(icon: "ic_user", title: "add_person_create_profile", subtitle: "add_person_create_profile_hint", action: { onAction(.onCreateProfileTap) })
                        .disabled(!state.isSignedIn)
                        .opacity(state.isSignedIn ? 1 : 0.4)
                    OptionCard(icon: "ic_link", title: "add_person_invite", subtitle: "add_person_invite_hint", action: { onAction(.onInviteTap) })
                        .disabled(!state.isSignedIn)
                        .opacity(state.isSignedIn ? 1 : 0.4)
                }
                .padding(.top, Spacing.x8)
            }
            .padding(Spacing.x16)
        }
        .background(Color.bgBase)
        .navigationTitle(Text("add_person_title"))
        .inlineNavigationTitle()
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button(role: .close) { onAction(.onCloseTap) } }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !state.isSignedIn {
                Button("settings_sign_in") { onAction(.onSignInTap) }
                    .buttonStyle(.appPrimary)
                    .padding(.horizontal, Spacing.x16)
                    .padding(.top, Spacing.x12)
                    .padding(.bottom, Spacing.x8)
                    .background(Color.bgBase)
            }
        }
    }
}

private struct SignInNote: View {
    var body: some View {
        HStack(spacing: Spacing.x12) {
            Image("ic_user").resizable().frame(width: 20, height: 20).foregroundStyle(Color.accentPrimary)
            VStack(alignment: .leading, spacing: Spacing.x2) {
                Text("add_person_sign_in_title").textStyle(.subhead).foregroundStyle(Color.textPrimary)
                Text("add_person_sign_in_message").textStyle(.footnote).foregroundStyle(Color.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Spacing.x16)
        .padding(.vertical, Spacing.x12)
        .background(Color.accentSoft, in: .rect(cornerRadius: Radius.md))
        .insideBorder(.accentPrimary, cornerRadius: Radius.md, lineWidth: 1)
    }
}

#Preview("Signed in") {
    NavigationStack {
        AddPersonChoiceScreen(
            state: AddPersonChoiceState(me: UserUi(id: "1", name: "Alex Kim", initials: "AK", avatarColor: .blue, isSelected: true)),
            onAction: { _ in }
        )
    }
}

#Preview("Signed out") {
    NavigationStack { AddPersonChoiceScreen(state: AddPersonChoiceState(isSignedIn: false), onAction: { _ in }) }
}

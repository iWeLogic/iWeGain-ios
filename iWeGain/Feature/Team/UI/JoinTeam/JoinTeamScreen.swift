import SwiftUI

struct JoinTeamRoot: View {
    @State private var viewModel: JoinTeamViewModel
    @State private var message: String?
    private let onClose: () -> Void

    init(viewModel: @autoclosure () -> JoinTeamViewModel, onClose: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel())
        self.onClose = onClose
    }

    var body: some View {
        JoinTeamScreen(state: viewModel.state, onAction: viewModel.onAction)
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
            .task { viewModel.onAction(.onAppear) }
    }
}

struct JoinTeamScreen: View {
    let state: JoinTeamState
    let onAction: (JoinTeamAction) -> Void

    var body: some View {
        ZStack {
            Color.bgBase.ignoresSafeArea()
            if state.isLoading {
                ProgressView().tint(Color.accentPrimary)
            } else if let error = state.error {
                DialogBackdrop(onDismiss: { onAction(.onNotNowTap) }) {
                    ConfirmDialog(
                        title: Strings.text("join_team_error_title"),
                        message: error,
                        confirmText: Strings.text("action_ok"),
                        dismissText: Strings.text("action_close"),
                        onConfirm: { onAction(.onNotNowTap) },
                        onDismiss: { onAction(.onNotNowTap) }
                    )
                }
            } else if !state.isSignedIn {
                SignInToJoin(state: state, onAction: onAction)
            } else {
                DialogBackdrop(onDismiss: { onAction(.onNotNowTap) }) {
                    ConfirmDialog(
                        title: Strings.format("join_team_title", state.ownerName),
                        message: Strings.format("join_team_message", state.ownerName),
                        confirmText: Strings.text("join_team_confirm"),
                        dismissText: Strings.text("join_team_not_now"),
                        isWorking: state.isJoining,
                        onConfirm: { onAction(.onJoinTap) },
                        onDismiss: { onAction(.onNotNowTap) }
                    ) {
                        Avatar(initials: state.ownerInitials, color: .blue, size: 48)
                            .padding(3)
                            .overlay(Circle().inset(by: 1).stroke(Color.accentPrimary, lineWidth: 2))
                    }
                }
            }
        }
        .hidesNavigationBar()
    }
}

/// The dialogs are all this screen shows, so they're drawn in place: leaving closes the screen with them.
private struct DialogBackdrop<Content: View>: View {
    let onDismiss: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea().onTapGesture(perform: onDismiss)
            content
        }
    }
}

/// Figma "22 · Invite · Sign In": who invited me, then the sign-in buttons.
private struct SignInToJoin: View {
    let state: JoinTeamState
    let onAction: (JoinTeamAction) -> Void

    var body: some View {
        VStack(spacing: Spacing.x16) {
            Button { onAction(.onNotNowTap) } label: {
                Image("ic_x")
                    .resizable()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(Color.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(Color.bgSurface, in: .circle)
                    .contentShape(.circle)
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(Text("action_close"))
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: Spacing.x12) {
                Avatar(initials: state.ownerInitials, color: .blue, size: 32)
                VStack(alignment: .leading, spacing: 0) {
                    Text(Strings.format("join_team_invited_you", state.ownerName)).textStyle(.headline).foregroundStyle(Color.textPrimary)
                    Text("join_team_sign_in_hint").textStyle(.footnote).foregroundStyle(Color.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Spacing.x12)
            .background(Color.accentSoft, in: .rect(cornerRadius: Radius.lg))
            .insideBorder(.accentPrimary, cornerRadius: Radius.lg, lineWidth: 1)
            Spacer(minLength: 0)
            IconBadge(asset: "ic_dumbbell", size: 88, iconSize: 44, cornerRadius: Radius.xl, foreground: .accentOn, background: .accentPrimary)
            Text("iWeGain").textStyle(.largeTitle).foregroundStyle(Color.textPrimary)
            Text(Strings.format("join_team_sign_in_message", state.ownerName))
                .textStyle(.callout)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
            Button { onAction(.onGoogleTap) } label: {
                HStack(spacing: Spacing.x12) {
                    if state.isSigningIn {
                        ProgressView()
                    } else {
                        Image("ic_google").renderingMode(.original).resizable().frame(width: 20, height: 20)
                    }
                    Text("sign_in_google")
                }
            }
            .buttonStyle(.appSecondary)
            .disabled(state.isSigningIn)
            LegalConsentText()
        }
        .padding(Spacing.x16)
    }
}

#Preview("Signed out") {
    JoinTeamScreen(state: JoinTeamState(isLoading: false, ownerName: "Alex Kim", ownerInitials: "AK"), onAction: { _ in })
}

#Preview("Join") {
    JoinTeamScreen(state: JoinTeamState(isLoading: false, ownerName: "Alex Kim", ownerInitials: "AK", isSignedIn: true), onAction: { _ in })
}

#Preview("Invite expired") {
    JoinTeamScreen(state: JoinTeamState(isLoading: false, error: "This invite has expired"), onAction: { _ in })
}

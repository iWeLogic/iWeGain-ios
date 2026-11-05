import SwiftUI

struct MyTeamRoot: View {
    @State private var viewModel: MyTeamViewModel
    @State private var message: String?
    private let onNavigateToInvite: () -> Void
    private let onNavigateToCreateProfile: () -> Void
    private let onNavigateToEditProfile: (String) -> Void

    init(
        viewModel: @autoclosure () -> MyTeamViewModel,
        onNavigateToInvite: @escaping () -> Void,
        onNavigateToCreateProfile: @escaping () -> Void,
        onNavigateToEditProfile: @escaping (String) -> Void
    ) {
        _viewModel = State(initialValue: viewModel())
        self.onNavigateToInvite = onNavigateToInvite
        self.onNavigateToCreateProfile = onNavigateToCreateProfile
        self.onNavigateToEditProfile = onNavigateToEditProfile
    }

    var body: some View {
        MyTeamScreen(state: viewModel.state, onAction: viewModel.onAction)
            .onEvents(of: viewModel) { event in
                switch event {
                case .navigateToInvite: onNavigateToInvite()
                case .navigateToCreateProfile: onNavigateToCreateProfile()
                case .navigateToEditProfile(let id): onNavigateToEditProfile(id)
                case .showMessage(let text):
                    // Failures close the dialog: an alert can't be presented until its cover has gone.
                    Task {
                        try? await Task.sleep(for: .milliseconds(300))
                        message = text
                    }
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

struct MyTeamScreen: View {
    let state: MyTeamState
    let onAction: (MyTeamAction) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.x16) {
                VStack(alignment: .leading, spacing: Spacing.x4) {
                    Text("my_team_title").textStyle(.largeTitle).foregroundStyle(Color.textPrimary)
                    Text("my_team_message").textStyle(.footnote).foregroundStyle(Color.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if state.isLoading {
                    RoundedRectangle(cornerRadius: Radius.lg).fill(Color.bgSurface).frame(height: 136)
                }
                if !state.members.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(state.members) { member in
                            if member.id != state.members.first?.id {
                                Rectangle().fill(Color.borderDefault).frame(height: 1).padding(.leading, 68)
                            }
                            MemberRow(
                                member: member,
                                onTap: { onAction(.onMemberTap(member)) },
                                onRemoveTap: { onAction(.onRemoveTap(member)) }
                            )
                        }
                    }
                    .background(Color.bgSurface, in: .rect(cornerRadius: Radius.lg))
                }
                AddActionCard(title: "add_person_create_profile", subtitle: "my_team_create_profile_hint", action: { onAction(.onCreateProfileTap) })
                AddActionCard(title: "my_team_invite", subtitle: "my_team_invite_hint", action: { onAction(.onInviteTap) })
            }
            .padding(.horizontal, Spacing.x16)
            .padding(.bottom, Spacing.x16)
            .animation(.default, value: state.members.map(\.uid))
        }
        .background(Color.bgBase)
        .navigationTitle("")
        .inlineNavigationTitle()
        .centeredDialog(isPresented: state.removing != nil, onDismiss: { onAction(.onRemoveDismiss) }) {
            if let member = state.removing {
                ConfirmDialog(
                    title: Strings.format(member.isProfile ? "profile_delete_title" : "my_team_remove_title", member.firstName),
                    message: member.isProfile ? Strings.format("profile_delete_message", member.firstName) : Strings.text("my_team_remove_message"),
                    confirmText: Strings.text(member.isProfile ? "profile_delete" : "my_team_remove"),
                    dismissText: Strings.text("action_cancel"),
                    isDestructive: true,
                    isWorking: state.isRemoving,
                    onConfirm: { onAction(.onRemoveConfirm) },
                    onDismiss: { onAction(.onRemoveDismiss) }
                ) {
                    Avatar(initials: member.initials, color: member.color, photo: member.photo, size: 56)
                }
            }
        }
    }
}

private struct MemberRow: View {
    let member: MemberUi
    let onTap: () -> Void
    let onRemoveTap: () -> Void

    var body: some View {
        HStack(spacing: Spacing.x12) {
            // Only profiles can be opened.
            if member.isProfile {
                Button(action: onTap) { person.contentShape(.rect) }.buttonStyle(.plain)
            } else {
                person
            }
            Button(action: onRemoveTap) {
                Image("ic_trash")
                    .resizable()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(Color.statusDanger)
                    .frame(width: 36, height: 36)
                    .background(Color.statusDangerSoft, in: .circle)
                    .contentShape(.circle)
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(Text(Strings.format(member.isProfile ? "profile_delete_description" : "my_team_remove_member", member.name)))
        }
        .padding(.horizontal, Spacing.x16)
        .padding(.vertical, Spacing.x12)
    }

    private var person: some View {
        HStack(spacing: Spacing.x12) {
            Avatar(initials: member.initials, color: member.color, photo: member.photo, size: 40)
            VStack(alignment: .leading, spacing: Spacing.x2) {
                Text(member.name).textStyle(.headline).foregroundStyle(Color.textPrimary).lineLimit(1)
                Text(member.caption).textStyle(.footnote).foregroundStyle(Color.textSecondary).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview("Members") {
    NavigationStack {
        MyTeamScreen(
            state: MyTeamState(isLoading: false, members: [
                MemberUi(uid: "1", name: "Maria Sokol", initials: "MS", color: .pink, caption: "Joined Sep 12"),
                MemberUi(uid: "2", name: "Dan Petrov", initials: "DP", color: .orange, caption: "Joined Aug 30 · Hasn't allowed access"),
                MemberUi(uid: "3", name: "Leo Novak", initials: "LN", color: .purple, caption: "Profile in your account", isProfile: true),
            ]),
            onAction: { _ in }
        )
    }
}

#Preview("Loading") {
    NavigationStack { MyTeamScreen(state: MyTeamState(), onAction: { _ in }) }
}

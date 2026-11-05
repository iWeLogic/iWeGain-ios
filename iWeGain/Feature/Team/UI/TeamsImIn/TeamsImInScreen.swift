import SwiftUI

struct TeamsImInRoot: View {
    @State private var viewModel: TeamsImInViewModel
    @State private var message: String?

    init(viewModel: @autoclosure () -> TeamsImInViewModel) {
        _viewModel = State(initialValue: viewModel())
    }

    var body: some View {
        TeamsImInScreen(state: viewModel.state, onAction: viewModel.onAction)
            .onEvents(of: viewModel) { event in
                switch event {
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

struct TeamsImInScreen: View {
    let state: TeamsImInState
    let onAction: (TeamsImInAction) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.x16) {
                VStack(alignment: .leading, spacing: Spacing.x4) {
                    Text("teams_im_in_title").textStyle(.largeTitle).foregroundStyle(Color.textPrimary)
                    Text("teams_im_in_message").textStyle(.footnote).foregroundStyle(Color.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if !state.isLoading && state.teams.isEmpty {
                    EmptyStateView(title: "teams_im_in_empty_title", message: "teams_im_in_empty_message", icon: "ic_user")
                }
                if state.isLoading {
                    RoundedRectangle(cornerRadius: Radius.lg).fill(Color.bgSurface).frame(height: 140)
                }
                ForEach(state.teams) { team in
                    TeamCard(
                        team: team,
                        onAccessChange: { onAction(.onAccessChange(ownerUid: team.ownerUid, access: $0)) },
                        onLeaveTap: { onAction(.onLeaveTap(team)) }
                    )
                }
            }
            .padding(.horizontal, Spacing.x16)
            .padding(.bottom, Spacing.x16)
            .animation(.default, value: state.teams.map(\.ownerUid))
        }
        .background(Color.bgBase)
        .navigationTitle("")
        .inlineNavigationTitle()
        .centeredDialog(isPresented: state.leaving != nil, onDismiss: { onAction(.onLeaveDismiss) }) {
            if let team = state.leaving {
                ConfirmDialog(
                    title: Strings.format("teams_im_in_leave_title", team.ownerName),
                    message: Strings.format("teams_im_in_leave_message", team.ownerName),
                    confirmText: Strings.text("teams_im_in_leave"),
                    dismissText: Strings.text("action_cancel"),
                    isDestructive: true,
                    isWorking: state.isLeaving,
                    onConfirm: { onAction(.onLeaveConfirm) },
                    onDismiss: { onAction(.onLeaveDismiss) }
                ) {
                    Avatar(initials: team.initials, color: team.color, size: 56)
                }
            }
        }
    }
}

private struct TeamCard: View {
    let team: MembershipUi
    let onAccessChange: (Bool) -> Void
    let onLeaveTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.x12) {
                Avatar(initials: team.initials, color: team.color, size: 40)
                VStack(alignment: .leading, spacing: Spacing.x2) {
                    Text(Strings.format("teams_im_in_team_name", team.ownerName))
                        .textStyle(.headline)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                    Text(team.caption).textStyle(.footnote).foregroundStyle(Color.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Spacing.x16)
            divider
            Toggle(isOn: Binding(get: { team.hasAccess }, set: { onAccessChange($0) })) {
                VStack(alignment: .leading, spacing: Spacing.x2) {
                    Text("teams_im_in_access").textStyle(.body).foregroundStyle(Color.textPrimary)
                    Text("teams_im_in_access_hint").textStyle(.footnote).foregroundStyle(Color.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .tint(Color.switchOn)
            .padding(Spacing.x16)
            // The whole row toggles, not only the switch.
            .contentShape(.rect)
            .onTapGesture { onAccessChange(!team.hasAccess) }
            divider
            Button(action: onLeaveTap) {
                HStack(spacing: Spacing.x8) {
                    Image("ic_logout").resizable().frame(width: 18, height: 18)
                    Text("teams_im_in_leave").textStyle(.body)
                }
                .foregroundStyle(Color.statusDanger)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.x16)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
        .background(Color.bgSurface, in: .rect(cornerRadius: Radius.lg))
    }

    private var divider: some View {
        Rectangle().fill(Color.borderDefault).frame(height: 1).padding(.horizontal, Spacing.x16)
    }
}

#Preview("Teams") {
    NavigationStack {
        TeamsImInScreen(
            state: TeamsImInState(isLoading: false, teams: [
                MembershipUi(ownerUid: "1", ownerName: "Alex Kim", initials: "AK", color: .blue, caption: "Team leader · joined Sep 29", hasAccess: true),
                MembershipUi(ownerUid: "2", ownerName: "Dana Ross", initials: "DR", color: .orange, caption: "Team leader · joined Aug 14", hasAccess: false),
            ]),
            onAction: { _ in }
        )
    }
}

#Preview("Empty") {
    NavigationStack { TeamsImInScreen(state: TeamsImInState(isLoading: false), onAction: { _ in }) }
}

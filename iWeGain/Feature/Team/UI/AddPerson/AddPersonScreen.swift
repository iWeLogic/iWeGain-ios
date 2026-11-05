import SwiftUI

struct AddPersonRoot: View {
    @State private var viewModel: AddPersonViewModel
    private let onNavigateToSignIn: () -> Void
    private let onClose: () -> Void

    init(viewModel: @autoclosure () -> AddPersonViewModel, onNavigateToSignIn: @escaping () -> Void, onClose: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel())
        self.onNavigateToSignIn = onNavigateToSignIn
        self.onClose = onClose
    }

    var body: some View {
        AddPersonScreen(state: viewModel.state, onAction: viewModel.onAction)
            .onEvents(of: viewModel) { event in
                switch event {
                case .close: onClose()
                case .navigateToSignIn: onNavigateToSignIn()
                case .copyLink(let link): Self.copy(link)
                }
            }
            .task { viewModel.onAction(.onAppear) }
    }

    private static func copy(_ link: URL) {
        #if canImport(UIKit)
        UIPasteboard.general.string = link.absoluteString
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(link.absoluteString, forType: .string)
        #endif
    }
}

struct AddPersonScreen: View {
    let state: AddPersonState
    let onAction: (AddPersonAction) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.x16) {
                AvatarPair(me: state.me)
                Text("add_person_heading").textStyle(.title2).foregroundStyle(Color.textPrimary)
                Text("add_person_message")
                    .textStyle(.callout)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                InviteSteps()
                if state.isSignedIn {
                    InviteLink(state: state, onCopyTap: { onAction(.onCopyTap) })
                } else {
                    Text("add_person_sign_in_first")
                        .textStyle(.footnote)
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                }
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
            BottomButton(state: state, onAction: onAction)
                .padding(.horizontal, Spacing.x16)
                .padding(.top, Spacing.x12)
                .padding(.bottom, Spacing.x8)
                .background(Color.bgBase)
        }
    }
}

private struct BottomButton: View {
    let state: AddPersonState
    let onAction: (AddPersonAction) -> Void

    var body: some View {
        if !state.isSignedIn {
            Button("settings_sign_in") { onAction(.onSignInTap) }.buttonStyle(.appPrimary)
        } else if let link = state.link {
            ShareLink(item: link) { shareLabel }.buttonStyle(.appPrimary)
        } else if state.error != nil {
            Button("add_person_retry") { onAction(.onRetryTap) }.buttonStyle(.appSecondary)
        } else {
            Button {} label: { shareLabel }.buttonStyle(.appPrimary).disabled(true)
        }
    }

    private var shareLabel: some View {
        Label { Text("add_person_share") } icon: { Image("ic_export") }
    }
}

/// Me, ringed, next to a dashed "+" for the person being added (Figma "21 · Add Person").
struct AvatarPair: View {
    let me: UserUi?

    var body: some View {
        HStack(spacing: 0) {
            Avatar(initials: me?.initials ?? "", color: me?.avatarColor, photo: me?.photo, size: 58)
                .padding(3)
                .overlay(Circle().inset(by: 1).stroke(Color.accentPrimary, lineWidth: 2))
            Image("ic_plus")
                .resizable()
                .frame(width: 24, height: 24)
                .foregroundStyle(Color.accentPrimary)
                .frame(width: 64, height: 64)
                .background(Color.bgSurface, in: .circle)
                .dashedBorder(.accentPrimary, cornerRadius: 32)
                .offset(x: -12)
        }
        .accessibilityHidden(true)
    }
}

private struct InviteSteps: View {
    private static let steps: [(title: LocalizedStringKey, hint: LocalizedStringKey)] = [
        ("add_person_step_share", "add_person_step_share_hint"),
        ("add_person_step_sign_in", "add_person_step_sign_in_hint"),
        ("add_person_step_list", "add_person_step_list_hint"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x16) {
            ForEach(Self.steps.indices, id: \.self) { index in
                HStack(alignment: .top, spacing: Spacing.x12) {
                    Text(verbatim: String(index + 1))
                        .textStyle(.caption)
                        .foregroundStyle(Color.accentPrimary)
                        .frame(width: 24, height: 24)
                        .background(Color.accentSoft, in: .circle)
                    VStack(alignment: .leading, spacing: Spacing.x2) {
                        Text(Self.steps[index].title).textStyle(.headline).foregroundStyle(Color.textPrimary)
                        Text(Self.steps[index].hint).textStyle(.footnote).foregroundStyle(Color.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .cardStyle()
    }
}

private struct InviteLink: View {
    let state: AddPersonState
    let onCopyTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x8) {
            SectionLabel(text: Strings.text("add_person_link_label"))
            HStack(spacing: Spacing.x12) {
                Image("ic_link").resizable().frame(width: 20, height: 20).foregroundStyle(Color.textSecondary)
                Group {
                    if let link = state.link {
                        Text(verbatim: link.absoluteString.replacing("https://", with: ""))
                            .textStyle(.callout)
                            .foregroundStyle(Color.textPrimary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    } else if let error = state.error {
                        Text(error).textStyle(.footnote).foregroundStyle(Color.statusDanger)
                    } else {
                        ProgressView().controlSize(.small)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if state.link != nil {
                    Button(action: onCopyTap) {
                        HStack(spacing: Spacing.x4) {
                            Image("ic_copy").resizable().frame(width: 16, height: 16)
                            Text("add_person_copy").textStyle(.subhead)
                        }
                        .foregroundStyle(Color.accentPrimary)
                        .padding(.horizontal, Spacing.x12)
                        .padding(.vertical, 6)
                        .background(Color.accentSoft, in: .rect(cornerRadius: Radius.sm))
                        .contentShape(.rect(cornerRadius: Radius.sm))
                    }
                    .buttonStyle(.pressable)
                }
            }
            .padding(.leading, Spacing.x16)
            .padding(.trailing, Spacing.x8)
            .frame(height: 56)
            .background(Color.bgSurface, in: .rect(cornerRadius: Radius.md))
            Text("add_person_link_hint").textStyle(.caption).foregroundStyle(Color.textTertiary)
        }
        .padding(.bottom, Spacing.x8)
    }
}

#Preview("Link") {
    NavigationStack {
        AddPersonScreen(
            state: AddPersonState(
                me: UserUi(id: "1", name: "Alex Kim", initials: "AK", avatarColor: .blue, isSelected: true),
                link: URL(string: "https://iwegain.com/i/AK7-29QX")
            ),
            onAction: { _ in }
        )
    }
}

#Preview("Signed out") {
    NavigationStack { AddPersonScreen(state: AddPersonState(isSignedIn: false), onAction: { _ in }) }
}

#Preview("Failed") {
    NavigationStack { AddPersonScreen(state: AddPersonState(error: "No internet connection"), onAction: { _ in }) }
}

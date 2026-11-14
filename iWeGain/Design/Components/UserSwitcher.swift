import SwiftUI

/// A person in the [UserSwitcher]; the ViewModel prepares the texts.
struct UserUi: Identifiable, Equatable {
    let id: String
    let name: String
    let initials: String
    /// nil for the local guest, who has a neutral avatar.
    let avatarColor: AvatarColor?
    var isSelected = false
    var isLocked = false
    var isGuest = false
    var photo: Data?
}

extension User {
    func toUserUi(isSelected: Bool) -> UserUi {
        UserUi(
            id: id,
            name: isGuest ? Strings.text("user_guest") : name,
            initials: isGuest ? Strings.text("user_guest_initials") : Self.initials(of: name),
            avatarColor: avatarColor,
            isSelected: isSelected,
            isLocked: isLocked,
            isGuest: isGuest,
            photo: photo
        )
    }

    /// "AK" from "Alex Kim"; "#" when there is no name to use.
    static func initials(of name: String) -> String {
        let letters = name.split(separator: " ").prefix(2).compactMap { $0.first.map { String($0).uppercased() } }
        return letters.isEmpty ? "#" : letters.joined()
    }
}

/// Circle with a person's photo or initials.
struct Avatar: View {
    let initials: String
    let color: AvatarColor?
    var photo: Data?
    var isSelected = false
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let photo, let image = Self.image(photo) {
                image.resizable().scaledToFill()
            } else {
                Text(initials)
                    .textStyle(.subhead)
                    .foregroundStyle(color == nil ? Color.textPrimary : Color.accentOn)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(color?.swatch ?? .bgSurface2)
            }
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
        .overlay { if isSelected { Circle().stroke(Color.accentPrimary, lineWidth: 2) } }
        .accessibilityHidden(true)
    }

    private static func image(_ data: Data) -> Image? {
        #if canImport(UIKit)
        UIImage(data: data).map(Image.init(uiImage:))
        #elseif canImport(AppKit)
        NSImage(data: data).map(Image.init(nsImage:))
        #endif
    }
}

extension AvatarColor {
    var swatch: Color {
        switch self {
        case .blue: .dataBlue
        case .pink: .dataPink
        case .orange: .dataOrange
        case .purple: .dataPurple
        }
    }
}

/// The selected person at the top of Home, Statistics and Calendar; a tap opens the list of people, which
/// also offers adding someone. Shows "Offline" while the server can't be reached. Hidden while signed out:
/// the guest is the only person then, and there is no one to switch to.
struct UserSwitcher: View {
    let users: [UserUi]
    var isOffline = false
    let onUserTap: (String) -> Void
    let onCreateProfileTap: () -> Void
    let onInviteTap: () -> Void

    @State private var isPickerOpen = false

    var body: some View {
        if !users.allSatisfy(\.isGuest) { content }
    }

    private var content: some View {
        let selected = users.first(where: \.isSelected) ?? users.first
        return HStack(spacing: Spacing.x8) {
            Button { isPickerOpen = true } label: {
                HStack(spacing: Spacing.x12) {
                    if let selected {
                        Avatar(initials: selected.initials, color: selected.avatarColor, photo: selected.photo, size: 40)
                        Text(selected.name).textStyle(.headline).foregroundStyle(Color.textPrimary).lineLimit(1)
                    }
                    Image("ic_chevron_down").resizable().frame(width: 16, height: 16).foregroundStyle(Color.textSecondary)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("user_change"))
            Spacer(minLength: 0)
            if isOffline {
                // The server can't be reached: changes are kept on the device and synced later.
                HStack(spacing: 6) {
                    Image("ic_cloud_off").resizable().frame(width: 16, height: 16)
                    Text("sync_offline").textStyle(.footnote).lineLimit(1)
                }
                .foregroundStyle(Color.textSecondary)
                .padding(.leading, 10)
                .padding(.trailing, Spacing.x12)
                .padding(.vertical, 6)
                .background(Color.bgSurface2, in: .capsule)
            }
        }
        .sheet(isPresented: $isPickerOpen) {
            UserPickerSheet(
                users: users,
                onUserTap: { id in isPickerOpen = false; onUserTap(id) },
                onCreateProfileTap: { isPickerOpen = false; onCreateProfileTap() },
                onInviteTap: { isPickerOpen = false; onInviteTap() }
            )
        }
    }
}

private struct UserPickerSheet: View {
    let users: [UserUi]
    let onUserTap: (String) -> Void
    let onCreateProfileTap: () -> Void
    let onInviteTap: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            FittedSheetScroll {
                VStack(spacing: Spacing.x12) {
                    VStack(spacing: 0) {
                        ForEach(users) { user in
                            if user.id != users.first?.id { Divider().overlay(Color.borderDefault).padding(.leading, 72) }
                            row(user)
                        }
                    }
                    .background(Color.bgSurface, in: .rect(cornerRadius: Radius.lg))
                    Button(action: onCreateProfileTap) {
                        Label { Text("user_create_profile_button") } icon: { Image("ic_user") }
                    }
                    .buttonStyle(.appSecondary)
                    Button(action: onInviteTap) {
                        Label { Text("user_invite_button") } icon: { Image("ic_link") }
                    }
                    .buttonStyle(.appSecondary)
                }
                .padding(.horizontal, Spacing.x16)
                .padding(.bottom, Spacing.x24)
            }
            .background(Color.bgBase)
            .navigationTitle(Text("user_picker_title"))
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(role: .close) { dismiss() } }
            }
        }
        .presentationBackground(Color.bgBase)
    }

    private func row(_ user: UserUi) -> some View {
        Button { onUserTap(user.id) } label: {
            HStack(spacing: Spacing.x12) {
                Avatar(initials: user.initials, color: user.avatarColor, photo: user.photo, size: 40)
                VStack(alignment: .leading, spacing: Spacing.x2) {
                    Text(user.name).textStyle(.body).foregroundStyle(Color.textPrimary).lineLimit(1)
                    if user.isLocked {
                        Text("user_no_access").textStyle(.footnote).foregroundStyle(Color.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if user.isSelected {
                    Image("ic_check").resizable().frame(width: 20, height: 20).foregroundStyle(Color.accentPrimary)
                }
            }
            .padding(.horizontal, Spacing.x16)
            .padding(.vertical, Spacing.x12)
            .contentShape(.rect)
            .opacity(user.isLocked ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(user.isLocked)
        .accessibilityAddTraits(user.isSelected ? .isSelected : [])
    }
}

#Preview {
    UserSwitcher(
        users: [UserUi(id: "1", name: "Alex Kim", initials: "AK", avatarColor: .blue, isSelected: true)],
        isOffline: true,
        onUserTap: { _ in }, onCreateProfileTap: {}, onInviteTap: {}
    )
    .padding()
    .background(Color.bgBase)
}

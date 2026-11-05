import PhotosUI
import SwiftUI

struct ProfileEditorRoot: View {
    @State private var viewModel: ProfileEditorViewModel
    @State private var message: String?
    @State private var isGalleryOpen = false
    @State private var isCameraOpen = false
    @State private var pickedItem: PhotosPickerItem?
    private let onClose: () -> Void

    init(viewModel: @autoclosure () -> ProfileEditorViewModel, onClose: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel())
        self.onClose = onClose
    }

    var body: some View {
        ProfileEditorScreen(state: viewModel.state, onAction: viewModel.onAction)
            .onEvents(of: viewModel) { event in
                switch event {
                case .close: onClose()
                case .launchCamera: isCameraOpen = true
                case .launchGallery: isGalleryOpen = true
                case .showMessage(let text):
                    // A failed delete closes the dialog: an alert can't be presented until its cover has gone.
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
            .photosPicker(isPresented: $isGalleryOpen, selection: $pickedItem, matching: .images)
            .onChange(of: pickedItem) { _, item in
                guard let item else { return }
                pickedItem = nil
                Task {
                    // A picture that can't be loaded gets the same message as one that can't be read.
                    let data = (try? await item.loadTransferable(type: Data.self)) ?? Data()
                    viewModel.onAction(.onPhotoPicked(data))
                }
            }
            #if os(iOS)
            .fullScreenCover(isPresented: $isCameraOpen) {
                CameraPicker(onResult: { viewModel.onAction(.onPhotoTaken($0)) }).ignoresSafeArea()
            }
            #endif
            .task { viewModel.onAction(.onAppear) }
    }
}

/// Figma "21b/21c · Create Profile", "24c · Edit Profile" and "05f · Edit My Profile".
struct ProfileEditorScreen: View {
    let state: ProfileEditorState
    let onAction: (ProfileEditorAction) -> Void

    private var title: LocalizedStringKey {
        switch state.mode {
        case .new: "profile_new_title"
        case .edit: "profile_edit_title"
        case .me: "profile_me_title"
        }
    }

    var body: some View {
        let canSave = state.isLoaded && !state.isSaving
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.x12) {
                PhotoPicker(state: state, onTap: { onAction(.onPhotoTap) })
                AppTextField(placeholder: "profile_first_name", text: state.firstName, onTextChange: { onAction(.onFirstNameChange($0)) }, dashedWhenEmpty: true, isError: state.isNameMissing)
                    .capitalizesWords()
                    .padding(.top, Spacing.x12)
                AppTextField(placeholder: "profile_last_name", text: state.lastName, onTextChange: { onAction(.onLastNameChange($0)) }, dashedWhenEmpty: true)
                    .capitalizesWords()
                Text(state.mode == .me ? "profile_me_note" : "profile_note")
                    .textStyle(.footnote)
                    .foregroundStyle(Color.textSecondary)
                if case .edit = state.mode {
                    Button { onAction(.onDeleteTap) } label: {
                        Label { Text("profile_delete") } icon: { Image("ic_trash") }
                    }
                    .buttonStyle(.appDanger)
                    .padding(.top, Spacing.x12)
                }
            }
            .padding(.horizontal, Spacing.x16)
            .padding(.vertical, Spacing.x24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.bgBase)
        .navigationTitle(Text(title))
        .inlineNavigationTitle()
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("action_cancel") { onAction(.onCancelTap) }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("action_save") { onAction(.onSaveTap) }.tint(Color.accentPrimary).disabled(!canSave)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button { onAction(.onSaveTap) } label: {
                Label { Text(state.mode == .new ? "profile_save" : "profile_save_changes") } icon: { Image("ic_check") }
            }
            .buttonStyle(.appPrimary)
            .disabled(!canSave)
            .padding(.horizontal, Spacing.x16)
            .padding(.top, Spacing.x12)
            .padding(.bottom, Spacing.x8)
            .background(Color.bgBase)
        }
        .sheet(
            isPresented: Binding(get: { state.isPhotoSheetOpen }, set: { if !$0 { onAction(.onPhotoSheetClose) } }),
            onDismiss: { onAction(.onPhotoSheetDismissed) }
        ) {
            PhotoSheet(hasPhoto: state.photo != nil, onAction: onAction)
        }
        .centeredDialog(isPresented: state.isDeleteConfirmOpen, onDismiss: { onAction(.onDeleteDismiss) }) {
            let firstName = state.firstName.trimmingCharacters(in: .whitespaces)
            ConfirmDialog(
                title: Strings.format("profile_delete_title", firstName),
                message: Strings.format("profile_delete_message", firstName),
                confirmText: Strings.text("profile_delete"),
                dismissText: Strings.text("action_cancel"),
                isDestructive: true,
                isWorking: state.isDeleting,
                onConfirm: { onAction(.onDeleteConfirm) },
                onDismiss: { onAction(.onDeleteDismiss) }
            ) {
                Avatar(initials: state.initials, color: state.color, photo: state.photo, size: 56)
            }
        }
    }
}

private extension View {
    func capitalizesWords() -> some View {
        #if os(macOS)
        self
        #else
        textInputAutocapitalization(.words)
        #endif
    }
}

/// The photo, or the initials in the profile's color, with a camera badge; an empty dashed circle before either.
private struct PhotoPicker: View {
    private static let size: CGFloat = 96

    let state: ProfileEditorState
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: Spacing.x8) {
            Button(action: onTap) {
                if state.hasAvatar {
                    Avatar(initials: state.initials, color: state.color, photo: state.photo, size: Self.size)
                        .overlay(alignment: .bottomTrailing) {
                            Image("ic_camera")
                                .resizable()
                                .frame(width: 16, height: 16)
                                .foregroundStyle(Color.accentOn)
                                .frame(width: 28, height: 28)
                                .background(Color.accentPrimary, in: .circle)
                                .padding(3)
                                .background(Color.bgBase, in: .circle)
                                .offset(x: 2, y: 2)
                        }
                } else {
                    Image("ic_camera")
                        .resizable()
                        .frame(width: 32, height: 32)
                        .foregroundStyle(Color.textSecondary)
                        .frame(width: Self.size, height: Self.size)
                        .background(Color.bgSurface, in: .circle)
                        .dashedBorder(.addCardBorder, cornerRadius: Self.size / 2)
                }
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(Text("profile_photo_title"))
            Button(action: onTap) {
                Text(state.photo != nil ? "profile_change_photo" : "profile_add_photo")
                    .textStyle(.subhead)
                    .foregroundStyle(Color.accentPrimary)
                    .padding(.horizontal, Spacing.x8)
                    .padding(.vertical, Spacing.x2)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            if state.photo == nil && state.mode == .new {
                Text("profile_photo_hint").textStyle(.caption).foregroundStyle(Color.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// Figma "21d · Create Profile · Photo": camera, gallery, and Remove photo while there is one.
private struct PhotoSheet: View {
    let hasPhoto: Bool
    let onAction: (ProfileEditorAction) -> Void

    @State private var height: CGFloat = 220

    var body: some View {
        VStack(spacing: Spacing.x16) {
            Text("profile_photo_title").textStyle(.headline).foregroundStyle(Color.textPrimary)
            VStack(spacing: 0) {
                if CameraPicker.isAvailable {
                    option("profile_take_photo", icon: "ic_camera", color: .textPrimary) { onAction(.onTakePhotoTap) }
                }
                option("profile_choose_photo", icon: "ic_image", color: .textPrimary) { onAction(.onChoosePhotoTap) }
                if hasPhoto {
                    option("profile_remove_photo", icon: "ic_trash", color: .statusDanger) { onAction(.onRemovePhotoTap) }
                }
            }
            .padding(.vertical, Spacing.x4)
            .background(Color.bgSurface2, in: .rect(cornerRadius: Radius.md))
        }
        .padding(.horizontal, Spacing.x16)
        .padding(.top, Spacing.x24)
        .padding(.bottom, Spacing.x24)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        .presentationDetents([.height(height)])
        .presentationBackground(Color.bgBase)
    }

    private func option(_ title: LocalizedStringKey, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).textStyle(.body).frame(maxWidth: .infinity, alignment: .leading)
                Image(icon).resizable().frame(width: 20, height: 20)
            }
            .foregroundStyle(color)
            .padding(.horizontal, Spacing.x16)
            .padding(.vertical, Spacing.x12)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

#if os(iOS)
/// The system camera; [onResult] gets the picture as JPEG data, or nil when it was cancelled.
private struct CameraPicker: UIViewControllerRepresentable {
    /// The simulator and devices without a camera crash on presenting it, so they don't offer it.
    static var isAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    let onResult: (Data?) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var parent: CameraPicker

        init(parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.onResult((info[.originalImage] as? UIImage)?.jpegData(compressionQuality: 0.9) ?? Data())
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onResult(nil)
            parent.dismiss()
        }
    }
}
#else
private enum CameraPicker {
    static var isAvailable: Bool { false }
}
#endif

#Preview("Edit") {
    NavigationStack {
        ProfileEditorScreen(
            state: ProfileEditorState(mode: .edit(profileId: "1"), isLoaded: true, firstName: "Leo", lastName: "Novak", initials: "LN", color: .purple),
            onAction: { _ in }
        )
    }
}

#Preview("New") {
    NavigationStack { ProfileEditorScreen(state: ProfileEditorState(isLoaded: true), onAction: { _ in }) }
}

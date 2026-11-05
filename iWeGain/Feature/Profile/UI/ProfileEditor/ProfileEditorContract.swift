import Foundation

/// Who the editor is for: a new profile in my account, one I created before, or me.
nonisolated enum ProfileEditorMode: Hashable, Sendable {
    case new
    case edit(profileId: String)
    case me
}

struct ProfileEditorState: Equatable {
    var mode: ProfileEditorMode = .new
    /// false while an existing profile is loading.
    var isLoaded = false
    var firstName = ""
    var lastName = ""
    /// From the name fields, for the avatar while there's no photo.
    var initials = ""
    /// nil for a new profile, which gets a random color when it's saved.
    var color: AvatarColor?
    var photo: Data?
    /// Save was tapped with no name: the field turns red until it's filled.
    var isNameMissing = false
    var isPhotoSheetOpen = false
    var isDeleteConfirmOpen = false
    var isDeleting = false
    var isSaving = false

    /// The photo, or the initials in the profile's color; an empty dashed circle before either.
    var hasAvatar: Bool { photo != nil || (!initials.isEmpty && color != nil) }
}

enum ProfileEditorAction {
    case onAppear
    case onFirstNameChange(String)
    case onLastNameChange(String)
    case onCancelTap
    case onSaveTap
    case onPhotoTap
    /// The sheet is being closed by the user.
    case onPhotoSheetClose
    /// The sheet is gone from the screen, so the camera or the gallery can be shown.
    case onPhotoSheetDismissed
    case onTakePhotoTap
    case onChoosePhotoTap
    case onRemovePhotoTap
    /// The camera's picture; nil when it was cancelled.
    case onPhotoTaken(Data?)
    /// The gallery's picture; nil when nothing was picked.
    case onPhotoPicked(Data?)
    case onDeleteTap
    case onDeleteConfirm
    case onDeleteDismiss
}

enum ProfileEditorEvent: UiEvent, Equatable {
    case close
    case launchCamera
    case launchGallery
    case showMessage(String)
}

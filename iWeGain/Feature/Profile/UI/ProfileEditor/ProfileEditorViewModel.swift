import Foundation

/// Name, surname and photo of a profile (Figma "21b · Create Profile", "24c · Edit Profile") or of my own account
/// ("05f · Edit My Profile"). Works like the training editor: the name is required and turns red when Save is
/// tapped without one. Without a photo, the avatar shows the initials.
final class ProfileEditorViewModel: BaseViewModel<ProfileEditorState, ProfileEditorAction, ProfileEditorEvent> {
    private enum PhotoSource { case camera, gallery }

    private let mode: ProfileEditorMode
    private let profileRepository: ProfileRepository
    private let userRepository: UserRepository
    private var isStarted = false
    private var showMissing = false
    private var editing: Profile?
    /// Waits for the photo sheet to go away: nothing else can be presented before that.
    private var pendingSource: PhotoSource?

    init(mode: ProfileEditorMode, profileRepository: ProfileRepository, userRepository: UserRepository) {
        self.mode = mode
        self.profileRepository = profileRepository
        self.userRepository = userRepository
        super.init(initialState: ProfileEditorState(mode: mode))
    }

    override func onAction(_ action: ProfileEditorAction) {
        switch action {
        case .onAppear: load()
        case .onFirstNameChange(let text):
            updateState { $0.firstName = text }
            namesChanged()
        case .onLastNameChange(let text):
            updateState { $0.lastName = text }
            namesChanged()
        case .onCancelTap: sendEvent(.close)
        case .onSaveTap: save()
        case .onPhotoTap: updateState { $0.isPhotoSheetOpen = true }
        case .onPhotoSheetClose: updateState { $0.isPhotoSheetOpen = false }
        case .onPhotoSheetDismissed:
            switch pendingSource {
            case .camera: sendEvent(.launchCamera)
            case .gallery: sendEvent(.launchGallery)
            case nil: break
            }
            pendingSource = nil
        case .onTakePhotoTap:
            pendingSource = .camera
            updateState { $0.isPhotoSheetOpen = false }
        case .onChoosePhotoTap:
            pendingSource = .gallery
            updateState { $0.isPhotoSheetOpen = false }
        case .onRemovePhotoTap:
            updateState {
                $0.photo = nil
                $0.isPhotoSheetOpen = false
            }
        case .onPhotoTaken(let data), .onPhotoPicked(let data):
            if let data { setPhoto(data) }
        case .onDeleteTap: updateState { $0.isDeleteConfirmOpen = true }
        case .onDeleteDismiss: updateState { $0.isDeleteConfirmOpen = false }
        case .onDeleteConfirm: delete()
        }
    }

    private func load() {
        guard !isStarted else { return }
        isStarted = true
        launch { [self] in
            switch mode {
            case .new:
                break
            case .edit(let profileId):
                guard let profile = await profileRepository.profile(id: profileId) else {
                    sendEvent(.close)
                    return
                }
                editing = profile
                updateState {
                    $0.firstName = profile.firstName
                    $0.lastName = profile.lastName
                    $0.color = profile.avatarColor
                    $0.photo = profile.photo
                }
            case .me:
                let me = await userRepository.observeMe().first()
                let own = await profileRepository.observeMyProfile().first() ?? nil
                let parts = Self.splitName(me?.name ?? "")
                updateState {
                    $0.firstName = own?.firstName ?? parts.first
                    $0.lastName = own?.lastName ?? parts.last
                    $0.color = me?.avatarColor
                    $0.photo = own?.photo
                }
            }
            updateState { $0.isLoaded = true }
            namesChanged()
        }
    }

    /// Until I set my own, the account's name splits into name and surname at the first space.
    static func splitName(_ name: String) -> (first: String, last: String) {
        guard let space = name.firstIndex(of: " ") else { return (name, "") }
        return (String(name[..<space]), String(name[name.index(after: space)...]))
    }

    private func namesChanged() {
        updateState {
            let name = fullName($0.firstName, $0.lastName)
            $0.initials = name.isEmpty ? "" : User.initials(of: name)
            $0.isNameMissing = showMissing && $0.firstName.nonBlank == nil
        }
    }

    private func setPhoto(_ data: Data) {
        launch { [self] in
            if let photo = await Self.processPhoto(data) {
                updateState { $0.photo = photo }
            } else {
                sendEvent(.showMessage(ProfileError.photo.message))
            }
        }
    }

    @concurrent private nonisolated static func processPhoto(_ data: Data) async -> Data? {
        ProfilePhotoProcessor.jpeg(from: data)
    }

    private func save() {
        guard !state.isSaving, state.isLoaded else { return }
        let first = state.firstName
        let last = state.lastName
        guard first.nonBlank != nil else {
            showMissing = true
            updateState { $0.isNameMissing = true }
            return
        }
        let photo = state.photo
        updateState { $0.isSaving = true }
        launch { [self] in
            do throws(ProfileError) {
                switch mode {
                case .new:
                    _ = try profileRepository.createProfile(firstName: first, lastName: last, photo: photo)
                case .edit:
                    guard var profile = editing else { throw .unknown }
                    profile.firstName = first
                    profile.lastName = last
                    profile.photo = photo
                    try profileRepository.updateProfile(profile)
                case .me:
                    try await profileRepository.updateMyProfile(firstName: first, lastName: last, photo: photo)
                }
                sendEvent(.close)
            } catch {
                updateState { $0.isSaving = false }
                sendEvent(.showMessage(error.message))
            }
        }
    }

    /// Deleting goes to the server right away (it removes the profile's trainings and workouts too), so it needs a connection.
    private func delete() {
        guard case .edit(let profileId) = mode, !state.isDeleting else { return }
        updateState { $0.isDeleting = true }
        launch { [self] in
            do throws(ProfileError) {
                try await profileRepository.deleteProfile(id: profileId)
                // The dialog is a cover on this screen: it goes away with it.
                updateState { $0.isDeleteConfirmOpen = false }
                sendEvent(.close)
            } catch {
                updateState {
                    $0.isDeleting = false
                    $0.isDeleteConfirmOpen = false
                }
                sendEvent(.showMessage(error.message))
            }
        }
    }
}

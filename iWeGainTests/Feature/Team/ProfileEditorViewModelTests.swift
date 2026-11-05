import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import iWeGain

@MainActor
struct ProfileEditorViewModelTests {
    private let container = AppContainer.inMemory()

    private func loaded(_ mode: ProfileEditorMode) async -> (ProfileEditorViewModel, () -> [ProfileEditorEvent]) {
        let viewModel = container.makeProfileEditorViewModel(mode: mode)
        let events = EventLog()
        viewModel.subscribe { events.values.append($0) }
        viewModel.onAction(.onAppear)
        await viewModel.waitForTasks()
        return (viewModel, { events.values })
    }

    private final class EventLog {
        var values: [ProfileEditorEvent] = []
    }

    private func png() throws -> Data {
        let context = try #require(CGContext(data: nil, width: 40, height: 20, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let image = try #require(context.makeImage())
        let output = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return output as Data
    }

    @Test func aNewProfileStartsEmptyWithoutAnAvatar() async {
        let (viewModel, _) = await loaded(.new)
        #expect(viewModel.state.isLoaded)
        #expect(viewModel.state.initials.isEmpty)
        #expect(!viewModel.state.hasAvatar)
    }

    @Test func initialsFollowTheNameFields() async {
        let (viewModel, _) = await loaded(.new)
        viewModel.onAction(.onFirstNameChange("Leo"))
        #expect(viewModel.state.initials == "L")
        viewModel.onAction(.onLastNameChange("Novak"))
        #expect(viewModel.state.initials == "LN")
        viewModel.onAction(.onFirstNameChange("  "))
        viewModel.onAction(.onLastNameChange(""))
        #expect(viewModel.state.initials.isEmpty)
    }

    @Test func savingWithoutANameTurnsTheFieldRedUntilItsFilled() async {
        let (viewModel, events) = await loaded(.new)
        #expect(!viewModel.state.isNameMissing)

        viewModel.onAction(.onFirstNameChange("   "))
        #expect(!viewModel.state.isNameMissing)
        viewModel.onAction(.onSaveTap)
        await viewModel.waitForTasks()
        #expect(viewModel.state.isNameMissing)
        #expect(!viewModel.state.isSaving)
        #expect(events().isEmpty)

        viewModel.onAction(.onFirstNameChange("Leo"))
        #expect(!viewModel.state.isNameMissing)
    }

    @Test func savingSignedOutFailsAndCanBeTriedAgain() async {
        let (viewModel, events) = await loaded(.new)
        viewModel.onAction(.onFirstNameChange("Leo"))

        viewModel.onAction(.onSaveTap)
        #expect(viewModel.state.isSaving)
        await viewModel.waitForTasks()

        #expect(!viewModel.state.isSaving)
        #expect(events() == [.showMessage(Strings.text("team_error_not_signed_in"))])
    }

    @Test func nothingIsSavedBeforeItsLoaded() async {
        let viewModel = container.makeProfileEditorViewModel(mode: .new)
        var events: [ProfileEditorEvent] = []
        viewModel.subscribe { events.append($0) }

        viewModel.onAction(.onFirstNameChange("Leo"))
        viewModel.onAction(.onSaveTap)

        #expect(!viewModel.state.isSaving)
        #expect(events.isEmpty)
    }

    @Test func aProfileThatIsGoneClosesTheEditor() async {
        let (viewModel, events) = await loaded(.edit(profileId: "missing"))
        #expect(!viewModel.state.isLoaded)
        #expect(events() == [.close])
    }

    @Test func myOwnEditorLoadsWithoutAnAccountProfile() async {
        let (viewModel, _) = await loaded(.me)
        #expect(viewModel.state.isLoaded)
        #expect(viewModel.state.firstName.isEmpty)
        #expect(viewModel.state.lastName.isEmpty)
    }

    @Test(arguments: [
        ("Alex Kim", "Alex", "Kim"),
        ("Alex", "Alex", ""),
        ("Mary Ann Smith", "Mary", "Ann Smith"),
        ("", "", ""),
    ])
    func theAccountsNameSplitsAtTheFirstSpace(name: String, first: String, last: String) {
        let parts = ProfileEditorViewModel.splitName(name)
        #expect(parts.first == first)
        #expect(parts.last == last)
    }

    @Test func theCameraWaitsForThePhotoSheetToGoAway() async {
        let (viewModel, events) = await loaded(.new)

        viewModel.onAction(.onPhotoTap)
        #expect(viewModel.state.isPhotoSheetOpen)
        viewModel.onAction(.onTakePhotoTap)
        #expect(!viewModel.state.isPhotoSheetOpen)
        #expect(events().isEmpty)

        viewModel.onAction(.onPhotoSheetDismissed)
        #expect(events() == [.launchCamera])
    }

    @Test func theGalleryWaitsForThePhotoSheetToGoAway() async {
        let (viewModel, events) = await loaded(.new)

        viewModel.onAction(.onPhotoTap)
        viewModel.onAction(.onChoosePhotoTap)
        #expect(events().isEmpty)

        viewModel.onAction(.onPhotoSheetDismissed)
        #expect(events() == [.launchGallery])
    }

    @Test func closingThePhotoSheetOpensNothing() async {
        let (viewModel, events) = await loaded(.new)

        viewModel.onAction(.onPhotoTap)
        viewModel.onAction(.onPhotoSheetClose)
        viewModel.onAction(.onPhotoSheetDismissed)

        #expect(!viewModel.state.isPhotoSheetOpen)
        #expect(events().isEmpty)
    }

    @Test func aPictureBecomesThePhotoAndCanBeRemoved() async throws {
        let (viewModel, events) = await loaded(.new)

        viewModel.onAction(.onPhotoPicked(try png()))
        await viewModel.waitForTasks()

        #expect(viewModel.state.photo != nil)
        #expect(viewModel.state.hasAvatar)
        #expect(events().isEmpty)

        viewModel.onAction(.onPhotoTap)
        viewModel.onAction(.onRemovePhotoTap)
        #expect(viewModel.state.photo == nil)
        #expect(!viewModel.state.isPhotoSheetOpen)
    }

    @Test func somethingThatIsNotAPictureSaysSo() async {
        let (viewModel, events) = await loaded(.new)

        viewModel.onAction(.onPhotoTaken(Data([1, 2, 3])))
        await viewModel.waitForTasks()

        #expect(viewModel.state.photo == nil)
        #expect(events() == [.showMessage(Strings.text("profile_error_photo"))])
    }

    @Test func cancellingThePickersChangesNothing() async {
        let (viewModel, events) = await loaded(.new)

        viewModel.onAction(.onPhotoTaken(nil))
        viewModel.onAction(.onPhotoPicked(nil))
        await viewModel.waitForTasks()

        #expect(viewModel.state.photo == nil)
        #expect(events().isEmpty)
    }

    @Test func aFailedDeleteClosesTheDialogAndSaysWhy() async {
        let viewModel = container.makeProfileEditorViewModel(mode: .edit(profileId: "p1"))
        var events: [ProfileEditorEvent] = []
        viewModel.subscribe { events.append($0) }

        viewModel.onAction(.onDeleteTap)
        #expect(viewModel.state.isDeleteConfirmOpen)
        viewModel.onAction(.onDeleteConfirm)
        await viewModel.waitForTasks()

        #expect(!viewModel.state.isDeleteConfirmOpen)
        #expect(!viewModel.state.isDeleting)
        #expect(events == [.showMessage(Strings.text("team_error_not_signed_in"))])
    }

    @Test func onlyAnExistingProfileCanBeDeleted() async {
        let (viewModel, events) = await loaded(.new)
        viewModel.onAction(.onDeleteConfirm)
        await viewModel.waitForTasks()
        #expect(events().isEmpty)
        #expect(!viewModel.state.isDeleting)
    }
}

import Foundation
import Testing
@testable import iWeGain

@MainActor
struct UserRepositoryTests {
    private let container = AppContainer.inMemory()

    @Test func theGuestIsTheOnlyPersonWhileSignedOut() async {
        let users = await container.userRepository.observeUsers().first()
        #expect(users == [User.guest])
        #expect(await container.userRepository.observeSelectedUserId().first() == User.guestId)
    }

    @Test func aSelectionOfSomeoneNotInTheListFallsBackToMe() async {
        container.userRepository.selectUser("someone-who-left")
        #expect(await container.userRepository.observeSelectedUserId().first() == User.guestId)
        #expect(container.defaults.string(forKey: "selected_user_id") == "someone-who-left")
    }
}

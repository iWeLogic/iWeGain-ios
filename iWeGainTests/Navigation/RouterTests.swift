import Testing
@testable import iWeGain

@MainActor
struct RouterTests {
    @Test func startsAtTheRootWithoutASheet() {
        let router = Router()
        #expect(router.path.isEmpty)
        #expect(router.sheet == nil)
        router.popToRoot()
        router.pop()
        router.dismissSheet()
        #expect(router.path.isEmpty)
    }

}

@MainActor
struct RouterStackTests {
    @Test func replaceTakesTheCurrentScreensPlace() {
        let router = Router()
        router.push(.myTeam)
        router.push(.addPerson)
        router.replace(.invite)
        #expect(router.path == [.myTeam, .invite])
    }

    @Test func replaceAtTheRootPushes() {
        let router = Router()
        router.replace(.invite)
        #expect(router.path == [.invite])
    }

    @Test func removeTakesOutTheScreenWhereverItIs() {
        let router = Router()
        router.push(.invite)
        router.push(.signIn)
        router.push(.myTeam)
        router.remove(.signIn)
        #expect(router.path == [.invite, .myTeam])
    }

    @Test(arguments: [
        (Route.profileEditor(), "NewProfile"),
        (.profileEditor(profileId: "p"), "EditProfile"),
        (.profileEditor(isMe: true), "MyProfile"),
        (.training(trainingId: nil), "NewTraining"),
        (.training(trainingId: "t"), "Training"),
        (.joinTeam(code: "c"), "JoinTeam"),
    ])
    func screensHaveTheirAnalyticsName(route: Route, name: String) {
        #expect(route.screenName == name)
    }
}

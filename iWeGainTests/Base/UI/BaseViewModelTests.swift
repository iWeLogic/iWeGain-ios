import Testing
@testable import iWeGain

@MainActor
struct BaseViewModelTests {

    private enum CounterAction { case increment, incrementLater, ping }
    private enum CounterEvent: UiEvent, Equatable { case pong(Int) }

    private final class CounterViewModel: BaseViewModel<Int, CounterAction, CounterEvent> {
        init() { super.init(initialState: 0) }

        override func onAction(_ action: CounterAction) {
            switch action {
            case .increment: updateState { $0 += 1 }
            case .incrementLater: launch { [self] in updateState { $0 += 1 } }
            case .ping: sendEvent(.pong(state))
            }
        }
    }

    @Test func actionsUpdateTheState() {
        let viewModel = CounterViewModel()
        viewModel.onAction(.increment)
        viewModel.onAction(.increment)
        #expect(viewModel.state == 2)
    }

    @Test func launchedWorkFinishesBeforeWaitForTasksReturns() async {
        let viewModel = CounterViewModel()
        viewModel.onAction(.incrementLater)
        await viewModel.waitForTasks()
        #expect(viewModel.state == 1)
    }

    @Test func eventsWaitUntilSomeoneSubscribes() {
        let viewModel = CounterViewModel()
        viewModel.onAction(.ping)
        viewModel.onAction(.increment)
        viewModel.onAction(.ping)

        var events: [CounterEvent] = []
        viewModel.subscribe { events.append($0) }

        #expect(events == [.pong(0), .pong(1)])
    }

    @Test func eventsAreDeliveredRightAwayWhileSubscribed() {
        let viewModel = CounterViewModel()
        var events: [CounterEvent] = []
        viewModel.subscribe { events.append($0) }

        viewModel.onAction(.ping)
        #expect(events == [.pong(0)])

        // After the screen disappears, events are buffered again instead of being lost.
        viewModel.unsubscribe()
        viewModel.onAction(.ping)
        #expect(events == [.pong(0)])
        viewModel.subscribe { events.append($0) }
        #expect(events == [.pong(0), .pong(0)])
    }
}

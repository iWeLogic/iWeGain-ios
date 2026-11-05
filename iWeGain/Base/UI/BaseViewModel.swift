import Observation

/// Base of every screen's ViewModel (MVI): the view renders [state] and sends actions to [onAction];
/// one-time effects go out through [sendEvent].
@Observable
class BaseViewModel<State, Action, Event: UiEvent> {

    private(set) var state: State

    @ObservationIgnored private var eventHandler: ((Event) -> Void)?
    @ObservationIgnored private var pendingEvents: [Event] = []
    @ObservationIgnored private var tasks: [Task<Void, Never>] = []

    init(initialState: State) {
        state = initialState
    }

    deinit {
        tasks.forEach { $0.cancel() }
    }

    /// Subclasses override. Called synchronously by the view, so text input never lags.
    func onAction(_ action: Action) {
        fatalError("\(Self.self) must override onAction(_:)")
    }

    func updateState(_ reduce: (inout State) -> Void) {
        reduce(&state)
    }

    /// Delivered right away while the screen is visible, buffered until it reappears otherwise.
    func sendEvent(_ event: Event) {
        if let eventHandler {
            eventHandler(event)
        } else {
            pendingEvents.append(event)
        }
    }

    /// Runs async work tied to this ViewModel; it's cancelled when the ViewModel goes away.
    func launch(_ operation: @escaping @MainActor () async -> Void) {
        tasks.removeAll { $0.isCancelled }
        tasks.append(Task { await operation() })
    }

    func subscribe(_ handler: @escaping (Event) -> Void) {
        eventHandler = handler
        let pending = pendingEvents
        pendingEvents.removeAll()
        pending.forEach(handler)
    }

    func unsubscribe() {
        eventHandler = nil
    }

    /// Tests only: waits until all launched work has finished.
    func waitForTasks() async {
        while !tasks.isEmpty {
            let running = tasks
            tasks.removeAll()
            for task in running { await task.value }
        }
    }
}

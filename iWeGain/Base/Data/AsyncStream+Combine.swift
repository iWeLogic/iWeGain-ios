/// Kotlin Flow-style helpers for the data streams repositories return.

extension AsyncStream where Element: Sendable {
    /// A stream that emits [transform] of each element.
    func map<T: Sendable>(_ transform: @escaping (Element) -> T) -> AsyncStream<T> {
        AsyncStream<T> { continuation in
            let task = Task { @MainActor in
                for await element in self { continuation.yield(transform(element)) }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Skips elements equal to the one before (Flow's distinctUntilChanged).
    func removeDuplicates() -> AsyncStream<Element> where Element: Equatable {
        AsyncStream { continuation in
            let task = Task { @MainActor in
                var last: Element?
                for await element in self where element != last {
                    last = element
                    continuation.yield(element)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Follows the stream [transform] returns for the latest element, dropping the previous one
    /// (Flow's flatMapLatest).
    func flatMapLatest<T: Sendable>(_ transform: @escaping (Element) -> AsyncStream<T>) -> AsyncStream<T> {
        AsyncStream<T> { continuation in
            let task = Task { @MainActor in
                var inner: Task<Void, Never>?
                for await element in self {
                    inner?.cancel()
                    let stream = transform(element)
                    inner = Task { @MainActor in
                        for await value in stream { continuation.yield(value) }
                    }
                }
                inner?.cancel()
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// The first element, or nil when the stream ends without one.
    func first() async -> Element? {
        for await element in self { return element }
        return nil
    }
}

/// Emits the latest pair once both streams have emitted, and again whenever either emits (Flow's combine).
func combineLatest<A: Sendable, B: Sendable>(_ a: AsyncStream<A>, _ b: AsyncStream<B>) -> AsyncStream<(A, B)> {
    AsyncStream { continuation in
        let latest = LatestPair<A, B>(continuation: continuation)
        let taskA = Task { @MainActor in
            for await value in a { latest.a = value }
            latest.sourceFinished()
        }
        let taskB = Task { @MainActor in
            for await value in b { latest.b = value }
            latest.sourceFinished()
        }
        continuation.onTermination = { _ in
            taskA.cancel()
            taskB.cancel()
        }
    }
}

/// The latest values of [combineLatest]'s two streams.
private final class LatestPair<A: Sendable, B: Sendable> {
    private let continuation: AsyncStream<(A, B)>.Continuation
    private var finishedSources = 0
    var a: A? { didSet { emit() } }
    var b: B? { didSet { emit() } }

    init(continuation: AsyncStream<(A, B)>.Continuation) {
        self.continuation = continuation
    }

    func sourceFinished() {
        finishedSources += 1
        if finishedSources == 2 { continuation.finish() }
    }

    private func emit() {
        if let a, let b { continuation.yield((a, b)) }
    }
}

func combineLatest<A: Sendable, B: Sendable, C: Sendable>(
    _ a: AsyncStream<A>, _ b: AsyncStream<B>, _ c: AsyncStream<C>
) -> AsyncStream<(A, B, C)> {
    combineLatest(combineLatest(a, b), c).map { ($0.0.0, $0.0.1, $0.1) }
}

func combineLatest<A: Sendable, B: Sendable, C: Sendable, D: Sendable>(
    _ a: AsyncStream<A>, _ b: AsyncStream<B>, _ c: AsyncStream<C>, _ d: AsyncStream<D>
) -> AsyncStream<(A, B, C, D)> {
    combineLatest(combineLatest(a, b), combineLatest(c, d)).map { ($0.0.0, $0.0.1, $0.1.0, $0.1.1) }
}

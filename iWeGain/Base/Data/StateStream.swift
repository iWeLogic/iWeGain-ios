/// A value that changes over time and can be followed (Kotlin's StateFlow): every stream starts with the
/// current value and gets each later one. Main-actor only.
final class StateStream<Value: Sendable & Equatable> {
    private(set) var value: Value
    private var continuations: [ObjectIdentifier: AsyncStream<Value>.Continuation] = [:]

    init(_ value: Value) {
        self.value = value
    }

    func send(_ newValue: Value) {
        guard newValue != value else { return }
        value = newValue
        continuations.values.forEach { $0.yield(newValue) }
    }

    func stream() -> AsyncStream<Value> {
        let (stream, continuation) = AsyncStream<Value>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let token = Token()
        let id = ObjectIdentifier(token)
        continuations[id] = continuation
        continuation.yield(value)
        continuation.onTermination = { [weak self] _ in
            // The token lives until here, so its identifier isn't reused by another stream.
            Task { @MainActor in
                withExtendedLifetime(token) { self?.continuations[id] = nil }
            }
        }
        return stream
    }

    private final class Token: Sendable {}
}

/// Every stream's latest value, once each has one; a single [] right away for no streams.
func combineLatest<T: Sendable>(_ streams: [AsyncStream<T>]) -> AsyncStream<[T]> {
    guard !streams.isEmpty else { return .single([]) }
    return AsyncStream { continuation in
        let latest = LatestValues<T>(count: streams.count)
        let tasks = streams.enumerated().map { index, stream in
            Task { @MainActor in
                for await value in stream {
                    if let all = latest.set(value, at: index) { continuation.yield(all) }
                }
            }
        }
        continuation.onTermination = { _ in tasks.forEach { $0.cancel() } }
    }
}

private final class LatestValues<T: Sendable> {
    private var values: [T?]

    init(count: Int) {
        values = Array(repeating: nil, count: count)
    }

    /// All the values, once every position has one.
    func set(_ value: T, at index: Int) -> [T]? {
        values[index] = value
        let all = values.compactMap { $0 }
        return all.count == values.count ? all : nil
    }
}

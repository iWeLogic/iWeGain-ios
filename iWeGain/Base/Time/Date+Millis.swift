import Foundation

nonisolated extension Date {
    /// Epoch milliseconds, the time format Android and Firestore documents use.
    var epochMillis: Int64 { Int64((timeIntervalSince1970 * 1000).rounded()) }

    init(epochMillis: Int64) {
        self.init(timeIntervalSince1970: TimeInterval(epochMillis) / 1000)
    }
}

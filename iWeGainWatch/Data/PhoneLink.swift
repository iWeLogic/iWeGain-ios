import Foundation

/// The phone app: the workout it publishes, whether it can be reached, and the commands sent to it.
protocol PhoneLink: AnyObject {
    var onWorkout: ((WatchWorkoutState) -> Void)? { get set }
    var onReachabilityChange: ((Bool) -> Void)? { get set }
    func start()
    /// false when the phone couldn't be reached.
    func send(_ command: WatchCommand) async -> Bool
}

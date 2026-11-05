import Observation

/// Navigation state of one tab: its pushed screens and the sheet shown over it.
@Observable
final class Router {
    var path: [Route] = []
    var sheet: Route?
    /// The exercise just picked in the library, waiting for the training editor to take it.
    var pickedExerciseId: String?
    /// The training just picked in Select training, waiting for the schedule form to take it.
    var pickedTrainingId: String?

    func push(_ route: Route) { path.append(route) }
    func pop() { _ = path.popLast() }
    func popToRoot() { path.removeAll() }
    /// Shows [route] in place of the current screen, so going back skips the one it replaced.
    func replace(_ route: Route) {
        pop()
        push(route)
    }
    /// Removes every screen showing [route], wherever it is in the stack.
    func remove(_ route: Route) { path.removeAll { $0 == route } }
    func present(_ route: Route) { sheet = route }
    func dismissSheet() { sheet = nil }

    /// The library returns [exerciseId] to the editor it was opened from.
    func returnPickedExercise(_ exerciseId: String) {
        pickedExerciseId = exerciseId
        pop()
    }

    /// Select training returns [trainingId] to the schedule form it was opened from.
    func returnPickedTraining(_ trainingId: String) {
        pickedTrainingId = trainingId
        pop()
    }
}

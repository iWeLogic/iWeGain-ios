#if os(iOS)
import SwiftUI
import UIKit
import Testing
@testable import iWeGain

@MainActor
struct TmpTypingProbeTests {
    @Test func typeIntoTrainingName() async throws {
        let container = AppContainer.inMemory()
        let vm = container.makeTrainingViewModel(trainingId: nil)
        let host = UIHostingController(rootView: NavigationStack {
            TrainingRoot(viewModel: vm, pickedExerciseId: nil, takePickedExercise: { nil }, onNavigateToExerciseLibrary: {}, onNavigateToWorkout: { _ in }, onClose: {})
        })
        let scene = try #require(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = host
        window.makeKeyAndVisible()
        try await Task.sleep(for: .seconds(1))
        func fields(_ v: UIView) -> [UITextField] { (v as? UITextField).map { [$0] } ?? v.subviews.flatMap(fields) }
        let field = try #require(fields(window).first, "no UITextField found")
        print("PROBE enabled=\(field.isEnabled) userInteraction=\(field.isUserInteractionEnabled)")
        let became = field.becomeFirstResponder()
        print("PROBE becameFirstResponder=\(became)")
        try await Task.sleep(for: .milliseconds(300))
        for ch in "Push" {
            field.insertText(String(ch))
            try await Task.sleep(for: .milliseconds(200))
        }
        try await Task.sleep(for: .milliseconds(500))
        let after = fields(window).first
        print("PROBE vm.name='\(vm.state.name)' field.text='\(after?.text ?? "nil")' same=\(after === field) firstResponder=\(after?.isFirstResponder ?? false)")
        #expect(vm.state.name == "Push")
    }
}
#endif

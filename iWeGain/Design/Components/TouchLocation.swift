import SwiftUI
#if os(iOS)
import UIKit
#endif

extension View {
    /// Calls [onTouch] with the finger's x (in this view) as soon as it touches the view and while it slides
    /// sideways, without taking the touch from an enclosing ScrollView: a swipe that turns vertical scrolls the
    /// screen and stops reporting. A SwiftUI `DragGesture(minimumDistance: 0)` would block that scroll.
    func onTouchLocation(_ onTouch: @escaping (CGFloat) -> Void) -> some View {
        #if os(iOS)
        gesture(TouchLocationGesture(onTouch: onTouch))
        #else
        // The Mac scrolls with the wheel or trackpad, so a drag doesn't compete with it.
        gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local).onChanged { onTouch($0.location.x) })
        #endif
    }
}

#if os(iOS)
private struct TouchLocationGesture: UIGestureRecognizerRepresentable {
    let onTouch: (CGFloat) -> Void

    func makeUIGestureRecognizer(context: Context) -> TouchLocationRecognizer {
        let recognizer = TouchLocationRecognizer()
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: TouchLocationRecognizer, context: Context) {
        switch recognizer.state {
        case .began, .changed:
            onTouch(context.converter.localLocation.x)
        default:
            break
        }
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        /// Lets the scroll view's pan run at the same time.
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }
    }
}

/// Begins on touch down; ends when the finger lifts, or as soon as the movement turns out to be vertical (a scroll).
private final class TouchLocationRecognizer: UIGestureRecognizer {
    /// Movement before the direction is decided.
    private static let slop: CGFloat = 10

    private var start: CGPoint = .zero
    private var isHorizontal = false

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard state == .possible, let touch = touches.first else {
            touches.forEach { ignore($0, for: event) }
            return
        }
        start = touch.location(in: view)
        isHorizontal = false
        state = .began
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: view)
        let dx = abs(point.x - start.x)
        let dy = abs(point.y - start.y)
        if !isHorizontal {
            if dy > Self.slop && dy > dx {
                state = .cancelled
                return
            }
            if dx > Self.slop { isHorizontal = true }
        }
        state = .changed
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .ended
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .cancelled
    }
}
#endif

import SwiftUI
import UIKit

/// Turns the phone into a touchpad for the car screen.
struct TrackpadView: UIViewRepresentable {
    var onMove: (CGFloat, CGFloat) -> Void
    var onScroll: (CGFloat, CGFloat) -> Void
    var onTap: () -> Void

    private static let pointerSpeed: CGFloat = 1.6
    private static let scrollSpeed: CGFloat = 2.0

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear

        let move = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMove(_:)))
        move.maximumNumberOfTouches = 1
        let scroll = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleScroll(_:)))
        scroll.minimumNumberOfTouches = 2
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))

        [move, scroll, tap].forEach(view.addGestureRecognizer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self
    }

    final class Coordinator: NSObject {
        var parent: TrackpadView

        init(_ parent: TrackpadView) { self.parent = parent }

        @objc func handleMove(_ gesture: UIPanGestureRecognizer) {
            let t = gesture.translation(in: gesture.view)
            gesture.setTranslation(.zero, in: gesture.view)
            parent.onMove(t.x * TrackpadView.pointerSpeed, t.y * TrackpadView.pointerSpeed)
        }

        @objc func handleScroll(_ gesture: UIPanGestureRecognizer) {
            let t = gesture.translation(in: gesture.view)
            gesture.setTranslation(.zero, in: gesture.view)
            parent.onScroll(-t.x * TrackpadView.scrollSpeed, -t.y * TrackpadView.scrollSpeed)
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            if gesture.state == .ended { parent.onTap() }
        }
    }
}

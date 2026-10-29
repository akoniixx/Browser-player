import CarPlay
import UIKit

/// Runs the app as a CarPlay "navigation" app, which is the only kind that gets a
/// free-form CPWindow. The map template supplies the on-car buttons and the
/// drag gestures from the car's touchscreen.
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private enum DragMode {
        case scroll, cursor

        var buttonTitle: String { self == .scroll ? "ลาก: เลื่อนหน้า" : "ลาก: เมาส์" }
    }

    private let engine = BrowserEngine.shared
    private var interfaceController: CPInterfaceController?
    private var carWindow: CPWindow?
    private var modeButton: CPBarButton?
    private var dragMode = DragMode.scroll
    private var lastPanTranslation = CGPoint.zero

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController,
        to window: CPWindow
    ) {
        self.interfaceController = interfaceController
        carWindow = window
        window.rootViewController = CarScreenViewController()
        interfaceController.setRootTemplate(makeMapTemplate(), animated: false, completion: nil)
        DrivingSafetyMonitor.shared.start()
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController,
        from window: CPWindow
    ) {
        engine.carDidDisconnect()
        window.rootViewController = nil
        carWindow = nil
        self.interfaceController = nil
    }

    private var isMoving: Bool { DrivingSafetyMonitor.shared.isMoving }

    private func makeMapTemplate() -> CPMapTemplate {
        let template = CPMapTemplate()
        template.mapDelegate = self
        template.automaticallyHidesNavigationBar = false
        template.hidesButtonsWithNavigationBar = false

        let back = CPBarButton(title: "ย้อนกลับ") { [weak self] _ in self?.engine.goBack() }
        let home = CPBarButton(title: "หน้าแรก") { [weak self] _ in self?.engine.goHome() }
        let mode = CPBarButton(title: dragMode.buttonTitle) { [weak self] _ in self?.toggleDragMode() }
        let fill = CPBarButton(title: "เต็มจอ") { [weak self] _ in self?.engine.toggleVideoFill() }
        modeButton = mode
        template.leadingNavigationBarButtons = [back, home]
        template.trailingNavigationBarButtons = [mode, fill]

        template.mapButtons = [
            mapButton("gobackward.10") { [weak self] in self?.engine.seek(by: -10) },
            mapButton("playpause.fill") { [weak self] in self?.engine.togglePlayPause() },
            mapButton("goforward.10") { [weak self] in self?.engine.seek(by: 10) },
            mapButton("hand.tap.fill") { [weak self] in
                guard let self, !self.isMoving else { return }
                self.engine.clickAtCursor()
            },
        ]
        return template
    }

    private func mapButton(_ symbol: String, action: @escaping () -> Void) -> CPMapButton {
        let button = CPMapButton { _ in action() }
        button.image = UIImage(
            systemName: symbol,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 26, weight: .semibold)
        )
        return button
    }

    private func toggleDragMode() {
        dragMode = dragMode == .scroll ? .cursor : .scroll
        modeButton?.title = dragMode.buttonTitle
    }
}

extension CarPlaySceneDelegate: CPMapTemplateDelegate {
    func mapTemplateDidBeginPanGesture(_ mapTemplate: CPMapTemplate) {
        lastPanTranslation = .zero
    }

    func mapTemplate(_ mapTemplate: CPMapTemplate, didUpdatePanGestureWithTranslation translation: CGPoint, velocity: CGPoint) {
        // translation is cumulative since the gesture began; convert to a delta.
        let dx = translation.x - lastPanTranslation.x
        let dy = translation.y - lastPanTranslation.y
        lastPanTranslation = translation
        guard !isMoving else { return }
        switch dragMode {
        case .scroll: engine.scroll(dx: -dx, dy: -dy)
        case .cursor: engine.moveCursor(dx: dx, dy: dy)
        }
    }

    func mapTemplate(_ mapTemplate: CPMapTemplate, didEndPanGestureWithVelocity velocity: CGPoint) {
        lastPanTranslation = .zero
    }
}

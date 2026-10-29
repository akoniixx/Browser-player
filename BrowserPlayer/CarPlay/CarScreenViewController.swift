import Combine
import UIKit

/// Root view controller of the CarPlay window: the web page, a pointer, and the driving overlay.
final class CarScreenViewController: UIViewController {
    private let engine = BrowserEngine.shared
    private let cursorView = UIView()
    private let drivingOverlay = UIView()
    private var cancellables = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        engine.carDidConnect(container: view)
        setUpCursor()
        setUpDrivingOverlay()

        engine.$cursorPosition
            .receive(on: DispatchQueue.main)
            .sink { [weak self] point in self?.cursorView.center = point }
            .store(in: &cancellables)

        DrivingSafetyMonitor.shared.$isMoving
            .receive(on: DispatchQueue.main)
            .sink { [weak self] moving in
                self?.drivingOverlay.isHidden = !moving
                self?.cursorView.isHidden = moving
            }
            .store(in: &cancellables)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        engine.centerCursorIfNeeded()
    }

    private func setUpCursor() {
        cursorView.frame = CGRect(x: 0, y: 0, width: 22, height: 22)
        cursorView.layer.cornerRadius = 11
        cursorView.backgroundColor = UIColor.white.withAlphaComponent(0.55)
        cursorView.layer.borderColor = UIColor.systemBlue.cgColor
        cursorView.layer.borderWidth = 3
        cursorView.layer.shadowColor = UIColor.black.cgColor
        cursorView.layer.shadowOpacity = 0.6
        cursorView.layer.shadowRadius = 3
        cursorView.layer.shadowOffset = .zero
        cursorView.isUserInteractionEnabled = false
        view.addSubview(cursorView)
    }

    private func setUpDrivingOverlay() {
        drivingOverlay.backgroundColor = .black
        drivingOverlay.translatesAutoresizingMaskIntoConstraints = false
        drivingOverlay.isHidden = true

        let icon = UIImageView(image: UIImage(systemName: "car.fill"))
        icon.tintColor = .white
        icon.contentMode = .scaleAspectFit

        let label = UILabel()
        label.text = "ซ่อนวิดีโอขณะรถเคลื่อนที่เพื่อความปลอดภัย\nเสียงยังเล่นต่อได้ — จอดรถเพื่อดูภาพ"
        label.textColor = .white
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.numberOfLines = 0
        label.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [icon, label])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        drivingOverlay.addSubview(stack)
        view.addSubview(drivingOverlay)
        NSLayoutConstraint.activate([
            drivingOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            drivingOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            drivingOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            drivingOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            icon.widthAnchor.constraint(equalToConstant: 56),
            icon.heightAnchor.constraint(equalToConstant: 56),
            stack.centerXAnchor.constraint(equalTo: drivingOverlay.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: drivingOverlay.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: drivingOverlay.leadingAnchor, constant: 24),
        ])
    }
}

import CoreLocation
import Foundation

/// Watches GPS speed so the car screen can hide video while the car is moving.
final class DrivingSafetyMonitor: NSObject, ObservableObject {
    static let shared = DrivingSafetyMonitor()

    @Published private(set) var isMoving = false
    @Published private(set) var authorization: CLAuthorizationStatus = .notDetermined

    /// Hysteresis so stop-and-go traffic doesn't flicker the overlay.
    private let movingSpeed: CLLocationSpeed = 10 / 3.6
    private let stoppedSpeed: CLLocationSpeed = 3 / 3.6

    private let manager = CLLocationManager()
    private var started = false

    var hasPermission: Bool {
        authorization == .authorizedWhenInUse || authorization == .authorizedAlways
    }

    private override init() {
        super.init()
        manager.delegate = self
        manager.activityType = .automotiveNavigation
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.pausesLocationUpdatesAutomatically = false
        authorization = manager.authorizationStatus
    }

    func start() {
        guard !started else { return }
        started = true
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        beginUpdatesIfAllowed()
    }

    private func beginUpdatesIfAllowed() {
        guard started, hasPermission else { return }
        manager.allowsBackgroundLocationUpdates = true
        manager.startUpdatingLocation()
    }
}

extension DrivingSafetyMonitor: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
        beginUpdatesIfAllowed()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let speed = locations.last?.speed, speed >= 0 else { return }
        if speed >= movingSpeed {
            if !isMoving { isMoving = true }
        } else if speed <= stoppedSpeed {
            if isMoving { isMoving = false }
        }
    }
}

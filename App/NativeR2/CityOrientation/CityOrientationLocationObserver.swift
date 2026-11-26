import Foundation
import CoreLocation
import UIKit

/// Foreground-only position for the live run map: distance to the next control point and the
/// walked distance metric. Like `TeamTrailForegroundRecorder`, it never asks for permission and
/// never runs in the background. It only reads; arrival is still `PlayArrivalService` and the
/// server, and the 50 m highlight never punches by itself (`PlayArrivalPolicy.stationHighlightMeters`).
@MainActor final class CityOrientationLocationObserver: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    struct Fix: Equatable {
        /// GCJ-02, the datum the run's control points use.
        let latitude: Double
        let longitude: Double
        let accuracyMeters: Double
    }
    enum Access: Equatable { case notDetermined, denied, granted }

    @Published private(set) var fix: Fix?
    @Published private(set) var walkedMeters: Double = 0
    @Published private(set) var access: Access = .notDetermined
    private var manager: CLLocationManager?
    private var lastWalked: Fix?

    static var currentAccess: Access {
        guard CLLocationManager.locationServicesEnabled() else { return .denied }
        switch CLLocationManager().authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: return .granted
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }

    /// No-op unless already authorized and foreground. Never requests authorization.
    func start() {
        access = Self.currentAccess
        guard manager == nil, access == .granted, UIApplication.shared.applicationState == .active else { return }
        let manager = CLLocationManager()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
        manager.activityType = .fitness
        manager.pausesLocationUpdatesAutomatically = true
        self.manager = manager
        manager.startUpdatingLocation()
    }

    func stop() {
        manager?.stopUpdatingLocation(); manager?.delegate = nil; manager = nil
    }

    /// Distance in metres from the last fix to a GCJ-02 point; nil without a fix or coordinate.
    func distance(toLatitude latitude: Double?, longitude: Double?) -> Double? {
        guard let fix, let latitude, let longitude else { return nil }
        return PlayArrivalPolicy.distanceMeters(latitude: fix.latitude, longitude: fix.longitude,
                                                toLatitude: latitude, toLongitude: longitude)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard self.manager === manager else { return }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: access = .granted
        default: access = .denied; stop()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard self.manager === manager else { return }
        guard UIApplication.shared.applicationState == .active else { stop(); return }
        for location in locations where location.horizontalAccuracy >= 0 {
            guard let raw = RoamCoordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude),
                  let center = try? RuntimeLocationProjection.gcj02MapCenter(.init(coordinate: raw, datum: .wgs84)) else { continue }
            let next = Fix(latitude: center.coordinate.latitude, longitude: center.coordinate.longitude,
                           accuracyMeters: location.horizontalAccuracy)
            fix = next
            // Walked distance follows the team-trail rule: coarse fixes and standing jitter are not steps.
            guard location.horizontalAccuracy <= TeamWalkedTrail.maxAccuracyMeters else { continue }
            if let last = lastWalked {
                let step = PlayArrivalPolicy.distanceMeters(latitude: last.latitude, longitude: last.longitude,
                                                            toLatitude: next.latitude, toLongitude: next.longitude)
                guard step >= TeamWalkedTrail.minStepMeters else { continue }
                walkedMeters += step
            }
            lastWalked = next
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard self.manager === manager else { return }
        if (error as? CLError)?.code == .denied { access = .denied; stop() }
    }
}

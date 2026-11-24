import Foundation
import CoreLocation
import UIKit

/// Feeds `TeamWalkedTrail` for the team route sync while it is sharing. Like the mini-program's play trail,
/// it never asks for permission and never runs in the background: it starts only when When-In-Use (or
/// Always) is already granted and the app is active, and stops when either changes. Points are GCJ-02,
/// the datum `wx.startLocationUpdate` reports and the backend stores.
@MainActor final class TeamTrailForegroundRecorder: NSObject, @preconcurrency CLLocationManagerDelegate {
    private(set) var trail = TeamWalkedTrail()
    private var manager: CLLocationManager?

    var points: [TeamTrailPoint] { trail.points }

    static var isAuthorized: Bool {
        guard CLLocationManager.locationServicesEnabled() else { return false }
        switch CLLocationManager().authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: return true
        default: return false
        }
    }

    /// No-op unless already authorized and foreground. Never requests authorization.
    func start() {
        guard manager == nil, UIApplication.shared.applicationState == .active, Self.isAuthorized else { return }
        let manager = CLLocationManager()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = TeamWalkedTrail.minStepMeters
        manager.activityType = .fitness
        manager.pausesLocationUpdatesAutomatically = true
        self.manager = manager
        manager.startUpdatingLocation()
    }

    func stop() {
        manager?.stopUpdatingLocation(); manager?.delegate = nil; manager = nil
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard self.manager === manager else { return }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: break
        default: stop()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard self.manager === manager else { return }
        guard UIApplication.shared.applicationState == .active else { stop(); return }
        for location in locations where location.horizontalAccuracy >= 0 {
            guard let raw = RoamCoordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude),
                  let center = try? RuntimeLocationProjection.gcj02MapCenter(.init(coordinate: raw, datum: .wgs84)) else { continue }
            trail.note(latitude: center.coordinate.latitude, longitude: center.coordinate.longitude, accuracy: location.horizontalAccuracy)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard self.manager === manager else { return }
        if (error as? CLError)?.code == .denied { stop() }
    }
}

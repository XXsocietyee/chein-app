import Foundation
import CoreLocation
import SwiftUI
import UIKit

/// OWN-D-07.a: the app's single session-location owner table (`mp:utils/location/bg-tracker.js`).
/// Roam takes a background-capable hold; play takes a foreground-only hold (`mp:pages/play/index.js:5317`
/// `foregroundOnly: true`). Nothing here shares a location with anyone or uploads it; the sessions that
/// hold it send their own existing reads and writes.
@MainActor final class SessionBackgroundLocationTracker: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate, SessionLocationDriving {
    static let shared = SessionBackgroundLocationTracker()

    private(set) lazy var ledger: SessionLocationHoldLedger = {
        let ledger = SessionLocationHoldLedger(driver: self)
        ledger.onChange = { [weak self] in self?.objectWillChange.send() }
        return ledger
    }()
    private let makeManager: () -> CLLocationManager
    private var manager: CLLocationManager?
    private(set) var latest: CLLocation?
    private var waiters: [UUID: CheckedContinuation<CLLocation, Error>] = [:]

    init(makeManager: @escaping () -> CLLocationManager = { CLLocationManager() }) {
        self.makeManager = makeManager
        super.init()
    }

    // MARK: SessionLocationDriving

    func startUpdates(background: Bool) {
        let manager = self.manager ?? makeManager()
        self.manager = manager
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .fitness
        manager.pausesLocationUpdatesAutomatically = false
        // Background flags only while a background-capable hold exists. Setting them without the
        // `location` background mode would crash; Base.xcconfig declares it.
        if background, Self.declaresBackgroundLocationMode {
            manager.allowsBackgroundLocationUpdates = true
            manager.showsBackgroundLocationIndicator = true
        } else {
            manager.allowsBackgroundLocationUpdates = false
            manager.showsBackgroundLocationIndicator = false
        }
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization() // When-In-Use only; never Always.
        case .denied, .restricted: Task { @MainActor [weak self] in self?.ledger.driverFailed(PlayExperienceError.disabled) }
        default: manager.startUpdatingLocation()
        }
    }

    func stopUpdates() {
        if let manager {
            manager.stopUpdatingLocation()
            manager.allowsBackgroundLocationUpdates = false
            manager.showsBackgroundLocationIndicator = false
            manager.delegate = nil
        }
        manager = nil
        latest = nil
        let pending = waiters; waiters = [:]
        pending.values.forEach { $0.resume(throwing: CancellationError()) }
    }

    static var declaresBackgroundLocationMode: Bool {
        (Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String])?.contains("location") == true
    }

    // MARK: Fixes

    /// A fix no older than `maxAge`, or the next one. Fails when the hold ends or after `timeout`.
    func nextFix(maxAge: TimeInterval = 3, timeout: TimeInterval = 30) async throws -> CLLocation {
        if let latest, Date().timeIntervalSince(latest.timestamp) <= maxAge { return latest }
        guard ledger.isRunning else { throw PlayExperienceError.disabled }
        let id = UUID()
        let timer = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(timeout))
            guard !Task.isCancelled, let reply = self?.waiters.removeValue(forKey: id) else { return }
            reply.resume(throwing: PlayExperienceError.unsupported)
        }
        defer { timer.cancel() }
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { waiters[id] = $0 }
        }, onCancel: {
            Task { @MainActor [weak self] in self?.waiters.removeValue(forKey: id)?.resume(throwing: CancellationError()) }
        })
    }

    // MARK: CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard manager === self.manager, ledger.isRunning else { return }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: manager.startUpdatingLocation()
        case .denied, .restricted: ledger.driverFailed(PlayExperienceError.disabled)
        default: break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard manager === self.manager, let location = locations.last else { return }
        // OWN-D-07.d: an account change releases its holds in this same callback.
        ledger.dropStaleOwners()
        guard ledger.isRunning else { return }
        latest = location
        let pending = waiters; waiters = [:]
        pending.values.forEach { $0.resume(returning: location) }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard manager === self.manager else { return }
        if (error as? CLError)?.code == .denied { ledger.driverFailed(error) }
        // Other errors (locationUnknown) are transient; waiters keep waiting until their timeout.
    }
}

/// OWN-D-07.c: the roam live session's location. The first fix of a start or resume takes the `roam` hold in
/// the foreground; later pulses read the held stream, also in the background. `stop()` (pause, finish, failure,
/// identity change) releases the hold. A revoke from the privacy page fails the next pulse, which pauses the walk.
@MainActor final class SessionTrackedRoamLocationProvider: RoamDeviceLocationProviding {
    static let key = SessionLocationHoldLedger.Purpose.roam.rawValue
    private let tracker: SessionBackgroundLocationTracker
    private let owner: () -> AnyHashable?
    private var revoked = false
    private var stopObservingRevocation: (() -> Void)?

    init(tracker: SessionBackgroundLocationTracker = .shared, owner: @escaping () -> AnyHashable?) {
        self.tracker = tracker; self.owner = owner
    }

    var continuesInBackground: Bool { tracker.ledger.hasOwner(Self.key) && tracker.ledger.isBackground }

    func currentFix() async throws -> RoamDeviceFix {
        guard !revoked else { throw PlayExperienceError.disabled }
        if !tracker.ledger.hasOwner(Self.key) {
            // A hold starts only from the explicit start/resume gesture, in the foreground.
            guard UIApplication.shared.applicationState == .active, CLLocationManager.locationServicesEnabled(),
                  let captured = owner() else { throw PlayExperienceError.disabled }
            if CLLocationManager().authorizationStatus == .notDetermined {
                guard await CYPermissionSystemPrompt.precede(.location) else { throw PlayExperienceError.disabled }
            }
            stopObservingRevocation?()
            stopObservingRevocation = tracker.ledger.observeRevocation(Self.key) { [weak self] in self?.revoked = true }
            tracker.ledger.acquire(Self.key, foregroundOnly: false, isCurrent: { [owner] in owner() == captured })
        }
        let location = try await tracker.nextFix()
        guard !revoked, tracker.ledger.hasOwner(Self.key),
              let coordinate = RoamCoordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude) else {
            throw PlayExperienceError.disabled
        }
        return try RoamDeviceFix(coordinate: coordinate, accuracyMeters: location.horizontalAccuracy, measuredAt: location.timestamp, datum: .wgs84)
    }

    func stop() {
        revoked = false
        stopObservingRevocation?(); stopObservingRevocation = nil
        tracker.ledger.release(Self.key)
    }
}

extension SessionBackgroundLocationTracker {
    /// A fresh fix from a held stream, for one-shot consumers (play arrival). Nil when no hold runs.
    func freshFix(maxAge: TimeInterval = 5) -> CLLocation? {
        guard ledger.isRunning, let latest, Date().timeIntervalSince(latest.timestamp) <= maxAge else { return nil }
        return latest
    }
    /// Play may take its foreground hold only when When-In-Use is already granted: the first prompt stays behind
    /// the existing primer on the arrival action.
    static var locationAlreadyAuthorized: Bool {
        CLLocationManager.locationServicesEnabled()
            && [.authorizedWhenInUse, .authorizedAlways].contains(CLLocationManager().authorizationStatus)
    }
}

/// OWN-D-07.b: the play run holds a foreground-only session hold from start until finish, exit, leaving the page,
/// going to the background or an account change (`mp:pages/play/index.js:5286-5330`, `foregroundOnly: true`,
/// `_themeHidden` stops tracking). The running stream feeds the arrival check with a fresh fix.
struct PlaySessionLocationHold: ViewModifier {
    let identity: String?
    let running: Bool
    let currentIdentity: () -> String?
    @Environment(\.scenePhase) private var scenePhase
    @State private var heldKey: String?
    private var wanted: String? {
        guard running, scenePhase == .active, let identity, SessionBackgroundLocationTracker.locationAlreadyAuthorized else { return nil }
        return "play:" + identity
    }
    func body(content: Content) -> some View {
        content
            .onChange(of: wanted, initial: true) { _, next in sync(next) }
            .onDisappear { sync(nil) }
    }
    @MainActor private func sync(_ next: String?) {
        let ledger = SessionBackgroundLocationTracker.shared.ledger
        var held = heldKey
        if let key = held, key != next { ledger.release(key); held = nil }
        if let next, held == nil, let identity,
           ledger.acquire(next, foregroundOnly: true, isCurrent: { [currentIdentity] in currentIdentity() == identity }) { held = next }
        if held != heldKey { heldKey = held }
    }
}

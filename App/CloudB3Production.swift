import CoreLocation
import SwiftUI
import UIKit

/// Fills the existing `PlayThemePresentationReading`. Look tokens become `CYThemeLook`;
/// an unknown style stays nil, which is the legacy look.
@MainActor final class PlayThemeFactsStore: PlayThemePresentationReading {
    struct Owner: Equatable { let accountID: Int; let epoch: UInt64 }
    private let currentOwner: () -> Owner?
    private var owner: Owner?
    private var byTopic: [Int: PlayThemePresentationFacts] = [:]

    init(currentOwner: @escaping () -> Owner?) { self.currentOwner = currentOwner }

    func accept(_ result: PlayNodesResult) {
        guard let owner = currentOwner() else { self.owner = nil; byTopic.removeAll(); return }
        if self.owner != owner { byTopic.removeAll(); self.owner = owner }
        guard let topicID = result.topicID, topicID > 0 else { return }
        let server = result.themeFacts
        byTopic[topicID] = PlayThemePresentationFacts(
            look: server.look.flatMap { CYThemeLook(style: $0.style, palette: $0.palette, neon: $0.neon) },
            aiGenerated: server.aiGenerated,
            productType: server.productType,
            coverURL: server.coverURL)
    }

    func facts(topicID: Int) -> PlayThemePresentationFacts? {
        guard topicID > 0, currentOwner() == owner else { return nil }
        return byTopic[topicID]
    }
}

extension AppSession: OrientScoreEntryProviding {
    func orientScoreLoader(topicID: Int, activityID: Int) -> (() async throws -> OrientSessionScore?)? {
        CloudB3SessionBridge.orientLoader(session: self, topicID: topicID, activityID: activityID)
    }

    func orientScoreRoundsLoader(topicID: Int, activityID: Int) -> ((Int?) async throws -> OrientScoreLoad)? {
        CloudB3SessionBridge.orientRoundsLoader(session: self, topicID: topicID, activityID: activityID)
    }
}

/// Holds the per-session readers outside `AppSession` so that glue file does not grow.
@MainActor enum CloudB3SessionBridge {
    @MainActor private final class Slot {
        weak var session: AppSession?
        let facts: PlayThemeFactsStore
        let emergency: PlayEmergencyLocationConformer
        let reviewAudit: IMReviewAuditSessionReader
        let routeMap: SquareRouteMapProvider
        init(session: AppSession) {
            self.session = session
            reviewAudit = IMReviewAuditSessionReader(session: session)
            facts = PlayThemeFactsStore(currentOwner: { [weak session] in
                guard let session, let account = session.account else { return nil }
                return PlayThemeFactsStore.Owner(accountID: account.id, epoch: session.sessionRevision)
            })
            emergency = PlayEmergencyLocationConformer()
            routeMap = SquareRouteMapProvider { [weak session] id in
                guard let session else { throw CancellationError() }
                return try await session.topicReader.topicDetailDocument(id: id)
            }
        }
    }
    private static var slots: [Slot] = []

    private static func slot(for session: AppSession) -> Slot {
        slots.removeAll { $0.session == nil }
        if let existing = slots.first(where: { $0.session === session }) { return existing }
        let created = Slot(session: session)
        slots.append(created)
        return created
    }

    static func routeMap(for session: AppSession) -> SquareRouteMapProvider { slot(for: session).routeMap }

    static func acceptNodes(_ result: PlayNodesResult, session: AppSession) {
        slot(for: session).facts.accept(result)
    }

    static func facts(for session: AppSession) -> PlayThemeFactsStore { slot(for: session).facts }

    static func emergency(for session: AppSession) -> PlayEmergencyLocationConformer { slot(for: session).emergency }

    static func reviewAudit(for session: AppSession) -> IMReviewAuditSessionReader { slot(for: session).reviewAudit }

    static func filingNumber(_ session: AppSession) async -> String? {
        let owner = session.account?.id
        do {
            let value = try await session.squareReader.aigcFilingNumber()
            guard session.account?.id == owner else { return nil }
            return value
        } catch {
            return nil
        }
    }

    static func reportUnread(_ session: AppSession) async -> Int? {
        guard let service = session.squareGovernance()?.service else { return nil }
        let access = session.squareGovernanceAccess()
        return await ReportProgressUnreadReader(service: service, token: { access.token }, accountID: { session.account?.id }).unreadCount()
    }

    static func orientLoader(session: AppSession, topicID: Int, activityID: Int) -> (() async throws -> OrientSessionScore?)? {
        guard let configuration = session.regionalConfiguration?.apiConfiguration else { return nil }
        let service = OrientSessionService(configuration: configuration, transport: session.runtimeHTTPTransport, contract: .currentC6)
        let access = session.squareGovernanceAccess()
        return OrientScoreEntryProvider(service: service, token: { access.token }).orientScoreLoader(topicID: topicID, activityID: activityID)
    }

    static func orientRoundsLoader(session: AppSession, topicID: Int, activityID: Int) -> ((Int?) async throws -> OrientScoreLoad)? {
        guard let configuration = session.regionalConfiguration?.apiConfiguration else { return nil }
        let service = OrientSessionService(configuration: configuration, transport: session.runtimeHTTPTransport, contract: .currentC6)
        let access = session.squareGovernanceAccess()
        return OrientScoreEntryProvider(service: service, token: { access.token }).orientScoreRoundsLoader(topicID: topicID, activityID: activityID)
    }

    static func installSweepWriters(for session: AppSession) {
        ChallengePOIWriterFactory.makeWriter = {
            ChallengePOIHTTPWriter(
                configuration: { await MainActor.run { session.regionalConfiguration?.apiConfiguration } },
                transport: session.runtimeHTTPTransport,
                tokenProvider: { await MainActor.run { session.token } },
                isRouteOpen: { await MainActor.run {
                    session.isSignedIn
                        && session.regionalConfiguration?.market == .china
                        && (session.account?.role == "player" || session.account?.role == "club")
                        && session.regionalConfiguration?.showsRoute("/api/city/nodes/{}/complete") == true
                } }
            )
        }
        MyProjectMutationFactory.makeMutator = {
            MyProjectHTTPMutator(
                configuration: { await MainActor.run { session.regionalConfiguration?.apiConfiguration } },
                transport: session.runtimeHTTPTransport,
                tokenProvider: { await MainActor.run { session.token } },
                allowsCancelActivity: { await MainActor.run {
                    let host = session.regionalConfiguration?.apiConfiguration?.baseURL.host
                    return ReviewedAreaSwitch.moneyPayments(apiHost: host)
                        && !ReleaseMoneyWriteSwitch.blocks("/api/activity/cancel")
                } }
            )
        }
    }
}

/// Foreground, one-shot location for the SOS copy row. It never calls
/// `requestWhenInUseAuthorization` or `startUpdatingLocation`. Not-yet-authorized returns nil.
@MainActor final class PlayEmergencyLocationConformer: NSObject, PlayEmergencyLocationProviding, @preconcurrency CLLocationManagerDelegate {
    var heldFix: () -> (latitude: Double, longitude: Double)? = { nil }
    private var manager: CLLocationManager?
    private var pending: CheckedContinuation<(latitude: Double, longitude: Double)?, Never>?
    private var pendingID: UUID?
    private var timeout: Task<Void, Never>?

    func currentCoordinate() async -> (latitude: Double, longitude: Double)? {
        if let held = heldFix(), Self.usable(held) { return held }
        guard UIApplication.shared.applicationState == .active, pending == nil,
              let purpose = Bundle.main.object(forInfoDictionaryKey: "NSLocationWhenInUseUsageDescription") as? String,
              !purpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              CLLocationManager.locationServicesEnabled() else { return nil }
        switch CLLocationManager.authorizationStatus() {
        case .authorizedAlways, .authorizedWhenInUse: break
        default: return nil
        }
        let id = UUID()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { reply in
                pending = reply
                pendingID = id
                let manager = CLLocationManager()
                self.manager = manager
                manager.delegate = self
                manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
                timeout = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(12))
                    if self?.pendingID == id { self?.finish(nil) }
                }
                manager.requestLocation()
            }
        } onCancel: {
            Task { @MainActor [weak self] in if self?.pendingID == id { self?.finish(nil) } }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard self.manager === manager else { return }
        guard UIApplication.shared.applicationState == .active else { finish(nil); return }
        guard let value = locations.last else { finish(nil); return }
        let coordinate = (latitude: value.coordinate.latitude, longitude: value.coordinate.longitude)
        finish(Self.usable(coordinate) ? coordinate : nil)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError _: Error) {
        guard self.manager === manager else { return }
        finish(nil)
    }

    private func finish(_ value: (latitude: Double, longitude: Double)?) {
        let reply = pending
        pending = nil
        pendingID = nil
        timeout?.cancel()
        timeout = nil
        manager?.delegate = nil
        manager = nil
        reply?.resume(returning: value)
    }

    private static func usable(_ value: (latitude: Double, longitude: Double)) -> Bool {
        value.latitude.isFinite && value.longitude.isFinite && !(value.latitude == 0 && value.longitude == 0)
    }
}

struct CloudB3RootModifier: ViewModifier {
    let session: AppSession
    @State private var filingNumber: String?
    @State private var reportUnread: Int?

    init(session: AppSession) {
        self.session = session
        CloudB3SessionBridge.installSweepWriters(for: session)
    }

    func body(content: Content) -> some View {
        content
            .environment(\.playThemePresentationReader, CloudB3SessionBridge.facts(for: session))
            .environment(\.playEmergencyLocationProvider, CloudB3SessionBridge.emergency(for: session))
            .environment(\.imReviewAuditReader, CloudB3SessionBridge.reviewAudit(for: session))
            .environment(\.imReportProgressUnread, reportUnread)
            .environment(\.aigcFilingNumber, filingNumber)
            .environment(\.squareRouteMap, CloudB3SessionBridge.routeMap(for: session))
            .task(id: session.account?.id) {
                let owner = session.account?.id
                filingNumber = nil
                reportUnread = nil
                let filing = await CloudB3SessionBridge.filingNumber(session)
                guard !Task.isCancelled, session.account?.id == owner else { return }
                filingNumber = filing
                let unread = await CloudB3SessionBridge.reportUnread(session)
                guard !Task.isCancelled, session.account?.id == owner else { return }
                reportUnread = unread
            }
    }
}

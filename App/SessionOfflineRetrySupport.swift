import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// Thread-safe accumulator used by `SessionOfflineSyncModel.performWriteOptIn` so captured
/// pre-send offline `URLRequest`s are drained deterministically as soon as the write returns.
final class OfflinePreSendCaptureBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [URLRequest] = []
    private var confirmed: Set<String> = []

    func append(_ request: URLRequest) {
        lock.lock()
        requests.append(request)
        lock.unlock()
    }

    func drain() -> [URLRequest] {
        lock.lock()
        let copy = requests
        requests.removeAll()
        lock.unlock()
        return copy
    }

    func noteConfirmed(path: String, key: String) {
        lock.lock()
        confirmed.insert(path + "\n" + key)
        lock.unlock()
    }

    func isConfirmed(path: String, key: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return confirmed.contains(path + "\n" + key)
    }
}

/// Package 63 offline + idempotent-write queue coordinator kept outside `AppSession.swift`
/// and `AppCompositionRoot.swift` so composition line ratchets stay intact.
@MainActor
@Observable
final class SessionOfflineSyncModel {
    static let shared = SessionOfflineSyncModel()

    private(set) var queuedCount: Int = 0
    private(set) var lockedUnknownCount: Int = 0
    private(set) var isSyncing: Bool = false
    private(set) var lastReport: OfflineWriteQueueFlushReport?
    private(set) var blockedMoneyWarningVisible: Bool = false
    private(set) var recentlySyncedPaths: Set<String> = []
    private(set) var rejectedMoneyPaths: Set<String> = []

    private var queue: OfflineIdempotentWriteQueue?
    private var boundScope: OfflineWriteQueueScope?
    private weak var boundSession: AppSession?
    private var customDirectory: URL?

    init(directory: URL? = nil) {
        self.customDirectory = directory
    }

    func bind(session: AppSession) {
        let nextScope = session.currentOfflineWriteScope
        if nextScope == nil {
            boundSession = nil
        } else {
            boundSession = session
        }
        if boundScope != nextScope {
            boundScope = nextScope
            lastReport = nil
            blockedMoneyWarningVisible = false
            recentlySyncedPaths.removeAll()
            rejectedMoneyPaths.removeAll()
            queue = nextScope.flatMap { Self.openQueue(for: $0, directory: customDirectory) }
        }
        refreshCounts()
    }

    /// Resolves the best active `AppSession` for nested screens that may not directly own an `@EnvironmentObject`.
    func resolveSession(_ explicit: AppSession?, environment: AppSession?) -> AppSession? {
        if let explicit { return explicit }
        if let environment { return environment }
        guard let boundSession, let boundScope, boundSession.currentOfflineWriteScope == boundScope else {
            return nil
        }
        return boundSession
    }

    @discardableResult
    func enqueueNonMoneyIdempotentWrite(
        _ request: URLRequest,
        session: AppSession,
        explicitKey: String? = nil
    ) -> Bool {
        bind(session: session)
        guard let queue, let scope = boundScope else { return false }
        let path = request.url.map { ChinaReviewedRouteCapability.normalized($0.path) } ?? ""
        do {
            let item = try queue.enqueueOfflineWrite(request, scope: scope, explicitKey: explicitKey)
            recentlySyncedPaths.remove(item.path)
            rejectedMoneyPaths.remove(item.path)
            refreshCounts()
            return true
        } catch OfflineWriteQueueError.moneyWriteNeverAutoReplayed {
            blockedMoneyWarningVisible = true
            if !path.isEmpty { rejectedMoneyPaths.insert(path) }
            return false
        } catch {
            return false
        }
    }

    func status(
        for paths: [String],
        isOnline: Bool = SharedNetworkReachabilityState.shared.isOnline
    ) -> CYOfflineWriteScreenStatus {
        let normalized = Set(paths.map(ChinaReviewedRouteCapability.normalized))
        guard !normalized.isEmpty else { return .none }
        if !rejectedMoneyPaths.isDisjoint(with: normalized) {
            return .moneyExcluded
        }
        if let queue, let scope = boundScope {
            let matching = queue.pendingItems(for: scope).filter { normalized.contains($0.path) }
            let queued = matching.filter { $0.status == .queuedOffline }.count
            if isSyncing && queued > 0 {
                return .syncing(count: queued)
            }
            if queued > 0 {
                return .queued(count: queued)
            }
            let locked = matching.filter { $0.status == .waitingExplicitConfirmation }.count
            if locked > 0 {
                return .waitingConfirmation(count: locked)
            }
            let rejected = matching.filter { $0.status == .rejected }.count
            if rejected > 0 {
                return .rejected(count: rejected)
            }
        }
        if !recentlySyncedPaths.isDisjoint(with: normalized) {
            return .synced
        }
        return .none
    }

    func dismissSynced(for paths: [String]) {
        for path in paths {
            let normalized = ChinaReviewedRouteCapability.normalized(path)
            recentlySyncedPaths.remove(normalized)
            rejectedMoneyPaths.remove(normalized)
        }
    }

    /// Executes an opted-in write action while capturing any pre-send unreachable `URLRequest`
    /// matching `routes` and persisting it to `OfflineIdempotentWriteQueue` ("will send when online").
    /// Money writes remain excluded; timeouts/5xx remain locked against auto-replay.
    func performWriteOptIn<T>(
        session: AppSession? = nil,
        environmentSession: AppSession? = nil,
        routes: [String],
        explicitKey: String? = nil,
        operation: @MainActor () async throws -> T
    ) async rethrows -> T {
        let targetSession = resolveSession(session, environment: environmentSession)
        if let targetSession {
            bind(session: targetSession)
        }
        let normalizedRoutes = Set(routes.map(ChinaReviewedRouteCapability.normalized))
        for route in normalizedRoutes {
            recentlySyncedPaths.remove(route)
            rejectedMoneyPaths.remove(route)
        }
        let buffer = OfflinePreSendCaptureBuffer()
        let box = OfflinePreSendCaptureBox(
            onPreSendOffline: { [weak self, weak targetSession] request, _ in
                guard let url = request.url else { return }
                let path = ChinaReviewedRouteCapability.normalized(url.path)
                guard normalizedRoutes.contains(path) || BackendIdempotentWriteRouteCatalog.isMoneyOrCashSensitiveRequest(request) else {
                    return
                }
                buffer.append(request)
                Task { @MainActor [weak self, weak targetSession] in
                    guard let self, let targetSession else { return }
                    let pending = buffer.drain()
                    for req in pending {
                        self.enqueueCaptured(req, buffer: buffer, session: targetSession, explicitKey: explicitKey)
                    }
                }
            },
            onLiveSuccess: { [weak self, weak targetSession] request in
                guard let presented = OfflineIdempotentWriteQueue.presentedIdempotencyKey(on: request) else { return }
                buffer.noteConfirmed(path: presented.path, key: presented.key)
                Task { @MainActor [weak self, weak targetSession] in
                    guard let self, let targetSession else { return }
                    self.bind(session: targetSession)
                    guard let queue = self.queue, let scope = self.boundScope else { return }
                    if (try? queue.dropConfirmedWrite(scope: scope, path: presented.path, idempotencyKey: presented.key)) == true {
                        self.refreshCounts()
                    }
                }
            }
        )
        do {
            let value = try await OfflineWriteCaptureContext.$current.withValue(box) {
                try await operation()
            }
            drainCaptured(buffer, session: targetSession, explicitKey: explicitKey)
            return value
        } catch {
            drainCaptured(buffer, session: targetSession, explicitKey: explicitKey)
            throw error
        }
    }

    private func enqueueCaptured(
        _ request: URLRequest,
        buffer: OfflinePreSendCaptureBuffer,
        session: AppSession,
        explicitKey: String?
    ) {
        if let presented = OfflineIdempotentWriteQueue.presentedIdempotencyKey(on: request),
           buffer.isConfirmed(path: presented.path, key: presented.key) {
            return
        }
        _ = enqueueNonMoneyIdempotentWrite(request, session: session, explicitKey: explicitKey)
    }

    private func drainCaptured(_ buffer: OfflinePreSendCaptureBuffer, session: AppSession?, explicitKey: String?) {
        guard let session else { return }
        for request in buffer.drain() {
            enqueueCaptured(request, buffer: buffer, session: session, explicitKey: explicitKey)
        }
    }

    func flushIfOnline(
        session: AppSession,
        isOnline: @escaping () -> Bool,
        transport: (any HTTPTransport)? = nil
    ) async {
        bind(session: session)
        guard !isSyncing, isOnline(),
              let queue, let scope = boundScope,
              let api = session.regionalConfiguration?.apiConfiguration,
              let token = session.token, AuthRequestBuilder.isValidToken(token) else {
            refreshCounts()
            return
        }
        let queued = queue.queuedItems(for: scope)
        guard !queued.isEmpty else {
            refreshCounts()
            return
        }
        isSyncing = true
        defer {
            isSyncing = false
            refreshCounts()
        }
        do {
            let replayTransport = transport ?? SessionOfflineReplayTransport(session: session)
            let report = try await queue.flushPending(
                scope: scope,
                configuration: api,
                token: token,
                currentScope: { [weak session] in session?.currentOfflineWriteScope },
                isOnline: isOnline,
                transport: replayTransport
            )
            lastReport = report
            recentlySyncedPaths.formUnion(report.succeededPaths)
        } catch {
            lastReport = nil
        }
    }

    func refreshCounts() {
        guard let queue, let scope = boundScope else {
            queuedCount = 0
            lockedUnknownCount = 0
            return
        }
        let scoped = queue.pendingItems(for: scope)
        queuedCount = scoped.filter { $0.status == .queuedOffline }.count
        lockedUnknownCount = scoped.filter { $0.status == .waitingExplicitConfirmation }.count
    }

    private static func openQueue(for scope: OfflineWriteQueueScope, directory: URL? = nil) -> OfflineIdempotentWriteQueue? {
        let baseFolder: URL
        if let directory {
            baseFolder = directory
        } else if let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            baseFolder = support.appendingPathComponent("QuestifyOfflineQueue", isDirectory: true)
        } else {
            return nil
        }
        let safeScope = scope.storageKey.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: ":", with: "_")
        let queueURL = baseFolder.appendingPathComponent("queue-\(safeScope).json")
        let opURL = baseFolder.appendingPathComponent("opids-\(safeScope).json")
        let opStore = try? FileClientOperationIDStore(fileURL: opURL)
        return try? OfflineIdempotentWriteQueue(fileURL: queueURL, operationIDStore: opStore)
    }
}

/// Dispatches replayed offline non-money writes through the matching reviewed lease-checked transport
/// (`RoamLiveWriteTransport` for roam/privateTools, `ProfileParticipantTransport` for address save,
/// and `runtimeHTTPTransport` for reviewed player writes).
private struct SessionOfflineReplayTransport: HTTPTransport {
    private let session: AppSession

    init(session: AppSession) {
        self.session = session
    }

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        let path = request.url.map { ChinaReviewedRouteCapability.normalized($0.path) } ?? ""
        return try await dispatch(path: path, request: request)
    }

    @MainActor
    private func dispatch(path: String, request: URLRequest) async throws -> (Data, Int) {
        let compositionTransport = session.runtimeHTTPTransport as? CompositionHTTPTransport
        switch path {
        case "/api/roam/reveal":
            if let roam = compositionTransport?.makeRoamLiveWriteTransport(profile: .liveRoam) {
                return try await roam.send(request)
            }
        case "/api/roam/stamp/create":
            if let stamp = compositionTransport?.makeRoamLiveWriteTransport(profile: .writes) {
                return try await stamp.send(request)
            }
        case "/api/capsules/create", "/api/exploration-goals/create":
            if let tools = compositionTransport?.makeRoamLiveWriteTransport(profile: .privateTools) {
                return try await tools.send(request)
            }
        case "/api/user/address/action":
            let participantRevision = session.participantRevision
            if let context = session.currentRuntimeDependencyContext,
               let access = session.participantAccessSelector(context),
               let wire = compositionTransport?.makeProfileParticipantTransport(
                   context: context,
                   access: access,
                   currentRuntime: { [weak session] in session?.currentRuntimeDependencyContext },
                   stillCurrent: { [weak session] in session?.participantRevision == participantRevision && session?.participantAccessSelector(context) != nil }
               ) {
                return try await wire.send(request)
            }
        default:
            break
        }
        return try await session.runtimeHTTPTransport.send(request)
    }
}

final class WeakAppSessionBox {
    weak var session: AppSession?
    init(_ session: AppSession?) { self.session = session }
}

private struct OfflineWriteSessionEnvironmentKey: EnvironmentKey {
    static let defaultValue = WeakAppSessionBox(nil)
}

private struct OfflineSyncModelEnvironmentKey: EnvironmentKey {
    @MainActor static var defaultValue: SessionOfflineSyncModel { .shared }
}

extension EnvironmentValues {
    var offlineWriteSession: WeakAppSessionBox {
        get { self[OfflineWriteSessionEnvironmentKey.self] }
        set { self[OfflineWriteSessionEnvironmentKey.self] = newValue }
    }

    var offlineSyncModel: SessionOfflineSyncModel {
        get { self[OfflineSyncModelEnvironmentKey.self] }
        set { self[OfflineSyncModelEnvironmentKey.self] = newValue }
    }
}

/// Standalone view that renders per-screen offline write status (`queued -> syncing -> synced / locked / rejected`)
/// using the shared `SessionOfflineSyncModel`. Safe when `offlineWriteSession` is nil in isolated previews/tests.
@MainActor
struct CYScreenOfflineWriteBanner: View {
    let routes: [String]
    var session: AppSession? = nil
    var accessibilityID: String = "cy.offlineWrite.status"
    var onSynced: (() -> Void)? = nil

    @Environment(\.offlineWriteSession) private var envSession
    @State private var syncModel = SessionOfflineSyncModel.shared
    private var reachability = SharedNetworkReachabilityState.shared

    private var activeSession: AppSession? {
        syncModel.resolveSession(session, environment: envSession.session)
    }

    private var status: CYOfflineWriteScreenStatus {
        syncModel.status(for: routes, isOnline: reachability.isOnline)
    }

    var body: some View {
        CYOfflineWriteStatusBanner(
            status: status,
            isOnline: reachability.isOnline,
            accessibilityID: accessibilityID,
            onSyncNow: activeSession.map { active in
                {
                    Task { await syncModel.flushIfOnline(session: active, isOnline: { reachability.isOnline }) }
                }
            },
            onDismissSynced: {
                syncModel.dismissSynced(for: routes)
            }
        )
        .onChange(of: status) { _, next in
            if case .synced = next { onSynced?() }
        }
        .onAppear {
            if let activeSession { syncModel.bind(session: activeSession) }
        }
    }
}

/// Drop-in `Form`/`List` section that collapses completely when there is no offline write state for `routes`.
@MainActor
struct CYScreenOfflineWriteSection: View {
    let routes: [String]
    var session: AppSession? = nil
    var accessibilityID: String = "cy.offlineWrite.status"
    var onSynced: (() -> Void)? = nil

    @State private var syncModel = SessionOfflineSyncModel.shared
    private var reachability = SharedNetworkReachabilityState.shared

    /// Explicit: the memberwise init is private because of the private stored properties (Xcode 26 rejects it).
    init(routes: [String], session: AppSession? = nil, accessibilityID: String = "cy.offlineWrite.status", onSynced: (() -> Void)? = nil) {
        self.routes = routes
        self.session = session
        self.accessibilityID = accessibilityID
        self.onSynced = onSynced
    }

    var body: some View {
        if syncModel.status(for: routes, isOnline: reachability.isOnline) != .none {
            Section {
                CYScreenOfflineWriteBanner(
                    routes: routes,
                    session: session,
                    accessibilityID: accessibilityID,
                    onSynced: onSynced
                )
            }
        }
    }
}

extension AppSession {
    var currentOfflineWriteScope: OfflineWriteQueueScope? {
        guard let context = currentRuntimeDependencyContext,
              let base = context.baseURL.absoluteString.trimmingCharacters(in: .whitespacesAndNewlines) as String?,
              !base.isEmpty else { return nil }
        return try? OfflineWriteQueueScope(
            accountID: context.session.accountID,
            realm: context.session.namespace,
            baseURL: base
        )
    }
}

/// Global offline + queued-write banner attached cleanly to both player and merchant root shells.
struct SessionOfflineBannerModifier: ViewModifier {
    let reachability: NetworkReachability
    @ObservedObject var session: AppSession
    @State private var syncModel = SessionOfflineSyncModel.shared

    private var showsBanner: Bool {
        reachability.isOffline || syncModel.queuedCount > 0 || syncModel.lockedUnknownCount > 0 || syncModel.blockedMoneyWarningVisible
    }

    func body(content: Content) -> some View {
        content
            .environment(\.offlineWriteSession, WeakAppSessionBox(session))
            .environment(\.offlineSyncModel, syncModel)
            .safeAreaInset(edge: .top, spacing: 0) {
                if showsBanner {
                    VStack(spacing: CYSpacing.xs) {
                        if reachability.isOffline {
                            CYStatusOfflineBanner(
                                messageKey: "cy.state.offline.banner.title",
                                detailKey: syncModel.queuedCount > 0 ? nil : nil,
                                cachedAt: reachability.lastConnectedAt,
                                stillOffline: reachability.stillOfflineAfterRecheck,
                                serious: false,
                                actionTitleKey: "cy.state.offline.banner.retry",
                                onRetry: {
                                    if reachability.recheck() {
                                        Task { await syncModel.flushIfOnline(session: session, isOnline: { !reachability.isOffline }) }
                                    }
                                }
                            )
                        }
                        if syncModel.queuedCount > 0 {
                            offlineQueueStatusCard
                        }
                        if syncModel.lockedUnknownCount > 0 {
                            CYStatusOfflineBanner(
                                messageKey: "cy.state.offline.queue.moneyNoAutoReplay",
                                detailKey: "cy.state.offline.queue.lockedUnknown \(syncModel.lockedUnknownCount)",
                                serious: true
                            )
                        } else if syncModel.blockedMoneyWarningVisible {
                            CYStatusOfflineBanner(
                                messageKey: "cy.state.offline.queue.moneyNoAutoReplay",
                                serious: true
                            )
                        }
                    }
                    .padding(.horizontal, CYSpacing.md)
                    .padding(.top, CYSpacing.xs)
                    .padding(.bottom, CYSpacing.xs)
                }
            }
            .onAppear {
                syncModel.bind(session: session)
            }
            .onChange(of: session.sessionRevision) { _, _ in
                syncModel.bind(session: session)
            }
            .onChange(of: reachability.isOffline) { wasOffline, nowOffline in
                if wasOffline && !nowOffline {
                    Task { await syncModel.flushIfOnline(session: session, isOnline: { !reachability.isOffline }) }
                }
            }
    }

    private var offlineQueueStatusCard: some View {
        HStack(spacing: CYSpacing.sm) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .cyText(.meta, weight: .semibold)
            Text("cy.state.offline.queue.pending \(syncModel.queuedCount)")
                .cyText(.caption)
            Spacer(minLength: CYSpacing.xs)
            if !reachability.isOffline {
                Button {
                    Task { await syncModel.flushIfOnline(session: session, isOnline: { !reachability.isOffline }) }
                } label: {
                    Text(syncModel.isSyncing ? "cy.state.offline.queue.syncing" : "cy.state.offline.queue.syncNow")
                        .cyText(.caption, weight: .semibold)
                }
                .buttonStyle(.bordered)
                .disabled(syncModel.isSyncing)
                .accessibilityIdentifier("cy.offlineQueue.syncNow")
                .accessibilityLabel(Text(LocalizedStringKey(syncModel.isSyncing ? "cy.state.offline.queue.syncing" : "cy.state.offline.queue.syncNow")))
                .accessibilityValue(Text("cy.state.offline.queue.pending \(syncModel.queuedCount)"))
                .accessibilityHint(Text(LocalizedStringKey(syncModel.isSyncing ? "cy.state.offline.queue.syncing" : "cy.state.offline.queue.syncNow")))
            }
        }
        .padding(.horizontal, CYSpacing.md)
        .padding(.vertical, CYSpacing.xs)
        .background(CYColor.bgSurface, in: RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("cy.state.offline.queue.pending \(syncModel.queuedCount)"))
        .accessibilityValue(Text(verbatim: "\(syncModel.queuedCount)"))
        .accessibilityHint(Text(LocalizedStringKey(reachability.isOffline ? "cy.state.offline.banner.title" : (syncModel.isSyncing ? "cy.state.offline.queue.syncing" : "cy.state.offline.queue.syncNow"))))
        .accessibilityIdentifier("cy.offlineQueue.banner")
    }
}

extension View {
    func sessionOfflineBanner(reachability: NetworkReachability, session: AppSession) -> some View {
        modifier(SessionOfflineBannerModifier(reachability: reachability, session: session))
    }
}

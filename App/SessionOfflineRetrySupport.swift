import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// Package 63 offline + idempotent-write queue coordinator kept outside `AppSession.swift`
/// and `AppCompositionRoot.swift` so composition line ratchets stay intact.
@MainActor
@Observable
final class SessionOfflineSyncModel {
    private(set) var queuedCount: Int = 0
    private(set) var lockedUnknownCount: Int = 0
    private(set) var isSyncing: Bool = false
    private(set) var lastReport: OfflineWriteQueueFlushReport?
    private(set) var blockedMoneyWarningVisible: Bool = false

    private var queue: OfflineIdempotentWriteQueue?
    private var boundScope: OfflineWriteQueueScope?

    func bind(session: AppSession) {
        let nextScope = session.currentOfflineWriteScope
        if boundScope != nextScope {
            boundScope = nextScope
            lastReport = nil
            blockedMoneyWarningVisible = false
            queue = nextScope.flatMap { Self.openQueue(for: $0) }
        }
        refreshCounts()
    }

    func enqueueNonMoneyIdempotentWrite(
        _ request: URLRequest,
        session: AppSession,
        explicitKey: String? = nil
    ) -> Bool {
        bind(session: session)
        guard let queue, let scope = boundScope else { return false }
        do {
            _ = try queue.enqueueOfflineWrite(request, scope: scope, explicitKey: explicitKey)
            refreshCounts()
            return true
        } catch OfflineWriteQueueError.moneyWriteNeverAutoReplayed {
            blockedMoneyWarningVisible = true
            return false
        } catch {
            return false
        }
    }

    func flushIfOnline(session: AppSession, isOnline: @escaping () -> Bool) async {
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
            let report = try await queue.flushPending(
                scope: scope,
                configuration: api,
                token: token,
                currentScope: { [weak session] in session?.currentOfflineWriteScope },
                isOnline: isOnline,
                transport: session.composition.makeTransport()
            )
            lastReport = report
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

    private static func openQueue(for scope: OfflineWriteQueueScope) -> OfflineIdempotentWriteQueue? {
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let folder = support.appendingPathComponent("QuestifyOfflineQueue", isDirectory: true)
        let safeScope = scope.storageKey.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: ":", with: "_")
        let queueURL = folder.appendingPathComponent("queue-\(safeScope).json")
        let opURL = folder.appendingPathComponent("opids-\(safeScope).json")
        let opStore = try? FileClientOperationIDStore(fileURL: opURL)
        return try? OfflineIdempotentWriteQueue(fileURL: queueURL, operationIDStore: opStore)
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
    @State private var syncModel = SessionOfflineSyncModel()

    private var showsBanner: Bool {
        reachability.isOffline || syncModel.queuedCount > 0 || syncModel.lockedUnknownCount > 0 || syncModel.blockedMoneyWarningVisible
    }

    func body(content: Content) -> some View {
        content
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
                .font(CYTypography.meta.weight(.semibold))
            Text("cy.state.offline.queue.pending \(syncModel.queuedCount)")
                .font(CYTypography.caption)
            Spacer(minLength: CYSpacing.xs)
            if !reachability.isOffline {
                Button {
                    Task { await syncModel.flushIfOnline(session: session, isOnline: { !reachability.isOffline }) }
                } label: {
                    Text(syncModel.isSyncing ? "cy.state.offline.queue.syncing" : "cy.state.offline.queue.syncNow")
                        .font(CYTypography.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .disabled(syncModel.isSyncing)
                .accessibilityIdentifier("cy.offlineQueue.syncNow")
            }
        }
        .padding(.horizontal, CYSpacing.md)
        .padding(.vertical, CYSpacing.xs)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous))
        .accessibilityIdentifier("cy.offlineQueue.banner")
    }
}

extension View {
    func sessionOfflineBanner(reachability: NetworkReachability, session: AppSession) -> some View {
        modifier(SessionOfflineBannerModifier(reachability: reachability, session: session))
    }
}

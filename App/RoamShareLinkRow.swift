import SwiftUI

/// RSESS-2: the share composer publishes the footprint snapshot so the shared link opens this walk
/// (`subpackageRoam/session?shareToken=`). Failed → 重试; no reviewed publisher → the dormant line as before.
@MainActor struct RoamShareLinkRow: View {
    let record: RoamHistoryRecord
    let includeRoute: Bool
    let routeName: String?
    @Environment(\.roamShareSnapshotPublisher) private var makePublisher
    @State private var reason: RoamShareLinkReason?
    @State private var publishing = false

    var body: some View {
        Group {
            if let publisher = makePublisher?() {
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    switch reason {
                    case .ready(let token)?:
                        if let url = RoamShareSnapshotPublisher.link(token: token) {
                            ShareLink(item: url) { Label("roam.shareLink.send", systemImage: "link") }
                                .frame(minHeight: 44)
                                .accessibilityIdentifier("roam.shareLink.send")
                        }
                        Text("roam.shareLink.ready").cyText(.meta).foregroundStyle(.secondary)
                    case .failed?:
                        Label("roam.shareLink.failed", systemImage: "exclamationmark.triangle").cyText(.meta).foregroundStyle(.secondary)
                        Button("action.retry") { Task { await publish(publisher) } }.frame(minHeight: 44)
                            .accessibilityIdentifier("roam.shareLink.retry")
                    case .unavailable?:
                        RoamShareLinkDormantNotice()
                    case nil:
                        ProgressView { Text("roam.shareLink.publishing") }.accessibilityIdentifier("roam.shareLink.publishing")
                    }
                }
                // MP: every open republishes with the current clipping; a route toggle changes the snapshot.
                .task(id: PublishKey(ts: record.ts, includeRoute: includeRoute)) { await publish(publisher) }
            } else {
                RoamShareLinkDormantNotice()
            }
        }
        .accessibilityIdentifier("roam.shareLink")
    }
    private struct PublishKey: Hashable { let ts: Int64; let includeRoute: Bool }
    private func publish(_ publisher: RoamShareSnapshotPublisher) async {
        guard !publishing else { return }
        guard record.serverSessionID != nil else { reason = .unavailable; return }
        publishing = true; reason = nil
        defer { publishing = false }
        let result = await publisher.publish(record, includeRoute: includeRoute, routeName: routeName)
        guard !Task.isCancelled else { return }
        reason = result
    }
}

private struct RoamShareSnapshotPublisherKey: EnvironmentKey {
    static let defaultValue: (@MainActor () -> RoamShareSnapshotPublisher?)? = nil
}
extension EnvironmentValues {
    var roamShareSnapshotPublisher: (@MainActor () -> RoamShareSnapshotPublisher?)? {
        get { self[RoamShareSnapshotPublisherKey.self] }
        set { self[RoamShareSnapshotPublisherKey.self] = newValue }
    }
}

extension AppSession {
    /// The publish is a write: it needs the reviewed roam live-write approval for this exact path and account.
    func makeRoamShareSnapshotPublisher() -> RoamShareSnapshotPublisher? {
        guard let context = currentRuntimeDependencyContext,
              let configuration = regionalConfiguration?.apiConfiguration,
              let approval = composition.roamLiveWriteApproval(context),
              approval.allows(configuration: configuration, namespace: context.session.namespace,
                  accountID: context.session.accountID, path: RoamShareSnapshotPublisher.path),
              let wire = compositionTransport.makeRoamLiveWriteTransport() else { return nil }
        let accountID = context.session.accountID
        return RoamShareSnapshotPublisher(configuration: configuration, transport: wire, token: { [weak self] in
            guard let self, self.currentRuntimeDependencyContext?.session.accountID == accountID else { return nil }
            return self.token
        })
    }
}

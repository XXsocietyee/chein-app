import SwiftUI
import UIKit

private let table = "PlayRecovery"
private func recoveryText(_ key: String) -> String { String(localized: String.LocalizationValue(key), table: table) }

/// U05-01/02. Why the server did not record this arrival and what can be done next. Reasons come
/// from the stable code only; the server sentence stays in the shared issue row above. A replacement stop is
/// only offered when the server approved it, and arriving there is still a real arrival.
@MainActor struct PlayArrivalFailureSection: View {
    let failure: PlayArrivalFailure
    var onRelocate: (() -> Void)?
    var onScan: (() -> Void)?
    var onRefresh: (() -> Void)?
    var onOpenNode: ((Int) -> Void)?
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                Label {
                    Text(LocalizedStringKey("arrival.reason." + (failure.reason?.rawValue ?? "OTHER")), tableName: table)
                        .cyText(.cardTitle).fixedSize(horizontal: false, vertical: true)
                } icon: { Image(systemName: "location.slash").foregroundStyle(CYColor.warningText) }
                Text(LocalizedStringKey("arrival.next." + (failure.reason?.rawValue ?? "OTHER")), tableName: table)
                    .cyText(.body).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("playRecovery.arrival.reason")
            ForEach(failure.actions, id: \.rawValue) { action in
                switch action {
                case .relocate:
                    if let onRelocate {
                        CYPillButton("arrival.action.relocate", style: .secondary, systemImage: "location", tableName: table, action: onRelocate)
                            .listRowBackground(Color.clear).accessibilityIdentifier("playRecovery.arrival.relocate")
                    }
                case .scanInstead:
                    if let onScan {
                        CYPillButton("arrival.action.scan", style: .tertiary, systemImage: "qrcode.viewfinder", tableName: table, action: onScan)
                            .listRowBackground(Color.clear).accessibilityIdentifier("playRecovery.arrival.scan")
                    } else {
                        Text("arrival.action.scanHint", tableName: table).cyText(.caption).foregroundStyle(CYColor.textSecondary)
                    }
                case .refresh:
                    if let onRefresh {
                        CYPillButton("arrival.action.refresh", style: .secondary, systemImage: "arrow.clockwise", tableName: table, action: onRefresh)
                            .listRowBackground(Color.clear).accessibilityIdentifier("playRecovery.arrival.refresh")
                    }
                case .contactOrganizer:
                    Text("arrival.action.contact", tableName: table).cyText(.caption).foregroundStyle(CYColor.textSecondary)
                        .accessibilityIdentifier("playRecovery.arrival.contact")
                case .appealGuard:
                    Text("arrival.action.appeal", tableName: table).cyText(.caption).foregroundStyle(CYColor.textSecondary)
                        .accessibilityIdentifier("playRecovery.arrival.appeal")
                case .waitForLeader:
                    Text("arrival.action.leader", tableName: table).cyText(.caption).foregroundStyle(CYColor.textSecondary)
                }
            }
            if !failure.replacements.isEmpty {
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    Text("arrival.replacement.title", tableName: table).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    Text("arrival.replacement.body", tableName: table).cyText(.caption).foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(failure.replacements) { stop in
                    if let onOpenNode {
                        Button { onOpenNode(stop.id) } label: {
                            Label { Text("arrival.replacement.open \(stop.name)", tableName: table) } icon: { Image(systemName: "arrow.triangle.branch") }
                        }
                        .accessibilityIdentifier("playRecovery.arrival.replacement.\(stop.id)")
                    } else { Text(verbatim: stop.name) }
                }
            } else if failure.reason == .stopClosed || failure.reason == .coordinatesNotConfigured {
                // U05-02: without an approved replacement there is no skip and no reward.
                Text("arrival.replacement.none", tableName: table).cyText(.caption).foregroundStyle(CYColor.textSecondary)
                    .accessibilityIdentifier("playRecovery.arrival.noReplacement")
            }
        } header: { Text("arrival.title", tableName: table) }
    }
}

/// U05-03. The last submission of this run, as the original receipt says. Pending is never shown
/// as a failure, and nothing here resubmits: "Check again" only re-reads with the same action id.
@MainActor struct PlaySubmitRecoveryRow: View {
    let state: PlaySubmitRecoveryState
    var onCheck: (() -> Void)?
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            switch state {
            case .checking:
                ProgressView { Text("submit.checking", tableName: table) }
            case .pending:
                CYStatusChip(verbatim: recoveryText("submit.pending.chip"), tone: .warning, systemImage: "clock")
                Text("submit.pending.body", tableName: table).cyText(.caption).foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let onCheck {
                    CYPillButton("submit.checkAgain", style: .secondary, systemImage: "arrow.clockwise", tableName: table, action: onCheck)
                        .listRowBackground(Color.clear).accessibilityIdentifier("playRecovery.submit.checkAgain")
                }
            case .confirmed:
                CYStatusChip(verbatim: recoveryText("submit.confirmed.chip"), tone: .success, systemImage: "checkmark.seal")
                Text("submit.confirmed.body", tableName: table).cyText(.caption).foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            case .failed(_, let refusal):
                CYStatusChip(verbatim: recoveryText("submit.failed.chip"), tone: .danger, systemImage: "xmark.circle")
                Text("submit.failed.body", tableName: table).cyText(.caption).foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let message = refusal.message {
                    Text(verbatim: message).cyText(.caption).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                }
            case .conflict:
                CYStatusChip(verbatim: recoveryText("submit.conflict.chip"), tone: .info, systemImage: "arrow.triangle.2.circlepath")
                Text("submit.conflict.body", tableName: table).cyText(.caption).foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityIdentifier("playRecovery.submit")
    }
}

/// U05-02. Route-level change from the server (`route-state.status`).
struct PlayRouteNoticeRow: View {
    let notice: PlayRouteNotice
    var body: some View {
        Label { Text(LocalizedStringKey("route.notice." + notice.rawValue), tableName: table).fixedSize(horizontal: false, vertical: true) }
            icon: { Image(systemName: notice == .switchedToFallback ? "arrow.triangle.branch" : "exclamationmark.triangle") }
            .cyText(.caption).foregroundStyle(CYColor.warningText)
            .accessibilityIdentifier("playRecovery.routeNotice")
    }
}

/// §23.2. Story text the server attached to a real arrival. The level is not a score.
struct PlayArrivalReadingSection: View {
    let reading: PlayArrivalReading
    var body: some View {
        Section {
            Text(verbatim: reading.log).cyText(.body).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("playRecovery.arrivalReading")
        } header: { Text("arrival.reading.title", tableName: table) }
    }
}

/// U05-02 for the shared (organiser) runtime: a paused station's reason, expected resumption and
/// the approved replacement exactly as projected. No replacement means there is nothing to skip to.
struct PlayStationPauseView: View {
    let notice: PlayStationPauseNotice
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            CYStatusChip(verbatim: recoveryText("station.paused.chip"), tone: .warning, systemImage: "pause.circle")
            if let reason = notice.reason { Text(verbatim: reason).cyText(.body).fixedSize(horizontal: false, vertical: true) }
            else { Text("station.paused.noReason", tableName: table).cyText(.caption).foregroundStyle(CYColor.textSecondary) }
            if let eta = notice.resumeEta {
                LabeledContent { Text(verbatim: eta) } label: { Text("station.paused.resume", tableName: table) }.cyText(.caption)
            } else {
                Text("station.paused.resumeUnknown", tableName: table).cyText(.caption).foregroundStyle(CYColor.textSecondary)
            }
            if let message = notice.replacementMessage {
                Label { Text(verbatim: message).fixedSize(horizontal: false, vertical: true) } icon: { Image(systemName: "arrow.triangle.branch") }
                    .cyText(.body)
                if let name = notice.replacementName {
                    Text("station.paused.replacement \(name)", tableName: table).cyText(.caption).foregroundStyle(CYColor.textSecondary)
                }
            } else {
                Text("station.paused.noReplacement", tableName: table).cyText(.caption).foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("station.paused.contact", tableName: table).cyText(.caption).foregroundStyle(CYColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("playRecovery.stationPause")
    }
}

/// Device-side location problems before anything is sent (U05-01 "not authorised" / "invalid").
struct PlayLocationCaptureIssueView: View {
    let issue: PlayExperienceError
    @Environment(\.openURL) private var openURL
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            if issue == .disabled {
                Label { Text("location.denied", tableName: table).fixedSize(horizontal: false, vertical: true) }
                    icon: { Image(systemName: "location.slash") }
                    .cyText(.body)
                Button { if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) } } label: {
                    Text("location.openSettings", tableName: table)
                }.accessibilityIdentifier("playRecovery.location.settings")
                    .accessibilityLabel(Text("location.openSettings", tableName: table))
                    .accessibilityValue(Text("location.denied", tableName: table))
                    .accessibilityHint(Text("location.denied", tableName: table))
            } else {
                Label { Text("location.unusable", tableName: table).fixedSize(horizontal: false, vertical: true) }
                    icon: { Image(systemName: "location.magnifyingglass") }
                    .cyText(.body)
            }
        }
        .foregroundStyle(CYColor.textSecondary)
        .accessibilityIdentifier("playRecovery.location.issue")
    }
}

/// App-side storage and transport for U05-04 downloads: per-device Caches (not backed up), and an
/// ephemeral HTTPS-only session that sends no account credentials to the media host.
enum PlayOfflinePackEnvironment {
    static func store() -> PlayContentPrefetchStore? {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        return PlayContentPrefetchStore(root: caches.appendingPathComponent("PlayContentPrefetch", isDirectory: true))
    }
    static func fetch(approvedHosts: Set<String>) -> @Sendable (URL) async throws -> Data {
        { url in
            guard url.scheme == "https", let host = url.host?.lowercased(), approvedHosts.contains(host) else { throw PlayExperienceError.unsupported }
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 30; configuration.httpCookieStorage = nil; configuration.urlCache = nil
            let (data, response) = try await URLSession(configuration: configuration).data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                  data.count <= PlayContentPrefetchStore.maximumAssetBytes else { throw PlayExperienceError.unknownResult }
            return data
        }
    }
}

/// U05-04. Download for this run and the limited offline scope it can honestly declare.
@MainActor struct PlayOfflinePackView: View {
    @Bindable var model: PlayOfflinePackModel
    @Environment(\.locale) private var locale
    var body: some View {
        List {
            switch model.phase {
            case .idle, .loading:
                Section { CYSkeleton().accessibilityIdentifier("playRecovery.pack.loading") }
            case .failed:
                Section {
                    Text("pack.failed", tableName: table).cyText(.body)
                    CYPillButton("pack.reload", style: .secondary, systemImage: "arrow.clockwise", tableName: table) { Task { await model.load() } }
                        .listRowBackground(Color.clear).accessibilityIdentifier("playRecovery.pack.reload")
                }
            case .loaded:
                if let manifest = model.manifest { content(manifest) }
            }
        }
        .navigationTitle(Text("pack.title", tableName: table)).navigationBarTitleDisplayMode(.inline)
        .task { if model.phase == .idle { await model.load() } }
        .refreshable { await model.load() }
    }

    @ViewBuilder private func content(_ manifest: PlayContentManifest) -> some View {
        Section {
            LabeledContent { Text(LocalizedStringKey("pack.status." + manifest.status.rawValue), tableName: table) }
                label: { Text("pack.identity", tableName: table) }
            if let revision = manifest.revisionNo {
                LabeledContent { Text(verbatim: "#" + String(revision)) } label: { Text("pack.revision", tableName: table) }
            }
            if let synced = model.lastSyncedAt {
                LabeledContent { Text(synced.formatted(date: .abbreviated, time: .shortened)) } label: { Text("pack.synced", tableName: table) }
                    .accessibilityIdentifier("playRecovery.pack.synced")
            }
            if model.previousCompleteIdentity != nil {
                Text("pack.previousKept", tableName: table).cyText(.caption).foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        Section {
            offlineScope(manifest)
            Text("pack.alwaysOnline", tableName: table).cyText(.caption).foregroundStyle(CYColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("playRecovery.pack.alwaysOnline")
        } header: { Text("pack.offline.title", tableName: table) }
        if manifest.identity != nil {
            assetSection("pack.required", rows: manifest.requiredAssets, manifest: manifest)
            if !manifest.optionalAssets.isEmpty { assetSection("pack.optional", rows: manifest.optionalAssets, manifest: manifest) }
            if !manifest.requiredAssets.isEmpty {
                Section {
                    CYPillButton("pack.downloadRequired", systemImage: "arrow.down.circle", tableName: table) { Task { await model.downloadRequired() } }
                        .listRowBackground(Color.clear)
                        .disabled(!manifest.requiredAssets.contains(where: model.canDownload))
                        .accessibilityIdentifier("playRecovery.pack.downloadRequired")
                    CYPillButton("pack.clear", style: .tertiary, systemImage: "trash", tableName: table) { model.clearDownloads() }
                        .listRowBackground(Color.clear).accessibilityIdentifier("playRecovery.pack.clear")
                }
            }
        }
    }

    @ViewBuilder private func offlineScope(_ manifest: PlayContentManifest) -> some View {
        let key: String = {
            switch model.offlineScope {
            case .onlineOnly: return "pack.offline.onlineOnly"
            case .incomplete: return "pack.offline.incomplete"
            case .notVerified: return "pack.offline.notVerified"
            case .readingOnly: return "pack.offline.readingOnly"
            }
        }()
        Label { Text(LocalizedStringKey(key), tableName: table).fixedSize(horizontal: false, vertical: true) }
            icon: { Image(systemName: model.offlineScope == .readingOnly ? "book.closed" : "wifi") }
            .cyText(.body).accessibilityIdentifier("playRecovery.pack.offlineScope")
    }

    @ViewBuilder private func assetSection(_ title: LocalizedStringKey, rows: [PlayContentManifest.Asset], manifest: PlayContentManifest) -> some View {
        let size = manifest.knownSize(of: rows)
        Section {
            if rows.isEmpty { Text("pack.none", tableName: table).foregroundStyle(CYColor.textSecondary) }
            ForEach(rows) { asset in assetRow(asset) }
        } header: { Text(title, tableName: table) } footer: {
            VStack(alignment: .leading, spacing: 2) {
                if size.bytes > 0 { Text(verbatim: ByteCountFormatter.string(fromByteCount: Int64(size.bytes), countStyle: .file)) }
                if size.unknownCount > 0 { Text("pack.sizeUnknown \(size.unknownCount)", tableName: table) }
            }
        }
    }

    @ViewBuilder private func assetRow(_ asset: PlayContentManifest.Asset) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Text(verbatim: asset.textAlternative ?? asset.mime ?? asset.assetKey).cyText(.body).lineLimit(2)
            HStack(spacing: CYSpacing.sm) {
                if let bytes = asset.bytes { Text(verbatim: ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)) }
                else { Text("pack.asset.sizeUnknown", tableName: table) }
                Text(asset.verified ? "pack.asset.serverHash" : "pack.asset.notVerified", tableName: table)
            }
            .cyText(.caption).foregroundStyle(CYColor.textSecondary)
            switch model.states[asset.assetKey] ?? .notStored {
            case .notStored:
                if asset.url == nil { Text("pack.asset.noLink", tableName: table).cyText(.caption).foregroundStyle(CYColor.textSecondary) }
                else {
                    Button { Task { await model.download(asset) } } label: { Text("pack.asset.download", tableName: table) }
                        .accessibilityIdentifier("playRecovery.pack.download.\(asset.assetKey)")
                }
            case .downloading:
                ProgressView().accessibilityLabel(Text("pack.asset.downloading", tableName: table))
            case .stored(let row):
                CYStatusChip(verbatim: recoveryText(row.serverVerified ? "pack.asset.storedVerified" : "pack.asset.stored"),
                             tone: row.serverVerified ? .success : .neutral, systemImage: "arrow.down.circle.fill")
            case .failed:
                HStack {
                    CYStatusChip(verbatim: recoveryText("pack.asset.failed"), tone: .danger, systemImage: "exclamationmark.circle")
                    Button { Task { await model.download(asset) } } label: { Text("pack.asset.retry", tableName: table) }
                        .accessibilityIdentifier("playRecovery.pack.retry.\(asset.assetKey)")
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

/// Creates the download model when the page opens, bound to the run that was current then.
@MainActor struct PlayOfflinePackHost: View {
    let make: () -> PlayOfflinePackModel?
    @State private var model: PlayOfflinePackModel?
    @State private var attempted = false
    var body: some View {
        Group {
            if let model { PlayOfflinePackView(model: model) }
            else if attempted {
                ContentUnavailableView {
                    Label { Text("pack.unavailable", tableName: table) } icon: { Image(systemName: "arrow.down.circle") }
                }
                .accessibilityIdentifier("playRecovery.pack.unavailable")
            } else { ProgressView { Text("cy.state.loading") } }
        }
        .task { if model == nil { model = make(); attempted = true } }
    }
}

import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// One creator topic the studio screens can scope a read to.
struct CreatorStudioTopic: Identifiable, Hashable {
    let id: Int
    let title: String?
}

extension AppSession {
    /// U08-03 / U08-04 client. Only the reviewed China deployment with the player-write grant has one; every request
    /// still passes the session transport's player-write lease. Other builds return nil and show no entry.
    var creatorStudioService: CreatorStudioService? {
        guard let reviewed = composition.reviewed, reviewed.playerWritesEnabled, reviewed.regional.market == .china,
              let api = reviewed.regional.apiConfiguration else { return nil }
        return CreatorStudioService(configuration: api, transport: runtimeHTTPTransport, token: { [weak self] in self?.token })
    }
}

/// Creator centre rows for the maintenance workbench (U08-03) and the post-game outcome report (U08-04,
/// "复报 · 分析适配入口"). Each row appears only after its route answers; a route the backend does not serve
/// (production today) keeps its row hidden.
@MainActor struct CreatorStudioEntrySection: View {
    let service: CreatorStudioService
    let reader: any CreatorContentReading
    @State private var maintenance: CreatorStudioAvailability = .hidden
    @State private var outcome: CreatorStudioAvailability = .hidden

    var body: some View {
        Group {
            if maintenance == .available || outcome == .available {
                Section {
                    if maintenance == .available {
                        NavigationLink { CreatorMaintenanceWorkbenchView(service: service, loadTopics: loadTopics) } label: {
                            Label {
                                VStack(alignment: .leading) {
                                    Text("creatorStudio.maintenance.entry")
                                    Text("creatorStudio.maintenance.entryMeta").font(.subheadline).foregroundStyle(.secondary)
                                }
                            } icon: { Image(systemName: "wrench.and.screwdriver") }
                        }.accessibilityIdentifier("creatorStudio.maintenance")
                    }
                    if outcome == .available {
                        NavigationLink { CreatorPostGameOutcomeView(service: service, loadTopics: loadTopics) } label: {
                            Label {
                                VStack(alignment: .leading) {
                                    Text("creatorStudio.outcome.entry")
                                    Text("creatorStudio.outcome.entryMeta").font(.subheadline).foregroundStyle(.secondary)
                                }
                            } icon: { Image(systemName: "chart.line.uptrend.xyaxis") }
                        }.accessibilityIdentifier("creatorStudio.outcome")
                    }
                } header: { Text("creatorStudio.section") }
            }
        }
        .task(id: reader.scope) {
            async let workbench = CreatorStudioAvailability.probeMaintenance(service)
            async let report = CreatorStudioAvailability.probeOutcome(service)
            let (m, o) = await (workbench, report)
            guard !Task.isCancelled else { return }
            maintenance = m; outcome = o
        }
    }

    /// The creator's own topics, from the creator content list. The workbench scopes feedback reads to one topic.
    private func loadTopics() async -> [CreatorStudioTopic] {
        guard let page = try? await reader.projects(query: CreatorContentQuery(type: "topic")) else { return [] }
        var seen = Set<Int>()
        return page.rows.compactMap { row in
            guard row.sourceID > 0, seen.insert(row.sourceID).inserted else { return nil }
            return CreatorStudioTopic(id: row.sourceID, title: row.title.isEmpty ? nil : row.title)
        }
    }
}

/// Shared rendering of a studio read failure. A 5xx is "unavailable", never an empty or zero state.
struct CreatorStudioIssueView: View {
    let failure: CreatorStudioFailure?
    let retry: () -> Void
    var body: some View {
        switch failure {
        case .unauthorized?:
            ContentUnavailableView("creatorStudio.issue.signIn", systemImage: "person.crop.circle.badge.exclamationmark")
        case .notFound(let code)? where code == "CREATOR_TOPICS_NOT_FOUND":
            ContentUnavailableView("creatorStudio.issue.noTopics", systemImage: "square.stack.3d.up.slash")
        case .notFound?:
            issue("creatorStudio.issue.notFound", systemImage: "questionmark.folder")
        case .unavailable?:
            issue("creatorStudio.issue.unavailable", systemImage: "exclamationmark.icloud")
        case .rejected(_, _, let message)?:
            issue("creatorStudio.issue.rejected", systemImage: "exclamationmark.triangle", detail: message)
        default:
            issue("creatorStudio.issue.failed", systemImage: "exclamationmark.triangle")
        }
    }

    private func issue(_ title: LocalizedStringKey, systemImage: String, detail: String? = nil) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            if let detail { Text(verbatim: detail) }
        } actions: {
            Button("creatorStudio.retry", action: retry).buttonStyle(.bordered)
        }
    }
}

import SwiftUI

/// CLB-detail-11: 自由探索期次 on 管理 for the owner. Each row this club executes offers 带票分享.
/// The link carries `sourceClubId` and `clubCode` (`club-<clubId>-t<topicId>`). Opening it puts
/// `clubCode` on the later registration as `sourceChannelCode`. The paid registration itself stays off.
@MainActor struct ClubEditionsShareSection: View {
    @Environment(\.locale) private var locale
    let clubID: Int
    let access: any ClubGovernanceAccess
    private enum Phase: Equatable { case loading, failed, ready([Edition]) }
    struct Edition: Equatable, Identifiable {
        let topicID: Int
        let name: String?
        let dateText: String?
        var id: Int { topicID }
    }
    @State private var expanded = false
    @State private var phase: Phase = .loading
    @State private var loadedFor: Int?

    var body: some View {
        Section {
            DisclosureGroup(isExpanded: $expanded) {
                switch phase {
                case .loading:
                    ProgressView { Text("club.editions.loading") }
                        .frame(maxWidth: .infinity)
                case .failed:
                    ContentUnavailableView {
                        Label("club.editions.loadFailed", systemImage: "exclamationmark.triangle")
                    } actions: {
                        Button("action.reload") { Task { await load(force: true) } }
                    }
                case let .ready(rows):
                    if rows.isEmpty {
                        ClubEditionEmptyReasonView(clubID: clubID, reload: { Task { await load(force: true) } })
                    } else {
                        ForEach(rows) { row in editionRow(row) }
                    }
                }
            } label: {
                Text("club.editions.title").cyText(.body)
            }
            .accessibilityIdentifier("club.editions.fold")
        }
        .task(id: expanded) { if expanded { await load(force: false) } }
    }

    private func editionRow(_ row: Edition) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                if let name = row.name {
                    Text(verbatim: name).cyText(.body)
                } else {
                    Text("club.editions.unnamed").cyText(.body)
                }
                (dateText(row) + Text(verbatim: " · ") + Text("club.editions.executing"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if let url = Self.shareURL(topicID: row.topicID, clubID: clubID) {
                ShareLink(item: url) {
                    Text("club.editions.share")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityIdentifier("club.editions.share.\(row.topicID)")
            }
        }
    }

    private func dateText(_ row: Edition) -> Text {
        if let date = row.dateText { return Text(verbatim: LocaleDisplay.civil(date, locale: locale)) }
        return Text("club.editions.dateTBD")
    }

    static func shareURL(topicID: Int, clubID: Int) -> URL? {
        guard topicID > 0, clubID > 0 else { return nil }
        let code = "club-\(clubID)-t\(topicID)"
        guard (1...64).contains(code.unicodeScalars.count) else { return nil }
        // CLB-detail-30 / CLB-r10-detail-03 (MP club/detail js:3509-3545): https universal link first; chein:// fallback.
        if let url = PublicContentShareLink.clubTicket(TopicClubShareLink(topicID: topicID, sourceClubId: clubID, clubCode: code)) {
            return url
        }
        var components = URLComponents()
        components.scheme = CheinDeepLink.scheme
        components.host = "mp"
        components.path = "/" + TopicClubShareLink.page
        components.queryItems = [
            URLQueryItem(name: "id", value: String(topicID)),
            URLQueryItem(name: "sourceClubId", value: String(clubID)),
            URLQueryItem(name: "clubCode", value: code)
        ]
        return components.url
    }

    private func load(force: Bool) async {
        guard force || loadedFor != clubID else { return }
        let captured = clubID
        if case .ready = phase, !force {} else { phase = .loading }
        do {
            let snapshot = try await access.read(.editions, scope: .init(clubID: captured), options: [:])
            guard captured == clubID, !Task.isCancelled else { return }
            let raw = snapshot.value.array ?? snapshot.value["rows"].array ?? []
            let rows = raw.compactMap { item -> Edition? in
                guard let topicID = item["topicId"].int, topicID > 0, item["executingClubId"].int == captured else { return nil }
                let name = item["topicName"].string?.trimmingCharacters(in: .whitespacesAndNewlines)
                let date = item["startDate"].string.map { String($0.prefix(10)) }
                return Edition(topicID: topicID, name: name?.isEmpty == false ? name : nil, dateText: date?.isEmpty == false ? date : nil)
            }
            phase = .ready(rows)
            loadedFor = captured
        } catch {
            guard captured == clubID, !Task.isCancelled else { return }
            phase = .failed
        }
    }
}

import SwiftUI

/// CLB-detail-11 (App half): 自由探索期次 fold on 管理 for the owner (MP `pages/club/detail/index.wxml:484-511`,
/// `index.js:1283-1318, 3517-3545`). Lists `/api/club-compensation/editions` rows this club executes and offers
/// 带票分享: the topic link carries `sourceClubId` and `clubCode = club-<clubId>-t<topicId>`
/// (MP `utils/ticket-source.js buildSharePath`). Registration turns `clubCode` into `sourceChannelCode` on the
/// receiving side (`TicketSourceRegistrationFields`, Core).
@MainActor struct ClubEditionsShareSection: View {
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
                    ProgressView().frame(maxWidth: .infinity)
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
        HStack(alignment: .center, spacing: CYSpacing.md) {
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                if let name = row.name { Text(verbatim: name).cyText(.body) } else { Text("club.editions.unnamed").cyText(.body) }
                (dateText(row) + Text(verbatim: " · ") + Text("club.editions.executing"))
                    .cyText(.meta)
                    .foregroundStyle(CYColor.textSecondary)
            }
            Spacer(minLength: 0)
            if let url = Self.shareURL(topicID: row.topicID, clubID: clubID) {
                ShareLink(item: url, message: Text(verbatim: row.name ?? "")) {
                    Text("club.editions.share")
                }
                .buttonStyle(CYPillButtonStyle(style: .secondary, fullWidth: false, compact: true))
                .accessibilityIdentifier("club.editions.share.\(row.topicID)")
            }
        }
    }

    private func dateText(_ row: Edition) -> Text {
        if let date = row.dateText { return Text(verbatim: date) }
        return Text("club.editions.dateTBD")
    }

    /// MP `buildSharePath('/pages/topic/index/index', { topicId, clubId, clubCode: 'club-' + cid + '-t' + topicId })`,
    /// carried on the in-app link like the other club shares (`ClubShareURL`).
    static func sharePath(topicID: Int, clubID: Int) -> String? {
        guard topicID > 0, clubID > 0 else { return nil }
        let code = "club-\(clubID)-t\(topicID)"
        let encoded = code.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? code
        return "/" + TopicClubShareLink.page + "?id=\(topicID)&sourceClubId=\(clubID)&clubCode=" + encoded
    }
    static func shareURL(topicID: Int, clubID: Int) -> URL? {
        sharePath(topicID: topicID, clubID: clubID).flatMap { URL(string: CheinDeepLink.scheme + "://mp" + $0) }
    }

    /// MP `loadShareEditions`: keep only rows whose `executingClubId` is this club.
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
            phase = .ready(rows); loadedFor = captured
        } catch {
            guard captured == clubID, !Task.isCancelled else { return }
            phase = .failed
        }
    }
}

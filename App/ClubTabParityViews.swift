import SwiftUI

/// Mini-program 俱乐部 tab (`pages/talent/list`) details layered on `ClubHomeView`.
struct ClubTabTagLine: View {
    let club: ClubRecord
    let section: ClubTabPresentation.Section
    /// Core page model topic count for this row; nil when no page model, em dash when the server omitted it.
    var topicCount: ClubTabPageModel.Count? = nil
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        let tags = ClubTabPresentation.tags(club, in: section)
        let level = ClubTabPresentation.levelKey(club.level)
        if !tags.labels.isEmpty || tags.freeToJoin || topicCount != nil || level.key != nil || level.fallback != nil {
            chipLayout(tags: tags, level: level)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("clubTab.tags.\(club.id)")
        }
    }
    private func chipLayout(tags: (labels: [String], freeToJoin: Bool), level: (key: String?, fallback: String?)) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 8))
        return layout {
            if let key = level.key { Label(LocalizedStringKey(key), systemImage: "star") }
            else if let fallback = level.fallback { Label(fallback, systemImage: "star") }
            ForEach(tags.labels.prefix(3), id: \.self) { label in
                Text(verbatim: label)
            }
            if tags.freeToJoin { Label("club.tab.freeToJoin", systemImage: "person.badge.plus") }
            if let topicCount {
                let label: LocalizedStringKey = "club.tab.topicCount \(topicCount.text)"
                Label(label, systemImage: "text.bubble")
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
}

/// polish-d-r1: the creation quota in plain words; above the limit gets a warning tag instead of reading as `5 / 2`.
struct ClubLeaderQuotaLine: View {
    let leader: ClubTabPageModel.LeaderStatus
    @Environment(\.locale) private var locale
    var body: some View {
        switch leader.quota {
        case .over(let owned, let limit):
            VStack(alignment: .leading, spacing: 4) {
                Label(clubR1("quota.overTag", locale), systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(CYColor.warningText)
                line(String(format: clubR1("quota.over", locale), owned, limit))
            }
        case .full(let owned):
            line(String(format: clubR1("quota.full", locale), owned))
        case .within(let owned, let remaining):
            line(String(format: clubR1("quota.within", locale), owned, remaining))
        case .unknown:
            Text("club.tab.leaderQuota \(leader.ownedCount.text) \(leader.maxOwned.text)")
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }
    private func line(_ text: String) -> some View {
        Text(verbatim: text)
            .font(.subheadline).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct ClubTabEmptyState: View {
    let merchant: Bool
    var body: some View {
        // Mini-program cy-empty shows only the title here; the create action sits in the row above.
        let keys = ClubTabPresentation.emptyKeys(merchant: merchant)
        ContentUnavailableView {
            Label {
                Text(LocalizedStringKey(keys.title)).accessibilityIdentifier("clubTab.empty")
            } icon: {
                Image(systemName: "person.3")
            }
        }
    }
}

/// One club-tab load: the typed home plus the optional Core page model (nil = capability off or unusable body).
struct ClubTabLoaded {
    let home: ClubHome
    let page: ClubTabPageModel?
}

extension ClubReading {
    /// The raw home body, or nil when this reader keeps none or the read failed (never an empty list).
    func clubHomeBodyIfAvailable() async -> Data? { (try? await clubHomeBody()) ?? nil }
}

private struct ClubEditDetailBodyKey: EnvironmentKey {
    static let defaultValue: (@MainActor (Int) async throws -> Data?)? = nil
}
extension EnvironmentValues {
    /// Raw club detail body read. Unset means the capability is off and the edit facts stay hidden.
    var clubEditDetailBody: (@MainActor (Int) async throws -> Data?)? {
        get { self[ClubEditDetailBodyKey.self] }
        set { self[ClubEditDetailBodyKey.self] = newValue }
    }
}

/// pages/club/edit facts over `ClubEditPage.make`: members, reserved quota and (owner with governance) blockers.
/// Unknown values are an em dash, never 0. No read port in the environment means nothing is drawn.
struct ClubEditFactsSection: View {
    let clubID: Int
    let governanceAvailable: Bool
    @Environment(\.clubEditDetailBody) private var readBody
    @State private var page: ClubEditPage?
    var body: some View {
        if let readBody {
            Section {
                switch page?.state {
                case nil, .loading?:
                    // mp-states-b r3 (MP scene-club-edit wxml:3): the facts read says 正在读取俱乐部资料 in words.
                    ProgressView { Text("club.ops.edit.loading") }
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("club.ops.facts.loading")
                case .error?:
                    // mp-states-b r3 (MP scene-club-edit wxml:6): 编辑资料没能打开 with 重新加载, never a bare line.
                    Label {
                        Text("club.ops.edit.loadFailed")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle").foregroundStyle(CYColor.warningText)
                    }
                    .accessibilityIdentifier("club.ops.facts.error")
                    Button("club.ops.edit.reload") { Task { await load(readBody) } }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("club.ops.facts.reload")
                case .empty?, .unknown?, .ready?:
                    if let page {
                        LabeledContent("club.ops.facts.members") { Text(verbatim: page.memberCountText) }
                            .accessibilityIdentifier("club.ops.facts.members")
                        LabeledContent("club.ops.facts.quota") { Text(verbatim: page.reservedQuotaText) }
                            .accessibilityIdentifier("club.ops.facts.quota")
                        if page.showsDissolve {
                            LabeledContent("club.ops.facts.blockers") { Text(verbatim: page.blockerCountText) }
                                .accessibilityIdentifier("club.ops.facts.blockers")
                        }
                    }
                }
            } header: { Text("club.ops.facts") }
            .task(id: clubID) { await load(readBody) }
        }
    }
    private func load(_ read: @MainActor (Int) async throws -> Data?) async {
        func make(_ value: ClubEditPage.Read) -> ClubEditPage {
            ClubEditPage.make(read: value, surface: .manage, clubID: clubID, governanceAvailable: governanceAvailable)
        }
        page = make(.loading)
        do {
            let body = try await read(clubID)
            guard !Task.isCancelled else { return }
            page = make(body.map { ClubEditPage.Read.detail($0, blockers: nil) } ?? .unknown)
        } catch {
            guard !Task.isCancelled else { return }
            page = make(.error)
        }
    }
}

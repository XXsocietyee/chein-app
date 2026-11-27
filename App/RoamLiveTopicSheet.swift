import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// MP 主题半屏 (原型 f-topic 自由探索 / f-city 城市定向, `pages/roam/index.wxml:618-645`, index.js `openTopicView`).
/// A shop that carries a `topicId` reads `/api/topic/info-to-user`; MP order: cover strip → tag · eyebrow → title →
/// description → 场次 / 走法 / 距你 → 查看详情 (`pages/topic/index/index`). When the read fails or has no name the MP
/// falls back to the plain shop card, so this sheet closes and the shop row stays in the live list.
struct RoamLiveTopicShop: Identifiable, Equatable {
    let shop: RoamRouteNode
    let topicID: Int
    var id: Int { shop.id }
    init?(shop: RoamRouteNode) {
        guard let topic = shop.topicId, topic > 0 else { return nil }
        self.shop = shop
        topicID = topic
    }
    /// MP: `productType == 2` → 自由探索 (不限顺序); anything else → 城市定向 (按顺序).
    var isFree: Bool { shop.productType == 2 }
    /// MP `poi.distM`; nil when unknown (shown as "—").
    var distanceMeters: Int? {
        guard let value = shop.distance, value.isFinite, value > 0 else { return nil }
        return Int(value.rounded())
    }
}

struct RoamLiveTopicInfo: Equatable {
    let title: String
    let description: String
    let cover: String?
    let sessionCount: Int
    /// MP `res.data.topic || res.data`; `activityList` sits next to `topic`.
    init?(data: PlayWireValue?) {
        guard let data else { return nil }
        let topic = data["topic"].object == nil ? data : data["topic"]
        let name = (topic["name"].text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        title = name
        description = topic["description"].text ?? topic["intro"].text ?? ""
        let rawCover = topic["coverUrl"].text ?? topic["cover"].text
        cover = rawCover?.isEmpty == false ? rawCover : nil
        sessionCount = data["activityList"].array?.count ?? 0
    }
}

@MainActor struct RoamLiveTopicSheet: View {
    let target: RoamLiveTopicShop
    let service: PlayRoamGapService?
    var topicDestination: (@MainActor (Int) -> AnyView)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var info: RoamLiveTopicInfo?

    var body: some View {
        NavigationStack {
            Group {
                if let info {
                    content(info)
                } else {
                    ProgressView {
                        Text("roam.live.topic.loading").cyText(.meta)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("roam.live.topic.loading")
                }
            }
            .navigationTitle(Text("roam.live.topic.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.close") { dismiss() }
                        .accessibilityIdentifier("roam.live.topic.close")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .task(id: target.topicID) { await load() }
    }

    private func load() async {
        guard let service else { dismiss(); return }
        let reply = await service.fetchTopicInfo(topicID: target.topicID)
        guard !Task.isCancelled else { return }
        if let value = RoamLiveTopicInfo(data: reply.data) {
            info = value
        } else {
            dismiss()
        }
    }

    private func content(_ info: RoamLiveTopicInfo) -> some View {
        List {
            if let cover = info.cover {
                Section {
                    RoamEntryCover(source: cover)
                        .frame(height: 160)
                        .listRowInsets(EdgeInsets())
                }
            }
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(target.isFree ? "roam.live.topic.tagFree" : "roam.live.topic.tagCity")
                            .cyText(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.tint.opacity(0.12), in: .capsule)
                        eyebrow.cyText(.meta).foregroundStyle(.secondary)
                    }
                    Text(verbatim: info.title).cyText(.sheetTitle)
                        .accessibilityIdentifier("roam.live.topic.name")
                    if !info.description.isEmpty {
                        Text(verbatim: info.description).cyText(.body).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            Section {
                HStack(alignment: .top) {
                    stat(value: Text(verbatim: String(info.sessionCount)), label: "roam.live.topic.sessions")
                    stat(value: Text(walkKey), label: "roam.live.topic.walk")
                    stat(value: distanceText, label: "roam.live.topic.distance")
                }
                .accessibilityElement(children: .combine)
            }
            if let topicDestination {
                Section {
                    NavigationLink { topicDestination(target.topicID) } label: {
                        Text("roam.live.topic.open")
                    }
                    .accessibilityIdentifier("roam.live.topic.open")
                }
            }
        }
    }

    private var walkKey: LocalizedStringKey {
        target.isFree ? "roam.live.topic.anyOrder" : "roam.live.topic.inOrder"
    }

    private var distanceText: Text {
        if let meters = target.distanceMeters { return Text("roam.live.topic.meters \(meters)") }
        return Text(verbatim: "—")
    }

    /// MP eyebrow: `[distM + 'm', 不限顺序 | 按顺序].join(' · ')`.
    private var eyebrow: Text {
        if let meters = target.distanceMeters {
            return Text("roam.live.topic.meters \(meters)") + Text(verbatim: " · ") + Text(walkKey)
        }
        return Text(walkKey)
    }

    private func stat(value: Text, label: LocalizedStringKey) -> some View {
        VStack(spacing: 2) {
            value.cyText(.cardTitle).monospacedDigit()
            Text(label).cyText(.meta).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

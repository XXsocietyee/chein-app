import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// A merchant chosen on `pages/coop/invite` (memberId + display name).
struct CoopInviteStationMerchant: Identifiable, Equatable {
    let id: Int
    let name: String
}

/// MP `pages/coop/invite` 核销据点 card (wxml:114-131): after ③ 邀请对象, one station picker per chosen merchant.
/// Every merchant invite on a station topic names one confirmed station; the merchant's accept freezes it.
@MainActor struct CoopInviteSupplyStationSection: View {
    let reader: any CoopFlowReading
    let topicID: Int?
    let merchants: [CoopInviteStationMerchant]
    @Binding var required: Bool
    @Binding var lists: [Int: [CoopInviteStationOption]]
    @Binding var picks: [Int: CoopInviteStationOption]
    @Environment(\.locale) private var locale
    @State private var states: [Int: Load] = [:]
    private enum Load: Equatable { case loading, failed, ready }
    private struct Key: Hashable { let topic: Int; let merchants: [Int]; let signedIn: Bool }
    private var key: Key {
        Key(topic: topicID ?? 0, merchants: merchants.map(\.id).sorted(), signedIn: reader.session != nil)
    }
    private var visible: Bool {
        guard let topicID, topicID > 0, !merchants.isEmpty, reader.session != nil else { return false }
        return required || states.values.contains(.loading) || states.values.contains(.failed)
    }
    var body: some View {
        Group {
            if visible {
                Section {
                    Text(verbatim: locale.pick("每条邀约明确选择一个据点；商家接受后冻结，订单间不能重复使用。",
                                               "Each invitation names one station. It is frozen once the merchant accepts and cannot be reused across orders."))
                        .cyText(.meta).foregroundStyle(CYColor.textTertiary).fixedSize(horizontal: false, vertical: true)
                    ForEach(merchants) { merchant in
                        row(merchant)
                    }
                } header: {
                    Text(verbatim: locale.pick("核销据点", "Redemption station"))
                }
                .accessibilityIdentifier("cooperation.invite.supplyStations")
            }
        }
        .task(id: key) { await loadAll() }
    }
    @ViewBuilder private func row(_ merchant: CoopInviteStationMerchant) -> some View {
        switch states[merchant.id] ?? .loading {
        case .loading:
            CYSkeleton()
        case .failed:
            stationNote(merchant.name, locale.pick("据点读取失败", "Stations did not load"))
            retryButton(merchant.id)
        case .ready:
            let options = lists[merchant.id] ?? []
            if options.isEmpty {
                stationNote(merchant.name, locale.pick("暂无已确定据点", "No confirmed station yet"))
                retryButton(merchant.id)
            } else {
                Picker(selection: pickBinding(merchant.id)) {
                    Text(verbatim: locale.pick("请选择一个据点", "Choose a station")).tag(Optional<Int>.none)
                    ForEach(options) { option in
                        Text(verbatim: option.name).tag(Optional(option.id))
                    }
                } label: {
                    Text(verbatim: merchant.name)
                }
                .accessibilityLabel(Text(verbatim: locale.pick("为\(merchant.name)选择核销据点", "Redemption station for \(merchant.name)")))
                .accessibilityIdentifier("cooperation.invite.supplyStation.\(merchant.id)")
            }
        }
    }
    private func stationNote(_ name: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xxs) {
            Text(verbatim: name).cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary)
            Text(verbatim: detail).cyText(.meta).foregroundStyle(CYColor.textSecondary)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }
    private func retryButton(_ merchantID: Int) -> some View {
        Button {
            Task { await load(merchantID) }
        } label: {
            Label(locale.pick("刷新据点", "Refresh stations"), systemImage: "arrow.clockwise")
                .frame(minHeight: CYSpacing.minTouchTarget)
        }
    }
    private func pickBinding(_ merchantID: Int) -> Binding<Int?> {
        Binding(
            get: { picks[merchantID]?.id },
            set: { value in
                let option = (lists[merchantID] ?? []).first { $0.id == value }
                picks[merchantID] = option
            }
        )
    }
    private func loadAll() async {
        let ids = Set(merchants.map(\.id))
        states = states.filter { ids.contains($0.key) }
        lists = lists.filter { ids.contains($0.key) }
        picks = picks.filter { ids.contains($0.key) }
        required = false
        guard let topicID, topicID > 0, reader.session != nil else {
            states = [:]; lists = [:]; picks = [:]; required = false; return
        }
        for merchant in merchants { await load(merchant.id, topicID: topicID) }
    }
    private func load(_ merchantID: Int) async {
        guard let topicID, topicID > 0 else { return }
        await load(merchantID, topicID: topicID)
    }
    private func load(_ merchantID: Int, topicID: Int) async {
        states[merchantID] = .loading
        let reply: CoopInviteSupplyStations.Reply?
        do {
            let page = try await reader.read(.supplyStations(topicID: topicID, merchantMemberID: merchantID))
            reply = CoopInviteSupplyStations.parse(page)
        } catch { reply = nil }
        guard let reply else { states[merchantID] = .failed; return }
        lists[merchantID] = reply.stations
        // MP js:612-616: a kept choice survives a re-read while it is still listed.
        if let kept = picks[merchantID], !reply.stations.contains(kept) { picks[merchantID] = nil }
        if reply.required { required = true }
        states[merchantID] = .ready
    }
}

/// MP invite sheet `.iv-terms` station line: {merchant} · 接受后冻结 → 核销据点：{station}.
struct CoopInviteFrozenStationRow: View {
    let merchant: String
    let station: String
    @Environment(\.locale) private var locale
    var body: some View {
        let name = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        VStack(alignment: .leading, spacing: CYSpacing.xxs) {
            Text(verbatim: locale.pick("\(name.isEmpty ? "—" : name) · 接受后冻结", "\(name.isEmpty ? "—" : name) · frozen on accept"))
                .cyText(.meta).foregroundStyle(CYColor.textTertiary)
            Text(verbatim: locale.pick("核销据点：\(station)", "Redemption station: \(station)"))
                .cyText(.body).foregroundStyle(CYColor.textPrimary)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("cooperation.invite.frozenStation")
    }
}

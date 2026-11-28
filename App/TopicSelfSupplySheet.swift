import SwiftUI

/// R11-PC-B-3: one unclaimed recruit node in the host view (MP project-host/index.wxml:383 `hostRecruit.openNodes`).
struct TopicSelfSupplyNode: Identifiable, Hashable {
    let nodeID: Int
    let chapterID: Int?
    let nodeName: String
    var id: Int { nodeID }

    static func openNodes(_ recruit: MerchantContentValue) -> [TopicSelfSupplyNode] {
        (recruit["openNodes"].array ?? []).compactMap { row in
            guard let id = row["nodeId"].integer, id > 0 else { return nil }
            let chapter = row["chapterId"].integer.flatMap { $0 > 0 ? $0 : nil }
            return TopicSelfSupplyNode(nodeID: id, chapterID: chapter, nodeName: row["nodeName"].text ?? "")
        }
    }
}

/// R11-PC-B-3: free-explore author 自己承接 sheet (MP merchantinfo.js:3232-3274; utils/fe-author-sale.js:59-77, 117-128).
/// A plain Form: 权益名称, 核销说明, 可接待人次, 有效期至. Submit posts the self-supply once and closes on success.
@MainActor struct TopicSelfSupplySheet: View {
    let topicID: Int
    let node: TopicSelfSupplyNode
    let chapterID: Int
    let makeService: @MainActor () -> PlayerContentRound4Service?
    var onDone: () -> Void = {}
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var name = ""
    @State private var redeemRule = ""
    @State private var capacity = ""
    @State private var validEnd = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    @State private var submitting = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Form {
                if !node.nodeName.isEmpty {
                    Section { Text(verbatim: node.nodeName).font(.headline) }
                }
                Section {
                    TextField("topicSelfSupply.name", text: $name)
                    TextField("topicSelfSupply.redeemRule", text: $redeemRule, axis: .vertical)
                    TextField("topicSelfSupply.capacity", text: $capacity).keyboardType(.numberPad)
                    DatePicker("topicSelfSupply.validEnd", selection: $validEnd, in: Date()..., displayedComponents: .date)
                } footer: {
                    if let errorText { Text(verbatim: errorText).foregroundStyle(CYColor.dangerText) }
                }
            }
            .appNavigationTitle("topicSelfSupply.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .disabled(submitting)
        }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("topicSelfSupply.cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            if submitting { ProgressView() } else {
                Button("topicSelfSupply.submit") { submit() }
                    .accessibilityIdentifier("topicSelfSupply.submit")
            }
        }
    }

    private static func dayText(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private func submit() {
        switch TopicSelfSupplyPerk.validate(name: name, redeemRule: redeemRule, capacity: capacity, validEnd: Self.dayText(validEnd)) {
        case .failure(let error):
            switch error.problem {
            case .name: errorText = appLocalized("topicSelfSupply.error.name", locale: locale)
            case .capacity: errorText = appLocalized("topicSelfSupply.error.capacity", locale: locale)
            case .validEnd: errorText = appLocalized("topicSelfSupply.error.validEnd", locale: locale)
            }
        case .success(let perk):
            guard let service = makeService() else { errorText = appLocalized("topicSelfSupply.error.failed", locale: locale); return }
            submitting = true; errorText = nil
            Task {
                let reply = await service.selfSupply(topicID: topicID, chapterID: chapterID, perk: perk)
                submitting = false
                if case .ok = reply { onDone(); dismiss() }
                else { errorText = reply.message.flatMap { $0.isEmpty ? nil : $0 } ?? appLocalized("topicSelfSupply.error.failed", locale: locale) }
            }
        }
    }
}

private struct TopicSelfSupplyServiceKey: EnvironmentKey {
    static let defaultValue: (@MainActor () -> PlayerContentRound4Service?)? = nil
}
extension EnvironmentValues {
    /// R11-PC-B-3: the host view's self-supply write. Nil hides the free-explore 自己承接 sheet path.
    var topicSelfSupplyService: (@MainActor () -> PlayerContentRound4Service?)? {
        get { self[TopicSelfSupplyServiceKey.self] }
        set { self[TopicSelfSupplyServiceKey.self] = newValue }
    }
}

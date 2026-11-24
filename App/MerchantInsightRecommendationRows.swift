import SwiftUI

struct MerchantInsightRecommendationRows: View {
    let rows: [MerchantMarketingValue]
    let kind: MerchantInsightRecommendationRoute.Kind
    let origin: MerchantInsightOrigin?
    let open: (MerchantInsightRecommendationRoute) -> Void
    /// MC7-11-4 (ai-insight/index.wxml:280-299): a recommended topic first opens a medium sheet (先不用 / 去申请承接).
    @State private var pendingTopic: PendingTopic?
    private struct PendingTopic: Identifiable {
        let route: MerchantInsightRecommendationRoute
        let item: MerchantInsightRecommendation
        var id: Int { route.targetID }
    }
    var body: some View {
        ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
            let item = MerchantInsightRecommendation(row: row, kind: kind, siblings: rows)
            VStack(alignment: .leading, spacing: 8) {
                Text(verbatim: item.name ?? "—").font(.headline)
                if let host = item.hostName, !host.isEmpty { LabeledContent("merchant.insightNavigation.host", value: host) }
                if let category = item.category, !category.isEmpty { Text(verbatim: category).font(.subheadline) }
                if let reason = item.reason, !reason.isEmpty { Text(verbatim: reason).font(.subheadline) }
                if let origin, let route = item.route(origin: origin) {
                    Button(LocalizedStringKey(kind == .topic ? "merchant.insightNavigation.topic" : "merchant.insightNavigation.partner")) {
                        if kind == .topic { pendingTopic = PendingTopic(route: route, item: item) } else { open(route) }
                    }
                    .frame(minHeight: CYSpacing.minTouchTarget)
                    .accessibilityIdentifier("merchant.insightNavigation." + kind.rawValue + "." + String(route.targetID))
                }
            }
        }
        .sheet(item: $pendingTopic) { pending in
            NavigationStack {
                List {
                    Section {
                        Text(verbatim: pending.item.reason.flatMap { $0.isEmpty ? nil : $0 }
                             ?? appLocalized("merchant.insightTopicSheet.defaultReason", locale: .current))
                        if let host = pending.item.hostName, !host.isEmpty {
                            LabeledContent("merchant.insightNavigation.host", value: host)
                        }
                    }
                    Section {
                        Button {
                            let route = pending.route
                            pendingTopic = nil
                            open(route)
                        } label: {
                            Text("merchant.insightTopicSheet.apply").frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
                        }
                        .buttonStyle(.borderedProminent)
                        .listRowBackground(Color.clear)
                        .accessibilityIdentifier("merchant.insightTopicSheet.apply")
                    }
                }
                .navigationTitle(Text(verbatim: pending.item.name ?? "—"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("merchant.insightTopicSheet.notNow") { pendingTopic = nil }
                            .accessibilityIdentifier("merchant.insightTopicSheet.notNow")
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}

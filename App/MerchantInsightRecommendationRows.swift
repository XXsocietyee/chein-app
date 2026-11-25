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
                // MP ai-insight/index.wxml:173 (topic `coverUrl`, only when present) and :205-206
                // (partner `logo`, else the name initial). Remote images are https-only.
                if kind == .topic, let cover = Self.httpsURL(row["coverUrl"].text) {
                    AsyncImage(url: cover) { phase in
                        if case .success(let image) = phase { image.resizable().scaledToFill() }
                        else { Rectangle().fill(CYColor.borderSubtle) }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityHidden(true)
                }
                HStack(spacing: CYSpacing.sm) {
                    if kind == .partner {
                        CYAvatarView(url: Self.httpsURL(row["logo"].text), name: item.name ?? "", size: .md)
                            .accessibilityHidden(true)
                    }
                    Text(verbatim: item.name ?? "—").font(.headline)
                }
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

    private static func httpsURL(_ raw: String?) -> URL? {
        guard let raw, let url = URL(string: raw), url.scheme?.lowercased() == "https" else { return nil }
        return url
    }
}

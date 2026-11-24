import SwiftUI

/// club/topic-detail 核销 card: three counters. Hosts embed it only when
/// `ClubTopicDetailPort.showsVerify` is true; nothing here reads or writes.
@MainActor struct ClubTopicVerifySummarySection: View {
    let metrics: [ClubTopicDetailPort.Metric]
    var body: some View {
        Section {
            // Mini-program 核销 card: three tiles, big number over its label.
            HStack(spacing: CYSpacing.sm) {
                ForEach(metrics, id: \.key) { metric in
                    VStack(alignment: .leading, spacing: CYSpacing.sm) {
                        Text(verbatim: metric.value.isEmpty ? "—" : metric.value)
                            .cyText(.dataXL).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
                        Text(LocalizedStringKey("club.topic.verify." + metric.key))
                            .cyText(.label).foregroundStyle(.secondary).lineLimit(2)  // CLB-topic-detail-14
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(CYSpacing.md)
                    .background(RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous).fill(CYColor.bgRaised))
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("club.topic.verify." + metric.key)
                }
            }
            .listRowInsets(EdgeInsets(top: CYSpacing.sm, leading: CYSpacing.sm, bottom: CYSpacing.sm, trailing: CYSpacing.sm))
            .listRowBackground(Color.clear)
        } header: {
            // CLB-topic-detail-14 (MP wxss:118-126): a sentence-case section title, not the small uppercase list header.
            Text("club.topic.verify.title").cyText(.sectionTitle).foregroundStyle(CYColor.textPrimary).textCase(nil)
                .accessibilityAddTraits(.isHeader)
        }
    }
}

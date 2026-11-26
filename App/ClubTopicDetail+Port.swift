import SwiftUI

/// club/topic-detail 核销 card: three counters. Hosts embed it only when
/// `ClubTopicDetailPort.showsVerify` is true; nothing here reads or writes.
@MainActor struct ClubTopicVerifySummarySection: View {
    let metrics: [ClubTopicDetailPort.Metric]
    var body: some View {
        Section {
            // Mini-program 核销 card: three counters in one row, big number over its label (Fitness-summary style).
            HStack(alignment: .top, spacing: 12) {
                ForEach(metrics, id: \.key) { metric in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: metric.value.isEmpty ? "—" : metric.value)
                            .font(.title2.bold()).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
                        Text(LocalizedStringKey("club.topic.verify." + metric.key))
                            .font(.footnote).foregroundStyle(.secondary).lineLimit(2)  // CLB-topic-detail-14
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("club.topic.verify." + metric.key)
                }
            }
            .padding(.vertical, 4)
        } header: {
            // CLB-topic-detail-14 (MP wxss:118-126): a sentence-case section title, not the small uppercase list header.
            Text("club.topic.verify.title").textCase(nil)
                .accessibilityAddTraits(.isHeader)
        }
    }
}

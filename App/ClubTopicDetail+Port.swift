import SwiftUI

/// club/topic-detail 核销 card: three counters. Hosts embed it only when
/// `ClubTopicDetailPort.showsVerify` is true; nothing here reads or writes.
@MainActor struct ClubTopicVerifySummarySection: View {
    let metrics: [ClubTopicDetailPort.Metric]
    /// CLB-topic-detail-05 (MP topic-detail wxml:96-100 `goLedger`): 台账 in the 核销 header opens the topic's 报名名册.
    var ledger: AnyView? = nil
    var body: some View {
        Section {
            // Mini-program 核销 card: three counters. CLB-r10-nat-topic-detail-01: three system `LabeledContent` rows
            // (label leading, monospaced value trailing); no tile chrome and no shrink-to-fit.
            rows
        } header: {
            HStack {
                Text("club.topic.verify.title").textCase(nil)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if let ledger {
                    NavigationLink { ledger } label: { Text("club.topic.verify.ledger").textCase(nil) }
                        .accessibilityIdentifier("club.topic.verify.ledger")
                }
            }
        }
    }

    private var rows: some View {
        ForEach(metrics, id: \.key) { metric in
            LabeledContent {
                Text(verbatim: metric.value.isEmpty ? "—" : metric.value).monospacedDigit()
            } label: {
                Text(LocalizedStringKey("club.topic.verify." + metric.key))  // CLB-topic-detail-14
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("club.topic.verify." + metric.key)
        }
    }
}

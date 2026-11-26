import SwiftUI

/// club/topic-detail 核销 card: three counters. Hosts embed it only when
/// `ClubTopicDetailPort.showsVerify` is true; nothing here reads or writes.
@MainActor struct ClubTopicVerifySummarySection: View {
    let metrics: [ClubTopicDetailPort.Metric]
    /// CLB-topic-detail-05 (MP topic-detail wxml:96-100 `goLedger`): 台账 in the 核销 header opens the topic's 报名名册.
    var ledger: AnyView? = nil
    var body: some View {
        Section {
            // Mini-program 核销 card: three counters, number over label. CLB-r9-native-01: no shrink-to-fit; at large
            // Dynamic Type sizes the counters stack instead (system text styles, no card chrome).
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top) { tiles }
                VStack(alignment: .leading) { tiles }
            }
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

    @ViewBuilder private var tiles: some View {
        ForEach(metrics, id: \.key) { metric in
            VStack(alignment: .leading) {
                Text(verbatim: metric.value.isEmpty ? "—" : metric.value)
                    .font(.title2.weight(.semibold)).monospacedDigit()
                Text(LocalizedStringKey("club.topic.verify." + metric.key))
                    .font(.footnote).foregroundStyle(.secondary)  // CLB-topic-detail-14
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("club.topic.verify." + metric.key)
        }
    }
}

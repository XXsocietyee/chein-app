import SwiftUI

/// club/topic-detail 核销 card: three counters. Hosts embed it only when
/// `ClubTopicDetailPort.showsVerify` is true; nothing here reads or writes.
@MainActor struct ClubTopicVerifySummarySection: View {
    let metrics: [ClubTopicDetailPort.Metric]
    var body: some View {
        Section {
            // Mini-program 核销 card: three counters, number over label. CLB-r9-native-01: no shrink-to-fit; at large
            // Dynamic Type sizes the counters stack instead (system text styles, no card chrome).
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top) { tiles }
                VStack(alignment: .leading) { tiles }
            }
        } header: {
            Text("club.topic.verify.title")
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

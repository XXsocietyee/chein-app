import SwiftUI

/// club/topic-detail 核销 card: three counters. Hosts embed it only when
/// `ClubTopicDetailPort.showsVerify` is true; nothing here reads or writes.
@MainActor struct ClubTopicVerifySummarySection: View {
    let metrics: [ClubTopicDetailPort.Metric]
    var body: some View {
        Section("club.topic.verify.title") {
            ForEach(metrics, id: \.key) { metric in
                LabeledContent(LocalizedStringKey("club.topic.verify." + metric.key)) {
                    Text(verbatim: metric.value).monospacedDigit()
                }
                .accessibilityIdentifier("club.topic.verify." + metric.key)
            }
        }
    }
}

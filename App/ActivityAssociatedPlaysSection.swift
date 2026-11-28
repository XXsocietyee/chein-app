import SwiftUI

/// Associated-play rows. A positive public template id plus a destination opens
/// the public template detail. Without either, the row stays a label.
struct ActivityAssociatedPlaysSection: View {
    let plays: [ActivityAssociatedPlay]
    var templateDestination: ((Int) -> AnyView)? = nil
    var body: some View {
        if !plays.isEmpty {
            Section("activityAssociated.title") {
                // Preserve returned order/repetitions. The public id never merges rows.
                ForEach(Array(plays.enumerated()), id: \.offset) { index, play in
                    row(index: index, play: play)
                }
            }.accessibilityIdentifier("activityAssociated.section")
        }
    }
    @ViewBuilder private func row(index: Int, play: ActivityAssociatedPlay) -> some View {
        if let id = play.publicTemplateID, let templateDestination {
            NavigationLink { templateDestination(id) } label: {
                ActivityAssociatedPlayRow(play: play).questifyCardListRow()
            }
            .accessibilityIdentifier("activityAssociated.row.\(index)")
        } else {
            ActivityAssociatedPlayRow(play: play)
                .questifyCardListRow()
                .accessibilityIdentifier("activityAssociated.row.\(index)")
        }
    }
}

struct ActivityAssociatedPlayRow: View {
    let play: ActivityAssociatedPlay
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title = play.title { Text(verbatim: title).font(.headline) }
            else { Text("activityAssociated.untitled").font(.headline) }
            LabeledContent("activityAssociated.players") {
                if let players = play.players { Text(verbatim: players) }
                else { Text("activityAssociated.playersUnknown") }
            }
            LabeledContent("activityAssociated.durationMinutes") {
                if let duration = play.durationMinutes { Text(duration, format: .number) }
                else { Text("activityAssociated.durationUnknown") }
            }
        }.fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
            .questifyCardSurface()
    }
}

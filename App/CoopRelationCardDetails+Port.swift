import SwiftUI

/// Port-2: merchant venue facts that Core already projects (relation/index.wxml cy-merchant-card):
/// business hours, free/paid + capacity tags, suitable activity types.
struct CoopRelationCardDetails: View {
    let row: CoopRelationDiscoveryRow
    private func title(_ tag: CoopRelationVenueTag) -> Text {
        switch tag {
        case .freeVenue: return Text("cooprelation.venue.free")
        case .paidVenue: return Text("cooprelation.venue.paid")
        case .capacity(let value): return Text("cooprelation.venue.capacity \(value)")
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let hours = row.hours {
                Label { Text(verbatim: hours) } icon: { Image(systemName: "clock") }
                    .font(.footnote).accessibilityIdentifier("cooprelation.hours")
            }
            if !row.venueTags.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Array(row.venueTags.enumerated()), id: \.offset) { item in
                        title(item.element).cyText(.meta)
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                    }
                }.accessibilityIdentifier("cooprelation.venueTags")
            }
            if let suit = row.suitText {
                Label { Text(verbatim: suit) } icon: { Image(systemName: "figure.2") }
                    .font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("cooprelation.suit")
            }
        }
    }
}

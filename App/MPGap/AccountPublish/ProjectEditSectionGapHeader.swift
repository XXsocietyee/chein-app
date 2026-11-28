import SwiftUI

/// MP `publish/fabu/step3.wxml` `pd-sec-hd`: a section title with the red `* 还有 N 项未填` on the trailing side
/// (ticketMissing.dates / .tickets). With nothing missing the trailing slot shows `trailing` (for 票务, the price summary).
struct ProjectEditSectionGapHeader<Trailing: View>: View {
    let title: LocalizedStringKey
    let missing: Int
    let identifier: String
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: CYSpacing.sm) {
                Text(title)
                Spacer(minLength: CYSpacing.sm)
                trailingContent
            }
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text(title)
                trailingContent
            }
        }
    }

    @ViewBuilder private var trailingContent: some View {
        if missing > 0 {
            Text("fixr9.ap.tickets.missing \(missing)")
                .foregroundStyle(CYColor.dangerText)
                .accessibilityIdentifier(identifier)
        } else {
            trailing()
        }
    }
}

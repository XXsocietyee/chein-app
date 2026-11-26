import SwiftUI

/// Presentation-only normalization. Keep source strings and their timezone/currency
/// semantics intact; blank optional metadata must not create empty visual rows.
enum ActivityPresentation {
    static func nonempty(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else { return nil }
        return value
    }
    static func place(_ summary: ActivitySummary) -> String? {
        nonempty(summary.addressName) ?? nonempty(summary.address)
    }
}

/// Same row rules as home: cover thumbnail, title, one date · place line, starting price. Missing values are left out.
/// A plain List row (the caller's link draws the system chevron).
struct ActivityListCard: View {
    let item: ActivitySummary
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @Environment(\.timeZone) private var timeZone

    private var copy: CoreLoopCopy { CoreLoopCopy(locale: locale) }
    private var title: Text { ActivityPresentation.nonempty(item.name).map { Text(verbatim: $0) } ?? Text("activity.untitled") }
    private var metaLine: String? {
        QuestifyCardText.metaLine(date: QuestifyCardText.date(item.startDate, locale: locale, displayTimeZone: timeZone),
                                  place: ActivityPresentation.place(item))
    }
    private var symbol: String { ["figure.walk", "music.note", "camera", "leaf", "building.2", "moon.stars", "map"][abs(item.id) % 7] }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    cover(size: nil)
                    text
                }
            } else {
                HStack(alignment: .center, spacing: 12) {
                    cover(size: 64)
                    text
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private func cover(size: CGFloat?) -> some View {
        if let url = QuestifyCardArtwork.safeURL(item.imageURL) {
            QuestifyCardArtwork(url: url, height: size ?? 160)
                .frame(width: size)
        } else {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: size ?? 44, height: size ?? 44)
                .accessibilityHidden(true)
        }
    }

    private var text: some View {
        VStack(alignment: .leading, spacing: 2) {
            title.font(.headline).foregroundStyle(.primary).lineLimit(2)
            if let metaLine {
                Text(verbatim: metaLine).lineLimit(2)
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                if let state = E1ActivityState.of(start: item.startDate, end: item.endDate) { stateLabel(state) }
                priceLabel
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stateLabel(_ state: E1ActivityState) -> some View {
        switch state {
        case .upcoming: return Label { Text(verbatim: copy.t("即将开始", "Upcoming")) } icon: { Image(systemName: "clock") }
        case .live: return Label { Text(verbatim: copy.t("进行中", "Happening now")) } icon: { Image(systemName: "dot.radiowaves.left.and.right") }
        case .ended: return Label { Text(verbatim: copy.t("已结束", "Ended")) } icon: { Image(systemName: "checkmark") }
        }
    }

    @ViewBuilder private var priceLabel: some View {
        if let amount = item.minimumAmount, amount >= 0 {
            if amount == 0 { Text(verbatim: copy.t("免费", "Free")).foregroundStyle(.green) }
            else { let p = MoneyDisplay.yuan(amount)  // owner decision 9: ¥12.50
                Text(verbatim: copy.t("\(p) 起", "From \(p)")).monospacedDigit() }
        }
    }
}

struct ActivityDetailHeader: View {
    let summary: ActivitySummary
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment:.leading,spacing:12) {
            if let url=QuestifyCardArtwork.safeURL(summary.imageURL) {
                QuestifyCardArtwork(url:url,height:dynamicTypeSize.isAccessibilitySize ? 180 : 240)
            }
            // No cover: nothing is drawn in its place.
            ActivityName(name:summary.name)
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("activity.detail.name")
            ActivitySummaryMetadata(summary:summary)
            if let address=ActivityPresentation.nonempty(summary.address),
               let place=ActivityPresentation.nonempty(summary.addressName), address != place {
                QuestifyMetadataLine(label:"activity.address",value:address,systemImage:"location")
            }
        }
        // Keep the title's focus frame on its text, not the entire cover/list cell.
        // The decorative cover is hidden; a containing boundary preserves that distinction.
        .accessibilityElement(children: .contain)
    }
}

private struct ActivityName: View {
    let name: String
    private var text: Text {
        if ActivityPresentation.nonempty(name) != nil { return Text(verbatim:name) }
        return Text("activity.untitled")
    }
    var body: some View {
        text.fixedSize(horizontal:false,vertical:true)
    }
}

private struct ActivitySummaryMetadata: View {
    let summary: ActivitySummary
    var body: some View {
        VStack(alignment:.leading,spacing:8) {
            if let date=ActivityPresentation.nonempty(summary.startDate) {
                QuestifyMetadataLine(label:"activity.date",value:date,systemImage:"calendar")
            }
            if let place=ActivityPresentation.place(summary) {
                QuestifyMetadataLine(label:"activity.location",value:place,systemImage:"mappin.and.ellipse")
            }
        }
    }
}

struct ActivityTicketCard: View {
    let ticket: ActivityTicket
    @Environment(\.locale) private var locale
    private var copy: CoreLoopCopy { CoreLoopCopy(locale: locale) }
    var body: some View {
        VStack(alignment:.leading,spacing:6) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) { name; Spacer(minLength: 8); price }
                VStack(alignment: .leading, spacing: 4) { name; price }
            }
            Group {
                if ticket.isSoldOut {
                    Label { Text(verbatim: copy.t("已售罄", "Sold out")) } icon: { Image(systemName: "xmark.circle").foregroundStyle(.red) }
                        .accessibilityIdentifier("activity.ticket.soldOut.\(ticket.id)")
                } else if let left = ticket.remainingInventory {
                    Label { Text(verbatim: copy.t("剩余 \(left)", "\(left) left")) } icon: { Image(systemName: "ticket").foregroundStyle(left <= 10 ? Color.orange : Color.green) }
                } else {
                    Label { Text(verbatim: copy.t("余票待确认", "Availability unconfirmed")) } icon: { Image(systemName: "questionmark.circle") }
                        .accessibilityIdentifier("activity.ticket.inventoryUnknown.\(ticket.id)")
                }
                // R7-PC-C1-5 (r8, MP utils/ticket-window.js): a session that has started / ended / closed says so on its card.
                let window = TicketWindowRule.state(for: ticket)
                if window != .available {
                    Label { Text(verbatim: window.label) } icon: { Image(systemName: "clock.badge.xmark") }
                        .accessibilityIdentifier("activity.ticket.window.\(ticket.id)")
                }
                // R7-PC-C1-5 (r1 PC-C-1-6): MP 场次时间 from the ticket's own start / end, then 报名截止 and 集合点.
                if let session = TopicXcxFacts.sessionTime(start: ticket.startTime, end: ticket.endTime) {
                    Label { Text(verbatim: session).monospacedDigit() } icon: { Image(systemName: "clock") }
                        .accessibilityIdentifier("activity.ticket.session.\(ticket.id)")
                }
                if let deadline = ActivityPresentation.nonempty(ticket.signupDeadline) {
                    Text(verbatim: copy.t("报名截止 \(deadline)", "Sign-up closes \(deadline)"))
                        .monospacedDigit()
                        .accessibilityIdentifier("activity.ticket.deadline.\(ticket.id)")
                }
                if let meeting = ActivityPresentation.nonempty(ticket.meetingPoint) {
                    Label { Text(verbatim: meeting) } icon: { Image(systemName: "mappin.and.ellipse") }
                }
                if let description=ActivityPresentation.nonempty(ticket.description) {
                    Text(verbatim:description)
                        .fixedSize(horizontal:false,vertical:true)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
    private var name: some View {
        Text(verbatim:ticket.name).font(.headline).foregroundStyle(.primary).fixedSize(horizontal:false,vertical:true)
    }
    private var price: some View {
        Text(verbatim: ticket.price == 0 ? copy.t("免费", "Free") : (E1Money.yuan(ticket.price, locale: locale) ?? "—"))
            .font(.headline).monospacedDigit().foregroundStyle(.primary)
            .accessibilityIdentifier("activity.ticket.price.\(ticket.id)")
    }
}

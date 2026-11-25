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

/// Same card rules as home: cover, title, one date · place line, starting price. Missing values are left out.
struct ActivityListCard: View {
    let item: ActivitySummary
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @Environment(\.timeZone) private var timeZone
    @Environment(\.cyPalette) private var palette

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
                VStack(alignment: .leading, spacing: CYSpacing.md) {
                    cover.aspectRatio(16.0 / 9.0, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                    text
                }
            } else {
                HStack(alignment: .center, spacing: CYSpacing.md) {
                    cover.frame(width: 96, height: 96).clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                    text
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.textSecondary).accessibilityHidden(true)
                }
            }
        }
        .cyDomainCard(radius: CYRadius.lg, padding: CYSpacing.md)
        .foregroundStyle(.primary)
        .accessibilityElement(children: .combine)
    }

    private var cover: some View {
        Color.clear.overlay { E1CoverArt(seed: item.name, symbol: symbol, imageURL: QuestifyCardArtwork.safeURL(item.imageURL)?.absoluteString, debugLabel: false) }
    }

    private var text: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            title.cyText(.cardTitle).foregroundStyle(palette.textPrimary).lineLimit(2)
            if let metaLine {
                Label { Text(verbatim: metaLine).lineLimit(2) } icon: { Image(systemName: "calendar") }
                    .cyText(.meta).foregroundStyle(palette.textSecondary)
            }
            HStack(spacing: CYSpacing.xs) {
                if let state = E1ActivityState.of(start: item.startDate, end: item.endDate) { state.chip(copy) }
                priceChip
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var priceChip: some View {
        if let amount = item.minimumAmount, amount >= 0 {
            if amount == 0 { CYStatusChip(verbatim: copy.t("免费", "Free"), tone: .success) }
            else { let p = MoneyDisplay.yuan(amount)  // owner decision 9: ¥12.50
                CYStatusChip(verbatim: copy.t("\(p) 起", "From \(p)")) }
        }
    }
}

struct ActivityDetailHeader: View {
    let summary: ActivitySummary
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment:.leading,spacing:16) {
            if let url=QuestifyCardArtwork.safeURL(summary.imageURL) {
                QuestifyCardArtwork(url:url,height:dynamicTypeSize.isAccessibilitySize ? 180 : 240)
            } else {
                // No cover: a clean surface with no text.
                RoundedRectangle(cornerRadius: 12,style:.continuous)
                    .fill(Color(uiColor:.tertiarySystemFill))
                    .frame(height:160)
                    .accessibilityHidden(true)
            }
            ActivityName(name:summary.name)
                .cyText(.display)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("activity.detail.name")
            ActivitySummaryMetadata(summary:summary)
            if let address=ActivityPresentation.nonempty(summary.address),
               let place=ActivityPresentation.nonempty(summary.addressName), address != place {
                QuestifyMetadataLine(label:"activity.address",value:address,systemImage:"location")
            }
        }
        .questifyCardSurface()
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
    @Environment(\.cyPalette) private var palette
    private var copy: CoreLoopCopy { CoreLoopCopy(locale: locale) }
    var body: some View {
        VStack(alignment:.leading,spacing:CYSpacing.md) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) { name; Spacer(minLength: CYSpacing.sm); price }
                VStack(alignment: .leading, spacing: CYSpacing.xs) { name; price }
            }
            if ticket.isSoldOut {
                CYStatusChip(verbatim: copy.t("已售罄", "Sold out"), tone: .danger, systemImage: "xmark.circle")
                    .accessibilityIdentifier("activity.ticket.soldOut.\(ticket.id)")
            } else if let left = ticket.remainingInventory {
                CYStatusChip(verbatim: copy.t("剩余 \(left)", "\(left) left"), tone: left <= 10 ? .warning : .success, systemImage: "ticket")
            } else {
                CYStatusChip(verbatim: copy.t("余票待确认", "Availability unconfirmed"), systemImage: "questionmark.circle")
                    .accessibilityIdentifier("activity.ticket.inventoryUnknown.\(ticket.id)")
            }
            // R7-PC-C1-5 (r8, MP utils/ticket-window.js): a session that has started / ended / closed says so on its card.
            let window = TicketWindowRule.state(for: ticket)
            if window != .available {
                CYStatusChip(verbatim: window.label, tone: .neutral, systemImage: "clock.badge.xmark")
                    .accessibilityIdentifier("activity.ticket.window.\(ticket.id)")
            }
            // R7-PC-C1-5 (r1 PC-C-1-6): MP 场次时间 from the ticket's own start / end, then 报名截止 and 集合点.
            if let session = TopicXcxFacts.sessionTime(start: ticket.startTime, end: ticket.endTime) {
                Label { Text(verbatim: session).monospacedDigit() } icon: { Image(systemName: "clock") }
                    .cyText(.bodyCompact).foregroundStyle(palette.textSecondary)
                    .accessibilityIdentifier("activity.ticket.session.\(ticket.id)")
            }
            if let deadline = ActivityPresentation.nonempty(ticket.signupDeadline) {
                Text(verbatim: copy.t("报名截止 \(deadline)", "Sign-up closes \(deadline)"))
                    .cyText(.meta).monospacedDigit().foregroundStyle(palette.textSecondary)
                    .accessibilityIdentifier("activity.ticket.deadline.\(ticket.id)")
            }
            if let meeting = ActivityPresentation.nonempty(ticket.meetingPoint) {
                Label { Text(verbatim: meeting) } icon: { Image(systemName: "mappin.and.ellipse") }
                    .cyText(.meta).foregroundStyle(palette.textSecondary)
            }
            if let description=ActivityPresentation.nonempty(ticket.description) {
                Text(verbatim:description)
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal:false,vertical:true)
            }
        }
        .cyDomainCard(radius: CYRadius.lg, padding: CYSpacing.lg)
        .accessibilityElement(children: .combine)
    }
    private var name: some View {
        Text(verbatim:ticket.name).cyText(.cardTitle).foregroundStyle(palette.textPrimary).fixedSize(horizontal:false,vertical:true)
    }
    private var price: some View {
        Text(verbatim: ticket.price == 0 ? copy.t("免费", "Free") : (E1Money.yuan(ticket.price, locale: locale) ?? "—"))
            .cyText(.dataXL, weight: .semibold).monospacedDigit().foregroundStyle(palette.textPrimary)
            .accessibilityIdentifier("activity.ticket.price.\(ticket.id)")
    }
}

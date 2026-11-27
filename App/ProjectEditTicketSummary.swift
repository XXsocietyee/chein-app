import SwiftUI

/// Design hand-off r1 CF-38 / CF-48: ticket summary for the 创作页 (`2 种票 · 39 积分起`, or `还没设置`
/// in red). Prices are 积分, the only currency; an unknown price shows `—`.
struct ProjectEditTicketSummaryLabel: View {
    let summary: EditorTicketSummary
    @Environment(\.cyPalette) private var palette
    var body: some View {
        Group {
            if summary.isEmpty {
                Text("editorKit.tickets.empty", tableName: "EditorKit").foregroundStyle(palette.danger)
            } else if let lowest = summary.lowestPoints {
                Text("editorKit.tickets.summary \(summary.kinds) \(lowest)", tableName: "EditorKit").foregroundStyle(palette.textSecondary)
            } else {
                Text("editorKit.tickets.summaryNoPrice \(summary.kinds)", tableName: "EditorKit").foregroundStyle(palette.textSecondary)
            }
        }
        .cyText(.meta)
        .textCase(nil)
        .accessibilityIdentifier("projectEdit.tickets.summary")
    }
}

/// Ticket row value: price in 积分 and stock, `—` when unknown.
struct ProjectEditTicketValue: View {
    let ticket: ProjectEditTicket
    @Environment(\.cyPalette) private var palette
    var body: some View {
        HStack(spacing: 4) {
            if let price = Int(ticket.price.trimmingCharacters(in: .whitespaces)) {
                Text("editorKit.points.value \(price)", tableName: "EditorKit")
            } else {
                Text(verbatim: EditorUnknown.dash)
            }
            Text(verbatim: "·").accessibilityHidden(true)
            if let stock = Int(ticket.totalStock.trimmingCharacters(in: .whitespaces)) {
                Text("editorKit.tickets.stock \(stock)", tableName: "EditorKit")
            } else {
                Text(verbatim: EditorUnknown.dash)
            }
            if ticket.isFamily {
                Text(verbatim: "·").accessibilityHidden(true)
                Text("mpPublish.ticket.familyShort")
            }
        }
        .cyText(.meta)
        .foregroundStyle(palette.textSecondary)
    }
}

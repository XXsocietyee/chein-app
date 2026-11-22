import SwiftUI

/// Card facts, mounted on the own shelf. The marketplace plan's one action is a row button on
/// `TemplateAuthoringMineView`: the host row owns the action, so this view
/// has no button and builds no market request.
struct TemplateOwnShelfCardSection: View {
    let facts: TemplateOwnShelfCardFacts?
    let state: TemplateOwnShelfStateProjection
    let rowID: Int
    @Environment(\.locale) private var locale
    private var zh: Bool { locale.language.languageCode?.identifier == "zh" }
    private var plan: TemplateOwnShelfMarketPlan { TemplateOwnShelfMarketPlan(state) }
    var body: some View {
        if let facts {
            TemplateOwnShelfCardFactLines(facts: facts, zh: zh, rowID: rowID)
        }
        // The marketplace plan is never dispatchable here: the host row shows its one action, so this card adds none.
    }
}

private struct TemplateOwnShelfCardFactLines: View {
    @Environment(\.locale) private var locale
    let facts: TemplateOwnShelfCardFacts
    let zh: Bool
    let rowID: Int
    var body: some View {
        if let rating = facts.rating {
            LabeledContent("discovery.templateDetail.stat.rating", value: NSDecimalNumber(decimal: rating).stringValue)
                .accessibilityIdentifier("templateOwnShelf.card.rating.\(rowID)")
        }
        if let count = facts.useCount {
            fact("templateOwnShelf.card.useCount", String(count), id: "templateOwnShelf.card.uses.\(rowID)")
        }
        if let duration = facts.durationMinutes {
            fact("templateOwnShelf.card.durationLabel", appLocalized("templateOwnShelf.card.minutes \(duration)", locale: locale), id: "templateOwnShelf.card.duration.\(rowID)")
        }
        if let created = facts.createTime {
            fact("templateOwnShelf.card.createdLabel", created, id: "templateOwnShelf.card.created.\(rowID)")
        }
        if let feedback = facts.reviewFeedback {
            Text("discovery.templateDetail.reviewFeedback \(feedback)")
                .accessibilityIdentifier("templateOwnShelf.card.feedback.\(rowID)")
        }
    }
    /// Label left, value right; the value keeps the row's identifier.
    private func fact(_ title: LocalizedStringKey, _ value: String, id: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(verbatim: value).foregroundStyle(.secondary).accessibilityIdentifier(id)
        }
    }
}

import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// U06 turn block in the session team view. Every member sees the current and next turn and when theirs comes;
/// only the leader sees which role holds them and the full order (the server sends the order to the leader only).
struct PlayAdvancedTurnBlock: View {
    let turn: PlayAdvancedTurn
    let isLeader: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            LabeledContent("advancedTeam.turn.current") {
                if turn.finished { Text("advancedTeam.turn.finished") }
                else if let slot = turn.currentSlot { Text(verbatim: slot.display) }
                else { Text("advancedTeam.turn.position \(turn.position + 1) \(turn.size)").monospacedDigit() }
            }.accessibilityIdentifier("advancedTeam.turn.current")
            if !turn.finished {
                LabeledContent("advancedTeam.turn.next") { nextText }.accessibilityIdentifier("advancedTeam.turn.next")
                HStack(spacing: CYSpacing.sm) {
                    mineChip
                    Text("advancedTeam.turn.round \(turn.round)").cyText(.meta).foregroundStyle(CYColor.textTertiary).monospacedDigit()
                }
            }
            if isLeader && !turn.order.isEmpty {
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    Text("advancedTeam.turn.order").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    ForEach(turn.order) { slot in
                        HStack(spacing: CYSpacing.sm) {
                            Text(verbatim: String(slot.position + 1)).cyText(.meta).monospacedDigit().foregroundStyle(CYColor.textTertiary)
                            Text(verbatim: slot.display).cyText(.body).foregroundStyle(CYColor.textPrimary)
                            Spacer(minLength: CYSpacing.sm)
                            if !turn.finished && slot.position == turn.position { CYStatusChip("advancedTeam.turn.now", tone: .info) }
                            else if slot.position == turn.nextPosition { CYStatusChip("advancedTeam.turn.upNext", tone: .neutral) }
                        }.accessibilityElement(children: .combine)
                    }
                }.accessibilityIdentifier("advancedTeam.turn.order")
            }
        }
    }

    @ViewBuilder private var nextText: some View {
        if turn.nextPosition == nil { Text(verbatim: "—") }
        else if let slot = turn.nextSlot { Text(verbatim: slot.display) }
        else if turn.nextIsMine == true { Text("advancedTeam.turn.you") }
        else { Text("advancedTeam.turn.position \((turn.nextPosition ?? 0) + 1) \(turn.size)").monospacedDigit() }
    }

    @ViewBuilder private var mineChip: some View {
        if turn.myTurn { CYStatusChip("advancedTeam.turn.mine", tone: .success, systemImage: "hand.raised") }
        else if let wait = turn.turnsUntilMine { CYStatusChip("advancedTeam.turn.wait \(wait)", tone: .neutral, systemImage: "hourglass") }
        else { CYStatusChip("advancedTeam.turn.noRole", tone: .neutral) }
    }
}

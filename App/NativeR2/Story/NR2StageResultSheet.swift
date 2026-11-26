import SwiftUI

/// Which stop just settled as done on this screen. Opened only by the stop's own submission.
struct NR2StageResultTarget: Identifiable, Equatable {
    let id = UUID()
    let nodeID: Int
}

/// Native r2 story flow, S9: the stage result, in place, as a medium sheet.
/// Result icon, then score / stamp / unlock as `LabeledContent`, then one prominent Continue.
/// Every value is read from what the coordinator already holds (`model.reward` for this stop,
/// `PlayTaskOutcomePresentation` for the next stop); nothing is requested or invented.
@MainActor struct NR2StageResultSheet: View {
    @Bindable var model: PlayExperienceCoordinator
    let nodeID: Int
    /// Opens the next stop (same callback the r1 outcome section uses). Nil just closes.
    var openNode: ((Int) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var appeared = false

    private var reward: PlayWireValue? {
        guard let reward = model.reward, reward["nodeId"].tolerantInteger == nodeID else { return nil }
        return reward
    }
    private var outcome: PlayTaskOutcomePresentation {
        PlayTaskOutcomePresentation(snapshot: model.snapshot, nodeID: nodeID, phase: model.phase.rawValue,
                                    isCurrentRead: model.hasCurrentMediaSnapshot, unresolved: model.unresolved)
    }
    private var stationName: String? {
        let name = model.snapshot?.visibleNodes.first { $0.id == nodeID }?.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        return name?.isEmpty == false ? name : nil
    }
    private var score: Int? { reward.flatMap { $0["xp"].tolerantInteger ?? $0["score"].tolerantInteger } }
    private var stamp: String? {
        guard let reward else { return nil }
        if let medal = reward["medalName"].text?.trimmingCharacters(in: .whitespacesAndNewlines), !medal.isEmpty { return medal }
        if let drop = PlayRewardDrop.fromReward(reward) { return drop.detailText(locale: locale) }
        return PlayRewardBadgeTarget.targets(in: reward).compactMap(\.name).first
    }

    var body: some View {
        let outcome = self.outcome
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.green)
                            .nativeR2BounceOnAppear()
                            .accessibilityHidden(true)
                        Text("play.nr2.result.done").font(.title2.bold())
                            .accessibilityIdentifier("playVerdict.word")
                        if let stationName {
                            Text(verbatim: stationName).font(.subheadline).foregroundStyle(.secondary)
                                .accessibilityIdentifier("playVerdict.text")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                }
                Section {
                    LabeledContent("play.nr2.result.score") {
                        if let score { Text(verbatim: "+" + String(score)).monospacedDigit().contentTransition(.numericText()) }
                        else { Text(verbatim: "—") }
                    }
                    .accessibilityIdentifier("play.nr2.result.score")
                    LabeledContent("play.nr2.result.stamp") {
                        if let stamp { Text(verbatim: stamp).multilineTextAlignment(.trailing) }
                        else { Text(verbatim: "—") }
                    }
                    .accessibilityIdentifier("play.nr2.result.stamp")
                    LabeledContent("play.nr2.result.unlock") {
                        if let next = outcome.nextNodeName, !next.isEmpty { Text(verbatim: next).multilineTextAlignment(.trailing) }
                        else { Text(LocalizedStringKey("play.nr2.result.unlock." + outcome.continuation.rawValue)) }
                    }
                    .accessibilityIdentifier("play.nr2.result.unlock")
                }
                Section {
                    Button(action: proceed) {
                        Text(canOpenNext(outcome) ? "play.nr2.result.next" : "play.nr2.result.continue")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .listRowBackground(Color.clear)
                    .accessibilityIdentifier("playVerdict.continue")
                }
            }
            .navigationTitle(Text("play.nr2.result.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("play.nr2.result.close") { dismiss() }
                        .accessibilityIdentifier("play.nr2.result.close")
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .sensoryFeedback(.success, trigger: appeared)
        .onAppear { appeared = true }
        .accessibilityIdentifier("play.nr2.result")
    }

    private func canOpenNext(_ outcome: PlayTaskOutcomePresentation) -> Bool {
        outcome.continuation == .nextTask && outcome.nextNodeID != nil && openNode != nil && model.hasCurrentMediaSnapshot
    }
    private func proceed() {
        let outcome = self.outcome
        let next = canOpenNext(outcome) ? outcome.nextNodeID : nil
        dismiss()
        if let next { openNode?(next) }
    }
}

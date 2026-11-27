import SwiftUI

/// Optional node augmentation: probe errors render nothing and never replace task controls.
@MainActor struct PlayJourneyCheckView: View {
    @Bindable var model: JourneyCheckCoordinator
    let nodeDone: Bool
    var body: some View {
        Group {
            JourneyRoleViewSection(model: model.roleContent)
            if model.visible, let problem = model.problem {
                Section {
                    VStack(alignment: .leading, spacing: CYSpacing.md) {
                        HStack(spacing: CYSpacing.sm) {
                            Image(systemName: "dice.fill").font(.title3).foregroundStyle(CYColor.textSecondary)
                            Text("journey.check.title").cyText(.meta).foregroundStyle(CYColor.textTertiary)
                        }.accessibilityHidden(true)
                        Text(verbatim: problem.skill).cyText(.display).foregroundStyle(CYColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("journey.check.stage")
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: CYSpacing.sm) { checkChips(problem) }
                            VStack(alignment: .leading, spacing: CYSpacing.sm) { checkChips(problem) }
                        }
                        CYDiceTierStrip(tier: problem.tier)
                        DiceD20CanvasView(
                            values: model.receipt?.dice ?? [],
                            kept: model.receipt?.kept,
                            rollMode: problem.advantage ? "advantage" : (problem.disadvantage ? "disadvantage" : "normal"),
                            rolling: model.acting && model.receipt == nil
                        ).frame(maxWidth: .infinity)
                        if let receipt = model.receipt, let dc = receipt.dc, let total = receipt.total {
                            JourneyCheckDCTrack(total: total, dc: dc, success: receipt.success)
                        }
                        modifiers(problem.mods)
                        if let receipt = model.receipt {
                            if receipt.settled, let success = receipt.success {
                                // Settle screen headline (mini-program journey-check): over the line or not, in words and icon.
                                Label(success ? "journey.settled.passed" : "journey.settled.missed",
                                      systemImage: success ? "checkmark.seal.fill" : "xmark.seal")
                                    .cyText(.sectionTitle)
                                    .foregroundStyle(success ? CYColor.successText : CYColor.warningText)
                                    .frame(maxWidth: .infinity)
                                    .accessibilityIdentifier("journey.check.settledVerdict")
                            }
                            resultCard(receipt)
                            modifiers(receipt.mods)
                            if receipt.exhausted { Text("journey.exhausted").cyText(.meta).foregroundStyle(CYColor.textSecondary) }
                            if receipt.settled {
                                if !receipt.text.isEmpty { Text(verbatim: receipt.text).cyText(.body).foregroundStyle(CYColor.textSecondary) }
                                if !receipt.failCostLabel.isEmpty { LabeledContent("journey.cost") { Text(verbatim: receipt.failCostLabel) } }
                            }
                        }
                        if let issue = model.issue { Text(verbatim: issue).foregroundStyle(CYColor.dangerText).accessibilityIdentifier("journey.check.error") }
                        if model.unknown {
                            Text("journey.unknown")
                            CYPillButton("journey.recover") { try? model.prepare(.settle, recoverUnknown: true) }
                                .disabled(!model.canRecover).accessibilityIdentifier("journey.check.recover")
                        } else if model.receipt == nil {
                            // Mini-program 「按住摇骰，松手掷出」; a tap or a phone shake also rolls.
                            CYHoldToRollButton(busy: model.acting) {
                                UIKitHapticsDriver.ensureInstalled()
                                HapticsService.shared.play(.diceRoll)
                                try? model.prepare(.roll)
                            }
                                .disabled(model.acting || !model.available)
                                .cyOnShake(enabled: !model.acting && model.available) {
                                    UIKitHapticsDriver.ensureInstalled()
                                    HapticsService.shared.play(.diceRoll)
                                    try? model.prepare(.roll)
                                }
                        }
                        else if model.receipt?.settled == false {
                            if model.receipt?.canReroll == true { action(.reroll, style: .secondary) }
                            action(.settle)
                        }
                        if model.acting { ProgressView("journey.working") }
                        if !model.available { Text("journey.disabled") }
                        Button("journey.close") { model.close() }.cyText(.label).foregroundStyle(CYColor.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: 44).accessibilityIdentifier("journey.check.close")
                    }
                    .padding(CYSpacing.xl)
                    .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.sheet, style: .continuous))
                    .cyHapticEvent(.diceLand, trigger: model.receipt?.dice ?? []) { old, next in !next.isEmpty && old != next }
                    .cyHapticEvent(.rewardOrMedal, trigger: model.receipt?.success) { _, next in next == true }
                    .cyHapticEvent(.warning, trigger: model.receipt?.success) { _, next in next == false }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)).listRowBackground(Color.clear)
                }
            } else if model.problem != nil && !model.nodeDone {
                Button("journey.check.title") { model.reopen() }.accessibilityIdentifier("journey.check.reopen")
            }
        }
    }
    /// Big total against the pass line, with icon + words so colour is never the only signal.
    private func resultCard(_ receipt: JourneyCheckReceipt) -> some View {
        let tone = receipt.success == true ? CYColor.successText : receipt.success == false ? CYColor.warningText : CYColor.textSecondary
        return VStack(spacing: CYSpacing.xs) {
            if let success = receipt.success {
                Label(success ? "journey.success" : "journey.failure", systemImage: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .cyText(.cardTitle).foregroundStyle(tone)
            }
            Text(verbatim: receipt.total.map(String.init) ?? "—").cyText(.data2XL)
                .foregroundStyle(CYColor.textPrimary)
            HStack(spacing: CYSpacing.md) {
                number("journey.kept", receipt.kept); number("journey.dc", receipt.dc)
            }.cyText(.meta).foregroundStyle(CYColor.textSecondary)
            if !receipt.nat.isEmpty { Text(verbatim: receipt.nat).cyText(.meta) }
            HStack(spacing: CYSpacing.md) { number("journey.hp", receipt.hp); number("journey.luck", receipt.luck) }
                .cyText(.meta).foregroundStyle(CYColor.textSecondary)
        }.frame(maxWidth: .infinity).padding(CYSpacing.lg)
            .background(CYColor.bgPage, in: RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous).stroke(tone.opacity(0.5), lineWidth: 1))
            .accessibilityElement(children: .contain)
    }
    private func action(_ action: JourneyCheckAction, style: CYPillStyle = .primary) -> some View {
        CYPillButton(LocalizedStringKey("journey." + action.rawValue), style: style) { try? model.prepare(action) }
            .disabled(model.acting || !model.available).accessibilityIdentifier("journey.check." + action.rawValue)
    }
    @ViewBuilder private func number(_ key: LocalizedStringKey, _ value: Int?) -> some View {
        if let value { HStack(spacing: 4) { Text(key); Text(verbatim: String(value)).monospacedDigit().fontWeight(.semibold) } }
    }
    @ViewBuilder private func checkChips(_ problem: JourneyCheckProblem) -> some View {
        if let lit = JourneyCheckTier(raw: problem.tier) {
            // Three difficulty tiers with the author's choice lit; the exact line comes from the receipt's DC.
            HStack(spacing: CYSpacing.xxs) {
                ForEach(JourneyCheckTier.allCases, id: \.self) { tier in
                    Text(LocalizedStringKey("journey.tier." + tier.rawValue))
                        .cyText(.label)
                        .padding(.horizontal, CYSpacing.md).frame(minHeight: 32)
                        .foregroundStyle(tier == lit ? CYColor.bgPage : CYColor.textSecondary)
                        .background(tier == lit ? CYColor.textPrimary : CYColor.textTertiary.opacity(0.15), in: Capsule())
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("journey.tier.label") + Text(verbatim: " ") + Text(LocalizedStringKey("journey.tier." + lit.rawValue)))
        } else {
            CYStatusChip(verbatim: problem.tier)
        }
        if problem.advantage { CYStatusChip("journey.advantage", tone: .success, systemImage: "plus.circle") }
        if problem.disadvantage { CYStatusChip("journey.disadvantage", tone: .warning, systemImage: "minus.circle") }
    }
    private func modifiers(_ mods: [JourneyCheckMod]) -> some View {
        ForEach(Array(mods.enumerated()), id: \.offset) { _, mod in
            HStack(alignment: .firstTextBaseline, spacing: CYSpacing.sm) {
                Image(systemName: mod.active ? "checkmark.circle.fill" : "circle").foregroundStyle(mod.active ? CYColor.successText : CYColor.textTertiary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: mod.label).cyText(.bodyCompact).foregroundStyle(CYColor.textPrimary)
                    Text(mod.active ? "journey.active" : "journey.inactive").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                }
                Spacer(minLength: 0)
                if let value = mod.value { Text(verbatim: value >= 0 ? "+\(value)" : "\(value)").cyText(.label).monospacedDigit() }
            }.accessibilityElement(children: .combine)
        }
    }
}
/// Difficulty tier names the server uses; anything else keeps the raw chip.
enum JourneyCheckTier: String, CaseIterable {
    case easy, medium, hard
    init?(raw: String) {
        switch raw.lowercased() {
        case "easy", "simple": self = .easy
        case "medium", "normal", "standard": self = .medium
        case "hard", "difficult": self = .hard
        default: return nil
        }
    }
}

/// 1-20 track with the DC marker and the total filled up to it (mini-program `.jc__track`).
/// Colour is never the only signal: the result card states success in words.
struct JourneyCheckDCTrack: View {
    let total: Int
    let dc: Int
    let success: Bool?
    @QuestifyReduceMotion private var reduceMotion
    @State private var filled = false
    private func fraction(_ value: Int) -> CGFloat { CGFloat(min(max(value, 0), 20)) / 20 }
    var body: some View {
        VStack(spacing: CYSpacing.xxs) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(CYNight.glassFill)
                    Capsule().fill(success == false ? CYColor.warningText : CYNight.verify)
                        .frame(width: proxy.size.width * (filled ? fraction(total) : 0))
                    Rectangle().fill(CYColor.textPrimary).frame(width: 2, height: 18)
                        .offset(x: proxy.size.width * fraction(dc) - 1)
                }
            }
            .frame(height: 10)
            HStack {
                ForEach([1, 5, 10, 15, 20], id: \.self) { tick in
                    Text(verbatim: String(tick)).cyText(.micro).monospacedDigit().foregroundStyle(CYColor.textTertiary)
                    if tick != 20 { Spacer(minLength: 0) }
                }
            }
        }
        .padding(.vertical, CYSpacing.xs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("journey.track \(total) \(dc)"))
        .onAppear { withAnimation(reduceMotion ? nil : .easeOut(duration: CYMotion.Duration.slow)) { filled = true } }
    }
}

/// A List row is recycled while scrolling. Present reviews from the owning screen instead
/// of distributing one sheet modifier across the optional Group's lazy Section children.
@MainActor struct JourneyCheckReviewPresentation: ViewModifier {
    let model: JourneyCheckCoordinator?
    @ViewBuilder func body(content: Content) -> some View {
        if let model { content.modifier(JourneyCheckReviewPresenter(model: model)) }
        else { content }
    }
}
@MainActor private struct JourneyCheckReviewPresenter: ViewModifier {
    @Bindable var model: JourneyCheckCoordinator
    func body(content: Content) -> some View {
        content.cySheet(item: Binding(get: { model.review }, set: { if $0 == nil { model.cancelReview() } })) { review in Group {
            NavigationStack {
                Form {
                    Section("journey.review") {
                        Text(LocalizedStringKey("journey." + review.action.rawValue))
                        if review.action == .reroll { Text("journey.reroll.cost") }
                        if review.action == .settle { Text("journey.settle.impact") }
                        Text(verbatim: "\(review.topicID) / \(review.nodeID) / \(review.checkID)")
                        Button("journey.confirm") { Task { await model.confirm(review) } }
                            .accessibilityIdentifier("journey.check.confirm")
                    }
                }.cyGroupedSurface().navigationTitle("journey.review").navigationBarTitleDisplayMode(.inline).privacySensitive()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("journey.cancel", role: .cancel) { model.cancelReview() }
                                .accessibilityIdentifier("journey.check.cancelReview")
                        }
                    }
            }
        }.cySheet(detents: [.large]) }
    }
}
@MainActor struct PlayAmbientView: View {
    @Bindable var model: JourneyAmbientCoordinator
    var locationSource: (any JourneyAmbientLocationSource)? = nil
    var body: some View {
        Group {
            // The companion line is the MP floating bubble (`PlayNavBubbleOverlay`), not a list row.
            if let egg = model.eggBubble {
                Section("journey.egg") {
                    Text(verbatim: egg.text).accessibilityIdentifier("journey.egg.text")
                    if model.collected.contains(egg.id) { Text("journey.egg.collected") }
                    Button("journey.close") { model.dismissBubble() }
                }.accessibilityIdentifier("journey.egg.bubble")
            }
        }
        .task {
            if let locationSource { await model.track(source: locationSource) }
        }
        .task {
            while !Task.isCancelled {
                model.tick(now: Date())
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}

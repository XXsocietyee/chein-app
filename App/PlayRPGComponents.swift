import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

// MARK: - Shared Play / RPG components (design-system based)

/// Honest "not available yet" state for play writes that the city-node transport rejects.
/// It never claims success; it explains what stays on the device.
@available(macOS 14.0, *)
@MainActor struct PlayWriteUnavailableBanner: View {
    let surface: PlayWriteSurface

    var body: some View {
        let availability = PlayWriteAvailability.current(for: surface)
        CYCard(variant: .subtle, radius: CYRadius.sm, padding: CYSpacing.md) {
            HStack(alignment: .top, spacing: CYSpacing.md) {
                Image(systemName: "clock.badge.exclamationmark")
                    .cyText(.cardTitle)
                    .foregroundStyle(CYColor.warningText)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    Text(availability.title)
                        .cyText(.cardTitle)
                        .foregroundStyle(CYColor.textPrimary)
                    Text(availability.message)
                        .cyText(.bodyCompact)
                        .foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("play.write.unavailable.\(surface.rawValue)")
    }
}

/// Step checklist for a challenge (arrive, photo, answer).
@available(macOS 14.0, *)
@MainActor struct ChallengePOIChecklistView: View {
    let items: [ChallengePOIChecklistItem]

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            ForEach(items) { item in
                HStack(alignment: .top, spacing: CYSpacing.md) {
                    Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                        .cyText(.cardTitle)
                        .foregroundStyle(item.isDone ? CYColor.successText : CYColor.textTertiary)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                        Text(item.title)
                            .cyText(.bodyMedium)
                            .foregroundStyle(CYColor.textPrimary)
                        Text(item.detail)
                            .cyText(.meta)
                            .foregroundStyle(CYColor.textTertiary)
                    }
                    Spacer(minLength: 0)
                }
                .frame(minHeight: CYSpacing.minTouchTarget, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityValue(item.isDone ? W8Text.t("已完成", "Done") : W8Text.t("待完成", "To do"))
            }
        }
    }
}

// MARK: - Dice roller sheet (practice rolls)

/// Practice D20 roller presented as a sheet with detents. Rolls are local only and never recorded on a character.
@available(macOS 14.0, *)
@MainActor struct DiceRollerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var session = DiceRollerSession(seed: UInt64.random(in: 1...UInt64.max))
    @State private var mode: DiceCheckEngine.RollMode = .normal
    @State private var rolledMode: DiceCheckEngine.RollMode = .normal
    @State private var tier = "medium"
    @State private var skill = 0
    @State private var rolling = false
    @State private var animationStart: Date?
    @State private var rollTick = 0
    @State private var settleTask: Task<Void, Never>?

    private var shownReceipt: DiceJourneyCheckReceiptView? { rolling ? nil : session.receipt }
    private var canvasMode: DiceCheckEngine.RollMode { (session.receipt == nil && !rolling) ? mode : rolledMode }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CYSpacing.lg) {
                    dieCard
                    controlsCard
                    if !session.history.isEmpty { historySection }
                    Text(W8Text.t("练习掷骰只在本机进行，不会记录到角色卡。", "Practice rolls stay on this device and are not recorded on your character."))
                        .cyText(.meta)
                        .foregroundStyle(CYColor.textTertiary)
                }
                .padding(.horizontal, CYSpacing.pageHorizontal)
                .padding(.vertical, CYSpacing.lg)
            }
            .background(CYColor.bgPage.ignoresSafeArea())
            .navigationTitle(W8Text.t("掷骰练习", "Dice roller"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(W8Text.t("完成", "Done")) { dismiss() }
                        .frame(minHeight: CYSpacing.minTouchTarget)
                }
            }
        }
        .cySheet()
        .cyHaptic(.impactMedium, trigger: rollTick)
        .onDisappear { settleTask?.cancel() }
    }

    private var dieCard: some View {
        CYCard(variant: .elevated) {
            VStack(spacing: CYSpacing.md) {
                DiceD20CanvasView(
                    values: shownReceipt?.dice ?? [],
                    kept: shownReceipt?.kept,
                    rollMode: canvasMode.rawValue,
                    rolling: rolling,
                    animationStart: animationStart
                )
                if let receipt = shownReceipt {
                    Text(receipt.success == true ? W8Text.t("检定通过", "Check passed") : W8Text.t("检定未通过", "Check failed"))
                        .cyText(.sectionTitle)
                        .foregroundStyle(receipt.success == true ? CYColor.successText : CYColor.dangerText)
                    DiceJourneyReceiptSummaryCard(receipt: receipt)
                } else {
                    Text(rolling ? W8Text.t("掷骰中…", "Rolling…") : W8Text.t("选择难度后掷骰", "Pick a difficulty, then roll"))
                        .cyText(.bodyCompact)
                        .foregroundStyle(CYColor.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .contain)
    }

    private var controlsCard: some View {
        CYCard {
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                Picker(W8Text.t("掷骰方式", "Roll mode"), selection: $mode) {
                    Text(W8Text.t("普通", "Normal")).tag(DiceCheckEngine.RollMode.normal)
                    Text(W8Text.t("优势", "Advantage")).tag(DiceCheckEngine.RollMode.advantage)
                    Text(W8Text.t("劣势", "Disadvantage")).tag(DiceCheckEngine.RollMode.disadvantage)
                }
                .pickerStyle(.segmented)
                .disabled(rolling)

                Picker(W8Text.t("难度", "Difficulty"), selection: $tier) {
                    ForEach(["easy", "medium", "hard"], id: \.self) { key in
                        Text(DiceJourneyCheckRules.tierLabel(key)).tag(key)
                    }
                }
                .pickerStyle(.menu)
                .frame(minHeight: CYSpacing.minTouchTarget)
                .disabled(rolling)

                Stepper(value: $skill, in: -5...10) {
                    Text(W8Text.t("技能加值 \(skill >= 0 ? "+" : "")\(skill)", "Skill bonus \(skill >= 0 ? "+" : "")\(skill)"))
                        .cyText(.bodyMedium)
                        .foregroundStyle(CYColor.textPrimary)
                }
                .disabled(rolling)

                Button(action: roll) {
                    Text(session.receipt == nil ? W8Text.t("掷 D20", "Roll D20") : W8Text.t("再掷一次", "Roll again"))
                }
                .buttonStyle(.cyPrimary(fullWidth: true))
                .disabled(rolling)
                .accessibilityIdentifier("dice.roller.roll")
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            CYSectionHeader(LocalizedStringKey(W8Text.t("最近几次", "Recent rolls")))
            CYCard(variant: .subtle) {
                VStack(spacing: CYSpacing.sm) {
                    ForEach(session.history) { entry in
                        HStack {
                            Text("D20 \(entry.kept)")
                                .cyText(.numericBody)
                                .foregroundStyle(CYColor.textPrimary)
                            Spacer()
                            Text(W8Text.t("总计 \(entry.total) / DC \(entry.dc)", "Total \(entry.total) / DC \(entry.dc)"))
                                .cyText(.meta)
                                .foregroundStyle(CYColor.textSecondary)
                            Image(systemName: entry.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(entry.success ? CYColor.successText : CYColor.dangerText)
                                .accessibilityHidden(true)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityValue(entry.success ? W8Text.t("通过", "Passed") : W8Text.t("未通过", "Failed"))
                    }
                }
            }
        }
    }

    private func roll() {
        guard !rolling else { return }
        rolledMode = mode
        session.roll(mode: mode, tier: tier, skillValue: skill)
        rollTick += 1
        settleTask?.cancel()
        if reduceMotion {
            animationStart = nil
            AccessibilityNotification.Announcement(session.announcement).post()
            return
        }
        rolling = true
        animationStart = Date()
        settleTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }
            rolling = false
            animationStart = Date()
            AccessibilityNotification.Announcement(session.announcement).post()
        }
    }
}

#if DEBUG
#Preview("Dice roller") {
    DiceRollerSheet()
}
#endif

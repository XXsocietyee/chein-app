import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// Rich character sheet and RPG status detail view (ported from `subpackageMember/character/index.wxml`).
/// Read view by default. "Adjust" opens a local, clamped editing mode; saving is not wired to a server contract,
/// so Save explains that instead of claiming success (see `PlayWriteAvailability`).
@available(macOS 14.0, *)
@MainActor struct CharacterSheetDetailView: View {
    let card: CharacterCard
    var rpgSheet: CharacterRpgSheet? = nil
    var definitionSource: String? = nil
    var attributeLevels: [String: [CharacterAttributeLevel]] = [:]

    @State private var draft: CharacterSheetDraft?
    @State private var saveAttempted = false
    @State private var showingDice = false

    private var isEditing: Bool { draft != nil }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: CYSpacing.lg) {
                headerCard

                if isEditing {
                    PlayWriteUnavailableBanner(surface: .characterSheetSave)
                }

                if !card.attributes.isEmpty {
                    CYSectionHeader("characterCard.traits")
                    CYCard {
                        VStack(alignment: .leading, spacing: CYSpacing.lg) {
                            ForEach(card.attributes) { attribute in
                                CharacterAttributeRow(
                                    attribute: attribute,
                                    levels: attributeLevels[attribute.stateKey] ?? [],
                                    draft: $draft)
                            }
                        }
                    }
                }

                if let draft, draft.isDirty {
                    pendingChangesCard(draft)
                }

                if let rpg = rpgSheet {
                    CYSectionHeader("characterCard.rpgStatus")
                    CYCard { rpgContent(rpg) }
                }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.vertical, CYSpacing.lg)
        }
        .background(CYColor.bgPage.ignoresSafeArea())
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showingDice = true
                } label: {
                    Label(W8Text.t("掷骰练习", "Dice roller"), systemImage: "dice")
                }
                .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
                .accessibilityIdentifier("characterSheet.diceRoller")

                if !card.attributes.isEmpty {
                    Button(isEditing ? W8Text.t("完成", "Done") : W8Text.t("调整", "Adjust")) {
                        toggleEditing()
                    }
                    .frame(minHeight: CYSpacing.minTouchTarget)
                    .accessibilityIdentifier("characterSheet.toggleEdit")
                }
            }
        }
        .sheet(isPresented: $showingDice) { DiceRollerSheet() }
    }

    // MARK: Header

    private var headerCard: some View {
        CYCard(variant: .elevated) {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                HStack(alignment: .firstTextBaseline) {
                    Text(card.heading)
                        .font(CYTypography.sheetTitle)
                        .foregroundStyle(CYColor.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: CYSpacing.sm)
                    Text(card.statusText)
                        .font(CYTypography.caption)
                        .foregroundStyle(card.running ? CYColor.successText : CYColor.textSecondary)
                        .padding(.horizontal, CYSpacing.sm)
                        .padding(.vertical, CYSpacing.xs)
                        .background(card.running ? CYColor.successSoft : CYColor.bgRaised, in: Capsule())
                }
                Text(card.definitionNote(for: definitionSource))
                    .font(CYTypography.meta)
                    .foregroundStyle(CYColor.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Editing

    private func toggleEditing() {
        if isEditing {
            draft = nil
            saveAttempted = false
        } else {
            draft = CharacterSheetDraft(attributes: card.attributes)
        }
    }

    @ViewBuilder
    private func pendingChangesCard(_ draft: CharacterSheetDraft) -> some View {
        CYCard(variant: .accentTint) {
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                Text(W8Text.t("本机预览的调整", "Adjustments previewed on this device"))
                    .font(CYTypography.cardTitle)
                    .foregroundStyle(CYColor.textPrimary)
                ForEach(draft.changes) { change in
                    HStack {
                        Text(change.label)
                            .font(CYTypography.bodyCompact)
                            .foregroundStyle(CYColor.textSecondary)
                        Spacer()
                        Text("\(change.from) → \(change.to)")
                            .font(CYTypography.numericBody)
                            .foregroundStyle(CYColor.accentText)
                    }
                    .accessibilityElement(children: .combine)
                }
                if saveAttempted {
                    // Honest result of pressing Save: nothing was sent.
                    Label(PlayWriteAvailability.current(for: .characterSheetSave).title, systemImage: "exclamationmark.circle")
                        .font(CYTypography.label)
                        .foregroundStyle(CYColor.warningText)
                        .accessibilityIdentifier("characterSheet.saveUnavailable")
                }
                HStack(spacing: CYSpacing.md) {
                    Button(W8Text.t("还原", "Reset")) {
                        self.draft?.reset()
                        saveAttempted = false
                    }
                    .buttonStyle(.cySecondary(fullWidth: true))
                    Button(W8Text.t("保存", "Save")) { saveAttempted = true }
                        .buttonStyle(.cyPrimary(fullWidth: true))
                        .accessibilityIdentifier("characterSheet.save")
                }
            }
        }
    }

    // MARK: RPG status

    @ViewBuilder
    private func rpgContent(_ rpg: CharacterRpgSheet) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.lg) {
            if let momentum = rpg.momentum {
                meterRow(label: Text("characterCard.momentum"), valueText: "\(momentum.value)/\(momentum.max)",
                         percent: momentum.percent, tint: CYColor.accentWarm)
            }
            ForEach(rpg.clocks) { clock in
                meterRow(label: Text(clock.label), valueText: "\(clock.value)/\(clock.segments)",
                         percent: clock.percent, tint: CYColor.accent)
            }
            ForEach(rpg.facets) { traitRow($0) }
            ForEach(rpg.aspects) { traitRow($0) }
        }
    }

    private func meterRow(label: Text, valueText: String, percent: Int, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            HStack {
                label
                    .font(CYTypography.bodyMedium)
                    .foregroundStyle(CYColor.textPrimary)
                Spacer()
                Text(valueText)
                    .font(CYTypography.numericBody)
                    .foregroundStyle(CYColor.textSecondary)
            }
            ProgressView(value: Double(percent), total: 100)
                .tint(tint)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }

    private func traitRow(_ trait: CharacterRpgTrait) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            HStack {
                Text(trait.label)
                    .font(CYTypography.bodyMedium)
                    .foregroundStyle(CYColor.textPrimary)
                Spacer()
                Text(trait.tag)
                    .font(CYTypography.caption)
                    .foregroundStyle(CYColor.textTertiary)
            }
            if !trait.desc.isEmpty {
                Text(trait.desc)
                    .font(CYTypography.meta)
                    .foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Attribute row (read + local edit)

@available(macOS 14.0, *)
@MainActor struct CharacterAttributeRow: View {
    let attribute: CharacterCardAttribute
    let levels: [CharacterAttributeLevel]
    @Binding var draft: CharacterSheetDraft?

    private var shownValue: Int { draft?.value(for: attribute.stateKey) ?? attribute.value }

    private var levelText: String {
        levels.filter { !$0.label.isEmpty }
            .sorted { $0.at < $1.at }
            .last { shownValue >= $0.at }?.label ?? ""
    }

    private var percent: Double {
        guard attribute.max > attribute.min else { return 0 }
        let raw = Double(shownValue - attribute.min) / Double(attribute.max - attribute.min) * 100.0
        return Swift.max(0, Swift.min(100, raw))
    }

    private var showsStars: Bool {
        attribute.displayType == "stars" && attribute.min == 0 && attribute.max > 0 && attribute.max <= 10
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            HStack(spacing: CYSpacing.sm) {
                Text(attribute.label)
                    .font(CYTypography.bodyMedium)
                    .foregroundStyle(CYColor.textPrimary)
                Spacer(minLength: CYSpacing.sm)
                if !levelText.isEmpty {
                    Text(levelText)
                        .font(CYTypography.caption)
                        .foregroundStyle(CYColor.accentText)
                        .padding(.horizontal, CYSpacing.sm)
                        .padding(.vertical, CYSpacing.xxs)
                        .background(CYColor.accentSoft, in: Capsule())
                }
                if draft != nil {
                    stepper
                } else {
                    Text(String(shownValue))
                        .font(CYTypography.numericBody)
                        .foregroundStyle(CYColor.textPrimary)
                }
            }

            if attribute.displayType == "bar" {
                ProgressView(value: percent, total: 100)
                    .tint(CYColor.accent)
                    .accessibilityHidden(true)
            } else if showsStars {
                HStack(spacing: CYSpacing.xs) {
                    ForEach(0..<attribute.max, id: \.self) { index in
                        Image(systemName: index < shownValue ? "star.fill" : "star")
                            .font(CYTypography.meta)
                            .foregroundStyle(index < shownValue ? CYColor.warningText : CYColor.textPlaceholder)
                    }
                }
                .accessibilityHidden(true)
            }

            HStack {
                Text(attribute.scopeText)
                Spacer()
                Text(attribute.rangeText)
            }
            .font(CYTypography.meta)
            .foregroundStyle(CYColor.textTertiary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(attribute.label)
        .accessibilityValue("\(shownValue) / \(attribute.max)" + (levelText.isEmpty ? "" : ", \(levelText)"))
        .accessibilityAdjustableAction { direction in
            guard draft != nil else { return }
            switch direction {
            case .increment: draft?.adjust(attribute.stateKey, by: 1)
            case .decrement: draft?.adjust(attribute.stateKey, by: -1)
            @unknown default: break
            }
        }
    }

    private var stepper: some View {
        HStack(spacing: CYSpacing.xs) {
            Button {
                draft?.adjust(attribute.stateKey, by: -1)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(CYTypography.sectionTitle)
                    .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
            }
            .disabled(!(draft?.canDecrement(attribute.stateKey) ?? false))
            .accessibilityHidden(true)

            Text(String(shownValue))
                .font(CYTypography.numericBody)
                .foregroundStyle(CYColor.textPrimary)
                .frame(minWidth: 28)

            Button {
                draft?.adjust(attribute.stateKey, by: 1)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(CYTypography.sectionTitle)
                    .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
            }
            .disabled(!(draft?.canIncrement(attribute.stateKey) ?? false))
            .accessibilityHidden(true)
        }
        .foregroundStyle(CYColor.accentText)
    }
}

#if DEBUG
#Preview("Attribute row · editing") {
    let attribute = CharacterCardAttribute(
        stateKey: "str", label: "Strength", value: 3, min: 0, max: 5,
        displayType: "stars", persistScope: "topic", levels: [])
    return CharacterAttributeRow(
        attribute: attribute,
        levels: [CharacterAttributeLevel(at: 3, label: "Skilled")],
        draft: .constant(CharacterSheetDraft(attributes: [attribute])))
        .padding()
}
#endif

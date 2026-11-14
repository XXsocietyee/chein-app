import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// Rich character sheet and RPG status detail view (ported from `subpackageMember/character/index.wxml`).
@available(macOS 14.0, *)
@MainActor struct CharacterSheetDetailView: View {
    let card: CharacterCard
    var rpgSheet: CharacterRpgSheet? = nil
    var definitionSource: String? = nil
    var attributeLevels: [String: [CharacterAttributeLevel]] = [:]

    @State private var showingDice = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: CYSpacing.lg) {
                headerCard

                if !card.attributes.isEmpty {
                    CYSectionHeader("characterCard.traits")
                    CYCard {
                        VStack(alignment: .leading, spacing: CYSpacing.lg) {
                            ForEach(card.attributes) { attribute in
                                CharacterAttributeRow(
                                    attribute: attribute,
                                    levels: attributeLevels[attribute.stateKey] ?? [])
                            }
                        }
                    }
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
                    Label("characterCard.dice", systemImage: "dice")
                }
                .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
                .accessibilityIdentifier("characterSheet.diceRoller")
                .accessibilityLabel(Text("characterCard.dice"))
                .accessibilityValue(Text(verbatim: card.statusText.isEmpty ? "—" : card.statusText))
                .accessibilityHint(Text("characterCard.dice"))
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
                        .accessibilityLabel(Text(verbatim: card.heading))
                        .accessibilityValue(Text(verbatim: card.statusText.isEmpty ? "—" : card.statusText))
                        .accessibilityHint(Text(verbatim: card.definitionNote(for: definitionSource)))
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(Text(verbatim: valueText.isEmpty ? "—" : valueText))
        .accessibilityHint(label)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: trait.label.isEmpty ? "—" : trait.label))
        .accessibilityValue(Text(verbatim: trait.tag.isEmpty ? "—" : trait.tag))
        .accessibilityHint(Text(verbatim: trait.desc.isEmpty ? "—" : trait.desc))
    }
}

// MARK: - Attribute row

@available(macOS 14.0, *)
@MainActor struct CharacterAttributeRow: View {
    let attribute: CharacterCardAttribute
    let levels: [CharacterAttributeLevel]

    private var levelText: String {
        levels.filter { !$0.label.isEmpty }
            .sorted { $0.at < $1.at }
            .last { attribute.value >= $0.at }?.label ?? ""
    }

    private var percent: Double {
        guard attribute.max > attribute.min else { return 0 }
        let raw = Double(attribute.value - attribute.min) / Double(attribute.max - attribute.min) * 100.0
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
                Text(String(attribute.value))
                    .font(CYTypography.numericBody)
                    .foregroundStyle(CYColor.textPrimary)
            }

            if attribute.displayType == "bar" {
                ProgressView(value: percent, total: 100)
                    .tint(CYColor.accent)
                    .accessibilityHidden(true)
            } else if showsStars {
                HStack(spacing: CYSpacing.xs) {
                    ForEach(0..<attribute.max, id: \.self) { index in
                        Image(systemName: index < attribute.value ? "star.fill" : "star")
                            .font(CYTypography.meta)
                            .foregroundStyle(index < attribute.value ? CYColor.warningText : CYColor.textPlaceholder)
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
        .accessibilityValue("\(attribute.value) / \(attribute.max)" + (levelText.isEmpty ? "" : ", \(levelText)"))
        .accessibilityHint(Text(verbatim: levelText.isEmpty ? "—" : levelText))
    }
}

#if DEBUG
#Preview("Attribute row") {
    let attribute = CharacterCardAttribute(
        stateKey: "str", label: "Strength", value: 3, min: 0, max: 5,
        displayType: "stars", persistScope: "topic", levels: [])
    return CharacterAttributeRow(
        attribute: attribute,
        levels: [CharacterAttributeLevel(at: 3, label: "Skilled")])
        .padding()
}
#endif

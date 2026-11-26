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
    /// PLY-24-6: MP character/index.wxml:61 ends the ready card with a secondary 刷新角色卡. It uses the host's
    /// `.refreshable` action, so a host without pull-to-refresh shows no button.
    @Environment(\.refresh) private var refreshAction



    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: CYSpacing.lg) {
                headerCard

                // PLY-24-4: the MP lists attributes under the header card with no group title
                // (本局特质 is only the aspect tag there).
                if !card.attributes.isEmpty {
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

                // R7-MEM-24-2: MP character/index.wxml has no 此刻环境 or 掷骰, so neither is shown here.

                if let rpg = rpgSheet {
                    CYSectionHeader("characterCard.rpgStatus")
                    CYCard { rpgContent(rpg) }
                }

                if let refreshAction {
                    Button { Task { await refreshAction() } } label: { Text("characterCard.refresh") }
                        .buttonStyle(.cySecondary(fullWidth: true))
                        .accessibilityIdentifier("characterCard.refresh.ready")
                }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.vertical, CYSpacing.lg)
        }
        .background(CYColor.bgPage.ignoresSafeArea())
    }

    // MARK: Header

    private var headerCard: some View {
        CYCard(variant: .elevated) {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                HStack(alignment: .firstTextBaseline) {
                    // PLY-24-5: a pushed page's header card uses the card title style, not the sheet title.
                    Text(card.heading)
                        .cyText(.cardTitle)
                        .foregroundStyle(CYColor.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: CYSpacing.sm)
                    Text(card.statusText)
                        .cyText(.caption)
                        .foregroundStyle(card.running ? CYColor.successText : CYColor.textSecondary)
                        .accessibilityLabel(Text(verbatim: card.heading))
                        .accessibilityValue(Text(verbatim: card.statusText.isEmpty ? "—" : card.statusText))
                        .accessibilityHint(Text(verbatim: card.definitionNote(for: definitionSource)))
                        .padding(.horizontal, CYSpacing.sm)
                        .padding(.vertical, CYSpacing.xs)
                        .background(card.running ? CYColor.successSoft : CYColor.bgRaised, in: Capsule())
                }
                Text(card.definitionNote(for: definitionSource))
                    .cyText(.meta)
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
                meterRow(label: Text("characterCard.momentum"), valueText: "\(momentum.value) / \(momentum.max)",
                         percent: momentum.percent, tint: CYColor.rare)
            }
            ForEach(rpg.clocks) { clock in
                meterRow(label: Text(clock.label), valueText: "\(clock.value) / \(clock.segments)",
                         percent: clock.percent, tint: CYColor.brand)
            }
            ForEach(rpg.facets) { traitRow($0) }
            ForEach(rpg.aspects) { traitRow($0) }
        }
    }

    private func meterRow(label: Text, valueText: String, percent: Int, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            HStack {
                label
                    .cyText(.bodyMedium)
                    .foregroundStyle(CYColor.textPrimary)
                Spacer()
                Text(valueText)
                    .cyText(.numericBody)
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
                    .cyText(.bodyMedium)
                    .foregroundStyle(CYColor.textPrimary)
                Spacer()
                Text(trait.tag)
                    .cyText(.caption)
                    .foregroundStyle(CYColor.textTertiary)
            }
            if !trait.desc.isEmpty {
                Text(trait.desc)
                    .cyText(.meta)
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
                    .cyText(.bodyMedium)
                    .foregroundStyle(CYColor.textPrimary)
                Spacer(minLength: CYSpacing.sm)
                if !levelText.isEmpty {
                    Text(levelText)
                        .cyText(.caption)
                        .foregroundStyle(CYColor.brand)
                        .padding(.horizontal, CYSpacing.sm)
                        .padding(.vertical, CYSpacing.xxs)
                        .background(CYColor.brandSoft, in: Capsule())
                }
                Text(String(attribute.value))
                    .cyText(.numericBody)
                    .foregroundStyle(CYColor.textPrimary)
            }

            if attribute.displayType == "bar" {
                ProgressView(value: percent, total: 100)
                    .tint(CYColor.brand)
                    .accessibilityHidden(true)
            } else if showsStars {
                HStack(spacing: CYSpacing.xs) {
                    ForEach(0..<attribute.max, id: \.self) { index in
                        Image(systemName: index < attribute.value ? "star.fill" : "star")
                            .cyText(.meta)
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
            .cyText(.meta)
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

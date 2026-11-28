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



    /// NAT-11 (native-r2): an inset-grouped `List`, one `Section` per MP block (header, attributes, RPG status).
    var body: some View {
        List {
            Section { header }

            // PLY-24-4: the MP lists attributes under the header card with no group title
            // (本局特质 is only the aspect tag there).
            if !card.attributes.isEmpty {
                Section {
                    ForEach(card.attributes) { attribute in
                        CharacterAttributeRow(
                            attribute: attribute,
                            levels: attributeLevels[attribute.stateKey] ?? [])
                    }
                }
            }

            // R7-MEM-24-2: MP character/index.wxml has no 此刻环境 or 掷骰, so neither is shown here.

            if let rpg = rpgSheet {
                Section("characterCard.rpgStatus") { rpgRows(rpg) }
            }

            if let refreshAction {
                Section {
                    Button { Task { await refreshAction() } } label: { Text("characterCard.refresh") }
                        .accessibilityIdentifier("characterCard.refresh.ready")
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                // PLY-24-5: a pushed page's header uses the headline style, not the sheet title.
                Text(card.heading)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                // Native r2: the state is secondary text (green while running), not a capsule.
                Text(card.statusText)
                    .font(.subheadline)
                    .foregroundStyle(card.running ? CYColor.successText : Color.secondary)
                    .accessibilityLabel(Text(verbatim: card.heading))
                    .accessibilityValue(Text(verbatim: card.statusText.isEmpty ? "—" : card.statusText))
                    .accessibilityHint(Text(verbatim: card.definitionNote(for: definitionSource)))
            }
            Text(card.definitionNote(for: definitionSource))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: RPG status

    @ViewBuilder
    private func rpgRows(_ rpg: CharacterRpgSheet) -> some View {
        if let momentum = rpg.momentum {
            meterRow(label: Text("characterCard.momentum"), valueText: "\(momentum.value) / \(momentum.max)",
                     percent: momentum.percent)
        }
        ForEach(rpg.clocks) { clock in
            meterRow(label: Text(clock.label), valueText: "\(clock.value) / \(clock.segments)",
                     percent: clock.percent)
        }
        ForEach(rpg.facets) { traitRow($0) }
        ForEach(rpg.aspects) { traitRow($0) }
    }

    private func meterRow(label: Text, valueText: String, percent: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            LabeledContent {
                Text(valueText).monospacedDigit()
            } label: {
                label
            }
            ProgressView(value: Double(percent), total: 100)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(Text(verbatim: valueText.isEmpty ? "—" : valueText))
        .accessibilityHint(label)
    }

    private func traitRow(_ trait: CharacterRpgTrait) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            LabeledContent {
                Text(trait.tag).font(.footnote)
            } label: {
                Text(trait.label)
            }
            if !trait.desc.isEmpty {
                Text(trait.desc)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(attribute.label)
                Spacer(minLength: 8)
                // Native r2: the level is secondary text, not a tinted capsule.
                if !levelText.isEmpty {
                    Text(levelText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Text(String(attribute.value))
                    .monospacedDigit()
            }

            if attribute.displayType == "bar" {
                ProgressView(value: percent, total: 100)
                    .accessibilityHidden(true)
            } else if showsStars {
                HStack(spacing: 4) {
                    ForEach(0..<attribute.max, id: \.self) { index in
                        Image(systemName: index < attribute.value ? "star.fill" : "star")
                            .font(.footnote)
                            .foregroundStyle(index < attribute.value ? CYColor.ratingStar : Color.secondary)
                    }
                }
                .accessibilityHidden(true)
            }

            HStack {
                Text(attribute.scopeText)
                Spacer()
                Text(attribute.rangeText)
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(attribute.label)
        .accessibilityValue(Text("a11y.value.ofTotal \(attribute.value) \(attribute.max)") + Text(verbatim: levelText.isEmpty ? "" : ", \(levelText)"))
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

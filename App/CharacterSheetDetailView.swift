import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// Rich character sheet and RPG status detail view (ported from `subpackageMember/character/index.wxml`).
@available(macOS 14.0, *)
@MainActor struct CharacterSheetDetailView: View {
    @Environment(\.locale) private var locale
    let card: CharacterCard
    var rpgSheet: CharacterRpgSheet? = nil
    var definitionSource: String? = nil
    var attributeLevels: [String: [CharacterAttributeLevel]] = [:]

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(card.heading)
                            .font(.headline)
                        Spacer()
                        Text(card.statusText)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(card.running ? Color.green.opacity(0.15) : Color.secondary.opacity(0.12), in: Capsule())
                    }
                    Text(card.definitionNote(for: definitionSource))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            if !card.attributes.isEmpty {
                Section("characterCard.traits") {
                    ForEach(card.attributes) { attribute in
                        let lvlLabel = attribute.levelLabel(levels: attributeLevels[attribute.stateKey] ?? [])
                        VStack(alignment: .leading, spacing: 6) {
                            LabeledContent(attribute.label) {
                                HStack(spacing: 6) {
                                    Text(String(attribute.value))
                                        .font(.body.monospacedDigit().weight(.semibold))
                                    if !lvlLabel.isEmpty {
                                        Text(lvlLabel)
                                            .font(.caption2.weight(.medium))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.accentColor.opacity(0.14), in: Capsule())
                                    }
                                }
                            }
                            if attribute.displayType == "bar" {
                                ProgressView(value: Double(attribute.percent), total: 100)
                                    .tint(.accentColor)
                            } else if !attribute.stars.isEmpty {
                                HStack(spacing: 4) {
                                    ForEach(attribute.stars) { pip in
                                        Image(systemName: pip.filled ? "star.fill" : "star")
                                            .font(.caption)
                                            .foregroundStyle(pip.filled ? Color.yellow : Color.secondary.opacity(0.4))
                                    }
                                }
                                .accessibilityLabel("\(attribute.value) / \(attribute.max)")
                            }
                            HStack {
                                Text(attribute.scopeText)
                                Spacer()
                                Text(attribute.rangeText)
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            if let rpg = rpgSheet {
                Section(String(localized: LocalizedStringResource("characterCard.rpgStatus", defaultValue: "本局状态", locale: locale))) {
                    if let momentum = rpg.momentum {
                        VStack(alignment: .leading, spacing: 4) {
                            LabeledContent(String(localized: LocalizedStringResource("characterCard.momentum", defaultValue: "势头", locale: locale)), value: "\(momentum.value)/\(momentum.max)")
                            ProgressView(value: Double(momentum.percent), total: 100)
                                .tint(.orange)
                        }
                    }
                    ForEach(rpg.clocks) { clock in
                        VStack(alignment: .leading, spacing: 4) {
                            LabeledContent(clock.label, value: "\(clock.value)/\(clock.segments)")
                            ProgressView(value: Double(clock.percent), total: 100)
                                .tint(.purple)
                        }
                    }
                    ForEach(rpg.facets) { facet in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(facet.label).font(.subheadline.weight(.medium))
                                Spacer()
                                Text(facet.tag).font(.caption2).foregroundStyle(.secondary)
                            }
                            if !facet.desc.isEmpty {
                                Text(facet.desc).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    ForEach(rpg.aspects) { aspect in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(aspect.label).font(.subheadline.weight(.medium))
                                Spacer()
                                Text(aspect.tag).font(.caption2).foregroundStyle(.secondary)
                            }
                            if !aspect.desc.isEmpty {
                                Text(aspect.desc).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }
}

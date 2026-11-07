import SwiftUI

/// Leaves the card retired when the page goes away. A late read cannot refill it.
@available(macOS 14.0, *)
@MainActor struct CharacterCardReadbackView: View {
    @ObservedObject var session: AppSession
    let model: CharacterCardReadback
    var body: some View {
        let _ = session.account?.id
        let card = model.cardIfCurrent()
        // Mini-program subpackageMember/character: 我的角色卡 with the run's traits; states are user words, never raw availability codes.
        Group {
            if model.isCurrent, model.availability == .unknown {
                ContentUnavailableView {
                    Label("characterCard.unavailable", systemImage: "person.text.rectangle")
                } actions: {
                    Button("characterCard.refresh") { Task { await model.load() } }
                }
            } else if model.isCurrent, let card {
                if card.attributes.isEmpty && card.rpgSheet == nil {
                    ContentUnavailableView("characterCard.empty", systemImage: "person.text.rectangle")
                } else {
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
                                Text(card.definitionNote)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }

                        if !card.attributes.isEmpty {
                            Section("characterCard.traits") {
                                ForEach(card.attributes) { attribute in
                                    VStack(alignment: .leading, spacing: 6) {
                                        LabeledContent(attribute.label) {
                                            HStack(spacing: 6) {
                                                Text(String(attribute.value))
                                                    .font(.body.monospacedDigit().weight(.semibold))
                                                if !attribute.levelLabel.isEmpty {
                                                    Text(attribute.levelLabel)
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

                        if let rpg = card.rpgSheet {
                            Section(String(localized: "characterCard.rpgStatus", defaultValue: "本局状态")) {
                                if let momentum = rpg.momentum {
                                    VStack(alignment: .leading, spacing: 4) {
                                        LabeledContent(String(localized: "characterCard.momentum", defaultValue: "势头"), value: "\(momentum.value)/\(momentum.max)")
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

                        if card.equipment.availability == .ready, !card.equipment.items.isEmpty {
                            Section(String(localized: "characterCard.equipment", defaultValue: "随身装备")) {
                                ForEach(card.equipment.items, id: \.id) { item in
                                    LabeledContent(item.id, value: "×\(item.quantity)")
                                }
                            }
                        }

                        if card.party.availability == .ready, !card.party.members.isEmpty {
                            Section(String(localized: "characterCard.party", defaultValue: "同行队友")) {
                                ForEach(card.party.members, id: \.id) { member in
                                    LabeledContent(member.displayName, value: member.roleCode ?? "")
                                }
                            }
                        }

                        if card.breakdown.availability == .ready, let total = card.breakdown.total {
                            Section(String(localized: "characterCard.lastCheck", defaultValue: "最近检定")) {
                                LabeledContent(String(localized: "characterCard.checkTotal", defaultValue: "合计点数"), value: String(total))
                                if let dc = card.breakdown.dc {
                                    LabeledContent("DC", value: String(dc))
                                }
                                if let die = card.breakdown.die {
                                    LabeledContent(String(localized: "characterCard.checkDie", defaultValue: "骰面"), value: String(die))
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .refreshable { await model.load() }
                }
            } else {
                ProgressView("characterCard.loading")
            }
        }
        .appNavigationTitle("characterCard.title")
        .task { await model.load() }
        .onDisappear { model.dismiss() }
    }
}

import SwiftUI

/// Attributes v2 on the viewer's own profile (CITY-MONOPOLY-SPEC §3.5–§3.6): archetype, equipped
/// title, the six attributes with level / AXP progress / today's AXP, and title equip.
/// Functional wiring only with existing components; the radar page is a later design task.
@MainActor struct MemberAttributesSection: View {
    @StateObject private var model: MemberAttributesModel
    @Environment(\.locale) private var locale
    @QuestifyReduceMotion private var reduceMotion

    init(service: any CityMonopolyReading) {
        _model = StateObject(wrappedValue: MemberAttributesModel(service: service))
    }

    private var chinese: Bool { ChannelCopy.isChinese(locale) }
    private func copy(_ zh: String, _ en: String) -> String { ChannelCopy.text(zh, en, locale: locale) }

    var body: some View {
        Section {
            if let attributes = model.attributes {
                LabeledContent {
                    Text(verbatim: attributes.archetype?.display(chinese: chinese) ?? "—")
                } label: {
                    Text(verbatim: copy("原型", "Archetype"))
                }
                LabeledContent {
                    Text(verbatim: attributes.equippedTitle?.display(chinese: chinese) ?? copy("未佩戴", "None"))
                } label: {
                    Text(verbatim: copy("称号", "Title"))
                }
                ForEach(attributes.orderedAttrs) { row in
                    attributeRow(row, seasonDelta: attributes.seasonDelta?[row.key])
                }
                titlesRows
            } else if model.loading {
                CYSkeleton()
            }
            if let issue = model.issueCode {
                CYNoteBanner(text: Text(verbatim: copy("六维暂不可用：", "Attributes unavailable: ") + issue), symbol: "exclamationmark.triangle", tone: .warning)
            }
            CYPillButton(verbatim: copy("刷新六维", "Refresh attributes"), style: .tertiary, systemImage: "arrow.clockwise", fullWidth: false) {
                Task { await model.load() }
            }
            .disabled(model.loading)
        } header: {
            Text(verbatim: copy("城瘾六维", "Six attributes"))
        }
        .task { await model.load() }
        .cityMonopolyHaptics(model.haptic, reduceMotion: reduceMotion)
    }

    @ViewBuilder private func attributeRow(_ row: MemberAttributeRow, seasonDelta: Double?) -> some View {
        let name = row.attribute?.name(chinese: chinese) ?? row.key
        let progress = row.levelProgress
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            LabeledContent {
                Text(verbatim: "Lv\(row.level)" + (seasonDelta.map { $0 > 0 ? copy("（本赛季 +\(Int($0))）", " (+\(Int($0)) this season)") : "" } ?? ""))
            } label: {
                Text(verbatim: name)
            }
            if let progress {
                CYProgressBar(title: copy("AXP 进度", "AXP progress"), completed: Int(progress.current), total: Int(progress.need))
            }
            if let today = row.todayAxp {
                let cap = row.softCap ?? Int64(row.attribute?.dailySoftCap ?? 0)
                CYFactRow(label: Text(verbatim: copy("今日 AXP / 软上限", "Today AXP / soft cap")), value: "\(today) / \(cap)")
            }
            if let unlock = row.nextUnlock {
                CYFactRow(label: Text(verbatim: copy("下一个解锁", "Next unlock")),
                          value: (unlock.level.map { "Lv\($0) " } ?? "") + unlock.display(chinese: chinese))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: accessibilityText(name: name, row: row)))
    }

    /// e.g. "探索 23 级，距 24 级还差 410".
    private func accessibilityText(name: String, row: MemberAttributeRow) -> String {
        guard let remaining = row.remainingToNextLevel else {
            return copy("\(name) \(row.level) 级", "\(name) level \(row.level)")
        }
        return copy("\(name) \(row.level) 级，距 \(row.level + 1) 级还差 \(remaining)",
                    "\(name) level \(row.level), \(remaining) AXP to level \(row.level + 1)")
    }

    @ViewBuilder private var titlesRows: some View {
        let equippedCode = model.attributes?.equippedTitle?.code
        ForEach(model.titles) { title in
            let equipped = title.equipped ?? (title.code == equippedCode)
            HStack(spacing: CYSpacing.sm) {
                Text(verbatim: title.display(chinese: chinese))
                Spacer(minLength: CYSpacing.sm)
                if equipped {
                    CYPillButton(verbatim: copy("卸下", "Unequip"), style: .tertiary, fullWidth: false) {
                        Task { await model.equip(titleCode: nil) }
                    }
                    .disabled(model.loading)
                } else {
                    CYPillButton(verbatim: copy("佩戴", "Equip"), style: .secondary, fullWidth: false) {
                        Task { await model.equip(titleCode: title.code) }
                    }
                    .disabled(model.loading)
                }
            }
        }
    }
}

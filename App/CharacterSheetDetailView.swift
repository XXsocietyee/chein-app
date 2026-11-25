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

    @Environment(\.locale) private var locale
    @State private var showingDice = false

    private var copy: CoreLoopCopy { CoreLoopCopy(locale: locale) }

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

                if card.environment.availability != .waitingSource {
                    CYSectionHeader(verbatim: copy.t("此刻环境", "Environment"))
                    CYCard { environmentContent(card.environment) }
                }

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
            }
        }
        .sheet(isPresented: $showingDice) { DiceRollerSheet() }
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

    // MARK: Environment

    @ViewBuilder
    private func environmentContent(_ env: WorldEnvironmentProjection) -> some View {
        let items = WorldEnvironmentProjection.keys.compactMap { key -> (key: String, label: String, icon: String, isUnknown: Bool)? in
            guard let val = env[key] else { return nil }
            let isUnknown: Bool
            let text: String
            switch val {
            case .known(let raw):
                isUnknown = false
                text = localizedEnvironmentText(key: key, value: raw)
            case .unknown:
                isUnknown = true
                text = copy.t("未知", "Unknown")
            }
            return (key, "\(environmentKeyName(key))：\(text)", environmentIcon(key: key, value: val), isUnknown)
        }
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            if !items.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: CYSpacing.xs, alignment: .leading)], alignment: .leading, spacing: CYSpacing.xs) {
                    ForEach(items, id: \.key) { item in
                        CYStatusChip(
                            verbatim: item.label,
                            tone: item.isUnknown ? .warning : .info,
                            systemImage: item.icon
                        )
                        .accessibilityIdentifier("characterSheet.environment.\(item.key)")
                    }
                }
            }
            if env.availability == .unknown || env.weather == .unknown {
                CYStatusChip(
                    verbatim: copy.t("天色未明，先凭直觉探路", "Sky unclear — rely on your instincts"),
                    tone: .warning,
                    systemImage: "cloud.slash"
                )
                .accessibilityIdentifier("characterSheet.environment.unknown")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("characterSheet.environment")
    }

    private func environmentKeyName(_ key: String) -> String {
        switch key {
        case "weather": return copy.t("天气", "Weather")
        case "daypart": return copy.t("时段", "Time")
        case "weekpart": return copy.t("周历", "Week")
        case "season": return copy.t("季节", "Season")
        default: return key
        }
    }

    private func localizedEnvironmentText(key: String, value: String) -> String {
        switch value {
        case "clear": return copy.t("晴", "Clear")
        case "cloudy": return copy.t("多云", "Cloudy")
        case "rain": return copy.t("雨", "Rain")
        case "snow": return copy.t("雪", "Snow")
        case "fog": return copy.t("雾霾", "Fog")
        case "wind": return copy.t("风", "Wind")
        case "storm": return copy.t("雷暴", "Storm")
        case "dawn": return copy.t("清晨", "Dawn")
        case "morning": return copy.t("上午", "Morning")
        case "afternoon": return copy.t("午后", "Afternoon")
        case "evening": return copy.t("傍晚", "Evening")
        case "night": return copy.t("夜晚", "Night")
        case "weekday": return copy.t("工作日", "Weekday")
        case "weekend": return copy.t("周末", "Weekend")
        case "spring": return copy.t("春", "Spring")
        case "summer": return copy.t("夏", "Summer")
        case "autumn": return copy.t("秋", "Autumn")
        case "winter": return copy.t("冬", "Winter")
        default: return value
        }
    }

    private func environmentIcon(key: String, value: WorldEnvironmentProjection.Value) -> String {
        if case .unknown = value { return "cloud.slash" }
        switch key {
        case "weather":
            switch value.text {
            case "clear": return "sun.max.fill"
            case "cloudy": return "cloud.fill"
            case "rain": return "cloud.rain.fill"
            case "snow": return "cloud.snow.fill"
            case "fog": return "cloud.fog.fill"
            case "wind": return "wind"
            case "storm": return "cloud.bolt.rain.fill"
            default: return "cloud"
            }
        case "daypart": return "clock"
        case "weekpart": return "calendar"
        case "season": return "leaf"
        default: return "sparkles"
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

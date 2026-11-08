import SwiftUI

/// Mini-program `pages/topic/index` sections layered onto the existing topic detail list.
enum TopicXcxTab: Int, CaseIterable, Identifiable {
    case details, nodes, route
    var id: Int { rawValue }
    var titleKey: LocalizedStringKey { switch self { case .details: return "topicXcx.tab.details"; case .nodes: return "topicXcx.tab.nodes"; case .route: return "topicXcx.tab.route" } }
    var anchor: String { "topicXcx.anchor.\(rawValue)" }
}

/// Mini-program 详情 / 故事 / 路线 tabs as a native segmented control; it jumps to that part of the page
/// so every existing row stays reachable.
struct TopicXcxTabs: View {
    let proxy: ScrollViewProxy
    @State private var selection: TopicXcxTab = .details
    var body: some View {
        Picker("topicXcx.tabs", selection: $selection) {
            ForEach(TopicXcxTab.allCases) { tab in Text(tab.titleKey).tag(tab) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .accessibilityIdentifier("topic.tabs")
        .onChange(of: selection) { _, tab in withAnimation { proxy.scrollTo(tab.anchor, anchor: .top) } }
    }
}

struct TopicXcxHero: View {
    let topic: TopicDetail
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(topic.productType == 2 ? "topicXcx.type.explore" : "topicXcx.type.orienteering").font(CYTypography.label).foregroundStyle(CYColor.accentText)
            if !topic.categoryNames.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: CYSpacing.sm) { ForEach(topic.categoryNames, id: \.self) { Text(verbatim: $0).font(CYTypography.caption).foregroundStyle(CYColor.textSecondary).padding(.horizontal, CYSpacing.sm).padding(.vertical, CYSpacing.xs).background(Capsule().fill(CYColor.bgSurfaceSubtle)) } }
                }
            }
            if let club = topic.clubName { Label { Text("topicXcx.clubHost \(club)") } icon: { Image(systemName: "person.3") }.font(CYTypography.bodyCompact).foregroundStyle(CYColor.textSecondary) }
        }
    }
}

struct TopicXcxStatBar: View {
    let cells: [TopicXcxFacts.StatCell]
    var body: some View {
        if !cells.isEmpty {
            // Mini-program `statbar`: horizontal strip, hairline between cells, each "label / big number / unit".
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: CYSpacing.lg) {
                    ForEach(Array(cells.enumerated()), id: \.offset) { index, cell in
                        if index > 0 { Rectangle().fill(CYColor.borderSubtle).frame(width: 1).frame(maxHeight: .infinity) }
                        VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                            switch cell {
                            case .rating(let value, let stars):
                                label("topicXcx.stat.rating"); number(String(format: "%.1f", value))
                                HStack(spacing: 1) { ForEach(0..<stars, id: \.self) { _ in Image(systemName: "star.fill").font(.caption2).foregroundStyle(CYColor.accentWarm) } }.accessibilityHidden(true)
                            case .hours(let text):
                                label("topicXcx.stat.hours"); number(text); unit("topicXcx.stat.hoursUnit")
                            case .open(let start, let end):
                                label("topicXcx.stat.open"); number(start + "-" + end)
                            case .mileage(let text):
                                label("topicXcx.stat.mileage"); number(text); unit("topicXcx.stat.mileageUnit")
                            case .merchants(let count):
                                label("topicXcx.stat.merchants"); number(String(count)); unit("topicXcx.stat.merchantsUnit")
                            }
                        }.accessibilityElement(children: .combine)
                    }
                }.fixedSize(horizontal: false, vertical: true).padding(.vertical, CYSpacing.xs)
            }.accessibilityIdentifier("topic.statBar")
        }
    }
    private func label(_ key: LocalizedStringKey) -> some View { Text(key).font(CYTypography.micro).foregroundStyle(CYColor.textTertiary) }
    private func number(_ text: String) -> some View { Text(verbatim: text).font(CYTypography.numericBody).monospacedDigit().foregroundStyle(CYColor.textPrimary) }
    private func unit(_ key: LocalizedStringKey) -> some View { Text(key).font(CYTypography.micro).foregroundStyle(CYColor.textTertiary) }
}

struct TopicXcxDurationText: View {
    let seconds: Int?
    var body: some View {
        switch TopicXcxFacts.duration(seconds: seconds) {
        case .zero: Text("topicXcx.duration.zero")
        case .underMinute: Text("topicXcx.duration.underMinute")
        case .minutes(let m): Text("topicXcx.duration.minutes \(m)")
        case .hours(let h): Text("topicXcx.duration.hours \(h)")
        case .hoursMinutes(let h, let m): Text("topicXcx.duration.hoursMinutes \(h) \(m)")
        }
    }
}

struct TopicXcxIncludes: View {
    let rows: [TopicXcxFacts.Include]
    var body: some View {
        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
            switch row {
            case .chapters(let n): Label { Text("topicXcx.include.chapters \(n)") } icon: { Image(systemName: "book") }
            case .stops(let n): Label { Text("topicXcx.include.stops \(n)") } icon: { Image(systemName: "mappin.and.ellipse") }
            case .plays(let n): Label { Text("topicXcx.include.plays \(n)") } icon: { Image(systemName: "gamecontroller") }
            case .audioMinutes(let n): Label { Text("topicXcx.include.audioMinutes \(n)") } icon: { Image(systemName: "headphones") }
            case .audio: Label("topicXcx.include.audio", systemImage: "headphones")
            case .medal(let name?): Label { Text("topicXcx.include.medal \(name)") } icon: { Image(systemName: "medal") }
            case .medal(nil): Label("topicXcx.include.medalFallback", systemImage: "medal")
            case .coupon: Label("topicXcx.include.coupon", systemImage: "ticket")
            }
        }
    }
}

struct TopicXcxLineup: View {
    let members: [TopicXcxFacts.LineupMember]
    var body: some View {
        // Mini-program `lineup-row`: horizontal scroll of avatar / name / role cards.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: CYSpacing.md) {
                ForEach(Array(members.enumerated()), id: \.offset) { _, member in
                    VStack(spacing: CYSpacing.xs) {
                        CYAvatarView(name: member.name, size: .lg)
                        Text(verbatim: member.name).font(CYTypography.label).foregroundStyle(CYColor.textPrimary).lineLimit(1)
                        Text(member.kind == .club ? "topicXcx.lineup.club" : "topicXcx.lineup.merchant").font(CYTypography.micro).foregroundStyle(CYColor.textTertiary)
                    }.frame(width: 88).accessibilityElement(children: .combine)
                }
            }
        }
    }
}

/// Source bottom bar. Purchase/sign-up keep their existing flows; nothing here dispatches a write.
struct TopicXcxActionBar: View {
    let topic: TopicDetail
    var openSessions: () -> Void
    var openSelfPlay: () -> Void
    var openPricing: (() -> Void)?
    var body: some View {
        VStack(spacing: 6) {
            if topic.merchantClosed && !topic.isSignUp { Text("topicXcx.merchantClosed").font(CYTypography.meta).foregroundStyle(CYColor.warningText) }
            HStack {
                switch TopicXcxFacts.action(topic) {
                case .ticketWallet:
                    Label("topicXcx.cta.ticketWallet", systemImage: "ticket").frame(maxWidth: .infinity)
                case .locked(let lifecycle):
                    if TopicXcxFacts.opensPricing(topic), let openPricing {
                        Button(action: openPricing) { Text("topicXcx.cta.confirmPrice").frame(maxWidth: .infinity) }.buttonStyle(.cyPrimary)
                            .accessibilityIdentifier("topic.cta.pricing")
                    } else {
                        Text(LocalizedStringKey("topicXcx.cta.locked." + String(lifecycle))).frame(maxWidth: .infinity).foregroundStyle(CYColor.textSecondary)
                    }
                case .selfPlay(let price):
                    Button(action: openSessions) { Text("topicXcx.cta.sessions").frame(maxWidth: .infinity) }.buttonStyle(.cySecondary)
                    Button(action: openSelfPlay) {
                        if let price { Text("topicXcx.cta.selfPlay \(NSDecimalNumber(decimal: price).stringValue)").frame(maxWidth: .infinity) }
                        else { Text("topicXcx.cta.selfPlayNoPrice").frame(maxWidth: .infinity) }
                    }.buttonStyle(.cyPrimary).disabled(!topic.canOfferPurchase)
                case .signUp:
                    Button(action: openSessions) { Text("topicXcx.cta.signUp").frame(maxWidth: .infinity) }.buttonStyle(.cyPrimary)
                        .disabled(topic.merchantClosed)
                }
            }
            .controlSize(.large)
            .accessibilityIdentifier("topic.actionBar")
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Theme.Space.pageX)
        .padding(.vertical, Theme.Space.s2)
        .background(CYColor.bgElevated)
    }
}

private struct TopicPricingDestinationKey: EnvironmentKey { static let defaultValue: ((Int) -> AnyView)? = nil }
extension EnvironmentValues {
    /// Owner-only final-price page (source `pages/topic/pricing`); nil hides the entry.
    var topicPricingDestination: ((Int) -> AnyView)? {
        get { self[TopicPricingDestinationKey.self] }
        set { self[TopicPricingDestinationKey.self] = newValue }
    }
}

/// Source tab "路线": every stop in order with its walking estimate.
struct TopicXcxRouteSection: View {
    let topic: TopicDetail
    var body: some View {
        Section("topicXcx.tab.route") {
            if topic.chapters.allSatisfy({ $0.nodes.isEmpty }) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("topicXcx.route.emptyTitle").foregroundStyle(.secondary)
                }.accessibilityIdentifier("topic.route.empty")
            }
            ForEach(Array(topic.chapters.enumerated()), id: \.offset) { _, chapter in
                if !chapter.nodes.isEmpty { Text(verbatim: chapter.title).font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary) }
                ForEach(TopicChapterItinerary(chapter: chapter).stops) { stop in
                    VStack(alignment: .leading, spacing: 2) {
                        if let minutes = stop.estimatedWalkingMinutes { Text("topicXcx.route.walk \(minutes)").font(.caption2).foregroundStyle(.secondary) }
                        HStack(alignment: .top) {
                            Text(verbatim: String(stop.id + 1)).font(CYTypography.label).monospacedDigit().frame(width: 28, height: 28).foregroundStyle(CYColor.accentText).background(Circle().fill(CYColor.accentSoft))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: stop.node.name)
                                if let hours = stop.node.businessTime { Text(verbatim: hours).font(.caption) }
                                if let address = stop.node.address { Label { Text(verbatim: address).lineLimit(1) } icon: { Image(systemName: "mappin") }.font(.caption) }
                            }
                        }
                    }
                }
            }
        }
    }
}

/// Source session chip: `周X M.D HH:mm` (time omitted at 00:00).
struct TopicXcxSessionChip: View {
    let startDate: String?
    var body: some View {
        if let chip = TopicXcxFacts.sessionChip(startDate) {
            HStack(spacing: 4) {
                Text(LocalizedStringKey("topicXcx.weekday." + String(chip.weekday)))
                Text(verbatim: chip.monthDay)
                if let time = chip.time { Text(verbatim: time) }
            }.font(.caption.bold()).accessibilityElement(children: .combine).accessibilityIdentifier("topic.sessionChip")
        }
    }
}

/// Source 节点介绍: horizontal template cards (title, players, minutes). Images stay behind the gated gallery.
struct TopicXcxTemplatesSection: View {
    let templates: [TopicTemplate]
    var body: some View {
        if !templates.isEmpty {
            Section("topicXcx.section.nodeIntro") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(templates, id: \.id) { template in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(verbatim: template.title).font(CYTypography.label).foregroundStyle(CYColor.textPrimary).lineLimit(1)
                                if let players = template.players { Text(verbatim: players).font(CYTypography.caption).foregroundStyle(CYColor.textSecondary) }
                                Text("topicXcx.templateMinutes \(TopicXcxFacts.templateMinutes(template))").font(CYTypography.caption).monospacedDigit().foregroundStyle(CYColor.textTertiary)
                            }.frame(width: 140, alignment: .leading).padding(10)
                                .background(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous).fill(CYColor.bgElevated))
                                .accessibilityElement(children: .combine).accessibilityIdentifier("topic.nodeIntro.\(template.id)")
                        }
                    }
                }
            }
        }
    }
}

/// Source node card foot: `{商家}（{节点}）` plus `等 N 家`.
struct TopicXcxNodeFootView: View {
    let node: TopicNode
    var body: some View {
        let foot = TopicXcxFacts.nodeFoot(node)
        if let merchant = foot.merchant {
            HStack(spacing: 4) {
                Text(verbatim: merchant + "（" + foot.node + "）").font(.subheadline)
                if foot.merchantCount > 1 { Text("topicXcx.moreMerchants \(foot.merchantCount)").font(.caption).foregroundStyle(.secondary) }
            }.accessibilityIdentifier("topic.nodeFoot")
        }
    }
}

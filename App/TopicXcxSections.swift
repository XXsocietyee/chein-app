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
    @Environment(\.cyPalette) private var palette
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s2) {
            Text(topic.productType == 2 ? "topicXcx.type.explore" : "topicXcx.type.orienteering").font(Theme.Font.label.weight(.semibold)).foregroundStyle(.secondary)
            if !topic.categoryNames.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Space.s2) { ForEach(topic.categoryNames, id: \.self) { Text(verbatim: $0).font(Theme.Font.label).lineLimit(1).padding(.horizontal, Theme.Space.s2).padding(.vertical, Theme.Space.s1).background(palette.bgRaised, in: RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)) } }
                }
            }
            if let club = topic.clubName { Label { Text("topicXcx.clubHost \(club)") } icon: { Image(systemName: "person.3") }.font(.subheadline).foregroundStyle(.secondary) }
        }
    }
}

struct TopicXcxStatBar: View {
    let cells: [TopicXcxFacts.StatCell]
    @Environment(\.cyPalette) private var palette
    var body: some View {
        if !cells.isEmpty {
            // Mini-program `statbar`: horizontal strip, hairline between cells, each "label / big number / unit".
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Space.s5) {
                    ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                        VStack(alignment: .leading, spacing: 2) {
                            switch cell {
                            case .rating(let value, let stars):
                                Text("topicXcx.stat.rating").font(Theme.Font.label).foregroundStyle(.secondary)
                                Text(verbatim: String(format: "%.1f", value)).font(.headline.monospacedDigit())
                                HStack(spacing: 1) { ForEach(0..<stars, id: \.self) { _ in Image(systemName: "star.fill").font(.caption2) } }.accessibilityHidden(true)
                            case .hours(let text):
                                Text("topicXcx.stat.hours").font(Theme.Font.label).foregroundStyle(.secondary)
                                Text(verbatim: text).font(.headline.monospacedDigit()); Text("topicXcx.stat.hoursUnit").font(Theme.Font.label).foregroundStyle(.secondary)
                            case .open(let start, let end):
                                Text("topicXcx.stat.open").font(Theme.Font.label).foregroundStyle(.secondary)
                                Text(verbatim: start + "-" + end).font(.headline.monospacedDigit())
                            case .mileage(let text):
                                Text("topicXcx.stat.mileage").font(Theme.Font.label).foregroundStyle(.secondary)
                                Text(verbatim: text).font(.headline.monospacedDigit()); Text("topicXcx.stat.mileageUnit").font(Theme.Font.label).foregroundStyle(.secondary)
                            case .merchants(let count):
                                Text("topicXcx.stat.merchants").font(Theme.Font.label).foregroundStyle(.secondary)
                                Text(verbatim: String(count)).font(.headline.monospacedDigit()); Text("topicXcx.stat.merchantsUnit").font(Theme.Font.label).foregroundStyle(.secondary)
                            }
                        }.accessibilityElement(children: .combine)
                    }
                }
                .padding(Theme.Space.s4)
            }
            .background(palette.bgElevated, in: RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
            .accessibilityIdentifier("topic.statBar")
        }
    }
    private func label(_ key: LocalizedStringKey) -> some View { Text(key).font(CYTypography.micro).foregroundStyle(CYColor.textTertiary) }
    private func number(_ text: String) -> some View { Text(verbatim: text).font(CYTypography.numericBody).monospacedDigit().foregroundStyle(CYColor.textPrimary) }
    private func unit(_ key: LocalizedStringKey) -> some View { Text(key).font(CYTypography.micro).foregroundStyle(CYColor.textTertiary) }
}

struct TopicXcxDurationText: View {
    let seconds: Int?
    var body: some View {
        // pages/topic/index: a missing duration is an em dash, never "0 h". A literal 0 keeps the zero copy.
        if let seconds, seconds >= 0 { known(seconds) } else { Text(verbatim: "—") }
    }
    @ViewBuilder private func known(_ seconds: Int) -> some View {
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
    @Environment(\.cyPalette) private var palette
    let topic: TopicDetail
    var openSessions: () -> Void
    var openSelfPlay: () -> Void
    var openPricing: (() -> Void)?
    var body: some View {
        VStack(spacing: 6) {
            if topic.merchantClosed && !topic.isSignUp { Text("topicXcx.merchantClosed").font(.footnote).foregroundStyle(palette.warning) }
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
                    Button(action: openSessions) { Text("topicXcx.cta.sessions").frame(maxWidth: .infinity) }.buttonStyle(.bordered).frame(minHeight: 44)
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
        .padding(.vertical, Theme.Space.s2_5)
        .background(.bar)
        .overlay(alignment: .top) { Rectangle().fill(palette.borderSubtle).frame(height: 0.5) }
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
    @Environment(\.cyPalette) private var palette
    let topic: TopicDetail
    var body: some View {
        Section("topicXcx.tab.route") {
            // Source `route-note`: 固定路线 for city orienteering, 没有固定路线 for free explore.
            Text(topic.productType == 2 ? "u9cde.topic.routeNote.free" : "u9cde.topic.routeNote.fixed")
                .font(CYTypography.label.weight(.semibold))
                .foregroundStyle(topic.productType == 2 ? CYColor.textSecondary : CYNight.ink0)
                .padding(.horizontal, CYSpacing.sm).padding(.vertical, CYSpacing.xxs)
                .background(Capsule().fill(topic.productType == 2 ? CYNight.glassFill : CYNight.lantern))
                .accessibilityIdentifier("topic.route.note")
            if topic.chapters.allSatisfy({ $0.nodes.isEmpty }) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("u9cde.topic.routeConfiguring").font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary)
                    Text("topicXcx.route.emptyTitle").foregroundStyle(.secondary)
                }.accessibilityIdentifier("topic.route.empty")
            }
            ForEach(Array(topic.chapters.enumerated()), id: \.offset) { _, chapter in
                if !chapter.nodes.isEmpty { Text(verbatim: chapter.title).font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary) }
                ForEach(TopicChapterItinerary(chapter: chapter).stops) { stop in
                    VStack(alignment: .leading, spacing: 2) {
                        if let minutes = stop.estimatedWalkingMinutes { Text("topicXcx.route.walk \(minutes)").font(Theme.Font.label).foregroundStyle(.secondary) }
                        HStack(alignment: .top) {
                            Text(verbatim: String(stop.id + 1)).font(Theme.Font.label.weight(.bold).monospacedDigit()).frame(minWidth: 24, minHeight: 24).background(Circle().fill(palette.bgRaised)).accessibilityHidden(true)
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
            }.font(Theme.Font.label.weight(.semibold).monospacedDigit()).accessibilityElement(children: .combine).accessibilityIdentifier("topic.sessionChip")
        }
    }
}

/// Source 节点介绍: horizontal template cards (title, players, minutes). Images stay behind the gated gallery.
struct TopicXcxTemplatesSection: View {
    @Environment(\.cyPalette) private var palette
    let templates: [TopicTemplate]
    var body: some View {
        if !templates.isEmpty {
            Section("topicXcx.section.nodeIntro") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(templates, id: \.id) { template in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(verbatim: template.title).font(.subheadline.bold()).lineLimit(1)
                                if let players = template.players { Text(verbatim: players).font(.caption) }
                                Text("topicXcx.templateMinutes \(TopicXcxFacts.templateMinutes(template))").font(.caption).foregroundStyle(.secondary)
                            }.frame(width: 140, alignment: .leading).padding(Theme.Space.s3)
                                .background(palette.bgElevated, in: RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
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

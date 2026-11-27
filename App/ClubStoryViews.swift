import SwiftUI

/// No default destination, session or read grant. Normal composition supplies the
/// existing personal-template reader, never the owned shelf or public library.
struct ClubStoryTemplateContext {
    var viewerRevision: UInt64 = 0
    var reader: (any MemberTemplateReading)? = nil
    var destination: ((MemberPlayTemplateID) -> AnyView)? = nil
    var imageReader: (any RetainedPublicImageReading)? = nil
    @MainActor var readerIdentity: ObjectIdentifier? { reader.map { ObjectIdentifier($0) } }
    @MainActor var readerScope: UUID? { reader?.scope }
    @MainActor var isAvailable: Bool {
        destination != nil && reader?.isAuthenticated == true && reader?.isConfigured == true
    }
}
private struct ClubStoryTemplateKey: EnvironmentKey {
    static let defaultValue = ClubStoryTemplateContext()
}
extension EnvironmentValues {
    var clubStoryTemplates: ClubStoryTemplateContext {
        get { self[ClubStoryTemplateKey.self] }
        set { self[ClubStoryTemplateKey.self] = newValue }
    }
}
@MainActor extension AppSession {
    func clubStoryTemplateContext(viewerRevision: UInt64) -> ClubStoryTemplateContext {
        .init(viewerRevision: viewerRevision, reader: playerJourneyReader, destination: { [weak self] id in
            guard let self else { return AnyView(Text("club.story.templateUnavailable")) }
            return AnyView(SessionMemberTemplateDetailView(id: id).environmentObject(self))
        })
    }
}

enum ClubStoryTab: Hashable { case route, play }
struct ClubStorySourceRevision: Equatable {
    let snapshot: ClubGovernanceSnapshot?
    let context: ClubGovernanceReadContext
    let snapshotGeneration: UInt64
    let sourceIsCurrent: Bool
    let viewerRevision: UInt64
    let readerScope: UUID?
    let destinationAvailable: Bool
}
/// This extra app fence captures the current player reader's session scope. A
/// source refresh or session/reader replacement cannot dispatch a queued route.
struct ClubStoryTemplateSelection: Identifiable, Hashable {
    let route: ClubStoryTemplateRoute
    let readerScope: UUID
    let viewerRevision: UInt64
    var id: UUID { route.id }
    @MainActor init?(gameplay: ClubStoryGameplay, snapshot: ClubGovernanceSnapshot,
          context: ClubGovernanceReadContext, snapshotGeneration: UInt64, templates: ClubStoryTemplateContext) {
        guard templates.isAvailable, let readerScope = templates.readerScope,
              context.viewerRevision == templates.viewerRevision,
              context.readerIdentity == templates.readerIdentity,
              let route = ClubStoryTemplateRoute(gameplay: gameplay, snapshot: snapshot,
                  context: context, snapshotGeneration: snapshotGeneration) else { return nil }
        self.route = route; self.readerScope = readerScope; viewerRevision = templates.viewerRevision
    }
    @MainActor func isCurrent(snapshot: ClubGovernanceSnapshot?, context: ClubGovernanceReadContext,
                   snapshotGeneration: UInt64, templates: ClubStoryTemplateContext) -> Bool {
        templates.isAvailable && templates.viewerRevision == viewerRevision &&
        templates.readerScope == readerScope && context.readerIdentity == templates.readerIdentity &&
        route.isCurrent(snapshot: snapshot, context: context, snapshotGeneration: snapshotGeneration)
    }
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct ClubStoryEmptyState: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    var body: some View {
        // Mini-program cy-empty: title only; the explanatory detail line is no longer shown.
        let _ = detail
        ContentUnavailableView(title, systemImage: "map")
    }
}
struct ClubStoryChapterTitle: View {
    let chapter: ClubStoryChapter
    @Environment(\.locale) private var locale
    var body: some View {
        Text(verbatim: ClubStoryChapterText.title(chapter, locale: locale))
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("club.gov.fact.title")
    }
}
/// CLB-topic-story-06 (MP topic-story/index.js:30-35, 104-107): 第一章 · name with Chinese ordinals, and one meta
/// line 「1h 30min · 3 站」 (or 未开放 · 待招商 when the chapter has no stop).
enum ClubStoryChapterText {
    private static let chineseOrdinals = ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
    static func title(_ chapter: ClubStoryChapter, locale: Locale) -> String {
        let name = chapter.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if name.hasPrefix("第"), name.contains("章") { return name }
        let ordinal: String
        if locale.language.languageCode?.identifier == "zh" {
            let word = chapter.id >= 0 && chapter.id < chineseOrdinals.count ? chineseOrdinals[chapter.id] : String(chapter.id + 1)
            ordinal = "第" + word + "章"
        } else {
            ordinal = appLocalized("club.story.chapter \(chapter.id + 1)", locale: locale)
        }
        return name.isEmpty ? ordinal : ordinal + " · " + name
    }
    /// MP `durationText`: 90 → 1h 30min, 60 → 1h, 25 → 25min; a missing or non-positive value is left out.
    static func duration(_ minutes: Double?) -> String? {
        guard let minutes, minutes.isFinite, minutes > 0 else { return nil }
        let total = Int(minutes.rounded())
        guard total > 0 else { return nil }
        let hours = total / 60, rest = total % 60
        if hours > 0, rest > 0 { return "\(hours)h \(rest)min" }
        if hours > 0 { return "\(hours)h" }
        return "\(rest)min"
    }
    static func meta(_ chapter: ClubStoryChapter, locale: Locale) -> String {
        guard !chapter.stops.isEmpty else { return appLocalized("club.story.awaitingMerchants", locale: locale) }
        return [duration(chapter.totalTime), appLocalized("club.story.stopCount \(chapter.stops.count)", locale: locale)]
            .compactMap { $0 }.joined(separator: " · ")
    }
}
struct ClubStoryChapterHeader: View {
    let chapter: ClubStoryChapter
    @Environment(\.locale) private var locale
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ClubStoryChapterTitle(chapter: chapter)
            Text(verbatim: ClubStoryChapterText.meta(chapter, locale: locale))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
@MainActor struct ClubStoryCover: View {
    let raw: String?
    let imageReader: (any RetainedPublicImageReading)?
    var seed = "story"
    var body: some View {
        Color.clear
            .aspectRatio(16.0 / 10.0, contentMode: .fit)
            .overlay { media }
            .clipShape(RoundedRectangle(cornerRadius: CYRadius.inner, style: .continuous))
            .accessibilityHidden(true)
    }
    @ViewBuilder private var media: some View {
        if let raw {
            NativeMediaImage(raw: raw, reader: imageReader ?? RetainedPublicImageReader(), zoomable: false)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            // A plain system tile with the map glyph stands in for a missing photo (`seed` kept for callers).
            let _ = seed
            ZStack {
                Color(uiColor: .secondarySystemFill)
                Image(systemName: "map.fill").foregroundStyle(.secondary).accessibilityHidden(true)
            }
        }
    }
}
/// CLB-topic-story-08 (MP topic-story wxml:28-52): one list row per stop. The numbered symbol on the left, then a
/// thumbnail beside 时间 / 站名 / 地址. The estimated walk sits above as one secondary line.
/// CLB-topic-story-04: the address is the mounted `ClubGapStoryMapAddressRow` (opens Maps once Core supplies coordinates).
@MainActor struct ClubStoryStopCard: View {
    /// CLB-r9-native-05: sequence dot, pin and thumbnail follow Dynamic Type.
    @ScaledMetric(relativeTo: .body) private var seqSide: CGFloat = 28
    @ScaledMetric(relativeTo: .body) private var pinSide: CGFloat = 16
    @ScaledMetric(relativeTo: .body) private var thumbWidth: CGFloat = 117
    @ScaledMetric(relativeTo: .body) private var thumbHeight: CGFloat = 80
    let stop: ClubStoryStop
    let imageReader: (any RetainedPublicImageReading)?
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let minutes = stop.estimatedWalkingMinutes {
                Label {
                    Text("club.story.walkMinutes \(minutes)")
                } icon: {
                    Image(systemName: "figure.walk").accessibilityHidden(true)
                }
                .font(.caption).foregroundStyle(.secondary)
                .padding(.leading, seqSide + 12)
                .accessibilityElement(children: .combine)
                .accessibilityHint(Text("topic.itinerary.estimateNotice"))
                .accessibilityIdentifier("club.story.walk.\(stop.id)")
            }
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: (0...50).contains(stop.sequence) ? "\(stop.sequence).circle.fill" : "circle.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: seqSide)
                    .accessibilityLabel(Text("club.story.stop \(stop.sequence)"))
                card
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("club.story.stop.\(stop.id)")
    }
    private var card: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        return layout {
            thumbnail
            VStack(alignment: .leading, spacing: 2) {
                Group {
                    if let time = stop.businessTime { Text(verbatim: time) } else { Text("club.story.hoursUnavailable") }
                }
                .font(.caption).foregroundStyle(.secondary)
                Group {
                    if let name = stop.name { Text(verbatim: name) } else { Text("club.story.unnamedStop") }
                }
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
                if let address = stop.address, !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // CLB-topic-story-04 (MP topic-story wxml:41, js:77-78): the address opens the map at the node's coordinates.
                    ClubGapStoryMapAddressRow(stop: ClubStoryStopLocation(name: stop.name ?? "", address: address,
                                                                          latitude: stop.latitude, longitude: stop.longitude))
                } else {
                    Label {
                        Text("club.story.addressUnavailable")
                    } icon: {
                        MPAsset.FeatureIcon.pin.resizable().scaledToFit().frame(width: pinSide, height: pinSide).accessibilityHidden(true)
                    }
                    .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    @ViewBuilder private var thumbnail: some View {
        Group {
            if let raw = stop.imgUrl {
                NativeMediaImage(raw: raw, reader: imageReader ?? RetainedPublicImageReader(), zoomable: false)
            } else {
                // MP stop-card__cover--empty: a plain tile with the image glyph.
                ZStack {
                    Color(uiColor: .secondarySystemFill)
                    Image(systemName: "photo").foregroundStyle(.secondary).accessibilityHidden(true)
                }
            }
        }
        .frame(width: thumbWidth, height: thumbHeight)
        .clipShape(RoundedRectangle(cornerRadius: CYRadius.inner, style: .continuous))
        .accessibilityHidden(true)
    }
}
/// CLB-topic-story-09 (MP topic-story wxml:89-110): one list row per play: the cover thumbnail beside the method
/// label, the title and one meta line 「第 N 站 节点 · 人数 · 分钟 · 难度」, the order trailing. Actions stay below (GV playContent).
@MainActor struct ClubStoryGameplayCard: View {
    let play: ClubStoryGameplay
    let imageReader: (any RetainedPublicImageReading)?
    var order: Int? = nil
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            cover
            VStack(alignment: .leading, spacing: 4) {
                chipRow
                Group {
                    if let title = play.title { Text(verbatim: title) }
                    else { Text("discovery.untitledPlay") }
                }
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("club.gov.fact.title")
                Text(verbatim: metaLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("club.story.play.\(play.id)")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(verbatim: String(order ?? play.sequence))
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }
    /// MP `joinMeta(['第 N 站 ' + node, players, duration + ' 分钟', '难度' + difficulty])`.
    private var metaLine: String {
        var stopText = appLocalized("club.story.stop \(play.sequence)", locale: locale)
        if let node = play.nodeName?.trimmingCharacters(in: .whitespacesAndNewlines), !node.isEmpty { stopText += " " + node }
        let duration = play.duration.map { appLocalized("club.story.minutes \($0.formatted(.number.precision(.fractionLength(0...2))))", locale: locale) }
        let difficulty = play.difficulty.map { appLocalized("club.story.difficulty \($0)", locale: locale) }
        return [stopText, play.players, duration, difficulty]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
    private var cover: some View {
        Group {
            if let raw = play.imgUrl {
                NativeMediaImage(raw: raw, reader: imageReader ?? RetainedPublicImageReader(), zoomable: false)
            } else {
                ZStack {
                    Color(uiColor: .secondarySystemFill)
                    Image(systemName: "map.fill").foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 80, height: 80)
        .clipShape(RoundedRectangle(cornerRadius: CYRadius.inner, style: .continuous))
        .accessibilityHidden(true)
    }
    private var chipRow: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 8))
        return layout {
            // MP play-card: no "no answer" chip; an unanswerable play just has no 查看答案 button.
            methodChip
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    @ViewBuilder private var methodChip: some View {
        if let code = play.validationMethod, let method = TemplateAuthoringMethod(rawValue: code) {
            Label(LocalizedStringKey(method.labelKey), systemImage: "checkmark.seal")
        } else if let label = play.validationMethodLabel {
            Label { Text(verbatim: label) } icon: { Image(systemName: "checkmark.seal") }
        } else {
            Label("club.story.play", systemImage: "gamecontroller")
        }
    }
}

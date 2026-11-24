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
        CYEmptyState(systemImage: "map", title)
    }
}
struct ClubStoryChapterTitle: View {
    let chapter: ClubStoryChapter
    var body: some View {
        Group {
            if let name = chapter.name, name.hasPrefix("第"), name.contains("章") { Text(verbatim: name) }
            else if let name = chapter.name { Text("club.story.chapter \(chapter.id + 1)") + Text(verbatim: " · " + name) }
            else { Text("club.story.chapter \(chapter.id + 1)") }
        }
        .cyText(.cardTitle)
        .foregroundStyle(CYColor.textPrimary)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("club.gov.fact.title")
    }
}
struct ClubStoryChapterHeader: View {
    let chapter: ClubStoryChapter
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            ClubStoryChapterTitle(chapter: chapter)
            if chapter.stops.isEmpty {
                Text("club.story.awaitingMerchants")
                    .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("club.story.stopCount \(chapter.stops.count)")
                    .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let minutes = chapter.totalTime {
                    Text("club.story.minutes \(minutes.formatted(.number.precision(.fractionLength(0...2))))")
                        .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }.textCase(nil)
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
            .clipShape(RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous))
            .accessibilityHidden(true)
    }
    @ViewBuilder private var media: some View {
        if let raw {
            NativeMediaImage(raw: raw, reader: imageReader ?? RetainedPublicImageReader(), zoomable: false)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            // Generated cover art stands in for a missing photo so the card stays image-led.
            CYCoverArt(seed: seed, symbol: "map.fill")
        }
    }
}
@MainActor struct ClubStoryStopCard: View {
    let stop: ClubStoryStop
    let imageReader: (any RetainedPublicImageReading)?
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            if let minutes = stop.estimatedWalkingMinutes {
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    CYListRow("topic.itinerary.estimatedWalkMinutes", trailing: .value(minutes.formatted(.number))) {
                        CYRowIcon(systemImage: "figure.walk")
                    }
                    Text("topic.itinerary.estimateNotice")
                        .cyText(.meta).foregroundStyle(CYColor.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("club.story.walk.\(stop.id)")
            }
            ZStack(alignment: .topLeading) {
                ClubStoryCover(raw: stop.imgUrl, imageReader: imageReader, seed: stop.name ?? String(stop.id))
                CYStatusChip("club.story.stop \(stop.sequence)", tone: .neutral, systemImage: "mappin.circle.fill")
                    .padding(CYSpacing.sm)
            }
            if let name = stop.name { Text(verbatim: name).cyText(.sectionTitle).foregroundStyle(CYColor.textPrimary).fixedSize(horizontal: false, vertical: true) }
            else { Text("club.story.unnamedStop").cyText(.sectionTitle).foregroundStyle(CYColor.textPrimary).fixedSize(horizontal: false, vertical: true) }
            if let time = stop.businessTime {
                CYListRow(verbatim: time, trailing: .none) { CYRowIcon(systemImage: "clock") }
            } else {
                CYListRow("club.story.hoursUnavailable", trailing: .none) { CYRowIcon(systemImage: "clock") }
            }
            if let address = stop.address {
                CYListRow(verbatim: address, trailing: .none) { CYRowIcon(systemImage: "mappin.and.ellipse") }
            } else {
                CYListRow("club.story.addressUnavailable", trailing: .none) { CYRowIcon(systemImage: "mappin.and.ellipse") }
            }
        }
        .padding(.vertical, CYSpacing.sm)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("club.story.stop.\(stop.id)")
    }
}
@MainActor struct ClubStoryGameplayCard: View {
    let play: ClubStoryGameplay
    let imageReader: (any RetainedPublicImageReading)?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            ClubStoryCover(raw: play.imgUrl, imageReader: imageReader, seed: play.title ?? String(play.id))
            chipRow
            Group {
                if let title = play.title { Text(verbatim: title) }
                else { Text("discovery.untitledPlay") }
            }
            .cyText(.cardTitle)
            .foregroundStyle(CYColor.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("club.gov.fact.title")
            CYListRow("club.story.stop \(play.sequence)", trailing: .none) { CYRowIcon(systemImage: "mappin.circle") }
                .accessibilityIdentifier("club.story.play.\(play.id)")
            if let name = play.nodeName {
                CYListRow(verbatim: name, trailing: .none) { CYRowIcon(systemImage: "flag") }
            }
            if let players = play.players {
                CYListRow(verbatim: players, trailing: .none) { CYRowIcon(systemImage: "person.2") }
            }
            if let duration = play.duration {
                CYListRow("club.story.minutes \(duration.formatted(.number.precision(.fractionLength(0...2))))", trailing: .none) {
                    CYRowIcon(systemImage: "clock")
                }
            }
            if let difficulty = play.difficulty {
                CYListRow("club.story.difficulty \(difficulty)", trailing: .none) { CYRowIcon(systemImage: "speedometer") }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
    private var chipRow: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: CYSpacing.sm))
            : AnyLayout(HStackLayout(alignment: .center, spacing: CYSpacing.sm))
        return layout {
            methodChip
            if !play.isAnswerable {
                CYStatusChip("club.story.noAnswer", tone: .warning, systemImage: "questionmark.circle")
            }
        }
    }
    @ViewBuilder private var methodChip: some View {
        if let code = play.validationMethod, let method = TemplateAuthoringMethod(rawValue: code) {
            CYStatusChip(LocalizedStringKey(method.labelKey), tone: .neutral, systemImage: "checkmark.seal")
        } else if let label = play.validationMethodLabel {
            CYStatusChip(verbatim: label, tone: .neutral, systemImage: "checkmark.seal")
        } else {
            CYStatusChip("club.story.play", tone: .neutral, systemImage: "gamecontroller")
        }
    }
}

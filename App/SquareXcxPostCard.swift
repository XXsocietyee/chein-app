import SwiftUI

/// Mini-program `cy-post-card` layout for Square list rows: author head, meta line (club · relative time),
/// review lifecycle, clamped body, play card, image strip and read-only counters.
/// Images stay behind the existing gated `NativeMediaGalleryEntry`; avatars use a local placeholder.
struct SquareXcxPostCard: View {
    let post: SquarePost
    var mediaScope: UUID = UUID()
    var now: Date = Date()
    /// List rows place the tappable gallery outside their NavigationLink, so the card omits it there.
    var showsMedia = true
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .headline) private var verifiedSize: CGFloat = 12
    private var facts: SquarePostCardFacts { SquarePostCardFacts(post) }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            head
            if let lifecycle = facts.lifecycle {
                Text(LocalizedStringKey("square.xcx.lifecycle." + lifecycle.rawValue)).font(.caption).foregroundStyle(CYColor.warningText)
                    .accessibilityIdentifier("square.card.lifecycle")
            }
            if let contents = post.contents, !contents.isEmpty {
                Text(verbatim: contents).lineLimit(6)
                if facts.bodyExpandable { Text("square.xcx.expand").font(.caption).foregroundStyle(.tint) }
            }
            stravaSection
            if facts.isCompletionShare || facts.hasPlayCover { playCard }
            if showsMedia, let preview = facts.leadingRoutePreview {
                NativeMediaGalleryEntry(sources: [preview], scope: mediaScope, titleKey: "media.destination.squareImages", compact: true)
            }
            if !facts.strip.isEmpty {
                if showsMedia { NativeMediaGalleryEntry(sources: facts.strip, scope: mediaScope, titleKey: "media.destination.squareImages", compact: true) }
                if facts.showsCountPill { Text("square.xcx.countPill \(facts.strip.count)").font(.caption).monospacedDigit().foregroundStyle(.secondary).accessibilityIdentifier("square.card.count") }
            }
            counters
        }.padding(.vertical, 4)
    }
    /// One line: avatar, name (single line) and time; at most ONE chip under it (notice > author badge > level).
    /// The remaining badges stay in the accessibility label and in the post detail.
    private var head: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "person.crop.circle.fill").font(.largeTitle).foregroundStyle(.secondary).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if let name = post.nickname?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty { Text(verbatim: name).font(.headline) }
                    else { Text("square.xcx.defaultName").font(.headline) }
                    if post.verified {
                        // MP: components/cy/post-card/index.wxml:25 (icon_rz.png, .post-card__verified 24rpx)
                        MPAsset.FeatureIcon.iconRz.resizable().scaledToFit().frame(width: verifiedSize, height: verifiedSize)
                            .accessibilityLabel(Text("square.verified"))
                    }
                    Spacer(minLength: 4)
                    SquareXcxRelativeTime(createTime: post.createTime, now: now).font(.caption).foregroundStyle(.secondary).lineLimit(1).fixedSize()
                }
                metaLayout {
                    if let club = post.clubName { Text(verbatim: club).font(.caption).foregroundStyle(.secondary).lineLimit(metaLines) }
                    if let badge = post.noticeBadge ?? post.authorBadge {
                        Text(verbatim: badge).font(.caption.weight(.semibold)).foregroundStyle(.secondary).lineLimit(metaLines)
                    } else if post.memberLevel > 0 {
                        Text("square.xcx.level \(post.memberLevel)").font(.caption.weight(.semibold)).foregroundStyle(.secondary).lineLimit(metaLines)
                    }
                }
            }
        }
    }
    /// a11y-dt: club · badge stay one line at normal sizes; at accessibility sizes they stack and may wrap to 2 lines.
    private var metaLayout: AnyLayout {
        typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2)) : AnyLayout(HStackLayout(spacing: 6))
    }
    private var metaLines: Int { typeSize.isAccessibilitySize ? 2 : 1 }
    @ViewBuilder private var playCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            if post.isTopicTemplate { Text("square.xcx.templateBadge").font(.caption.weight(.semibold)).foregroundStyle(.secondary).accessibilityIdentifier("square.card.templateBadge") }
            if let title = post.referenceTitle { Text(verbatim: title).font(.subheadline.weight(.medium)) }
            else if facts.isCompletionShare { Text("square.xcx.completionFallback").font(.subheadline.weight(.medium)) }
            switch facts.playSubtitle {
            case .completedNodes(let total)?: Text("square.xcx.play.completedNodes \(total)").font(.caption).foregroundStyle(.secondary)
            case .progress(let done, let total)?: Text("square.xcx.play.progress \(done) \(total)").font(.caption).foregroundStyle(.secondary)
            case .completed?: Text("square.xcx.play.completed").font(.caption).foregroundStyle(.secondary)
            case .inProgress?: Text("square.xcx.play.inProgress").font(.caption).foregroundStyle(.secondary)
            case nil: EmptyView()
            }
            if showsMedia, let cover = facts.playCover {
                NativeMediaGalleryEntry(sources: [cover], scope: mediaScope, titleKey: "media.destination.squareImages", compact: true)
            }
        }
            .accessibilityElement(children: .contain).accessibilityIdentifier("square.card.play")
    }
    private var counters: some View {
        HStack(spacing: 24) {
            Label { Text(verbatim: SquareCountDisplay.text(post.likeCount)) } icon: { Image(systemName: post.isLiked == 1 ? "heart.fill" : "heart").foregroundStyle(post.isLiked == 1 ? AnyShapeStyle(CYColor.brand) : AnyShapeStyle(.secondary)) }
                .accessibilityLabel(post.likeCount.map { Text("square.xcx.likesA11y \($0)") } ?? Text(verbatim: SquareCountDisplay.unknownMark))
            Label { Text(verbatim: SquareCountDisplay.text(post.commentCount)) } icon: { Image(systemName: "bubble.right") }
                .accessibilityLabel(post.commentCount.map { Text("square.xcx.commentsA11y \($0)") } ?? Text(verbatim: SquareCountDisplay.unknownMark))
            if let shareURL = PublicContentShareLink.squarePost(PublicContentShareLink.l5Post(from: post)) {
                ShareLink(item: shareURL) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel(Text("mp.common.share"))
                .accessibilityIdentifier("square.card.share")
            }
        }.font(.caption).monospacedDigit().foregroundStyle(.secondary)
    }
}

struct SquareXcxRelativeTime: View {
    let createTime: String
    let now: Date
    var body: some View {
        switch SquareRelativeAge.of(createTime, now: now) {
        case .justNow?: Text("square.xcx.justNow")
        // MP `N天前`; coordinator 19:50: full units within a week, then the locale's absolute date (never "330 d ago").
        case .days(let days)?:
            if days < 7 { Text("mpr3.square.ageDays \(days)") }
            else if let date = SquareXcxTime.date(createTime) {
                if Calendar.current.isDate(date, equalTo: now, toGranularity: .year) { Text(date, format: .dateTime.month(.abbreviated).day()) }
                else { Text(date, format: .dateTime.year().month(.abbreviated).day()) }
            }
            else { Text("mpr3.square.ageDays \(days)") }
        case .hoursMinutes(let hours, let minutes)?:
            if hours > 0 && minutes > 0 { Text("square.xcx.ageHoursMinutes \(hours) \(minutes)") }
            else if hours > 0 { Text("mpr3.square.ageHours \(hours)") }
            else { Text("square.xcx.ageMinutes \(minutes)") }
        case nil:
            // Unparseable source time is shown verbatim rather than guessed.
            if !createTime.isEmpty { Text(verbatim: createTime) }
        }
    }
}

/// Source list header strip: official events starting within 24 hours. Read-only; opening uses the host's destination.
@MainActor struct SquareXcxUpcomingStrip: View {
    let reader: any OfficialEventReading
    var destination: ((Int) -> AnyView)? = nil
    @StateObject private var sourceObservation = OfficialReadInvalidationObserver()
    @State private var loadGeneration = UUID()
    @State private var loadingScope: UUID?
    @State private var items: [SquareUpcomingBannerItem] = []
    @State private var loadedScope: UUID?
    /// i18n r1: the card grows with Dynamic Type so English kicker/countdown copy wraps instead of clipping.
    @ScaledMetric(relativeTo: .headline) private var cardWidth: CGFloat = 240
    var body: some View {
        Group {
            if loadedScope == reader.scope, !items.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 20) {
                        ForEach(items) { item in
                            if let destination {
                                NavigationLink { destination(item.id) } label: { card(item) }.buttonStyle(.plain)
                                    .accessibilityIdentifier("square.upcoming.\(item.id)")
                            } else { card(item).accessibilityIdentifier("square.upcoming.\(item.id)") }
                        }
                    }
                }.accessibilityIdentifier("square.upcoming")
            }
        }
        .task(id: reader.scope) { await load() }
        .onAppear { sourceObservation.bind(reader) }
        .onChange(of: ObjectIdentifier(reader)) { _, _ in sourceObservation.bind(reader) }
        .onChange(of: sourceObservation.revision) { _, _ in
            guard sourceObservation.isBound(to: reader) else { return }
            if loadingScope != reader.scope { loadGeneration = UUID(); loadingScope = nil }
            if loadedScope != reader.scope { items = []; loadedScope = nil }
        }
        .onDisappear { loadGeneration = UUID(); sourceObservation.stop() }
    }
    private func card(_ item: SquareUpcomingBannerItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("square.xcx.upcoming.kicker").fontWeight(.semibold).foregroundStyle(CYColor.warningText)
                switch item.countdown(now: Date()) {
                case .days(let n): Text("square.xcx.upcoming.days \(n)")
                case .hours(let n): Text("square.xcx.upcoming.hours \(n)")
                case .minutes(let n): Text("square.xcx.upcoming.minutes \(n)")
                case .soon: Text("square.xcx.upcoming.soon")
                }
            }
            .font(.caption)
            Text(verbatim: item.title).font(.headline).foregroundStyle(.primary)
            if let subtitle = item.subtitle { Text(verbatim: subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
            HStack(spacing: 4) {
                ForEach(Array(item.avatars.enumerated()), id: \.offset) { _, _ in Image(systemName: "person.circle.fill").accessibilityHidden(true) }
                if item.overflow > 0 { Text("square.xcx.upcoming.overflow \(item.overflow)") }
                Text("square.xcx.upcoming.participants").foregroundStyle(.secondary)
            }
            .font(.caption)
        }
        .frame(width: cardWidth, alignment: .leading)
        .contentShape(Rectangle())
    }
    private func load() async {
        let scope = reader.scope
        guard !Task.isCancelled, reader.isConfigured, loadedScope != scope else { return }
        loadGeneration = UUID(); let generation = loadGeneration
        loadingScope = scope
        defer { if generation == loadGeneration { loadingScope = nil } }
        do {
            let events = try await reader.events(city: nil)
            try Task.checkCancellation()
            guard generation == loadGeneration, scope == reader.scope else { return }
            items = SquareUpcomingBannerItem.select(events, now: Date()); loadedScope = scope
        } catch {
            // Source hides the strip on a current failure; stale cancellation cannot clear a newer load.
            guard !Task.isCancelled, !(error is CancellationError),
                  generation == loadGeneration, scope == reader.scope else { return }
            items = []
        }
    }
}

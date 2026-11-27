import SwiftUI
import UIKit

/// A chapter belongs to the live play session. Native scrolling, type scaling and Back
/// replace source animation chrome; gameplay stays embedded when the server says inline.
@MainActor struct ChapterStoryView: View {
    let chapterID: Int
    let nodeID: Int
    @Bindable var model: PlayExperienceCoordinator
    var advancedModel: ((Int) -> PlayAdvancedCoordinator?)? = nil
    var journeyModel: ((Int) -> JourneyCheckCoordinator?)? = nil
    var deviceModel: ((Int) -> PlayDeviceCaptureCoordinator)? = nil
    var mediaScope: UUID = UUID()
    var makeAudio: (@MainActor () -> PlatformAudioPlayback)? = nil
    var approvedArtworkHosts: Set<String> = []
    var makeSensorProvider: (@MainActor () -> any PlayKitSensorProviding)? = nil
    var spatialApproval = PlayKitSpatialApproval()
    var imageReader: (any RetainedPublicImageReading)? = nil
    /// Nil for callers that have no cast. The play host passes the run's coordinator.
    var castModel: CastCoordinator? = nil
    let nodeDestination: (Int) -> AnyView
    @State private var advancedVariables: [String: PlayWireValue] = [:]
    @State private var dirtyNodes = Set<Int>()
    @State private var confirmLeave = false
    @State private var activeInlineNodeID: Int?
    @State private var audioURL: String?
    @State private var audioMounted = false
    @State private var audioPresentationID = UUID()
    @State private var thoughtReadRevision = UUID()
    /// Chapter opening gate (mini-program chapter-gate): once per visit of this chapter.
    @State private var showGate = false
    @State private var gateSeen = false
    /// U04-04 reading resume: the segment at the top of the viewport, restored once per visit.
    @State private var readingSegmentID: String?
    @State private var resumeTried = false
    @State private var zoomedImage: ChapterStoryZoomedImage?
    @State private var castCard: ChapterStoryCastCard?
    /// Reading rhythm (mini-program reading-motion.js): fade, then settle. Tap shows the rest at once.
    @State private var revealSettled = false
    /// VIDEO-r11-1: the chapter film shown once when the chapter opens.
    @State private var chapterVideo: ChapterVideoItem?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let readingStore = ChapterReadingPositionStore()
    private var readingKey: String? {
        ChapterReadingPositionStore.key(runIdentity: model.identity, contentVersion: model.contentVersion, chapterID: chapterID)
    }
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    /// P-082: the domain of the page that opened the reader (the story route). Native r2 reads in that same domain.
    @Environment(\.themeDomain) private var hostDomain
    private var chapter: ChapterStoryDocument? { model.chapterStories[chapterID] }
    private var gameStage: PlayGameStage? {
        guard let result = model.snapshot?.result else { return nil }
        return PlayGameStage.resolve(nodeID: nodeID, nodes: result.nodes, chapters: result.chapters)
    }
    private var visible: Bool {
        guard model.hasCurrentMediaSnapshot, let snapshot = model.snapshot,
              snapshot.availability == .active || snapshot.availability == .completed,
              let node = snapshot.visibleNodes.first(where: { $0.id == nodeID && $0.chapterID == chapterID }) else { return false }
        return !snapshot.isLocked(node)
    }
    private var segments: [ChapterStorySegment] {
        guard visible, let chapter, let snapshot = model.snapshot else { return [] }
        return ChapterStoryProjection.segments(chapter: chapter, snapshot: snapshot,
            variables: model.storyVariables.merging(advancedVariables) { _, new in new },
            thoughts: model.storyThoughts, storyVoices: model.storyVoices, activeInlineNodeID: activeInlineNodeID,
            cast: castModel?.context)
    }
    /// Position of this chapter in the run (1-based) and the run's chapter count.
    private var chapterPosition: (number: Int, total: Int, name: String?, next: String?)? {
        guard let chapters = model.snapshot?.result.chapters, let index = chapters.firstIndex(where: { $0.id == chapterID }) else { return nil }
        let next = chapters.indices.contains(index + 1) ? chapters[index + 1].name : nil
        return (index + 1, chapters.count, chapters[index].name, next)
    }
    /// Stops of this chapter that the player can see, and how many of them are done.
    private var chapterProgress: (done: Int, total: Int)? {
        guard visible, let snapshot = model.snapshot else { return nil }
        let nodes = snapshot.visibleNodes.filter { $0.chapterID == chapterID }
        guard !nodes.isEmpty else { return nil }
        return (nodes.filter { snapshot.isDone($0) }.count, nodes.count)
    }
    private var currentAudioURLs: Set<String> {
        guard visible else { return [] }
        var urls = Set(segments.compactMap { segment -> String? in
            if case .audio(let url) = segment.content { return url }
            return nil
        })
        if let selection = PlatformChapterAudioSelection.resolve(snapshot: model.snapshot, nodeID: nodeID, extras: model.extras, currentRead: visible) {
            if let narration = selection.narrationURL { urls.insert(narration) }
            if let guide = selection.guideURL { urls.insert(guide) }
        }
        return urls
    }
    /// Native r2 mini player queue: narration, guide, then the chapter's audio blocks in reading order.
    /// Same members as `currentAudioURLs`, so a skip can never select a clip the reader would refuse.
    private var orderedAudioURLs: [String] {
        guard visible else { return [] }
        var ordered: [String] = []
        if let selection = PlatformChapterAudioSelection.resolve(snapshot: model.snapshot, nodeID: nodeID, extras: model.extras, currentRead: visible) {
            if let narration = selection.narrationURL { ordered.append(narration) }
            if let guide = selection.guideURL, !ordered.contains(guide) { ordered.append(guide) }
        }
        for segment in segments {
            if case .audio(let url) = segment.content, !ordered.contains(url) { ordered.append(url) }
        }
        return ordered
    }
    private struct ThoughtReadTaskKey: Hashable {
        let identity: String?
        let chapterID: Int
        let nodeID: Int
        let revision: UUID
        let active: Bool
    }
    private var thoughtReadTaskKey: ThoughtReadTaskKey {
        .init(identity: model.identity, chapterID: chapterID, nodeID: nodeID,
              revision: thoughtReadRevision, active: scenePhase == .active)
    }
    /// MP `openChapterFull` → `playChapterVideo` when no chapter gate is up (pages/play/index.js:4062).
    private func presentChapterVideoIfNeeded() {
        guard chapterVideo == nil, visible, model.hasCurrentMediaSnapshot,
              let row = model.snapshot?.result.chapters.first(where: { $0.id == chapterID }),
              let item = ChapterVideoItem.make(chapterID: chapterID, video: row.videoURL, poster: row.videoPosterURL,
                                               approvedHosts: approvedArtworkHosts),
              ChapterVideoSeen.claim(item.id) else { return }
        chapterVideo = item
    }
    var body: some View {
        ScrollViewReader { reader in
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if visible, let chapter {
                    if NativeR2Flags.storyFlow {
                        let position = chapterPosition
                        NR2ChapterOpener(number: position?.number, total: position?.total,
                                         title: chapter.title ?? position?.name, opening: chapter.openingLine ?? chapter.description)
                        if segments.isEmpty {
                            ContentUnavailableView("chapterStory.empty", systemImage: "book.closed")
                        }
                    } else {
                        if let title = chapter.title { CYHeroHeader(verbatim: title) }
                        if segments.isEmpty { CYEmptyState(systemImage: "book.closed", "chapterStory.empty") }
                    }
                    ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                        segmentBody(segment)
                            .cyThemeEdge(mood: NativeR2Flags.storyFlow ? nil : segment.mood, odd: NativeR2Flags.storyFlow ? 0 : segment.odd)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .modifier(ChapterReadingReveal(index: index, settled: NativeR2Flags.storyFlow || revealSettled || reduceMotion))
                            .accessibilityIdentifier("chapterStory.segment." + segment.id)
                            .id(segment.id)
                            .background(GeometryReader { proxy in
                                Color.clear.preference(key: ChapterSegmentOffsetKey.self,
                                                       value: [segment.id: proxy.frame(in: .named(Self.scrollSpace)).minY])
                            })
                    }
                    if let snapshot = model.snapshot, let stop = ChapterStoryProjection.lockedStop(chapter: chapter, snapshot: snapshot) {
                        // Lock reason is the server's text; without one the reader still learns the flow is waiting, not over.
                        Label {
                            if let reason = snapshot.lockReason(stop) { Text(verbatim: reason) }
                            else { Text("chapterStory.lockedStop", tableName: "PlayFullStory") }
                        } icon: { Image(systemName: "lock") }
                        .font(CYTypography.caption).foregroundStyle(CYColor.textSecondary)
                        .accessibilityIdentifier("chapterStory.lockedStop")
                    }
                    if let position = chapterPosition {
                        Text("chapterStory.footer.station \(position.number) \(position.total)")
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .accessibilityIdentifier("chapterStory.footer")
                    }
                    if model.thoughtSyncPhase == .syncing { ProgressView("chapterStory.thought.syncing") }
                    if model.thoughtSyncPhase == .disabled { Text("chapterStory.thought.disabled").cyText(.bodyCompact).foregroundStyle(.secondary) }
                    if model.thoughtSyncPhase == .needsReadback {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("chapterStory.thought.readback")
                            Button("playx.refresh") { Task { await model.load() } }
                        }.accessibilityIdentifier("chapterStory.thought.readback")
                    }
                    if NativeR2Flags.storyFlow {
                        if visible { NarrationAutoplayToggle() }
                    } else {
                        audioSelection
                    }
                    if makeAudio == nil, !currentAudioURLs.isEmpty {
                        Label("platform.audio.gated", systemImage: "speaker.slash")
                            .font(CYTypography.caption).foregroundStyle(CYColor.textSecondary)
                    }
                    if !NativeR2Flags.storyFlow, let audioURL, audioMounted, scenePhase == .active, currentAudioURLs.contains(audioURL) {
                        PlatformAudioHost(rawURL: audioURL, scope: mediaScope, makeModel: makeAudio)
                    }
                    if NativeR2Flags.storyFlow, let progress = chapterProgress, progress.done == progress.total {
                        let position = chapterPosition
                        NR2ChapterFooter(closing: chapter.closingLine, done: progress.done, total: progress.total,
                                         nextTitle: position?.next, onContinue: { leave() })
                    } else if NativeR2Flags.storyFlow {
                        Text("chapterStory.end").font(.footnote).foregroundStyle(.secondary)
                        Button { leave() } label: { Text("chapterStory.return").frame(maxWidth: .infinity) }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                    } else if let progress = chapterProgress, progress.done == progress.total {
                        if let closing = chapter.closingLine {
                            Text(verbatim: closing).cyText(.body).italic().foregroundStyle(CYColor.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityIdentifier("chapterStory.closingLine")
                        }
                        // Mini-program chapter-flip end card: the chapter is complete, the next stop is named.
                        let position = chapterPosition
                        CYChapterEndCard(number: position?.number ?? 1, title: position?.name ?? chapter.title,
                            stats: [
                                CYStoryStat(key: "chapterFlip.stat.stops", value: "\(progress.done)/\(progress.total)"),
                                CYStoryStat(key: "chapterFlip.stat.chapter", value: position.map { "\($0.number)/\($0.total)" }),
                            ],
                            nextTitle: position?.next, onContinue: { leave() })
                    } else {
                        Text("chapterStory.end").cyText(.meta).foregroundStyle(CYColor.textTertiary)
                        CYPillButton("chapterStory.return") { leave() }
                    }
                } else if NativeR2Flags.storyFlow && model.phase == .loading && model.snapshot == nil {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .accessibilityLabel(Text("homeFeed.loading"))
                        .accessibilityIdentifier("chapterStory.loading")
                } else if NativeR2Flags.storyFlow && model.phase == .failed {
                    ContentUnavailableView {
                        Label("chapterStory.unavailable", systemImage: "book.closed")
                    } description: {
                        Text("chapterStory.unavailable.detail")
                    } actions: {
                        Button("homeFeed.retry") { Task { await model.load() } }
                            .buttonStyle(.bordered)
                    }
                    .accessibilityIdentifier("chapterStory.error")
                } else if model.phase == .loading && model.snapshot == nil {
                    // Loading is not "locked": the lock state only shows once the read has settled.
                    CYLoadingStateView(rows: 3)
                        .accessibilityLabel(Text("homeFeed.loading"))
                        .accessibilityIdentifier("chapterStory.loading")
                } else if model.phase == .failed {
                    CYErrorStateView(title: "chapterStory.unavailable", message: "chapterStory.unavailable.detail",
                                     retryTitle: "homeFeed.retry") { Task { await model.load() } }
                        .accessibilityIdentifier("chapterStory.error")
                } else {
                    ChapterGate()
                }
            }
            .padding(CYSpacing.pageHorizontal).frame(maxWidth: 720).frame(maxWidth: .infinity)
            .simultaneousGesture(TapGesture().onEnded { revealSettled = true })
        }
        .coordinateSpace(.named(Self.scrollSpace))
        .onPreferenceChange(ChapterSegmentOffsetKey.self) { offsets in
            // The last segment whose top has reached the upper band is where the reader is.
            let order = segments.map(\.id)
            let reached = order.last { (offsets[$0] ?? .infinity) <= 120 } ?? order.first
            guard visible, let reached, reached != readingSegmentID, resumeTried else { return }
            readingSegmentID = reached
            readingStore.save(reached, key: readingKey)
        }
        .task(id: "\(readingKey ?? ""):\(segments.count)") {
            guard !Task.isCancelled, !resumeTried, visible, !segments.isEmpty, let capturedKey = readingKey else { return }
            resumeTried = true
            await Task.yield()
            guard !Task.isCancelled, visible, capturedKey == readingKey else { return }
            if let target = ChapterReadingPositionStore.resumeTarget(saved: readingStore.read(capturedKey), rendered: segments.map(\.id)) {
                reader.scrollTo(target, anchor: .top)
            }
        }
        }
        .cyFullScreenCover(item: $zoomedImage) { item in
            if visible, scenePhase == .active, imageReader?.enabled == true {
                ChapterStoryImageViewer(image: item.image, alt: item.alt)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // P-083: native r2 keeps the mini player mounted when the app leaves the foreground so narration goes on.
            if NativeR2Flags.storyFlow, visible, audioMounted, makeAudio != nil, !orderedAudioURLs.isEmpty {
                NR2MiniAudioPlayer(title: chapter?.title ?? chapterPosition?.name, urls: orderedAudioURLs,
                                   selected: audioURL.flatMap { currentAudioURLs.contains($0) ? $0 : nil },
                                   scope: mediaScope, makeAudio: makeAudio, select: scopedAudioSelection())
                    .id(audioPresentationID)
            }
        }
        .background {
            if NativeR2Flags.storyFlow {
                Color(uiColor: .systemBackground).ignoresSafeArea()
            } else if visible, let atmosphere = chapter?.atmosphere {
                ChapterAtmosphereFill(atmosphere).ignoresSafeArea()
            } else {
                CYColor.bgPage.ignoresSafeArea()
            }
        }
        .modifier(ChapterAtmosphereScheme(atmosphere: !NativeR2Flags.storyFlow && visible ? chapter?.atmosphere : nil))
        .environment(\.questifyCast, castModel?.context)
        .environment(\.playGameStage, gameStage)
        .cySheet(item: $castCard) { target in
            if let member = castModel?.config?.member(target.memberID) {
                CastCharacterCard(member: member, trust: castModel?.trust[member.id] ?? 0,
                                  reachedChapters: reachedChapters, line: target.line, chapterID: chapterID,
                                  cast: castModel, mediaScope: mediaScope, makeAudio: makeAudio, imageReader: imageReader)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .cyPageTitle("chapterStory.title")
        // Unsaved answers: the one exit guard (system-look back + confirm), swipe back blocked while dirty.
        .cyGuardedBack(when: !dirtyNodes.isEmpty, onBack: leave)
        .overlay {
            if showGate {
                let position = chapterPosition
                CYChapterGate(number: position?.number ?? 1, total: position?.total ?? 1,
                              title: chapter?.title ?? position?.name, subtitle: chapter?.openingLine ?? chapter?.description) {
                    withAnimation(CYMotion.reduced) { showGate = false }
                }
                .transition(.opacity)
            }
        }
        .toolbar(showGate ? .hidden : .automatic, for: .navigationBar)
        .onAppear {
            audioMounted = true; if !gateSeen && visible && chapter != nil { gateSeen = true; showGate = !NativeR2Flags.storyFlow }
            if !showGate { presentChapterVideoIfNeeded() }
        }
        .onChange(of: showGate) { _, shown in if !shown { presentChapterVideoIfNeeded() } }
        .fullScreenCover(item: $chapterVideo) { item in
            ChapterVideoCover(item: item, onClose: { chapterVideo = nil })
        }
        .task(id: segments.map(\.id).joined(separator: "\u{1e}")) {
            guard !reduceMotion, !segments.isEmpty else { revealSettled = true; return }
            revealSettled = false
            let steps = min(segments.count, 6)
            let seconds = CYMotion.Duration.quick + Double(steps) * (CYMotion.Stagger.rewrite.dropFirst().first ?? 0.04)
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            if !Task.isCancelled { revealSettled = true }
        }
        .onChange(of: visible) { _, now in
            if !now { zoomedImage = nil }
            if now && !gateSeen && chapter != nil { gateSeen = true; showGate = !NativeR2Flags.storyFlow }
        }
        .privacySensitive().accessibilityIdentifier("chapterStory.body")
        .interactiveDismissDisabled(!dirtyNodes.isEmpty)
        .confirmationDialog("chapterStory.discardQuestion", isPresented: $confirmLeave, titleVisibility: .visible) {
            Button("chapterStory.discard", role: .destructive) { dirtyNodes = []; dismiss() }
            Button("chapterStory.keepEditing", role: .cancel) {}
        } message: { Text("chapterStory.discardBody") }
        .task(id: thoughtReadTaskKey) {
            guard !Task.isCancelled, scenePhase == .active, visible else { return }
            await model.claimVisibleThoughts(chapterID: chapterID)
        }
        .onChange(of: model.snapshot) { _, _ in thoughtReadRevision = UUID() }
        .onChange(of: model.storyVariables) { _, next in advancedVariables.merge(next) { _, new in new } }
        .onChange(of: currentAudioURLs) { _, available in
            if let selected = audioURL, !available.contains(selected) { audioURL = nil }
        }
        .onChange(of: mediaScope) { _, _ in audioPresentationID = UUID(); audioURL = nil; zoomedImage = nil }
        .onChange(of: chapterID) { _, _ in audioPresentationID = UUID(); audioURL = nil; resumeTried = false; readingSegmentID = nil; zoomedImage = nil }
        .onChange(of: nodeID) { _, _ in audioPresentationID = UUID(); audioURL = nil; zoomedImage = nil }
        .onChange(of: model.identity) { _, _ in audioPresentationID = UUID(); advancedVariables = [:]; dirtyNodes = []; activeInlineNodeID = nil; audioURL = nil; resumeTried = false; readingSegmentID = nil; zoomedImage = nil }
        .onChange(of: scenePhase) { _, phase in
            // P-083: native r2 narration continues in the background (the mini player owns that rule); r1 stops it.
            if NativeR2Flags.storyFlow { if phase != .active { zoomedImage = nil }; return }
            audioPresentationID = UUID(); if phase != .active { audioURL = nil; zoomedImage = nil }
        }
        .onDisappear { audioMounted = false; audioURL = nil; audioPresentationID = UUID(); advancedVariables = [:]; dirtyNodes = []; zoomedImage = nil }
        // P-082: native r2 reads in the route's domain (no dark route → light reader jump); r1 keeps the player domain.
        .cyDomainScreen(NativeR2Flags.storyFlow ? hostDomain : .player)
    }
    @ViewBuilder private func segmentBody(_ segment: ChapterStorySegment) -> some View {
        switch segment.content {
        case .text(let text) where NativeR2Flags.storyFlow: NR2NarrationText(text: text)
        case .text(let text): Text(verbatim: text).cyText(.body).foregroundStyle(CYColor.textPrimary).lineSpacing(8).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
        case .image(let url):
            ChapterStoryArtwork(url: url, alt: segment.alt, reader: imageReader) { image in zoomedImage = .init(image: image, alt: segment.alt) }
                .id(mediaScope)
        case .audio(let url):
            let selectAudio = scopedAudioSelection()
            VStack(alignment: .leading, spacing: 8) {
                Button("chapterStory.listen", systemImage: "speaker.wave.2") { selectAudio(url) }
                    .disabled(makeAudio == nil)
                if let transcript = segment.alt {
                    // Same-version text of the audio: muted, interrupted or slow audio still gives the evidence.
                    DisclosureGroup {
                        Text(verbatim: transcript).cyText(.body).foregroundStyle(CYColor.textPrimary)
                            .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    } label: { Text("chapterStory.transcript", tableName: "PlayFullStory") }
                    .accessibilityIdentifier("chapterStory.transcript." + segment.id)
                }
            }
        case .divider where NativeR2Flags.storyFlow: Divider().padding(.vertical, 4)
        case .divider:
            Rectangle().fill(CYColor.borderSubtle).frame(height: 1).frame(maxWidth: .infinity).padding(.vertical, 4)
                .accessibilityHidden(true)
        case .unsupported:
            Label { Text("chapterStory.unsupportedBlock", tableName: "PlayFullStory") } icon: { Image(systemName: "square.dashed") }
                .font(CYTypography.caption).foregroundStyle(CYColor.textSecondary)
                .accessibilityIdentifier("chapterStory.unsupported")
        case .voice(let speaker, let text) where NativeR2Flags.storyFlow: NR2VoiceText(speaker: speaker, text: text)
        case .voice(let speaker, let text):
            VStack(alignment: .leading, spacing: 8) {
                if !speaker.isEmpty { Text(verbatim: speaker).font(CYTypography.caption).foregroundStyle(CYColor.textSecondary) }
                Text(verbatim: text).cyText(.body).italic().foregroundStyle(CYColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
            }.frame(maxWidth: .infinity, alignment: .leading).cyDomainCard(radius: CYRadius.md, padding: CYSpacing.lg)
                .accessibilityElement(children: .combine)
        case .reveal(let speaker, let lines):
            DisclosureGroup {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(verbatim: line).padding(.vertical, 4)
                        .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                }
            } label: {
                if speaker.isEmpty { Label("chapterStory.reveal", systemImage: "text.bubble") }
                else { Text(verbatim: speaker) }
            }
        case .dream(let title, let images):
            VStack(alignment: .leading, spacing: 12) {
                if let title { Text(verbatim: title).cyText(.cardTitle).accessibilityAddTraits(.isHeader) }
                ForEach(Array(images.enumerated()), id: \.offset) { _, item in
                    ChapterStoryArtwork(url: item.url, alt: item.line, reader: imageReader) { image in zoomedImage = .init(image: image, alt: item.line) }
                        .id(mediaScope)
                    if let line = item.line, !line.isEmpty {
                        Text(verbatim: line).font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                    }
                }
            }
        case .thought(let name, let description):
            VStack(alignment: .leading, spacing: 8) {
                Label { Text(verbatim: name).cyText(.cardTitle) } icon: { Image(systemName: "lightbulb") }
                if let description {
                    Text(verbatim: description).cyText(.body).foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                }
            }.frame(maxWidth: .infinity, alignment: .leading).cyDomainCard(radius: CYRadius.md, padding: CYSpacing.lg)
                .accessibilityElement(children: .combine)
        case .line(let line) where NativeR2Flags.storyFlow:
            let member = marginMember(line)
            VStack(alignment: .leading, spacing: 6) {
                NR2RoleLineRow(name: marginName(line), text: line.text, member: member,
                               openCard: member.map { picked in { castCard = ChapterStoryCastCard(memberID: picked.id, line: line) } })
                if member != nil || line.audioURL != nil || line.blockKey != nil {
                    CastVoiceButton(line: line, member: member, chapterID: chapterID, cast: castModel,
                                    mediaScope: mediaScope, makeAudio: makeAudio, compact: true)
                        .padding(.leading, member == nil ? 0 : 44)
                }
                CastRememberedLines(members: (castModel?.config).map { config in
                    line.rememberedBy.compactMap { config.member($0) }
                } ?? [])
            }
        case .line(let line):
            let member = marginMember(line)
            VStack(alignment: .leading, spacing: 6) {
                ChapterStoryLineView(name: marginName(line), text: line.text, margin: marginName(line) == nil ? 0 : 72,
                                     onTapName: member.map { picked in { castCard = ChapterStoryCastCard(memberID: picked.id, line: line) } })
                if member != nil || line.audioURL != nil || line.blockKey != nil {
                    CastVoiceButton(line: line, member: member, chapterID: chapterID, cast: castModel,
                                    mediaScope: mediaScope, makeAudio: makeAudio, compact: true)
                }
                CastRememberedLines(members: (castModel?.config).map { config in
                    line.rememberedBy.compactMap { config.member($0) }
                } ?? [])
            }
        case .optionalReading(let subtitle, let paragraphs):
            ChapterOptionalReadingCard(subtitle: subtitle, paragraphs: paragraphs)
        case .choice(let choice):
            VStack(alignment: .leading, spacing: 10) {
                if let question = choice.question {
                    Text(verbatim: question).font(.body).fixedSize(horizontal: false, vertical: true)
                }
                ForEach(Array(choice.options.enumerated()), id: \.offset) { index, option in
                    Button {
                        Task { await castModel?.pick(choice, optionIndex: index) }
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(verbatim: String(index + 1)).font(.body.monospacedDigit()).foregroundStyle(.secondary)
                            Text(verbatim: option.text).font(.body).multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("chapterStory.choice.\(index)")
                }
            }
        case .game(let id):
            if let journey = journeyModel?(id) {
                JourneyRoleViewInlineHost(model: journey.roleContent, sessionIdentity: model.identity,
                    runID: model.snapshot?.route?.sessionID, stateVersion: model.snapshot?.route?.version)
            }
            if let node = model.snapshot?.visibleNodes.first(where: { $0.id == id }),
               node.hasAdvancedPrerequisite, let advanced = advancedModel?(id) {
                PlayInteractionBoundContent(context: model.interactionContext) { advancedContext in
                ChapterStoryGameHost(advanced: advanced, device: deviceModel?(id), mediaScope: mediaScope,
                    makeAudio: makeAudio, approvedArtworkHosts: approvedArtworkHosts, makeSensorProvider: makeSensorProvider, spatialApproval: spatialApproval, fallback: { nodeDestination(id) },
                    variables: { advancedVariables.merge($0) { _, new in new } },
                    ready: { try? model.acceptAdvanced($0, context: advancedContext) },
                    inline: { activeInlineNodeID = id },
                    dirty: { value in if value { dirtyNodes.insert(id) } else { dirtyNodes.remove(id) } })
                }.id(id)
            } else {
                NavigationLink { nodeDestination(id) } label: { Label("chapterStory.play", systemImage: "play.circle") }
            }
        }
    }
    @ViewBuilder private var audioSelection: some View {
        if let selection = PlatformChapterAudioSelection.resolve(snapshot: model.snapshot, nodeID: nodeID, extras: model.extras, currentRead: visible) {
            let selectAudio = scopedAudioSelection()
            VStack(alignment: .leading, spacing: 12) {
                if let url = selection.narrationURL { Button("chapterStory.narration", systemImage: "headphones") { selectAudio(url) } }
                if let url = selection.guideURL { Button("chapterStory.guide", systemImage: "location.circle") { selectAudio(url) } }
            }.disabled(makeAudio == nil)
        }
        if visible { NarrationAutoplayToggle() }
    }
    private func scopedAudioSelection() -> (String) -> Void {
        let expectedIdentity = model.identity
        let expectedPresentationID = audioPresentationID
        return { url in
            guard let expectedIdentity, expectedIdentity == model.identity else { return }
            guard expectedPresentationID == audioPresentationID else { return }
            selectAudio(url)
        }
    }
    private func selectAudio(_ url: String) {
        guard makeAudio != nil else { return }
        // P-083: native r2 also accepts the Lock Screen "next" while in the background.
        guard audioMounted, scenePhase == .active || NativeR2Flags.storyFlow, currentAudioURLs.contains(url) else { return }
        audioURL = url
    }
    private func leave() { if dirtyNodes.isEmpty { dismiss() } else { confirmLeave = true } }
    private var reachedChapters: Set<Int> {
        guard let snapshot = model.snapshot else { return [] }
        return Set(snapshot.visibleNodes.compactMap { snapshot.isDone($0) ? $0.chapterID : nil })
    }
    private func marginName(_ line: ChapterStoryLine) -> String? {
        switch line.speaker {
        case .cast(let id): return castModel?.config?.member(id)?.name
        case .player: return castModel?.profile?.name ?? CastStoryVariables.playerFallback
        case .named(let name): return name
        case nil: return nil
        }
    }
    private func marginMember(_ line: ChapterStoryLine) -> CastMember? {
        if case .cast(let id) = line.speaker { return castModel?.config?.member(id) }
        return nil
    }
}

@MainActor private struct ChapterStoryGameHost: View {
    @Bindable var advanced: PlayAdvancedCoordinator
    let device: PlayDeviceCaptureCoordinator?
    let mediaScope: UUID
    let makeAudio: (@MainActor () -> PlatformAudioPlayback)?
    var approvedArtworkHosts: Set<String> = []
    var makeSensorProvider: (@MainActor () -> any PlayKitSensorProviding)? = nil
    var spatialApproval = PlayKitSpatialApproval()
    let fallback: () -> AnyView
    let variables: ([String: PlayWireValue]) -> Void
    let ready: (PlayAdvancedState) -> Void
    let inline: () -> Void
    let dirty: (Bool) -> Void
    @State private var selection = ChapterInlineKitSelection()
    @State private var hasDraft = false
    @State private var requestedKind: PlayKitScreenKind?
    @State private var confirmSwitch = false
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let state = advanced.state, advanced.isCurrent {
                if state.inline, let kind = selection.selected ?? ChapterInlineKitSelection.preferred(in: state) {
                    kindNavigation(state, current: kind)
                    PlayKitInlineHost(model: advanced, kind: kind, device: device, mediaScope: mediaScope,
                        makeAudio: makeAudio, approvedArtworkHosts: approvedArtworkHosts, reportDirty: { value in
                            // A disappearing previous form must not clear a newer form's draft flag.
                            guard selection.sessionID == state.sessionID, selection.selected == kind else { return }
                            hasDraft = value; dirty(value)
                        }, makeSensorProvider: makeSensorProvider, spatialApproval: spatialApproval)
                        .id("\(state.sessionID):\(kind.rawValue)")
                } else {
                    if state.inline && !state.isMultiplayer && state.config["leaderboard"]["enabled"].bool != true {
                        CYEmptyState(systemImage: "rectangle.slash", "playkit.unavailable")
                    }
                    NavigationLink { fallback() } label: { Label("chapterStory.play", systemImage: "play.circle") }
                }
                if state.inline && (state.isMultiplayer || state.config["leaderboard"]["enabled"].bool == true) {
                    PlayAdvancedInlineTeamHost(model: advanced)
                }
            } else if advanced.phase == "loading" { ProgressView("chapterStory.loadingGame") }
            else {
                if let issue = advanced.issue { PlayExperienceIssueView(issue: issue) }
                Button("chapterStory.loadGame") { Task { await advanced.start() } }
            }
        }
        .task { await advanced.start(); publish() }
        .onChange(of: advanced.state) { _, _ in publish() }
        .confirmationDialog("chapterStory.switchQuestion", isPresented: $confirmSwitch, titleVisibility: .visible) {
            Button("chapterStory.switchDiscard", role: .destructive) {
                if let requestedKind { switchKind(requestedKind) }
                requestedKind = nil
            }
            Button("chapterStory.keepEditing", role: .cancel) { requestedKind = nil }
        } message: { Text("chapterStory.switchBody") }
        .onDisappear { device?.cancel(); dirty(false) }
    }
    @ViewBuilder private func kindNavigation(_ state: PlayAdvancedState, current: PlayKitScreenKind) -> some View {
        let kinds = PlayKitScreenKind.present(in: state)
        if !kinds.isEmpty && (kinds.count > 1 || !kinds.contains(current)) {
            Menu {
                ForEach(kinds) { kind in
                    Button { requestKind(kind) } label: {
                        Label(LocalizedStringKey("playkit.kind." + kind.rawValue), systemImage: kind == current ? "circle.inset.filled" : ChapterInlineKitSelection.complete(kind, in: state) ? "checkmark.circle" : "circle")
                    }
                }
            } label: { Label("chapterStory.chooseTask", systemImage: "list.bullet") }
                .disabled(advanced.pending != nil || advanced.phase != "ready")
                .accessibilityIdentifier("chapterStory.chooseTask")
            if ChapterInlineKitSelection.complete(current, in: state),
               let next = ChapterInlineKitSelection.preferred(in: state, excluding: current) {
                Button("chapterStory.nextTask") { requestKind(next) }
                    .disabled(advanced.pending != nil || advanced.phase != "ready")
                    .accessibilityIdentifier("chapterStory.nextTask")
            }
        }
    }
    private func requestKind(_ kind: PlayKitScreenKind) {
        guard kind != selection.selected, advanced.isCurrent, advanced.pending == nil, advanced.phase == "ready" else { return }
        if hasDraft { requestedKind = kind; confirmSwitch = true }
        else { switchKind(kind) }
    }
    private func switchKind(_ kind: PlayKitScreenKind) {
        guard advanced.isCurrent, advanced.pending == nil, advanced.phase == "ready", let state = advanced.state,
              selection.select(kind, in: state) else { return }
        device?.cancel(); hasDraft = false; dirty(false)
        // Only this local form's identity changes. The authoritative state and pending journal are untouched.
    }
    private func publish() {
        guard advanced.isCurrent, let state = advanced.state else { return }
        if selection.sessionID != state.sessionID { hasDraft = false; requestedKind = nil; confirmSwitch = false; dirty(false) }
        // Keep the frozen action's recovery screen even if a readback removes its segment.
        selection.reconcile(state, preservingDraft: hasDraft || advanced.pending != nil)
        if state.inline { inline() }
        variables(state.storyVariables)
        if state.readyForBase { ready(state) }
    }
}
/// Locked chapter. The same empty state, with the resting ink look on the gate card.
@MainActor private struct ChapterGate: View {
    var body: some View {
        CYEmptyState(systemImage: "lock", "chapterStory.unavailable", detail: "chapterStory.unavailable.detail")
            .cyThemeEdge(mood: nil, odd: 0)
            .accessibilityIdentifier("chapterStory.gate")
    }
}

private struct ChapterSegmentOffsetKey: PreferenceKey {
    static let defaultValue: [String: CGFloat] = [:]
    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) { value.merge(nextValue()) { $1 } }
}
extension ChapterStoryView { static let scrollSpace = "chapterStory.scroll" }

struct ChapterStoryZoomedImage: Identifiable {
    let id = UUID()
    let image: UIImage
    let alt: String?
}

/// U04-04 image zoom: pinch / double-tap, alt text kept as the label, Close always reachable.
@MainActor private struct ChapterStoryImageViewer: View {
    let image: UIImage
    let alt: String?
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @State private var settled: CGFloat = 1
    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ScrollView([.horizontal, .vertical]) {
                    Image(uiImage: image).resizable().scaledToFit()
                        .frame(width: proxy.size.width * scale)
                        .frame(minHeight: proxy.size.height)
                        .accessibilityLabel(alt.map { Text(verbatim: $0) } ?? Text("chapterStory.artwork"))
                        .accessibilityIdentifier("chapterStory.zoom.image")
                }
            }
            .gesture(MagnifyGesture().onChanged { scale = min(4, max(1, settled * $0.magnification)) }.onEnded { _ in settled = scale })
            .onTapGesture(count: 2) { withAnimation(CYMotion.reduced) { scale = scale > 1 ? 1 : 2; settled = scale } }
            .background(CYColor.bgPage.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Text("chapterStory.zoom.close", tableName: "PlayFullStory") }
                        .accessibilityIdentifier("chapterStory.zoom.close")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

@MainActor private struct ChapterStoryArtwork: View {
    let url: String
    var alt: String? = nil
    let reader: (any RetainedPublicImageReading)?
    var zoom: ((UIImage) -> Void)? = nil
    @State private var image: UIImage?
    @State private var loading = false
    @State private var failed = false
    @State private var attempt = 0
    @State private var imageRequestID = UUID()
    @State private var loadedURL: String?
    @Environment(\.scenePhase) private var scenePhase
    private struct RequestKey: Hashable {
        let url: String
        let attempt: Int
        let enabled: Bool
        let active: Bool
    }
    private var requestKey: RequestKey {
        .init(url: url, attempt: attempt, enabled: reader?.enabled == true, active: scenePhase == .active)
    }
    var body: some View {
        Group {
            if !requestKey.enabled || !requestKey.active {
                VStack(alignment: .leading, spacing: 8) {
                    Label("chapterStory.imageGated", systemImage: "photo")
                    if let alt { Text(verbatim: alt).cyText(.body).foregroundStyle(CYColor.textPrimary) }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            else if let image, loadedURL == url {
                Button { zoom?(image) } label: { Image(uiImage: image).resizable().scaledToFit() }
                    .buttonStyle(.plain)
                    .accessibilityLabel(alt.map { Text(verbatim: $0) } ?? Text("chapterStory.artwork"))
                    .accessibilityHint(Text("chapterStory.zoom.hint", tableName: "PlayFullStory"))
                    .accessibilityIdentifier("chapterStory.image")
            }
            else if loading { ProgressView("chapterStory.loadingImage") }
            else if failed {
                // Slow or failed media: the alt text still carries the evidence, and the reader can retry.
                VStack(alignment: .leading, spacing: 8) {
                    Label("chapterStory.imageFailed", systemImage: "photo")
                    if let alt { Text(verbatim: alt).cyText(.body).foregroundStyle(CYColor.textPrimary) }
                    Button { attempt += 1 } label: { Text("chapterStory.image.retry", tableName: "PlayFullStory") }
                        .accessibilityIdentifier("chapterStory.image.retry")
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            else {
                VStack(alignment: .leading, spacing: 8) {
                    Label("chapterStory.imageGated", systemImage: "photo")
                    if let alt { Text(verbatim: alt).cyText(.body).foregroundStyle(CYColor.textPrimary) }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }.frame(maxWidth: .infinity).clipShape(RoundedRectangle(cornerRadius: 18))
        .task(id: requestKey) {
            guard !Task.isCancelled else { return }
            let captured = requestKey
            let requestID = UUID()
            imageRequestID = requestID
            image = nil; loadedURL = nil; failed = false; loading = false
            guard captured.enabled, captured.active, let reader, let source = URL(string: captured.url) else { return }
            loading = true
            defer { if imageRequestID == requestID { loading = false } }
            do {
                let bytes = try await reader.image(url: source)
                try Task.checkCancellation()
                guard imageRequestID == requestID else { return }
                guard captured == requestKey else { return }
                let sanitized = try RetainedImageSanitizer.sanitize(bytes)
                try Task.checkCancellation()
                guard imageRequestID == requestID else { return }
                guard captured == requestKey else { return }
                guard let decoded = UIImage(data: sanitized.jpeg) else {
                    if imageRequestID == requestID && captured == requestKey { failed = true }
                    return
                }
                loadedURL = captured.url; image = decoded
            } catch { if imageRequestID == requestID && captured == requestKey && !Task.isCancelled { failed = true } }
        }.onDisappear { imageRequestID = UUID(); image = nil; loadedURL = nil; loading = false; failed = false }
    }
}

/// F06 「到站自动播放」. The preference is read by playback when P2 wires `autoplaySelectedNarration`.
public struct NarrationAutoplayToggle: View {
    @AppStorage(PlatformNarrationAutoplayPreference.storageKey) private var enabled = PlatformNarrationAutoplayPreference.defaultValue
    public init() {}
    public var body: some View {
        Toggle("platform.audio.autoplay", isOn: $enabled)
            .font(.body)
            .accessibilityIdentifier("platform.audio.autoplay")
    }
}

/// 「延伸阅读」. Collapsed until the reader opens it. Shared with the journey ending chapter.
public struct ChapterOptionalReadingCard: View {
    public let subtitle: String?
    public let paragraphs: [String]
    public init(subtitle: String?, paragraphs: [String]) {
        self.subtitle = subtitle
        self.paragraphs = paragraphs
    }
    public var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, text in
                    Text(verbatim: text).font(.body).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text("chapterStory.optionalReading").font(.headline)
                if let subtitle { Text(verbatim: subtitle).font(.subheadline).foregroundStyle(.secondary) }
            }
        }
        .accessibilityIdentifier("chapterStory.optionalReading")
    }
}

private struct ChapterStoryCastCard: Identifiable, Equatable {
    let memberID: String
    let line: ChapterStoryLine?
    var id: String { memberID }
}

/// Flat fill of the route's own chapter colour. No glow.
private struct ChapterAtmosphereFill: View {
    let atmosphere: ProjectChapterAtmosphere
    init(_ atmosphere: ProjectChapterAtmosphere) { self.atmosphere = atmosphere }
    var body: some View {
        CYPackedRGB.color(atmosphere.backgroundRGB)
    }
}

/// White chapters stay light. Every other painted chapter is the night reading scheme.
private struct ChapterAtmosphereScheme: ViewModifier {
    let atmosphere: ProjectChapterAtmosphere?
    func body(content: Content) -> some View {
        if let atmosphere {
            content.environment(\.colorScheme, atmosphere == .white ? .light : .dark)
        } else {
            content
        }
    }
}

/// One fade, staggered at most 40ms, capped at six steps. Reduce Motion is already settled by the caller.
private struct ChapterReadingReveal: ViewModifier {
    let index: Int
    let settled: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        let step = CYMotion.Stagger.rewrite.dropFirst().first ?? 0.04
        content
            .opacity(settled || reduceMotion ? 1 : 0)
            .animation(reduceMotion ? nil : .easeOut(duration: CYMotion.Duration.quick).delay(Double(min(index, 6)) * step), value: settled)
    }
}

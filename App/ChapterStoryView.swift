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
    let nodeDestination: (Int) -> AnyView
    @State private var advancedVariables: [String: PlayWireValue] = [:]
    @State private var dirtyNodes = Set<Int>()
    @State private var confirmLeave = false
    @State private var activeInlineNodeID: Int?
    @State private var audioURL: String?
    /// Chapter opening gate (mini-program chapter-gate): once per visit of this chapter.
    @State private var showGate = false
    @State private var gateSeen = false
    /// U04-04 reading resume: the segment at the top of the viewport, restored once per visit.
    @State private var readingSegmentID: String?
    @State private var resumeTried = false
    @State private var zoomedImage: ChapterStoryZoomedImage?
    private let readingStore = ChapterReadingPositionStore()
    private var readingKey: String? {
        ChapterReadingPositionStore.key(runIdentity: model.identity, contentVersion: model.contentVersion, chapterID: chapterID)
    }
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    private var chapter: ChapterStoryDocument? { model.chapterStories[chapterID] }
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
            thoughts: model.storyThoughts, storyVoices: model.storyVoices, activeInlineNodeID: activeInlineNodeID)
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
    var body: some View {
        ScrollViewReader { reader in
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if visible, let chapter {
                    if let title = chapter.title { CYHeroHeader(verbatim: title) }
                    if segments.isEmpty { CYEmptyState(systemImage: "book.closed", "chapterStory.empty") }
                    ForEach(segments) { segment in
                        segmentBody(segment)
                            .cyThemeEdge(mood: segment.mood, odd: segment.odd)
                            .frame(maxWidth: .infinity, alignment: .leading)
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
                    if model.thoughtSyncPhase == .syncing { ProgressView("chapterStory.thought.syncing") }
                    if model.thoughtSyncPhase == .disabled { Text("chapterStory.thought.disabled").font(.footnote).foregroundStyle(.secondary) }
                    if model.thoughtSyncPhase == .needsReadback {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("chapterStory.thought.readback")
                            Button("playx.refresh") { Task { await model.load() } }
                        }.accessibilityIdentifier("chapterStory.thought.readback")
                    }
                    audioSelection
                    if audioURL != nil { PlatformAudioHost(rawURL: audioURL, scope: mediaScope, makeModel: makeAudio) }
                    if let progress = chapterProgress, progress.done == progress.total {
                        if let closing = chapter.closingLine {
                            Text(verbatim: closing).font(CYTypography.body).italic().foregroundStyle(CYColor.textSecondary)
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
                        Text("chapterStory.end").font(CYTypography.meta).foregroundStyle(CYColor.textTertiary)
                        CYPillButton("chapterStory.return") { leave() }
                    }
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
            }.padding(CYSpacing.pageHorizontal).frame(maxWidth: 720).frame(maxWidth: .infinity)
        }
        .coordinateSpace(.named(Self.scrollSpace))
        .onPreferenceChange(ChapterSegmentOffsetKey.self) { offsets in
            // The last segment whose top has reached the upper band is where the reader is.
            let order = segments.map(\.id)
            let reached = order.last { (offsets[$0] ?? .infinity) <= 120 } ?? order.first
            guard let reached, reached != readingSegmentID, resumeTried else { return }
            readingSegmentID = reached
            readingStore.save(reached, key: readingKey)
        }
        .task(id: "\(readingKey ?? ""):\(segments.count)") {
            guard !resumeTried, visible, !segments.isEmpty else { return }
            resumeTried = true
            await Task.yield()
            if let target = ChapterReadingPositionStore.resumeTarget(saved: readingStore.read(readingKey), rendered: segments.map(\.id)) {
                reader.scrollTo(target, anchor: .top)
            }
        }
        }
        .fullScreenCover(item: $zoomedImage) { item in ChapterStoryImageViewer(image: item.image, alt: item.alt) }
        .background(CYColor.bgPage.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("chapterStory.title").navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(!dirtyNodes.isEmpty)
        .toolbar {
            if !dirtyNodes.isEmpty {
                ToolbarItem(placement: .topBarLeading) { Button("chapterStory.back", systemImage: "chevron.left") { leave() } }
            }
        }
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
        .onAppear { if !gateSeen && visible && chapter != nil { gateSeen = true; showGate = true } }
        .onChange(of: visible) { _, now in if now && !gateSeen && chapter != nil { gateSeen = true; showGate = true } }
        .privacySensitive().accessibilityIdentifier("chapterStory.body")
        .interactiveDismissDisabled(!dirtyNodes.isEmpty)
        .confirmationDialog("chapterStory.discardQuestion", isPresented: $confirmLeave, titleVisibility: .visible) {
            Button("chapterStory.discard", role: .destructive) { dirtyNodes = []; dismiss() }
            Button("chapterStory.keepEditing", role: .cancel) {}
        } message: { Text("chapterStory.discardBody") }
        .task(id: "\(model.identity ?? ""):chapter=\(chapterID)") { if visible { await model.claimVisibleThoughts(chapterID: chapterID) } }
        .onChange(of: model.snapshot) { _, _ in if visible { Task { await model.claimVisibleThoughts(chapterID: chapterID) } } }
        .onChange(of: model.storyVariables) { _, next in advancedVariables.merge(next) { _, new in new } }
        .onChange(of: model.identity) { _, _ in advancedVariables = [:]; dirtyNodes = []; activeInlineNodeID = nil; audioURL = nil; resumeTried = false; readingSegmentID = nil }
        .onChange(of: scenePhase) { _, phase in if phase != .active { audioURL = nil } }
        .onDisappear { audioURL = nil; advancedVariables = [:]; dirtyNodes = [] }
        .cyDomainScreen(.player)
    }
    @ViewBuilder private func segmentBody(_ segment: ChapterStorySegment) -> some View {
        switch segment.content {
        case .text(let text): Text(verbatim: text).font(CYTypography.body).foregroundStyle(CYColor.textPrimary).lineSpacing(8).textSelection(.enabled)
        case .image(let url):
            ChapterStoryArtwork(url: url, alt: segment.alt, reader: imageReader) { image in zoomedImage = .init(image: image, alt: segment.alt) }
        case .audio(let url):
            VStack(alignment: .leading, spacing: 8) {
                Button("chapterStory.listen", systemImage: "speaker.wave.2") { audioURL = url }
                if let transcript = segment.alt {
                    // Same-version text of the audio: muted, interrupted or slow audio still gives the evidence.
                    DisclosureGroup {
                        Text(verbatim: transcript).font(CYTypography.body).foregroundStyle(CYColor.textPrimary)
                            .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    } label: { Text("chapterStory.transcript", tableName: "PlayFullStory") }
                    .accessibilityIdentifier("chapterStory.transcript." + segment.id)
                }
            }
        case .divider:
            Rectangle().fill(CYColor.borderSubtle).frame(height: 1).frame(maxWidth: .infinity).padding(.vertical, 4)
                .accessibilityHidden(true)
        case .unsupported:
            Label { Text("chapterStory.unsupportedBlock", tableName: "PlayFullStory") } icon: { Image(systemName: "square.dashed") }
                .font(CYTypography.caption).foregroundStyle(CYColor.textSecondary)
                .accessibilityIdentifier("chapterStory.unsupported")
        case .voice(let speaker, let text):
            VStack(alignment: .leading, spacing: 8) {
                if !speaker.isEmpty { Text(verbatim: speaker).font(CYTypography.caption).foregroundStyle(CYColor.textSecondary) }
                Text(verbatim: text).font(CYTypography.body).italic().foregroundStyle(CYColor.textPrimary)
            }.frame(maxWidth: .infinity, alignment: .leading).cyDomainCard(radius: CYRadius.md, padding: CYSpacing.lg)
        case .reveal(let speaker, let lines):
            DisclosureGroup {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in Text(verbatim: line).padding(.vertical, 4) }
            } label: {
                if speaker.isEmpty { Label("chapterStory.reveal", systemImage: "text.bubble") }
                else { Text(verbatim: speaker) }
            }
        case .dream(let title, let images):
            VStack(alignment: .leading, spacing: 12) {
                if let title { Text(verbatim: title).font(.headline) }
                ForEach(Array(images.enumerated()), id: \.offset) { _, item in
                    ChapterStoryArtwork(url: item.url, alt: item.line, reader: imageReader) { image in zoomedImage = .init(image: image, alt: item.line) }
                    if let line = item.line, !line.isEmpty { Text(verbatim: line).font(.subheadline) }
                }
            }
        case .thought(let name, let description):
            VStack(alignment: .leading, spacing: 8) {
                Label { Text(verbatim: name).font(CYTypography.cardTitle) } icon: { Image(systemName: "lightbulb") }
                if let description { Text(verbatim: description).font(CYTypography.body).foregroundStyle(CYColor.textSecondary) }
            }.frame(maxWidth: .infinity, alignment: .leading).cyDomainCard(radius: CYRadius.md, padding: CYSpacing.lg)
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
            VStack(alignment: .leading, spacing: 12) {
                if let url = selection.narrationURL { Button("chapterStory.narration", systemImage: "headphones") { audioURL = url } }
                if let url = selection.guideURL { Button("chapterStory.guide", systemImage: "location.circle") { audioURL = url } }
            }
        }
    }
    private func leave() { if dirtyNodes.isEmpty { dismiss() } else { confirmLeave = true } }
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
    var body: some View {
        Group {
            if let image {
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
                    if let alt { Text(verbatim: alt).font(CYTypography.body).foregroundStyle(CYColor.textPrimary) }
                    Button { attempt += 1 } label: { Text("chapterStory.image.retry", tableName: "PlayFullStory") }
                        .accessibilityIdentifier("chapterStory.image.retry")
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            else {
                VStack(alignment: .leading, spacing: 8) {
                    Label("chapterStory.imageGated", systemImage: "photo")
                    if let alt { Text(verbatim: alt).font(CYTypography.body).foregroundStyle(CYColor.textPrimary) }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }.frame(maxWidth: .infinity).clipShape(RoundedRectangle(cornerRadius: 18))
        .task(id: "\(url)#\(attempt)") {
            image = nil; failed = false
            guard let reader, reader.enabled, let source = URL(string: url) else { return }
            loading = true
            defer { loading = false }
            do {
                let bytes = try await reader.image(url: source)
                let sanitized = try RetainedImageSanitizer.sanitize(bytes)
                try Task.checkCancellation(); image = UIImage(data: sanitized.jpeg)
            } catch { if !Task.isCancelled { failed = true } }
        }.onDisappear { image = nil }
    }
}

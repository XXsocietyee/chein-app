import SwiftUI

/// A frozen action review is the only write outlet for all specialized native kits.
typealias PlayKitReviewRequest = (String, [String: PlayWireValue], @escaping () -> Void) -> Void

/// `.sheet` is the mini-program sheet over the pack: the kit is the one sheet on screen, so its
/// review shows as a panel inside it rather than a second sheet stacked on top.
enum PlayKitNativePresentation: Equatable { case navigation, inline, sheet }

@MainActor struct PlayKitScreen: View {
    @Bindable var model: PlayAdvancedCoordinator
    let kind: PlayKitScreenKind
    var presentation: PlayKitNativePresentation = .navigation
    var reportDirty: ((Bool) -> Void)? = nil
    var device: PlayDeviceCaptureCoordinator? = nil
    var mediaScope: UUID = UUID()
    var makeAudio: (@MainActor () -> PlatformAudioPlayback)? = nil
    // Empty by default. Backend/device/media acceptance is independent of having UI.
    var approvedArtworkHosts: Set<String> = []
    var makeSensorProvider: (@MainActor () -> any PlayKitSensorProviding)? = nil
    var spatialApproval = PlayKitSpatialApproval()
    /// Override for the accusation confirm. Nil publishes the existing SUBMIT_QA review when UG-03 is publishable.
    var ugAccusationWrite: PlayKitAccusationWrite? = nil
    @State var text = ""
    @State var selected = Set<String>()
    @State var answers: [String: String] = [:]
    @State var profileStep = 0
    @State var avatarURL = ""
    @State var dirty = false
    @State var reasoningFeedback = PlayKitReasoningFeedbackState()
    @State var review: PlayKitActionReview?
    @State var reviewedCompletion: (() -> Void)?
    @State var issue: PlayExperienceError?
    @State var leaveReview = false
    @State var childReset = UUID()
    @State var sessionIdentity: Int?
    @State var loaded = false
    @State var lifetime = UUID()
    // Native r2 games (App/NativeR2/Games): result sheet, sort/match drafts and the child kit's bottom-bar action.
    @State var nativeResultShown = false
    @State var nativeExpectResult = false
    @State var nativeOrder: [String] = []
    @State var nativePlacement: [String: String] = [:]
    @State var nativeIndex: Int?
    @State var nativeChildSubmit: NativeGameSubmit?
    @Environment(\.dismiss) var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.offlineWriteSession) var offlineWriteSession
    @Environment(\.analyticsEventClient) private var analytics
    @Environment(\.playGameStage) var stage
    @Environment(\.nativeGameHelp) var nativeHelp
    @Environment(\.questifyCast) var castContext
    @QuestifyReduceMotion private var reduceMotion
    private var segment: PlayWireValue {
        guard let state = model.state else { return .null }
        return ChapterInlineKitSelection.segment(kind, in: state)
    }
    var projection: PlayKitScreenProjection { .init(kind: kind, segment: segment) }
    var raw: PlayWireValue { segment }
    var runtimeIdentity: String { model.state.map { "\($0.sessionID):\($0.version)" } ?? "" }
    var enabled: Bool { model.canInteract && !projection.complete && review == nil }
    var body: some View {
        screenContainer
        .scrollDismissesKeyboard(.interactively)
        .modifier(PlayKitScreenChrome(presentation: presentation, kind: kind, dirty: dirty, native: usesNativeGame, close: {
            if dirty { leaveReview = true } else { dismiss() }
        }))
        .privacySensitive()
        .cySheet(item: stackedReview) { item in
            NavigationStack {
                Form {
                    Section { reviewReadback(item) }
                    Section {
                        reviewConfirm(item)
                            .frame(maxWidth: .infinity)
                            .listRowBackground(Color.clear)
                    }
                }.cyGroupedSurface().navigationTitle("playkit.submitQuestion")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("playkit.cancel") { review = nil; reviewedCompletion = nil } } }
            }.privacySensitive()
            .cyDomainSheet(detents: [.half, .full])
        }
        .safeAreaInset(edge: .bottom) {
            if presentation == .sheet, !usesNativeGame, let item = review { reviewPanel(item) }
        }
        // N-KIT-DARK: system confirmation dialog for discarding an unsaved answer.
        .confirmationDialog(Text("playkit.discardQuestion"), isPresented: $leaveReview, titleVisibility: .visible) {
            Button("playkit.discard", role: .destructive) { leaveReview = false; clearTransient(); dismiss() }
            Button("playkit.keepEditing", role: .cancel) { leaveReview = false }
        } message: {
            Text("playkit.discardBoundary")
        }
        .onAppear {
            loadInitial()
            PlayStageAnalytics.track(analytics, .stageEnter, nodeID: model.state?.nodeID, kit: kind.rawValue)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: CYMotion.Duration.quick), value: showsStoryResult)
        .onChange(of: model.playKitPresentation.playKitOpen) { _, open in
            if !open { review = nil; reviewedCompletion = nil }
        }
        .onChange(of: dirty) { _, next in reportDirty?(next) }
        .onChange(of: model.state?.sessionID) { _, next in
            if sessionIdentity != next { clearTransient(); sessionIdentity = next; loaded = false; loadInitial() }
        }
        .onChange(of: model.isCurrent) { _, current in if !current { clearTransient() } }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                review = nil; reviewedCompletion = nil
                if phase == .background || device?.isAuthorizing != true { device?.cancel() }
                // Specialized children own interruption semantics. Destroying a sensor
                // child on OS-permission inactivity would cancel its first-use grant.
                if phase == .background { childReset = UUID() }
            }
        }
        .onDisappear { clearTransient() }
    }
    /// A nested review sheet only when the kit itself is not already the sheet.
    private var stackedReview: Binding<PlayKitActionReview?> {
        // Native r2 games: the review is always its own sheet over the game (the shell owns the bottom bar).
        Binding(get: { presentation == .sheet && !usesNativeGame ? nil : review }, set: { review = $0 })
    }
    @ViewBuilder private func reviewReadback(_ item: PlayKitActionReview) -> some View {
        if let question = item.compareQuestion { PlayCompareReview(question: question, marked: (item.payload["marked"]?.array ?? []).compactMap(\.text)) }
        else { PlayKitPayloadReadback(payload: item.payload) }
    }
    private func reviewConfirm(_ item: PlayKitActionReview) -> some View {
        Button("playkit.confirm") {
            let completion = reviewedCompletion
            let expectedLifetime = lifetime
            review = nil; reviewedCompletion = nil
            Task {
                let submitted = await SessionOfflineSyncModel.shared.performWriteOptIn(
                    environmentSession: offlineWriteSession.session,
                    routes: ["/api/play/advanced/action"],
                    explicitKey: item.id.uuidString
                ) {
                    await model.submit(item)
                }
                if submitted, lifetime == expectedLifetime { issue = nil; dirty = false; completion?() }
            }
        }
            .buttonStyle(.borderedProminent)
            .disabled(!model.canInteract || model.state?.version != item.version || model.state?.sessionID != item.sessionID)
            .accessibilityIdentifier("playkit.review.confirm")
    }
    /// Review inside the kit sheet: same readback and confirm, docked at the bottom.
    private func reviewPanel(_ item: PlayKitActionReview) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            HStack {
                Text("playkit.submitQuestion").cyText(.cardTitle).accessibilityAddTraits(.isHeader)
                Spacer()
                Button("playkit.cancel") { review = nil; reviewedCompletion = nil }
                    .accessibilityIdentifier("playkit.review.cancel")
            }
            reviewReadback(item)
            reviewConfirm(item).frame(maxWidth: .infinity)
        }
        .padding(CYSpacing.lg)
        .background(RoundedRectangle(cornerRadius: CYRadius.sheet, style: .continuous).fill(CYColor.bgElevated).ignoresSafeArea(edges: .bottom))
        .privacySensitive()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("playkit.review.panel")
    }
    @ViewBuilder private var screenContainer: some View {
        if usesNativeGame { nativeGameContainer }
        else if presentation == .inline { contents }
        else {
            ScrollView { contents.padding().frame(maxWidth: 720).frame(maxWidth: .infinity) }
                .accessibilityIdentifier("playkit.screen." + kind.rawValue)
        }
    }
    private var showsStoryResult: Bool { PlayGameOutcome.resolve(projection) != nil }
    private var contents: some View {
        VStack(alignment: .leading, spacing: 24) {
            if let stage { PlayGameStageHeader(stage: stage) }
            if let source = PlayKitReferenceImage.source(in: segment) {
                PlayKitReferenceButton(source: source, alt: PlayKitReferenceImage.alt(in: segment),
                    approvedHosts: approvedArtworkHosts, nodeID: model.state?.nodeID, kit: kind.rawValue)
            }
            PlayKitIssueReportMenu(nodeID: model.state?.nodeID, kit: kind.rawValue)
            header
            CYScreenOfflineWriteBanner(
                routes: ["/api/play/advanced/action"],
                session: offlineWriteSession.session
            )
            if let issue { PlayExperienceIssueView(issue: issue) }
            if let modelIssue = model.issue { PlayExperienceIssueView(issue: modelIssue) }
            if !model.isCurrent { Text("playkit.sessionChanged") }
            else if segment.object == nil { CYEmptyState(systemImage: "rectangle.slash", "playkit.unavailable") }
            else { content; authoritativeResult }
            recovery
        }
    }
    @ViewBuilder private var header: some View {
        // Mini-program kits open with a small kicker line above the title.
        if let eyebrow = segment["eyebrow"].text?.trimmingCharacters(in: .whitespacesAndNewlines), !eyebrow.isEmpty, eyebrow != projection.title {
            Text(verbatim: eyebrow).cyText(.meta).foregroundStyle(.secondary)
                .accessibilityIdentifier("playkit.eyebrow." + kind.rawValue)
        }
        if !projection.title.isEmpty { Text(verbatim: projection.title).cyText(.pageTitle).fixedSize(horizontal: false, vertical: true) }
        ForEach(["lead", "prompt", "hint", "sub"], id: \.self) { key in
            if let value = segment[key].text, !value.isEmpty { Text(verbatim: value).foregroundStyle(.secondary) }
        }
        if let state = model.state, state.deadlineAt != nil {
            // No server clock on the play payload, so this does not tick from the phone.
            Label {
                Text(verbatim: "—")
                    .cyText(.dataXL).monospacedDigit()
            } icon: { Image(systemName: "timer") }
            .foregroundStyle(Color.primary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("playkit.sessionRemaining"))
            .accessibilityValue(Text(verbatim: "—"))
        }
    }
    @ViewBuilder private var content: some View {
        switch kind {
        case .qa:
            if let accusation = accusationProjection {
                PlayKitAccusationView(projection: accusation, approvedHosts: approvedArtworkHosts, enabled: enabled, showsTitle: false,
                    accuse: accusationWrite, close: presentation == .inline ? nil : { dismiss() })
            } else { qaForm }
        case .trueFalse: trueFalseForm
        case .imageGuess: imageGuessForm
        case .jigsaw: jigsawForm
        case .scratchCard: scratchCardForm
        case .branch: branchForm
        case .estimate: estimateForm
        case .pricePair: pricePairForm
        case .hiddenObject: hiddenObjectForm
        case .predict: predictForm
        case .profile: profileForm
        case .note: noteForm
        case .photoCheck: photoCheckForm
        case .scan: scanForm
        case .bingo: bingoBoard
        case .walk: walkProgress
        case .steps:
            NativeStepsHostView(advanced: model, segment: raw)
        case .coinFlip: coinFace
        case .diceRoll: diceFaces
        case .dailySign: dailySignForm
        case .random: randomDeck
        case .reaction, .countdown, .stopwatch, .typeIn:
            PlayKitTimedChallengeView(kind: kind, segment: segment, enabled: enabled, active: model.isCurrent,
                onDirty: { dirty = true }, requestReview: prepare,
                revisionIdentity: runtimeIdentity, currentRevisionIdentity: { model.state.map { "\($0.sessionID):\($0.version)" } ?? "" })
                .id(childReset)
        case .sort, .match, .classify: reasoningForm
        case .compare:
            PlayCompareView(segment: segment, revision: runtimeIdentity, enabled: enabled,
                currentRevision: { runtimeIdentity }, onDirty: { dirty = true }, requestReview: prepare)
                .id(childReset)
        case .blindTaste, .diyName, .silentOrder, .slowTask, .musicCorner, .timeWindow: legacyBody
        case .ballShake, .quietHold, .compass, .shout:
            PlayKitSensorChallengeView(kind: kind, segment: segment, enabled: enabled, active: model.isCurrent,
                onDirty: { dirty = true }, requestReview: prepare,
                revisionIdentity: runtimeIdentity, currentRevisionIdentity: { model.state.map { "\($0.sessionID):\($0.version)" } ?? "" },
                makeSensorProvider: makeSensorProvider)
                .id(childReset)
        }
    }
    /// UG-03 publishes through prepare("SUBMIT_QA"). A second action name is not used.
    /// Internal so the native accusation kit (App/NativeR2/Games/NativeGameKitsC.swift) publishes through the same write.
    var accusationWrite: PlayKitAccusationWrite? {
        if let ugAccusationWrite { return ugAccusationWrite }
        guard UGGameplay.accusationPublishable else { return nil }
        return { id in prepare(PlayKitPublishedWrites.accusationAction, PlayKitPublishedWrites.accusationDetail(optionID: id)) }
    }
    /// UG-03: a PICK qa whose node turned accusation on. Its end screen reads the server verdict itself.
    var accusationProjection: PlayKitAccusationProjection? {
        kind == .qa ? model.state.flatMap(PlayKitAccusationProjection.project) : nil
    }
    @ViewBuilder var authoritativeResult: some View {
        if reasoningFeedback.showsResult(for: projection), accusationProjection == nil {
            let recordedChoice = PlayKitNoRightAnswer.applies(kind: kind, segment: segment) && projection.reportedPass != nil
            if recordedChoice {
                Label("playkit.story.recorded", systemImage: "bookmark.circle")
            } else if kind == .photoCheck, segment["degraded"].bool == true {
                Label("playkit.photo.noVerdict", systemImage: "exclamationmark.bubble")
            } else if let passed = projection.reportedPass {
                Label(passed ? "playkit.result.passed" : "playkit.result.notPassed", systemImage: passed ? "checkmark.circle" : "info.circle")
            } else if projection.complete { Label("playkit.result.recorded", systemImage: "checkmark.circle") }
            if let outcome = PlayGameOutcome.resolve(projection) {
                PlayGameResultLine(outcome: outcome, open: !projection.complete)
            }
            if let feedback = projection.feedback, !feedback.isEmpty { Text(verbatim: feedback) }
            if presentation != .inline,
               PlayGameOutcome.showsContinue(complete: projection.complete, pending: model.pending != nil, phase: model.phase) {
                CYPillButton("playkit.story.continue") { dismiss() }
                    .accessibilityIdentifier("playkit.story.continue")
            }
        }
    }
    @ViewBuilder private var recovery: some View {
        if model.phase == "submitting" || model.phase == "loading" { ProgressView("playkit.sending") }
        if model.pending != nil { Text("playkit.pendingBoundary").cyText(.bodyCompact).foregroundStyle(.secondary) }
        if model.phase == "unknown" { Button("playkit.reconcile") { Task { await model.recover() } }.accessibilityIdentifier("playkit." + kind.rawValue + ".reconcile") }
        if model.phase == "retryable" { Button("playkit.retryExact") { Task { await model.retryExact() } }.accessibilityIdentifier("playkit." + kind.rawValue + ".retryExact") }
        if model.pending == nil && model.isCurrent && model.phase != "submitting" {
            Button("playkit.refresh") { Task { await model.refreshAuthoritative() } }.accessibilityIdentifier("playkit." + kind.rawValue + ".refresh")
        }
    }
    func prepare(_ action: String, _ payload: [String: PlayWireValue] = [:], _ completion: @escaping () -> Void = {}) {
        do { review = try model.review(kind: kind.rawValue, action: action, detail: payload); reviewedCompletion = completion; issue = nil; model.openPlayKitSheet() }
        catch { issue = error as? PlayExperienceError ?? .invalidAction }
    }
    func submitButton(_ action: String, payload: [String: PlayWireValue], valid: Bool = true) -> some View {
        Button("playkit.review") { prepare(action, payload) }
            .buttonStyle(.borderedProminent).disabled(!enabled || !valid)
            .accessibilityIdentifier("playkit.submit." + kind.rawValue)
    }
    func artwork(_ url: String?) -> some View {
        PlayKitArtwork(source: url, approvedHosts: approvedArtworkHosts)
    }
    func textBinding(limit: Int = 4096) -> Binding<String> {
        Binding(get: { text }, set: { text = PlayKitInputContract.limitText($0, toUTF16: max(1, limit)); dirty = true })
    }
    private func loadInitial() {
        guard !loaded else { return }; loaded = true; sessionIdentity = model.state?.sessionID
        if kind == .note { text = segment["mine"].text ?? segment["mine"]["text"].text ?? "" }
        if kind == .qa { text = segment["acceptedInput"].text ?? segment["lastInput"].text ?? "" }
        if kind == .diyName { text = segment["name"].text ?? "" }
        if kind == .dailySign { text = segment["myText"].text ?? "" }
        if kind == .profile { answers = (segment["answers"].object ?? [:]).compactMapValues(\.text); avatarURL = segment["avatarUrl"].text ?? "" }
    }
    private func clearTransient() {
        if kind == .photoCheck { model.clearObjectCardReceipt() }
        lifetime = UUID(); review = nil; reviewedCompletion = nil; text = ""; selected = []; answers = [:]; avatarURL = ""; profileStep = 0
        dirty = false; reasoningFeedback = .init(); childReset = UUID(); device?.cancel()
        nativeResultShown = false; nativeExpectResult = false; nativeOrder = []; nativePlacement = [:]; nativeIndex = nil; nativeChildSubmit = nil
    }
}

@MainActor struct PlayKitPayloadReadback: View {
    let payload: [String: PlayWireValue]
    /// Shows what the player chose, never the request field names.
    var body: some View {
        ForEach(payload.keys.sorted(), id: \.self) { key in
            if let value = payload[key], value != .null {
                Text(verbatim: display(value)).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
            }
        }
    }
    private func display(_ value: PlayWireValue) -> String {
        switch value {
        case .string(let text): return text
        case .integer(let number): return String(number)
        case .number(let number): return String(number)
        case .bool(let value): return String(value)
        case .array(let values): return values.map(display).joined(separator: ", ")
        case .object(let values): return values.keys.sorted().map { "\($0): \(display(values[$0]!))" }.joined(separator: "\n")
        case .null: return "—"
        }
    }
}

/// Transport is permitted only for independently approved exact hosts. No account
/// headers, arbitrary scheme, local file path or hard-coded media origin is accepted.
@MainActor struct PlayKitArtwork: View {
    let source: String?; let approvedHosts: Set<String>
    var alt: String? = nil
    @State private var attempt = 0
    var body: some View {
        if let url = QuestifyCardArtwork.safeURL(source), let host = url.host, approvedHosts.contains(host) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit()
                        .accessibilityLabel(alt.map { Text(verbatim: $0) } ?? Text("playkit.image"))
                }
                else if phase.error != nil {
                    ContentUnavailableView {
                        Label("playkit.imageUnavailable", systemImage: "photo.badge.exclamationmark")
                    } actions: {
                        Button("playkit.imageRetry") { attempt += 1 }
                            .accessibilityIdentifier("playkit.imageRetry")
                    }
                }
                else { PlayGameImagePlaceholder(titleKey: "playkit.imageLoading", loading: true) }
            }
            .id(attempt)
        } else if source?.isEmpty == false {
            PlayGameImagePlaceholder(titleKey: "playkit.imageGated", systemImage: "photo")
        }
    }
}

private struct PlayKitScreenChrome: ViewModifier {
    let presentation: PlayKitNativePresentation; let kind: PlayKitScreenKind; let dirty: Bool
    /// Native r2 games: `NativeGameShell` draws its own title, close and hint buttons.
    var native = false
    let close: () -> Void
    @ViewBuilder func body(content: Content) -> some View {
        if presentation == .inline { content }
        else if native {
            if presentation == .sheet {
                content.cyDomainScreen(.game).cyHideTabBar(true)
            } else {
                content.cyGuardedBack(when: dirty, onBack: close).cyDomainScreen(.game).cyHideTabBar(true)
            }
        }
        else if presentation == .sheet {
            // A sheet has no back: 关闭 is its exit (with the unsaved-answer review when dirty).
            content.navigationTitle(Text(LocalizedStringKey("playkit.kind." + kind.rawValue)))
                .navigationBarTitleDisplayMode(.inline)
                .cyDomainScreen(domain)
                .tint(tint)
                .cyHideTabBar(true)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("playkit.close", action: close).accessibilityIdentifier("playkit.close") } }
        } else {
            // Pushed: the system back; only unsaved answers route it through the review (cyGuardedBack).
            content.navigationTitle(Text(LocalizedStringKey("playkit.kind." + kind.rawValue)))
                .navigationBarTitleDisplayMode(.inline)
                .cyGuardedBack(when: dirty, onBack: close)
                .cyDomainScreen(domain)
                .tint(tint)
                .cyHideTabBar(true)
        }
    }
    /// N-KIT-DARK (MP pages/playkit/components/*): only the focused stage (`isFocusedStage`) stays on the dark game
    /// domain; form kits (profile, note, photoCheck, dailySign, diyName, steps, timeWindow, branch, estimate, predict,
    /// pricePair, compare, …) follow the system Light/Dark setting with the system accent.
    private var domain: ThemeDomain { kind.isFocusedStage ? .game : .player }
    private var tint: Color { kind.isFocusedStage ? CYColor.gameAccent : Color.accentColor }
}

/// Actual story-flow body: no nested ScrollView, List, navigation container or chrome.
@MainActor struct PlayKitInlineHost: View {
    let model: PlayAdvancedCoordinator; let kind: PlayKitScreenKind
    var device: PlayDeviceCaptureCoordinator? = nil
    var mediaScope: UUID = UUID()
    var makeAudio: (@MainActor () -> PlatformAudioPlayback)? = nil
    var approvedArtworkHosts: Set<String> = []
    var reportDirty: ((Bool) -> Void)? = nil
    var makeSensorProvider: (@MainActor () -> any PlayKitSensorProviding)? = nil
    var spatialApproval = PlayKitSpatialApproval()
    var body: some View {
        PlayKitScreen(model: model, kind: kind, presentation: .inline, reportDirty: reportDirty,
            device: device, mediaScope: mediaScope, makeAudio: makeAudio, approvedArtworkHosts: approvedArtworkHosts, makeSensorProvider: makeSensorProvider, spatialApproval: spatialApproval)
    }
}

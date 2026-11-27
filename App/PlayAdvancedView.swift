import SwiftUI

@MainActor struct PlayAdvancedView: View {
    @Bindable var model: PlayAdvancedCoordinator
    var device: PlayDeviceCaptureCoordinator? = nil
    var mediaScope: UUID = UUID()
    var makeAudio: (@MainActor () -> PlatformAudioPlayback)? = nil
    var approvedArtworkHosts: Set<String> = []
    var makeSensorProvider: (@MainActor () -> any PlayKitSensorProviding)? = nil
    var spatialApproval = PlayKitSpatialApproval()
    /// Override for SUBMIT_HANGMAN. Nil uses the advanced-action review on this screen.
    var ugHangmanWrite: PlayKitHangmanWrite? = nil
    /// Override for accusation. Nil lets the qa screen publish SUBMIT_QA when UG-03 is publishable.
    var ugAccusationWrite: PlayKitAccusationWrite? = nil
    /// Override for album completion. Nil uploads one photo, then posts SUBMIT_ALBUM.
    var albumComplete: (() -> Void)? = nil
    /// Hangman title fallback: station question, then place name. Pass text is the solved line when the kit has none.
    var stationQuestion: String? = nil
    var stationName: String? = nil
    var stationPassText: String? = nil
    let onReady: (PlayAdvancedState) -> Void
    @State private var teamSurfaceID = UUID()
    @State private var teamSurfaceVisible = false
    @State private var continueReason: String?
    /// The one playkit sheet over the pack. Opening another replaces it; closing the panel closes it.
    @State private var openKit: PlayAdvancedKitSheet?
    @State private var kitDirty = false
    @State private var albumCapture = false
    @State private var showingAlbumRetry = false
    @State private var toastMessage: String?
    @Environment(\.locale) private var locale
    @Environment(\.nativePlatformRuntime) private var nativePlatform
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.offlineWriteSession) private var offlineWriteSession
    @AppStorage(PlatformBGMPreference.storageKey) private var stationBGMOn = PlatformBGMPreference.defaultValue
    @ViewBuilder var body: some View {
        Group {
            if !model.hasCurrentReadLifetime { Text("playMode.recoveryBlocked") }
            else { currentContent }
        }
        // PLAY-r11-1: station 背景音乐 (`playKit.backgroundMusic`, MP pages/play/index.js:4175-4192, :1513-1518).
        .task(id: PlayThemeMusicKey(url: model.state?.playKit["backgroundMusic"]["audioUrl"].text, enabled: stationBGMOn)) {
            let music = model.state?.playKit["backgroundMusic"]
            PlayBackgroundMusic.shared.syncStation(rawURL: music?["audioUrl"].text, loop: music?["loop"].bool != false,
                                                   enabled: stationBGMOn, approvedHosts: approvedArtworkHosts)
        }
        .onDisappear { PlayBackgroundMusic.shared.stopStation() }
    }
    private var currentContent: some View {
        List {
            Section {
                LabeledContent("playx.state") { PlayRuntimePhaseText(phase: model.phase) }
                if let issue = model.issue { PlayExperienceIssueView(issue: issue) }
                if model.state == nil && ["idle", "rejected", "disabled"].contains(model.phase) { CYPillButton("playx.advanced.start") { Task { await model.start() } }.listRowBackground(Color.clear) }
                if model.state != nil && model.pending == nil { CYPillButton("playx.refresh", style: .secondary) { Task { await model.refreshAuthoritative() } }.listRowBackground(Color.clear) }
                if model.phase == "unknown" {
                    CYPillButton("playx.reconcile", style: .secondary) {
                        Task {
                            await SessionOfflineSyncModel.shared.performWriteOptIn(
                                environmentSession: offlineWriteSession.session,
                                routes: ["/api/play/advanced/action"]
                            ) {
                                await model.recover()
                            }
                        }
                    }.listRowBackground(Color.clear)
                }
                if model.phase == "retryable" {
                    CYPillButton("playx.retryExact", style: .tertiary) {
                        Task {
                            await SessionOfflineSyncModel.shared.performWriteOptIn(
                                environmentSession: offlineWriteSession.session,
                                routes: ["/api/play/advanced/action"]
                            ) {
                                await model.retryExact()
                            }
                        }
                    }.listRowBackground(Color.clear)
                }
            }
            CYScreenOfflineWriteSection(
                routes: ["/api/play/advanced/action"],
                session: offlineWriteSession.session
            )
            if let receipt = model.modInstallationActionReceipt, let requestID = model.modInstallationActionKey {
                ModInstallationNativeActionReceiptView(receipt: receipt, requestID: requestID)
            }
            if model.state == nil, nativePlatform?.acceptance.localRemindersEnabled == true {
                Section { NativeTimeWindowHostView(advanced: model, segment: .null) }
            }
            if let state = model.state {
                Section("playx.advanced.authority") {
                    // Mini-program summary strip: status word, then the score.
                    HStack(spacing: CYSpacing.xl) {
                        let phase = state.status.lowercased()
                        if PlayAdvancedStatusWord.known.contains(phase) { PlayRuntimePhaseText(phase: phase) }
                        else { Text(verbatim: state.status.isEmpty ? "—" : state.status) }
                        if let score = state.score { Text("playx.advanced.scoreLine \(score)").monospacedDigit() }
                    }
                    .cyText(.body)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("playx.advanced.summary")
                    if state.deadlineAt != nil {
                        LabeledContent("playx.advanced.remaining") { Text(verbatim: "—") }
                    }
                    if state.readyForBase {
                        CYPillButton("playx.advanced.continue") {
                            let ready = model.pending == nil && model.isCurrent && model.phase == "ready"
                            if let reason = DisabledCallToAction.reason(enabled: ready) {
                                continueReason = reason
                                return
                            }
                            continueReason = nil
                            onReady(state)
                            dismiss()
                        }
                            .listRowBackground(Color.clear)
                            .accessibilityIdentifier("playx.advanced.continue")
                        if let continueReason {
                            Text(verbatim: continueReason)
                                .cyText(.bodyCompact)
                                .accessibilityIdentifier("playx.advanced.continue.reason")
                        }
                    }
                }
                ForEach(PlayKitScreenKind.present(in: state)) { kind in
                    Section {
                        kitRow(.screen(kind), title: state.playKit[kind.rawValue]["title"].text,
                               recorded: PlayKitScreenProjection(kind: kind, segment: state.playKit[kind.rawValue]).complete)
                    }
                }
                if state.playKit["hangman"].object != nil {
                    Section { kitRow(.hangman, title: state.playKit["hangman"]["title"].text, recorded: state.playKit["hangman"]["solved"].bool == true) }
                }
                if state.playKit["album"].object != nil {
                    Section { kitRow(.album, title: state.playKit["album"]["title"].text, recorded: state.playKit["album"]["done"].bool == true) }
                }
                // Existing non-screen kits remain explicitly distinct from this migration.
                ForEach((state.playKit.object ?? [:]).keys.filter { PlayKitScreenKind(rawValue: $0) == nil && !PlayAdvancedKitSheet.ownKeys.contains($0) }.sorted(), id: \.self) { kind in
                    Section {
                        Text(verbatim: state.playKit[kind]["title"].text ?? kind).cyText(.cardTitle)
                        if let description = state.playKit[kind]["description"].text { Text(verbatim: description) }
                        Text("playx.advanced.specialGate").cyText(.bodyCompact)
                    }
                }
                if state.isMultiplayer {
                    Section("playx.advanced.roles") { PlayAdvancedTeamControls(model: model, surfaceID: teamSurfaceID) }
                }
                if state.config["leaderboard"]["enabled"].bool == true {
                    Section("advancedBoard.title") { PlayAdvancedLeaderboardView(model: model, surfaceID: teamSurfaceID) }
                }
            }
        }.cyGroupedSurface().privacySensitive().navigationTitle("playx.advanced").accessibilityIdentifier("playx.advanced.view")
        .onAppear { teamSurfaceVisible = true; model.beginTeamSurface(id: teamSurfaceID) }
        .task(id: model.state?.version) { await model.loadAdvancedLeaderboard(surfaceID: teamSurfaceID) }
        .onDisappear { teamSurfaceVisible = false; model.endTeamSurface(id: teamSurfaceID); model.closeAdvancedPanel() }
        .cySheet(item: $openKit, onDismiss: { kitDirty = false; albumCapture = false; model.closePlayKitSheet() }) { sheet in
            NavigationStack { kitSheet(sheet) }
                .cyDomainSheet(detents: sheet.halfSheet ? [.half, .full] : [.full])
                .interactiveDismissDisabled(kitDirty)
        }
        .cyModalOverlay(isPresented: showingAlbumRetry) {
            PlayKitAlbumRetryModal(
                onCancel: { showingAlbumRetry = false },
                onConfirm: {
                    showingAlbumRetry = false
                    albumCapture = true
                }
            )
        }
        .cyToast(verbatimMessage: $toastMessage)
        .onChange(of: model.playKitPresentation.playKitOpen) { _, open in if !open { openKit = nil } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { model.endTeamSurface(id: teamSurfaceID) }
            else if phase == .active && teamSurfaceVisible { model.beginTeamSurface(id: teamSurfaceID); Task { await model.loadAdvancedLeaderboard(surfaceID: teamSurfaceID) } }
        }
    }
}

extension PlayAdvancedView {
    private func kitRow(_ sheet: PlayAdvancedKitSheet, title: String?, recorded: Bool) -> some View {
        Button {
            openKit = sheet
            model.openPlayKitSheet()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(LocalizedStringKey("playkit.kind." + sheet.key)).cyText(.cardTitle)
                    if let title, !title.isEmpty { Text(verbatim: title).font(.subheadline) }
                    if recorded { Text("playkit.result.recorded").cyText(.meta) }
                }
                Spacer(minLength: CYSpacing.sm)
                Image(systemName: "chevron.up").font(.footnote.weight(.semibold)).foregroundStyle(CYColor.textTertiary).accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("playkit.open." + sheet.key)
    }

    @ViewBuilder private func kitSheet(_ sheet: PlayAdvancedKitSheet) -> some View {
        switch sheet {
        case .screen(let kind):
            PlayKitScreen(model: model, kind: kind, presentation: .sheet, reportDirty: { kitDirty = $0 }, device: device, mediaScope: mediaScope,
                makeAudio: makeAudio, approvedArtworkHosts: approvedArtworkHosts, makeSensorProvider: makeSensorProvider, spatialApproval: spatialApproval,
                ugAccusationWrite: ugAccusationWrite)
        case .hangman:
            Group {
                if let segment = model.state?.playKit["hangman"], segment.object != nil {
                    if let issue = model.issue { PlayExperienceIssueView(issue: issue) }
                    PlayKitHangmanView(projection: PlayKitHangmanProjection(segment: segment), enabled: model.canInteract,
                        stationQuestion: stationQuestion, stationName: stationName, stationPassText: stationPassText,
                        submit: ugHangmanWrite ?? hangmanWrite, close: { openKit = nil },
                        segment: segment, nodeID: model.state?.nodeID)
                        .padding()
                } else { CYEmptyState(systemImage: "rectangle.slash", "playkit.unavailable") }
            }
            .modifier(PlayAdvancedKitSheetChrome(key: sheet.key, close: { openKit = nil }))
        case .album:
            Group {
                if let state = model.state, let album = PlayKitAlbumProjection(state: state) {
                    ScrollView {
                        if NativeR2Flags.games {
                            CameraAlbumView(projection: album, approvedHosts: approvedArtworkHosts, complete: albumComplete ?? albumFinish, close: { openKit = nil })
                        } else {
                            PlayKitAlbumView(projection: album, approvedHosts: approvedArtworkHosts, complete: albumComplete ?? albumFinish, close: { openKit = nil })
                        }
                        albumCapturePanel
                        if let issue = model.issue { PlayExperienceIssueView(issue: issue).padding(.horizontal) }
                    }
                } else { CYEmptyState(systemImage: "rectangle.slash", "playkit.unavailable") }
            }
            .modifier(PlayAdvancedKitSheetChrome(key: sheet.key, close: { openKit = nil }))
        }
    }

    /// SUBMIT_HANGMAN through the advanced review. An unknown result keeps the saved request id.
    private var hangmanWrite: PlayKitHangmanWrite {
        { payload in
            Task {
                await SessionOfflineSyncModel.shared.performWriteOptIn(
                    environmentSession: offlineWriteSession.session,
                    routes: ["/api/play/advanced/action"]
                ) {
                    await model.submit(kind: PlayKitPublishedWrites.hangmanKind, action: PlayKitPublishedWrites.hangmanAction, detail: payload)
                }
            }
        }
    }

    /// R5 albums that are not done open the photo step. An in-flight unknown SUBMIT_ALBUM does not start another.
    private var albumFinish: (() -> Void)? {
        guard model.phase != "unknown", model.pending?.action != PlayKitPublishedWrites.albumAction,
              let state = model.state, let album = PlayKitAlbumProjection(state: state),
              album.completionEnabled, !album.done, model.canInteract else { return nil }
        return { albumCapture = true }
    }

    @ViewBuilder private var albumCapturePanel: some View {
        if model.phase == "unknown", let pending = model.pending, pending.action == PlayKitPublishedWrites.albumAction {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                Text("playkit.pendingBoundary")
                Text(verbatim: pending.key).cyText(.meta).textSelection(.enabled)
                    .accessibilityIdentifier("playkit.album.requestId")
                Button("playkit.reconcile") {
                    Task {
                        await SessionOfflineSyncModel.shared.performWriteOptIn(
                            environmentSession: offlineWriteSession.session,
                            routes: ["/api/play/advanced/action"]
                        ) {
                            await model.recover()
                        }
                    }
                }
                    .accessibilityIdentifier("playkit.album.reconcile")
                Button {
                    showingAlbumRetry = true
                } label: {
                    Text(verbatim: PlayCloseCopy.text("查看/重试审核", "View / retry review", locale))
                }
                .accessibilityIdentifier("playkit.album.retryReview")
            }
            .padding(.horizontal)
            .accessibilityIdentifier("playkit.album.unknown")
        } else if albumCapture {
            Group {
                if let device {
                    PlayKitPhotoInput(model: device, identity: albumIdentity, enabled: model.canInteract && model.pending == nil,
                                      onDirty: { kitDirty = true }, onURL: submitAlbum(url:))
                } else {
                    Label("playkit.camera.gated", systemImage: "camera")
                }
            }
            .padding(.horizontal)
            .accessibilityIdentifier(device == nil || device?.issue != nil ? "playkit.album.uploadFailed" : "playkit.album.upload")
        }
    }

    private var albumIdentity: String { "\(model.state?.sessionID ?? -1):\(model.state?.version ?? -1):album" }

    /// Upload failure stays failed and does not post. A ready https URL posts SUBMIT_ALBUM.
    private func submitAlbum(url: String) {
        guard model.pending == nil, model.phase != "unknown",
              case .ready(let accepted) = PlayAlbumUploadOutcome.resolve(url: url, issue: device?.issue) else { return }
        Task {
            await model.submit(kind: PlayKitPublishedWrites.albumKind, action: PlayKitPublishedWrites.albumAction,
                               detail: PlayKitPublishedWrites.albumDetail(imageURL: accepted))
        }
    }
}

/// Which playkit sits in the sheet over the advanced pack.
enum PlayAdvancedKitSheet: Identifiable, Equatable {
    case screen(PlayKitScreenKind), hangman, album
    /// playKit keys with their own native sheet outside PlayKitScreenKind.
    static let ownKeys: Set<String> = ["hangman", "album"]
    var key: String {
        switch self {
        case .screen(let kind): return kind.rawValue
        case .hangman: return "hangman"
        case .album: return "album"
        }
    }
    var id: String { key }
    private static let halfSheetKinds: Set<PlayKitScreenKind> = [.timeWindow, .blindTaste, .silentOrder, .diyName, .musicCorner, .steps, .dailySign, .slowTask]
    /// The mini-program v5.1 kits open as a half sheet over the pack; the full-screen kits use the whole sheet.
    var halfSheet: Bool {
        guard case .screen(let kind) = self else { return false }
        return Self.halfSheetKinds.contains(kind)
    }
}

private struct PlayAdvancedKitSheetChrome: ViewModifier {
    let key: String; let close: () -> Void
    func body(content: Content) -> some View {
        content.navigationTitle(Text(LocalizedStringKey("playkit.kind." + key)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("playkit.close", action: close).accessibilityIdentifier("playkit.close") } }
            .accessibilityIdentifier("playkit.screen." + key)
    }
}

enum PlayAdvancedStatusWord {
    /// Server statuses that have a localized playx.phase word.
    static let known: Set<String> = ["running", "completed", "paused", "ended", "failed", "idle", "ready", "done"]
}

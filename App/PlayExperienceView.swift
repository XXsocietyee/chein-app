import SwiftUI
import MapKit

/// Integration entry for migrated runtime. Factories are scope-specific, optional, and
/// never create provider/network permissions as a side effect of opening the screen.
@MainActor struct PlayExperienceView: View {
    @Bindable var model: PlayExperienceCoordinator
    var deviceModel: ((Int) -> PlayDeviceCaptureCoordinator)? = nil
    var advancedModel: ((Int) -> PlayAdvancedCoordinator?)? = nil
    var motionModel: ((Int, PlayStillnessConfiguration) -> PlayStillnessCoordinator?)? = nil
    var preferenceModel: ((Int) -> PlayPreferenceCoordinator?)? = nil
    var summaryModel: ((Int) -> PlayOperatingSummaryCoordinator?)? = nil
    var playerModel: PlayPlayerGameCoordinator? = nil
    var circleModel: PlayCircleCoordinator? = nil
    var openingModel: PlayOpeningCompletionCoordinator? = nil
    var finishRouteModel: PlayFinishRouteRecommendationCoordinator? = nil
    var finishRouteDestination: ((Int) -> AnyView)? = nil
    var themeRecordsModel: PlayThemeRecordsCoordinator? = nil
    var backpackModel: PlayThemeBackpackCoordinator? = nil
    var teamBackpackModel: PlayTeamBackpackCoordinator? = nil
    var entryCode: PlayEntryCodeContext? = nil
    /// W20 city business game on the real CITY read (`AppSession.playCityGame`). Nil (no CITY lease or no board) hides it.
    var cityGameModel: CityGameCoordinator? = nil
    var prefabModel: PlayPrefabRuntimeCoordinator? = nil
    var journeyModel: ((Int) -> JourneyCheckCoordinator?)? = nil
    var ambientModel: JourneyAmbientCoordinator? = nil
    var narrativeModel: ((JourneyNarrativeQuery) -> JourneyNarrativeCoordinator?)? = nil
    var narrativeImageReader: (any RetainedPublicImageReading)? = nil
    var shopNPCModel: ((Int) -> ShopNPCNodeHost?)? = nil
    var invalidateShopNPC: (() -> Void)? = nil
    var storeDayModel: ((Int) -> PlayStoreDayCoordinator?)? = nil
    /// Team run only: the shared hint pool for a stop (contract §4). Nil outside a team run.
    var teamPoolModel: ((Int) -> TeamPoolHintModel?)? = nil
    var mediaScope: UUID = UUID()
    var makeAudio: (@MainActor () -> PlatformAudioPlayback)? = nil
    var makeExternalMaps: (@MainActor () -> PlatformExternalMaps)? = nil
    var approvedArtworkHosts: Set<String> = []
    var makeSensorProvider: (@MainActor () -> any PlayKitSensorProviding)? = nil
    var spatialApproval = PlayKitSpatialApproval()
    var rewardCollectionDestination: ((PlayRewardBadgeTarget) -> AnyView)? = nil
    /// Session attachment. Nil leaves the map on the ids this view already holds.
    var routeActionRead: RouteActionPageReadRequest? = nil
    @State private var selectedNode: Int?
    /// 提示 on the play HUD (401:4731): the stop opens with its hint ladder already up. Cleared once it is used.
    @State private var hintNode: Int?
    /// 背包 on the play HUD: the theme (or team) backpack pushed over the play map.
    @State private var showBackpack = false
    /// PLAY-1: MP 章节结算 half sheet (journey/stage-end) when a chapter's last place is done; 底部 = 继续.
    @State private var stageSettlement: PlayStageSettlementTarget?
    @State private var settledChapters: Set<Int>?
    @State private var showRouteMap = false
    @State private var confirmEnd = false
    @State private var presentedMode: PlayGameplayMode?
    @State private var presentationMount = PlayExperiencePresentationMount()
    /// Run-complete medal screen (mini-program medal-screen); shown once per session when the run completes.
    @State private var finishScreen = false
    /// U08-01: the finish-screen result word comes from the server battle report, not local completion.
    @State private var finishReport: (any JourneyReportBinding)?
    @State private var finishShownFor: String?
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette
    /// 切换章节: nil shows every chapter's places.
    @State private var chapterFilter: Int?
    @State private var showChapterPicker = false
    @State private var showEmergencyHelp = false
    /// PLAY-6a: MP 游玩工具 preferences sheet (pages/play/index.wxml 游玩工具).
    @State private var showPlayTools = false
    @AppStorage(PlatformBGMPreference.storageKey) private var playBGMOn = PlatformBGMPreference.defaultValue
    @AppStorage(PlatformNarrationAutoplayPreference.storageKey) private var playNarrationOn = PlatformNarrationAutoplayPreference.defaultValue
    @AppStorage(PlayReducedMotionPreference.storageKey) private var playReducedMotion = false
    @State private var titleCardTopic: Int?
    /// Cast for this run. Nil until a nodes read carries cast. Capabilities stay empty.
    @State private var castModel: CastCoordinator?
    @State private var castPlaybillSeen = false
    @State private var castCover = false
    @State private var showingCastRoster = false
    @State private var runTeamPool: TeamPoolHintModel?
    /// Native r2 city orientation (`NativeR2Flags.cityOrientation`): foreground position, the run sheet,
    /// teams mirrored from `TeamTrailSection`, the punch sheet and the end dialog.
    @StateObject private var cityLocation = CityOrientationLocationObserver()
    @State private var cityRunSheet = false
    @State private var cityTeams: [TeamTrailTeam] = []
    @State private var cityPunchNode: CityOrientationPunchTarget?
    /// P-056: the stop whose hint ladder is open over the run map.
    @State private var cityHintNode: CityOrientationHintTarget?
    @State private var cityEndDialog = false
    /// Native r2 route page: the chapter whose reader is pushed (Continue or a chapter row).
    @State private var nr2ReaderChapter: Int?
    @Environment(\.playThemePresentationReader) private var themeReader
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.mpParity) private var mpParity
    @Environment(\.externalGameSession) private var externalGameSession
    private func chapterTitle(_ name: String?) -> String {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "—" : trimmed
    }
    private func journeyRunScope(_ topicID: Int?, _ topicName: String?) -> JourneyRunScope {
        var scope = JourneyRunScope(topicID: topicID.map(String.init), topicName: topicName)
        if case .activity(let id) = model.scope { scope.activityID = String(id) }
        // Contract §5 item 17: a team run carries its play_team id, which opens the in-team (队内) board on report/settle.
        scope.teamID = model.snapshot?.result.teamID.map(String.init)
        return scope
    }
    /// Split from body so the type checker handles the modifier chain in parts.
    private var navigationLayer: some View {
        Group {
            if model.gameplayMode == .freeExploration || (model.snapshot == nil && presentedMode == .freeExploration) {
                if NativeR2Flags.freeExplore {
                    NativeFreeExploreMapView(model: model, storeDestination: { AnyView(freeStoreDestination($0)) },
                                             rewardCollectionDestination: rewardCollectionDestination,
                                             castConfig: castModel?.config, castEnding: model.castPayload,
                                             makeExternalMaps: makeExternalMaps, mediaScope: mediaScope,
                                             arrivalLocation: RuntimeNativeLocationProvider(enabled: true))
                } else {
                    FreeExplorationExperienceView(model: model, storeDestination: { AnyView(freeStoreDestination($0)) }, rewardCollectionDestination: rewardCollectionDestination, castConfig: castModel?.config, castEnding: model.castPayload)
                }
            } else if model.gameplayMode == .cityOrientation {
                if NativeR2Flags.cityOrientation { cityOrientationNative } else { orientationContent.cyThemeLook(themeFacts?.look) }
            } else if model.snapshot == nil {
                if model.phase == .loading {
                    CYSkeleton().padding(CYSpacing.lg).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .accessibilityIdentifier("playMode.loading")
                } else {
                    VStack(spacing: CYSpacing.md) {
                        if model.available {
                            CYEmptyState(systemImage: "exclamationmark.triangle", "playx.error.title", actionTitle: "playx.refresh") {
                                if model.phase != .submitting { Task { await model.load() } }
                            }
                            if let issue = model.issue { PlayExperienceIssueView(issue: issue) }
                        } else {
                            CYEmptyState(systemImage: "gamecontroller", "playx.disabled.title")
                            Text("playx.disabled").font(CYTypography.bodyCompact).foregroundStyle(CYColor.textSecondary)
                                .accessibilityIdentifier("playx.disabled")
                        }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else { CYEmptyState(systemImage: "questionmark.circle", "playMode.unavailable") }
        }
        .environment(\.questifyCast, castModel?.context)
        .privacySensitive()
        // N-PLAY-DARK: system Light/Dark and the system accent (player domain) for every play mode.
        .cyDomainScreen(screenDomain)
        .cyPushedChrome(domain: screenDomain)
        .tint(Color.accentColor)
        .appNavigationTitle(key: model.gameplayMode == .freeExploration ? "playFree.title" : "playx.title")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedNode) { id in
            nodeDestination(id, opensHelp: hintNode == id)
                .cyPushedChrome(domain: screenDomain)
        }
        .onChange(of: selectedNode) { _, id in if id == nil { hintNode = nil } }
        .navigationDestination(item: $nr2ReaderChapter) { chapterID in
            nr2ReaderDestination(chapterID)
        }
        .navigationDestination(isPresented: $showBackpack) {
            backpackDestination.cyPushedChrome(domain: screenDomain)
        }
        .navigationDestination(isPresented: $showRouteMap) {
            PlayRouteMapView(
                model: model,
                nodeDestination: { AnyView(nodeDestination($0)) },
                actionRead: routeActionRead ?? heldRouteActionRead)
                .cyPushedChrome(domain: screenDomain)
        }
    }
    private var presentationLayer: some View {
        navigationLayer
        .toolbar {
            if castModel?.config != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    CastRosterButton { showingCastRoster = true }
                }
            }
            // The play HUD carries the channel as its 队伍 circle; elsewhere it stays in the bar.
            if let scope = playChannelScope, hudStop == nil {
                ToolbarItem(placement: .topBarTrailing) {
                    InGameChannelToolbarButton(
                        scope: scope,
                        titleKey: playChannelTitleKey,
                        accessibilityID: "ingame.channel.play.entry",
                        reloadTrigger: model.snapshot?.result.teamID ?? 0
                    )
                }
            }
        }
        .cyModalConfirm(
            isPresented: confirmEnd,
            title: appLocalized("playx.run.end", locale: locale),
            message: appLocalized("playx.run.end.detail", locale: locale),
            cancelTitle: appLocalized("playx.cancel", locale: locale),
            confirmTitle: appLocalized("playx.run.end", locale: locale),
            isDestructive: true,
            onCancel: { confirmEnd = false },
            onConfirm: {
                confirmEnd = false
                Task { await model.endRun(now: ProcessInfo.processInfo.systemUptime, savedAt: Self.milliseconds) }
            }
        )
        .cySheet(isPresented: $showEmergencyHelp) {
            PlayEmergencyHelpSheet()
                .cyPlayerSheetGlass()
                .cyDomainSheet(detents: [.half, .full])
        }
        .sheet(isPresented: $showPlayTools) { playToolsSheet }
        .cySheet(isPresented: $showChapterPicker) {
            if let snapshot = model.snapshot {
                PlayChapterPickerSheet(rows: PlayChapterPickRow.rows(snapshot), current: chapterFilter) { picked in
                    withAnimation(CYMotion.standard) { chapterFilter = picked }
                }
                .cyPlayerSheetGlass()
                .cyDomainSheet(detents: [.half, .full])
            }
        }
        .overlay { titleCardOverlay }
        .onChange(of: doneChapterIDs, initial: true) { _, done in
            // The first read only records what was already settled; a chapter finishing in this visit opens the sheet.
            guard let previous = settledChapters else { settledChapters = done; return }
            settledChapters = done
            if let chapterID = done.subtracting(previous).sorted().first, narrativeModel?(.stage(chapterID: chapterID)) != nil {
                stageSettlement = PlayStageSettlementTarget(chapterID: chapterID)
            }
        }
        .cySheet(item: $stageSettlement) { target in
            if let narrative = narrativeModel?(.stage(chapterID: target.chapterID)) {
                NavigationStack {
                    JourneyNarrativeView(model: narrative, imageReader: narrativeImageReader, makeAudio: makeAudio, mediaScope: mediaScope)
                        .safeAreaInset(edge: .bottom) {
                            Button { stageSettlement = nil } label: { Text("playx.stage.continue").frame(maxWidth: .infinity) }
                                .buttonStyle(.cyPrimary(fullWidth: true))
                                .padding(.horizontal, CYSpacing.pageHorizontal).padding(.vertical, CYSpacing.md)
                                .background(.bar)
                                .accessibilityIdentifier("playx.stage.continue")
                        }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }
    var body: some View {
        presentationLayer
        .onChange(of: model.snapshot?.result.topicID) { _, topicID in
            chapterFilter = nil
            presentTitleCardIfNeeded(topicID)
        }
        .onChange(of: model.chapterStories.count) { _, _ in presentTitleCardIfNeeded(model.snapshot?.result.topicID) }
        .task(id: model.snapshot?.result.teamID ?? model.snapshot?.result.topicID) {
            if let next = teamPoolModel?(0) {
                next.onPoolUpdated = { _ in }
                await next.load()
                runTeamPool = next.isVisible ? next : nil
            } else {
                runTeamPool = nil
            }
        }
        .task(id: PlayExperiencePresentationKey(model: model)) {
            // This task also restarts when returning from a pushed store. Preserve
            // the same owner's mode host through refresh so its open card pack survives.
            if presentationMount.enter(model) { selectedNode = nil; presentedMode = nil }
            await model.load()
            // E2E-20261113b: the mode can switch to city orientation before the snapshot is ready, when restoreRun's
            // guard still fails, so the run record was never read and Start did nothing. Restore once the load is done.
            if model.gameplayMode == .cityOrientation { await model.restoreRun(); projectAmbient() }
        }
        .onChange(of: model.gameplayMode) { _, mode in
            let previous = presentedMode
            if let mode { presentedMode = mode }
            if mode == .cityOrientation, previous != .cityOrientation {
                Task { await model.restoreRun(); projectAmbient() }
            }
            if let mode, mode != .cityOrientation { selectedNode = nil; confirmEnd = false }
        }
        .onChange(of: model.gameplayMode) { _, mode in
            if let mode, mode != .cityOrientation { showRouteMap = false }
        }
        .onChange(of: PlayExperiencePresentationKey(model: model)) { _, _ in showRouteMap = false; showChapterPicker = false; showEmergencyHelp = false }
        .onChange(of: model.snapshot?.result) { _, _ in if model.gameplayMode == .cityOrientation { projectAmbient() } }
        .onChange(of: model.snapshot) { _, _ in invalidateShopNPC?() }
        .onChange(of: model.snapshot?.availability) { old, new in
            // Present only on the live transition into completed, never for a run that was already complete on open.
            guard model.gameplayMode == .cityOrientation, old == .active, new == .completed,
                  model.hasCurrentMediaSnapshot, finishShownFor != model.identity else { return }
            finishShownFor = model.identity; finishScreen = true
        }
        .cyFullScreenCover(isPresented: $finishScreen) {
            if NativeR2Flags.cityOrientation { cityFinishSummary } else { finishMedalScreen }
        }
        .onChange(of: finishScreen) { _, shown in
            guard shown, let make = mpParity.journeyReport, let snapshot = model.snapshot else { return }
            let report = make(journeyRunScope(snapshot.result.topicID, snapshot.result.topicName))
            finishReport = report
            report.load()
        }
        .onChange(of: model.hasCurrentMediaSnapshot) { _, current in if !current { invalidateShopNPC?() } }
        .modifier(PlayExperienceCastMounts(host: self))
        .modifier(PlaySessionLocationHold(identity: model.identity, running: model.clock.phase == .running,
                                          currentIdentity: { [model] in model.identity }))
        .onChange(of: scenePhase) { _, next in
            if model.gameplayMode == .cityOrientation, next != .active, model.clock.phase == .running {
                Task { await model.pauseRun(now: ProcessInfo.processInfo.systemUptime, savedAt: Self.milliseconds) }
            }
        }
        // P-050: city orientation distance is run-scoped. It keeps reading over pushed pages and, while the run is
        // started and not ended, in the background; the run's end stops it.
        .onChange(of: model.clock.phase, initial: true) { _, phase in syncCityRunTracking(phase) }
    }
    private func syncCityRunTracking(_ phase: PlayRunClock.Phase) {
        guard NativeR2Flags.cityOrientation, model.gameplayMode == .cityOrientation else { return }
        cityLocation.setRunActive(phase == .running || phase == .paused)
        if phase == .ended { cityLocation.stop() }
    }
    private var themeFacts: PlayThemePresentationFacts? {
        model.snapshot?.result.topicID.flatMap { themeReader?.facts(topicID: $0) }
    }
    /// 主题开场标题卡: once per topic on this device, only for a story route (chapters carry story blocks)
    /// or a product that skips the card pack.
    private func presentTitleCardIfNeeded(_ topicID: Int?) {
        guard let topicID, topicID > 0, !PlayThemeTitleCardMemory.seen(topicID), model.hasCurrentMediaSnapshot,
              let snapshot = model.snapshot, (snapshot.result.topicName ?? "").isEmpty == false else { return }
        let story = !model.chapterStories.isEmpty
        let freeWithoutPack = model.gameplayMode == .freeExploration && themeFacts?.skipsCardPack == true
        guard story || freeWithoutPack else { return }
        titleCardTopic = topicID
    }
    @ViewBuilder private var titleCardOverlay: some View {
        // Native r2: the title card is the first section of the route page, not a full-screen overlay.
        if !NativeR2Flags.storyFlow, let topicID = titleCardTopic, let snapshot = model.snapshot, snapshot.result.topicID == topicID {
            PlayThemeTitleCard(title: snapshot.result.topicName ?? "", line: PlayThemeIntro.line(snapshot.result.topicDescription),
                               modeKey: model.gameplayMode == .freeExploration ? "playFree.title" : "mpd.mode.cityOrientation",
                               aiGenerated: themeFacts?.aiGenerated == true, coverURL: themeFacts?.coverURL) {
                PlayThemeTitleCardMemory.markSeen(topicID)
                withAnimation(CYMotion.standard) { titleCardTopic = nil }
            }
            .cyThemeLook(themeFacts?.look)
            .transition(.opacity)
            .zIndex(10)
        }
    }
    /// Action id and route session id already on the completion journal or receipt.
    /// Absent ids leave this read closed. Does not mint either id and does not set an approval.
    private var heldRouteActionRead: RouteActionPageReadRequest? {
        guard let held = model.heldRouteActionIdentity else { return nil }
        return RouteActionPageReadRequest(sessionID: held.routeSessionID, actionID: held.actionID)
    }
    /// Every stop the read makes visible (`PlayStationListPresentation`): done ones as completed,
    /// locked ones as locked, the rest openable. Nothing here filters to the current stop only.
    @ViewBuilder private func stationsSection(_ snapshot: PlaySnapshot) -> some View {
        Section {
            let rows = PlayStationListPresentation.rows(snapshot, chapterID: chapterFilter)
            ForEach(rows) { row in
                if let node = snapshot.visibleNodes.first(where: { $0.id == row.id }) {
                    Button { selectedNode = node.id } label: {
                        VStack(alignment: .leading, spacing: CYSpacing.xs) {
                            CYRouteNodeRow(
                                index: row.position,
                                title: node.name ?? "#\(node.id)",
                                distanceAndETA: [node.address, node.businessTime].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.joined(separator: " · "),
                                requirement: PlayTaskStatusCardMapper.arrivalRequirement(for: node),
                                completion: PlayTaskStatusCardMapper.routeCompletion(row.state),
                                isFirst: row.position == 1,
                                isLast: row.position == rows.count
                            )
                            PlayTaskStatusBadge(node: node, snapshot: snapshot)
                            if let reason = snapshot.lockReason(node) {
                                Text(verbatim: reason).font(CYTypography.caption).foregroundStyle(palette.warning)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, CYSpacing.xs)
                    }.accessibilityIdentifier("playx.node.\(node.id)")
                }
            }
        } header: {
            HStack {
                Text("playx.nodes")
                if let chapterFilter, let chapter = snapshot.result.chapters.first(where: { $0.id == chapterFilter }) {
                    Text(verbatim: "· " + chapterTitle(chapter.name)).cyWrapText()
                    Spacer()
                    Button("mpd.chapters.all") { withAnimation(CYMotion.standard) { self.chapterFilter = nil } }
                        .font(CYTypography.meta).textCase(nil)
                        .accessibilityIdentifier("play.chapterPick.clear")
                }
            }
        }
    }
    private var orientationList: some View {
        List { orientationSections(native: false) }
        .refreshable { if model.available && model.phase != .submitting { await model.load() } }
        .toolbar { orientationToolbar }
        .accessibilityIdentifier("playx.overview")
    }
    /// The run panel sections. `native` (NativeR2Flags.cityOrientation) leaves out the current-goal card and the
    /// station rows, which the native run sheet replaces with its next-stop and legs sections.
    @ViewBuilder private func orientationSections(native: Bool) -> some View {
            if NativeR2Flags.storyFlow, model.hasCurrentMediaSnapshot, let snapshot = model.snapshot, !model.chapterStories.isEmpty {
                NR2StoryRouteSections(snapshot: snapshot, coverURL: themeFacts?.coverURL,
                                      aiGenerated: themeFacts?.aiGenerated == true,
                                      cast: castModel?.config?.cast ?? [],
                                      readableChapterIDs: nr2ReadableChapters(snapshot),
                                      openChapter: { nr2ReaderChapter = $0 },
                                      openCast: castModel?.config == nil ? nil : { showingCastRoster = true })
            }
            // Template 6 order: (1) Current goal + location/arrival + 6-state status + primary CTA FIRST,
            // (2) Progress & runtime header, (3) Ordered stops (`CYRouteNodeRow`) & recovery/records.
            if !native, model.hasCurrentMediaSnapshot, !model.unresolved, let snapshot = model.snapshot,
               let id = PlayTaskSummaryPresentation(snapshot: snapshot).currentNodeID,
               let node = snapshot.visibleNodes.first(where: { $0.id == id }) {
                Section("referenceTask.current") {
                    VStack(alignment: .leading, spacing: CYSpacing.md) {
                        HStack(alignment: .center, spacing: CYSpacing.sm) {
                            CYStatusChip(
                                LocalizedStringKey("playx.task." + PlayNodeTask.resolve(mode: snapshot.result.mode, node: node).rawValue),
                                tone: .info,
                                systemImage: "flag.fill"
                            )
                            CYStatusChip(
                                verbatim: node.arrived == true
                                    ? CoreLoopCopy(locale: locale).t("已到达", "Arrived")
                                    : (node.needGPS == true || node.needScan == true
                                        ? CoreLoopCopy(locale: locale).t("待到达", "Not arrived")
                                        : CoreLoopCopy(locale: locale).t("线上/现场均可", "Flexible")),
                                tone: node.arrived == true ? .success : .neutral,
                                systemImage: node.arrived == true ? "checkmark.circle.fill" : "location.fill"
                            )
                            Spacer(minLength: 0)
                            PlayTaskStatusBadge(node: node, snapshot: snapshot)
                        }
                        if let place = node.address, !place.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Label {
                                Text(verbatim: place)
                                    .fixedSize(horizontal: false, vertical: true)
                            } icon: {
                                Image(systemName: "mappin.and.ellipse")
                                    .foregroundStyle(palette.actionPrimaryBg)
                                    .accessibilityHidden(true)
                            }
                            .font(CYTypography.meta)
                            .foregroundStyle(palette.textSecondary)
                        }
                        CYTaskStatusCard(
                            title: node.name ?? "#\(node.id)",
                            state: PlayTaskStatusCardMapper.state(
                                node: node,
                                snapshot: snapshot,
                                model: model,
                                locale: locale,
                                ctaTitle: appLocalized("referenceTask.open", locale: locale),
                                onOpen: { selectedNode = id },
                                onRefresh: { Task { await model.load() } }
                            )
                        )
                        Button("referenceTask.open") { selectedNode = id }
                            .buttonStyle(.questifyPrimary)
                            .accessibilityIdentifier("referenceTask.open")
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: CYSpacing.xs, leading: 0, bottom: CYSpacing.xs, trailing: 0))
                }
            }
            Section {
                if let snapshot = model.snapshot {
                    PlayTaskSummaryView(snapshot: snapshot, phase: model.phase.rawValue)
                    if let note = snapshot.result.timeNote { Text(verbatim: note).foregroundStyle(palette.textSecondary) }
                }
                if !model.available { Text("playx.disabled").accessibilityIdentifier("playx.disabled") }
                if model.phase == .loading { CYSkeleton().accessibilityIdentifier("playx.loading") }
                if let issue = model.issue { PlayExperienceIssueView(issue: issue) }
                if PlayContentCompatibility.isUnsupportedRejection(model.issue) {
                    // The server refused to open this run for this build; nothing was skipped or started.
                    Text("playCompat.refused.next", tableName: "PlayFullStory").font(CYTypography.caption)
                        .foregroundStyle(palette.textSecondary).accessibilityIdentifier("playCompat.refused")
                }
                PlayResyncAction(model: model)
                if model.hasCurrentMediaSnapshot, let notice = model.routeNotice { PlayRouteNoticeRow(notice: notice) }
                if model.remoteRunSaveFailed { Label("playx.run.saveFailed", systemImage: "exclamationmark.triangle.fill").font(CYTypography.caption).foregroundStyle(palette.warning) }
            }
            // F-05: the ordered stops follow the progress header (Template 6), so every visible stop is
            // reachable in the half-height panel instead of sitting below records and downloads.
            if !native, let snapshot = model.snapshot { stationsSection(snapshot) }
            if let compatibility = model.compatibility, model.hasCurrentMediaSnapshot {
                PlayCompatibilitySection(compatibility: compatibility)
            }
            if let runTeamPool, runTeamPool.isVisible {
                TeamPoolRunStatusSection(model: runTeamPool)
            }
            if let openingModel { PlayOpeningCompletionSection(model: openingModel) }
            if let entryCode { PlayEntryCodeSection(context: entryCode) }
            if let cityGameModel {
                Section { CityGamePanel(model: cityGameModel, read: cityGameModel.read, boardLayout: true) }
                    .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            }
            Section {
                NavigationLink { PlayGapMiscSurfaces() } label: {
                    Text("playGap.entry", tableName: "PlayGapMisc")
                }
                .accessibilityIdentifier("playGap.entry")
            }
            if model.unresolved {
                Section("playx.unknown.title") {
                    Text(LocalizedStringKey(model.hasModeRecoveryBlock ? "playMode.recoveryBlocked" : "playx.unknown.body"))
                    // U05-03: what the original receipt says; checking again re-reads it, never resubmits.
                    if let state = model.submitRecovery { PlaySubmitRecoveryRow(state: state) }
                    Button("playx.reconcile") { Task { await model.load() } }.accessibilityIdentifier("playx.reconcile")
                    if model.canRetryExactBranch {
                        Button("playx.retryExact") { Task { await model.retryExactBranchAfterReadback() } }
                            .accessibilityIdentifier("playx.retryExact")
                    }
                }
            }
            if model.hasCurrentMediaSnapshot, model.available {
                // U05-04: download for this run; the page states what is (not) usable offline.
                Section {
                    NavigationLink {
                        PlayOfflinePackHost(make: {
                            PlayOfflinePackEnvironment.store().flatMap {
                                model.makeOfflinePackModel(store: $0, fetch: PlayOfflinePackEnvironment.fetch(approvedHosts: approvedArtworkHosts))
                            }
                        })
                    } label: {
                        Label { Text("pack.entry", tableName: "PlayRecovery") } icon: { Image(systemName: "arrow.down.circle") }
                    }.accessibilityIdentifier("playRecovery.pack.open")
                }
            }
            if let ambientModel { PlayAmbientView(model: ambientModel) }
            if model.snapshot != nil {
                if let snapshot = model.snapshot, model.hasCurrentMediaSnapshot {
                    Section("journey.record.title") {
                        narrativeLink(.casebook); narrativeLink(.backpack)
                        ForEach(snapshot.result.chapters) { chapter in
                            let nodes = snapshot.visibleNodes.filter { $0.chapterID == chapter.id }
                            if !nodes.isEmpty, nodes.allSatisfy({ snapshot.isDone($0) && !snapshot.isLocked($0) }) {
                                narrativeLink(.stage(chapterID: chapter.id), subtitle: chapter.name)
                            }
                        }
                        if snapshot.availability == .completed { narrativeLink(.ending) }
                    }
                }
                if !NativeR2Flags.storyFlow, let snapshot = model.snapshot, model.hasCurrentMediaSnapshot {
                    Section("chapterStory.title") {
                        ForEach(snapshot.result.chapters) { chapter in
                            if let node = snapshot.visibleNodes.first(where: { $0.chapterID == chapter.id && !snapshot.isLocked($0) }),
                               model.chapterStories[chapter.id] != nil {
                                NavigationLink {
                                    ChapterStoryView(chapterID: chapter.id, nodeID: node.id, model: model,
                                        advancedModel: advancedModel, journeyModel: journeyModel, deviceModel: deviceModel, mediaScope: mediaScope,
                                        makeAudio: makeAudio, approvedArtworkHosts: approvedArtworkHosts, makeSensorProvider: makeSensorProvider, spatialApproval: spatialApproval,
                                        castModel: castModel, nodeDestination: { AnyView(nodeDestination($0)) })
                                } label: {
                                    if let title = chapter.name { Label { Text(verbatim: title) } icon: { Image(systemName: "book") } }
                                    else { Label("chapterStory.title", systemImage: "book") }
                                }.accessibilityIdentifier("chapterStory.open.\(chapter.id)")
                            }
                        }
                    }
                }
                Section("playx.results") {
                    if let mode = model.snapshot?.result.runStartMode {
                        LabeledContent("playx.completion.start") {
                            Text(LocalizedStringKey(mode == .desk ? "playx.completion.desk" : "playx.completion.alternate"))
                        }
                        .accessibilityIdentifier("playx.runStartMode")
                    }
                    if let snapshot = model.snapshot {
                        let cards = PlayRunKeepsakes.evidence(in: snapshot)
                        if !cards.isEmpty {
                            Text("playx.evidence.title").cyText(.cardTitle)
                            ForEach(cards) { card in
                                VStack(alignment: .leading, spacing: 4) {
                                    if let title = card.title { Text(verbatim: title).cyText(.cardTitle) }
                                    Text(verbatim: card.text).cyText(.body)
                                }
                                .accessibilityIdentifier("playx.evidence.\(card.id)")
                            }
                        }
                        let photos = PlayRunKeepsakes.photos(in: snapshot)
                        if !photos.isEmpty {
                            Text("playx.photos.title").cyText(.cardTitle)
                            ForEach(photos) { photo in
                                VStack(alignment: .leading, spacing: 4) {
                                    if let title = photo.title { Text(verbatim: title).cyText(.bodyCompact) }
                                    PlayStationArtwork(image: PlayStationImage(source: photo.url, tier: .station), title: photo.title ?? "")
                                }
                                .accessibilityIdentifier("playx.photos.\(photo.id)")
                            }
                        }
                    }
                    if model.snapshot?.availability == .completed, model.hasCurrentMediaSnapshot {
                        Button { finishScreen = true } label: { Label("medalScreen.open", systemImage: "rosette") }
                            .accessibilityIdentifier("medalScreen.open")
                    }
                    Button("playx.results.load") { Task { await model.loadEndingAndLeaderboard() } }.accessibilityIdentifier("playx.results.load")
                    NavigationLink("playx.stopwatch") { PlayStopwatchView() }
                    if let topicID = model.snapshot?.result.topicID, let factory = summaryModel, let summary = factory(topicID),
                       let source = PlayOperatingSummarySource(runtime: model, summary: summary) {
                        NavigationLink("playx.os.title") {
                            PlayOperatingSummaryView(model: summary,
                                sourceIsCurrent: { source.accepts(model, summary: summary, currentSummary: { factory(topicID) }) })
                        }.accessibilityIdentifier("playx.os.open")
                    }
                    if PrefabPreviewState.isPrefabTopic(name: model.snapshot?.result.topicName), let prefabModel {
                        NavigationLink("playx.prefab.title") { PlayPrefabRuntimeView(model: prefabModel) }
                    }
                    if let playerModel { NavigationLink("playx.player.title") { PlayPlayerSessionView(model: playerModel, deviceModel: deviceModel) } }
                    if case .activity(let activityID) = model.scope, model.hasCurrentMediaSnapshot {
                        NavigationLink("共同方案") {
                            PlaySharedPlanLifecycleEntry(activityID: activityID,
                                sourceCurrent: { model.available && model.hasCurrentMediaSnapshot })
                        }
                    }
                    if let circleModel { NavigationLink("playx.circle.title") { PlayCircleView(model: circleModel) } }
                    if circleModel != nil, let topicID = model.snapshot?.result.topicID, topicID > 0 { CircleThemeHostSection(topicID: topicID) }
                    if let card = finishRouteModel?.card {
                        PlayFinishRouteCardView(card: card, destination: finishRouteDestination)
                            .modifier(FinishRouteAnalyticsModifier(card: card, activityID: { if case .activity(let id) = model.scope { return id }; return nil }(),
                                topicID: model.snapshot?.result.topicID, runID: model.snapshot?.result.routeState?.sessionID, mode: model.snapshot?.result.mode))
                    }
                    if mpParity.journeyReport != nil, let snapshot = model.snapshot, snapshot.availability == .completed {
                        // Mini-program report/settle open at the end of a run; hidden until the journey binding exists.
                        NavigationLink { MPParityDestination(route: .journeyReport(journeyRunScope(snapshot.result.topicID, snapshot.result.topicName))) } label: {
                            Label("mp.entry.journeyReport", systemImage: "flag.checkered")
                        }
                        .accessibilityIdentifier("journeyReport.entry")
                    }
                    if let themeRecordsModel, themeRecordsModel.isAvailable {
                        NavigationLink("playx.themeRecords.title") { PlayThemeRecordsView(model: themeRecordsModel, title: model.snapshot?.result.topicName) }
                            .accessibilityIdentifier("playx.themeRecords.open")
                    }
                    if let backpackModel {
                        NavigationLink("playx.backpack.title") {
                            PlayThemeBackpackView(model: backpackModel, externalGamesEnabled: ExternalGameSessionRead.externalGamesOpen(baseURL: externalGameSession?.baseURL))
                        }
                            .accessibilityIdentifier("playx.backpack.open")
                    }
                    if let teamBackpackModel {
                        NavigationLink("play.teamBackpack.title") { PlayTeamBackpackView(model: teamBackpackModel) }
                            .accessibilityIdentifier("play.teamBackpack.open")
                    }
                }
                // 联系主办 / 联系商家 (`GET api/play/contact`); no phone, no row.
                if model.hasCurrentMediaSnapshot, let snapshot = model.snapshot {
                    PlayContactSection(currentNodeID: PlayTaskSummaryPresentation(snapshot: snapshot).currentNodeID,
                                       finished: snapshot.availability == .completed)
                    // 已完成章节 from `GET api/play/history` that the live route no longer lists.
                    PlayCompletedHistorySection(routeSessionID: snapshot.route?.sessionID,
                                                liveChapterIDs: Set(snapshot.result.chapters.map(\.id)))
                }
                if let reward = model.reward { PlayRewardSection(reward: reward, collectionDestination: rewardCollectionDestination) }
                if let ending = model.ending {
                    Section("playx.ending") {
                        if ending.hasStory {
                            if !ending.opener.isEmpty { Text(verbatim: ending.opener) }
                            ForEach(Array(ending.fragments.enumerated()), id: \.offset) { _, fragment in
                                VStack(alignment: .leading) { Text(verbatim: fragment.name).cyText(.cardTitle); if let text = fragment.text, !text.isEmpty { Text(verbatim: text) } }
                            }
                        } else { Text("playx.ending.empty").accessibilityIdentifier("playx.ending.empty") }
                    }
                    if let config = castModel?.config {
                        CastEndingSection(config: config, result: CastEndingResult(raw: model.castPayload))
                    }
                }
                if let board = model.leaderboard {
                    Section("playx.leaderboard") {
                        ForEach(board.entries) { row in
                            LabeledContent { Text(verbatim: String(row.score)).monospacedDigit() } label: {
                                HStack(spacing: 10) {
                                    Text(verbatim: row.rank.map(String.init) ?? "—").cyText(.cardTitle, monospacedDigit: true).frame(minWidth: 28, alignment: .leading)
                                    if let name = row.name, !name.isEmpty { Text(verbatim: name) } else { Text("playx.player.unnamed") }
                                }
                            }
                        }
                        LabeledContent("playx.leaderboard.me") { Text(verbatim: "\(board.me.rank.map(String.init) ?? "—") · \(board.me.score)") }
                    }
                }
                if case .activity = model.scope { PlayLeadSection(model: model) }
            }
    }
    @ToolbarContentBuilder private var orientationToolbar: some ToolbarContent {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await model.load() } } label: { Label("playx.refresh", systemImage: "arrow.clockwise") }
                    .disabled(model.phase == .submitting || !model.available).accessibilityIdentifier("playx.refresh")
            }
            ToolbarItem(placement: .topBarTrailing) {
                // 游玩工具: 切换章节 when the route has more than one chapter (also after the run is done), 紧急求助 always.
                PlayToolsMenu(showsChapters: (model.snapshot?.result.chapters.count ?? 0) > 1, showsEmergency: model.snapshot != nil,
                              openChapters: { showChapterPicker = true }, openEmergency: { showEmergencyHelp = true },
                              openScanArrival: hudStop == nil ? nil : { if let id = hudStop?.node.id { selectedNode = id } },
                              openPreferences: openPlayTools)
            }
    }
    private func openPlayTools() { showPlayTools = true }
    /// PLAY-6a: lead actions already sit in `PlayLeadSection` on the page, so the sheet carries stats + preferences.
    private var playToolsSheet: some View {
        PlayToolsAndLeadSheetView(
            chapterCount: model.snapshot?.result.chapters.count ?? 0,
            completedCount: doneChapterIDs.count,
            bgmEnabled: $playBGMOn,
            narrationAutoplay: $playNarrationOn,
            reduceMotionOverride: playReducedMotionBinding,
            onClose: { showPlayTools = false },
            showsContentRows: false
        )
    }
    /// `utils/motion-preference.js`: writes the primary and the legacy key.
    private var playReducedMotionBinding: Binding<Bool> {
        Binding(get: { _ = playReducedMotion; return PlayReducedMotionPreference.isEnabled(in: .standard) },
                set: { on in PlayReducedMotionPreference.set(on, in: .standard); playReducedMotion = on })
    }
    private var playChannelScope: InGameChannelScope? {
        if let teamID = model.snapshot?.result.teamID, teamID > 0 {
            return .team(id: teamID)
        }
        switch model.scope {
        case .activity(let id):
            return .activity(id: id)
        case .topic(let id):
            return .topic(id: id)
        }
    }
    private var playChannelTitleKey: LocalizedStringKey {
        if let teamID = model.snapshot?.result.teamID, teamID > 0 {
            return "ingame.channel.team"
        }
        return "ingame.channel.activity"
    }
    /// Map-first play screen: static map ground, glass clock / route map / end on top, the one primary
    /// (pause / resume) above the panel, and the unchanged task list in a three-detent panel.
    // MARK: native r2 city orientation (NativeR2Flags.cityOrientation)

    /// N-PLAY-DARK (MP pages/play/index.wxml is a normal light page): the runtime shell, backpack, route map and node
    /// pages follow the system Light/Dark setting under the player domain. Only the focused kit stage stays dark.
    private var screenDomain: ThemeDomain { .player }

    /// Any other presentation of this screen hides the run sheet first; it comes back when that one closes.
    private var cityRunSheetBlocked: Bool {
        finishScreen || stageSettlement != nil || showEmergencyHelp || showChapterPicker || showRouteMap || showBackpack
            || selectedNode != nil || titleCardTopic != nil || castCover || showingCastRoster
    }
    private var cityRunSheetBinding: Binding<Bool> {
        Binding(get: { cityRunSheet && !cityRunSheetBlocked }, set: { shown in if shown { cityRunSheet = true } })
    }
    @ViewBuilder private var cityOrientationNative: some View {
        let routeOpen = !model.unresolved && model.interactionContext != nil
            && model.snapshot.flatMap { PlayRouteMapPresentation(snapshot: $0) } != nil
        CityOrientationRunView(
            model: model, location: cityLocation, teammates: cityTeams, sheetShown: cityRunSheetBinding,
            onOpenRoute: routeOpen ? { showRouteMap = true } : nil,
            onEnd: model.snapshot == nil ? nil : { cityEndDialog = true },
            onPunch: { cityPunchNode = CityOrientationPunchTarget(id: $0) },
            channel: {
                // The nav bar carries the channel while there is no current stop; otherwise it sits on the map.
                if let scope = playChannelScope, hudStop != nil {
                    InGameChannelToolbarButton(scope: scope, titleKey: playChannelTitleKey,
                                               accessibilityID: "ingame.channel.play.entry",
                                               reloadTrigger: model.snapshot?.result.teamID ?? 0)
                }
            },
            panel: { cityRunPanel })
        .onAppear { cityRunSheet = true }
        .onDisappear { cityRunSheet = false; cityPunchNode = nil; cityHintNode = nil }
    }
    @ViewBuilder private var cityRunPanel: some View {
        VStack(spacing: 0) {
            CityOrientationRunMetricsRow(model: model, walkedMeters: cityLocation.walkedMeters) { cityRunPrimary }
            NavigationStack {
                List {
                    if model.hasCurrentMediaSnapshot, !model.unresolved, let snapshot = model.snapshot,
                       let id = PlayTaskSummaryPresentation(snapshot: snapshot).currentNodeID,
                       let node = snapshot.visibleNodes.first(where: { $0.id == id }) {
                        CityOrientationNextStopSection(
                            node: node, snapshot: snapshot,
                            distance: cityLocation.distance(toLatitude: node.latitude, longitude: node.longitude),
                            onPunch: { cityPunchNode = CityOrientationPunchTarget(id: id) },
                            onHint: { openCityHint(id) })
                    }
                    if let snapshot = model.snapshot, let route = PlayRouteMapPresentation(snapshot: snapshot) {
                        CityOrientationLegsSection(route: route, onOpen: { cityPunchNode = CityOrientationPunchTarget(id: $0) })
                    } else if let snapshot = model.snapshot {
                        stationsSection(snapshot)
                    }
                    if case .activity = model.scope { CityOrientationTeammatesSection(teams: cityTeams) }
                    orientationSections(native: true)
                }
                .refreshable { if model.available && model.phase != .submitting { await model.load() } }
                .toolbar { orientationToolbar }
                .navigationTitle(Text("playx.title"))
                .navigationBarTitleDisplayMode(.inline)
                .accessibilityIdentifier("playx.overview")
            }
        }
        .environment(\.cityOrientationTeamsSink, { teams in cityTeams = teams })
        .cySheet(item: $cityPunchNode) { target in
            CityOrientationPunchSheet(
                model: model, nodeID: target.id, location: cityLocation,
                onOpenTask: { id in cityPunchNode = nil; selectedNode = id },
                onNext: { id in cityPunchNode = CityOrientationPunchTarget(id: id) })
            .nativeR2SheetBackdropSource()
        }
        .nativeR2SheetBackdrop(isPresented: cityPunchNode != nil)
        // P-056: the hint ladder opens in place; the stop page is only for stops without a server ladder.
        .cySheet(item: $cityHintNode) { target in
            CityOrientationHintSheet(
                model: model, nodeID: target.id, makeTeamPool: teamPoolModel, approvedArtworkHosts: approvedArtworkHosts,
                onOpenStop: { id in cityHintNode = nil; hintNode = id; selectedNode = id })
        }
        .confirmationDialog(Text("playx.run.end"), isPresented: $cityEndDialog, titleVisibility: .visible) {
            Button("playx.run.end", role: .destructive) {
                Task { await model.endRun(now: ProcessInfo.processInfo.systemUptime, savedAt: Self.milliseconds) }
            }
            Button("playx.cancel", role: .cancel) {}
        } message: {
            Text("playx.run.end.detail")
        }
    }
    /// P-056: a server hint ladder opens as a sheet over the map; without one, the stop page keeps its legacy hint rows.
    private func openCityHint(_ id: Int) {
        if model.helpClient(nodeID: id) != nil {
            cityHintNode = CityOrientationHintTarget(id: id)
        } else {
            hintNode = id; selectedNode = id
        }
    }
    /// Same actions and identifiers as `runPrimary`, drawn with system button styles.
    @ViewBuilder private var cityRunPrimary: some View {
        if model.snapshot != nil {
            if model.clock.phase == .running {
                Button { Task { await model.pauseRun(now: ProcessInfo.processInfo.systemUptime, savedAt: Self.milliseconds) } } label: {
                    Label("playx.run.pause", systemImage: "pause.fill")
                }
                .buttonStyle(.bordered).controlSize(.large)
                .disabled(!model.canManageRun)
                .accessibilityIdentifier("playx.run.pause")
            } else if model.clock.phase != .ended {
                Button { model.startRun(now: ProcessInfo.processInfo.systemUptime) } label: {
                    Label(model.clock.elapsedSeconds == 0 ? "playx.run.start" : "playx.run.resume", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .disabled(!model.canManageRun)
                .accessibilityIdentifier("playx.run.resume")
            }
        }
    }
    @ViewBuilder private var cityFinishSummary: some View {
        let snapshot = model.snapshot
        let medals = model.reward.map { PlayRewardSection.medals(in: $0, locale: locale) } ?? []
        let topic = snapshot?.result.topicName.flatMap { $0.isEmpty ? nil : $0 }
        let key = finishResultKey(snapshot)
        let title = appLocalized(String.LocalizationValue(key), locale: locale)
        let earned = medals.isEmpty ? nil : appLocalized("medalScreen.earned \(medals.count)", locale: locale)
        CityOrientationFinishSummaryView(
            model: model, titleKey: key, subtitle: [topic, earned].compactMap { $0 }.joined(separator: " · "),
            medals: medals, shareText: appLocalized("medalScreen.shareText \(topic ?? title)", locale: locale),
            walkedMeters: cityLocation.walkedMeters, reportDestination: cityReportDestination,
            onClose: { finishScreen = false })
    }
    private var cityReportDestination: AnyView? {
        guard mpParity.journeyReport != nil, let snapshot = model.snapshot else { return nil }
        return AnyView(MPParityDestination(route: .journeyReport(journeyRunScope(snapshot.result.topicID, snapshot.result.topicName))))
    }
    private var orientationContent: some View {
        CYMapScaffold(detent: .medium, map: { PlayStoryMapGround(snapshot: model.snapshot) }, controls: { runHeader }, floating: { runFloating },
                      panel: { orientationList })
    }
    /// The one current stop of a live run, for the play HUD (401:4731). nil while branches are a choice, before the
    /// read is current, after the run ends, or when the run is unresolved: then the floating area is the run primary.
    private var hudStop: (node: PlayNode, snapshot: PlaySnapshot)? {
        guard model.gameplayMode == .cityOrientation, model.hasCurrentMediaSnapshot, !model.unresolved,
              model.clock.phase != .ended, let snapshot = model.snapshot,
              let id = PlayTaskSummaryPresentation(snapshot: snapshot).currentNodeID,
              let node = snapshot.visibleNodes.first(where: { $0.id == id }) else { return nil }
        return (node, snapshot)
    }
    @ViewBuilder private var runFloating: some View {
        if let hud = hudStop {
            PlayHUDView(node: hud.node, snapshot: hud.snapshot, elapsedSeconds: model.clock.elapsedSeconds,
                        onOpenStop: { selectedNode = hud.node.id },
                        onHint: { hintNode = hud.node.id; selectedNode = hud.node.id },
                        onBackpack: (backpackModel != nil || teamBackpackModel != nil) ? { showBackpack = true } : nil,
                        primary: { runPrimary },
                        team: {
                            if let scope = playChannelScope {
                                InGameChannelToolbarButton(scope: scope, titleKey: playChannelTitleKey,
                                                           accessibilityID: "ingame.channel.play.entry",
                                                           reloadTrigger: model.snapshot?.result.teamID ?? 0)
                            }
                        })
        } else {
            runPrimary
        }
    }
    @ViewBuilder private var backpackDestination: some View {
        if let teamBackpackModel, model.snapshot?.result.teamID ?? 0 > 0 {
            PlayTeamBackpackView(model: teamBackpackModel)
        } else if let backpackModel {
            PlayThemeBackpackView(model: backpackModel, externalGamesEnabled: ExternalGameSessionRead.externalGamesOpen(baseURL: externalGameSession?.baseURL))
        } else if let teamBackpackModel {
            PlayTeamBackpackView(model: teamBackpackModel)
        }
    }
    /// Elapsed clock plus route map and end as glass controls (max three with the toolbar refresh).
    @ViewBuilder private var runHeader: some View {
        if model.snapshot != nil {
            let seconds = model.clock.elapsedSeconds
            HStack(spacing: CYSpacing.sm) {
                CYGlassCapsule {
                    HStack(spacing: CYSpacing.sm) {
                        Image(systemName: "timer").accessibilityHidden(true)
                        Text(verbatim: PlayRunElapsedText.format(seconds))
                            .cyText(.dataXL).monospacedDigit().cyWrapText()
                            .accessibilityAddTraits(.updatesFrequently)
                            .accessibilityIdentifier("playx.run.clock")
                    }.foregroundStyle(.white)
                }
                Spacer(minLength: CYSpacing.sm)
                if !model.unresolved, model.interactionContext != nil, let snapshot = model.snapshot,
                   PlayRouteMapPresentation(snapshot: snapshot) != nil {
                    CYGlassButton(systemImage: "map", label: "playRoute.open") { showRouteMap = true }
                        .accessibilityIdentifier("playRoute.open")
                }
                if model.clock.phase != .ended {
                    CYGlassButton(systemImage: "flag.checkered", label: "playx.run.end") { confirmEnd = true }
                        .disabled(!model.canManageRun)
                        .accessibilityIdentifier("playx.run.end")
                }
            }
        }
    }
    @ViewBuilder private var runPrimary: some View {
        if model.snapshot != nil {
            let seconds = model.clock.elapsedSeconds
            Group {
                if model.clock.phase == .running {
                    Button { Task { await model.pauseRun(now: ProcessInfo.processInfo.systemUptime, savedAt: Self.milliseconds) } } label: {
                        Label("playx.run.pause", systemImage: "pause.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.cyPrimary).disabled(!model.canManageRun)
                    .pageTemplateControl(label: Text("playx.run.pause"), traits: .isButton)
                    .accessibilityIdentifier("playx.run.pause")
                } else if model.clock.phase != .ended {
                    Button { model.startRun(now: ProcessInfo.processInfo.systemUptime) } label: {
                        Label(seconds == 0 ? "playx.run.start" : "playx.run.resume", systemImage: "play.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.cyPrimary).disabled(!model.canManageRun)
                    .pageTemplateControl(label: Text(seconds == 0 ? "playx.run.start" : "playx.run.resume"), traits: .isButton)
                    .accessibilityIdentifier("playx.run.resume")
                }
            }
            .controlSize(.large).frame(maxWidth: 280).padding(.horizontal, CYSpacing.lg)
        }
    }
    /// Chapters the native route page can open: a story document and a stop that is not locked (same rule as r1's list).
    private func nr2ReadableChapters(_ snapshot: PlaySnapshot) -> Set<Int> {
        Set(snapshot.result.chapters.compactMap { chapter in
            guard model.chapterStories[chapter.id] != nil,
                  snapshot.visibleNodes.contains(where: { $0.chapterID == chapter.id && !snapshot.isLocked($0) }) else { return nil }
            return chapter.id
        })
    }
    /// The same `ChapterStoryView` the r1 chapter link pushed, for the chapter's first unlocked stop.
    @ViewBuilder private func nr2ReaderDestination(_ chapterID: Int) -> some View {
        if let snapshot = model.snapshot,
           let node = snapshot.visibleNodes.first(where: { $0.chapterID == chapterID && !snapshot.isLocked($0) }) {
            ChapterStoryView(chapterID: chapterID, nodeID: node.id, model: model,
                advancedModel: advancedModel, journeyModel: journeyModel, deviceModel: deviceModel, mediaScope: mediaScope,
                makeAudio: makeAudio, approvedArtworkHosts: approvedArtworkHosts, makeSensorProvider: makeSensorProvider, spatialApproval: spatialApproval,
                castModel: castModel, nodeDestination: { AnyView(nodeDestination($0)) })
        } else {
            ContentUnavailableView("play.nr2.reader.locked", systemImage: "lock",
                                   description: Text("play.nr2.reader.locked.detail"))
                .accessibilityIdentifier("chapterStory.lockedStop")
        }
    }
    @ViewBuilder private func freeStoreDestination(_ id: Int) -> some View {
        if model.gameplayMode == .freeExploration {
            FreeExplorationStoreView(nodeID: id, model: model, device: deviceModel?(id), shopNPC: shopNPCModel?(id), mediaScope: mediaScope,
                makeExternalMaps: makeExternalMaps, storyDestination: { node in
                    guard model.hasCurrentMediaSnapshot, let chapterID = node.chapterID,
                          model.chapterStories[chapterID] != nil else { return nil }
                    return AnyView(ChapterStoryView(chapterID: chapterID, nodeID: node.id, model: model,
                        mediaScope: mediaScope, makeAudio: makeAudio, approvedArtworkHosts: approvedArtworkHosts,
                        castModel: castModel,
                        nodeDestination: { AnyView(freeStoreDestination($0)) }))
                }, storeDayModel: storeDayModel,
                arrivalLocation: RuntimeNativeLocationProvider(enabled: true))
        } else { Text("playMode.unavailable") }
    }
    /// Chapters whose visible places are all done and unlocked (the same rule as the 旅程记录 stage rows).
    private var doneChapterIDs: Set<Int> {
        guard let snapshot = model.snapshot, model.hasCurrentMediaSnapshot else { return [] }
        return Set(snapshot.result.chapters.compactMap { chapter in
            let nodes = snapshot.visibleNodes.filter { $0.chapterID == chapter.id }
            return !nodes.isEmpty && nodes.allSatisfy({ snapshot.isDone($0) && !snapshot.isLocked($0) }) ? chapter.id : nil
        })
    }
    @ViewBuilder private func narrativeLink(_ query: JourneyNarrativeQuery, subtitle: String? = nil) -> some View {
        if let narrative = narrativeModel?(query) {
            NavigationLink {
                JourneyNarrativeView(model: narrative, imageReader: narrativeImageReader, makeAudio: makeAudio, mediaScope: mediaScope)
            } label: {
                VStack(alignment: .leading) { Text(LocalizedStringKey(query.titleKey)); if let subtitle { Text(verbatim: subtitle).cyText(.meta) } }
            }.accessibilityIdentifier("journey.record.open." + query.key)
        }
    }
    @ViewBuilder private func nodeDestination(_ id: Int, opensHelp: Bool = false) -> some View {
        if model.gameplayMode == .cityOrientation {
        let configuration = try? PlayStillnessConfiguration(raw: model.extras[id]?.sensorConfig ?? .null)
        PlayExperienceNodeView(nodeID: id, model: model, device: deviceModel?(id), advanced: advancedModel.flatMap { $0(id) },
            stillness: configuration.flatMap { configuration in motionModel.flatMap { $0(id, configuration) } },
            preference: preferenceModel.flatMap { $0(id) }, journey: journeyModel.flatMap { $0(id) }, narrative: narrativeModel?(.questions(nodeID: id)), shopNPC: shopNPCModel?(id),
            mediaScope: mediaScope, makeAudio: makeAudio, makeExternalMaps: makeExternalMaps, approvedArtworkHosts: approvedArtworkHosts, makeSensorProvider: makeSensorProvider, spatialApproval: spatialApproval,
            makeTeamPool: teamPoolModel, openNode: { selectedNode = $0 }, opensHelp: opensHelp)
        } else { Text("playMode.unavailable") }
    }
    @ViewBuilder private var finishMedalScreen: some View {
        let snapshot = model.snapshot
        let nodes = snapshot?.visibleNodes ?? []
        let done = snapshot.map { snapshot in nodes.filter { snapshot.isDone($0) }.count }
        let medals = model.reward.map { PlayRewardSection.medals(in: $0, locale: locale) } ?? []
        let topic = snapshot?.result.topicName.flatMap { $0.isEmpty ? nil : $0 }
        // Mini-program v13 medal screen: 主题通关 over `{topic} · 获得 N 枚勋章`; only stats it can read
        // (用时 h:mm:ss, 节点 done/total) — a missing one is left out rather than shown as a guess.
        let title = appLocalized(String.LocalizationValue(finishResultKey(snapshot)), locale: locale)
        // Only medals the reward read actually returned; none means no medal line, never "1".
        let earned = medals.isEmpty ? nil : appLocalized("medalScreen.earned \(medals.count)", locale: locale)
        let subtitle = [topic, earned].compactMap { $0 }.joined(separator: " · ")
        let stats = [
            CYStoryStat(key: "medalScreen.stat.time", value: Self.finishClockText(model.clock.elapsedSeconds), systemImage: "stopwatch"),
            CYStoryStat(key: "medalScreen.stat.nodes", value: done.flatMap { nodes.isEmpty ? nil : "\($0)/\(nodes.count)" }, systemImage: "book"),
        ].filter { $0.value != nil }
        CYMedalScreen(items: medals, title: title, subtitle: subtitle, stats: stats,
                      shareText: appLocalized("medalScreen.shareText \(topic ?? title)", locale: locale),
                      secondaryTitle: "medalScreen.records",
                      onClose: { finishScreen = false })
    }
    /// `finish-result.js`: cleared only from the report's legitimate completion or the server route's own COMPLETED status;
    /// every stop done while the report is pending or unreadable has no result word.
    private func finishResultKey(_ snapshot: PlaySnapshot?) -> String {
        let state: PostGameFinishResult.ReportState
        switch finishReport?.phase {
        case .ready(let report)?: state = .loaded(report.result.flatMap { PostGameCompletion(rawValue: $0.rawValue) })
        case .loading?: state = .pending
        default: state = .failed
        }
        let result = PostGameFinishResult.resolve(report: state, topicCompleted: snapshot?.route?.status == "COMPLETED",
                                                  allDone: snapshot?.result.allDone ?? false, chapterDone: false)
        switch result {
        case .cleared: return "medalScreen.themeComplete"
        case .assisted: return "mp.report.result.assisted"
        case .ended: return "mp.report.result.ended"
        case .chapterDone, .unknown: return "medalScreen.allDone"
        }
    }
    private static func finishClockText(_ seconds: Int) -> String? {
        guard seconds > 0 else { return nil }
        return PlayRunElapsedText.format(seconds)
    }
    private func projectAmbient() {
        guard let result = model.snapshot?.result else { return }
        ambientModel?.project(eggs: result.eggs, topicID: result.topicID)
    }
    private static var milliseconds: Int64 { Int64(Date().timeIntervalSince1970 * 1000) }
    /// Naming, then the playbill, only at the start of an active run that has not finished a station.
    private var castOpeningStep: CastOpeningFlow.Step? {
        guard let config = castModel?.config, model.snapshot?.availability == .active, let snapshot = model.snapshot else { return nil }
        let anyDone = snapshot.visibleNodes.contains { snapshot.isDone($0) }
        return CastOpeningFlow.step(config: config, profile: castModel?.profile, anyStationDone: anyDone, playbillSeen: castPlaybillSeen)
    }
    private func adoptCast() {
        let payload = model.castPayload
        guard payload != .null else {
            castModel?.invalidate()
            castModel = nil
            castCover = false
            return
        }
        let next = castModel ?? model.makeCastCoordinator()
        next.adopt(raw: payload, topicID: model.snapshot?.result.topicID, runID: model.snapshot?.route?.sessionID)
        if castModel !== next { castModel = next }
        if castOpeningStep != nil { castCover = true }
    }
}

@MainActor private struct PlayExperienceNodeView: View {
    let nodeID: Int
    @Bindable var model: PlayExperienceCoordinator
    let device: PlayDeviceCaptureCoordinator?
    let advanced: PlayAdvancedCoordinator?
    let stillness: PlayStillnessCoordinator?
    let preference: PlayPreferenceCoordinator?
    let journey: JourneyCheckCoordinator?
    let narrative: JourneyNarrativeCoordinator?
    let shopNPC: ShopNPCNodeHost?
    let mediaScope: UUID
    var makeAudio: (@MainActor () -> PlatformAudioPlayback)? = nil
    var makeExternalMaps: (@MainActor () -> PlatformExternalMaps)? = nil
    var approvedArtworkHosts: Set<String> = []
    var makeSensorProvider: (@MainActor () -> any PlayKitSensorProviding)? = nil
    var spatialApproval = PlayKitSpatialApproval()
    var makeTeamPool: ((Int) -> TeamPoolHintModel?)? = nil
    /// Opens another stop from the outcome card ("Next stop"); nil hides that shortcut.
    var openNode: ((Int) -> Void)? = nil
    /// Opened from 提示 on the play HUD: the hint ladder sheet comes up once the ladder has loaded (no ladder: the
    /// stop's own hint rows are on the page).
    var opensHelp = false
    @State private var helpOpenedOnce = false
    @Environment(\.cyPalette) private var palette
    @Environment(\.locale) private var locale
    @State private var answer = ""
    /// Shared full-screen verdict (mini-program play-verdict) after this stop's own submission settles.
    @State private var verdict: CYPlayVerdict?
    @State private var review: PlayCompletionReview?
    @State private var showReview = false
    @State private var showHint = false
    @State private var hintContext: PlayInteractionContext?
    @State private var hintLevel: Int?
    /// F-05: why the last submit tap was refused. Shown beside the button and as a toast, never silently dropped.
    @State private var refusal: PlayReviewRefusal?
    /// UG-05…UG-09 ladder for this stop. When the server enables it, the legacy hint and reveal entries step aside.
    @State private var help: PlayHelpLadderModel?
    /// The team's shared pool for this stop, shown inside the hint dialog when the server enables it.
    @State private var teamPool: TeamPoolHintModel?
    @State private var showHelpPanel = false
    @State private var skippedHere = false
    @State private var showUnsavedDiscard = false
    @State private var nodeToastMessage: String?
    /// This screen's own submission settled as done (the button shows 已完成 in place).
    @State private var justSubmitted = false
    /// Native r2: the stage result shown in place as a medium sheet after this screen's own submission.
    @State private var nr2Result: NR2StageResultTarget?
    /// The server's reason when this screen's answer was not accepted, shown above the button.
    @State private var rejectionText: String?
    /// 「我已到达」 on the existing completion channel. One when-in-use fix; no continuous roam.
    @State private var arrival: PlayArrivalService?
    @State private var continuedWithoutPhoto = false
    private var answerPhase: CYResultPhase {
        if outcomeState == .submitting { return .loading }
        if justSubmitted && (outcomeState == .completed || nodeDone) { return .done }
        return .idle
    }
    private var node: PlayNode? { model.snapshot?.visibleNodes.first { $0.id == nodeID } }
    /// The server's done flag for this stop: node `done`, or a `COMPLETED` node or route state.
    private var nodeDone: Bool { node.map { model.snapshot?.isDone($0) == true } ?? false }
    private var activeDispatchedTask: PlayRandomDispatchedTask? {
        if let reward = model.reward, reward["nodeId"].tolerantInteger == nodeID,
           let dispatched = PlayRandomDispatchedTask.fromResponse(reward) {
            return dispatched
        }
        return model.extras[nodeID]?.dispatchedTask
    }
    private var helpEnabled: Bool { help?.enabled == true && help?.identity.nodeID == nodeID }
    private var gameStage: PlayGameStage? {
        guard let result = model.snapshot?.result else { return nil }
        guard PlayKitPilotGate.allows(eventID: result.topicID) else { return nil }
        return PlayGameStage.resolve(nodeID: nodeID, nodes: result.nodes, chapters: result.chapters)
    }
    var body: some View {
        let context = model.interactionContext
        nodeWithConfirms(context: context)
            .environment(\.playGameStage, gameStage)
            // Native r2 games: the kit shell shows the same ladder from its toolbar hint button.
            .environment(\.nativeGameHelp, helpEnabled ? help.map { NativeGameHelpContext(model: $0, teamPool: teamPool, approvedArtworkHosts: approvedArtworkHosts,
                onPoolTrimmed: { Task { await advanced?.refreshAuthoritative() } }) } : nil)
            // Design hand-off r1 PL-15: the hint ladder is a resizable sheet over the play screen.
            .cySheet(isPresented: Binding(get: { showHelpPanel && helpEnabled }, set: { if !$0 { showHelpPanel = false } })) {
                if let help {
                    PlayHelpLadderPanel(model: help, teamPool: teamPool, approvedArtworkHosts: approvedArtworkHosts,
                                         onPoolTrimmed: { Task { await advanced?.refreshAuthoritative() } },
                                         close: { showHelpPanel = false })
                }
            }
            .cyModalOverlay(isPresented: showUnsavedDiscard) {
                PlayUnsavedEditModal(
                    onKeepEditing: { showUnsavedDiscard = false },
                    onDiscard: { showUnsavedDiscard = false; answer = "" }
                )
            }
            .cyToast(verbatimMessage: $nodeToastMessage)
            // Native r2 M4: a revealed hint (story or game stop) also shows as a hint island; "下一条提示" reopens the ladder.
            .islandHints(helpEnabled ? help : nil) { showHelpPanel = true }
            .onChange(of: answer) { _, _ in refusal = nil }
            // A new read (advanced step accepted, stop done, run resynced) replaces the reason from the last tap.
            .onChange(of: model.reviewRefusal(nodeID: nodeID)) { _, _ in refusal = nil }
            .onChange(of: help?.skipped) { _, skipped in
                // The server settled the skip (0 points, assisted). No success verdict; progress is re-read by the model.
                if skipped == true { skippedHere = true; showHelpPanel = false }
            }
            .onChange(of: teamPool?.skipResult) { _, skipped in
                if skipped != nil {
                    skippedHere = true
                    showHelpPanel = false
                    Task { await model.load() }
                }
            }
            .onAppear { if arrival == nil { arrival = PlayArrivalService(runtime: model, location: RuntimeNativeLocationProvider(enabled: true)) } }
            .onDisappear { journey?.roleContent.close(); device?.cancel(); arrival?.cancel(); model.cancelReview(); review = nil; hintContext = nil; answer = ""; showHelpPanel = false }
    }

    @ViewBuilder
    private func nodeList(context: PlayInteractionContext?) -> some View {
        List {
            PlayTaskOutcomeSection(model: model, nodeID: nodeID, openNode: openNode)
            // Also shown at the top: the answer row can sit under the keyboard.
            if let refusal { Section { PlayReviewRefusalRow(refusal: refusal, identifier: "playx.review.refusal") } }
            if let state = model.submitRecovery, state.nodeID == nodeID {
                Section { PlaySubmitRecoveryRow(state: state, onCheck: model.unresolved ? { Task { await model.load() } } : nil) }
            }
            if let failure = model.arrivalFailure, failure.nodeID == nodeID, node.map({ model.snapshot?.isDone($0) != true }) ?? false {
                PlayArrivalFailureSection(failure: failure,
                    onRelocate: device.map { device -> () -> Void in
                        // A new reading is a new input with a new action id; the settled one is never replayed.
                        { _ = Task { await device.capture(.location, interaction: .init(context: context, current: { model.interactionContext })) } }
                    },
                    onRefresh: { Task { await model.load() } },
                    onOpenNode: openNode)
            }
            // WP-02: the original-run guard appeal for this stop (kept across visits by owner and session).
            PlayGuardAppealSection(scope: model.scope, nodeID: nodeID,
                                   reference: model.arrivalFailure?.nodeID == nodeID ? model.arrivalFailure?.guardReference : nil)
            if let reading = model.arrivalReading, model.reward?["nodeId"].tolerantInteger == nodeID {
                PlayArrivalReadingSection(reading: reading)
            }
            if let dispatched = activeDispatchedTask {
                Section {
                    VStack(alignment: .leading, spacing: CYSpacing.sm) {
                        CYStatusChip(
                            verbatim: CoreLoopCopy(locale: locale).t("今日盲盒任务", "Today's Mystery Task"),
                            tone: .info,
                            systemImage: "shippingbox.fill"
                        )
                        Text(verbatim: dispatched.displayName)
                            .cyText(.cardTitle)
                            .foregroundStyle(palette.textPrimary)
                        if let rule = dispatched.ruleInstructions, !rule.isEmpty {
                            Text(verbatim: rule)
                                .font(CYTypography.bodyCompact)
                                .foregroundStyle(palette.textSecondary)
                        }
                        if dispatched.nodeID != nodeID, let openNode {
                            Button(CoreLoopCopy(locale: locale).t("前往盲盒任务", "Open Mystery Task")) {
                                openNode(dispatched.nodeID)
                            }
                            .buttonStyle(.questifyPrimary)
                            .accessibilityIdentifier("playx.random.openDispatched")
                        }
                    }
                    .accessibilityIdentifier("playx.random.dispatchedTask")
                }
            }
            if let node {
                nodeSections(node: node, context: context)
            } else {
                Text("playx.node.unavailable")
            }
        }
    }

    private func nodeWithConfirms(context: PlayInteractionContext?) -> some View {
        nodeWithOutcomes(context: context)
            .cyModalConfirm(
                isPresented: showReview,
                title: appLocalized("playx.review", locale: .current),
                message: appLocalized("playx.review.detail", locale: .current),
                cancelTitle: appLocalized("playx.cancel", locale: .current),
                confirmTitle: appLocalized("playx.submit", locale: .current),
                confirmIdentifier: "playx.confirm",
                onCancel: { showReview = false; model.cancelReview(); review = nil },
                onConfirm: {
                    showReview = false
                    guard let review else { return }
                    self.review = nil // Consume before adaptive dismissal
                    Task { await model.submit(review) }
                }
            )
            .onChange(of: showReview) { _, visible in
                // A popover's outside-tap dismissal has no visible Cancel button.
                if !visible, review != nil { model.cancelReview(); review = nil }
            }
            .cyModalConfirm(
                isPresented: showHint,
                title: appLocalized("playx.hints.request", locale: .current),
                message: appLocalized("playx.hints.consequence", locale: .current),
                cancelTitle: appLocalized("playx.cancel", locale: .current),
                confirmTitle: appLocalized("playx.hints.confirm", locale: .current),
                confirmIdentifier: "playx.hints.confirm",
                onCancel: { showHint = false },
                onConfirm: {
                    showHint = false
                    let context = hintContext, level = hintLevel
                    hintContext = nil
                    Task { await model.requestHint(nodeID: nodeID, level: level, context: context) }
                }
            )
    }

    private func nodeWithOutcomes(context: PlayInteractionContext?) -> some View {
        nodeList(context: context)
            .privacySensitive()
            .navigationTitle("playx.task.title")
            .onChange(of: outcomeState) { old, new in
                // Only this screen's own submission produces a verdict; a later read never replays one.
                guard old == .submitting else { return }
                if new == .completed {
                    if let node {
                        let task = PlayNodeTask.resolve(mode: model.snapshot?.result.mode, node: node)
                        if task == .arrive || task == .scan {
                            UIKitHapticsDriver.ensureInstalled()
                            HapticsService.shared.play(.checkInSuccess)
                        }
                    }
                    // In place (xrefs-1 C2 / owner continuity pass): the submit button morphs to Done and the task card
                    // above updates where it is; no full-screen verdict for an ordinary stop.
                    justSubmitted = true
                    if NativeR2Flags.storyFlow { nr2Result = NR2StageResultTarget(nodeID: nodeID) }
                } else if new == .pending || new == .failed, case .rejected(_, let message)? = model.issue {
                    UIKitHapticsDriver.ensureInstalled()
                    HapticsService.shared.play(.wrongAnswer)
                    // The answer was not accepted: the button returns to its label and the reason stays beside it.
                    rejectionText = message
                }
            }
            .onChange(of: model.reward) { _, reward in
                guard let reward, reward["nodeId"].tolerantInteger == nodeID else { return }
                if let drop = PlayRewardDrop.fromReward(reward) {
                    nodeToastMessage = drop.toastMessage(locale: locale)
                } else if let dispatched = PlayRandomDispatchedTask.fromResponse(reward) {
                    nodeToastMessage = dispatched.revealTitle(locale: locale)
                }
            }
            .cyPlayVerdict($verdict)
            .cySheet(item: $nr2Result) { target in
                NR2StageResultSheet(model: model, nodeID: target.nodeID, openNode: openNode)
                    .nativeR2SheetBackdropSource()
            }
            .nativeR2SheetBackdrop(isPresented: nr2Result != nil)
            .modifier(JourneyCheckReviewPresentation(model: journey))
            // The optional check initially renders no rows, so its probe belongs to this stable host.
            .task(id: [model.identity, node.map { String($0.id) }, (model.snapshot?.route?.sessionID).map(String.init), (model.snapshot?.route?.version).map(String.init)]) {
                if let node {
                    await loadHelp(node: node)
                    if opensHelp, !helpOpenedOnce, helpEnabled { helpOpenedOnce = true; showHelpPanel = true }
                    await journey?.probe(nodeDone: model.snapshot?.isDone(node) == true)
                    guard !Task.isCancelled, self.node?.id == node.id, model.hasCurrentMediaSnapshot else { journey?.roleContent.close(); return }
                    await journey?.roleContent.load(expectedRunID: model.snapshot?.route?.sessionID, minimumStateVersion: model.snapshot?.route?.version)
                } else { journey?.roleContent.close() }
            }
            .onChange(of: nodeDone) { _, done in
                if node != nil { journey?.updateNodeDone(done) }
            }
    }

    @ViewBuilder
    private func nodeSections(node: PlayNode, context: PlayInteractionContext?) -> some View {
        if let journey {
            if NativeR2Flags.games { ChanceJourneyCheckView(model: journey, nodeDone: nodeDone) }
            else { PlayJourneyCheckView(model: journey, nodeDone: nodeDone) }
        }
        else { PlayCheckRuntimeSection(nodeID: node.id, routeSessionID: model.snapshot?.route?.sessionID, nodeDone: nodeDone) }
        if let narrative, model.hasCurrentMediaSnapshot, model.snapshot?.isLocked(node) == false {
            NavigationLink("journey.record.questions") {
                JourneyNarrativeView(model: narrative, onChanged: { await model.load() })
            }.accessibilityIdentifier("journey.record.open.questions.\(nodeID)")
        }
        nodeBriefSection(node: node, context: context)
        if model.hasCurrentMediaSnapshot, model.snapshot?.isLocked(node) == false, node.npc != nil, let shopNPC {
            Section {
                ShopNPCNodeEntrance(name: shopNPC.name, makeCoordinator: shopNPC.makeCoordinator, greeting: shopNPC.greeting,
                    makeScriptedGuide: { scope in ShopNPCScriptedGuideSource(runtime: model, nodeID: nodeID, conversation: scope) })
                    .id(shopNPC.identity)
            }
        }
        if model.snapshot?.result.mode == 2 {
            FreeExplorationVisitSteps(node: node)
        }
        nodeAnswerSection(node: node, context: context)
        nodeHelpAndHintSections(node: node, context: context)
        nodeSensorAndDeviceSections(node: node, context: context)
        if let arrival, arrival.offer(for: node.id) != nil {
            Section { PlayArrivalControl(arrival: arrival, nodeID: node.id, context: context) }
        }
    }

    @ViewBuilder
    private func nodeAnswerSection(node: PlayNode, context: PlayInteractionContext?) -> some View {
        if PlayNodeTask.resolve(mode: model.snapshot?.result.mode, node: node) == .answer {
            Section("playx.answer") {
                if let options = node.options, node.validationMethod == 3 {
                    // Keyed option cards (A / B / C) with outdoor high-contrast game runtime tokens.
                    VStack(spacing: CYSpacing.sm) {
                        ForEach(options.keys.sorted(), id: \.self) { key in
                            let on = answer == key
                            Button { answer = key } label: {
                                HStack(spacing: CYSpacing.md) {
                                    Text(verbatim: key)
                                        .cyText(.cardTitle)
                                        .foregroundStyle(on ? palette.actionPrimaryFg : palette.textSecondary)
                                    Text(verbatim: options[key] ?? key)
                                        .cyText(.body)
                                        .foregroundStyle(on ? palette.actionPrimaryFg : palette.textPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, CYSpacing.lg).padding(.vertical, CYSpacing.sm).frame(minHeight: 52)
                                .background(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous).fill(on ? palette.actionPrimaryBg : palette.bgRaised))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(on ? .isSelected : [])
                            .accessibilityIdentifier("playx.answer.option." + key)
                        }
                    }
                    .accessibilityIdentifier("playx.answer.options")
                } else {
                    TextField("playx.answer.placeholder", text: $answer, axis: .vertical)
                        .foregroundStyle(palette.textPrimary)
                        .accessibilityIdentifier("playx.answer.field")
                }
                // F-05: a done, locked or not-yet-ready stop says why and keeps its submit disabled.
                let blocker = model.reviewRefusal(nodeID: nodeID)
                if answerPhase == .idle, let shown = refusal ?? blocker, shown != .busy { PlayReviewRefusalRow(refusal: shown) }
                if answerPhase == .idle, let rejectionText {
                    Label { Text(verbatim: rejectionText).fixedSize(horizontal: false, vertical: true) } icon: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(palette.danger).accessibilityHidden(true)
                    }
                    .font(CYTypography.bodyCompact).foregroundStyle(palette.textPrimary)
                    .accessibilityIdentifier("playx.answer.rejected")
                }
                // In place: 提交 → 正在提交 → 已完成 in the same capsule (`CYResultButton`).
                CYResultButton("playx.review", loading: "playx.phase.submitting", done: "playx.completed",
                               systemImage: "checkmark.circle.fill", phase: answerPhase) {
                    rejectionText = nil
                    prepare(.answer(answer), context: context)
                }
                .identifier("playx.answer.review")
                .disabled(answerPhase == .idle && (!model.canWrite || (blocker != nil && blocker != .busy) || answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
            }
        }
    }

    @ViewBuilder
    private func nodeHelpAndHintSections(node: PlayNode, context: PlayInteractionContext?) -> some View {
        if helpEnabled || skippedHere {
            Section("playHelp.title") {
                if skippedHere {
                    Label("playHelp.skipped", systemImage: "forward.end").foregroundStyle(CYColor.textSecondary)
                        .accessibilityIdentifier("playHelp.skipped")
                } else {
                    Button("playHelp.open") { showHelpPanel = true }
                        .disabled(!model.hasCurrentMediaSnapshot)
                        .accessibilityIdentifier("playHelp.open")
                }
            }
        }
        if !helpEnabled, !skippedHere, let extra = model.extras[nodeID], extra.hintLocked == true || extra.puzzleScoring == true {
            legacyHintSection(extra: extra, context: context)
        }
        if !helpEnabled, let hint = model.hint {
            Section("playx.hints") {
                ForEach(Array(hint.hints.enumerated()), id: \.offset) { _, text in
                    Text(verbatim: text)
                }
            }
        }
    }

    @ViewBuilder
    private func nodeSensorAndDeviceSections(node: PlayNode, context: PlayInteractionContext?) -> some View {
        if let preference, node.validationMethod == 6 {
            NavigationLink("playx.preference.title") { PlayPreferenceView(model: preference) { Task { await model.load() } } }
                .accessibilityIdentifier("playx.preference.open")
        }
        if let stillness, node.sensorType == "still" {
            NavigationLink("playx.stillness") {
                PlayInteractionBoundContent(context: model.interactionContext) { issuedContext in
                    PlayStillnessStreamView(model: stillness) { prepare(.sensor(type: "still", payload: $0), context: issuedContext) }
                }
            }
        }
        if node.sensorType == "audio_clip",
           let audioConfig = try? PlayAudioClipConfiguration(raw: model.extras[nodeID]?.sensorConfig ?? .null) {
            NavigationLink("playx.audioClip.title") {
                PlayInteractionBoundContent(context: model.interactionContext) { issuedContext in
                    PlayAudioClipStreamView(
                        configuration: audioConfig,
                        canWrite: model.canWrite,
                        uploadAudio: { bytes, mime in
                            try await model.uploadAudio(bytes, mimeType: mime)
                        },
                        onSubmit: { payload in
                            prepare(.sensor(type: "audio_clip", payload: payload), context: issuedContext)
                        }
                    )
                }
            }
            .accessibilityIdentifier("playx.audioClip.open")
        }
        if let advanced, node.hasAdvancedPrerequisite {
            NavigationLink("playx.advanced") {
                PlayInteractionBoundContent(context: model.interactionContext) { advancedContext in
                    PlayAdvancedView(model: advanced, device: device, mediaScope: mediaScope, makeAudio: makeAudio, approvedArtworkHosts: approvedArtworkHosts, makeSensorProvider: makeSensorProvider, spatialApproval: spatialApproval,
                                      stationQuestion: node.question, stationName: node.name, stationPassText: node.passText) { state in
                        try? model.acceptAdvanced(state, context: advancedContext)
                    }
                }
            }
        }
        let resolvedTask = PlayNodeTask.resolve(mode: model.snapshot?.result.mode, node: node)
        let arrivalReplacesDevice = arrival?.offer(for: node.id) != nil && (resolvedTask == .arrive || resolvedTask == .merchantScan)
        if let device, !arrivalReplacesDevice { PlayDeviceTaskSection(model: device, task: resolvedTask,
            photoFilter: node.sensorType == "filter_shot" ? PlayPhotoFilter(rawValue: model.extras[nodeID]?.sensorConfig["filterStyle"].text ?? "") : nil,
            unsupportedPhotoSubtype: node.validationMethod == 2 && node.sensorType?.isEmpty == false && (node.sensorType != "filter_shot" || PlayPhotoFilter(rawValue: model.extras[nodeID]?.sensorConfig["filterStyle"].text ?? "") == nil), interaction: .init(context: context, current: { model.interactionContext }), onEvidence: { prepare($0, context: $1) }) }
        else if !arrivalReplacesDevice, resolvedTask != .answer { Text("playx.device.disabled") }
    }
    @ViewBuilder
    private func nodeBriefCard(node: PlayNode) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            HStack(spacing: CYSpacing.sm) {
                if let snapshot = model.snapshot {
                    CYStatusChip(
                        LocalizedStringKey("playx.task." + PlayNodeTask.resolve(mode: snapshot.result.mode, node: node).rawValue),
                        tone: .info,
                        systemImage: "flag.fill"
                    )
                }
                CYStatusChip(
                    verbatim: node.arrived == true
                        ? CoreLoopCopy(locale: locale).t("已到达", "Arrived")
                        : (node.needGPS == true || node.needScan == true
                            ? CoreLoopCopy(locale: locale).t("待到达", "Arrival required")
                            : CoreLoopCopy(locale: locale).t("自由打卡", "Open check-in")),
                    tone: node.arrived == true ? .success : .neutral,
                    systemImage: node.arrived == true ? "checkmark.circle.fill" : "location.fill"
                )
            }
            if let result = model.snapshot?.result {
                PlayStationArtwork(image: PlayStationImageResolver.station(for: node, in: result), title: node.name ?? "")
                    .accessibilityIdentifier("playx.station.artwork")
            }
            PlayNodeTitle(name: node.name)
                .cyText(.pageTitle)
                .foregroundStyle(palette.textPrimary)
            if model.snapshot?.isStoryLocked(node) == true {
                CYStatusChip("playFree.story.locked", tone: .neutral, systemImage: "lock.fill")
                    .accessibilityLabel(Text("playFree.story.locked.a11y"))
            } else if let body = node.storyText ?? node.description {
                Text(verbatim: body)
                    .cyText(.body)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let instructions = node.ruleInstructions {
                Text(verbatim: instructions)
                    .font(CYTypography.bodyCompact)
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let question = node.question {
                Text(verbatim: question)
                    .cyText(.cardTitle)
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if model.hasCurrentMediaSnapshot, model.snapshot?.isLocked(node) == false, let image = node.questionImage, !image.isEmpty {
                PlayKitArtwork(source: image, approvedHosts: approvedArtworkHosts)
                    .clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                    .accessibilityIdentifier("playx.question.image")
            }
            if let perk = node.perk {
                if perk.included == true { Text("playx.perk.included").cyText(.bodyCompact) }
                if let spend = perk.extraSpendText, !spend.isEmpty { Text(verbatim: spend).cyText(.bodyCompact) }
                if perk.reserveRequired == true { Text("playx.perk.reserve").cyText(.bodyCompact) }
            }
            if let mode = PlayCompletionModePresentation(raw: node.completionMode) {
                Text(LocalizedStringKey(mode.titleKey)).cyText(.bodyCompact).accessibilityIdentifier("playx.completion.mode")
            }
            if model.extras[node.id]?.photoCheckMode == "RECORD" {
                Button("playkit.photo.continueWithout") {
                    if case .success(let submission) = PlayPhotoRecordSubmission.validate(mode: "RECORD", imageURL: nil, textConfirmed: true, submitPhotoCheck: false) {
                        continuedWithoutPhoto = true
                        if let advanced { Task { await PlayKitInputContract.postRecord(submission, through: advanced) } }
                    }
                }
                .cyText(.body)
                .disabled(continuedWithoutPhoto)
                .accessibilityIdentifier("playkit.photo.continueWithout")
            }
            if node.validationMethod == 2, let requirement = node.photoRequirement, !requirement.isEmpty {
                Text(verbatim: requirement)
                    .cyText(.cardTitle)
                    .foregroundStyle(palette.textPrimary)
                    .accessibilityIdentifier("playx.photo.requirement")
            }
            if node.validationMethod == 4 {
                Text("playx.scan.prompt")
                    .cyText(.cardTitle)
                    .foregroundStyle(palette.textPrimary)
                    .accessibilityIdentifier("playx.scan.prompt")
            }
            if let address = node.address, !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Label {
                    Text(verbatim: address).fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "mappin.and.ellipse").foregroundStyle(palette.actionPrimaryBg).accessibilityHidden(true)
                }
                .font(CYTypography.meta)
                .foregroundStyle(palette.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cyDomainCard(radius: CYRadius.lg, padding: CYSpacing.lg)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: CYSpacing.xs, leading: 0, bottom: CYSpacing.xs, trailing: 0))
    }

    @ViewBuilder
    private func nodeBriefSection(node: PlayNode, context: PlayInteractionContext?) -> some View {
        Section {
            nodeBriefCard(node: node)
            PlatformChapterAudioHost(selection: PlatformChapterAudioSelection.resolve(snapshot: model.snapshot, nodeID: nodeID, extras: model.extras, currentRead: model.hasCurrentMediaSnapshot), scope: mediaScope, makeModel: makeAudio)
            if model.hasCurrentMediaSnapshot, model.snapshot?.isLocked(node) == false {
                if let audio = node.questionAudio, !audio.isEmpty { PlatformAudioHost(rawURL: audio, scope: mediaScope, makeModel: makeAudio) }
                PlatformExternalMapHost(destination: .init(name: node.name ?? "#\(node.id)", address: node.address, latitude: node.latitude, longitude: node.longitude), scope: mediaScope, makeModel: makeExternalMaps)
            }
            if let snapshot = model.snapshot {
                CYTaskStatusCard(
                    title: node.name ?? "#\(node.id)",
                    state: PlayTaskStatusCardMapper.state(
                        node: node,
                        snapshot: snapshot,
                        model: model,
                        locale: locale,
                        ctaTitle: appLocalized("playx.review", locale: locale),
                        onOpen: {
                            // An empty or refused answer surfaces its reason through prepare.
                            if PlayNodeTask.resolve(mode: snapshot.result.mode, node: node) == .answer {
                                prepare(.answer(answer), context: context)
                            }
                        },
                        onRefresh: { Task { await model.load() } }
                    )
                )
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: CYSpacing.xs, leading: 0, bottom: CYSpacing.xs, trailing: 0))
                PlayTaskStatusBadge(node: node, snapshot: snapshot)
            }
        }
    }

    @ViewBuilder
    private func legacyHintSection(extra: PlayNodeExtras, context: PlayInteractionContext?) -> some View {
        let nextLevel = min(2, (extra.puzzleHintLevel ?? 0) + 1)
        Section("playx.hints") {
            if let cost = extra.hintCost { LabeledContent("playx.hints.cost") { Text(verbatim: String(cost)) } }
            ForEach(Array(extra.usedHints.enumerated()), id: \.offset) { _, text in Text(verbatim: text).font(CYTypography.meta).foregroundStyle(.secondary) }
            if let cap = extra.puzzleScoreCap {
                Text("playx.hints.capLine \(cap)").font(CYTypography.meta).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                    .accessibilityIdentifier("playx.hints.cap")
            }
            Button {
                hintContext = context
                hintLevel = extra.puzzleScoring == true ? nextLevel : nil
                showHint = true
            } label: {
                if extra.puzzleScoring == true { Text("playx.hints.requestLevel \(nextLevel)") }
                else { Text("playx.hints.request") }
            }
            .disabled(!model.canWrite || (extra.puzzleScoring != true && extra.hintCost == nil))
            .accessibilityIdentifier("playx.hints.request")
        }
    }

    /// One read when an unfinished stop opens. A failed read keeps the legacy hint entries.
    private func loadHelp(node: PlayNode) async {
        let done = model.snapshot?.isDone(node) == true
        guard !done, model.snapshot?.isLocked(node) == false, let client = model.helpClient(nodeID: node.id) else {
            if help?.identity.nodeID != node.id || done { help = nil; showHelpPanel = false }
            return
        }
        if teamPool?.nodeID != Int64(node.id) {
            teamPool = makeTeamPool?(node.id)
            teamPool?.onPoolUpdated = { updated in
                if updated.solvedNodeIds?.contains(Int64(node.id)) == true {
                    Task { await model.load() }
                }
            }
        }
        if let help, help.identity == client.identity, help.loaded { await teamPool?.load(); return }
        let next = PlayHelpLadderModel(client: client, store: PlayHelpDefaultsRequestStore.shared)
        help = next
        await next.load()
        await teamPool?.load()
    }
    private var outcomeState: PlayTaskOutcomePresentation.State {
        PlayTaskOutcomePresentation(snapshot: model.snapshot, nodeID: nodeID, phase: model.phase.rawValue,
                                    isCurrentRead: model.hasCurrentMediaSnapshot, unresolved: model.unresolved).state
    }
    private func stateRow(_ key: String, done: Bool) -> some View { Label(LocalizedStringKey(key), systemImage: done ? "checkmark.circle.fill" : "circle") }
    private func prepare(_ evidence: PlayCompletionEvidence, context: PlayInteractionContext?) {
        do { review = try model.review(nodeID: nodeID, evidence: evidence, context: context); showReview = true; refusal = nil }
        catch {
            // F-05: a refused review always shows its reason (inline and as a toast); nothing was sent.
            let reason = model.reviewRefusal(nodeID: nodeID, evidence: evidence) ?? PlayReviewRefusal(error: error)
            refusal = reason
            nodeToastMessage = PlayReviewRefusalRow.text(reason, locale: locale)
        }
    }
}

/// U04-03: the server's compatibility verdict before play. Unconfirmed (old/undeclared client) shows
/// nothing; a damaged declaration is "not confirmed", never "supported"; missing keys are listed as sent.
struct PlayCompatibilitySection: View {
    let compatibility: PlayContentCompatibility
    var body: some View {
        switch compatibility.verdict {
        case .supported: EmptyView()
        case .unconfirmed(let source):
            if source == "MALFORMED" || source == "DECLARED_MALFORMED" {
                Section {
                    Label { Text("playCompat.unconfirmed", tableName: "PlayFullStory") } icon: { Image(systemName: "questionmark.circle") }
                        .font(CYTypography.caption).foregroundStyle(CYColor.textSecondary)
                        .accessibilityIdentifier("playCompat.unconfirmed")
                }
            }
        case .unsupported(let missing):
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label { Text("playCompat.unsupported.title", tableName: "PlayFullStory").cyText(.cardTitle) }
                        icon: { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(CYColor.warningText) }
                    Text("playCompat.unsupported.body", tableName: "PlayFullStory").cyText(.body)
                        .foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                    if !missing.isEmpty {
                        DisclosureGroup {
                            ForEach(missing, id: \.key) { row in
                                Text(verbatim: row.key + " ≥ v" + String(row.minVersion)).font(CYTypography.meta).monospaced()
                                    .foregroundStyle(CYColor.textSecondary)
                            }
                        } label: { Text("playCompat.unsupported.details", tableName: "PlayFullStory").font(CYTypography.caption) }
                        .accessibilityIdentifier("playCompat.missing")
                    }
                }.accessibilityIdentifier("playCompat.unsupported")
            }
        }
    }
}

/// F-05: the reason a stop's submit was refused or is unavailable, beside the submit button.
struct PlayReviewRefusalRow: View {
    let refusal: PlayReviewRefusal
    var identifier = "playx.answer.refusal"
    var body: some View {
        Label {
            Text(LocalizedStringKey(refusal.messageKey), tableName: PlayReviewRefusal.table)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: refusal == .completed ? "checkmark.circle.fill" : "exclamationmark.circle")
        }
        .font(CYTypography.bodyCompact)
        .foregroundStyle(refusal == .completed ? CYColor.successText : CYColor.warningText)
        .accessibilityIdentifier(identifier)
    }
    static func text(_ refusal: PlayReviewRefusal, locale: Locale) -> String {
        String(localized: LocalizedStringResource(String.LocalizationValue(stringLiteral: refusal.messageKey),
                                                  table: PlayReviewRefusal.table, locale: locale))
    }
}
struct PlayExperienceIssueView: View {
    let issue: PlayExperienceError
    static func showsReference(_ issue: PlayExperienceError) -> Bool {
        switch issue {
        case .unknownResult, .malformed, .rejected: return true
        default: return false
        }
    }
    var body: some View {
        VStack(alignment: .leading) {
            if case .rejected(let code, let message) = issue {
                Label("playx.rejected", systemImage: "exclamationmark.circle").cyText(.cardTitle)
                Text(verbatim: message ?? String(code)).fixedSize(horizontal: false, vertical: true)
            } else { Text(LocalizedStringKey(issue == .disabled ? "playx.disabled" : issue == .staleSession ? "playx.session.changed" : issue == .unsupported ? "playx.unsupported" : "playx.error")) }
            // OWN-OPT-072: unknown result or server error carries the server request reference for support.
            if Self.showsReference(issue), let row = RequestReferenceRow(pathFragment: "/api/play/") { row }
        }.foregroundStyle(.secondary).accessibilityIdentifier("playx.issue")
    }
}
@MainActor struct PlayRewardSection: View {
    let reward: PlayWireValue
    var collectionDestination: ((PlayRewardBadgeTarget) -> AnyView)? = nil
    @Environment(\.locale) private var locale
    var body: some View {
        Section("playx.reward") {
            // Mini-program finish-medals: the earned medals stack first, the ledger rows follow.
            let medals = Self.medals(in: reward, locale: locale)
            if !medals.isEmpty {
                CYMedalDeck(items: medals).padding(.vertical, CYSpacing.sm)
                    .listRowBackground(Color.clear)
            }
            if let xp = reward["xp"].tolerantInteger ?? reward["score"].tolerantInteger { LabeledContent("playx.reward.xp") { Text(verbatim: String(xp)) } }
            if let score = reward["puzzleScore"].tolerantInteger { LabeledContent("playx.reward.puzzle") { Text(verbatim: String(score)) } }
            if let mode = PlayCompletionModePresentation(raw: reward["completionMode"].text) {
                LabeledContent("play.completionMode") { Text(LocalizedStringKey(mode.titleKey)) }
            }
            if let drop = PlayRewardDrop.fromReward(reward) {
                LabeledContent {
                    Text(verbatim: drop.detailText(locale: locale))
                } label: {
                    CYStatusChip(
                        verbatim: CoreLoopCopy(locale: locale).t("随机掉落", "Bonus Drop"),
                        tone: .success,
                        systemImage: "sparkles"
                    )
                }
                .accessibilityIdentifier("playx.reward.drop")
            }
            if let dispatched = PlayRandomDispatchedTask.fromResponse(reward) {
                LabeledContent {
                    Text(verbatim: dispatched.displayName)
                } label: {
                    CYStatusChip(
                        verbatim: CoreLoopCopy(locale: locale).t("今日盲盒任务", "Mystery Task"),
                        tone: .info,
                        systemImage: "shippingbox.fill"
                    )
                }
                .accessibilityIdentifier("playx.reward.dispatchedTask")
            }
            if let medal = reward["medalName"].text { Text(verbatim: medal) }
            PlayRewardBadgeRows(targets: PlayRewardBadgeTarget.targets(in: reward), destination: collectionDestination)
                .id(PlayRewardBadgeTarget.targets(in: reward))
        }.accessibilityIdentifier("playx.reward")
    }
    /// Medals carried by the reward receipt: the topic medal name plus each new badge. Nothing is invented.
    static func medals(in reward: PlayWireValue, locale: Locale) -> [CYMedalItem] {
        var items: [CYMedalItem] = []
        if let medal = reward["medalName"].text, !medal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items.append(.init(id: "topic-medal", name: medal, imageURL: reward["medalImg"].text ?? reward["medalImage"].text, systemImage: "rosette", mpDefault: .trophy))
        }
        for target in PlayRewardBadgeTarget.targets(in: reward) {
            items.append(.init(id: "badge-" + target.code, name: target.name ?? appLocalized("medalDeck.unnamed", locale: locale), systemImage: "seal.fill", mpDefault: .glassBadge))
        }
        return items
    }
}
@MainActor private struct PlayLeadSection: View {
    @Bindable var model: PlayExperienceCoordinator
    @State private var text = ""
    @State private var action: PlayLeadAction?
    @State private var review = false
    @State private var actionContext: PlayInteractionContext?
    @Environment(\.playerGapService) private var gapService
    var body: some View {
        let context = model.interactionContext
        Section("playx.lead.title") {
            Button("playx.lead.load") { Task { await model.loadLead(context: context) } }.accessibilityIdentifier("playx.lead.load")
            if let lead = model.lead {
                if !lead.exists { Text("playx.lead.notStarted") }
                if let broadcast = lead.broadcast { Text(verbatim: broadcast) }
                if let chapter = lead.chapterName { Text(verbatim: chapter) }
                if let arrived = lead.arrived, !lead.members.isEmpty { LabeledContent("playx.lead.arrived") { Text(verbatim: "\(arrived) / \(lead.members.count)") } }
                ForEach(lead.members) { member in
                    Label { if let name = member.name, !name.isEmpty { Text(verbatim: name) } else { Text("playx.player.unnamed") } }
                        icon: { Image(systemName: member.arrived ? "checkmark.circle.fill" : "circle").foregroundStyle(member.arrived ? CYColor.successText : CYColor.textTertiary) }
                }
                if gapService != nil, case .activity(let activityID) = model.scope, lead.exists, !lead.isLeader {
                    // leadArrive (one approved GCJ-02 fix) and the member broadcast; leader tools stay hidden.
                    LeadMemberActionsSection(activityID: activityID, meArrived: lead.meArrived,
                                             reload: { Task { await model.loadLead(context: context) } })
                } else if lead.exists && !lead.meArrived { actionButton(context: context, .arrive) }
                if lead.isLeader {
                    if lead.exists, case .activity(let activityID) = model.scope {
                        LeadMemberTicketScanButton(activityID: activityID)
                        // PLAY-8: MP 展示整团码 (`leadShowGroupCode` → scene qr-group-code for this activity). The club
                        // group-code page issues and shows it; its own access check covers a leader without club rights.
                        NavigationLink {
                            MPReviewedPageScreen(page: "pages/club/group-code/index", query: ["activityId": String(activityID)])
                                .cyPushedChrome()
                        } label: {
                            Label("playTools.lead.showGroupCode", systemImage: "qrcode")
                        }
                        .accessibilityIdentifier("playx.lead.showGroupCode")
                    }
                    TextField("playx.lead.text", text: $text, axis: .vertical).accessibilityIdentifier("playx.lead.text")
                    if !lead.exists { actionButton(context: context, .start) }
                    else {
                        actionButton(context: context, .broadcast)
                        PlayLeadChapterTools(model: model, lead: lead, context: context)
                        actionButton(context: context, .settle)
                    }
                }
                if model.leaderOutcomeUnknown { Text("playx.lead.unknown") }
                if model.leadReadFailed { PlayRuntimePhaseText(phase: "failed") }
            }
            if case .activity(let activityID) = model.scope {
                TeamTrailSection(activityID: activityID, done: { [model] in
                    guard let snapshot = model.snapshot else { return 0 }
                    return snapshot.visibleNodes.filter { snapshot.isDone($0) }.count
                })
            }
        }
        .modifier(PlayLeadProgressPollingModifier(model: model, context: context))
        .cyModalConfirm(
            isPresented: review,
            title: appLocalized("playx.review", locale: .current),
            message: appLocalized(String.LocalizationValue(stringLiteral: action == .settle ? "playx.lead.settle.consequence" : "playx.lead.review"), locale: .current),
            cancelTitle: appLocalized("playx.cancel", locale: .current),
            confirmTitle: appLocalized("playx.submit", locale: .current),
            onCancel: { review = false; actionContext = nil },
            onConfirm: {
                review = false
                if let action {
                    let context = actionContext, message = action == .broadcast ? text : nil
                    actionContext = nil
                    Task { await model.performLead(action, text: message, context: context) }
                }
            }
        )
    }
    private func actionButton(context: PlayInteractionContext?, _ value: PlayLeadAction) -> some View {
        Button(LocalizedStringKey("playx.lead." + value.rawValue)) { action = value; actionContext = context; review = true }
            .disabled(!model.canWrite || model.leaderOutcomeUnknown || (value == .unlockChapter && model.lead?.allArrived != true) || (value == .broadcast && text.isEmpty))
            .accessibilityIdentifier("playx.lead." + value.rawValue)
    }
}

/// A stop's name, or a neutral placeholder; never the raw id.
struct PlayNodeTitle: View {
    let name: String?
    var body: some View {
        if let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { Text(verbatim: name) }
        else { Text("playx.node.untitled") }
    }
}

struct PlayRuntimePhaseText: View {
    let phase: String
    var body: some View { Text(LocalizedStringKey("playx.phase." + phase)) }
}

/// Freeze authority when this interaction is mounted. A redraw must not bind
/// an old child operation to a newly loaded mode or request generation.
@MainActor struct PlayInteractionBoundContent<Content: View>: View {
    @State private var context: PlayInteractionContext?
    private let currentContext: PlayInteractionContext?
    private let content: (PlayInteractionContext?) -> Content
    init(context: PlayInteractionContext?, @ViewBuilder content: @escaping (PlayInteractionContext?) -> Content) {
        _context = State(initialValue: context); currentContext = context; self.content = content
    }
    @ViewBuilder var body: some View {
        if context != nil, context == currentContext { content(context) }
        else { Text("playMode.unavailable") }
    }
}

/// Session AND coordinator identity delimit one visible runtime. Retaining the previous
/// coordinator prevents pointer reuse from making a replacement look like the old owner.
struct PlayExperiencePresentationKey: Hashable {
    let coordinator: ObjectIdentifier
    let session: String?
    @MainActor init(model: PlayExperienceCoordinator) { coordinator = ObjectIdentifier(model); session = model.identity }
}
@MainActor final class PlayExperiencePresentationMount {
    private var model: PlayExperienceCoordinator?
    private var session: String?
    func enter(_ next: PlayExperienceCoordinator) -> Bool {
        guard model !== next || session != next.identity else { return false }
        model = next; session = next.identity; return true
    }
}

struct PlayStageSettlementTarget: Identifiable, Equatable {
    let chapterID: Int
    var id: Int { chapterID }
}

/// Cast mounts (W1) split out of `PlayExperienceView.body` so the modifier chain type-checks in time.
private struct PlayExperienceCastMounts: ViewModifier {
    let host: PlayExperienceView
    func body(content: Content) -> some View {
        host.castMounts(content)
    }
}

extension PlayExperienceView {
    @ViewBuilder fileprivate func castMounts<C: View>(_ content: C) -> some View {
        content
            .onAppear { adoptCast() }
            .onChange(of: model.castPayload) { _, _ in adoptCast() }
            .onChange(of: model.snapshot?.route?.sessionID) { old, new in
                if old != new { castPlaybillSeen = false }
                adoptCast()
            }
            .onChange(of: castOpeningStep) { _, step in castCover = step != nil }
            .cyFullScreenCover(isPresented: $castCover) {
                if let config = castModel?.config {
                    CastOpeningFlow(config: config, profile: castModel?.profile, routeName: model.snapshot?.result.topicName,
                                    suggestedName: castModel?.profile?.name ?? "", initial: castOpeningStep ?? .playbill,
                                    save: { name, identity in Task { await castModel?.saveProfile(name: name, identityKey: identity) } },
                                    finish: { castPlaybillSeen = true; castCover = false })
                }
            }
            .cySheet(isPresented: $showingCastRoster) {
                if let config = castModel?.config {
                    NavigationStack {
                        CastPlaybillView(config: config, profile: castModel?.profile, routeName: model.snapshot?.result.topicName, start: { showingCastRoster = false })
                    }
                }
            }
    }
}

/// PLAY-2: MP pages/play story map (wxml:102, 145): the route's stops and dashed order line drawn as the play
/// screen's ground, with no chrome. Read-only and not interactive (the full route map stays one push away);
/// it shows only what PlayRouteMapPresentation already exposes (no story, answers or player position).
/// A route without coordinates keeps the placeholder ground.
@MainActor private struct PlayStoryMapGround: View {
    let snapshot: PlaySnapshot?
    var body: some View {
        if let snapshot, let presentation = PlayRouteMapPresentation(snapshot: snapshot), !presentation.mappedStops.isEmpty {
            let points = presentation.mappedStops.compactMap(\.coordinate).map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            Map(initialPosition: .region(CYMapRegion.boundingRegion(coordinates: points)), interactionModes: []) {
                ForEach(presentation.segments) { segment in
                    MapPolyline(coordinates: [
                        CLLocationCoordinate2D(latitude: segment.start.latitude, longitude: segment.start.longitude),
                        CLLocationCoordinate2D(latitude: segment.end.latitude, longitude: segment.end.longitude),
                    ])
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [6, 5]))
                }
                ForEach(presentation.mappedStops) { stop in
                    if let location = stop.coordinate {
                        Annotation("", coordinate: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)) {
                            Image(systemName: stop.state.symbol)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(stop.state == .current ? CYColor.textOnAccent : Color.primary)
                                .padding(6)
                                .background(stop.state == .current ? CYColor.actionPrimaryBg : Color(uiColor: .systemBackground), in: Circle())
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, emphasis: .muted))
            .environment(\.colorScheme, .light)
            .background { CYMapPlaceholder(fog: false) }
            // Decorative ground: the stop list in the panel carries the same facts for VoiceOver.
            .accessibilityHidden(true)
            .allowsHitTesting(false)
            .id(presentation.mappedStops.map(\.id))
        } else {
            CYMapPlaceholder()
        }
    }
}

import SwiftUI

/// G7/G8 player routes. Each section renders nothing unless the shipped China composition
/// built the player grant for this viewer. Money and club host-only routes have no view here.
private struct PlayerGapServiceKey: EnvironmentKey { static let defaultValue: PlayerGapService? = nil }
extension EnvironmentValues {
    /// Injected once by `SessionRootView`; fixtures and non-China builds leave it nil, so every gap section hides.
    var playerGapService: PlayerGapService? {
        get { self[PlayerGapServiceKey.self] }
        set { self[PlayerGapServiceKey.self] = newValue }
    }
}

extension AppSession {
    var playerGapService: PlayerGapService? {
        guard let context = currentRuntimeDependencyContext, composition.playerWriteGrant(context) != nil else { return nil }
        let epoch = context.session.epoch, account = context.session.accountID
        return PlayerGapService(baseURL: context.baseURL, accountID: account, token: { [weak self] in
            guard let now = self?.currentRuntimeDependencyContext, now.session.epoch == epoch,
                  now.session.accountID == account else { return nil }
            return now.session.token
        }, transport: runtimeHTTPTransport)
    }
}

// MARK: official events

/// `official-detail` doSignup through the SIGNUP command with a kept request id.
struct OfficialSignupCommandSection: View {
    @Environment(\.playerGapService) private var service
    let eventID: Int
    var onSettled: () -> Void = {}
    /// PC-C-4-1: false while a 安全须知 is shown and not yet checked (MP toast 请先勾选安全须知).
    var consented = true
    @State private var flow: OfficialSignupCommandFlow?

    var body: some View {
        Group {
            if let flow {
                content(flow)
            }
        }
        .task(id: eventID) {
            guard let service = service, let account = service.accountID else { flow = nil; return }
            flow = OfficialSignupCommandFlow(service: service, store: OfficialSignupCommandDefaultsStore(), accountID: account, eventID: eventID)
        }
    }

    @ViewBuilder private func content(_ flow: OfficialSignupCommandFlow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            switch flow.phase {
            case .idle:
                Button("playerGap.signup.submit") { run { await flow.start() } }
                    .buttonStyle(CYPillButtonStyle(style: .primary, fullWidth: true))
                    .disabled(!consented)
                    .accessibilityIdentifier("gap.signup.submit")
                if !consented {
                    Text("official.safetyNotice.required").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                }
            case .busy:
                ProgressView()
            case .unknown:
                Text("playerGap.signup.unknown").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                HStack {
                    Button("playerGap.signup.query") { run { await flow.query() } }
                    Button("playerGap.signup.retry") { run { await flow.retry() } }
                    Button("playerGap.signup.cancel", role: .destructive) { run { await flow.cancel() } }
                }
                .buttonStyle(CYPillButtonStyle(style: .secondary))
            case .settled(let state, let message):
                settled(state, message: message)
                if flow.safetyBlocked { Text("playerGap.signup.safetyBlocked").cyText(.meta).foregroundStyle(CYColor.textSecondary) }
            case .storageError:
                Text("playerGap.signup.storageError").cyText(.meta).foregroundStyle(CYColor.dangerText)
            }
        }
    }

    @ViewBuilder private func settled(_ state: OfficialSignupReceipt.State, message: String?) -> some View {
        switch state {
        case .applied: Label("playerGap.signup.applied", systemImage: "checkmark.circle.fill").foregroundStyle(CYColor.successText)
        case .cancelled: Text("playerGap.signup.cancelled").foregroundStyle(CYColor.textSecondary)
        case .rejected:
            if let message, !message.isEmpty { Text(verbatim: message).foregroundStyle(CYColor.dangerText) }
            else { Text("playerGap.signup.rejected").foregroundStyle(CYColor.dangerText) }
        }
    }

    private func run(_ work: @escaping @MainActor () async -> OfficialSignupReceipt.State?) {
        Task { if await work() != nil { onSettled() } }
    }
}

/// BL-41 roam passport official-events card. `onPassportPlayTap('event')`: one open event navigates to
/// `official-detail?id=`; several open the roam official-task list (`openRoamTasks`).
struct OfficialRoamActiveCardView: View {
    @Environment(\.playerGapService) private var service
    /// Host-supplied destination for the card's tap; nil keeps the card as a plain label.
    var destination: ((Int?) -> AnyView)? = nil
    @State private var card: OfficialRoamActiveCard?

    var body: some View {
        Group {
            if let card {
                if let destination {
                    NavigationLink { destination(card.eventID) } label: { label(card) }
                        .accessibilityIdentifier("gap.roamEvents")
                } else {
                    label(card).accessibilityIdentifier("gap.roamEvents")
                }
            }
        }
        .task { card = await service?.activeOfficialForRoam() }
    }

    private func label(_ card: OfficialRoamActiveCard) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("playerGap.roamEvents.title").cyText(.cardTitle)
            if card.count > 1 { Text("playerGap.roamEvents.many \(card.firstTitle) \(card.count)").cyText(.meta) }
            else { Text("playerGap.roamEvents.one \(card.firstTitle)").cyText(.meta) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Where the BL-41 card leads: the one open event's detail, or (several open) the roam official-task list.
/// Same session-reader guard as `RoamOfficialTasksDestination`; a stale reader shows the changed state.
@MainActor struct RoamActiveOfficialEventDestination: View {
    @EnvironmentObject private var session: AppSession
    let roamReader: any RoamExperienceReading
    let eventID: Int?
    var body: some View {
        if let eventID {
            if ObjectIdentifier(roamReader) == ObjectIdentifier(session.roamExperienceReader), roamReader.identity != nil {
                OfficialEventDetailView(id: eventID, reader: session.officialEventReader, actions: session.officialActionCoordinator)
                    .id(session.sessionRevision)
            } else { CYEmptyState(systemImage: "person.crop.circle.badge.exclamationmark", "roam.tasks.changed") }
        } else {
            RoamOfficialTasksDestination(roamReader: roamReader)
        }
    }
}

// MARK: team

/// l-misc team invite mini-program code. Only for a member of a recruiting team.
struct TeamInviteQRSection: View {
    @Environment(\.playerGapService) private var service
    let teamID: Int
    /// C-D10: the team-detail sheet reads the code as it opens (MP openInviteQr); the inline section waits for a tap.
    var loadsOnAppear = false
    @State private var view: TeamInviteQRView?
    @State private var loading = false

    var body: some View {
        if service != nil {
            VStack(alignment: .leading, spacing: 8) {
                switch view {
                case .ready(let qr, let code)?:
                    AsyncImage(url: qr) { $0.resizable().scaledToFit() } placeholder: { ProgressView() }
                        .frame(maxWidth: 180, maxHeight: 180)
                        .accessibilityLabel(Text("playerGap.teamQR.image"))
                    // r8 C-D11-r7 (MP team/detail 邀请卡 保存图片): in-page notice, then add to Photos.
                    TeamInviteImageSaveRow(imageURL: qr)
                    codeLine(code)
                case .code(let code)?:
                    codeLine(code)
                case .error(let message)?:
                    if let message, !message.isEmpty { Text(verbatim: message).cyText(.meta).foregroundStyle(CYColor.textSecondary) }
                    else { Text("playerGap.teamQR.failed").cyText(.meta).foregroundStyle(CYColor.textSecondary) }
                case nil:
                    EmptyView()
                }
                if loading, view == nil { ProgressView().frame(maxWidth: .infinity) }
                if !loadsOnAppear || view == nil || failed {
                    Button("playerGap.teamQR.load") { load() }
                    .disabled(loading)
                    .buttonStyle(CYPillButtonStyle(style: .secondary, fullWidth: true))
                    .accessibilityIdentifier("gap.teamQR.load")
                }
            }
            .task { if loadsOnAppear, view == nil { load() } }
        }
    }

    private var failed: Bool { if case .error? = view { return true }; return false }

    private func load() {
        guard !loading, let service = service else { return }
        loading = true
        Task { view = await service.teamInviteQRCode(teamID: teamID); loading = false }
    }

    private func codeLine(_ code: String) -> some View {
        LabeledContent("playerGap.teamQR.code") { Text(verbatim: code).cyText(.numericBody).textSelection(.enabled) }
    }
}

/// Round 9 m2 #2: teams on the same activity. Consent first; polling only while the player shares,
/// the app is foreground, and location is already granted (the mini-program starts the poller from its
/// location watch). Each sync uploads only the points walked since the last success (≤40).
struct TeamTrailSection: View {
    @Environment(\.playerGapService) private var service
    @Environment(\.scenePhase) private var scenePhase
    let activityID: Int
    /// Count of done nodes on the run (`team-trail.js` `done()`).
    var done: () -> Int = { 0 }
    @State private var model: TeamTrailModel?
    @State private var recorder = TeamTrailForegroundRecorder()
    /// PLAY-r8-1 (MP AUDIT-1122 L01-039): the share switch starts off; only the player's own choice turns it on.
    @State private var share = false
    /// Native r2 city run map: mirrors this section's last team read onto the map (no extra request).
    @Environment(\.cityOrientationTeamsSink) private var teamsSink

    /// L01-039: never upload for a player who has not decided, even when the server's default says share.
    private var recording: Bool { scenePhase == .active && model?.canRun == true && model?.needsConsent == false }

    var body: some View {
        Group {
            if let model, model.state.available {
                VStack(alignment: .leading, spacing: 8) {
                    if model.needsConsent {
                        Toggle("playerGap.trail.share", isOn: $share)
                        Button("playerGap.trail.confirm") { Task { await model.consent(share) } }
                            .buttonStyle(CYPillButtonStyle(style: .primary, fullWidth: true))
                            .accessibilityIdentifier("gap.trail.confirm")
                    } else if model.state.share {
                        if !TeamTrailForegroundRecorder.isAuthorized {
                            Text("playerGap.trail.needsLocation").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                        }
                        ForEach(model.teams) { team in
                            HStack {
                                Text(verbatim: team.initial.isEmpty ? team.name : team.initial).cyText(.label)
                                Text(verbatim: team.name).cyText(.meta)
                                Spacer()
                                if team.done > 0 { Text("playerGap.trail.done \(team.done)").cyText(.meta).foregroundStyle(CYColor.textSecondary) }
                            }
                        }
                        Button("playerGap.trail.stop") { Task { await model.consent(false) } }
                            .buttonStyle(CYPillButtonStyle(style: .tertiary))
                    } else {
                        Button("playerGap.trail.start") { Task { await model.consent(true) } }
                            .buttonStyle(CYPillButtonStyle(style: .secondary))
                    }
                }
            }
        }
        .task(id: activityID) {
            guard activityID > 0, let service = service else { model = nil; return }
            let trail = TeamTrailModel(service: service, activityID: activityID)
            model = trail
            await trail.load()
            var wait = TeamTrailModel.interval
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(wait))
                guard !Task.isCancelled, trail.canRun, !trail.needsConsent, scenePhase == .active, TeamTrailForegroundRecorder.isAuthorized else { continue }
                let ok = await trail.tick(points: recorder.points, done: done())
                wait = ok ? TeamTrailModel.interval : min(wait * 2, TeamTrailModel.maxInterval)
            }
        }
        .onChange(of: recording, initial: true) { _, on in if on { recorder.start() } else { recorder.stop() } }
        .onChange(of: model?.state.share == true ? (model?.teams ?? []) : [], initial: true) { _, teams in teamsSink?(teams) }
        .onDisappear {
            recorder.stop()
            if let model { Task { await model.finish() } }
        }
    }
}

// MARK: club lead (member)

/// `leadArrive` and the member broadcast. Leader tools (start, unlock, release, scan, settle) stay hidden.
struct LeadMemberActionsSection: View {
    @Environment(\.playerGapService) private var service
    @Environment(\.locale) private var locale
    let activityID: Int
    let meArrived: Bool
    var reload: () -> Void = {}
    @State private var askLocation = false
    @State private var busy = false
    @State private var text = ""
    @State private var message: String?

    var body: some View {
        if service != nil, activityID > 0 {
            VStack(alignment: .leading, spacing: 8) {
                if !meArrived {
                    Button("playerGap.lead.arrive") { askLocation = true }
                        .disabled(busy)
                        .buttonStyle(CYPillButtonStyle(style: .primary, fullWidth: true))
                        .accessibilityIdentifier("gap.lead.arrive")
                }
                TextField("playerGap.lead.broadcastPlaceholder", text: $text, axis: .vertical)
                Button("playerGap.lead.broadcast") { broadcast() }
                    .disabled(busy || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .buttonStyle(CYPillButtonStyle(style: .secondary, fullWidth: true))
                if let message { Text(verbatim: message).cyText(.meta).foregroundStyle(CYColor.textSecondary) }
            }
            .confirmationDialog("playerGap.lead.arriveTitle", isPresented: $askLocation, titleVisibility: .visible) {
                Button("playerGap.lead.arriveConfirm") { arrive() }
            } message: { Text("playerGap.lead.arriveMessage") }
        }
    }

    private func arrive() {
        guard let service = service, !busy else { return }
        busy = true
        Task {
            defer { busy = false }
            let provider = RuntimeNativeLocationProvider(enabled: true)
            guard let fix = try? await RoamDeviceFixGCJ.currentGCJ02Fix(provider: provider) else {
                message = appLocalized("playerGap.lead.noLocation", locale: locale); return
            }
            let reply = await service.leadArrive(activityID: activityID, latitude: fix.coordinate.latitude, longitude: fix.coordinate.longitude)
            message = reply.message ?? appLocalized(reply.data != nil ? "playerGap.lead.arrived" : "playerGap.lead.retry", locale: locale)
            if reply.data != nil { reload() }
        }
    }

    private func broadcast() {
        guard let service = service, !busy else { return }
        busy = true
        let sent = text
        Task {
            defer { busy = false }
            let reply = await service.leadBroadcast(activityID: activityID, text: sent)
            message = reply.message ?? appLocalized(reply.data != nil ? "playerGap.lead.broadcasted" : "playerGap.lead.retry", locale: locale)
            if reply.data != nil { text = ""; reload() }
        }
    }
}

// MARK: profile

/// BL-71 personal invite code from `data.qr` only, plus the latest join record.
struct PlayerCodeAndJoinSection: View {
    @Environment(\.playerGapService) private var service
    @State private var qr: URL?
    @State private var join: RegistrationJoinInfo?
    @State private var loading = false

    var body: some View {
        if service != nil {
            VStack(alignment: .leading, spacing: 8) {
                if let join, join.hasJoin {
                    LabeledContent("playerGap.join.title") { Text(verbatim: join.title ?? "#\(join.id)") }
                }
                if let qr {
                    AsyncImage(url: qr) { $0.resizable().scaledToFit() } placeholder: { ProgressView() }
                        .frame(maxWidth: 180, maxHeight: 180)
                        .accessibilityLabel(Text("playerGap.playerCode.image"))
                } else {
                    Button("playerGap.playerCode.load") {
                        guard !loading, let service = service else { return }
                        loading = true
                        Task { qr = await service.playerCode(); loading = false }
                    }
                    .disabled(loading)
                    .buttonStyle(CYPillButtonStyle(style: .secondary, fullWidth: true))
                    .accessibilityIdentifier("gap.playerCode.load")
                }
            }
            .task {
                guard let service = service, let account = service.accountID else { return }
                join = await service.joinInfo(memberID: account)
            }
        }
    }
}

// MARK: city

/// OFF-FAV-01 favorites "nodes" tab: one full read.
struct CityFavoriteNodesSection: View {
    @Environment(\.playerGapService) private var service
    @State private var nodes: [CityFavoriteNode]?
    @State private var failed = false
    /// MP mylike 据点 (A4-01): 取消收藏 asks first, then drops the row only when the server says `favorited == false`.
    @State private var pendingRemoval: CityFavoriteNode?
    @State private var removing: Int?
    @State private var removalFailed: Int?

    var body: some View {
        if service != nil {
            Section("playerGap.cityFavorites.title") {
                if let nodes {
                    if nodes.isEmpty { Text("playerGap.cityFavorites.empty").cyText(.body).foregroundStyle(CYColor.textTertiary) }
                    ForEach(nodes) { node in
                        // r8 A4-01 (MP mylike.wxml:43 bindtap goNode → subpackageRoam/poi-detail?poiId=): the row opens the place.
                        NavigationLink {
                            MPReviewedPageScreen(page: "subpackageRoam/poi-detail/index", query: ["poiId": String(node.id), "name": node.name])
                        } label: { row(node) }
                            .accessibilityHint(Text("fixr8.favorites.node.openHint"))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("playerGap.cityFavorites.remove", role: .destructive) { pendingRemoval = node }
                                    .disabled(removing != nil)
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                // r9 A4-04b: MP mylike.wxml:49-53 分享据点 (open-type="share").
                                R9PublicShareButton(url: PublicContentShareLink.poi(id: node.id),
                                                    copyText: PublicContentShareLink.poiCopyText(id: node.id),
                                                    identifier: "favorites.node.share")
                            }
                            .contextMenu {
                                R9PublicShareButton(url: PublicContentShareLink.poi(id: node.id),
                                                    copyText: PublicContentShareLink.poiCopyText(id: node.id),
                                                    identifier: "favorites.node.share")
                                Button("playerGap.cityFavorites.remove", systemImage: "star.slash", role: .destructive) { pendingRemoval = node }
                                    .disabled(removing != nil)
                            }
                    }
                } else if failed {
                    // Missing state: say what failed, then 重试 (44 pt), not a bare button.
                    Label { Text("playerGap.cityFavorites.loadFailed") } icon: { Image(systemName: "exclamationmark.triangle").accessibilityHidden(true) }
                        .cyText(.body).foregroundStyle(CYColor.textSecondary)
                        .accessibilityIdentifier("playerGap.cityFavorites.failed")
                    Button("playerGap.retry") { Task { await load() } }
                        .frame(minHeight: CYSpacing.minTouchTarget)
                        .accessibilityIdentifier("playerGap.cityFavorites.retry")
                } else {
                    ProgressView { Text("playerGap.cityFavorites.loading") }
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("playerGap.cityFavorites.loading")
                }
            }
            .task { await load() }
            .confirmationDialog(Text("playerGap.cityFavorites.removeTitle"), isPresented: Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } }),
                                titleVisibility: .visible, presenting: pendingRemoval) { node in
                Button("playerGap.cityFavorites.remove", role: .destructive) { Task { await remove(node) } }
                Button("action.cancel", role: .cancel) { pendingRemoval = nil }
            } message: { node in Text(verbatim: node.name) }
        }
    }

    private func row(_ node: CityFavoriteNode) -> some View {
        HStack(spacing: CYSpacing.md) {
            Group {
                if let cover = node.cover.flatMap(URL.init(string:)), cover.scheme == "https" {
                    AsyncImage(url: cover) { $0.resizable().scaledToFill() } placeholder: { CYColor.bgSurfaceSubtle }
                } else {
                    // MP mylike.wxml:42 cover default `/pages/mylike/images/mer1.jpg`.
                    MPAsset.BannerCover.pagesMylikeImagesMer1.resizable().scaledToFill()
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: node.name.isEmpty ? "—" : node.name).cyText(.cardTitle).cyWrapText()
                if let address = node.address, !address.isEmpty { Text(verbatim: address).cyText(.meta).foregroundStyle(CYColor.textSecondary) }
                if removing == node.id { ProgressView().controlSize(.small) }
                if removalFailed == node.id {
                    Text("playerGap.cityFavorites.removeFailed").cyText(.meta).foregroundStyle(CYColor.dangerText)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("playerGap.cityFavorites.row.\(node.id)")
    }

    private func load() async {
        failed = false
        let read = await service?.favoriteCityNodes()
        nodes = read; failed = read == nil
    }

    private func remove(_ node: CityFavoriteNode) async {
        pendingRemoval = nil
        guard removing == nil, let service else { return }
        removing = node.id; removalFailed = nil
        let favorited = await service.toggleCityNodeFavorite(poiID: node.id)
        removing = nil
        switch favorited {
        case false?: nodes?.removeAll { $0.id == node.id }
        case true?:
            // The toggle turned it back on (state had changed elsewhere): read the list again instead of guessing.
            await load()
        case nil: removalFailed = node.id
        }
    }
}

/// BL-69 merchant public page node with its favorite toggle; no node hides the block.
struct MerchantCityNodeFavoriteRow: View {
    @Environment(\.playerGapService) private var service
    let merchantID: Int
    @State private var node: CityMerchantNode?
    @State private var favorited = false
    @State private var busy = false
    @State private var failed = false

    var body: some View {
        Group {
            if let node {
                HStack {
                    Label { Text(verbatim: node.name) } icon: { Image(systemName: "mappin.circle") }
                    Spacer()
                    Button { toggle(node.poiID) } label: {
                        Image(systemName: favorited ? "star.fill" : "star")
                    }
                    .disabled(busy)
                    .accessibilityLabel(Text(favorited ? "playerGap.node.unfavorite" : "playerGap.node.favorite"))
                }
                if failed { Text("playerGap.node.failed").cyText(.meta).foregroundStyle(CYColor.dangerText) }
            }
        }
        .task(id: merchantID) {
            node = await service?.merchantCityNode(merchantID: merchantID)
            favorited = node?.favorited ?? false
        }
    }

    private func toggle(_ poiID: Int) {
        guard let service = service, !busy else { return }
        busy = true; failed = false
        Task {
            if let value = await service.toggleCityNodeFavorite(poiID: poiID) { favorited = value } else { failed = true }
            busy = false
        }
    }
}

// MARK: media, cards, publish, club

/// U02-05 node image credit: attribution only; a failed or unreviewed read draws nothing.
struct AssetCreditText: View {
    @Environment(\.playerGapService) private var service
    let reference: String
    @State private var credit: String?

    var body: some View {
        Group {
            if let credit { Text(verbatim: credit).cyText(.caption).foregroundStyle(CYColor.textSecondary) }
        }
        .task(id: reference) { credit = await service?.assetCredit(reference: reference) }
    }
}

/// BL-79 object-card rename. The server validates; its text is shown as is.
struct ObjectCardRenameButton: View {
    @Environment(\.playerGapService) private var service
    @Environment(\.locale) private var locale
    let cardID: Int
    let title: String
    var renamed: (String) -> Void = { _ in }
    @State private var editing = false
    @State private var draft = ""
    @State private var error: String?
    @State private var busy = false

    var body: some View {
        if service != nil, cardID > 0 {
            Button { draft = title; error = nil; editing = true } label: { Image(systemName: "pencil") }
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
                .accessibilityLabel(Text("playerGap.card.rename"))
                // OCARDS-4 (MP object-cards wxml:91 改名 sheet): 64-char field with count, inline server error, 保存.
                .cySheet(isPresented: $editing) {
                    ObjectCardRenameSheetView(initialName: draft, errorMessage: error, isSaving: busy,
                                              onSave: { save($0) }, onClose: { editing = false })
                }
        }
    }

    private func save(_ text: String) {
        guard let service = service, !busy else { return }
        draft = text
        error = nil
        busy = true
        Task {
            defer { busy = false }
            switch await service.renameObjectCard(id: cardID, title: text) {
            case .renamed(let saved): renamed(saved); editing = false
            case .failed(let message): error = message ?? appLocalized("playerGap.card.renameFailed", locale: locale)
            }
        }
    }
}

/// Activity publish entry gate: 200 allows; 403 shows the server reason.
struct ActivityPublishPrecheckGate<Content: View>: View {
    @Environment(\.playerGapService) private var service
    var merchantHost = false
    @ViewBuilder let content: () -> Content
    @State private var result: ActivityPublishPrecheck?
    @State private var showsSignIn = false

    var body: some View {
        Group {
            if service == nil { content() }
            else {
                switch result {
                case .allowed?: content()
                case .denied(let reason)?:
                    ContentUnavailableView { Label("playerGap.publish.denied", systemImage: "lock") } description: {
                        if let reason, !reason.isEmpty { Text(verbatim: reason) }
                    }
                case .signInRequired?:
                    // C-A5: MP 登录后发布活动 + 去登录.
                    ContentUnavailableView {
                        Label("playerGap.publish.signIn", systemImage: "person.crop.circle")
                    } actions: {
                        Button("action.goSignIn") { showsSignIn = true }.buttonStyle(.cyPrimary)
                            .accessibilityIdentifier("playerGap.publish.goSignIn")
                    }
                    .cySheet(isPresented: $showsSignIn) { Group { LoginView(intent: .player) }.cySheet(detents: [.large]) }
                case .failed(let message)?:
                    ContentUnavailableView { Label("playerGap.publish.failed", systemImage: "exclamationmark.triangle") } description: {
                        if let message, !message.isEmpty { Text(verbatim: message) }
                    } actions: {
                        Button("playerGap.retry") { Task { await check() } }
                    }
                case nil:
                    ProgressView()
                }
            }
        }
        .task { await check() }
    }

    private func check() async {
        guard let service = service else { return }
        result = nil
        result = await service.publishPrecheck(merchantHost: merchantHost)
    }
}

/// Club post like readback after a like whose outcome was not confirmed.
struct ClubPostLikeStateButton: View {
    @Environment(\.playerGapService) private var service
    let postID: Int
    let clubID: Int
    var resolved: (ClubPostLikeState) -> Void = { _ in }
    @State private var message: LocalizedStringKey?
    @State private var busy = false

    var body: some View {
        if service != nil {
            VStack(alignment: .leading, spacing: 4) {
                Button("playerGap.like.check") {
                    guard let service = service, !busy else { return }
                    busy = true
                    Task {
                        defer { busy = false }
                        if let state = await service.clubPostLikeState(postID: postID, clubID: clubID) {
                            message = state.isLiked ? "playerGap.like.liked" : "playerGap.like.notLiked"; resolved(state)
                        } else { message = "playerGap.like.unresolved" }
                    }
                }
                .disabled(busy)
                .accessibilityIdentifier("gap.like.check")
                if let message { Text(message).cyText(.meta).foregroundStyle(CYColor.textSecondary) }
            }
        }
    }
}

/// §27.6 request a host for a waitlisted ticket. The result is the reread reservation state.
struct ClubHostRequestButton: View {
    @Environment(\.playerGapService) private var service
    @Environment(\.locale) private var locale
    let activityID: Int
    let ticketID: Int
    var reload: () -> Void = {}
    @State private var busy = false
    @State private var message: String?

    var body: some View {
        if service != nil, activityID > 0, ticketID > 0 {
            VStack(alignment: .leading, spacing: 4) {
                Button("playerGap.host.request") {
                    guard let service = service, !busy else { return }
                    busy = true
                    Task {
                        let reply = await service.requestHost(activityID: activityID, ticketID: ticketID)
                        if reply.data == nil { message = reply.message ?? appLocalized("playerGap.host.unavailable", locale: locale) }
                        busy = false; reload()
                    }
                }
                .disabled(busy)
                .buttonStyle(CYPillButtonStyle(style: .secondary, fullWidth: true))
                .accessibilityIdentifier("gap.host.request")
                if let message { Text(verbatim: message).cyText(.meta).foregroundStyle(CYColor.textSecondary) }
            }
        }
    }
}

import SwiftUI

@MainActor final class CoopInvitationReadModel: ObservableObject {
    struct Permit: Equatable { let id: UUID; let session: CoopFlowSession?; let kind: CoopFlowTargetKind }
    let reader: any CoopFlowReading
    let operationScope: String?
    @Published private(set) var kind: CoopFlowTargetKind = .merchant
    @Published private(set) var topics: [CoopFlowOwnedTopic] = []
    @Published private(set) var candidates: [CoopFlowTargetCandidate] = []
    /// Club member counts from CoopInviteIndexReadiness. Unknown is an em dash. Merchants are absent.
    @Published private(set) var memberCounts: [String: CoopInviteIndexReadiness.Count] = [:]
    @Published private(set) var topicID: Int?
    @Published private(set) var selected: Set<String> = []
    @Published private(set) var topicsFailed = false
    @Published private(set) var targetsFailed = false
    @Published private(set) var topicsBusy = false
    @Published private(set) var targetsBusy = false
    @Published private(set) var hasMore = true
    private var topicsReady = false, targetsReady = false
    private var page = 1, failedPage: Int?
    @Published private var visible = false
    @Published private var active = false
    private var generation = UUID(), topicRun: UUID?, targetRun: UUID?
    private var session: CoopFlowSession?
    /// MC8-31-1: route presets (`type` / `toId` / `topicId`). They survive reloads; the matching rows are chosen once loaded.
    private(set) var presetTopicID: Int?
    private(set) var presetTargetID: Int?
    init(reader: any CoopFlowReading, operationScope: String?) { self.reader = reader; self.operationScope = operationScope; session = reader.session }
    /// Call before the first appear. `kind` follows MP `type` (0 merchant, 1 club).
    func applyRoutePreset(kind: CoopFlowTargetKind?, targetID: Int?, topicID: Int?) {
        if let kind { self.kind = kind }
        presetTargetID = targetID.flatMap { $0 > 0 ? $0 : nil }
        presetTopicID = topicID.flatMap { $0 > 0 ? $0 : nil }
    }
    /// The route topic once it is among the loaded owned topics.
    var lockedTopic: CoopFlowOwnedTopic? { presetTopicID == nil ? nil : topic }
    /// The route target once it is in the loaded directory.
    var lockedTarget: CoopFlowTargetCandidate? {
        guard let presetTargetID, isCurrent else { return nil }
        return candidates.first { $0.recipient.id == presetTargetID }
    }
    /// MC8-31-3: topics loaded without error and none can be linked.
    var topicsLoadedEmpty: Bool { isCurrent && topicsReady && !topicsBusy && !topicsFailed && topics.isEmpty }
    var permit: Permit { .init(id: generation, session: session, kind: kind) }
    var isCurrent: Bool { visible && active && session != nil && session == reader.session }
    var busy: Bool { topicsBusy || targetsBusy }
    var topic: CoopFlowOwnedTopic? { isCurrent ? topics.first { $0.id == topicID } : nil }
    private func accepts(_ value: Permit) -> Bool { isCurrent && value == permit && !Task.isCancelled }
    func appear(active: Bool) -> Permit {
        if session != reader.session { reset() }
        visible = true; self.active = active; return permit
    }
    func disappear() { visible = false; invalidateRuns() }
    func sceneChanged(active: Bool) { self.active = active; if !active { invalidateRuns() } }
    func identityChanged() { reset() }
    private func invalidateRuns() { generation = UUID(); topicRun = nil; targetRun = nil; topicsBusy = false; targetsBusy = false }
    private func reset() {
        invalidateRuns(); session = reader.session; topics = []; candidates = []; memberCounts = [:]; topicID = nil; selected = []
        topicsReady = false; targetsReady = false; topicsFailed = false; targetsFailed = false; page = 1; failedPage = nil; hasMore = true
    }
    func changeKind(_ value: CoopFlowTargetKind, permit old: Permit) -> Permit? {
        guard accepts(old), !busy, value != kind else { return nil }
        kind = value; reset(); return permit
    }
    func chooseTopic(_ id: Int?, permit value: Permit) {
        guard accepts(value), !topicsBusy, id == nil || topics.contains(where: { $0.id == id }) else { return }
        topicID = id
    }
    func toggle(_ id: String, permit value: Permit) {
        guard accepts(value), targetsReady, !targetsBusy, candidates.contains(where: { $0.id == id }) else { return }
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }
    func contexts(permit value: Permit) -> [CoopFlowInvitationContext]? {
        guard accepts(value), topicsReady, targetsReady, !busy, let topic, topic.inviteWindowOpen == true, !selected.isEmpty else { return nil }
        let result = candidates.filter { selected.contains($0.id) }.compactMap {
            CoopFlowInvitationContext(candidate: $0, topic: topic, scope: operationScope, session: session)
        }
        return result.count == selected.count ? result : nil
    }
    func loadInitial(_ value: Permit) async {
        guard accepts(value) else { return }
        if !topicsReady { await readTopics(value, requested: 1, append: false) }
        guard accepts(value) else { return }
        if !targetsReady { await retryTargets(value) }
    }
    func retryTopics(_ value: Permit) async {
        let requested = failedPage ?? 1
        await readTopics(value, requested: requested, append: requested > 1)
    }
    func more(_ value: Permit) async {
        guard topicsReady, hasMore, !topicsFailed else { return }
        await readTopics(value, requested: page, append: true)
    }
    private func refuses(_ error: Error) -> Bool {
        if let e = error as? CoopFlowFailure {
            switch e { case .permission, .disabled, .stale: return true; case .server(let code, _): return code == 401 || code == 403; default: break }
        }
        if let e = error as? APIError {
            switch e { case .unauthorized, .notConfigured: return true; case .httpStatus(let code): return code == 401 || code == 403; default: break }
        }
        return false
    }
    private func readTopics(_ value: Permit, requested: Int, append: Bool) async {
        guard accepts(value), !topicsBusy, requested > 0 else { return }
        let run = UUID(); topicRun = run; topicsBusy = true; topicsFailed = false
        defer { if topicRun == run { topicRun = nil; topicsBusy = false } }
        do {
            let result = try await reader.read(.ownedTopics(kind: value.kind, scope: operationScope, page: requested), isCurrent: { [weak self] in
                guard let self else { return false }; return self.accepts(value) && self.topicRun == run
            })
            guard accepts(value), topicRun == run else { return }
            guard let rows = result["rows"].rows else { throw CoopFlowFailure.malformed }
            let parsed = rows.compactMap(CoopFlowOwnedTopic.init)
            guard parsed.count == rows.count, Set(parsed.map(\.id)).count == parsed.count else { throw CoopFlowFailure.malformed }
            var seen = Set((append ? topics : []).map(\.id))
            topics = (append ? topics : []) + parsed.filter { seen.insert($0.id).inserted }
            if let id = topicID, !topics.contains(where: { $0.id == id }) { topicID = nil }
            if topicID == nil, let preset = presetTopicID, topics.contains(where: { $0.id == preset }) { topicID = preset }
            topicsReady = true; failedPage = nil; hasMore = rows.count == 20; page = requested + 1
        } catch {
            guard accepts(value), topicRun == run else { return }
            topicsFailed = true; failedPage = requested
            if refuses(error) { topics = []; topicID = nil; topicsReady = false; hasMore = true; page = 1; failedPage = 1 }
        }
    }
    func retryTargets(_ value: Permit) async {
        guard accepts(value), !targetsBusy else { return }
        let run = UUID(); targetRun = run; targetsBusy = true; targetsFailed = false
        defer { if targetRun == run { targetRun = nil; targetsBusy = false } }
        do {
            let result = try await reader.read(value.kind == .merchant ? .merchants(name: nil) : .clubs(name: nil), isCurrent: { [weak self] in
                guard let self else { return false }; return self.accepts(value) && self.targetRun == run
            })
            guard accepts(value), targetRun == run else { return }
            guard let rows = result.rows else { throw CoopFlowFailure.malformed }
            let parsed = rows.compactMap { CoopFlowTargetCandidate(kind: value.kind, row: $0) }
            guard parsed.count == rows.count, Set(parsed.map(\.id)).count == parsed.count else { throw CoopFlowFailure.malformed }
            let directory = CoopInviteIndexReadiness.targets(kind: value.kind, loading: false, payload: result, failed: false)
            guard directory.phase == .ready || directory.phase == .empty else { throw CoopFlowFailure.malformed }
            candidates = parsed
            memberCounts = Dictionary(uniqueKeysWithValues: directory.rows.compactMap { row in row.memberCount.map { (row.id, $0) } })
            selected.formIntersection(Set(parsed.map(\.id))); targetsReady = true
            if let preset = presetTargetID, let target = parsed.first(where: { $0.recipient.id == preset }) { selected = [target.id] }
        } catch {
            guard accepts(value), targetRun == run else { return }
            targetsFailed = true
            if refuses(error) { candidates = []; memberCounts = [:]; selected = []; targetsReady = false }
        }
    }
}

/// Original send receipts and confirmed supply stations for `pages/coop/invite`.
@MainActor struct CoopInviteReceiptSections: View {
    let reader: any CoopFlowReading
    let kind: CoopFlowTargetKind
    let topicID: Int?
    let merchantMemberIDs: [Int]
    /// MC7-31-2: MP `unknownTargets` — the 原请求 block shows only after a send whose outcome is unknown.
    var showsRequests = false
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var requests = Load.loading
    @State private var requestRows: [CoopFlowJSON] = []
    @State private var stations = Load.idle
    @State private var stationRows: [CoopFlowJSON] = []
    private enum Load: Equatable { case idle, loading, empty, failed, ready }
    private struct RequestKey: Hashable { let session: Bool; let shows: Bool }
    private var stationKey: String { "\(kind.rawValue):\(topicID ?? 0):\(merchantMemberIDs.sorted().map(String.init).joined(separator: ","))" }
    var body: some View {
        Group {
            if showsRequests {
                Section {
                    sectionTitle(locale.pick("原请求", "Original requests"))
                    Text(verbatim: locale.pick("以下邀请结果待确认，请勿重复发送。记录未出现也不能证明未发送；无法确认时请联系平台处理。",
                                               "These invitations are not confirmed yet. Do not send them again. A missing record does not prove nothing was sent; contact the platform if you cannot confirm."))
                        .cyText(.meta).foregroundStyle(CYColor.warningText).fixedSize(horizontal: false, vertical: true)
                    requestBody
                }
                .accessibilityIdentifier("cooperation.invite.unknownOutcome")
            }
            if kind == .merchant, let topicID, topicID > 0, !merchantMemberIDs.isEmpty {
                Section {
                    sectionTitle(locale.pick("已确定据点", "Confirmed stations"))
                    stationBody
                }
            }
        }
        .task(id: RequestKey(session: reader.session != nil, shows: showsRequests)) { if showsRequests { await loadRequests() } }
        .task(id: stationKey) { await loadStations() }
    }
    private func sectionTitle(_ title: String) -> some View {
        Text(verbatim: title)
            .cyText(.sectionTitle)
            .foregroundStyle(CYColor.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }
    private var rowGap: CGFloat { dynamicTypeSize.isAccessibilitySize ? CYSpacing.sm : CYSpacing.xxs }
    @ViewBuilder private var requestBody: some View {
        if reader.session == nil { Text("cooperation.login").cyText(.body).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true) }
        else {
            switch requests {
            case .idle, .loading: CYSkeleton().accessibilityLabel(Text(verbatim: locale.pick("读取中", "Loading")))
            case .empty:
                Text(verbatim: locale.pick("未查到本次发送记录；仍可能已经发出，请勿重复发送", "No original send was found. It may still have been sent. Do not send again."))
                    .cyText(.body).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            case .failed:
                Text(verbatim: locale.pick("原请求暂无法查询，请勿重复发送", "The original request cannot be read right now. Do not send again."))
                    .cyText(.body).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                CYPillButton(verbatim: locale.pick("重试", "Try again"), style: .secondary, fullWidth: dynamicTypeSize.isAccessibilitySize) { Task { await loadRequests() } }
            case .ready:
                // MP coop/invite/index.wxml:24: human copy per row; raw state / requestId stay hidden.
                ForEach(Array(requestRows.enumerated()), id: \.offset) { _, row in
                    valueLine(stateLine(row["state"].text), style: .bodyMedium, color: CYColor.textPrimary)
                }
            }
        }
    }
    @ViewBuilder private var stationBody: some View {
        if reader.session == nil { Text("cooperation.login").cyText(.body).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true) }
        else {
            switch stations {
            case .idle, .loading: CYSkeleton().accessibilityLabel(Text(verbatim: locale.pick("读取中", "Loading")))
            case .empty:
                Text(verbatim: locale.pick("暂无已确定据点", "No confirmed station")).cyText(.body).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            case .failed:
                Text(verbatim: locale.pick("据点读取失败，请重试", "Stations did not load. Try again.")).cyText(.body).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                CYPillButton(verbatim: locale.pick("重试", "Try again"), style: .secondary, fullWidth: dynamicTypeSize.isAccessibilitySize) { Task { await loadStations() } }
            case .ready:
                if stationRows.isEmpty { valueLine(nil, style: .body, color: CYColor.textSecondary) }
                ForEach(Array(stationRows.enumerated()), id: \.offset) { _, row in
                    valueLine(row["stationName"].text, style: .body, color: CYColor.textPrimary)
                }
            }
        }
    }
    private func stateLine(_ state: String?) -> String {
        state == "CREATED" ? locale.pick("邀请已创建", "Invitation created")
                           : locale.pick("结果仍待确认，请勿重复发送", "Still unconfirmed. Do not send again.")
    }
    private func valueLine(_ text: String?, style: CYTextStyle, color: Color) -> some View {
        Text(verbatim: text ?? "—")
            .cyText(style)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }
    private func loadRequests() async {
        guard reader.session != nil else { requests = .idle; return }
        requests = .loading
        do {
            let page = try await reader.read(.inviteRequests(before: nil, limit: 20))
            let rows = page["rows"].rows ?? []
            requestRows = rows
            requests = rows.isEmpty ? .empty : .ready
        } catch { requests = .failed }
    }
    private func loadStations() async {
        guard kind == .merchant, let topicID, topicID > 0, !merchantMemberIDs.isEmpty, reader.session != nil else {
            stations = .idle; stationRows = []; return
        }
        stations = .loading
        do {
            var found: [CoopFlowJSON] = []
            for memberID in merchantMemberIDs where memberID > 0 {
                let page = try await reader.read(.supplyStations(topicID: topicID, merchantMemberID: memberID))
                found.append(contentsOf: page["stations"].rows ?? [])
            }
            stationRows = found
            stations = found.isEmpty ? .empty : .ready
        } catch { stations = .failed }
    }
}

@MainActor struct CoopFlowNewInvitationView: View {
    let reader: any CoopFlowReading
    let operationScope: String?
    /// MC8-31-1: MP `type` (0 merchant, 1 club). Nil keeps the page default.
    var initialType: Int? = nil
    /// MC8-31-4: a fixed recipient (coop/list 回邀约 / 发邀约, or `toId`). The picker is skipped.
    var lockedTarget: CoopInviteLockedTarget? = nil
    /// MC8-31-2: a fixed topic (`topicId`).
    var initialTopicID: Int? = nil
    private struct Identity: Hashable { let reader: ObjectIdentifier; let scope: String? }
    var body: some View {
        if reader.session == nil {
            // MC7-31-1: one signed-out state (MP coop/invite/index.wxml:11 登录后发起协作邀请 + 去登录), not per-section text.
            Form {
                MerchantCoopSignInState(title: "merchantCoop.invite.signIn", identifier: "cooperation.invite.signIn")
                    .listRowBackground(Color.clear)
            }
            .cyMiniListScreen().navigationTitle("context.coop.new").navigationBarTitleDisplayMode(.inline)
        } else {
            CoopInvitationReadContent(reader: reader, operationScope: operationScope, initialType: lockedTarget?.type ?? initialType,
                                      lockedTarget: lockedTarget, initialTopicID: initialTopicID)
                .id(Identity(reader: ObjectIdentifier(reader), scope: operationScope))
        }
    }
}
@MainActor private struct CoopInvitationReadContent: View {
    let reader: any CoopFlowReading
    let operationScope: String?
    @StateObject private var model: CoopInvitationReadModel
    @State private var search = ""
    @State private var editing: [CoopFlowInvitationContext] = []
    @State private var showEditor = false
    @State private var sendOutcomeUnknown = false
    @Environment(\.coopInviteSent) private var inviteSent
    @Environment(\.cooperationNearbyDestination) private var nearbyDestination
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.coopTopicPublishDestination) private var topicPublishDestination
    @Environment(\.locale) private var locale
    @State private var publishingTopic = false
    private let lockedTargetPreset: CoopInviteLockedTarget?
    private let initialTopicID: Int?
    init(reader: any CoopFlowReading, operationScope: String?, initialType: Int? = nil,
         lockedTarget: CoopInviteLockedTarget? = nil, initialTopicID: Int? = nil) {
        self.reader = reader; self.operationScope = operationScope
        self.lockedTargetPreset = lockedTarget; self.initialTopicID = initialTopicID
        let model = CoopInvitationReadModel(reader: reader, operationScope: operationScope)
        model.applyRoutePreset(kind: initialType.flatMap(CoopFlowTargetKind.init(rawValue:)),
                               targetID: lockedTarget?.toID, topicID: initialTopicID)
        _model = StateObject(wrappedValue: model)
    }
    /// MP fallback names when the route target is not in the loaded directory (该俱乐部 / 该商家).
    private var lockedTargetTitle: String? {
        guard let preset = lockedTargetPreset else { return nil }
        if let found = model.lockedTarget { return found.name }
        if !preset.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return preset.name }
        return appLocalized(preset.type == CoopFlowTargetKind.club.rawValue ? "merchantCoop.invite.lockedClub" : "merchantCoop.invite.lockedMerchant", locale: locale)
    }
    private var filtered: [CoopFlowTargetCandidate] {
        guard model.isCurrent else { return [] }
        return search.isEmpty ? model.candidates : model.candidates.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }
    var body: some View {
        let permit = model.permit
        Form {
            Section {
                CYHeroHeader("context.coop.new", subtitle: "context.coop.topic")
                    .listRowInsets(EdgeInsets(top: CYSpacing.md, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.sm, trailing: CYSpacing.pageHorizontal))
                    .listRowBackground(Color.clear)
            }
            Section("context.coop.topic") {
                if model.topicsFailed { Button("action.retry") { Task { await model.retryTopics(permit) } }.disabled(model.topicsBusy) }
                if let locked = model.lockedTopic {
                    CoopInviteLockedRow(title: locked.name, detail: "merchantCoop.invite.lockedTopicScope", identifier: "cooperation.invite.lockedTopic")
                } else if model.topicsLoadedEmpty {
                    // MC8-31-3 (wxml:46): 还没有可关联的主题 + 先发布主题.
                    CYEmptyState("merchantCoop.invite.noTopics",
                                 actionTitle: topicPublishDestination == nil ? nil : "merchantCoop.invite.publishTopic",
                                 actionIdentifier: "cooperation.invite.publishTopic",
                                 action: { publishingTopic = true })
                } else {
                Picker("context.coop.topic", selection: Binding(get: { model.isCurrent ? model.topicID : nil }, set: { model.chooseTopic($0, permit: permit) })) {
                    Text("context.coop.chooseTopic").tag(Optional<Int>.none)
                    ForEach(model.isCurrent ? model.topics : []) { row in
                        Text(verbatim: [row.name, row.startDate, row.address].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")).tag(Optional(row.id))
                    }
                }.disabled(model.topicsBusy)
                }
                // Mini `.card-hint--warn`: topic not in its recruiting window.
                if model.topic != nil, model.topic?.inviteWindowOpen != true { Text("context.coop.closed").cyText(.meta).foregroundStyle(CYColor.warningText) }
                if model.lockedTopic == nil, model.hasMore, !model.topics.isEmpty { Button("context.picker.more") { Task { await model.more(permit) } }.disabled(model.topicsBusy || model.topicsFailed) }
            }
            // Source order: ① 关联主题, ③ 邀请对象 (club / merchant switch inside it); terms follow in the editor.
            Section("context.coop.targets") {
              if let lockedTargetTitle {
                // MC8-31-4: 已选定，发送前不可更换.
                CoopInviteLockedRow(title: lockedTargetTitle, detail: "merchantCoop.invite.lockedTargetHint", identifier: "cooperation.invite.lockedTarget")
                if model.busy { CYSkeleton().accessibilityLabel(Text("cooperation.loading")) }
                if model.targetsFailed { CYPillButton("action.retry", style: .secondary) { Task { await model.retryTargets(permit) } }.disabled(model.targetsBusy) }
                if !model.busy, !model.targetsFailed, model.lockedTarget == nil {
                    Text("merchantCoop.invite.lockedTargetMissing").cyText(.meta).foregroundStyle(CYColor.warningText)
                }
              } else {
                Picker("context.coop.kind", selection: Binding(get: { model.kind }, set: { value in
                    guard let next = model.changeKind(value, permit: permit) else { return }
                    editing = []; showEditor = false; search = ""
                    Task { await model.loadInitial(next) }
                })) {
                    Text("coopflow.invite.club").tag(CoopFlowTargetKind.club)
                    Text("context.coop.merchant").tag(CoopFlowTargetKind.merchant)
                }
                .pickerStyle(.segmented)
                .disabled(model.busy)
                if model.kind == .merchant, nearbyDestination != nil {
                    // Source: "附近商家 · 含未入驻商家可电话联系" opens pages/coop/nearby for the chosen topic.
                    NavigationLink { CoopFlowNearbyGate(reader: reader) } label: { Text("cooperation.invite.nearby") }
                        .accessibilityIdentifier("cooperation.invite.nearby")
                }
                TextField("context.coop.search", text: $search).accessibilityIdentifier("context.coop.search")
                if model.busy { CYSkeleton().accessibilityLabel(Text("cooperation.loading")) }
                if model.targetsFailed { CYPillButton("action.retry", style: .secondary) { Task { await model.retryTargets(permit) } }.disabled(model.targetsBusy) }
                if !model.busy, !model.targetsFailed, filtered.isEmpty {
                    CYEmptyState("context.picker.empty")
                    // MC7-31-5: MP coop/invite/index.wxml:100,110 刷新合作对象.
                    Button { Task { await model.retryTargets(permit) } } label: {
                        Label("merchantCoop.invite.refreshTargets", systemImage: "arrow.clockwise").frame(minHeight: CYSpacing.minTouchTarget)
                    }
                    .disabled(model.targetsBusy)
                    .accessibilityIdentifier("cooperation.invite.refreshTargets")
                }
                ForEach(filtered) { candidate in
                    Button { model.toggle(candidate.id, permit: permit) } label: {
                        HStack {
                            // MP coop/invite/index.wxml:93,106 `.target-logo` (`item.logo || /images/d_logo.png`). The candidate
                            // has no decoded logo yet (Core request in the receipt), so the MP default shows.
                            MerchantCoopMPThumb(urlString: nil, fallback: .logo)
                            VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                                Text(verbatim: candidate.name).cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary)
                                CoopInviteTargetMeta(candidate: candidate, memberCount: model.memberCounts[candidate.id]).cyText(.meta).foregroundStyle(CYColor.textTertiary)
                            }
                            Spacer()
                            // Mini `.target-action`: "已选" chip when chosen; a check keeps it native.
                            if model.selected.contains(candidate.id) {
                                CYStatusChip("context.coop.selected", tone: .neutral, systemImage: "checkmark")
                            }
                        }
                    }.disabled(model.targetsBusy || !model.isCurrent)
                        .accessibilityAddTraits(model.selected.contains(candidate.id) ? .isSelected : [])
                        .accessibilityIdentifier("context.coop.target.\(candidate.id)")
                }
              }
            }
            CoopInviteReceiptSections(reader: reader, kind: model.kind, topicID: model.topic?.id, merchantMemberIDs: model.candidates.filter { model.selected.contains($0.id) && $0.kind == .merchant }.map(\.recipient.id),
                                      showsRequests: sendOutcomeUnknown)
            if !model.selected.isEmpty, model.isCurrent {
                CYListRow("context.coop.selected", trailing: .value(model.selected.isEmpty ? "—" : String(model.selected.count)))
                // Mini `.cta-bar`: one solid action for the whole screen.
                CYPillButton("context.coop.continue") {
                    guard let contexts = model.contexts(permit: permit) else { return }
                    editing = contexts; showEditor = true
                }
                .listRowBackground(Color.clear)
                .disabled(model.contexts(permit: permit) == nil)
            }
            CoopFlowSafetyNotice()
        }.cyMiniListScreen().navigationTitle("context.coop.new").navigationBarTitleDisplayMode(.inline).scrollDismissesKeyboard(.interactively)
            .onAppear {
                let value = model.appear(active: scenePhase == .active)
                Task { await model.loadInitial(value) }
            }
            .onChange(of: reader.session) { _, _ in
                model.identityChanged(); editing = []; showEditor = false; search = ""
                let value = model.permit; Task { await model.loadInitial(value) }
            }
            .onChange(of: scenePhase) { _, phase in
                model.sceneChanged(active: phase == .active)
                if phase == .active { let value = model.permit; Task { await model.loadInitial(value) } }
            }
            .onDisappear { model.disappear() }
            .navigationDestination(isPresented: $publishingTopic) {
                if let topicPublishDestination { topicPublishDestination(operationScope) }
            }
            .sheet(isPresented: $showEditor) {
                NavigationStack { CoopFlowBatchInviteEditor(reader: reader, contexts: editing) }
                    .environment(\.coopInviteOutcomeUnknown, { sendOutcomeUnknown = true })
                    // flows-g2 108: only a one-target send leaves the page; with several drafts the others stay sendable.
                    .environment(\.coopInviteSent, editing.count == 1 ? inviteSent.map { sent in { showEditor = false; sent() } } : nil)
                    .cyDomainSheet(detents: [.half, .full])
            }
    }
}

@MainActor struct CoopPeerCreditView: View {
    let reader: any CoopFlowReading
    let peer: CoopPeerMember
    @State private var credit: CoopFlowJSON?
    @State private var summary: CoopFlowJSON?
    @State private var creditFailed = false
    @State private var summaryFailed = false
    @State private var busy = false
    @State private var generation = 0
    var body: some View {
        List {
            if busy { CYSkeleton(variant: .row).accessibilityLabel(Text("cooperation.loading")) }
            Section("coopflow.credit") {
                if creditFailed { Text("coopflow.read.failed"); Button("action.retry") { Task { await load() } } }
                else if let credit {
                    if credit == .null || credit == .object([:]) { Text("context.coop.noReputation") }
                    else { CoopFlowFields(value: credit, keys: ["fulfillmentRate", "violationCount"]) }
                }
            }
            Section("coopflow.reviews") {
                if summaryFailed { Text("coopflow.read.failed"); Button("action.retry") { Task { await load() } } }
                else if let summary {
                    if summary == .null || summary == .object([:]) { Text("context.coop.noReputation") }
                    if let count = summary["count"].integer { LabeledContent("context.coop.reviewCount", value: String(count)) }
                    if let avg = summary["avg"].text { LabeledContent("context.coop.reviewAverage", value: avg) }
                    if summary["count"].integer == 0 { Text("coopflow.reviews.empty") }
                }
            }
        }.navigationTitle("context.coop.peerCredit").navigationBarTitleDisplayMode(.inline)
            .task(id: "\(reader.session?.accountID ?? 0):\(reader.session?.epoch ?? 0)") { await load() }
            .onChange(of: reader.session) { _, _ in generation += 1; credit = nil; summary = nil; busy = false }
            .onDisappear { generation += 1; busy = false }
        .cyDomainScreen(.merchant)
    }
    private func load() async {
        generation += 1; let request = generation, session = reader.session
        credit = nil; summary = nil; creditFailed = false; summaryFailed = false; busy = true
        guard session != nil else { busy = false; return }
        async let a: Void = readCredit(request: request, session: session)
        async let b: Void = readSummary(request: request, session: session)
        _ = await (a, b)
        if request == generation { busy = false }
    }
    private func readCredit(request: Int, session: CoopFlowSession?) async {
        do {
            let value = try await reader.read(.credit(memberID: peer.memberID))
            guard request == generation, session == reader.session, !Task.isCancelled else { return }
            credit = value["credit"] == .null ? value : value["credit"]
        } catch { if request == generation, session == reader.session { creditFailed = true } }
    }
    private func readSummary(request: Int, session: CoopFlowSession?) async {
        do {
            let value = try await reader.read(.reviewSummary(memberID: peer.memberID))
            guard request == generation, session == reader.session, !Task.isCancelled else { return }
            summary = value["summary"]
        } catch { if request == generation, session == reader.session { summaryFailed = true } }
    }
}

@MainActor struct CoopFlowBatchInviteEditor: View {
    @Environment(\.dismiss) private var dismiss
    let reader: any CoopFlowReading
    let contexts: [CoopFlowInvitationContext]
    @State private var message = ""
    @State private var fixed = false
    @State private var fee = ""
    @State private var discard = false
    @FocusState private var typing: Bool
    private var drafts: [CoopFlowInvitation]? {
        CoopFlowBatchInvite.drafts(contexts: contexts, message: message, defaultMessage: defaultMessage,
                                   fixed: fixed, fee: fee, currentSession: reader.session)
    }
    private var dirty: Bool { !message.isEmpty || fixed || !fee.isEmpty }
    private var isClub: Bool { contexts.first?.kind == .club }
    @Environment(\.locale) private var locale
    private var defaultMessage: String {
        appLocalized(isClub ? "cooperation.invite.defaultMessage.club" : "cooperation.invite.defaultMessage.merchant", locale: locale)
    }
    var body: some View {
        Form {
            Section {
                CYHeroHeader("coopflow.invite.title", subtitle: "context.coop.targets")
                    .listRowInsets(EdgeInsets(top: CYSpacing.md, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.sm, trailing: CYSpacing.pageHorizontal))
                    .listRowBackground(Color.clear)
            }
            Section("context.coop.targets") {
                ForEach(contexts) { context in
                    let name = context.recipientName.trimmingCharacters(in: .whitespacesAndNewlines)
                    Text(verbatim: name.isEmpty ? "—" : name)
                }
            }
            TextField("cooperation.invite.messagePlaceholder", text: $message, axis: .vertical).lineLimit(3...8).focused($typing)
                .onChange(of: message) { _, value in if value.count > 100 { message = String(value.prefix(100)) } }
            Text(verbatim: "\(message.count) / 100").cyText(.meta).monospacedDigit().foregroundStyle(CYColor.textTertiary)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Picker("cooperation.invite.terms", selection: $fixed) {
                Text("cooperation.invite.terms.traffic").tag(false)
                Text(LocalizedStringKey(isClub ? "cooperation.invite.fee.club" : "cooperation.invite.fee.merchant")).tag(true)
            }.pickerStyle(.inline).accessibilityIdentifier("cooperation.invite.terms")
            if fixed {
                LabeledContent {
                    HStack(spacing: 4) {
                        Text(verbatim: "¥")
                        TextField(text: $fee, prompt: Text(verbatim: "0.00")) { Text("coopflow.field.fixedFee") }.keyboardType(.decimalPad).focused($typing)
                        Text(LocalizedStringKey(isClub ? "cooperation.invite.feeUnit.club" : "cooperation.invite.feeUnit.merchant")).cyText(.meta).foregroundStyle(CYColor.textTertiary)
                    }
                } label: { Text("coopflow.field.fixedFee") }
                Text("coopflow.currency")
            }
            if let drafts {
                NavigationLink {
                    List {
                        Text("context.coop.individualReviews")
                        ForEach(Array(drafts.enumerated()), id: \.offset) { index, draft in
                            let name = contexts[index].recipientName.trimmingCharacters(in: .whitespacesAndNewlines)
                            NavigationLink { CoopFlowRequestPreview(operation: .invite(draft)) } label: {
                                Text(verbatim: name.isEmpty ? "—" : name)
                            }
                        }
                        CoopFlowSafetyNotice()
                    }.navigationTitle("coopflow.reviewAction").navigationBarTitleDisplayMode(.inline)
                } label: {
                    Text("coopflow.reviewAction").frame(maxWidth: .infinity)
                }
                .buttonStyle(CYPillButtonStyle())
                .listRowBackground(Color.clear)
            } else {
                CYListRow("coopflow.reviewAction", trailing: .value("—"))
            }
            CoopFlowSafetyNotice()
        }.cyMiniListScreen().navigationTitle("coopflow.invite.title").navigationBarTitleDisplayMode(.inline).scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("action.cancel") { if dirty { discard = true } else { dismiss() } } }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("action.done") { typing = false } }
            }
            .interactiveDismissDisabled(dirty)
            .sheet(isPresented: $discard) {
                MemberCoopInviteDiscardConfirmSheet {
                    discard = false
                    dismiss()
                }
                .cyDomainSheet(detents: [.half])
            }
            .onChange(of: reader.session) { _, _ in message = ""; fee = ""; fixed = false; dismiss() }
    }
}

/// Source invite target meta: "{n} 位成员 · {city}" / "成员数待确认", or merchant "{types|address|开放承接}".
struct CoopInviteTargetMeta: View {
    let candidate: CoopFlowTargetCandidate
    /// Page-model count. Nil on a club row is an em dash, not the older "members unknown" sentence.
    var memberCount: CoopInviteIndexReadiness.Count? = nil
    var body: some View {
        if candidate.kind == .club {
            let members: Text = {
                if let value = memberCount?.value { return Text("cooperation.invite.members \(value)") }
                return Text(verbatim: memberCount?.display ?? CoopInviteIndexReadiness.unknownDisplay)
            }()
            if let city = candidate.city { members + Text(verbatim: " · " + city) } else { members }
        } else if let meta = candidate.merchantMeta { Text(verbatim: meta) }
        else { Text("cooperation.invite.openToHost") }
    }
}

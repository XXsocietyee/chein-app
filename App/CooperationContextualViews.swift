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
    /// MP `topicsState/targetsState === 'permission'`: the failure was a refusal (当前身份不能…), not a load error.
    @Published private(set) var topicsRefused = false
    @Published private(set) var targetsRefused = false
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
    private(set) var presetOriginApplyID: Int?
    init(reader: any CoopFlowReading, operationScope: String?) { self.reader = reader; self.operationScope = operationScope; session = reader.session }
    /// Call before the first appear. `kind` follows MP `type` (0 merchant, 1 club).
    func applyRoutePreset(kind: CoopFlowTargetKind?, targetID: Int?, topicID: Int?, originApplyID: Int? = nil) {
        if let kind { self.kind = kind }
        presetTargetID = targetID.flatMap { $0 > 0 ? $0 : nil }
        presetTopicID = topicID.flatMap { $0 > 0 ? $0 : nil }
        presetOriginApplyID = originApplyID.flatMap { $0 > 0 ? $0 : nil }
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
        topicsReady = false; targetsReady = false; topicsFailed = false; targetsFailed = false; topicsRefused = false; targetsRefused = false; page = 1; failedPage = nil; hasMore = true
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
            CoopFlowInvitationContext(candidate: $0, topic: topic, scope: operationScope, session: session, originApplyID: presetOriginApplyID)
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
            topicsFailed = true; failedPage = requested; topicsRefused = refuses(error)
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
            targetsFailed = true; targetsRefused = refuses(error)
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
    @State private var requestCursor: String?
    @State private var requestsHaveMore = false
    @State private var loadingMoreRequests = false
    /// MC8-31-6: 查看已发出邀请 → 协作列表 · 我发出的 when the list pushed this page (MP `checkUnknownInvites`).
    @Environment(\.coopInviteSent) private var showSentInvites
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
                if requestsHaveMore {
                    Button { Task { await loadMoreRequests() } } label: {
                        HStack { Text("merchantCoop.invite.requests.more"); if loadingMoreRequests { Spacer(); ProgressView() } }
                            .frame(minHeight: CYSpacing.minTouchTarget)
                    }
                    .disabled(loadingMoreRequests)
                    .accessibilityIdentifier("cooperation.invite.requests.more")
                }
            }
            if let showSentInvites {
                Button { showSentInvites() } label: {
                    Text("merchantCoop.invite.viewSent").frame(minHeight: CYSpacing.minTouchTarget)
                }
                .accessibilityIdentifier("cooperation.invite.viewSent")
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
        requests = .loading; requestCursor = nil; requestsHaveMore = false
        do {
            let page = try await reader.read(.inviteRequests(before: nil, limit: 20))
            let rows = page["rows"].rows ?? []
            requestRows = rows
            acceptCursor(page, before: nil)
            requests = rows.isEmpty ? .empty : .ready
        } catch { requests = .failed }
    }
    /// MC8-31-6 (coop-invite-request.js:66-73): `nextCursor` pages older requests; an inconsistent cursor stops paging.
    private func acceptCursor(_ page: CoopFlowJSON, before: String?) {
        let next = page["nextCursor"].text ?? page["nextCursor"].integer.map(String.init)
        let more = page["hasMore"].flag == true
        if more, let next, CoopFlowRead.validInviteCursor(next), before.map({ next.count < $0.count || (next.count == $0.count && next < $0) }) ?? true {
            requestCursor = next; requestsHaveMore = true
        } else { requestCursor = nil; requestsHaveMore = false }
    }
    private func loadMoreRequests() async {
        guard reader.session != nil, requestsHaveMore, !loadingMoreRequests, let before = requestCursor else { return }
        loadingMoreRequests = true
        defer { loadingMoreRequests = false }
        do {
            let page = try await reader.read(.inviteRequests(before: before, limit: 20))
            let rows = page["rows"].rows ?? []
            requestRows += rows
            acceptCursor(page, before: before)
        } catch { requestsHaveMore = false; requests = .failed }
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
    /// MP `originApplyId` on the new-invitation page.
    var originApplyID: Int? = nil
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
                                      lockedTarget: lockedTarget, initialTopicID: initialTopicID, originApplyID: originApplyID)
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
    @Environment(\.cooperationTopicNearbyDestination) private var topicNearbyDestination
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.coopTopicPublishDestination) private var topicPublishDestination
    @Environment(\.locale) private var locale
    @State private var publishingTopic = false
    /// MP coop/invite wxml:51-66 ② 合作条款 lives on the page between ① and ③ (shareMode 0 / 2 + fee).
    @State private var fixedTerms = false
    @State private var fee = ""
    @FocusState private var feeFocused: Bool
    private var termsReady: Bool {
        !fixedTerms || Double(fee.trimmingCharacters(in: .whitespacesAndNewlines)).map { $0 > 0 } == true
    }
    private let lockedTargetPreset: CoopInviteLockedTarget?
    private let initialTopicID: Int?
    init(reader: any CoopFlowReading, operationScope: String?, initialType: Int? = nil,
         lockedTarget: CoopInviteLockedTarget? = nil, initialTopicID: Int? = nil, originApplyID: Int? = nil) {
        self.reader = reader; self.operationScope = operationScope
        self.lockedTargetPreset = lockedTarget; self.initialTopicID = initialTopicID
        let model = CoopInvitationReadModel(reader: reader, operationScope: operationScope)
        model.applyRoutePreset(kind: initialType.flatMap(CoopFlowTargetKind.init(rawValue:)),
                               targetID: lockedTarget?.toID, topicID: initialTopicID, originApplyID: originApplyID)
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
            // MP coop/invite wxml:13-27: send receipts and the unknown-result lookup sit above ① 关联主题.
            CoopInviteReceiptSections(reader: reader, kind: model.kind, topicID: model.topic?.id, merchantMemberIDs: model.candidates.filter { model.selected.contains($0.id) && $0.kind == .merchant }.map(\.recipient.id),
                                      showsRequests: sendOutcomeUnknown)
            Section("mpr3.coop.invite.topicTitle") {
                // MP wxml:31-34, 43: 正在刷新主题… while a loaded list re-reads; 主题加载失败 + 重试 on failure.
                if model.topicsBusy, !model.topics.isEmpty { Text("mpr3.coop.invite.topicsRefreshing").cyText(.meta).foregroundStyle(CYColor.textTertiary) }
                if model.topicsFailed {
                    CYInlineError(model.topicsRefused ? "mpr3.coop.invite.topicsForbidden" : "mpr3.coop.invite.topicsFailed", retryTitle: "action.retry") { Task { await model.retryTopics(permit) } }
                        .disabled(model.topicsBusy)
                }
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
                    Text("mpr3.coop.invite.chooseTopic").tag(Optional<Int>.none)
                    ForEach(model.isCurrent ? model.topics : []) { row in
                        Text(verbatim: [row.name, row.startDate, row.address].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")).tag(Optional(row.id))
                    }
                }.disabled(model.topicsBusy)
                }
                // Mini `.card-hint--warn`: topic not in its recruiting window.
                if model.topic != nil, model.topic?.inviteWindowOpen != true { Text("mpr3.coop.invite.closed").cyText(.meta).foregroundStyle(CYColor.warningText) }
                if model.lockedTopic == nil, model.hasMore, !model.topics.isEmpty { Button("context.picker.more") { Task { await model.more(permit) } }.disabled(model.topicsBusy || model.topicsFailed) }
            }
            // MP wxml:51-66: ② 合作条款 — 引流合作（不产生现金结算） or the per-kind fee, with ¥ amount + unit.
            Section("mpr3.coop.invite.termsTitle") {
                Picker("cooperation.invite.terms", selection: $fixedTerms) {
                    Text("cooperation.invite.terms.traffic").tag(false)
                    Text(LocalizedStringKey(model.kind == .club ? "cooperation.invite.fee.club" : "cooperation.invite.fee.merchant")).tag(true)
                }
                .pickerStyle(.inline)
                .labelsHidden()
                .accessibilityIdentifier("cooperation.invite.terms")
                if fixedTerms {
                    LabeledContent {
                        HStack(spacing: CYSpacing.xxs) {
                            Text(verbatim: LocaleDisplay.currencySymbol(locale: locale))
                            TextField(text: $fee, prompt: Text(verbatim: "0.00")) { Text("coopflow.field.fixedFee") }
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .focused($feeFocused)
                            Text(LocalizedStringKey(model.kind == .club ? "cooperation.invite.feeUnit.club" : "cooperation.invite.feeUnit.merchant"))
                                .cyText(.meta).foregroundStyle(CYColor.textTertiary)
                        }
                    } label: {
                        Text(LocalizedStringKey(model.kind == .club ? "cooperation.invite.fee.club" : "cooperation.invite.fee.merchant"))
                    }
                    .accessibilityIdentifier("cooperation.invite.fee")
                }
            }
            // MP order: ① 关联主题 → ② 合作条款 → ③ 邀请对象.
            Section {
              if let lockedTargetTitle {
                // MC8-31-4: 已选定，发送前不可更换.
                CoopInviteLockedRow(title: lockedTargetTitle, detail: "merchantCoop.invite.lockedTargetHint", identifier: "cooperation.invite.lockedTarget")
                if model.busy { CYSkeleton().accessibilityLabel(Text("cooperation.loading")) }
                if model.targetsFailed {
                    // MP wxml:79-81: 合作对象加载失败 + 重试.
                    CYInlineError(model.targetsRefused ? "mpr3.coop.invite.targetsForbidden" : "mpr3.coop.invite.targetsFailed", retryTitle: "action.retry") { Task { await model.retryTargets(permit) } }
                        .disabled(model.targetsBusy)
                }
                if !model.busy, !model.targetsFailed, model.lockedTarget == nil {
                    Text("merchantCoop.invite.lockedTargetMissing").cyText(.meta).foregroundStyle(CYColor.warningText)
                }
              } else {
                Picker("context.coop.kind", selection: Binding(get: { model.kind }, set: { value in
                    guard let next = model.changeKind(value, permit: permit) else { return }
                    editing = []; showEditor = false; search = ""; fixedTerms = false; fee = ""
                    Task { await model.loadInitial(next) }
                })) {
                    Text("coopflow.invite.club").tag(CoopFlowTargetKind.club)
                    Text("context.coop.merchant").tag(CoopFlowTargetKind.merchant)
                }
                .cyAdaptiveSegmented()
                .disabled(model.busy)
                TextField("context.coop.search", text: $search).accessibilityIdentifier("context.coop.search")
                if model.busy { CYSkeleton().accessibilityLabel(Text("cooperation.loading")) }
                if model.targetsFailed {
                    // MP wxml:79-81: 合作对象加载失败 + 重试.
                    CYInlineError(model.targetsRefused ? "mpr3.coop.invite.targetsForbidden" : "mpr3.coop.invite.targetsFailed", retryTitle: "action.retry") { Task { await model.retryTargets(permit) } }
                        .disabled(model.targetsBusy)
                }
                if !model.busy, !model.targetsFailed, filtered.isEmpty {
                    CYEmptyState(LocalizedStringKey(model.kind == .club ? "mpr3.coop.invite.noClubs" : "mpr3.coop.invite.noMerchants"))
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
                // MP wxml:132-134: 附近商家 · 含未入驻商家可电话联系 closes the targets card and keeps the chosen topic.
                if model.kind == .merchant {
                    if let topic = model.topic, let topicNearbyDestination {
                        NavigationLink { topicNearbyDestination(CoopNearbyTopicContext(topicID: topic.id, topicName: topic.name)) } label: { Text("cooperation.invite.nearby") }
                            .accessibilityIdentifier("cooperation.invite.nearby")
                    } else if nearbyDestination != nil {
                        NavigationLink { CoopFlowNearbyGate(reader: reader) } label: { Text("cooperation.invite.nearby") }
                            .accessibilityIdentifier("cooperation.invite.nearby")
                    }
                }
              }
            } header: {
                // MP wxml:72: ③ 邀请对象 with 已选 N.
                HStack {
                    Text("mpr3.coop.invite.targetsTitle")
                    Spacer()
                    if !model.selected.isEmpty { Text("mpr3.coop.invite.selectedCount \(model.selected.count)") }
                }
            }
            if model.topic == nil {
                // MP cta-bar hint 请先选择主题 (wxml:138).
                Text("mpr3.coop.invite.needTopic").cyText(.meta).foregroundStyle(CYColor.textTertiary)
                    .listRowBackground(Color.clear)
            }
            if !model.selected.isEmpty, model.isCurrent {
                // Mini `.cta-bar`: one solid action for the whole screen, 发送邀约(N).
                CYPillButton("mpr3.coop.invite.send \(model.selected.count)") {
                    guard let contexts = model.contexts(permit: permit) else { return }
                    editing = contexts; showEditor = true
                }
                .listRowBackground(Color.clear)
                .disabled(model.contexts(permit: permit) == nil || !termsReady)
            }
            CoopFlowSafetyNotice()
        }.cyMiniListScreen().navigationTitle("context.coop.new").navigationBarTitleDisplayMode(.inline).scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("action.done") { feeFocused = false } }
            }
            .onAppear {
                let value = model.appear(active: scenePhase == .active)
                Task { await model.loadInitial(value) }
            }
            .onChange(of: reader.session) { _, _ in
                model.identityChanged(); editing = []; showEditor = false; search = ""; fixedTerms = false; fee = ""
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
            .cySheet(isPresented: $showEditor) {
                NavigationStack { CoopFlowBatchInviteEditor(reader: reader, contexts: editing, fixed: fixedTerms, fee: fee, topicName: model.topic?.name) }
                    .environment(\.coopInviteOutcomeUnknown, { sendOutcomeUnknown = true })
                    // flows-g2 108: only a one-target send leaves the page; with several drafts the others stay sendable.
                    // MC8-31-7: a several-target batch ends on one summary, whose 完成 does the same (the editor sends each
                    // draft through its own reviewed preview and only calls this once every draft is sent).
                    .environment(\.coopInviteSent, inviteSent.map { sent in { showEditor = false; sent() } })
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
    /// ② 合作条款 chosen on the invite page (MP wxml:51-66); the sheet shows them read-only (拟议条款).
    var fixed: Bool = false
    var fee: String = ""
    /// MP `.iv-topic`: 关联主题 · {topicName}, or 整主题合作邀请 without a name.
    var topicName: String? = nil
    @State private var message = ""
    @State private var discard = false
    @FocusState private var typing: Bool
    /// MC8-31-7 (coop/invite index.js:952-959): with several recipients each draft keeps its own reviewed submit,
    /// and the page shows one result summary after the last one is sent, then ends on 我发出的.
    @Environment(\.coopInviteSent) private var finishSend
    @State private var presentedDraft: Int?
    @State private var sentDrafts: Set<Int> = []
    private var drafts: [CoopFlowInvitation]? {
        CoopFlowBatchInvite.drafts(contexts: contexts, message: message, defaultMessage: defaultMessage,
                                   fixed: fixed, fee: fee, currentSession: reader.session)
    }
    private var dirty: Bool { !message.isEmpty }
    private var topicLine: Text {
        let name = topicName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if name.isEmpty { return Text("mpr3.coop.invite.wholeTopic") }
        return Text("mpr3.coop.invite.topicLine \(name)")
    }
    private var isClub: Bool { contexts.first?.kind == .club }
    @Environment(\.locale) private var locale
    private var defaultMessage: String {
        appLocalized(isClub ? "cooperation.invite.defaultMessage.club" : "cooperation.invite.defaultMessage.merchant", locale: locale)
    }
    var body: some View {
        Form {
            // MP sheet `编辑邀约语` order: 邀请对象 · 已锁定 → 拟议条款 → 协作邀请 + 关联主题 → 收到的 hint → 邀请语 → send.
            Section("mpr3.coop.invite.lockedTargets") {
                ForEach(contexts) { context in
                    let name = context.recipientName.trimmingCharacters(in: .whitespacesAndNewlines)
                    LabeledContent {
                        CYStatusChip("mpr3.coop.invite.locked", tone: .neutral, systemImage: "lock.fill")
                    } label: {
                        Text(verbatim: name.isEmpty ? "—" : name)
                    }
                }
            }
            Section {
                // MP sheet `.iv-terms`: 拟议条款 · 对方接受并成单后锁定, value = the page's ② 合作条款.
                LabeledContent {
                    if fixed {
                        Text(verbatim: "\(LocaleDisplay.currencySymbol(locale: locale))\(fee) ") + Text(LocalizedStringKey(isClub ? "cooperation.invite.feeUnit.club" : "cooperation.invite.feeUnit.merchant"))
                    } else {
                        Text("cooperation.invite.terms.traffic")
                    }
                } label: {
                    Text("mpr3.coop.invite.proposedTerms")
                }
                .accessibilityIdentifier("cooperation.invite.proposedTerms")
            }
            Section {
                // MP `.iv-hero` + `.iv-copy`.
                VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                    Text("mpr3.coop.invite.heroType").cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary)
                    topicLine.cyText(.meta).foregroundStyle(CYColor.textSecondary)
                }
                .accessibilityElement(children: .combine)
                Text("mpr3.coop.invite.receivedHint").cyText(.meta).foregroundStyle(CYColor.textTertiary)
            }
            Section("mpr3.coop.invite.messageTitle") {
                TextField("cooperation.invite.messagePlaceholder", text: $message, axis: .vertical).lineLimit(3...8).focused($typing)
                    .onChange(of: message) { _, value in if value.count > 100 { message = String(value.prefix(100)) } }
                Text(verbatim: "\(message.count) / 100").cyText(.meta).monospacedDigit().foregroundStyle(CYColor.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            if let drafts {
                NavigationLink {
                    List {
                        if drafts.count > 1, sentDrafts.count == drafts.count {
                            Section {
                                Label("merchantCoop.invite.batchSent \(drafts.count)", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(CYColor.successText)
                                    .accessibilityIdentifier("cooperation.invite.batchSent")
                                Button("coopflow.submit.done") { if let finishSend { finishSend() } else { dismiss() } }
                                    .frame(minHeight: CYSpacing.minTouchTarget)
                                    .accessibilityIdentifier("cooperation.invite.batchDone")
                            }
                        }
                        Text("context.coop.individualReviews")
                        ForEach(Array(drafts.enumerated()), id: \.offset) { index, draft in
                            let name = contexts[index].recipientName.trimmingCharacters(in: .whitespacesAndNewlines)
                            if drafts.count == 1 {
                                NavigationLink { CoopFlowRequestPreview(operation: .invite(draft)) } label: {
                                    Text(verbatim: name.isEmpty ? "—" : name)
                                }
                            } else {
                                Button { presentedDraft = index } label: {
                                    HStack {
                                        Text(verbatim: name.isEmpty ? "—" : name).foregroundStyle(CYColor.textPrimary)
                                        Spacer()
                                        if sentDrafts.contains(index) {
                                            CYStatusChip("coopflow.submit.sent", tone: .neutral, systemImage: "checkmark")
                                        }
                                    }
                                    .frame(minHeight: CYSpacing.minTouchTarget)
                                }
                                .disabled(sentDrafts.contains(index))
                            }
                        }
                        CoopFlowSafetyNotice()
                    }.navigationTitle("coopflow.reviewAction").navigationBarTitleDisplayMode(.inline)
                    .navigationDestination(item: $presentedDraft) { index in
                        if index < drafts.count {
                            CoopFlowRequestPreview(operation: .invite(drafts[index]))
                                .environment(\.coopInviteSent, { sentDrafts.insert(index); presentedDraft = nil })
                        }
                    }
                } label: {
                    Text("coopflow.reviewAction").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .listRowBackground(Color.clear)
            } else {
                CYListRow("coopflow.reviewAction", trailing: .value("—"))
            }
            CoopFlowSafetyNotice()
        }.cyMiniListScreen().navigationTitle("mpr3.coop.invite.editorTitle").navigationBarTitleDisplayMode(.inline).scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("action.cancel") { if dirty { discard = true } else { dismiss() } } }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("action.done") { typing = false } }
            }
            .interactiveDismissDisabled(dirty)
            .cySheet(isPresented: $discard) {
                MemberCoopInviteDiscardConfirmSheet {
                    discard = false
                    dismiss()
                }
                .cyDomainSheet(detents: [.half])
            }
            .onChange(of: reader.session) { _, _ in message = ""; dismiss() }
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

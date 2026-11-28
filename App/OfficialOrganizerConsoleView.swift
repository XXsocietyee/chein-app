import SwiftUI

/// Official activity V2 organizer console (`pages/activity/official-organizer`): publish / pause / resume.
/// Not a top-level page: it is pushed from the official event detail and from 我发布的 rows. Permission
/// truth is the server's `publish-check`; every command is idempotent through a stored request id, and
/// only the server receipt (never a later state read) says whether it applied.
@MainActor final class OfficialOrganizerConsoleModel: ObservableObject {
    enum Phase: Equatable { case loading, denied(String?), error, ready }
    struct Intent: Codable, Equatable { var requestId: String; var action: String; var fields: [String: String] }
    enum Outcome: Equatable { case applied(OfficialOrganizerAction), rejected(String), cancelled, notConfirmed(OfficialOrganizerAction) }

    let eventID: Int
    private let access: any OfficialOrganizerAccess
    private let defaults: UserDefaults
    @Published var phase: Phase = .loading
    @Published var refreshing = false
    @Published var state: OfficialOrganizerEventState?
    @Published var check = OfficialOrganizerCheck(known: false, blockers: [], risks: [])
    @Published var pause: [String: OfficialOrganizerPauseEntry] = [:]
    @Published var resumeReason = ""
    @Published var formError: (OfficialOrganizerAction, OfficialOrganizerFormError)?
    @Published var intent: Intent?
    @Published var busy = false
    @Published var outcome: Outcome?
    @Published var unconfirmedMessage: String?
    /// True when the event-state read returned no event (page-ready empty phase).
    @Published var eventMissing = false
    private var loadSeq = 0

    init(eventID: Int, access: any OfficialOrganizerAccess, defaults: UserDefaults = .standard) {
        self.eventID = eventID; self.access = access; self.defaults = defaults
        for f in OfficialOrganizerRules.pauseFields { pause[f] = OfficialOrganizerPauseEntry() }
        intent = loadIntent()
    }
    var availability: [OfficialOrganizerAction: OfficialOrganizerAvailability] { OfficialOrganizerRules.availability(state) }
    /// pages/activity/official-organizer/index projection. Unknown facts are an em dash; a server 0 stays "0".
    var snapshot: OfficialOrganizerConsoleSnapshot {
        let load: OfficialOrganizerConsoleLoad
        switch phase {
        case .loading: load = .loading
        case .error: load = .failed
        case .denied: load = .denied
        case .ready: load = .allowed(check, eventMissing ? nil : state)
        }
        return OfficialOrganizerConsoleSnapshot.resolve(enabled: true, load: load)
    }
    var hasPendingIntent: Bool { intent != nil }
    var controlsLocked: Bool { busy || intent != nil || refreshing }

    private var key: String { "cy-official-organizer-v1:\(access.accountID ?? 0):\(eventID)" }
    private func loadIntent() -> Intent? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(Intent.self, from: $0) }
    }
    private func saveIntent(_ value: Intent?) {
        intent = value
        if let value, let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
        else { defaults.removeObject(forKey: key) }
    }

    func load() async {
        loadSeq += 1; let seq = loadSeq
        let hadSnapshot = phase == .ready
        if hadSnapshot { refreshing = true } else { phase = .loading }
        defer { if seq == loadSeq { refreshing = false } }
        do {
            switch try await access.publishCheck(eventID: eventID) {
            case .denied(let message):
                guard seq == loadSeq else { return }
                state = nil; phase = .denied(message); return
            case .allowed(let result):
                guard seq == loadSeq else { return }
                check = result
            }
            let s = try await access.eventState(eventID: eventID)
            guard seq == loadSeq else { return }
            eventMissing = s == nil
            state = s ?? OfficialOrganizerEventState(status: nil, control: nil)
            phase = .ready
        } catch is CancellationError {
        } catch {
            guard seq == loadSeq else { return }
            if !hadSnapshot { phase = .error }
        }
    }

    func validate(_ action: OfficialOrganizerAction) -> Bool {
        let error: OfficialOrganizerFormError?
        switch action {
        case .pause: error = OfficialOrganizerRules.validatePause(pause)
        case .resume: error = OfficialOrganizerRules.validateResume(reason: resumeReason)
        case .schedule: error = nil
        }
        formError = error.map { (action, $0) }
        return error == nil
    }
    func canStart(_ action: OfficialOrganizerAction) -> Bool {
        guard phase == .ready, !controlsLocked, availability[action]?.enabled == true else { return false }
        return action != .schedule || check.pass
    }

    /// Persists the exact intent before the first dispatch so a lost reply is queried, never re-created.
    func start(_ action: OfficialOrganizerAction) async {
        guard canStart(action), validate(action) else { return }
        outcome = nil; unconfirmedMessage = nil
        let fields = OfficialOrganizerRules.payload(action, pause: pause, resumeReason: resumeReason)
        saveIntent(Intent(requestId: OfficialOrganizerCommand.newRequestID(), action: action.rawValue, fields: fields))
        await send(.submit)
    }
    func send(_ mode: OfficialOrganizerCommandMode) async {
        guard let intent, let action = OfficialOrganizerAction(rawValue: intent.action), !busy else { return }
        busy = true; defer { busy = false }
        let command = OfficialOrganizerCommand(eventID: eventID, action: action, requestId: intent.requestId, fields: intent.fields)
        let receipt = try? await access.command(command, mode: mode)
        guard let receipt else {
            unconfirmedMessage = "unknown"   // outcome unknown: keep the intent, never claim success or rollback
            return
        }
        unconfirmedMessage = nil
        switch receipt.state {
        case .applied:
            outcome = .applied(action)
            saveIntent(nil)
            clearForm(action)
            await load()
            if let state, !OfficialOrganizerRules.readBackMatches(action, state) { outcome = .notConfirmed(action) }
        case .rejected: outcome = .rejected(receipt.message); saveIntent(nil)
        case .cancelled: outcome = .cancelled; saveIntent(nil)
        }
    }
    private func clearForm(_ action: OfficialOrganizerAction) {
        switch action {
        case .pause: for f in OfficialOrganizerRules.pauseFields { pause[f] = OfficialOrganizerPauseEntry() }
        case .resume: resumeReason = ""
        case .schedule: break
        }
    }
}

struct OfficialOrganizerConsoleView: View {
    @StateObject private var model: OfficialOrganizerConsoleModel
    @Environment(\.locale) private var locale
    @State private var confirming: OfficialOrganizerAction?
    private var c: CoreLoopCopy { CoreLoopCopy(locale: locale) }
    @Environment(\.dismiss) private var dismissConsole
    /// MP `cy-field maxlength="200" show-count` on every organizer text field (R7-PC-C7-1).
    private static let fieldLimit = 200

    init(eventID: Int, access: any OfficialOrganizerAccess) {
        _model = StateObject(wrappedValue: OfficialOrganizerConsoleModel(eventID: eventID, access: access))
    }

    var body: some View {
        Group {
            switch model.phase {
            case .loading:
                // MP cy-state-shell kind="loading" title="正在确认主办身份": say what is loading.
                ProgressView { Text("activityR3.official.organizer.loading") }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("official.organizer.loading")
            case .denied(let reason):
                // R7-PC-C7-2 (MP official-organizer/index.wxml:26 primary="返回").
                ContentUnavailableView {
                    Label { Text("activityR3.official.organizer.deniedTitle") } icon: { Image(systemName: "lock") }
                } description: {
                    if let reason { Text(verbatim: c.tr(reason)) } else { Text("activityR3.official.organizer.deniedDefault") }
                } actions: {
                    Button { dismissConsole() } label: { Text("action.back") }
                        .buttonStyle(.bordered)
                }
                    .accessibilityIdentifier("official.organizer.denied")
            case .error:
                ContentUnavailableView {
                    Label { Text("activityR3.official.organizer.errorTitle") } icon: { Image(systemName: "exclamationmark.triangle") }
                } description: {
                    Text("activityR3.official.organizer.errorDetail")
                } actions: {
                    Button { Task { await model.load() } } label: { Text(verbatim: c.t("重试", "Retry")) }
                        .buttonStyle(.bordered)
                }
                    .accessibilityIdentifier("official.organizer.error")
            case .ready: content
            }
        }
        .navigationTitle(Text("official.organizer.title"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
        .refreshable { await model.load() }
        .confirmationDialog(confirming.map { confirmTitle(for: $0) } ?? "",
                            isPresented: Binding(get: { confirming != nil }, set: { if !$0 { confirming = nil } }),
                            titleVisibility: .visible, presenting: confirming) { action in
            Button(role: action == .schedule || action == .pause ? .destructive : nil) {
                confirming = nil
                Task { await model.start(action) }
            } label: { Text(verbatim: confirmButton(action)) }
            Button(role: .cancel) { confirming = nil } label: { Text(verbatim: appLocalized("action.cancel", locale: locale)) }
        } message: { action in
            Text(verbatim: ([confirmMessage(action)] + confirmConsequences(for: action).map(\.text)).joined(separator: "\n"))
        }
    }

    private var content: some View {
        List {
            // MP order: the command-recovery card sits at the top of the page, above the head card.
            if model.hasPendingIntent { recoverySection }
            // PC-C-7-3: say why controls are locked while the platform record is re-read (MP oo-sync line).
            if model.refreshing {
                Label("official.organizer.refreshing", systemImage: "arrow.triangle.2.circlepath")
                    .font(.footnote).foregroundStyle(.secondary)
                    .accessibilityIdentifier("official.organizer.refreshing")
            }
            headerSection
            snapshotSection
            if let o = model.outcome { outcomeSection(o) }
            publishSection
            // PC-C-7-2: only the form that applies (MP wx:if view.paused): paused → resume, running → pause.
            if model.state?.control == .paused { resumeSection } else { pauseSection }
            OfficialAttendanceSectionView(eventID: model.eventID, activityID: 0, organizer: true)
        }
        .accessibilityIdentifier("official.organizer.content")
    }

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                // MP oo-head: title with the control badge on one row (stacked when it doesn't fit), then 生命周期.
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        headerTitle
                        Spacer(minLength: 8)
                        controlBadge
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        headerTitle
                        controlBadge
                    }
                }
                (Text("activityR3.official.organizer.lifecycle")
                    + Text(LocalizedStringKey(OfficialPublishedPresentation.ownerStatusKey(model.state?.status))))
                    .font(.subheadline).foregroundStyle(.secondary)
                // R7-PC-C7-2 (MP index.wxml:38-39): 暂停原因 while paused; 最近恢复说明 while running.
                if model.state?.control == .paused {
                    if let r = model.state?.pausedReason, !r.isEmpty {
                        Text(verbatim: c.t("暂停原因：", "Pause reason: ") + r).font(.footnote)
                    }
                } else if let n = model.state?.resumeNote, !n.isEmpty {
                    Text(verbatim: c.t("最近恢复说明：", "Latest resume note: ") + n).font(.footnote)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("official.organizer.header")
        }
    }
    private var headerTitle: some View {
        Text(verbatim: model.state?.title.isEmpty == false ? model.state!.title : c.t("未命名官方活动", "Untitled official event"))
            .font(.headline)
            .fixedSize(horizontal: false, vertical: true)
    }
    /// MP cy-badge: warning tone while paused, neutral otherwise.
    private var controlBadge: some View {
        Text(verbatim: controlText)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(model.state?.control == .paused ? Color.orange : Color.secondary)
    }
    /// Page-model empty / unknown notice. R3: the blocker/risk count line is gone (the MP lists them in 发布活动).
    @ViewBuilder private var snapshotSection: some View {
        let snapshot = model.snapshot
        if snapshot.state == .empty {
            Section {
                Label("official.organizer.emptyNotice", systemImage: "tray")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(snapshot.accessibilityIdentifier ?? "")
            }
        } else if snapshot.state == .unknown {
            Section {
                Label("official.organizer.unknownNotice", systemImage: "questionmark.circle")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(snapshot.accessibilityIdentifier ?? "")
            }
        }
    }
    private var controlText: String {
        switch model.state?.control {
        case .normal: return c.t("正常运行", "Running normally")
        case .paused: return c.t("已暂停", "Paused")
        case nil: return "—"
        }
    }

    @ViewBuilder private func outcomeSection(_ outcome: OfficialOrganizerConsoleModel.Outcome) -> some View {
        Section {
            switch outcome {
            case .applied(let a):
                Label(appliedText(a), systemImage: "checkmark.circle.fill").foregroundStyle(CYColor.successText)
            case .notConfirmed(let a):
                Label(c.t("平台已受理「\(actionName(a))」，但回读状态还没更新，请下拉刷新确认。",
                          "The platform accepted “\(actionName(a))”, but the refreshed state doesn't show it yet. Pull to refresh."),
                      systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            case .rejected(let message):
                Label(message.isEmpty ? c.t("平台拒绝了这次操作", "The platform rejected this action") : c.tr(message),
                      systemImage: "xmark.octagon.fill").foregroundStyle(.red)
            case .cancelled:
                Label(c.t("原请求已取消", "The original request was cancelled"), systemImage: "minus.circle")
            }
            Button(c.t("知道了", "Dismiss")) { model.outcome = nil }.frame(minHeight: 44)
        }
        .accessibilityIdentifier("official.organizer.result")
    }

    private var recoverySection: some View {
        Section {
            Text(c.t("原请求的结果还没确认。你填写的内容已保留，请先查询结果，不要重复提交。",
                     "The result of your earlier request isn't confirmed. Your input is kept; check the result first instead of submitting again."))
                .font(.subheadline)
            if model.unconfirmedMessage != nil {
                Text(c.t("暂时无法确认，请稍后再查询", "Can't confirm right now. Check again shortly.")).font(.subheadline).foregroundStyle(.secondary)
            }
            Button(c.t("查询结果", "Check result")) { Task { await model.send(.query) } }.frame(minHeight: 44)
            Button(c.t("按原请求重试", "Retry the original request")) { Task { await model.send(.submit) } }.frame(minHeight: 44)
            Button(c.t("取消原请求", "Cancel the original request"), role: .destructive) { Task { await model.send(.cancel) } }.frame(minHeight: 44)
        } header: { Text(c.t("待确认的操作", "Unconfirmed action")) }
        .disabled(model.busy)
        .accessibilityIdentifier("official.organizer.recovery")
    }

    private var publishSection: some View {
        Section {
            // MP oo-card: intro, then the check result (passed, or 未通过 + blockers), then 风险 lines.
            Text("activityR3.official.organizer.publishIntro").font(.subheadline).foregroundStyle(.secondary)
            if !model.check.known {
                Label("activityR3.official.organizer.checkUnknown", systemImage: "questionmark.circle")
                    .foregroundStyle(.secondary)
            } else if model.check.pass {
                Label(c.t("发布检查已通过", "Publish check passed"), systemImage: "checkmark.seal").foregroundStyle(.green)
            } else {
                Text("activityR3.official.organizer.checkFailed").font(.subheadline)
            }
            ForEach(Array(model.check.blockers.enumerated()), id: \.offset) { _, text in
                Label(text, systemImage: "xmark.circle").foregroundStyle(.red)
            }
            ForEach(Array(model.check.risks.enumerated()), id: \.offset) { _, text in
                Label { Text("activityR3.official.organizer.risk \(text)") } icon: { Image(systemName: "exclamationmark.triangle") }
                    .foregroundStyle(.orange)
            }
            hintText(.schedule)
            actionButton(.schedule)
        } header: { Text(c.t("发布活动", "Publish event")) }
    }

    private var pauseSection: some View {
        Section {
            ForEach(OfficialOrganizerRules.pauseFields, id: \.self) { field in pauseField(field) }
            formErrorText(.pause)
            hintText(.pause)
            actionButton(.pause)
        } header: { Text("activityR3.official.organizer.pauseResumeHeader") }
    }
    private var resumeSection: some View {
        Section {
            TextField(c.t("风险处理说明（必填）", "How the risk was handled (required)"),
                      text: Binding(get: { model.resumeReason }, set: { model.resumeReason = String($0.prefix(Self.fieldLimit)) }), axis: .vertical)
                .lineLimit(2...5).disabled(model.controlsLocked)
                .accessibilityLabel(c.t("风险处理说明", "Risk handling note"))
                .accessibilityIdentifier("official.organizer.resume.reason")
            counter(model.resumeReason)
            formErrorText(.resume)
            hintText(.resume)
            actionButton(.resume)
        } header: { Text("activityR3.official.organizer.pauseResumeHeader") }
    }

    private func pauseField(_ field: String) -> some View {
        let presets = OfficialOrganizerRules.pausePresets[field] ?? []
        let binding = Binding(get: { model.pause[field] ?? OfficialOrganizerPauseEntry() }, set: { model.pause[field] = $0 })
        return VStack(alignment: .leading, spacing: 6) {
            // R7-PC-C7-1 (MP index.wxml:71 `oo-chips`, one tap picks a preset, a second clears it): the Apple control is a
            // menu Picker whose "—" row clears the preset.
            Picker(selection: Binding(get: { binding.wrappedValue.preset }, set: { binding.wrappedValue.preset = $0 })) {
                Text(verbatim: "—").tag("")
                ForEach(Array(presets.enumerated()), id: \.offset) { i, zh in
                    Text(verbatim: presetLabel(field, i, zh)).tag(zh)
                }
            } label: {
                Text(verbatim: fieldLabel(field))
            }
            .pickerStyle(.menu)
            TextField(c.t("补充说明（没有合适选项时必填）", "Add details (required if no preset fits)"),
                      text: Binding(get: { binding.wrappedValue.extra }, set: { binding.wrappedValue.extra = String($0.prefix(Self.fieldLimit)) }),
                      axis: .vertical)
                .lineLimit(1...4)
                .accessibilityLabel(fieldLabel(field))
            counter(binding.wrappedValue.extra)
        }
        .disabled(model.controlsLocked)
        .accessibilityIdentifier("official.organizer.pause.\(field)")
    }

    /// MP `show-count`: n/200 under the field.
    private func counter(_ text: String) -> some View {
        Text(verbatim: "\(text.count)/\(Self.fieldLimit)")
            .font(.caption).monospacedDigit().foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .accessibilityLabel(Text("official.organizer.counter \(text.count) \(Self.fieldLimit)"))
    }
    private func actionButton(_ action: OfficialOrganizerAction) -> some View {
        Button {
            if model.canStart(action), model.validate(action) { confirming = action }
        } label: {
            HStack { if model.busy { ProgressView() }; Text(actionName(action)).frame(maxWidth: .infinity) }
        }
        .modifier(OfficialOrganizerActionButtonStyle(prominent: action == .schedule))
        .disabled(!model.canStart(action))
        .accessibilityIdentifier("official.organizer.\(action.rawValue)")
    }
    @ViewBuilder private func hintText(_ action: OfficialOrganizerAction) -> some View {
        if let hint = model.availability[action]?.hint {
            Text(hintCopy(hint)).font(.footnote).foregroundStyle(.secondary)
        }
    }
    @ViewBuilder private func formErrorText(_ action: OfficialOrganizerAction) -> some View {
        if let (a, e) = model.formError, a == action {
            // MP cy-inline-error title="还不能提交" + the rule that failed.
            VStack(alignment: .leading, spacing: 2) {
                Text("activityR3.official.organizer.formErrorTitle").font(.footnote.weight(.semibold))
                Text(formErrorCopy(e)).font(.footnote)
            }
            .foregroundStyle(.red)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("official.organizer.formError")
        }
    }

    // MARK: copy
    private func actionName(_ a: OfficialOrganizerAction) -> String {
        switch a {
        case .schedule: return c.t("发布活动", "Publish event")
        case .pause: return c.t("暂停活动", "Pause event")
        case .resume: return c.t("恢复活动", "Resume event")
        }
    }
    private func appliedText(_ a: OfficialOrganizerAction) -> String {
        switch a {
        case .schedule: return c.t("活动已发布", "Event published")
        case .pause: return c.t("活动已暂停", "Event paused")
        case .resume: return c.t("活动已恢复", "Event resumed")
        }
    }
    private func confirmTitle(for action: OfficialOrganizerAction) -> String {
        let name = model.state?.title.isEmpty == false ? model.state!.title : c.t("这场活动", "this event")
        switch action {
        case .schedule: return c.t("发布「\(name)」?", "Publish “\(name)”?")
        case .pause: return c.t("暂停「\(name)」?", "Pause “\(name)”?")
        case .resume: return c.t("恢复「\(name)」?", "Resume “\(name)”?")
        }
    }
    private func confirmConsequences(for action: OfficialOrganizerAction) -> [CYConfirmConsequence] {
        switch action {
        case .schedule:
            return [
                CYConfirmConsequence(systemImage: "calendar.badge.clock", text: appLocalized("official.organizer.schedule.c1", locale: locale)),
                CYConfirmConsequence(systemImage: "arrow.uturn.backward.circle", text: appLocalized("official.organizer.schedule.c2", locale: locale)),
                CYConfirmConsequence(systemImage: "exclamationmark.triangle", text: appLocalized("official.organizer.schedule.c3", locale: locale))
            ]
        case .pause:
            return [
                CYConfirmConsequence(systemImage: "person.crop.circle.badge.xmark", text: appLocalized("official.organizer.pause.c1", locale: locale)),
                CYConfirmConsequence(systemImage: "megaphone", text: appLocalized("official.organizer.pause.c2", locale: locale)),
                CYConfirmConsequence(systemImage: "clock", text: appLocalized("official.organizer.pause.c3", locale: locale))
            ]
        case .resume:
            return [
                CYConfirmConsequence(systemImage: "checkmark.shield", text: appLocalized("official.organizer.resume.c1", locale: locale)),
                CYConfirmConsequence(systemImage: "hourglass", text: appLocalized("official.organizer.resume.c2", locale: locale))
            ]
        }
    }
    private func confirmButton(_ a: OfficialOrganizerAction) -> String { actionName(a) }
    private func confirmMessage(_ a: OfficialOrganizerAction) -> String {
        switch a {
        case .schedule: return c.t("通过发布检查后对报名可见，按设定的报名与开始时间自动推进。此操作不可撤销，发布后无法退回草稿。",
                                   "After the publish check it becomes visible for registration and advances automatically on its set times. This can't be undone: it can't go back to draft.")
        case .pause: return c.t("暂停期间不能报名，到达证据不计入；填写的通知策略不会自动群发，需要另行通知。原定结束时间不变。",
                                "While paused, registration and arrival evidence are blocked. The notification plan is not sent automatically; notify players yourself. The end time doesn't change.")
        case .resume: return c.t("平台会先重新做发布检查，不通过会拒绝恢复并给出原因。如果活动已过结束时间，会转入待结算。",
                                 "The platform re-runs the publish check first and refuses to resume with a reason if it fails. If the end time has passed, the event moves to settlement.")
        }
    }
    private func hintCopy(_ h: OfficialOrganizerHint) -> String {
        switch h {
        case .stateUnknown: return c.t("活动状态没读到，刷新后再操作", "The event status wasn't loaded. Refresh, then try again.")
        case .alreadyPublished: return c.t("活动已发布，只有草稿需要发布", "Already published; only drafts need publishing.")
        case .alreadyPaused: return c.t("活动已暂停", "The event is already paused.")
        case .notPaused: return c.t("活动未暂停", "The event isn't paused.")
        case .publishFirst: return c.t("活动发布后才能暂停", "Publish the event before pausing it.")
        case .ended: return c.t("活动已进入结算或已结束，不能再调整", "The event is settling or ended and can't be changed.")
        case .controlUnknown: return c.t("控制状态待确认，已停用暂停/恢复", "Control state isn't confirmed; pause/resume are off.")
        }
    }
    private func formErrorCopy(_ e: OfficialOrganizerFormError) -> String {
        switch e {
        case .pauseIncomplete: return c.t("暂停的原因、影响范围、替代方案和通知策略都要选一项或写几句", "Choose an option or write a few words for the reason, scope, alternative plan and notification plan.")
        case .pauseTooLong: return c.t("每项最多 \(OfficialOrganizerRules.planLimit) 字", "Each item can be at most \(OfficialOrganizerRules.planLimit) characters.")
        case .resumeMissing: return c.t("恢复必须填写风险处理说明", "Describe how the risk was handled before resuming.")
        case .resumeTooLong: return c.t("风险处理说明最多 \(OfficialOrganizerRules.reasonLimit) 字", "The note can be at most \(OfficialOrganizerRules.reasonLimit) characters.")
        case .unknownAction: return c.t("未知操作", "Unknown action")
        }
    }
    private func fieldLabel(_ f: String) -> String {
        switch f {
        case "reason": return c.t("暂停原因", "Pause reason")
        case "impactScope": return c.t("影响范围", "Impact scope")
        case "alternativePlan": return c.t("替代方案", "Alternative plan")
        default: return c.t("通知策略", "Notification plan")
        }
    }
    private func presetLabel(_ field: String, _ index: Int, _ zh: String) -> String {
        guard !c.isChinese else { return zh }
        let en: [String: [String]] = [
            "reason": ["Weather or safety", "Venue or partner merchant unavailable", "Event content or tasks need fixing"],
            "impactScope": ["All registered players", "Some nodes or tasks", "Players who haven't registered"],
            "alternativePlan": ["Continue as planned after resuming", "Rescheduled; time to be announced", "No alternative; closed until resumed"],
            "notificationPlan": ["In-app notice to all registered players", "Host will post an announcement", "Minor impact; no separate notice"],
        ]
        return en[field]?[index] ?? zh
    }
}

/// Entry row shown only when the server's `publish-check` lets this account manage the event
/// (the mini-program shows the organizer entry in detail and 我发布的 only then).
struct OfficialOrganizerEntryRow: View {
    let eventID: Int
    let access: (any OfficialOrganizerAccess)?
    /// MP official-detail: the entry is its own 主办控制台 section with an explanation and an 打开主办控制台 action.
    var detailSection = false
    @State private var allowed = false
    @Environment(\.locale) private var locale
    var body: some View {
        Group {
            if allowed, let access, detailSection {
                Section {
                    Text("activityR3.official.detail.organizerEntry.copy")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    NavigationLink {
                        OfficialOrganizerConsoleView(eventID: eventID, access: access)
                    } label: {
                        Label("activityR3.official.detail.organizerEntry.open", systemImage: "slider.horizontal.3")
                            .frame(minHeight: 44)
                    }
                    .accessibilityIdentifier("official.organizer.entry.\(eventID)")
                } header: {
                    Text("official.organizer.title")
                }
            } else if allowed, let access {
                NavigationLink {
                    OfficialOrganizerConsoleView(eventID: eventID, access: access)
                } label: {
                    Label(CoreLoopCopy(locale: locale).t("主办控制台", "Organizer console"), systemImage: "slider.horizontal.3")
                        .frame(minHeight: 44)
                }
                .accessibilityIdentifier("official.organizer.entry.\(eventID)")
            }
        }
        .task(id: eventID) {
            guard let access, access.enabled else { allowed = false; return }
            if case .allowed? = try? await access.publishCheck(eventID: eventID) { allowed = true } else { allowed = false }
        }
    }
}

/// Source `goRoam` jump (`pages/activity/official-detail/index.js`) for `.roamArrival` / `.roamLight` CTAs.
@MainActor struct OfficialDetailRoamJumpSection: View {
    let event: OfficialEvent
    let cta: OfficialDetailCTA
    var onOpenRoam: ((Int, String?) -> Void)? = nil
    @Environment(\.rootTabSwitch) private var rootTabSwitch

    private var canJumpToRoam: Bool {
        (cta == .roamArrival || cta == .roamLight) && (onOpenRoam != nil || rootTabSwitch.isAvailable)
    }

    var body: some View {
        if canJumpToRoam {
            Section {
                Button {
                    if let onOpenRoam {
                        onOpenRoam(event.id, nil)
                    } else if rootTabSwitch.isAvailable {
                        // ROAM-r11-1: carry the event into the live roam (MP goRoam `?eventId=&missionCode=`).
                        RoamOfficialEventHandoff.shared.hand(eventID: event.id, missionCode: nil)
                        rootTabSwitch(.roam)
                    }
                } label: {
                    Label {
                        Text(LocalizedStringKey(cta.key))
                    } icon: {
                        Image(systemName: "map.fill")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("official.detail.cta.roam")
            }
        }
    }
}

/// Source `onTapMission` Roam jump (`pages/activity/official-detail/index.js`) for signed-in `.verify` missions.
@MainActor struct OfficialMissionRoamJumpButton: View {
    let event: OfficialEvent
    let missionIndex: Int
    let action: OfficialDetailMissionAction
    var onOpenRoam: ((Int, String?) -> Void)? = nil
    @Environment(\.rootTabSwitch) private var rootTabSwitch
    @Environment(\.locale) private var locale

    private var canVerifyInRoam: Bool {
        event.signed == true && !event.paused && action == .verify && (onOpenRoam != nil || rootTabSwitch.isAvailable)
    }

    var body: some View {
        if canVerifyInRoam {
            Button {
                let code = event.missions.indices.contains(missionIndex) ? event.missions[missionIndex].code : nil
                if let onOpenRoam {
                    onOpenRoam(event.id, code)
                } else if rootTabSwitch.isAvailable {
                    // ROAM-r11-1: carry the event and mission into the live roam (MP goRoam).
                    RoamOfficialEventHandoff.shared.hand(eventID: event.id, missionCode: code)
                    rootTabSwitch(.roam)
                }
            } label: {
                Label(
                    CoreLoopCopy(locale: locale).t("去漫游完成", "Verify in Roam"),
                    systemImage: "location.magnifyingglass"
                )
                .font(.body.weight(.medium))
                .frame(minHeight: 44)
            }
            .accessibilityIdentifier("official.mission.roam.\(missionIndex)")
        }
    }
}


/// 发布活动 is the one prominent button; pause / resume are bordered.
private struct OfficialOrganizerActionButtonStyle: ViewModifier {
    let prominent: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if prominent { content.buttonStyle(.borderedProminent).controlSize(.large) }
        else { content.buttonStyle(.bordered).controlSize(.large) }
    }
}

extension OfficialOrganizerAction: @retroactive Identifiable {
    public var id: String { rawValue }
}

import SwiftUI
import UIKit

/// WP-02 play/creator tail: leader chapter release with its receipt and the station release (pages/play),
/// the original-run guard appeal (pages/play guard-appeal.js), the author's audit record and appeal
/// (subpackageA/pages/myproject) and the share-edition empty reason (pages/club/detail).
private let tailTable = "PlayCreatorTail"
private func tailText(_ key: String) -> String { String(localized: String.LocalizationValue(key), table: tailTable) }

// MARK: - leader chapter + station release (pages/play)

/// `leadUnlock` and `leadReleaseStation`. Shown to the leader of a started team; the leader capability decides
/// whether the buttons are enabled. An unknown chapter outcome turns the button into a receipt read.
@MainActor struct PlayLeadChapterTools: View {
    @Bindable var model: PlayExperienceCoordinator
    let lead: PlayLeadProgress
    let context: PlayInteractionContext?
    @State private var confirmUnlock = false
    @State private var releasing: PlayLeadProgress.SkipRequest?

    var body: some View {
        let pending = model.pendingUnlock
        Group {
            if pending?.receiptOnly == true {
                CYPillButton("lead.unlock.check", style: .secondary, systemImage: "arrow.clockwise", tableName: tailTable) {
                    Task { await model.unlockChapter(context: context) }
                }
                .disabled(model.leadToolBusy)
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("playx.lead.unlock.check")
            } else {
                CYPillButton("lead.unlock", style: .secondary, systemImage: "lock.open", tableName: tailTable) {
                    if pending != nil { Task { await model.unlockChapter(context: context) } } else { confirmUnlock = true }
                }
                .disabled(model.leadToolBusy || model.phase == .submitting || !lead.allArrived)
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("playx.lead.unlock-chapter")
            }
            if let notice = model.leadNotice { noticeRow(notice) }
            if !lead.skipRequests.isEmpty {
                Text("lead.release.title", tableName: tailTable).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                ForEach(lead.skipRequests) { request in
                    Button { releasing = request } label: {
                        CYListRow(verbatim: releaseLabel(request), trailing: .chevron) { CYRowIcon(systemImage: "figure.walk.departure") }
                    }
                    .disabled(model.leadToolBusy)
                    .accessibilityIdentifier("playx.lead.release.\(request.memberID).\(request.nodeID)")
                }
            }
        }
        .sheet(isPresented: $confirmUnlock) {
            CYConfirmSheet(title: tailText("lead.unlock.confirm.title"), message: tailText("lead.unlock.confirm.body"),
                           confirmTitle: tailText("lead.unlock.confirm.action"), confirmIdentifier: "playx.lead.unlock.confirm") {
                Task { await model.unlockChapter(context: context) }
            }
            .cySheet(detents: [.medium])
        }
        .sheet(item: $releasing) { request in
            CYConfirmSheet(title: tailText("lead.release.confirm.title"),
                           message: String(format: tailText("lead.release.confirm.body"), memberName(request), stationName(request)),
                           confirmTitle: tailText("lead.release.confirm.action"), confirmIdentifier: "playx.lead.release.confirm") {
                Task { await model.releaseStation(request, context: context) }
            }
            .cySheet(detents: [.medium])
        }
    }

    @ViewBuilder private func noticeRow(_ notice: PlayExperienceCoordinator.LeadNotice) -> some View {
        switch notice {
        case .server(let message):
            if let message, !message.isEmpty { Text(verbatim: message) } else { Text("lead.notice.retryLater", tableName: tailTable) }
        case .unlockApplied: Text("lead.notice.unlockApplied", tableName: tailTable)
        case .unlockPending: Text("lead.notice.unlockPending", tableName: tailTable).accessibilityIdentifier("playx.lead.unlock.pending")
        case .noNextChapter: Text("lead.notice.noNextChapter", tableName: tailTable)
        case .released: Text("lead.notice.released", tableName: tailTable)
        case .releaseNotSent: Text("lead.notice.releaseNotSent", tableName: tailTable)
        case .unlockNotExecuted:
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                Text("lead.notice.unlockNotExecuted", tableName: tailTable).fixedSize(horizontal: false, vertical: true)
                CYPillButton("lead.unlock.endIntent", style: .tertiary, tableName: tailTable) { model.endUnlockIntent() }
                    .accessibilityIdentifier("playx.lead.unlock.endIntent")
            }
        }
    }

    private func memberName(_ request: PlayLeadProgress.SkipRequest) -> String { request.nickname ?? tailText("lead.release.member") }
    private func stationName(_ request: PlayLeadProgress.SkipRequest) -> String {
        model.snapshot?.visibleNodes.first { $0.id == request.nodeID }?.name.flatMap { $0.isEmpty ? nil : $0 } ?? tailText("lead.release.station")
    }
    private func releaseLabel(_ request: PlayLeadProgress.SkipRequest) -> String {
        String(format: tailText("lead.release.row"), memberName(request), stationName(request))
    }
}

// MARK: - original-run guard appeal (pages/play)

/// The stop sheet line under an arrival the guard did not record. Eligibility, the submitted state and the
/// decision come only from the server; a pending submission offers a refresh, never a second submit.
@MainActor struct PlayGuardAppealSection: View {
    let scope: PlaySessionScope
    let nodeID: Int
    /// The newest appealable refusal for this stop, if the run produced one.
    let reference: PlayGuardAppealReference?
    @Environment(\.playerGapService) private var service
    @State private var flow: PlayGuardAppealFlow?
    @State private var composing = false
    @State private var reason = ""

    private struct LoadKey: Hashable { let account: Int?; let scope: String; let reference: PlayGuardAppealReference? }
    private var sessionKey: String { (scope.fields.keys.first ?? "scope") + ":" + String(scope.id) }

    var body: some View {
        Group {
            if let flow, let entry = flow.entry, entry.reference.nodeID == String(nodeID) {
                Section { content(flow, entry) } header: { Text("guard.title", tableName: tailTable) }
            } else if flow?.storageFailed == true {
                Section { Text("guard.storageFailed", tableName: tailTable) } header: { Text("guard.title", tableName: tailTable) }
            } else if service == nil, reference != nil {
                Section { Text("guard.unavailable", tableName: tailTable).foregroundStyle(CYColor.textSecondary) } header: { Text("guard.title", tableName: tailTable) }
            }
        }
        .task(id: LoadKey(account: service?.accountID, scope: sessionKey, reference: reference)) {
            guard let service else { flow = nil; return }
            if flow == nil || flow?.entry?.owner != service.accountID {
                flow = PlayGuardAppealFlow(service: service, store: PlayCreatorTailDefaultsStore(), session: sessionKey)
            }
            if let reference { flow?.reference(reference) }
            await flow?.read()
        }
        .sheet(isPresented: $composing) { Group { compose }.cySheet(detents: [.large]) }
    }

    @ViewBuilder private func content(_ flow: PlayGuardAppealFlow, _ entry: PlayGuardAppealFlow.Entry) -> some View {
        if entry.command != nil {
            if entry.state == .found {
                if entry.result?.canReverify == true {
                    Text("guard.accepted.reverify", tableName: tailTable).accessibilityIdentifier("play.guard.reverify")
                } else {
                    CYStatusChip(verbatim: tailText("guard.appealed"), tone: .info, systemImage: "checkmark.seal")
                        .accessibilityIdentifier("play.guard.appealed")
                }
                if let state = entry.result?.appealState { Text(verbatim: appealStateText(state)).cyText(.caption).foregroundStyle(CYColor.textSecondary) }
                if let decision = entry.result?.decisionReason, !decision.isEmpty { Text(verbatim: decision).cyText(.caption) }
            } else {
                Text("guard.unconfirmed", tableName: tailTable).accessibilityIdentifier("play.guard.unconfirmed")
                CYPillButton("guard.refresh", style: .secondary, systemImage: "arrow.clockwise", tableName: tailTable) { Task { await flow.read() } }
                    .disabled(flow.busy).listRowBackground(Color.clear)
                    .accessibilityIdentifier("play.guard.refresh")
            }
        } else if entry.eligibility?.canSubmit == true {
            Text("guard.notRecorded", tableName: tailTable)
            CYPillButton("guard.appeal", style: .secondary, systemImage: "text.bubble", tableName: tailTable) { reason = ""; composing = true }
                .disabled(!flow.canSubmit).listRowBackground(Color.clear)
                .accessibilityIdentifier("play.guard.appeal")
        } else if entry.eligibility != nil {
            Text("guard.readOnly", tableName: tailTable).foregroundStyle(CYColor.textSecondary)
        } else {
            Text(LocalizedStringKey(entry.note == .originMismatch ? "guard.originMismatch" : "guard.reading"), tableName: tailTable)
            if entry.note == .readFailed {
                CYPillButton("guard.refresh", style: .secondary, systemImage: "arrow.clockwise", tableName: tailTable) { Task { await flow.read() } }
                    .disabled(flow.busy).listRowBackground(Color.clear)
            }
        }
        if let message = entry.serverMessage, entry.state != .found, !message.isEmpty {
            Text(verbatim: message).cyText(.caption).foregroundStyle(CYColor.textSecondary)
        }
    }

    private var compose: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(tailText("guard.compose.placeholder"), text: $reason, axis: .vertical)
                        .lineLimit(4...10)
                        .accessibilityIdentifier("play.guard.reason")
                } footer: { Text("guard.compose.footer", tableName: tailTable) }
            }
            .navigationTitle(Text("guard.compose.title", tableName: tailTable))
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                CYPillButton("guard.compose.submit", tableName: tailTable) {
                    let text = reason; composing = false
                    Task { await flow?.submit(reason: text) }
                }
                .disabled(!CreatorAuditTimeline.reasonValid(reason) || flow?.canSubmit != true)
                .padding(CYSpacing.lg)
                .accessibilityIdentifier("play.guard.submit")
            }
        }
        .cySheet()
    }
}

/// `APPEAL_TEXT` of `audit-timeline.js`; an unknown state is a dash.
func appealStateText(_ state: String) -> String {
    CreatorAuditTimeline.appealStates.contains(state) ? tailText("appeal.state." + state) : "—"
}

// MARK: - author audit record + appeal (subpackageA/pages/myproject)

/// Row under a rejected or offline project card. Opens the audit record sheet.
@MainActor struct MyProjectAuditEntry: View {
    let project: CreatorContentProject
    @State private var open = false
    var body: some View {
        if let target = CreatorAuditTarget.project(id: project.sourceID, bizType: project.bizType, state: project.state) {
            Button { open = true } label: {
                CYListRow(verbatim: tailText("audit.entry"), trailing: .chevron) { CYRowIcon(systemImage: "doc.text.magnifyingglass") }
            }
            .accessibilityIdentifier("myProject.audit.\(project.id)")
            .sheet(isPresented: $open) { Group { CreatorAuditSheet(target: target, title: project.title) }.cySheet(detents: [.large]) }
        }
    }
}

@MainActor struct CreatorAuditSheet: View {
    let target: CreatorAuditTarget
    let title: String
    @Environment(\.playerGapService) private var service
    @Environment(\.dismiss) private var dismiss
    @State private var flow: CreatorAuditAppealFlow?
    @State private var composing = false
    @State private var reason = ""
    @State private var picking = false

    var body: some View {
        NavigationStack {
            List {
                if let flow { content(flow) }
                else if service == nil { CYEmptyState(systemImage: "lock", "audit.unavailable", tableName: tailTable) }
                else { CYLoadingStateView(rows: 2) }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(Text("audit.title", tableName: tailTable))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(tailText("audit.close")) { dismiss() } } }
        }
        .task(id: service?.accountID) {
            guard let service else { flow = nil; return }
            let next = CreatorAuditAppealFlow(service: service, store: PlayCreatorTailDefaultsStore(), target: target)
            flow = next
            await next?.loadTimeline()
        }
        .sheet(isPresented: $composing) { Group { compose }.cySheet(detents: [.large]) }
        .sheet(isPresented: $picking) { imagePicker }
    }

    @ViewBuilder private func content(_ flow: CreatorAuditAppealFlow) -> some View {
        if !title.isEmpty { Section { Text(verbatim: title).cyText(.cardTitle) } }
        switch flow.load {
        case .loading: CYLoadingStateView(rows: 2)
        case .failed(let message):
            Section {
                if let message, !message.isEmpty { Text(verbatim: message) } else { Text("audit.loadFailed", tableName: tailTable) }
                CYPillButton("audit.retry", style: .secondary, systemImage: "arrow.clockwise", tableName: tailTable) { Task { await flow.loadTimeline() } }
                    .listRowBackground(Color.clear).accessibilityIdentifier("myProject.audit.retry")
            }
        case .ready(let timeline):
            Section {
                if timeline.rows.isEmpty { Text("audit.empty", tableName: tailTable).foregroundStyle(CYColor.textSecondary) }
                ForEach(timeline.rows) { row in
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        Text(verbatim: rowLabel(row)).cyText(.body)
                        if !row.detail.isEmpty { Text(verbatim: row.detail).cyText(.caption).foregroundStyle(CYColor.textSecondary) }
                    }
                    .accessibilityElement(children: .combine)
                }
            } header: { Text("audit.records", tableName: tailTable) }
        }
        Section {
            if let state = flow.appealState {
                LabeledContent(tailText("audit.appeal")) { Text(verbatim: appealStateText(state)) }
                    .accessibilityIdentifier("myProject.audit.appealState")
            }
            if let note = flow.note { Text(verbatim: noteText(note)).cyText(.caption).foregroundStyle(CYColor.textSecondary)
                .accessibilityIdentifier("myProject.audit.note") }
            if flow.offersRecovery {
                CYPillButton("audit.recover", style: .secondary, systemImage: "arrow.clockwise", tableName: tailTable) { Task { await flow.recover() } }
                    .listRowBackground(Color.clear).accessibilityIdentifier("myProject.audit.recover")
            }
            attachments(flow)
            if flow.offersAppeal {
                CYPillButton("audit.appeal.open", style: .secondary, systemImage: "text.bubble", tableName: tailTable) {
                    reason = flow.draft.reason; composing = true
                }
                .listRowBackground(Color.clear).accessibilityIdentifier("myProject.audit.appeal")
                Text("audit.appeal.once", tableName: tailTable).cyText(.caption).foregroundStyle(CYColor.textSecondary)
            }
        }
    }

    @ViewBuilder private func attachments(_ flow: CreatorAuditAppealFlow) -> some View {
        if flow.uploadingImages {
            Text("audit.attach.uploading", tableName: tailTable).cyText(.caption).foregroundStyle(CYColor.textSecondary)
                .accessibilityIdentifier("myProject.audit.uploading")
        }
        if let problem = flow.imageProblem {
            Text(verbatim: imageProblemText(problem)).cyText(.caption).foregroundStyle(CYColor.textSecondary)
                .accessibilityIdentifier("myProject.audit.imageError")
            Button(action: { flow.dismissImageProblem() }) {
                Text("audit.attach.dismiss", tableName: tailTable)
            }
            .accessibilityIdentifier("myProject.audit.imageError.dismiss")
        }
        ForEach(Array(flow.draft.attachments.enumerated()), id: \.offset) { index, _ in
            if flow.offersAppeal {
                Button(action: { flow.removeImage(at: index) }) {
                    Text(verbatim: tailText("audit.attach.remove") + " " + String(index + 1))
                }
                .accessibilityIdentifier("myProject.audit.removeImage.\(index)")
            } else {
                Text(verbatim: tailText("audit.attach.item") + " " + String(index + 1))
                    .cyText(.body)
                    .accessibilityIdentifier("myProject.audit.image.\(index)")
            }
        }
        if flow.canAddImages {
            Button(action: { picking = true }) {
                CYListRow(verbatim: tailText("audit.attach.add"), meta: tailText("audit.attach.hint"), trailing: CYListRowTrailing.none) {
                    CYRowIcon(systemImage: "photo.badge.plus")
                }
            }
            .accessibilityIdentifier("myProject.audit.addImage")
        }
    }

    private var imagePicker: some View {
        AppealImagePicker(limit: max(flow?.imageSlots ?? 1, 1), onImages: { jpegs in
            picking = false
            guard !jpegs.isEmpty else { return }
            Task { await flow?.uploadImages(jpegs) }
        }, onFailure: {
            picking = false
            flow?.failImagePick()
        })
    }

    private var compose: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(tailText("audit.compose.placeholder"), text: $reason, axis: .vertical)
                        .lineLimit(4...12)
                        .accessibilityIdentifier("myProject.audit.reason")
                } footer: { Text("audit.compose.footer", tableName: tailTable) }
            }
            .navigationTitle(Text("audit.appeal", tableName: tailTable))
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                CYPillButton("audit.compose.submit", tableName: tailTable) {
                    let text = reason; composing = false
                    Task { await flow?.submit(reason: text) }
                }
                .disabled(!CreatorAuditTimeline.reasonValid(reason) || flow?.offersAppeal != true)
                .padding(CYSpacing.lg)
                .accessibilityIdentifier("myProject.audit.submit")
            }
        }
        .cySheet()
    }

    private func rowLabel(_ row: CreatorAuditTimelineRow) -> String {
        let kind = tailText("audit.kind." + row.kind.rawValue)
        if let action = row.action { return kind + " · " + tailText("audit.action." + action) }
        let item = row.problemItemType.map { tailText("audit.item." + $0) } ?? tailText("audit.item.other")
        return kind + " · " + item + (row.problemItemID.map { " #" + $0 } ?? "") + tailText("audit.problem")
    }

    private func imageProblemText(_ problem: CreatorAppealImageProblem) -> String {
        switch problem {
        case .oversize: return tailText("audit.attach.oversize")
        case .missingAddress: return tailText("audit.attach.missing")
        case .pendingReview: return tailText("audit.attach.pending")
        case .rejected(let reason):
            let shown = reason.trimmingCharacters(in: .whitespacesAndNewlines)
            return shown.isEmpty ? tailText("audit.attach.rejected") : shown
        case .server(let message):
            let shown = message.trimmingCharacters(in: .whitespacesAndNewlines)
            return shown.isEmpty ? "—" : shown
        case .unknown: return "—"
        }
    }

    private func noteText(_ note: CreatorAuditAppealFlow.Note) -> String {
        switch note {
        case .pendingOnOpen: return tailText("audit.note.pendingOnOpen")
        case .legacyUnbound: return tailText("audit.note.legacyUnbound")
        case .recordIncomplete: return tailText("audit.note.recordIncomplete")
        case .unconfirmed: return tailText("audit.note.unconfirmed")
        case .readFailed: return tailText("audit.note.readFailed")
        case .submitted: return tailText("audit.note.submitted")
        case .confirmed(let id): return String(format: tailText("audit.note.confirmed"), id)
        case .networkPending: return tailText("audit.note.networkPending")
        case .server(let message): return message
        case .storageFailed: return tailText("audit.note.storageFailed")
        }
    }
}

// MARK: - share-edition empty reason (pages/club/detail)

/// `loadShareEditionEmptyReason` for an empty editions list. Compensation stays behind the money area switch:
/// where it is closed (production) only the generic "no editions yet" line shows, as when the reason is unknown.
@MainActor struct ClubEditionEmptyReasonView: View {
    let clubID: Int
    var reload: () -> Void = {}
    @Environment(\.playerGapService) private var service
    private enum Phase: Equatable { case loading, ready(ClubEditionEmptyReason), failed, closed }
    @State private var phase: Phase = .loading

    var body: some View {
        Group {
            switch phase {
            case .ready(let reason):
                CYEmptyState(systemImage: "square.stack", LocalizedStringKey("edition.empty." + reason.rawValue), tableName: tailTable,
                             detailVerbatim: reason == .noPermission || reason == .hasEditions ? tailText("edition.empty." + reason.rawValue + ".sub") : nil,
                             actionTitle: reason.offersRetry ? LocalizedStringKey(tailText("edition.empty.reload")) : nil, action: reason.offersRetry ? reload : nil)
            case .failed:
                CYEmptyState(systemImage: "square.stack", "edition.empty.generic", tableName: tailTable, detailVerbatim: tailText("edition.empty.unconfirmed"),
                             actionTitle: LocalizedStringKey(tailText("edition.empty.retry")), action: { Task { await read() } })
            case .loading:
                CYEmptyState(systemImage: "square.stack", "edition.empty.generic", tableName: tailTable, detailVerbatim: tailText("edition.empty.checking"))
            case .closed:
                CYEmptyState(systemImage: "square.stack", "edition.empty.generic", tableName: tailTable)
            }
        }
        .accessibilityIdentifier("club.editions.emptyReason")
        .task(id: clubID) { await read() }
    }

    private func read() async {
        guard let service, ReviewedAreaSwitch.moneyPayments(apiHost: service.baseURL.host) else { phase = .closed; return }
        phase = .loading
        let captured = clubID
        let reason = await service.editionEmptyReason(clubID: captured)
        guard captured == clubID else { return }
        phase = reason.map(Phase.ready) ?? .failed
    }
}

/// `chooseImage` count is the slots left under 6. The shared picker keeps pick order.
@MainActor private struct AppealImagePicker: UIViewControllerRepresentable {
    let limit: Int
    let onImages: ([Data]) -> Void
    let onFailure: () -> Void
    func makeUIViewController(context: Context) -> Host { Host(limit: limit, onImages: onImages, onFailure: onFailure) }
    func updateUIViewController(_ controller: Host, context: Context) {}

    @MainActor final class Host: UIViewController {
        private let limit: Int
        private let onImages: ([Data]) -> Void
        private let onFailure: () -> Void
        private var started = false
        private var picker: RetainedNativeImagePicker?
        init(limit: Int, onImages: @escaping ([Data]) -> Void, onFailure: @escaping () -> Void) {
            self.limit = limit
            self.onImages = onImages
            self.onFailure = onFailure
            super.init(nibName: nil, bundle: nil)
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) unavailable") }
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard !started else { return }
            started = true
            let picker = RetainedNativeImagePicker(enabled: true, present: { [weak self] view in
                guard let self, self.presentedViewController == nil else { return false }
                self.present(view, animated: true)
                return true
            }, dismiss: { [weak self] in
                self?.presentedViewController?.dismiss(animated: true)
            })
            self.picker = picker
            let slots = limit
            Task { @MainActor [weak self] in
                guard let self else { return }
                do {
                    let images = try await picker.selectBatch(limit: slots)
                    self.onImages(images?.map(\.jpeg) ?? [])
                } catch {
                    self.onFailure()
                }
            }
        }
    }
}

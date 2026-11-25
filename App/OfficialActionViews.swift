import SwiftUI

/// Original shared sheet. Each occurrence owns its review; host identity gates remain in force.
@MainActor struct OfficialActionSheet: View {
    let coordinator: OfficialActionCoordinator
    let command: OfficialActionCommand
    /// Optional source confirmation copy (e.g. official-inbox modal title/content).
    var noticeTitleKey: String? = nil
    var noticeBodyKey: String? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model: OfficialActionPresentationModel
    init(coordinator: OfficialActionCoordinator, command: OfficialActionCommand,
         noticeTitleKey: String? = nil, noticeBodyKey: String? = nil) {
        self.coordinator = coordinator; self.command = command
        self.noticeTitleKey = noticeTitleKey; self.noticeBodyKey = noticeBodyKey
        _model = StateObject(wrappedValue: OfficialActionPresentationModel(coordinator: coordinator, command: command))
    }
    var body: some View {
        NavigationStack {
            Group {
                if model.isBound(to: coordinator, command: command) {
                    form
                } else { CYEmptyState(systemImage: "arrow.clockwise", "officialAction.stale") }
            }
            .cyPageTitle("officialAction.review")
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button("officialAction.close") { model.disappear(); dismiss() }.disabled(model.busy)
            } }
            .interactiveDismissDisabled(model.busy)
            .onAppear { model.appear(isActive: scenePhase == .active) }
            .onChange(of: scenePhase) { _, phase in model.sceneChanged(isActive: phase == .active) }
            .onChange(of: coordinator.identity) { _, _ in model.synchronizeIdentity() }
            .onChange(of: ObjectIdentifier(coordinator)) { _, _ in model.disappear() }
            .onChange(of: command) { _, _ in model.disappear() }
            .onDisappear { model.disappear() }
        }
    }
    private var form: some View {
        Form {
            Section {
                Label("officialAction.reviewNotice", systemImage: "lock.shield")
                Text(LocalizedStringKey(command.titleKey)).cyText(.sectionTitle).accessibilityAddTraits(.isHeader)
                Text("officialAction.noOutcomePromise").foregroundStyle(.secondary)
            }
            if noticeTitleKey != nil || noticeBodyKey != nil {
                Section {
                    if let noticeTitleKey { Text(LocalizedStringKey(noticeTitleKey)).cyText(.cardTitle).accessibilityAddTraits(.isHeader) }
                    if let noticeBodyKey { Text(LocalizedStringKey(noticeBodyKey)).foregroundStyle(.secondary) }
                }.accessibilityIdentifier("official.inbox.confirmation.\(command.scope)")
            }
            if let review = model.review {
                Section("officialAction.target") {
                    Text(review.command.scope).textSelection(.enabled)
                    if let event = review.snapshot.event { Text(event.title) }
                    if let invite = review.snapshot.invite { Text(invite.title) }
                    // Exact immutable payload, including explicit audience/channel and location details.
                    if let body = review.body, let object = try? JSONSerialization.jsonObject(with: body),
                       let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]) {
                        Text(String(decoding: pretty, as: UTF8.self)).font(.body.monospaced())
                            .textSelection(.enabled).accessibilityIdentifier("officialAction.reviewPayload")
                    }
                }
                Section {
                    CYPillButton("officialAction.confirm") { model.submit(review) }
                        .disabled(!model.canConfirm)
                        .accessibilityIdentifier("officialAction.confirm").e1ActionRow()
                    if !coordinator.enabled { Text("officialAction.disabled").foregroundStyle(.secondary) }
                }
            }
            if model.busy {
                CYSkeletonBlock(height: 18).accessibilityLabel(Text("officialAction.working"))
                // R7-PC-C5-2 (MP official-inbox/index.wxml:32): the inbox card's polite busy line while the write runs.
                if noticeTitleKey != nil {
                    Text("official.inbox.submitting").cyText(.caption).foregroundStyle(.secondary)
                        .accessibilityAddTraits(.updatesFrequently).accessibilityIdentifier("official.inbox.submitting")
                }
            }
            if let message = model.message {
                Text(LocalizedStringKey(message)).accessibilityIdentifier("officialAction.message")
                if model.canReview {
                    CYPillButton("officialAction.review", style: .secondary) { model.readAgain() }
                        .accessibilityIdentifier("officialAction.review").e1ActionRow()
                }
            }
            if let rejectionReason = model.rejectionReason { Text(rejectionReason).accessibilityIdentifier("officialAction.rejectionReason") }
            if let receipt = model.receipt { receiptView(receipt) }
        }
        .formStyle(.grouped)
        .cyGroupedSurface()
    }
    @ViewBuilder private func receiptView(_ receipt: OfficialActionReceipt) -> some View {
        Section("officialAction.result") {
            switch receipt {
            case .published(let id): Text("officialAction.published"); Text(String(id))
            case .broadcastSubmitted(let id): Text("officialAction.broadcastSubmitted"); Text(String(id))
            case .invitesIssued(let ids): Text("officialAction.invitesIssued"); Text(ids.map(String.init).joined(separator: ", "))
            case .arrival(let accepted, let completed, _):
                Text(accepted ? "officialAction.arrivalAccepted" : "officialAction.arrivalRejected")
                Text(completed ? "officialAction.serverCompleted" : "officialAction.serverNotCompleted")
            case .acknowledged: Text("officialAction.acknowledged")
            }
            Text("officialAction.refreshFacts").foregroundStyle(.secondary)
        }
    }
}

@MainActor struct OfficialPublishEditor: View {
    let coordinator: OfficialActionCoordinator
    @State private var draft = OfficialEventDraft()
    @State private var includeDates = false
    @State private var start = Date()
    @State private var end = Date().addingTimeInterval(86400)
    @State private var reviewed: OfficialActionCommand?
    var body: some View {
        Form {
            Section("officialAction.draft") {
                TextField("officialAction.title", text: $draft.title).accessibilityIdentifier("officialAction.title")
                TextField("officialAction.subtitle", text: $draft.subtitle, axis: .vertical)
                TextField("officialAction.city", text: $draft.city)
                Picker("officialAction.category", selection: $draft.category) {
                    ForEach(["city_light", "custom", "festival", "brand", "challenge"], id: \.self) { Text(LocalizedStringKey("officialAction.category." + $0)).tag($0) }
                }
                Toggle("officialAction.dates", isOn: $includeDates)
                if includeDates {
                    DatePicker("officialAction.start", selection: $start)
                    DatePicker("officialAction.end", selection: $end)
                }
            }
            Section("officialAction.rewards") {
                Toggle("officialAction.collective", isOn: $draft.collective)
                if draft.collective {
                    Picker("officialAction.metric", selection: $draft.metric) {
                        ForEach(["light_count", "complete_count", "signup_count"], id: \.self) { Text(LocalizedStringKey("officialAction.metric." + $0)).tag($0) }
                    }
                    TextField("officialAction.threshold", value: $draft.threshold, format: .number).keyboardType(.decimalPad)
                }
                TextField("officialAction.xp", value: $draft.experience, format: .number).keyboardType(.decimalPad)
                Toggle("officialAction.badge", isOn: $draft.badge)
                Text("officialAction.rewardWarning").foregroundStyle(.secondary)
            }
            Section {
                CYPillButton("officialAction.review") {
                    var copy = draft; copy.start = includeDates ? start : nil; copy.end = includeDates ? end : nil
                    reviewed = .publish(copy)
                }.disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("officialAction.reviewPublish").e1ActionRow()
                Text("officialAction.editGap").foregroundStyle(.secondary)
            }
        }.formStyle(.grouped).cyGroupedSurface().cyPageTitle("officialAction.publish")
            .sheet(isPresented: Binding(get: { reviewed != nil }, set: { if !$0 { reviewed = nil } })) { Group {
                if let reviewed { OfficialActionSheet(coordinator: coordinator, command: reviewed) }
            }.cySheet() }
    }
}

@MainActor struct OfficialBroadcastEditor: View {
    let coordinator: OfficialActionCoordinator
    @State private var draft = OfficialBroadcastDraft()
    @State private var reviewed: OfficialActionCommand?
    var body: some View {
        Form {
            Section("officialAction.audience") {
                ForEach(OfficialAudience.allCases, id: \.self) { role in
                    Toggle(LocalizedStringKey("officialAction.role." + role.rawValue), isOn: Binding(
                        get: { draft.audience.contains(role) }, set: { if $0 { draft.audience.insert(role) } else { draft.audience.remove(role) } }))
                }
                TextField("officialAction.city", text: $draft.city)
                Text("officialAction.cityWarning").foregroundStyle(.secondary)
            }
            Section("officialAction.channels") {
                ForEach(OfficialChannel.allCases, id: \.self) { channel in
                    Toggle(LocalizedStringKey("officialAction.channel." + channel.rawValue), isOn: Binding(
                        get: { draft.channels.contains(channel) }, set: { if $0 { draft.channels.insert(channel) } else { draft.channels.remove(channel) } }))
                }
            }
            Section("officialAction.copy") {
                Toggle("officialAction.split", isOn: $draft.split)
                if draft.split {
                    ForEach(OfficialAudience.allCases.filter { draft.audience.contains($0) }, id: \.self) { role in
                        Text(LocalizedStringKey("officialAction.role." + role.rawValue)).cyText(.cardTitle).accessibilityAddTraits(.isHeader)
                        TextField("officialAction.title", text: roleBinding(role, title: true))
                        TextField("officialAction.subtitle", text: roleBinding(role, title: false), axis: .vertical)
                    }
                } else {
                    TextField("officialAction.title", text: $draft.unified.title)
                    TextField("officialAction.subtitle", text: $draft.unified.sub, axis: .vertical)
                }
            }
            CYPillButton("officialAction.review") { reviewed = .broadcast(draft) }
                .disabled((try? draft.payload()) == nil)
                .accessibilityIdentifier("officialAction.reviewBroadcast").e1ActionRow()
        }.formStyle(.grouped).cyGroupedSurface().cyPageTitle("officialAction.broadcast")
            .sheet(isPresented: Binding(get: { reviewed != nil }, set: { if !$0 { reviewed = nil } })) { Group {
                if let reviewed { OfficialActionSheet(coordinator: coordinator, command: reviewed) }
            }.cySheet() }
    }
    private func roleBinding(_ role: OfficialAudience, title: Bool) -> Binding<String> {
        Binding(get: { let copy = draft.copies[role] ?? OfficialCopy(); return title ? copy.title : copy.sub },
                set: { var copy = draft.copies[role] ?? OfficialCopy(); if title { copy.title = $0 } else { copy.sub = $0 }; draft.copies[role] = copy })
    }
}

/// A caller must fetch the current account's inbox and permission before exposing controls.
/// Source official-inbox eligibility and fixed audit reasons; no free-text reason is sent.
/// Visibility is not authority: the coordinator re-reads the server row (and publisher
/// permission for OFFICIAL rows), and every write stays behind the dormant approval gate.
@MainActor struct OfficialInviteResponseActions: View {
    let coordinator: OfficialActionCoordinator
    let invite: OfficialPartyInvite
    /// Kept for callers; the source shows organizer controls without a client-side publisher check.
    let publisher: Bool
    var window: OfficialServiceWindow? = nil
    /// R7-PC-C5-3: inside the invite's own card (no second 回应 section).
    var embedded = false
    @Environment(\.locale) private var locale
    @State private var reviewed: OfficialActionCommand?
    @State private var reviewedAction: OfficialResponseAction?
    /// R7-PC-C5-2: the last reviewed action, kept so a failed or unconfirmed write can be retried from the card.
    @State private var lastReviewed: (command: OfficialActionCommand, action: OfficialResponseAction)?
    @State private var actionFailed = false
    @State private var transferHint = false
    @State private var toastMessage: String?
    private var actions: [OfficialResponseAction] { OfficialInboxPresentation.actions(for: invite) }
    var body: some View {
        Group {
            // Embedded: one row, so the sheet and toast below attach to a single view.
            if embedded { VStack(alignment: .leading, spacing: CYSpacing.sm) { content } } else { Section("officialAction.respond") { content } }
        }
        .cyToast(verbatimMessage: $toastMessage)
        .sheet(isPresented: Binding(get: { reviewed != nil }, set: { if !$0 { reviewed = nil; reviewedAction = nil } }), onDismiss: {
            // R7-PC-C5-2 (MP `cy-inline-error` 这次操作没有完成 + 重试): a rejected or unknown write stays visible on the card.
            actionFailed = lastReviewed != nil && [.rejected, .unknown].contains(coordinator.state)
        }) {
            if let reviewed {
                OfficialActionSheet(coordinator: coordinator, command: reviewed,
                                    noticeTitleKey: reviewedAction.map { OfficialInboxPresentation.confirmationTitleKey(invite, action: $0) },
                                    noticeBodyKey: reviewedAction.map { OfficialInboxPresentation.confirmationBodyKey(invite, action: $0) })
                    .cyDomainSheet(detents: [.half, .full])
            }
        }
    }
    @ViewBuilder private var content: some View {
            if actionFailed, let last = lastReviewed {
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    Label("official.inbox.actionFailed", systemImage: "exclamationmark.circle")
                        .cyText(.bodyCompact, weight: .semibold).foregroundStyle(CYColor.dangerText)
                    Button("action.retry") {
                        actionFailed = false
                        reviewedAction = last.action
                        reviewed = last.command
                    }
                    .frame(minHeight: CYSpacing.minTouchTarget)
                    .accessibilityIdentifier("official.inbox.retry.\(invite.id)")
                }
                .accessibilityElement(children: .contain)
            }
            if let window {
                LabeledContent("official.privateParity.inbox.window") {
                    Text(verbatim: window.sourceText)
                }.cyText(.bodyCompact).accessibilityIdentifier("official.inbox.actionWindow.\(invite.id)")
            }
            if OfficialInboxPresentation.showsOrganizerTransferNotice(invite) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("official.privateParity.inbox.organizerTransferHint").font(.subheadline)
                    Text("official.privateParity.inbox.organizerTransferDetail").cyText(.bodyCompact).foregroundStyle(.secondary)
                }.fixedSize(horizontal: false, vertical: true)
                    .accessibilityElement(children: .combine).accessibilityIdentifier("official.inbox.organizerTransfer.\(invite.id)")
            }
            ForEach(actions, id: \.self) { action in
                // PC-C-5-2: 接受职责 is the likely action (MP primary); decline / withdraw stay secondary.
                CYPillButton(LocalizedStringKey(OfficialInboxPresentation.buttonKey(action)), style: action == .accept ? .primary : .secondary) {
                    if OfficialInboxPresentation.requiresOrganizerTransfer(invite, action: action) {
                        transferHint = true
                        toastMessage = PlayCloseCopy.text("请前往主办方转移入口处理", "Handle this in organizer transfer", locale)
                        return
                    }
                    transferHint = false
                    // PC-C-5-1: one confirmation. The review sheet already carries the action's MP title and body
                    // (接受本场职责 / 拒绝本场邀约 / 退出本场职责), so the generic modal step is gone.
                    reviewedAction = action
                    let command = OfficialActionCommand.sourceInboxResponse(to: invite, action: action)
                    reviewed = command
                    lastReviewed = (command, action)
                    actionFailed = false
                }
                    .accessibilityIdentifier("official.inbox.\(action.rawValue.lowercased()).\(invite.id)").e1ActionRow()
            }
            if transferHint {
                Text("official.privateParity.inbox.organizerTransferHint").cyText(.bodyCompact).foregroundStyle(.secondary)
                    .accessibilityIdentifier("official.inbox.transferHint.\(invite.id)")
            }
    }
}

/// One sheet occurrence stays occupied until its matching dismissal finishes.
struct OfficialParticipationPresentation {
    struct Entry {
        let id = UUID()
        let command: OfficialActionCommand
        let onReturn: (() -> Void)?
    }
    private(set) var entry: Entry?
    private(set) var isPresented = false
    mutating func open(command: OfficialActionCommand, onReturn: (() -> Void)?) {
        guard entry == nil else { return }
        entry = Entry(command: command, onReturn: onReturn)
        isPresented = true
    }
    mutating func beginDismiss(id: UUID) {
        guard entry?.id == id else { return }
        isPresented = false
    }
    mutating func finishDismiss(id: UUID) -> (() -> Void)? {
        guard let current = entry, current.id == id else { return nil }
        entry = nil
        isPresented = false
        return current.onReturn
    }
}

@MainActor struct OfficialParticipationActions: View {
    let coordinator: OfficialActionCoordinator
    let event: OfficialEvent
    var arrival: OfficialArrivalEvidence? = nil
    var onReturn: (() -> Void)? = nil
    @State private var presentation = OfficialParticipationPresentation()
    @State private var safetyConsented = false
    @Environment(\.playerGapService) private var gapService
    /// PC-C-4-1: a signup with a 安全须知 needs the explicit check first.
    private var needsSafetyConsent: Bool {
        if case .signup? = command, event.safetyNoticeTitle != nil { return true }
        return false
    }
    private var command: OfficialActionCommand? {
        guard !event.paused else { return nil }
        if event.signed == false && [2, 3].contains(event.status ?? -1) { return .signup(event.id) }
        if event.signed == true && event.status == 3 {
            if !event.isV2 && !event.roamEnabled { return .complete(event.id) }
            if event.isV2, let arrival, arrival.eventID == event.id,
               event.missions.contains(where: { $0.code == arrival.missionCode && $0.complete == false && $0.canVerifyArrival == true }) { return .arrival(arrival) }
        }
        return nil
    }
    var body: some View {
        let presentationID = presentation.entry?.id
        Group { if command != nil || needsSafetyConsent {
        Section("officialAction.participation") {
            if needsSafetyConsent, let title = event.safetyNoticeTitle {
                // MP cy-consent-check: a checkbox, never pre-checked.
                Button { safetyConsented.toggle() } label: {
                    HStack(alignment: .firstTextBaseline, spacing: CYSpacing.sm) {
                        Image(systemName: safetyConsented ? "checkmark.square.fill" : "square")
                            .foregroundStyle(safetyConsented ? CYColor.brand : CYColor.textSecondary)
                        Text("official.safetyNotice.agree \(title)").cyText(.bodyCompact)
                            .foregroundStyle(CYColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(safetyConsented ? .isSelected : [])
                .accessibilityIdentifier("officialAction.safetyNotice.consent")
            }
            // The mini-program signs up through the SIGNUP command with a kept request id.
            if case .signup(let eventID)? = command, gapService != nil {
                OfficialSignupCommandSection(eventID: eventID, onSettled: { onReturn?() },
                                             consented: !needsSafetyConsent || safetyConsented)
            } else if let command {
                CYPillButton(LocalizedStringKey(command.titleKey)) {
                    // Capture the detail visit at presentation time. A late dismissal
                    // must not use a callback supplied by a newer account or page.
                    presentation.open(command: command, onReturn: onReturn)
                }
                    .disabled(presentation.entry != nil || (needsSafetyConsent && !safetyConsented))
                    .accessibilityIdentifier("officialAction.participationReview").e1ActionRow()
            }
            // R7-PC-C4-2: no 暂时没有需要你操作的事项 row; the page's CTA bar already states the event's state.
        }
        } }.sheet(isPresented: Binding(get: { presentation.isPresented }, set: { if !$0, let presentationID { presentation.beginDismiss(id: presentationID) } }), onDismiss: {
            guard let presentationID else { return }
            let callback = presentation.finishDismiss(id: presentationID)
            callback?()
        }) { Group {
            if let entry = presentation.entry { OfficialActionSheet(coordinator: coordinator, command: entry.command) }
        }.cySheet(detents: [.large]) }
    }
}
@MainActor struct OfficialMerchantInviteEditor: View {
    struct Merchant: Identifiable { let id: Int; let name: String }
    let coordinator: OfficialActionCoordinator
    /// Host supplies verified candidates. This screen never searches contacts or sends suggestions.
    let candidates: [Merchant]
    @State private var selected: Set<Int> = []
    @State private var reviewed: OfficialActionCommand?
    var body: some View {
        Form {
            Section("officialAction.merchants") {
                ForEach(candidates) { merchant in
                    Toggle(merchant.name, isOn: Binding(get: { selected.contains(merchant.id) }, set: {
                        if $0 { selected.insert(merchant.id) } else { selected.remove(merchant.id) }
                    }))
                }
            }
            Text("officialAction.inviteWarning")
            CYPillButton("officialAction.review") { reviewed = .inviteMerchants(selected.sorted()) }
                .disabled(selected.isEmpty).e1ActionRow()
        }.formStyle(.grouped).cyGroupedSurface().cyPageTitle("officialAction.invite")
            .sheet(isPresented: Binding(get: { reviewed != nil }, set: { if !$0 { reviewed = nil } })) { Group {
                if let reviewed { OfficialActionSheet(coordinator: coordinator, command: reviewed) }
            }.cySheet() }
    }
}

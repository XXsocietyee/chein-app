import SwiftUI

/// A local immutable review, never a permission grant or agreement signature.
struct CoopFlowRequestPreview: View {
    @Environment(\.locale) private var locale
    @Environment(\.coopFlowPreviewWrite) private var write
    @Environment(\.dismiss) private var dismiss
    @Environment(\.coopInviteOutcomeUnknown) private var reportUnknownOutcome
    @Environment(\.coopInviteSent) private var reportInviteSent
    @Environment(\.topicEditorDestination) private var topicEditor
    @Environment(\.coopConversationDestination) private var conversationDestination
    @State private var openedConversation: Int?
    private let review: CoopFlowRequestReviewContext?
    private let operation: CoopFlowMutation
    /// True only for 取消合作 on an accepted invite. That refund stays off the MP-first catalog.
    private let cancelsAcceptedCooperation: Bool
    private enum Outcome: Equatable { case idle, sending, sent, failed(String?), unknown }
    @State private var outcome: Outcome = .idle
    init(operation: CoopFlowMutation, invitationContext: CoopFlowInvitationContext? = nil,
         currentSession: CoopFlowSession? = nil, cancelsAcceptedCooperation: Bool = false) {
        self.operation = operation
        self.cancelsAcceptedCooperation = cancelsAcceptedCooperation
        review = try? CoopFlowRequestReviewContext(operation: operation, invitationContext: invitationContext,
                                                  currentSession: currentSession)
    }
    /// Parity X1: one primary that dispatches through the reviewed coordinator; never a permanently dead button.
    @ViewBuilder private var submitSection: some View {
        Section {
            switch outcome {
            case .sent:
                Label("coopflow.submit.sent", systemImage: "checkmark.circle.fill").foregroundStyle(CYColor.successText)
                    .accessibilityIdentifier("coopflow.submit.sent")
                Button("coopflow.submit.done") {
                    // flows-g2 108: a sent invite ends on 协作列表 · 我发出的 when the list pushed the invite page.
                    if case .invite = operation, let reportInviteSent { reportInviteSent() } else { dismiss() }
                }
            case .unknown:
                Label("coopflow.submit.unknown", systemImage: "questionmark.circle").foregroundStyle(CYColor.warningText)
                    .accessibilityIdentifier("coopflow.submit.unknown")
            default:
                if review != nil, write?.coordinator(for: operation, cancelsAcceptedCooperation: cancelsAcceptedCooperation) != nil {
                    Button { Task { await submit() } } label: {
                        HStack { Text("coopflow.submit"); if outcome == .sending { Spacer(); ProgressView() } }
                    }
                    .disabled(outcome == .sending)
                    .accessibilityIdentifier("coopflow.submit")
                    if case .failed(let message) = outcome {
                        Group { if let message { Text(verbatim: message) } else { Text("coopflow.submit.failed") } }
                            .cyText(.meta).foregroundStyle(CYColor.dangerText)
                    }
                    // MC7-31-9 (MP coop/invite wxml:157 `goEditTopic`): a rejected send offers the topic editor
                    // (`pages/publish/fabu/index?id=&scope=`), so the owner can fix price/content and send again.
                    if case .failed = outcome, case .invite(let draft) = operation, let topicEditor {
                        NavigationLink { topicEditor(draft.topicID, draft.scope) } label: {
                            Text("merchantCoop.invite.editTopic").cyText(.meta)
                        }
                        .accessibilityIdentifier("coopflow.submit.editTopic")
                    }
                } else {
                    // Gated, not removed: China MP-first opens non-money writes. 取消合作 stays on the TEST host.
                    Button("coopflow.submit") {}.disabled(true).accessibilityIdentifier("coopflow.submit.disabled")
                    Text("coopflow.submit.gated").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                }
            }
        }
    }
    private func submit() async {
        guard outcome != .sending, let coordinator = write?.coordinator(for: operation, cancelsAcceptedCooperation: cancelsAcceptedCooperation) else { return }
        outcome = .sending
        do {
            let accepted = try await coordinator.prepare(operation)
            let result = try await coordinator.confirm(accepted)
            outcome = .sent
            if case .contact = operation, conversationDestination != nil,
               let conversation = result["conversationId"].integer, conversation > 0 {
                openedConversation = conversation
            }
        } catch CoopFlowFailure.server(_, let message) { outcome = .failed(message) }
        catch CoopFlowFailure.inactiveMerchant(_, let message) { outcome = .failed(message) }
        catch CoopFlowFailure.ambiguous { outcome = .unknown; reportUnknownOutcome?() }
        catch CoopFlowFailure.permission { outcome = .failed(nil) }
        catch { outcome = .failed(nil) }
    }
    var body: some View {
        List {
            Section("coopflow.reviewAction") {
                if let review {
                    ForEach(review.rows) { row in
                        LabeledContent(LocalizedStringKey(row.labelKey)) {
                            reviewValue(row.value).textSelection(.enabled).foregroundStyle(Color.primary)
                        }.accessibilityIdentifier("coopflow.review.field." + row.id)
                    }
                } else { Text("coopflow.invalid") }
            }
            Section { CoopFlowSafetyNotice(); Text("coopflow.review.local") }
            submitSection
        }.navigationTitle("coopflow.reviewAction").navigationBarTitleDisplayMode(.inline).accessibilityIdentifier("coopflow.review")
            .navigationDestination(item: $openedConversation) { id in
                if let conversationDestination { conversationDestination(id) }
            }
    }
    @ViewBuilder private func reviewValue(_ value: CoopFlowRequestReviewValue) -> some View {
        switch value {
        case .text(let text): Text(verbatim: text)
        case .localized(let key, let raw):
            VStack(alignment: .trailing, spacing: 2) {
                Text(LocalizedStringKey(key))
                if let raw { Text(verbatim: raw).font(.caption) }
            }
        case .recipient(let name, let identity):
            VStack(alignment: .trailing, spacing: 2) {
                if let name { Text(verbatim: name) }
                Text(verbatim: appLocalized(String.LocalizationValue(stringLiteral: "coopflow.review.identity." + identity.domain.rawValue), locale: locale) + " " + String(identity.id))
                    .font(name == nil ? .body : .caption)
            }
        case .notProvided: Text("coopflow.notProvided")
        }
    }
}

struct CoopFlowTemplateEditor: View {
    var currentCalendarSession: (() -> CoopFlowSession?)? = nil
    @State private var name = ""
    @State private var type = 0
    @State private var retail = ""
    @State private var cost = ""
    @State private var quota = ""
    @State private var validEnd = ""
    @State private var calendarSession: MerchantPerkValiditySession?
    @State private var calendarAppliedValue: String?
    @State private var calendarAppliedContext: MerchantPerkValidityContext?
    @State private var validityIssue = false
    @State private var reviewedOperation: CoopFlowMutation?
    @State private var showingReview = false
    private var operation: CoopFlowMutation? {
        guard let retail = Decimal(string: retail, locale: Locale(identifier: "en_US_POSIX")), let quota = Int(quota),
              cost.isEmpty || Decimal(string: cost, locale: Locale(identifier: "en_US_POSIX")) != nil,
              let draft = try? CoopFlowPerkTemplate(name: name, type: type, retailValue: retail,
                    unitCost: cost.isEmpty ? nil : Decimal(string: cost, locale: Locale(identifier: "en_US_POSIX")),
                    quota: quota, validEnd: validEnd.isEmpty ? nil : validEnd) else { return nil }
        return .createTemplate(draft)
    }
    var body: some View {
        Form {
            Section("coopflow.template.new") {
                TextField("coopflow.field.name", text: $name).accessibilityIdentifier("coopflow.template.name")
                Picker("coopflow.field.perkType", selection: $type) {
                    Text("coopflow.perk.0").tag(0); Text("coopflow.perk.1").tag(1); Text("coopflow.perk.2").tag(2)
                }
                TextField("coopflow.field.retailValue", text: $retail).keyboardType(.decimalPad)
                TextField("coopflow.field.unitCost", text: $cost).keyboardType(.decimalPad)
                TextField("coopflow.field.quota", text: $quota).keyboardType(.numberPad)
                if let currentCalendarSession {
                    MerchantPerkValidityEntry(value: $validEnd, session: $calendarSession,
                        appliedValue: $calendarAppliedValue, appliedContext: $calendarAppliedContext, context: {
                        guard let session = currentCalendarSession() else { return nil }
                        return .init(session: session, value: validEnd, siblingFields: [name, String(type), retail, cost, quota])
                    })
                } else {
                    TextField("coopflow.field.validEnd", text: $validEnd)
                }
            }
            if validityIssue {
                Text("merchant.perkSubmission.invalidDate").foregroundStyle(CYColor.dangerText)
                    .accessibilityIdentifier("merchant.perkSubmission.invalidDate")
            }
            if let operation {
                Button("coopflow.reviewAction") {
                    do {
                        // Evaluate the clock on this tap, not when the calendar first opened.
                        _ = try operation.body()
                        validityIssue = false; reviewedOperation = operation; showingReview = true
                    } catch { validityIssue = true }
                }.accessibilityIdentifier("merchant.perkSubmission.review")
            }
            else { Text("coopflow.template.required").foregroundStyle(.secondary) }
            CoopFlowSafetyNotice()
        }.navigationTitle("coopflow.template.new").navigationBarTitleDisplayMode(.inline)
            .modifier(MerchantPerkValidityStablePresentation(value: $validEnd, session: $calendarSession,
                appliedValue: $calendarAppliedValue, appliedContext: $calendarAppliedContext, context: {
                    guard let session = currentCalendarSession?() else { return nil }
                    return .init(session: session, value: validEnd, siblingFields: [name, String(type), retail, cost, quota])
                }))
            .onChange(of: validEnd) { _, _ in validityIssue = false }
            .navigationDestination(isPresented: $showingReview) {
                if let reviewedOperation { CoopFlowRequestPreview(operation: reviewedOperation) }
            }
    }
}
struct CoopFlowReasonEditor: View {
    let topicID: Int
    @State private var reason = ""
    var body: some View {
        Form {
            LabeledContent("coopflow.field.topicId", value: String(topicID))
            Section("coopflow.field.reason") {
                TextEditor(text: $reason).frame(minHeight: 140).accessibilityLabel("coopflow.field.reason")
            }
            Text("coopflow.complaint.rules")
            if !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                NavigationLink("coopflow.reviewAction") { CoopFlowRequestPreview(operation: .complaint(topicID: topicID, reason: reason)) }
            }
            CoopFlowSafetyNotice()
        }.navigationTitle("coopflow.complaint.prepare").navigationBarTitleDisplayMode(.inline)
    }
}
struct CoopFlowHandleEditor: View {
    let inviteID: Int
    let action: CoopFlowHandle
    let currentStatus: Int
    var supplyStationID: Int? = nil
    var supplyStationName: String? = nil
    var flowReader: (any CoopFlowReading)? = nil
    @Environment(\.locale) private var locale
    /// MC7-30-6 (round 3): the TEST-only gated station sender; nil where merchant writes are closed.
    @Environment(\.coopFlowPreviewWrite) private var write
    @Environment(\.dismiss) private var dismiss
    @State private var reason = ""
    @State private var confirmHandle = false
    @State private var proceedPreview = false
    @State private var toastMessage: String?
    private enum StationOutcome: Equatable { case idle, sending, sent, failed(String?), unknown }
    @State private var stationOutcome: StationOutcome = .idle

    private var modalTitle: String {
        switch action {
        case .accept:
            return MerchantAreaCopy.text("接受合作邀约", "Accept cooperation invite", locale)
        case .reject:
            return MerchantAreaCopy.text("拒绝这条邀约", "Reject this invite", locale)
        case .cancel:
            return currentStatus == 1
                ? MerchantAreaCopy.text("取消合作", "Cancel cooperation", locale)
                : MerchantAreaCopy.text("撤回邀约", "Withdraw invite", locale)
        }
    }

    private var modalMessage: String {
        switch action {
        case .accept:
            return MerchantAreaCopy.text("确认进入提交预览，核对无误后发送决定。", "Continue to review your acceptance before submitting.", locale)
        case .reject:
            return MerchantAreaCopy.text("拒绝理由会连同决定一起发给对方。", "Your decline reason will be sent to the other party.", locale)
        case .cancel:
            return currentStatus == 1
                ? MerchantAreaCopy.text("锁价开卖前可取消；锁价后需联系客服协商。", "You can cancel before price lock; after price lock, contact support.", locale)
                : MerchantAreaCopy.text("撤回后对方将无法接受这条邀约。", "Withdrawing prevents the other party from accepting this invite.", locale)
        }
    }

    var body: some View {
        Form {
            LabeledContent("coopflow.field.id", value: String(inviteID))
            Text(LocalizedStringKey("coopflow.handle." + String(action.rawValue)))
            if action == .accept, let supplyStationID {
                // MC7-30-6: MP supplyStationConfirmation shows the frozen station and its lock note before the accept.
                LabeledContent {
                    if let supplyStationName, !supplyStationName.isEmpty { Text(verbatim: supplyStationName) }
                    else { Text("merchantCoop.station.fallback \(supplyStationID)") }
                } label: { Text("merchantCoop.station.label") }
                    .accessibilityIdentifier("coopflow.supplyStation")
                Text("merchantCoop.station.note.beforeAccept").cyText(.meta).foregroundStyle(CYColor.textSecondary)
            }
            TextField("coopflow.field.reason", text: $reason, axis: .vertical)
                .onChange(of: reason) { _, value in if value.count > 100 { reason = String(value.prefix(100)) } }
            Text(verbatim: "\(reason.count) / 100").font(.caption).foregroundStyle(.secondary).accessibilityLabel(Text("a11y.value.characters \(Int(reason.count)) \(Int(100))"))
            // Source invite-detail: accepting takes an optional note; declining, withdrawing and cancelling need a reason.
            if action == .cancel && currentStatus == 1 { Text("coopflow.cancel.reason") }
            else if action == .reject { Text("cooperation.detail.reject.reasonRequired") }
            else if action == .cancel { Text("cooperation.detail.withdraw.reasonRequired") }
            if supplyStationID != nil, action == .accept {
                stationStatus
            } else if action == .accept || !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button("coopflow.reviewAction") {
                    confirmHandle = true
                }
            }
            Text("coopflow.contract.notice")
            CoopFlowSafetyNotice()
        }
        .navigationTitle("coopflow.reviewAction").navigationBarTitleDisplayMode(.inline)
        .cyModalConfirm(
            isPresented: confirmHandle,
            title: modalTitle,
            message: modalMessage,
            cancelTitle: MerchantAreaCopy.text("再想想", "Reconsider", locale),
            confirmTitle: action == .cancel && currentStatus == 1
                ? MerchantAreaCopy.text("提交取消", "Confirm cancel", locale)
                : action == .reject
                    ? MerchantAreaCopy.text("确认拒绝", "Decline", locale)
                    : MerchantAreaCopy.confirm(locale),
            isDestructive: action != .accept,
            onCancel: { confirmHandle = false },
            onConfirm: {
                confirmHandle = false
                if let supplyStationID, action == .accept {
                    Task { await submitStation(supplyStationID) }
                } else {
                    proceedPreview = true
                }
            }
        )
        .navigationDestination(isPresented: $proceedPreview) {
            CoopFlowRequestPreview(operation: .handle(inviteID: inviteID, action: action, reason: reason),
                                   cancelsAcceptedCooperation: action == .cancel && currentStatus == 1)
        }
        .clubIslandStatus(verbatimMessage: $toastMessage, surface: "coop-flow")
    }

    /// MC7-30-6 status rows for a station accept: sent / unknown / failed copy, or the one review button.
    @ViewBuilder private var stationStatus: some View {
        switch stationOutcome {
        case .sent:
            Label("coopflow.submit.sent", systemImage: "checkmark.circle.fill").foregroundStyle(CYColor.successText)
                .accessibilityIdentifier("coopflow.stationAccept.sent")
            Button("coopflow.submit.done") { dismiss() }.frame(minHeight: CYSpacing.minTouchTarget)
        case .unknown:
            Label("coopflow.submit.unknown", systemImage: "questionmark.circle").foregroundStyle(CYColor.warningText)
                .accessibilityIdentifier("coopflow.stationAccept.unknown")
        default:
            // MC8-32-5: only the gated sender may confirm. Without it the page shows the same disabled 暂不可提交 +
            // gated note as CoopFlowRequestPreview, instead of a live 确认 that falls to the dormant flow reader.
            if stationSender != nil {
                Button { confirmHandle = true } label: {
                    HStack { Text("coopflow.reviewAction"); if stationOutcome == .sending { Spacer(); ProgressView() } }
                        .frame(minHeight: CYSpacing.minTouchTarget)
                }
                .disabled(stationOutcome == .sending)
                .accessibilityIdentifier("coopflow.stationAccept.submit")
                if case .failed(let message) = stationOutcome {
                    Group { if let message { Text(verbatim: message) } else { Text("coopflow.submit.failed") } }
                        .cyText(.meta).foregroundStyle(CYColor.dangerText)
                }
            } else {
                Button("coopflow.reviewAction") {}.disabled(true).accessibilityIdentifier("coopflow.stationAccept.disabled")
                Text("coopflow.submit.gated").cyText(.meta).foregroundStyle(CYColor.textSecondary)
            }
        }
    }

    /// Station accept (`CoopFlowPreviewWriteFactory.stationAccept`), the same per-op `.handle` approval as the
    /// generic accept. Nil where that write is closed, so the send falls to `flowReader`.
    private var stationSender: ((_ inviteID: Int, _ reason: String?, _ stationID: Int) async throws -> CoopFlowJSON)? {
        write?.stationAccept()
    }

    /// Station accept uses `acceptSupplyStation` after the name is shown and the confirm is accepted.
    /// The 3-argument `.handle` path is the one without a station.
    private func submitStation(_ stationID: Int) async {
        guard stationOutcome != .sending else { return }
        stationOutcome = .sending
        let note = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            if let send = stationSender {
                _ = try await send(inviteID, note.isEmpty ? nil : note, stationID)
            } else {
                guard let flowReader else { throw CoopFlowFailure.disabled }
                _ = try await flowReader.acceptSupplyStation(inviteID: inviteID, reason: note.isEmpty ? nil : note, supplyStationID: stationID)
            }
            stationOutcome = .sent
        } catch CoopFlowFailure.server(_, let message) { stationOutcome = .failed(message) }
        catch CoopFlowFailure.inactiveMerchant(_, let message) { stationOutcome = .failed(message) }
        catch CoopFlowFailure.ambiguous { stationOutcome = .unknown }
        catch {
            stationOutcome = .failed(nil)
            toastMessage = MerchantAreaCopy.text("接受未发送", "Acceptance was not sent", locale)
        }
    }
}
/// Context is supplied only by a current, approved merchant chapter application.
struct CoopCircleSupplyDraft: Equatable {
    var name = "", price = "", duration = "", hours = "", minPeople = "1", maxPeople = "1"
    var kind: CoopFlowCircleSupplyProfile.SupplyKind = .service
    var split = false
    var action: CoopFlowCircleSupplyProfile.ActionType = .navigate
    var actionValue = "", benefit = "", benefitRules = "", merchantRules = ""
    var profile: CoopFlowCircleSupplyProfile? {
        guard price.range(of: #"^[0-9]+(?:\.[0-9]+)?$"#, options: .regularExpression) != nil,
              let price = Decimal(string: price, locale: Locale(identifier: "en_US_POSIX")),
              let duration = Int(duration), let min = Int(minPeople), let max = Int(maxPeople) else { return nil }
        return try? .init(supplyName: name, supplyKind: kind, regularPrice: price, durationMinutes: duration,
            availableHours: hours, minPeople: min, maxPeople: max, splitBookingAllowed: split,
            actionType: action, actionValue: actionValue, optionalBenefit: benefit, benefitRules: benefitRules, merchantRules: merchantRules)
    }
}

struct CoopFlowOfferEditor: View {
    let context: CoopFlowOfferContext
    let eligibleTemplates: [CoopFlowJSON]
    var circleMode = false
    var sourceIsCurrent: () -> Bool = { true }
    @State private var circle = CoopCircleSupplyDraft()
    @State private var selectedTemplate = 0
    @State private var quota = ""
    @State private var fee = ""
    private var draft: CoopFlowOfferDraft? {
        guard sourceIsCurrent(), !circleMode || circle.profile != nil else { return nil }
        let profile = circleMode ? circle.profile : nil
        switch context.termsMode {
        case .traffic: return try? CoopFlowOfferDraft(context: context, circleSupplyProfile: profile)
        case .perk:
            guard eligibleTemplates.contains(where: { $0["id"].integer == selectedTemplate && (CoopFlowMoney($0["retailValue"]).amount ?? 0) > 0 && ($0["quota"].integer ?? 0) > 0 }) else { return nil }
            return try? CoopFlowOfferDraft(context: context, templateID: selectedTemplate, quota: Int(quota), circleSupplyProfile: profile)
        case .revshare: return try? CoopFlowOfferDraft(context: context, perHeadFee: Decimal(string: fee, locale: Locale(identifier: "en_US_POSIX")), circleSupplyProfile: profile)
        }
    }
    var body: some View {
        Form {
            LabeledContent("coopflow.field.chapterId", value: String(context.chapterID))
            LabeledContent("coopflow.field.termsMode", value: context.termsMode.rawValue)
            if circleMode { circleFields }
            if context.termsMode == .perk {
                Picker("coopflow.templates", selection: $selectedTemplate) {
                    Text("coopflow.choose").tag(0)
                    ForEach(Array(eligibleTemplates.enumerated()), id: \.offset) { _, row in
                        if let id = row["id"].integer, (CoopFlowMoney(row["retailValue"]).amount ?? 0) > 0, (row["quota"].integer ?? 0) > 0 {
                            Text(row["name"].text ?? String(id)).tag(id)
                        }
                    }
                }
                TextField("coopflow.field.quotaTotal", text: $quota).keyboardType(.numberPad)
            }
            if context.termsMode == .revshare { TextField("coopflow.field.perHeadFee", text: $fee).keyboardType(.decimalPad) }
            if let draft { NavigationLink("coopflow.reviewAction") {
                if sourceIsCurrent() { CoopFlowRequestPreview(operation: draft.mutation) }
                else { Text("coopflow.invalid") }
            } }
            if circleMode && circle.profile == nil { Text("coopflow.circle.complete") }
            Text("coopflow.offer.rules")
            CoopFlowSafetyNotice()
        }.disabled(!sourceIsCurrent()).navigationTitle("coopflow.offer.title").navigationBarTitleDisplayMode(.inline)
    }
    @ViewBuilder private var circleFields: some View {
        Section("coopflow.circle.title") {
            TextField("coopflow.circle.name", text: $circle.name)
            Picker("coopflow.circle.kind", selection: $circle.kind) {
                ForEach(CoopFlowCircleSupplyProfile.SupplyKind.allCases, id: \.rawValue) { value in Text(LocalizedStringKey("coopflow.circle.kind." + value.rawValue)).tag(value) }
            }
            TextField("coopflow.circle.price", text: $circle.price).keyboardType(.decimalPad)
            TextField("coopflow.circle.duration", text: $circle.duration).keyboardType(.numberPad)
            TextField("coopflow.circle.hours", text: $circle.hours)
            TextField("coopflow.circle.minPeople", text: $circle.minPeople).keyboardType(.numberPad)
            TextField("coopflow.circle.maxPeople", text: $circle.maxPeople).keyboardType(.numberPad)
            Toggle("coopflow.circle.split", isOn: $circle.split)
            Picker("coopflow.circle.action", selection: $circle.action) {
                ForEach(CoopFlowCircleSupplyProfile.ActionType.allCases, id: \.rawValue) { value in Text(LocalizedStringKey("coopflow.circle.action." + value.rawValue)).tag(value) }
            }
            TextField("coopflow.circle.actionValue", text: $circle.actionValue)
            TextField("coopflow.circle.benefit", text: $circle.benefit)
            TextField("coopflow.circle.benefitRules", text: $circle.benefitRules, axis: .vertical)
            TextField("coopflow.circle.merchantRules", text: $circle.merchantRules, axis: .vertical)
            Text("coopflow.circle.localOnly").font(.footnote)
        }
    }

}
/// A bounded composition sheet; the immutable local review pushes within this same stack.
@MainActor struct CoopFlowInviteEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    let reader: any CoopFlowReading
    let context: CoopFlowInvitationContext
    @State private var message = ""
    @State private var fixed = false
    @State private var fee = ""
    @State private var confirmDiscard = false
    private enum Field: Hashable { case message, fee }
    @FocusState private var focusedField: Field?
    private var hasDraft: Bool { !message.isEmpty || fixed || !fee.isEmpty }
    private var draft: CoopFlowInvitation? {
        let compensation: CoopFlowCompensation
        if fixed {
            guard let amount = Decimal(string: fee, locale: Locale(identifier: "en_US_POSIX")) else { return nil }
            compensation = .fixed(amount)
        } else { compensation = .traffic }
        return try? context.invitation(message: message, compensation: compensation, currentSession: reader.session)
    }
    var body: some View {
        Group {
            if reader.session == context.session {
                Form {
                    LabeledContent("coopflow.field.toId", value: context.recipientName.isEmpty ? appLocalized("coopflow.unnamed", locale: locale) : context.recipientName)
                    LabeledContent("coopflow.field.toType", value: appLocalized(context.kind == .club ? "coopflow.invite.club" : "context.coop.merchant", locale: locale))
                    LabeledContent("coopflow.field.topicId", value: String(context.topicID))
                    TextField("coopflow.field.message", text: $message, axis: .vertical)
                        .focused($focusedField, equals: .message).accessibilityIdentifier("coopflow.invite.message")
                    Toggle("coopflow.fixed", isOn: $fixed)
                    if fixed {
                        TextField("coopflow.field.fixedFee", text: $fee).keyboardType(.decimalPad).focused($focusedField, equals: .fee)
                        Text("coopflow.currency")
                    }
                    if let draft {
                        NavigationLink("coopflow.reviewAction") { CoopFlowRequestPreview(operation: .invite(draft), invitationContext: context, currentSession: reader.session) }
                            .accessibilityIdentifier("coopflow.invite.review")
                    }
                    Text("coopflow.invite.rules")
                    CoopFlowSafetyNotice()
                }.scrollDismissesKeyboard(.interactively)
            } else { Text("coopflow.invite.sessionChanged") }
        }
        .cyGroupedSurface()
        .navigationTitle("coopflow.invite.title").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("coopflow.invite.cancel") {
                    focusedField = nil
                    if hasDraft { confirmDiscard = true } else { dismiss() }
                }.accessibilityIdentifier("coopflow.invite.cancel")
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer(); Button("coopflow.invite.done") { focusedField = nil }
            }
        }
        .interactiveDismissDisabled(hasDraft)
        .cyModalConfirm(
            isPresented: confirmDiscard,
            title: appLocalized("coopflow.invite.discardPrompt", locale: locale),
            cancelTitle: appLocalized("coopflow.invite.keepEditing", locale: locale),
            confirmTitle: appLocalized("coopflow.invite.discard", locale: locale),
            isDestructive: true,
            onCancel: { confirmDiscard = false },
            onConfirm: {
                confirmDiscard = false
                dismiss()
            }
        )
        .onChange(of: reader.session) { _, _ in
            message = ""; fee = ""; fixed = false; focusedField = nil; dismiss()
        }
    }
}
struct CoopFlowReviewEditor: View {
    let topicID: Int
    let memberID: Int
    let partnerName: String
    @State private var rating = 5
    @State private var comment = ""
    var body: some View {
        Form {
            Text(partnerName).font(.headline)
            Stepper("\(rating) / 5", value: $rating, in: 1...5).accessibilityLabel("coopflow.field.rating").accessibilityValue(Text("a11y.value.ofTotal \(rating) \(5)"))
            TextField("coopflow.field.comment", text: $comment, axis: .vertical)
            NavigationLink("coopflow.reviewAction") {
                CoopFlowRequestPreview(operation: .review(topicID: topicID, memberID: memberID, rating: rating, comment: comment))
            }
            CoopFlowSafetyNotice()
        }.navigationTitle("coopflow.reviews").navigationBarTitleDisplayMode(.inline)
    }
}

@MainActor struct CoopFlowPerkPicker: View {
    let reader: any CoopFlowReading
    let inviteID: Int
    private struct Host: Hashable { let reader: ObjectIdentifier; let inviteID: Int }
    var body: some View {
        CoopFlowPerkPickerContent(reader: reader, inviteID: inviteID)
            .id(Host(reader: ObjectIdentifier(reader), inviteID: inviteID))
    }
}
@MainActor private struct CoopFlowPerkPickerContent: View {
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    let reader: any CoopFlowReading
    let inviteID: Int
    @StateObject private var model: CoopPerkPickerReadModel
    init(reader: any CoopFlowReading, inviteID: Int) {
        self.reader = reader; self.inviteID = inviteID
        _model = StateObject(wrappedValue: CoopPerkPickerReadModel(reader: reader, inviteID: inviteID))
    }
    var body: some View {
        let permit = model.permit
        List {
            if model.isCurrent {
                ForEach(Array(model.rows.enumerated()), id: \.offset) { _, row in
                    if let id = row["id"].integer {
                        Toggle(isOn: model.selectionBinding(id: id, permit: permit)) {
                            Text(row["name"].text ?? appLocalized("coopflow.unnamed", locale: locale))
                        }.disabled(!model.canSelect(id: id, permit: permit))
                    }
                }
                if model.rows.isEmpty { Text("coopflow.empty") }
                if !model.selected.isEmpty {
                    Button("coopflow.reviewAction") { model.openPreview(permit: permit) }
                        .accessibilityIdentifier("coopflow.perks.preview")
                }
            } else if model.failed {
                Text("coopflow.read.failed")
                CYPillButton("cooperation.retry", style: .secondary, fullWidth: false) { Task { await model.load(permit: permit) } }
                    .accessibilityIdentifier("coopflow.perks.retry")
            } else if reader.session == nil { Text("cooperation.login") }
            else { CYSkeleton(variant: .row, label: "cooperation.loading") }
            CoopFlowSafetyNotice()
        }.navigationTitle("coopflow.attach").navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: model.previewBinding()) { preview in
                if model.current(preview) {
                    CoopFlowRequestPreview(operation: .attachPerks(inviteID: preview.inviteID, templateIDs: preview.templateIDs))
                } else { Text("coopflow.invalid") }
            }
            .onAppear {
                model.appear(active: scenePhase == .active)
                let captured = model.permit
                Task { await model.loadForAppearance(permit: captured) }
            }
            .onDisappear { model.disappear() }
            .onChange(of: reader.session) { _, _ in
                model.identityChanged()
                let captured = model.permit
                Task { await model.loadForAppearance(permit: captured) }
            }
            .onChange(of: scenePhase) { _, phase in
                model.sceneChanged(active: phase == .active)
                let captured = model.permit
                if phase == .active { Task { await model.loadForAppearance(permit: captured) } }
            }
    }
}

@MainActor final class CoopPerkPickerReadModel: ObservableObject {
    struct Preview: Identifiable, Hashable {
        nonisolated let id = UUID()
        let inviteID: Int
        let templateIDs: [Int]
        fileprivate let readID: UUID
        fileprivate let session: CoopFlowSession
        nonisolated static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
        nonisolated func hash(into hasher: inout Hasher) { hasher.combine(id) }
    }
    let reader: any CoopFlowReading
    let inviteID: Int
    @Published private(set) var rows: [CoopFlowJSON] = []
    @Published private(set) var selected: Set<Int> = []
    @Published private(set) var failed = false
    @Published private(set) var loading = false
    @Published private(set) var preview: Preview?
    @Published private(set) var showingPreview = false
    private(set) var permit = UUID()
    private var visible = false, active = false
    private var loadedSession: CoopFlowSession?
    private var readID = UUID()
    init(reader: any CoopFlowReading, inviteID: Int) { self.reader = reader; self.inviteID = inviteID }
    var isCurrent: Bool { loadedSession != nil && loadedSession == reader.session && !loading && !failed }
    func appear(active: Bool) { visible = true; self.active = active; if !active { retire() } }
    func disappear() {
        visible = false
        if preview == nil { retire() }
    }
    func sceneChanged(active: Bool) { self.active = visible && active; if !self.active { retire() } }
    func identityChanged() { retire() }
    private func retire() {
        permit = UUID(); readID = UUID(); loadedSession = nil
        rows = []; selected = []; preview = nil; showingPreview = false; failed = false; loading = false
    }
    func loadForAppearance(permit expected: UUID) async {
        guard visible, active, expected == permit, !Task.isCancelled else { return }
        if let preview, current(preview) {
            self.preview = nil; showingPreview = false
            permit = UUID()
            return
        }
        if !isCurrent { await load(permit: expected) }
    }
    func load(permit expected: UUID) async {
        guard visible, active, expected == permit, inviteID > 0, !loading, !Task.isCancelled else { return }
        retire()
        guard let session = reader.session else { return }
        let request = readID; loading = true
        defer { if request == readID { loading = false } }
        do {
            let result = try await reader.read(.templates)
            guard !Task.isCancelled, request == readID, visible, active, reader.session == session else { return }
            guard let values = result.rows else { throw APIError.invalidRequest }
            rows = values.filter { (CoopFlowMoney($0["retailValue"]).amount ?? 0) > 0 && ($0["quota"].integer ?? 0) > 0 }
            loadedSession = session
        } catch {
            guard !Task.isCancelled, request == readID, visible, active, reader.session == session else { return }
            rows = []; selected = []; loadedSession = nil; failed = true
        }
    }
    func canSelect(id: Int, permit expected: UUID) -> Bool {
        visible && active && isCurrent && preview == nil && expected == permit && id > 0 && rows.filter { $0["id"].integer == id }.count == 1
    }
    func selectionBinding(id: Int, permit expected: UUID) -> Binding<Bool> {
        Binding(get: { self.canSelect(id: id, permit: expected) && self.selected.contains(id) }, set: { value in
            guard self.canSelect(id: id, permit: expected) else { return }
            if value { self.selected.insert(id) } else { self.selected.remove(id) }
        })
    }
    func openPreview(permit expected: UUID) {
        guard visible, active, isCurrent, preview == nil, expected == permit, !selected.isEmpty,
              selected.allSatisfy({ canSelect(id: $0, permit: expected) }), let loadedSession else { return }
        preview = Preview(inviteID: inviteID, templateIDs: selected.sorted(), readID: readID, session: loadedSession)
        showingPreview = true
    }
    func current(_ expected: Preview) -> Bool {
        preview?.id == expected.id && readID == expected.readID && isCurrent && active &&
            loadedSession == expected.session && inviteID == expected.inviteID && selected.sorted() == expected.templateIDs
    }
    func previewBinding() -> Binding<Preview?> {
        let original = preview
        return Binding(get: {
            guard let original, self.showingPreview, self.current(original) else { return nil }
            return original
        }, set: { value in
            guard value == nil, let original, self.current(original) else { return }
            self.showingPreview = false
        })
    }
}
struct CoopFlowSupplyManagementView: View {
    let context: CoopFlowOfferContext
    /// Provided by fresh MerchantContent application + chapter matching, not inferred from an offer ID.
    let canManageCircleSupply: Bool
    var body: some View {
        List {
            LabeledContent("coopflow.field.chapterId", value: String(context.chapterID))
            if canManageCircleSupply, let id = context.offerID {
                NavigationLink("coopflow.reconfirm") { CoopFlowRequestPreview(operation: .reconfirmOffer(id: id)) }
                NavigationLink("coopflow.pause") { CoopFlowRequestPreview(operation: .pauseOffer(id: id)) }
            }
            Text("coopflow.offer.rules")
            CoopFlowSafetyNotice()
        }.navigationTitle("coopflow.supply").navigationBarTitleDisplayMode(.inline)
        .cyDomainScreen(.merchant)
    }
}

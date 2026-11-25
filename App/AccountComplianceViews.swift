import SwiftUI

@MainActor final class ComplianceViewModel: ObservableObject {
    @Published var state: ComplianceState
    let coordinator: AccountComplianceCoordinator
    private let cancellationPresentation: AccountDeregistrationPresentation?
    private let marketingPresentation: AccountMarketingPresentation?
    private var ended = false
    init(_ coordinator: AccountComplianceCoordinator, isDeregistration: Bool = false, isMarketing: Bool = false) {
        self.coordinator = coordinator
        cancellationPresentation = isDeregistration ? coordinator.beginDeregistrationPresentation() : nil
        marketingPresentation = !isDeregistration && isMarketing ? coordinator.beginMarketingPresentation() : nil
        state = coordinator.state
        coordinator.onChange = { [weak self] value in
            guard let self else { return }
            if let lease = self.cancellationPresentation, !self.coordinator.ownsDeregistrationPresentation(lease) {
                self.state = .init()
            } else if let lease = self.marketingPresentation, !self.coordinator.ownsMarketingPresentation(lease) {
                self.state = .init()
            } else { self.state = value }
        }
    }
    func cancellationIntent(resume: Bool = false) -> AccountDeregistrationIntent? {
        guard !ended, !Task.isCancelled, let lease = cancellationPresentation else { return nil }
        if resume, !coordinator.resumeDeregistrationPresentation(lease) { state = .init(); state.error = "compliance.unavailable"; return nil }
        return coordinator.captureDeregistrationIntent(lease)
    }
    func pauseCancellation() {
        guard let lease = cancellationPresentation else { return }
        coordinator.pauseDeregistrationPresentation(lease); state = .init()
    }
    func marketingRead(resume: Bool = false) -> AccountMarketingReadIntent? {
        guard !ended, !Task.isCancelled, let lease = marketingPresentation else { return nil }
        if resume, !coordinator.resumeMarketingPresentation(lease) { state = .init(); state.error = "compliance.unavailable"; return nil }
        return coordinator.captureMarketingRead(lease)
    }
    func pauseMarketing() {
        guard let lease = marketingPresentation else { return }
        coordinator.pauseMarketingPresentation(lease); state = .init()
    }
    func endPresentation() {
        ended = true
        if cancellationPresentation != nil { pauseCancellation() }
        else if marketingPresentation != nil { pauseMarketing() }
        else { coordinator.invalidate() }
    }
    private var contractApplyRequestID = UUID().uuidString.lowercased()
    private var contractSMSSentAt: Date?
    private var contractSMSCode: String?

    func rememberContractCode(_ code: String) { contractSMSCode = code }

    func precheckOnContract(documentRead: Bool, explicitAgreement: Bool, expectedConsentVersion: String?, intent: AccountDeregistrationIntent) async {
        guard AccountPublishContractLane.isInstalled else {
            await coordinator.precheckAndAgree(documentRead: documentRead, explicitAgreement: explicitAgreement, expectedConsentVersion: expectedConsentVersion, recordConsent: false, intent: intent)
            return
        }
        guard let baseURL = AccountPublishContractLane.baseURL, coordinator.beginContractWrite(intent: intent) else { return }
        defer { coordinator.endContractWrite() }
        do {
            let request = try AccountPublishMPContract.deregisterPrecheckRequest(baseURL: baseURL, token: AccountPublishContractLane.token)
            let (data, _) = try await AccountPublishContractLane.send(request)
            guard let precheck = AccountPublishMPContract.deregisterPrecheck(from: data) else { return }
            coordinator.adoptContractPrecheck(precheck, documentRead: documentRead, explicitAgreement: explicitAgreement, intent: intent)
        } catch {}
    }

    func sendBoundSMSOnContract(intent: AccountDeregistrationIntent) async {
        guard AccountPublishContractLane.isInstalled else {
            await coordinator.sendBoundPhoneSMS(explicitlyRequested: true, intent: intent)
            return
        }
        if state.smsSent, let sent = contractSMSSentAt, Date().timeIntervalSince(sent) < 60 { return }
        guard coordinator.beginContractWrite(intent: intent) else { return }
        defer { coordinator.endContractWrite() }
        do {
            let (data, _) = try await AccountPublishContractLane.userInfo()
            guard let phone = AccountPublishMPContract.deregisterPhone(from: data) else {
                coordinator.adoptContractBoundSMS(phone: nil, intent: intent)
                return
            }
            guard let baseURL = AccountPublishContractLane.baseURL else { return }
            let request = try AccountPublishMPContract.smsSendRequest(baseURL: baseURL, phone: phone, token: AccountPublishContractLane.token)
            _ = try await AccountPublishContractLane.send(request)
            contractSMSSentAt = Date()
            coordinator.adoptContractBoundSMS(phone: phone, now: contractSMSSentAt ?? Date(), intent: intent)
        } catch {}
    }

    func applyOnContract(recordNoticeConsent: Bool, expectedConsentVersion: String?, intent: AccountDeregistrationIntent) async {
        guard AccountPublishContractLane.isInstalled else {
            await coordinator.apply(explicitlyConfirmed: true, recordNoticeConsent: recordNoticeConsent, expectedConsentVersion: expectedConsentVersion, intent: intent)
            return
        }
        guard coordinator.beginContractWrite(intent: intent) else { return }
        defer { coordinator.endContractWrite() }
        let consented = await coordinator.prepareContractApplyConsent(recordNoticeConsent: recordNoticeConsent, expectedConsentVersion: expectedConsentVersion, intent: intent)
        guard consented, let baseURL = AccountPublishContractLane.baseURL else { return }
        do {
            let request = try AccountPublishMPContract.deregisterApplyRequest(baseURL: baseURL, requestID: contractApplyRequestID, smsCode: contractSMSCode, token: AccountPublishContractLane.token)
            let (data, _) = try await AccountPublishContractLane.send(request)
            await coordinator.adoptContractApply(AccountPublishMPContract.deregisterApply(from: data), intent: intent)
        } catch {
            await coordinator.adoptContractApply(nil, intent: intent)
        }
    }

    func cancelOnContract(intent: AccountDeregistrationIntent) async {
        guard AccountPublishContractLane.isInstalled else {
            await coordinator.cancel(explicitlyConfirmed: true, intent: intent)
            return
        }
        guard let baseURL = AccountPublishContractLane.baseURL, coordinator.beginContractWrite(intent: intent) else { return }
        defer { coordinator.endContractWrite() }
        do {
            let request = try AccountPublishMPContract.deregisterCancelRequest(baseURL: baseURL, token: AccountPublishContractLane.token)
            let (data, _) = try await AccountPublishContractLane.send(request)
            coordinator.adoptContractCancel(cancelled: AccountPublishMPContract.deregisterCancel(from: data) == "CANCELLED", intent: intent)
        } catch {
            coordinator.adoptContractCancel(cancelled: false, intent: intent)
        }
    }
}
/// Add to Settings Form with an injected coordinator; sheet dismissal never retries a write.
@MainActor struct AccountComplianceSettingsSection: View {
    let makeCoordinator: () -> AccountComplianceCoordinator
    let market: RegionalMarket?
    let legalReader: any SettingsLegalReading
    var showsNPCChatDataEntry = true
    @State private var selected: ComplianceDestination?
    @State private var npcChatData: NPCChatDataPresentation?
    var body: some View {
        Section {
            ForEach(ComplianceDestination.allCases.filter { $0 != .cancellation }) { destination in
                if destination == .marketing {
                    NavigationLink {
                        AccountComplianceSheet(coordinator: makeCoordinator(), destination: destination,
                            market: market, legalReader: legalReader, showsCloseButton: false)
                    } label: {
                        // MP shezhi 营销消息与优惠券 = icon_lc_ticket.
                        Label { Text(LocalizedStringKey(destination.title)) } icon: { AccountPublishMPGlyph(MPAsset.FeatureIcon.iconLcTicket) }
                            .environment(\.settingsTileTint, SettingsTint.orange)
                    }
                    .accessibilityIdentifier("compliance.open.\(destination.rawValue)")
                } else {
                    Button { selected = destination } label: {
                        HStack { Label(LocalizedStringKey(destination.title), systemImage: "location.fill").environment(\.settingsTileTint, SettingsTint.green)
                            Spacer(minLength: 0); Image(systemName: "chevron.right").cyText(.meta, weight: .semibold).foregroundStyle(.tertiary) }
                    }
                    .foregroundStyle(CYColor.textPrimary)
                    .accessibilityIdentifier("compliance.open.\(destination.rawValue)")
                }
            }
            if showsNPCChatDataEntry {
                Button { npcChatData = .init(coordinator: makeCoordinator().makeNPCChatDataCoordinator()) } label: {
                    Label { Text("npcData.title") } icon: { AccountPublishMPGlyph(MPAsset.FeatureIcon.iconLcMessageSquareText) }
                        .environment(\.settingsTileTint, SettingsTint.indigo)
                }
                .foregroundStyle(CYColor.textPrimary)
                .accessibilityIdentifier("npcData.open")
            }
        } header: { Text("compliance.title") } footer: { Text("settings.privacy.footer") }
        // Destructive row: its own section, red, with the consequence stated underneath.
        Section {
            Button(role: .destructive) { selected = .cancellation } label: {
                Label { Text(LocalizedStringKey(ComplianceDestination.cancellation.title)).foregroundStyle(CYColor.dangerText) }
                    icon: { AccountPublishMPGlyph(MPAsset.FeatureIcon.iconLcUserRoundX) }
                    .environment(\.settingsTileTint, SettingsTint.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityIdentifier("compliance.open.\(ComplianceDestination.cancellation.rawValue)")
        } footer: { Text("settings.danger.footer") }
        .sheet(item: $selected) { destination in Group {
            NavigationStack {
                AccountComplianceSheet(coordinator: makeCoordinator(), destination: destination, market: market, legalReader: legalReader)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        }
        .sheet(item: $npcChatData) { presentation in Group { NPCChatDataView(coordinator: presentation.coordinator) }.presentationDetents([.large]).presentationDragIndicator(.visible) }
    }
}
/// B-DR-07: the compliance sheet in its own navigation stack, shared by the Settings row and the Settings search result.
@MainActor struct AccountComplianceSheetStack: View {
    let coordinator: AccountComplianceCoordinator
    let destination: ComplianceDestination
    let market: RegionalMarket?
    let legalReader: any SettingsLegalReading
    var body: some View {
        NavigationStack {
            AccountComplianceSheet(coordinator: coordinator, destination: destination, market: market, legalReader: legalReader)
        }
    }
}
enum ComplianceDestination: String, CaseIterable, Identifiable {
    case roam, marketing, cancellation
    var id: String { rawValue }
    var title: String { "compliance.\(rawValue)" }
}
@MainActor struct AccountComplianceSheet: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    @Environment(\.offlineWriteSession) private var offlineWriteSession
    @StateObject private var model: ComplianceViewModel
    let destination: ComplianceDestination
    let market: RegionalMarket?
    let legalReader: any SettingsLegalReading
    let showsCloseButton: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var agreement = false
    @State private var document: SettingsLegalDocument?
    @State private var code = ""
    @State private var cancelReview = false
    @State private var cancelIntent: AccountDeregistrationIntent?
    @State private var marketingChange: ComplianceMarketingReview?
    @State private var toastMessage: LocalizedStringKey?
    @State private var toastTone: CYToastTone = .info
    init(coordinator: AccountComplianceCoordinator, destination: ComplianceDestination, market: RegionalMarket?, legalReader: any SettingsLegalReading, showsCloseButton: Bool = true) {
        _model = StateObject(wrappedValue: ComplianceViewModel(coordinator, isDeregistration: destination == .cancellation, isMarketing: destination == .marketing)); self.destination = destination; self.market = market; self.legalReader = legalReader
        self.showsCloseButton = showsCloseButton
    }
#if DEBUG
    /// Design fixtures only: mounts this real view on a view model whose state was stubbed by the host.
    private(set) var designMode = false
    init(designModel: ComplianceViewModel, destination: ComplianceDestination, market: RegionalMarket?, legalReader: any SettingsLegalReading,
         document: SettingsLegalDocument? = nil) {
        _model = StateObject(wrappedValue: designModel); self.destination = destination; self.market = market; self.legalReader = legalReader
        showsCloseButton = false; designMode = true; _document = State(initialValue: document)
    }
#endif
    var body: some View {
        Form {
            // B-MK-02: MP marketing/index.wxml:6 is the title and the merchant list, with no intro block.
            if destination != .marketing {
                Section {
                    ComplianceHeader(destination: destination, step: model.state.step)
                        .listRowInsets(EdgeInsets(top: CYSpacing.md, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.sm, trailing: CYSpacing.pageHorizontal))
                        .listRowBackground(Color.clear)
                }
            }
            if model.state.busy {
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    CYSkeleton()
                    // B-DR-09-r7: the MP names what is loading (正在核验注销条件) on the deregister page.
                    if destination == .cancellation, model.state.status == nil {
                        Text("fixr3.deregister.loading").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    }
                }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("compliance.loading")
                    .accessibilityLabel(Text(LocalizedStringKey(destination == .cancellation && model.state.status == nil ? "fixr3.deregister.loading" : "compliance.loading")))
                    .listRowBackground(Color.clear)
            }
            // B-DR-03: the missing-bound-phone message shows inline under 获取验证码, not twice.
            if let error = model.state.error, error != DeregistrationBoundPhone.missingMessage {
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    // B-DR-09-r7: a failed condition read is titled 注销条件核验失败, as in the MP.
                    if destination == .cancellation, model.state.status == nil {
                        Text("fixr3.deregister.readFailed").cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary)
                    }
                    Text(LocalizedStringKey(error), tableName: error == "compliance.impactChanged" ? "AccountDeregistrationPresentation" : nil)
                        .foregroundStyle(CYColor.dangerText).accessibilityIdentifier("compliance.error")
                }
            }
            switch destination {
            case .cancellation: cancellation
            case .roam: roam
            case .marketing: marketing
            }
        }
        .themeDomain(.player)
        // B-MK-03 / B-DR-05 (T&C §2): one inline system title, pushed or in its sheet's navigation stack;
        // the in-content 34 pt title is gone.
        .cyPageTitle(String.LocalizationValue(destination.title))
        .toolbar {
            if showsCloseButton {
                ToolbarItem(placement: .cancellationAction) {
                    Button("compliance.close") { code = ""; dismiss() }
                }
            }
        }
        .disabled(model.state.busy)
        .interactiveDismissDisabled(model.state.busy)
        .task {
            if destination == .marketing, scenePhase == .active,
               let intent = model.marketingRead(resume: true) { await model.coordinator.loadMarketing(intent: intent) }
            if destination == .cancellation, scenePhase == .active,
               let intent = model.cancellationIntent(resume: true) { await loadCancellation(intent) }
        }
        .onDisappear {
            code = ""; agreement = false; cancelReview = false; cancelIntent = nil
            marketingChange = nil
            model.endPresentation()
        }
        .onChange(of: model.coordinator.deregistrationOriginalRevision) { _, _ in
            guard destination == .cancellation else { return }
            code = ""; agreement = false; cancelReview = false; cancelIntent = nil
            model.pauseCancellation()
        }
        .onChange(of: model.coordinator.marketingOriginalRevision) { _, _ in
            guard destination == .marketing else { return }
            marketingChange = nil; model.pauseMarketing()
        }
        .onChange(of: scenePhase) { _, phase in
            if destination == .marketing {
                marketingChange = nil
                if phase != .active { model.pauseMarketing() }
                else if let intent = model.marketingRead(resume: true) { Task { await model.coordinator.loadMarketing(intent: intent) } }
                return
            }
            guard destination == .cancellation else { return }
            code = ""; agreement = false; cancelReview = false; cancelIntent = nil
            if phase != .active { model.pauseCancellation() }
            else if let intent = model.cancellationIntent(resume: true) { Task { await loadCancellation(intent) } }
        }
        .sheet(isPresented: $cancelReview) {
            if let intent = cancelIntent {
                MemberDeregistrationCancelConfirmSheet {
                    cancelReview = false
                    cancelIntent = nil
                    Task { await model.cancelOnContract(intent: intent) }
                }
                .themeDomain(.player)
            }
        }
        .onChange(of: cancelReview) { _, visible in if !visible { cancelIntent = nil } }
        .cyToast(message: $toastMessage, tone: toastTone)
    }
    private var designModeAllowsToggles: Bool {
#if DEBUG
        return designMode
#else
        return false
#endif
    }
    private func loadCancellation(_ intent: AccountDeregistrationIntent) async {
        guard model.coordinator.isCurrentDeregistrationIntent(intent) else { return }
        let availability = try? await legalReader.document(type: .cancellationNotice, market: market)
        guard model.coordinator.isCurrentDeregistrationIntent(intent), scenePhase == .active else { return }
        if case .sourceDocument(let value)? = availability { document = value } else { document = nil }
        await model.coordinator.load(intent: intent)
    }
    private func requestCancellationRead() {
        guard scenePhase == .active, let intent = model.cancellationIntent() else { return }
        cancelReview = false; cancelIntent = nil
        Task { await loadCancellation(intent) }
    }
    @ViewBuilder private var cancellation: some View {
        if let request = model.state.originalApplicationRequestID {
            Section {
                // B-DR-01: the request id is support detail, folded under 详情.
                DisclosureGroup {
                    (Text("c08.display.43", tableName: "AccountDeregistrationPresentation") + Text(verbatim: request)).cyText(.meta).textSelection(.enabled)
                } label: { Text("compliance.details").cyText(.meta) }
                if let receipt = model.state.originalApplication {
                    Text(receipt.outcome)
                    if receipt.reason == "ACCOUNT_IMPACT_CHANGED_REFRESH_AND_CONFIRM" { Text("c08.display.37", tableName: "AccountDeregistrationPresentation") }
                    if let impact = receipt.impactAtConfirmation { AccountDeregistrationImpactSection(impact: impact) }
                    if receipt.accepted {
                        Text("c08.display.44", tableName: "AccountDeregistrationPresentation")
                        if let applicationID = receipt.applicationId {
                            Text("c08.display.45", tableName: "AccountDeregistrationPresentation") + Text(verbatim: String(applicationID))
                        }
                    } else if receipt.settled {
                        Text("c08.display.38", tableName: "AccountDeregistrationPresentation")
                    } else { Text("c08.display.39", tableName: "AccountDeregistrationPresentation") }
                } else { Text("c08.display.40", tableName: "AccountDeregistrationPresentation") }
            } header: { Text("c08.display.36", tableName: "AccountDeregistrationPresentation") }
        }
        if let status = model.state.status {
            // B-DR-01: no impact list from the server shows nothing (the MP backend never sends one).
            if let impact = status.impact { AccountDeregistrationImpactSection(impact: impact) }
            Section("compliance.serverStatus") {
                statusMark(status.status).accessibilityIdentifier("compliance.serverStatus")
                if model.state.step != .blocked {
                    ForEach(Array(status.blockers.enumerated()), id: \.offset) { _, blocker in Text(blocker) }
                }
                if status.executeAfter != nil || status.pending {
                    DeregistrationExecuteAfterRow(raw: status.executeAfter, coolingOffEnded: model.coordinator.coolingOffHasPassed(now: Date()))
                }
            }
        }
        switch model.state.step {
        case .idle: EmptyView()
        case .blocked:
            // B-DR-02 (MP BLOCKED card): neutral title, 「请先处理以下事项：」, one row per blocker, and
            // 「我已处理，重新检查」 in place of the generic refresh.
            Section {
                Text("fixr3.deregister.blocked.lead").cyText(.body).foregroundStyle(CYColor.textPrimary)
                ForEach(Array((model.state.status?.blockers ?? []).enumerated()), id: \.offset) { _, blocker in
                    Label { Text(verbatim: blocker).cyText(.body) } icon: {
                        Image(systemName: "exclamationmark.circle").foregroundStyle(CYColor.warningText)
                    }
                    .accessibilityIdentifier("compliance.blocker")
                }
                Button { requestCancellationRead() } label: { Text("fixr3.deregister.blocked.recheck") }
                    .frame(minHeight: CYSpacing.minTouchTarget)
                    .accessibilityIdentifier("compliance.blocked.recheck")
            } header: { Text("fixr3.deregister.blocked.title") }
        case .notice:
            if model.state.status?.cancellationConfirmed == true {
                Text("compliance.cancellationConfirmed", tableName: "AccountDeregistrationPresentation").accessibilityIdentifier("compliance.cancellationConfirmed")
            }
            Section {
                if let document {
                    Text(document.title).cyText(.cardTitle)
                    Text(document.intro).cyText(.body)
                    ForEach(Array(document.sections.enumerated()), id: \.offset) { _, section in
                        Text(section.heading).cyText(.cardTitle); Text(section.body).cyText(.body)
                    }
                    // Source content stays exact; availability is not release approval.
                    Toggle("fixr3.deregister.agreeNotice", isOn: $agreement)
                        .disabled(!model.state.localCancellationConsent.allowsNewConsent)
                        .accessibilityIdentifier("compliance.agreeNotice")
                } else { Text("compliance.legalMissing") }
                Button("compliance.precheck") {
                    guard let intent = model.cancellationIntent() else { return }
                    let displayedVersion = document?.version
                    let documentWasRead = document != nil
                    let explicitlyAgreed = agreement
                    // B-DR-04: the notice step only reads the precheck; AGREE is recorded in apply(), after SMS (MP order).
                    Task { await model.precheckOnContract(documentRead: documentWasRead, explicitAgreement: explicitlyAgreed, expectedConsentVersion: displayedVersion, intent: intent) }
                }
                    .buttonStyle(.borderedProminent).controlSize(.large).buttonBorderShape(.capsule)
                    .disabled(document?.version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false
                        || !agreement || !model.state.localCancellationConsent.allowsNewConsent)
                    .accessibilityIdentifier("compliance.precheck")
            }
        case .verify:
            Section {
                // B-DR-03 (MP deregister-flow sendSms): the code goes to the account's bound phone, read from
                // `/api/user/info`; there is no number field. Core blocks a second send for 60 seconds.
                Button(LocalizedStringKey(model.state.smsSent ? "fixr3.deregister.resendSMS" : "fixr3.deregister.sendSMS")) {
                    guard let intent = model.cancellationIntent() else { return }
                    Task { await model.sendBoundSMSOnContract(intent: intent) }
                }
                    .buttonStyle(.bordered).buttonBorderShape(.capsule)
                    .frame(minHeight: CYSpacing.minTouchTarget)
                    .disabled(model.state.busy || !model.state.localCancellationConsent.allowsNewConsent).accessibilityIdentifier("compliance.sendSMS")
                if model.state.error == DeregistrationBoundPhone.missingMessage {
                    Text(verbatim: DeregistrationBoundPhone.missingMessage).cyText(.meta).foregroundStyle(CYColor.dangerText)
                        .accessibilityIdentifier("compliance.boundPhoneMissing")
                } else if let notice = model.state.smsNotice, model.state.smsSent {
                    Text(verbatim: notice).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                        .accessibilityIdentifier("compliance.smsSent")
                } else if model.state.smsSent { Text("compliance.smsSent").cyText(.meta).foregroundStyle(CYColor.textSecondary) }
                TextField("fixr3.deregister.code", text: $code).textContentType(.oneTimeCode).keyboardType(.numberPad).accessibilityIdentifier("compliance.code")
                Button("compliance.review") {
                    guard model.cancellationIntent() != nil else { return }
                    model.rememberContractCode(code)
                    model.coordinator.prepareReview(code: code); code = ""
                }
                .buttonStyle(.borderedProminent).controlSize(.large).buttonBorderShape(.capsule)
                .disabled(!model.state.smsSent || !model.state.localCancellationConsent.allowsNewConsent).accessibilityIdentifier("compliance.review")
            }
        case .verificationUnavailable:
            DeregistrationVerificationUnavailableSection(method: model.state.status?.verificationMethod) { requestCancellationRead() }
        case .review:
            Section {
                Label { Text("compliance.reviewWarning").fixedSize(horizontal: false, vertical: true) } icon: { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(CYColor.warningText) }
                    .cyText(.bodyMedium).accessibilityIdentifier("compliance.reviewWarning")
                    .padding(CYSpacing.md)
                    .background(CYColor.warningText.opacity(0.12), in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                    .listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 0, leading: CYSpacing.lg, bottom: CYSpacing.sm, trailing: CYSpacing.lg))
                Text("c08.display.42", tableName: "AccountDeregistrationPresentation").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                if let impact = model.state.status?.impact, impact.confirmable {
                    AccountDeregistrationImpactConfirmation(revision: impact.revision) {
                        guard let intent = model.cancellationIntent() else { return }; code = ""
                        let displayedVersion = document?.version
                        Task { await model.applyOnContract(recordNoticeConsent: true, expectedConsentVersion: displayedVersion, intent: intent) }
                    }.id(impact.revision).disabled(!model.state.localCancellationConsent.allowsNewConsent)
                } else if model.coordinator.deregistrationOriginalRevision == nil {
                    Button("fixr3.deregister.confirmApply", role: .destructive) {
                        guard let intent = model.cancellationIntent() else { return }; code = ""
                        let displayedVersion = document?.version
                        Task { await model.applyOnContract(recordNoticeConsent: true, expectedConsentVersion: displayedVersion, intent: intent) }
                    }
                    .disabled(!model.state.localCancellationConsent.allowsNewConsent)
                    .accessibilityIdentifier("compliance.confirmApply")
                }
                Button("compliance.back") {
                    guard model.cancellationIntent() != nil else { return }
                    model.coordinator.backToVerification()
                }
                .buttonStyle(.borderless)
            }
        case .pending:
            Text("compliance.pending.submitted").cyText(.cardTitle).accessibilityIdentifier("compliance.pending.submitted")
            pendingCoolingOffCopy.accessibilityIdentifier("compliance.pending")
            Button("compliance.withdrawCancellation", role: .destructive) { cancelIntent = model.cancellationIntent(); cancelReview = cancelIntent != nil }
                .accessibilityIdentifier("compliance.cancelApplication")
                .accessibilityLabel(Text("compliance.withdrawCancellation"))
                .accessibilityValue(Text("compliance.pending.submitted"))
                .accessibilityHint(Text(LocalizedStringKey(model.coordinator.coolingOffHasPassed(now: Date()) ? "compliance.pending.afterCoolingOff" : "compliance.pending.duringCoolingOff")))
        case .completed: Text("compliance.completed", tableName: "AccountDeregistrationPresentation").accessibilityIdentifier("compliance.completed")
        case .freshLogin:
            // B-DR-06: the MP LOGIN_REQUIRED empty state. Sign-in itself happens outside this sheet (close first).
            CYEmptyState(systemImage: "person.crop.circle", "fixr3.deregister.signedOut", detail: "compliance.freshLogin",
                         messageIdentifier: "compliance.freshLogin")
        case .unknown: Text("compliance.unknown")
            .accessibilityIdentifier("compliance.unknown")
            .accessibilityLabel(Text("compliance.unknown"))
            .accessibilityValue(Text(verbatim: "—"))
            .accessibilityHint(Text("compliance.unknown"))
        }
        if model.state.step != .blocked {
            Button("compliance.refresh") { requestCancellationRead() }
                .buttonStyle(.borderless)
        }
        // B-DR-01: the on-device consent record is support detail, folded under 详情 instead of a permanent section.
        Section {
            DisclosureGroup {
                Text(LocalizedStringKey(model.state.localCancellationConsent.messageKey), tableName: "AccountDeregistrationConsent")
                    .cyText(.meta).foregroundStyle(CYColor.textSecondary).accessibilityIdentifier("cancellationConsent.state")
                if let request = model.state.localCancellationConsent.requestID {
                    Text("cancellationConsent.request", tableName: "AccountDeregistrationConsent").cyText(.meta)
                    Text(verbatim: request).cyText(.meta).textSelection(.enabled)
                }
                Text("cancellationConsent.scope", tableName: "AccountDeregistrationConsent").cyText(.meta)
            } label: { Text("cancellationConsent.title", tableName: "AccountDeregistrationConsent").cyText(.meta) }
        }
        .accessibilityElement(children: .combine)
    }
    @ViewBuilder private var pendingCoolingOffCopy: some View {
        if model.coordinator.coolingOffHasPassed(now: Date()) {
            Text("compliance.pending.afterCoolingOff")
        } else {
            Text("compliance.pending.duringCoolingOff")
        }
    }
    /// Server status codes (PENDING / ELIGIBLE / BLOCKED) read as plain words, as the mini-program titles them.
    @ViewBuilder private func statusMark(_ raw: String) -> some View {
        switch raw.uppercased() {
        case "PENDING": CYStatusChip("compliance.status.pending", tone: .warning)
        case "ELIGIBLE": CYStatusChip("compliance.status.eligible", tone: .success)
        case "BLOCKED": CYStatusChip("compliance.status.blocked", tone: .danger)
        default:
            Text(verbatim: DeregisterIndexPageModel.statusText(raw))
        }
    }
    private var roam: some View {
        Section {
            NavigationLink { SettingsLegalDocumentView(type: .privacyPolicy, market: market, reader: legalReader) } label: { Text("compliance.readPrivacy") }
            Text("compliance.roamExplanation")
            // E2E-20261112 F3: offer Agree while the latest server row is not a current AGREE.
            if model.state.roamConsent == .notAgreed {
                Text("compliance.roamConsent.notAgreed").accessibilityIdentifier("compliance.roamConsent.notAgreed")
                Button("compliance.roamAgree") {
                    Task {
                        await SessionOfflineSyncModel.shared.performWriteOptIn(
                            environmentSession: offlineWriteSession.session,
                            routes: ["/api/compliance/consents"]
                        ) {
                            await model.coordinator.agreeRoam(explicitlyConfirmed: true)
                        }
                    }
                }
                    .accessibilityIdentifier("compliance.roamAgree")
            } else {
                if model.state.roamConsent == .agreed {
                    Text("compliance.roamConsent.agreed").accessibilityIdentifier("compliance.roamConsent.agreed")
                }
                Text(LocalizedStringKey("compliance.cleanup." + String(describing: model.state.roamCleanup)))
                // B-PV-06: a partial (server revoked, local cleanup pending) or failed withdrawal gets an inline row with 重试.
                if model.state.roamCleanup == .serverConfirmed || model.state.roamCleanup == .trackingStopped
                    || (model.state.error != nil && model.state.roamCleanup != .complete && model.state.roamConsent != .notAgreed) {
                    HStack(alignment: .firstTextBaseline, spacing: CYSpacing.sm) {
                        Label { Text("fixr3.privacy.roam.incomplete").cyText(.bodyCompact) } icon: {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(CYColor.warningText)
                        }
                        Spacer(minLength: CYSpacing.sm)
                        Button { performRoamRevoke() } label: { Text("fixr3.common.retry") }
                            .buttonStyle(.borderless)
                            .frame(minHeight: CYSpacing.minTouchTarget)
                            .accessibilityIdentifier("compliance.revoke.retry")
                    }
                    .accessibilityElement(children: .contain)
                }
                Button("compliance.revoke", role: .destructive) { performRoamRevoke() }
                    .disabled(model.state.roamCleanup == .complete).accessibilityIdentifier("compliance.revoke")
            }
            CYScreenOfflineWriteBanner(
                routes: ["/api/compliance/consents"],
                session: offlineWriteSession.session
            )
        }
        .task { if model.state.roamConsent == .unknown { await model.coordinator.loadRoamConsent() } }
    }
    private func performRoamRevoke() {
        let previous = model.state.roamCleanup
        Task {
            await SessionOfflineSyncModel.shared.performWriteOptIn(
                environmentSession: offlineWriteSession.session,
                routes: ["/api/compliance/consents"]
            ) {
                await model.coordinator.revokeRoam(explicitlyConfirmed: true)
            }
            switch RoamConsentWithdrawalFeedback.evaluate(
                previous: previous,
                current: model.state.roamCleanup,
                error: model.state.error
            ) {
            case .withdrawn:
                toastTone = .success
                toastMessage = LocalizedStringKey(MemberPopupCopy.text(
                    "已撤回漫游定位同意",
                    "Roam location consent withdrawn",
                    locale: locale))
            case .partialLocalPending:
                toastTone = .warning
                toastMessage = LocalizedStringKey(MemberPopupCopy.text(
                    "已撤回平台授权，但本机清理未完成",
                    "Platform consent revoked; local cleanup pending",
                    locale: locale))
            case .failed:
                toastTone = .warning
                toastMessage = LocalizedStringKey(MemberPopupCopy.text(
                    "撤回漫游定位同意失败，请稍后再试",
                    "Failed to withdraw roam consent",
                    locale: locale))
            case .idle:
                break
            }
        }
    }
    /// pages/shezhi/marketing/index read model over the coordinator state already on screen. No extra request.
    private var marketingPage: ShezhiMarketingIndexPageModel { ShezhiMarketingIndexPageModel(state: model.state) }
    /// B-MK-06: a non-empty `merchantLogo` replaces the initial tile. `""` keeps the initial.
    @ViewBuilder private func merchantMark(_ row: ComplianceMarketingConsent) -> some View {
        let initial = Text(verbatim: String((row.merchantName ?? "?").prefix(1)))
            .cyText(.bodyMedium, weight: .bold).foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(SettingsTint.orange.gradient, in: RoundedRectangle(cornerRadius: CYRadius.inner, style: .continuous))
            .accessibilityHidden(true)
        // Only a safe (https) logo URL is fetched; "" or anything else keeps the initial tile.
        if let logo = QuestifyCardArtwork.safeURL(row.merchantLogo) {
            AsyncImage(url: logo) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    initial
                }
            }
            .frame(width: 36, height: 36)
            .clipShape(RoundedRectangle(cornerRadius: CYRadius.inner, style: .continuous))
            .accessibilityHidden(true)
        } else {
            initial
        }
    }
    private var marketing: some View {
        let page = marketingPage
        return Section {
            if page.phase == .empty {
                Text("compliance.marketing.empty", tableName: "MarketingConsentOriginalPresentation").accessibilityIdentifier("compliance.marketing.empty")
            }
            CYScreenOfflineWriteBanner(
                routes: ["/api/compliance/consents"],
                session: offlineWriteSession.session
            )
            // B-MK-02: no engineering scope line on the user page.
            ForEach(model.state.marketingOriginalResults) { receipt in
                MarketingConsentOriginalReceiptView(receipt: receipt)
            }
            if page.phase != .loading && !model.state.marketingLoaded {
                Text("marketingOriginal.current.unconfirmed", tableName: "MarketingConsentOriginalPresentation")
            }

            if page.unresolvedText != nil && !model.state.marketingUnresolved.isEmpty {
                Text("compliance.marketing.unknown", tableName: "MarketingConsentOriginalPresentation").accessibilityIdentifier("compliance.marketing.unknown")
            }
            ForEach(model.state.marketing) { row in
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: CYSpacing.md) {
                        merchantMark(row)
                        // B-MK-06b: MP mc-name is body-medium, not a headline.
                        Text(row.merchantName ?? appLocalized("compliance.merchant", locale: locale))
                            .cyText(.bodyMedium).accessibilityAddTraits(.isHeader)
                    }
                    .padding(.bottom, CYSpacing.sm)
                    ForEach(ComplianceMarketingChannel.allCases, id: \.rawValue) { channel in
                        Divider().padding(.vertical, CYSpacing.xs)
                        Toggle(isOn: Binding(get: { row.value(channel) }, set: { value in
                            guard scenePhase == .active, model.marketingRead() != nil else { return }
                            marketingChange = model.coordinator.reviewMarketing(row, channel: channel, optedIn: value)
                        })) {
                            // B-MK-02: MP rows are the channel name and the switch only.
                            Text(LocalizedStringKey("compliance.channel." + channel.rawValue)).cyText(.body)
                        }
                        .tint(SettingsTint.green)
                        .disabled(!designModeAllowsToggles && model.coordinator.reviewMarketing(row, channel: channel, optedIn: !row.value(channel)) == nil)
                        .accessibilityIdentifier("compliance.marketing.\(row.id).\(channel.rawValue)")
                    }
                }
                .padding(.vertical, CYSpacing.xs)
            }
            Button("compliance.refresh") {
                guard scenePhase == .active, let intent = model.marketingRead() else { return }
                marketingChange = nil
                Task { await model.coordinator.loadMarketing(intent: intent) }
            }.accessibilityIdentifier("compliance.marketing.refresh")
        }
        .sheet(isPresented: Binding(
            get: { marketingChange != nil },
            set: { if !$0 { marketingChange = nil } }
        )) {
            if let change = marketingChange {
                MemberMarketingConsentConfirmSheet(
                    merchantName: change.row.merchantName,
                    channelKey: String.LocalizationValue(stringLiteral: "compliance.channel." + change.channel.rawValue),
                    optedIn: change.optedIn
                ) {
                    guard scenePhase == .active, model.marketingRead() != nil else { marketingChange = nil; return }
                    marketingChange = nil
                    Task {
                        await SessionOfflineSyncModel.shared.performWriteOptIn(
                            environmentSession: offlineWriteSession.session,
                            routes: ["/api/compliance/consents"]
                        ) {
                            await model.coordinator.setMarketing(change, explicitlyConfirmed: true)
                        }
                        // B-MK-05: MP toast 已同意 / 已退订 once the server confirmed the new value.
                        if model.state.error == nil,
                           model.state.marketing.first(where: { $0.id == change.row.id })?.value(change.channel) == change.optedIn {
                            toastTone = .info
                            toastMessage = change.optedIn ? "compliance.marketing.toast.agreed" : "compliance.marketing.toast.unsubscribed"
                        }
                    }
                }
                .themeDomain(.player)
            }
        }
    }
}

/// Bridge for Registration/Play merchant-on-site consent. Content must be source-backed and
/// approved independently; missing content never becomes a guessed legal statement.
@MainActor struct ComplianceConsentReviewSheet: View {
    let subject: ComplianceSubject
    let sourceText: String?
    let service: AccountComplianceService
    let session: ComplianceSession
    let onConfirmed: (ComplianceConsent) -> Void
    @State private var agreed = false
    @State private var busy = false
    @State private var errorKey: String?
    @State private var requestID = UUID().uuidString
    @Environment(\.dismiss) private var dismiss
    @Environment(\.offlineWriteSession) private var offlineWriteSession
    var body: some View {
        Form {
            CYScreenOfflineWriteSection(
                routes: ["/api/compliance/consents"],
                session: offlineWriteSession.session
            )
            if let sourceText, !sourceText.isEmpty {
                Text(sourceText).accessibilityIdentifier("compliance.scope.document")
                Toggle("compliance.scope.agree", isOn: $agreed)
                Button("compliance.scope.confirm") {
                    Task {
                        guard !busy, agreed else { return }; busy = true; defer { busy = false }
                        do {
                            let record = try await SessionOfflineSyncModel.shared.performWriteOptIn(
                                environmentSession: offlineWriteSession.session,
                                routes: ["/api/compliance/consents"],
                                explicitKey: requestID
                            ) {
                                try await service.consent(subject, event: .agree, requestID: requestID, session: session)
                            }
                            try service.check(session); onConfirmed(record); dismiss()
                        } catch { errorKey = "compliance.unknown" }
                    }
                }.disabled(!agreed || busy).accessibilityIdentifier("compliance.scope.confirm")
            } else { Text("compliance.legalMissing") }
            if busy {
                CYSkeleton()
                    .accessibilityLabel(Text("compliance.loading"))
            }
            if let errorKey { Text(LocalizedStringKey(errorKey)) }
        }
        .interactiveDismissDisabled(busy)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("compliance.close") { dismiss() }.disabled(busy) } }
    }
}

/// The registration host can inspect the missing/legal-gated source without granting creation.
private struct ComplianceSignupDestinationKey: EnvironmentKey {
    static let defaultValue: (() -> AnyView)? = nil
}
extension EnvironmentValues {
    var complianceSignupDestination: (() -> AnyView)? {
        get { self[ComplianceSignupDestinationKey.self] }
        set { self[ComplianceSignupDestinationKey.self] = newValue }
    }
}
@MainActor struct SessionComplianceSignupView: View {
    @ObservedObject var session: AppSession
    var body: some View {
        Group {
            if let context = session.complianceSignupContext() {
                ComplianceConsentReviewSheet(subject: .signup, sourceText: nil, service: context.0,
                    session: context.1, onConfirmed: { _ in })
            } else { Text("compliance.legalMissing") }
        }.id(session.sessionRevision)
    }
}


/// Header for the privacy screens: tinted icon tile, large title, one calm sentence. Deregistration adds a
/// three-step strip (read the notice, verify, confirm) so the person always knows how far along they are.
struct ComplianceHeader: View {
    let destination: ComplianceDestination
    let step: ComplianceStep
    private var symbol: String {
        switch destination { case .cancellation: return "person.crop.circle.badge.minus"; case .marketing: return "megaphone.fill"; case .roam: return "location.fill" }
    }
    private var tint: Color { CYColor.textPrimary }
    /// B-DR-08: progress uses the accent fill with its own foreground (white on `textPrimary` failed in dark mode).
    private var stepFill: Color { CYColor.actionPrimaryBg }
    private var intro: LocalizedStringKey {
        switch destination {
        case .cancellation: return "compliance.cancellation.intro"
        case .marketing: return "compliance.marketingExplanation"
        case .roam: return "compliance.roamExplanation"
        }
    }
    private var stage: Int {
        switch step { case .idle, .notice, .blocked: return 0; case .verify, .verificationUnavailable: return 1; default: return 2 }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            Image(systemName: symbol).cyText(.sectionTitle, weight: .semibold).foregroundStyle(tint)
                .frame(width: 52, height: 52)
                .background(CYColor.bgRaised, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                .accessibilityHidden(true)
            Text(intro).cyText(.body).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            if destination == .cancellation, ![.completed, .pending, .freshLogin, .unknown].contains(step) {
                let names = ["compliance.step.1", "compliance.step.2", "compliance.step.3"]
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    HStack(spacing: 0) {
                        ForEach(0..<3, id: \.self) { i in
                            if i > 0 { Capsule().fill(i <= stage ? stepFill : CYColor.textPrimary.opacity(0.16)).frame(height: 3) }
                            ZStack {
                                Circle().fill(i <= stage ? stepFill : CYColor.textPrimary.opacity(0.12))
                                if i < stage { Image(systemName: "checkmark").cyText(.micro, weight: .heavy).foregroundStyle(CYColor.textOnAccent) }
                                else { Text(verbatim: String(i + 1)).cyText(.meta, weight: .bold, monospacedDigit: true).foregroundStyle(i == stage ? CYColor.textOnAccent : CYColor.textSecondary) }
                            }
                            .frame(width: 26, height: 26)
                        }
                    }
                    HStack(spacing: CYSpacing.xs) {
                        Text(verbatim: "\(stage + 1)/3").monospacedDigit().foregroundStyle(CYColor.textSecondary)
                        Text(LocalizedStringKey(names[stage])).foregroundStyle(CYColor.textPrimary)
                    }
                    .cyText(.bodyMedium)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(LocalizedStringKey(names[stage])))
                .accessibilityValue(Text(verbatim: "\(stage + 1)/3"))
                .padding(.top, CYSpacing.xs)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

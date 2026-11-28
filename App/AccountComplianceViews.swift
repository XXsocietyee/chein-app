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

    /// r8 B-DR-04b (MP utils/deregister-flow.js:137-176): the notice step runs the read-only precheck on entry, so
    /// blockers show before 我已阅读并理解注销后果. Nothing is recorded; the agreed precheck still runs on 下一步.
    @Published private(set) var entryPrecheck: AccountPublishMPContract.DeregisterPrecheck?
    @Published private(set) var entryPrecheckLoading = false
    func entryPrecheckOnContract() async {
        guard AccountPublishContractLane.isInstalled, let baseURL = AccountPublishContractLane.baseURL, !entryPrecheckLoading else { return }
        entryPrecheckLoading = true
        defer { entryPrecheckLoading = false }
        guard let request = try? AccountPublishMPContract.deregisterPrecheckRequest(baseURL: baseURL, token: AccountPublishContractLane.token),
              let (data, _) = try? await AccountPublishContractLane.send(request) else { return }
        entryPrecheck = AccountPublishMPContract.deregisterPrecheck(from: data)
    }
    var entryBlockers: [String] { entryPrecheck?.blockers.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? [] }

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
        // P0-6: an APPLE account sends its fresh Sign in with Apple proof (identityToken / authorizationCode), never an SMS code.
        let appleProof = coordinator.reviewedAppleProof
        let smsCode: String? = appleProof == nil ? contractSMSCode : nil
        let consented = await coordinator.prepareContractApplyConsent(recordNoticeConsent: recordNoticeConsent, expectedConsentVersion: expectedConsentVersion, intent: intent)
        guard consented, let baseURL = AccountPublishContractLane.baseURL else { return }
        do {
            let request = try AccountPublishMPContract.deregisterApplyRequest(baseURL: baseURL, requestID: contractApplyRequestID, smsCode: smsCode,
                appleProof: appleProof, token: AccountPublishContractLane.token)
            let (data, _) = try await AccountPublishContractLane.send(request)
            let outcome = AccountPublishMPContract.deregisterApply(from: data)
            let refusal = AccountPublishMPContract.deregisterApplyRefusal(from: data)
            if outcome == nil, refusal != nil { contractApplyRequestID = UUID().uuidString.lowercased() }
            await coordinator.adoptContractApply(outcome, refusal: refusal, intent: intent)
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
    /// r11 B-SZ-10: SettingsView shows 营销消息与优惠券 on its own, right after AI 对话记录 (MP shezhi.wxml:21-22).
    var showsMarketingEntry = true
    /// mp-settings r3: Settings opens 漫游定位 from 隐私与定位 (MP privacy-sheet), so the MP-ordered page hides this row.
    var showsRoamEntry = true
    @State private var selected: ComplianceDestination?
    private var listedDestinations: [ComplianceDestination] {
        ComplianceDestination.allCases.filter { $0 != .cancellation && (showsMarketingEntry || $0 != .marketing) && (showsRoamEntry || $0 != .roam) }
    }
    @State private var npcChatData: NPCChatDataPresentation?
    var body: some View {
        if !listedDestinations.isEmpty || showsNPCChatDataEntry {
        Section {
            ForEach(listedDestinations) { destination in
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
                            Spacer(minLength: 0); Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary) }
                    }
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("compliance.open.\(destination.rawValue)")
                }
            }
            if showsNPCChatDataEntry {
                Button { npcChatData = .init(coordinator: makeCoordinator().makeNPCChatDataCoordinator()) } label: {
                    Label { Text("npcData.title") } icon: { AccountPublishMPGlyph(MPAsset.FeatureIcon.iconLcMessageSquareText) }
                        .environment(\.settingsTileTint, SettingsTint.indigo)
                }
                .foregroundStyle(.primary)
                .accessibilityIdentifier("npcData.open")
            }
        } header: { Text("compliance.title") } footer: { Text("settings.privacy.footer") }
        }
        // Destructive row: its own section, red, with the consequence stated underneath.
        Section {
            Button(role: .destructive) { selected = .cancellation } label: {
                Label { Text("settings.deregister.row").foregroundStyle(CYColor.dangerText) } // MP shezhi.wxml:34 账号注销
                    icon: { AccountPublishMPGlyph(MPAsset.FeatureIcon.iconLcUserRoundX) }
                    .environment(\.settingsTileTint, SettingsTint.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityIdentifier("compliance.open.\(ComplianceDestination.cancellation.rawValue)")
        } footer: { Text("settings.danger.footer") }
        .cySheet(item: $selected) { destination in Group {
            NavigationStack {
                AccountComplianceSheet(coordinator: makeCoordinator(), destination: destination, market: market, legalReader: legalReader)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        }
        .cySheet(item: $npcChatData) { presentation in Group { NPCChatDataView(coordinator: presentation.coordinator) }.presentationDetents([.large]).presentationDragIndicator(.visible) }
    }
}
/// r11 B-SZ-10: the 营销消息与优惠券 row on its own, so Settings can place it where MP shezhi.wxml:21-22 does
/// (after AI 对话记录, before 帖文处置与申诉). Same destination and id as the row in `AccountComplianceSettingsSection`.
@MainActor struct AccountComplianceMarketingSettingsEntry: View {
    let coordinator: AccountComplianceCoordinator?
    let market: RegionalMarket?
    var legalReader: any SettingsLegalReading = SettingsBundledLegalReader()
    var body: some View {
        if let coordinator {
        Section {
            NavigationLink {
                AccountComplianceSheet(coordinator: coordinator, destination: .marketing,
                    market: market, legalReader: legalReader, showsCloseButton: false)
            } label: {
                Label { Text(LocalizedStringKey(ComplianceDestination.marketing.title)) } icon: { AccountPublishMPGlyph(MPAsset.FeatureIcon.iconLcTicket) }
                    .environment(\.settingsTileTint, SettingsTint.orange)
            }
            .accessibilityIdentifier("compliance.open.\(ComplianceDestination.marketing.rawValue)")
        }
        }
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
    /// a11y-dt r3: the initial grows with Dynamic Type instead of clipping in a fixed 36 pt tile.
    @ScaledMetric(relativeTo: .body) private var merchantMarkSide: CGFloat = 36
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
                }
            }
            if model.state.busy {
                // B-DR-09-r7 / mp-states r3: one labelled system loader; the MP names what is loading
                // (cy-empty kind loading 正在核验注销条件) on the deregister page, 加载中… elsewhere.
                ProgressView {
                    Text(LocalizedStringKey(destination == .cancellation && model.state.status == nil ? "fixr3.deregister.loading" : "compliance.loading"))
                }
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("compliance.loading")
            }
            // B-DR-03: the missing-bound-phone message shows inline under 获取验证码, not twice.
            if let error = model.state.error, error != DeregistrationBoundPhone.missingMessage {
                if destination == .cancellation {
                    // mp-states r3 (MP scene-settings-deregister cy-error): one state with its title, the reason
                    // as the description and 重试 inside it — 注销条件核验失败 / 验证码没有发送 / 注销申请没有提交 / 撤销没有完成.
                    cancellationIssue(error)
                } else if destination == .marketing {
                    // mp-states r3 (MP marketing-consent cy-inline-error): 营销同意状态加载失败 · sub · 重试 before the
                    // list has loaded; 营销同意状态未更新 · sub (no action) once rows are on screen.
                    marketingIssue(error)
                } else {
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
            if destination == .cancellation, scenePhase == .active {
                if let intent = model.cancellationIntent(resume: true) { await loadCancellation(intent) }
                else { model.coordinator.noteSignedOut() }
            }
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
            else { model.coordinator.noteSignedOut() }
        }
        .cySheet(isPresented: $cancelReview) {
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
    private var cancellationIssueTitle: LocalizedStringKey {
        if model.state.status == nil { return "fixr3.deregister.readFailed" }
        switch model.state.step {
        case .verify: return model.state.status?.verifiesWithApple == true ? "compliance.apple.failedTitle" : "fixr3.deregister.smsFailed"
        case .review: return "fixr3.deregister.applyFailed"
        case .pending: return "fixr3.deregister.cancelFailed"
        default: return "fixr3.deregister.readFailed"
        }
    }
    private var cancellationIssueRetry: (() -> Void)? {
        if model.state.status == nil { return { requestCancellationRead() } }
        switch model.state.step {
        case .verify:
            // The Apple button below is the retry for an APPLE account.
            if model.state.status?.verifiesWithApple == true { return nil }
            return {
                guard let intent = model.cancellationIntent() else { return }
                Task { await model.sendBoundSMSOnContract(intent: intent) }
            }
        case .pending:
            return {
                cancelIntent = model.cancellationIntent()
                cancelReview = cancelIntent != nil
            }
        case .review:
            return nil
        default:
            return { requestCancellationRead() }
        }
    }
    /// P0-6: hands the fresh Apple credential to the coordinator, which moves to the review step.
    private func appleCredentialReceived(token: String, authorizationCode: String?) {
        guard let intent = model.cancellationIntent() else { return }
        model.coordinator.prepareAppleReview(identityToken: token, authorizationCode: authorizationCode, intent: intent)
    }
    @ViewBuilder private func cancellationIssue(_ error: String) -> some View {
        ContentUnavailableView {
            Label { Text(cancellationIssueTitle) } icon: { Image(systemName: "exclamationmark.triangle") }
        } description: {
            Text(LocalizedStringKey(error), tableName: error == "compliance.impactChanged" ? "AccountDeregistrationPresentation" : nil)
                .accessibilityIdentifier("compliance.error")
        } actions: {
            if let retry = cancellationIssueRetry {
                Button(action: retry) { Text("fixr3.common.retry") }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("compliance.error.retry")
            }
        }
    }
    private var marketingIssueTitle: String {
        model.state.marketingLoaded
            ? MemberPopupCopy.text("营销同意状态未更新", "Marketing consent wasn't updated", locale: locale)
            : MemberPopupCopy.text("营销同意状态加载失败", "Couldn't load marketing consent", locale: locale)
    }
    @ViewBuilder private func marketingIssue(_ error: String) -> some View {
        ContentUnavailableView {
            Label { Text(verbatim: marketingIssueTitle) } icon: { Image(systemName: "wifi.exclamationmark") }
        } description: {
            Text(LocalizedStringKey(error))
                .accessibilityIdentifier("compliance.error")
        } actions: {
            if !model.state.marketingLoaded {
                Button(action: retryMarketingRead) { Text("fixr3.common.retry") }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("compliance.error.retry")
            }
        }
    }
    private func retryMarketingRead() {
        guard scenePhase == .active, let intent = model.marketingRead() else { return }
        marketingChange = nil
        Task { await model.coordinator.loadMarketing(intent: intent) }
    }
    private func requestCancellationRead() {
        guard destination == .cancellation, scenePhase == .active else { return }
        guard let intent = model.cancellationIntent() else {
            model.coordinator.noteSignedOut()
            return
        }
        cancelReview = false; cancelIntent = nil
        Task { await loadCancellation(intent) }
    }
    @ViewBuilder private var cancellation: some View {
        if let request = model.state.originalApplicationRequestID {
            Section {
                // B-DR-01: the request id is support detail, folded under 详情.
                DisclosureGroup {
                    (Text("c08.display.43", tableName: "AccountDeregistrationPresentation") + Text(verbatim: request)).font(.subheadline).textSelection(.enabled)
                } label: { Text("compliance.details").font(.subheadline) }
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
                Text("fixr3.deregister.blocked.lead")
                ForEach(Array((model.state.status?.blockers ?? []).enumerated()), id: \.offset) { _, blocker in
                    Label { Text(verbatim: blocker) } icon: {
                        Image(systemName: "exclamationmark.circle").foregroundStyle(.orange)
                    }
                    .accessibilityIdentifier("compliance.blocker")
                }
                Button { requestCancellationRead() } label: { Text("fixr3.deregister.blocked.recheck") }
                    .accessibilityIdentifier("compliance.blocked.recheck")
            } header: { Text("fixr3.deregister.blocked.title") }
        case .notice:
            if model.state.status?.cancellationConfirmed == true {
                Text("compliance.cancellationConfirmed", tableName: "AccountDeregistrationPresentation").accessibilityIdentifier("compliance.cancellationConfirmed")
            }
            if !model.entryBlockers.isEmpty {
                // r8 B-DR-04b: blockers from the entry precheck, before the agreement (MP BLOCKED card).
                Section {
                    Text("fixr3.deregister.blocked.lead")
                    ForEach(Array(model.entryBlockers.enumerated()), id: \.offset) { _, blocker in
                        Label { Text(verbatim: blocker) } icon: {
                            Image(systemName: "exclamationmark.circle").foregroundStyle(.orange).accessibilityHidden(true)
                        }
                        .accessibilityIdentifier("compliance.entryBlocker")
                    }
                    Button { Task { await model.entryPrecheckOnContract() } } label: { Text("fixr3.deregister.blocked.recheck") }
                        .disabled(model.entryPrecheckLoading)
                        .accessibilityIdentifier("compliance.entryBlocked.recheck")
                } header: { Text("fixr3.deregister.blocked.title") }
            }
            Section {
                if let document {
                    Text(document.title).font(.headline)
                    Text(document.intro)
                    ForEach(Array(document.sections.enumerated()), id: \.offset) { _, section in
                        Text(section.heading).font(.headline); Text(section.body)
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
                        || !agreement || !model.state.localCancellationConsent.allowsNewConsent
                        || !model.entryBlockers.isEmpty)
                    .accessibilityIdentifier("compliance.precheck")
            }
            .task { await model.entryPrecheckOnContract() }
        case .verify where model.state.status?.verifiesWithApple == true:
            DeregistrationAppleReauthSection(busy: model.state.busy, enabled: model.state.localCancellationConsent.allowsNewConsent,
                onCredential: { token, authorizationCode in appleCredentialReceived(token: token, authorizationCode: authorizationCode) },
                onFailure: { cancelled in model.coordinator.noteAppleReauthFailed(cancelled: cancelled) })
        case .verify:
            Section {
                // B-DR-03 (MP deregister-flow sendSms): the code goes to the account's bound phone, read from
                // `/api/user/info`; there is no number field. Core blocks a second send for 60 seconds.
                Button(LocalizedStringKey(model.state.smsSent ? "fixr3.deregister.resendSMS" : "fixr3.deregister.sendSMS")) {
                    guard let intent = model.cancellationIntent() else { return }
                    Task { await model.sendBoundSMSOnContract(intent: intent) }
                }
                    .disabled(model.state.busy || !model.state.localCancellationConsent.allowsNewConsent).accessibilityIdentifier("compliance.sendSMS")
                if model.state.error == DeregistrationBoundPhone.missingMessage {
                    Text(verbatim: DeregistrationBoundPhone.missingMessage).font(.subheadline).foregroundStyle(CYColor.dangerText)
                        .accessibilityIdentifier("compliance.boundPhoneMissing")
                } else if let notice = model.state.smsNotice, model.state.smsSent {
                    Text(verbatim: notice).font(.subheadline).foregroundStyle(.secondary)
                        .accessibilityIdentifier("compliance.smsSent")
                } else if model.state.smsSent { Text("compliance.smsSent").font(.subheadline).foregroundStyle(.secondary) }
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
                Label { Text("compliance.reviewWarning").fixedSize(horizontal: false, vertical: true) } icon: { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange) }
                    .accessibilityIdentifier("compliance.reviewWarning")
                Text("c08.display.42", tableName: "AccountDeregistrationPresentation").font(.subheadline).foregroundStyle(.secondary)
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
            Text("compliance.pending.submitted").font(.headline).accessibilityIdentifier("compliance.pending.submitted")
            pendingCoolingOffCopy.accessibilityIdentifier("compliance.pending")
            Button("compliance.withdrawCancellation", role: .destructive) { cancelIntent = model.cancellationIntent(); cancelReview = cancelIntent != nil }
                .accessibilityIdentifier("compliance.cancelApplication")
                .accessibilityLabel(Text("compliance.withdrawCancellation"))
                .accessibilityValue(Text("compliance.pending.submitted"))
                .accessibilityHint(Text(LocalizedStringKey(model.coordinator.coolingOffHasPassed(now: Date()) ? "compliance.pending.afterCoolingOff" : "compliance.pending.duringCoolingOff")))
        case .completed: Text("compliance.completed", tableName: "AccountDeregistrationPresentation").accessibilityIdentifier("compliance.completed")
        case .freshLogin:
            // B-DR-06: the MP LOGIN_REQUIRED empty state. Close this sheet, then open sign-in.
            ContentUnavailableView {
                Label { Text("fixr3.deregister.signedOut").accessibilityIdentifier("compliance.freshLogin") } icon: { Image(systemName: "person.crop.circle") }
            } description: {
                Text("compliance.freshLogin")
            } actions: {
                Button {
                    dismiss()
                    PlayerJourneySignInBridge.shared.request()
                } label: { Text("compliance.signIn") }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .accessibilityIdentifier("compliance.signIn")
            }
        case .denied:
            ContentUnavailableView {
                Label { Text("compliance.denied.identity").accessibilityIdentifier("compliance.denied") } icon: { Image(systemName: "person.crop.circle.badge.exclamationmark") }
            } description: {
                Text("compliance.denied.detail")
            }
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
                    .font(.subheadline).foregroundStyle(.secondary).accessibilityIdentifier("cancellationConsent.state")
                if let request = model.state.localCancellationConsent.requestID {
                    Text("cancellationConsent.request", tableName: "AccountDeregistrationConsent").font(.subheadline)
                    Text(verbatim: request).font(.subheadline).textSelection(.enabled)
                }
                Text("cancellationConsent.scope", tableName: "AccountDeregistrationConsent").font(.subheadline)
            } label: { Text("cancellationConsent.title", tableName: "AccountDeregistrationConsent").font(.subheadline) }
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
        case "PENDING": Label { Text("compliance.status.pending") } icon: { Image(systemName: "clock").foregroundStyle(.orange) }
        case "ELIGIBLE": Label { Text("compliance.status.eligible") } icon: { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
        case "BLOCKED": Label { Text("compliance.status.blocked") } icon: { Image(systemName: "xmark.octagon.fill").foregroundStyle(.red) }
        default:
            if DeregisterIndexPageModel.knownStatuses.contains(raw.trimmingCharacters(in: .whitespacesAndNewlines)) {
                Text(verbatim: DeregisterIndexPageModel.statusText(raw))
            } else {
                // mp-settings r3: MP scene-settings-deregister fallback — 账号状态待确认 + 重试.
                Label { Text("compliance.status.unconfirmed") } icon: { Image(systemName: "questionmark.circle").foregroundStyle(.secondary) }
                Button("settingsNative.retry") { requestCancellationRead() }
                    .accessibilityIdentifier("compliance.status.unconfirmed.retry")
            }
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
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Label { Text("fixr3.privacy.roam.incomplete") } icon: {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        }
                        Spacer(minLength: 8)
                        Button { performRoamRevoke() } label: { Text("fixr3.common.retry") }
                            .buttonStyle(.borderless)
                            .accessibilityIdentifier("compliance.revoke.retry")
                    }
                    .accessibilityElement(children: .contain)
                }
                Button("compliance.revoke", role: .destructive) { performRoamRevoke() }
                    .disabled(model.state.roamCleanup == .complete).accessibilityIdentifier("compliance.revoke")
            }
        } footer: {
            // r10 N-16: queued consent writes show as the section footer (system), not a banner row.
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
            .font(.body.weight(.bold)).foregroundStyle(.white)
            .frame(width: merchantMarkSide, height: merchantMarkSide)
            .background(SettingsTint.orange, in: .rect(cornerRadius: CYRadius.sm))
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
            .frame(width: merchantMarkSide, height: merchantMarkSide)
            .clipShape(.rect(cornerRadius: CYRadius.inner))
            .accessibilityHidden(true)
        } else {
            initial
        }
    }
    private var marketing: some View {
        let page = marketingPage
        return Section {
            if page.phase == .empty {
                // mp-settings r3: MP marketing-consent cy-empty kind="empty" 还没有商家消息 → system empty view.
                ContentUnavailableView {
                    Label { Text("compliance.marketing.empty", tableName: "MarketingConsentOriginalPresentation") } icon: { Image(systemName: "ticket") }
                }
                .accessibilityIdentifier("compliance.marketing.empty")
            }
            // B-MK-02: no engineering scope line on the user page.
            ForEach(model.state.marketingOriginalResults) { receipt in
                MarketingConsentOriginalReceiptView(receipt: receipt)
            }
            if page.phase != .loading && !model.state.marketingLoaded && model.state.error == nil {
                Text("marketingOriginal.current.unconfirmed", tableName: "MarketingConsentOriginalPresentation")
            }

            if page.unresolvedText != nil && !model.state.marketingUnresolved.isEmpty {
                Text("compliance.marketing.unknown", tableName: "MarketingConsentOriginalPresentation").accessibilityIdentifier("compliance.marketing.unknown")
            }
            ForEach(model.state.marketing) { row in
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 12) {
                        merchantMark(row)
                        // B-MK-06b: MP mc-name is body-medium, not a headline.
                        Text(row.merchantName ?? appLocalized("compliance.merchant", locale: locale))
                            .font(.body).accessibilityAddTraits(.isHeader)
                    }
                    .padding(.bottom, 8)
                    ForEach(ComplianceMarketingChannel.allCases, id: \.rawValue) { channel in
                        Divider().padding(.vertical, 4)
                        Toggle(isOn: Binding(get: { row.value(channel) }, set: { value in
                            guard scenePhase == .active, model.marketingRead() != nil else { return }
                            if let change = model.coordinator.reviewMarketing(row, channel: channel, optedIn: value) { sendMarketing(change) }
                        })) {
                            // B-MK-02: MP rows are the channel name and the switch only.
                            Text(LocalizedStringKey("compliance.channel." + channel.rawValue))
                        }
                        .tint(SettingsTint.green)
                        .disabled(!designModeAllowsToggles && model.coordinator.reviewMarketing(row, channel: channel, optedIn: !row.value(channel)) == nil)
                        .accessibilityIdentifier("compliance.marketing.\(row.id).\(channel.rawValue)")
                    }
                }
                .padding(.vertical, 4)
            }
            Button("compliance.refresh") {
                guard scenePhase == .active, let intent = model.marketingRead() else { return }
                marketingChange = nil
                Task { await model.coordinator.loadMarketing(intent: intent) }
            }.accessibilityIdentifier("compliance.marketing.refresh")
        } footer: {
            // r10 N-15: MP shezhi/marketing has no banner row; queued consent writes are the section footer.
            CYScreenOfflineWriteBanner(
                routes: ["/api/compliance/consents"],
                session: offlineWriteSession.session
            )
        }
    }
    /// B-MK-05 (r9): MP pages/marketing-consent/index.js:60-80 sends on toggle (no confirm sheet), then toasts 已同意 / 已退订.
    private func sendMarketing(_ change: ComplianceMarketingReview) {
        guard scenePhase == .active, model.marketingRead() != nil else { marketingChange = nil; return }
        marketingChange = nil
        Task {
            await SessionOfflineSyncModel.shared.performWriteOptIn(
                environmentSession: offlineWriteSession.session,
                routes: ["/api/compliance/consents"]
            ) {
                await model.coordinator.setMarketing(change, explicitlyConfirmed: true)
            }
            if model.state.error == nil,
               model.state.marketing.first(where: { $0.id == change.row.id })?.value(change.channel) == change.optedIn {
                toastTone = .info
                toastMessage = change.optedIn ? "compliance.marketing.toast.agreed" : "compliance.marketing.toast.unsubscribed"
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
                ProgressView { Text("compliance.loading") }
                    .frame(maxWidth: .infinity)
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


/// Header for the privacy screens: the destination symbol and one calm sentence. Deregistration adds the three-step
/// progress (read the notice, verify, confirm) as a system `ProgressView` so the person always knows how far along they are.
struct ComplianceHeader: View {
    let destination: ComplianceDestination
    let step: ComplianceStep
    private var symbol: String {
        switch destination { case .cancellation: return "person.crop.circle.badge.minus"; case .marketing: return "megaphone.fill"; case .roam: return "location.fill" }
    }
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
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text(intro).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: symbol).foregroundStyle(.tint).accessibilityHidden(true)
            }
            if destination == .cancellation, ![.completed, .pending, .freshLogin, .unknown].contains(step) {
                let names = ["compliance.step.1", "compliance.step.2", "compliance.step.3"]
                ProgressView(value: Double(stage + 1), total: 3) {
                    Text(LocalizedStringKey(names[stage])).font(.subheadline)
                } currentValueLabel: {
                    Text(verbatim: "\(stage + 1)/3").monospacedDigit()
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(LocalizedStringKey(names[stage])))
                .accessibilityValue(Text(verbatim: "\(stage + 1)/3"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

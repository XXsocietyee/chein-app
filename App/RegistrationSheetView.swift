import SwiftUI

@MainActor
private final class RegistrationSheetModel: ObservableObject {
    let flow: RegistrationUIFlow
    @Published private(set) var revision: UInt64 = 0
    init(flow: RegistrationUIFlow) {
        self.flow = flow
        flow.onChange = { [weak self] in self?.revision &+= 1 }
    }
}

/// Inject the stable session-owned coordinator; never allocate one in a sheet builder.
/// Production needs an independent scoped grant; default creation and waitlist writes stay off.
@MainActor
struct RegistrationSheetView: View {
    @Environment(\.complianceSignupDestination) private var complianceSignupDestination
    @Environment(\.registrationMySignupsDestination) private var mySignupsDestination
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model: RegistrationSheetModel
    @FocusState private var focusedField: Field?
    @State private var showingConfirmation = false
    @State private var showingWaitlistCancellation = false
    @State private var showingAddParticipant = false
    @State private var orderDestination: RegistrationWaitlistOrderVisit?
    @State private var resultOrderDestination: RegistrationResultOrderPresentation?
    @State private var recoveredOrderDestination: RegistrationRecoveredOrderPresentation?
    private let participantReader: (any ProfileReading)?
    private let orderReader: (any ProfileReading)?
    private let participantCoordinator: ParticipantMutationCoordinator?
    private enum Field { case name, phone }

    init(activity: ActivityDetail, coordinator: RegistrationCoordinator,
         participantReader: (any ProfileReading)? = nil,
         orderReader: (any ProfileReading)? = nil,
         participantCoordinator: ParticipantMutationCoordinator? = nil,
         currentIdentity: @escaping () -> ProfileReadIdentity?, quoteEnabled: Bool = false,
         creationPolicy: RegistrationUICreationPolicy = .disabled,
         waitlistService: (any RegistrationWaitlistServing)? = nil,
         couponUsability: (() async throws -> [CouponUsabilityRow])? = nil,
         availablePoints: (() -> Int?)? = nil,
         onReadback: @escaping (RegistrationStatusSnapshot) -> Void = { _ in }) {
        self.orderReader = orderReader
        self.participantReader = participantReader; self.participantCoordinator = participantCoordinator
        self.couponUsability = couponUsability
        _model = StateObject(wrappedValue: RegistrationSheetModel(flow: {
            let flow = RegistrationUIFlow(
                activity: activity, coordinator: coordinator, participantReader: participantReader,
                currentIdentity: currentIdentity, quoteEnabled: quoteEnabled,
                creationPolicy: creationPolicy, waitlistService: waitlistService, onReadback: onReadback)
            flow.availablePoints = availablePoints
            return flow
        }()))
    }
    #if DEBUG
    /// Offline fixture-only injection keeps the real view/controller clock and guards intact.
    init(fixtureFlow: RegistrationUIFlow) {
        participantReader = nil; participantCoordinator = nil; orderReader = nil
        couponUsability = nil
        _model = StateObject(wrappedValue: RegistrationSheetModel(flow: fixtureFlow))
    }
    #endif
    private var flow: RegistrationUIFlow { model.flow }
    private let couponUsability: (() async throws -> [CouponUsabilityRow])?
    @State private var couponPhase: CouponUsabilityPhase = .loading
    var body: some View {
        // Observe the controller notification even though its fields live in a reference type.
        let _ = model.revision
        NavigationStack {
            Form {
                if flow.creationPolicy.isOfflineFixture {
                    Section { Label("registration.form.fixtureNotice", systemImage: "testtube.2").font(.callout) }
                }
                if !flow.hasCurrentSession {
                    Section { Label("registration.form.sessionChanged", systemImage: "person.crop.circle.badge.exclamationmark") }
                } else {
                    // Source checkout banner: shown, never blocking (the viewer may register someone else).
                    alreadyRegisteredSection
                    if flow.hasRetainedIntent {
                        activitySection
                        RegistrationOperationSections(flow: flow,revision:model.revision,orderReader:orderReader)
                        resultOrderSection
                    } else if case .pending(let registrationID) = flow.durableCreation {
                        activitySection
                        Section("registration.form.outcomeUnknown") {
                            Text("registration.waitlist.retainedOrder")
                            if registrationID != nil {
                                CYPillButton("registration.waitlist.readRetainedOrder", style: .secondary) { Task { await flow.readDurableStatus() } }
                                    .disabled(flow.isReadingStatus)
                            }
                            if flow.isReadingStatus { CYLoadingStateView(rows: 1).accessibilityLabel(Text("registration.form.readingStatus")) }
                            if flow.durableStatusFailed {
                                Text("registration.form.statusUnavailable")
                                    .accessibilityIdentifier("registration.recovered.statusUnavailable")
                            }
                            if let snapshot = flow.durableStatus {
                                Text(LocalizedStringKey(RegistrationUIStatus.registrationKey(snapshot.registrationStatus)))
                            }
                        }
                        recoveredOrderSection
                    } else {
                        // Source order (RegistrationCheckoutSection): 参与人信息 → 活动信息 →
                        // 费用明细 (票种 → 订单金额 → 权益 → 积分 → 总计) → 候补 → 提交.
                        participantSection
                        activitySection
                        ticketSection
                        if flow.selectedTicket != nil { G6PromotionCatalogSection(activityID: flow.activity.summary.id) }
                        quoteSection
                        CouponUsabilitySection(phase: couponPhase, onRetry: { Task { await reloadCoupons() } })
                        RegistrationPaymentReadinessSection(price: flow.selectedTicket?.price)
                        refundTiersSection
                        waitlistSection
                        confirmationSection
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .modifier(G6PromotionCatalogLoader(activityID: flow.activity.summary.id))
            .task { await reloadCoupons() }
            .safeAreaInset(edge: .bottom, spacing: 0) { if showsCheckoutBar { checkoutBar } }
            .scrollContentBackground(.hidden)
            .background(CYColor.bgPage)
            .appNavigationTitle("registration.form.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.close") { flow.leave(); dismiss() }
                        .accessibilityIdentifier("registration.form.close")
                }
            }
            .alert(LocalizedStringKey(flow.creationPolicy.isOfflineFixture ? "registration.form.confirmTitle" : "registration.waitlist.confirmTitle"), isPresented: $showingConfirmation) {
                Button(LocalizedStringKey(flow.creationPolicy.isOfflineFixture ? "registration.form.confirmCreate" : "registration.waitlist.confirmCreate")) { Task { await flow.confirmAndReadBack() } }
                    .accessibilityIdentifier("registration.form.confirm")
                Button("action.cancel", role: .cancel) { flow.cancelConfirmation() }
            } message: {
                if let review = flow.confirmation {
                    let base = "\(flow.activity.summary.name)\n\(flow.selectedTicket?.name ?? "")\n\(review.draft.trimmedName)\n\(review.draft.trimmedPhone)\n"
                    let amountText = RegistrationUIMoney.display(review.quote.payAmount, locale: locale) ?? "—"
                    let nonRefundableSuffix = review.quote.requiresNonRefundableConfirmation
                        ? "\n\(CoreLoopCopy(locale: locale).tr(NonRefundable24hNotice.modalTitle)): \(CoreLoopCopy(locale: locale).tr(NonRefundable24hNotice.modalContent))"
                        : ""
                    Text(verbatim: base + amountText + nonRefundableSuffix)
                }
            }
            .alert("registration.waitlist.cancelTitle", isPresented: $showingWaitlistCancellation) {
                Button("registration.waitlist.confirmCancel", role: .destructive) { Task { await flow.cancelWaitlist() } }
                Button("action.cancel", role: .cancel) { flow.dismissWaitlistCancellation() }
            } message: {
                Text(LocalizedStringKey(flow.waitlistCancellation?.status.state == .offered
                    ? "registration.waitlist.cancelOfferHint" : "registration.waitlist.cancelQueueHint"))
                + Text(verbatim: "\n\(flow.activity.summary.name)\n\(flow.selectedTicket?.name ?? "")")
            }
            .onChange(of: flow.waitlistCancellation) { _, value in
                if value == nil { showingWaitlistCancellation = false }
            }
            .task(id: flow.identity) {
                flow.open()
                // Independent reads: a slow participant list must not hide the quote form.
                async let participants: Void = flow.loadParticipants()
                async let quote: Void = flow.requestQuote()
                _ = await (participants, quote)
            }
            .task(id: flow.waitlistReadKey) { await flow.loadWaitlist() }
            .task(id: flow.waitlistStatus?.expiresAt) {
                guard let deadline = flow.waitlistStatus?.expiresAt else { return }
                while deadline > Date() {
                    do { try await Task.sleep(for: .seconds(min(deadline.timeIntervalSinceNow, 86_400))) } catch { return }
                }
                flow.checkWaitlistDeadline()
            }
            .sheet(item: $orderDestination) { visit in
                if let orderReader {
                    RegistrationWaitlistOrderSheet(presentation: visit.presentation, reader: orderReader,
                        isCurrent: { RegistrationWaitlistOrderVisit.permits(visit, current: orderDestination,
                            destination: flow.waitlistOrderDestination, isActive: scenePhase == .active) })
                }
            }
            .onChange(of: flow.waitlistReadKey) { _, _ in orderDestination = nil }
            .onChange(of: flow.waitlistOrderDestination) { _, _ in orderDestination = nil }
            .sheet(item: $resultOrderDestination) { presentation in
                if let orderReader {
                    RegistrationResultOrderSheet(presentation: presentation, reader: orderReader,
                        isCurrent: { resultOrderDestination == presentation &&
                            flow.resultOrderDestination == presentation.destination && scenePhase == .active })
                }
            }
            .sheet(item: $recoveredOrderDestination) { presentation in
                if let orderReader {
                    RegistrationRecoveredOrderSheet(presentation: presentation, reader: orderReader,
                        isCurrent: { recoveredOrderDestination == presentation &&
                            flow.recoveredOrderDestination == presentation.destination && scenePhase == .active })
                }
            }
            .onChange(of: flow.recoveredOrderDestination) { _, _ in recoveredOrderDestination = nil }
            .onChange(of: flow.resultOrderDestination) { _, _ in resultOrderDestination = nil }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { orderDestination = nil; resultOrderDestination = nil; recoveredOrderDestination = nil; flow.retireResultOrderNavigation() }
            }
            .sheet(isPresented: $showingAddParticipant) {
                if let participantReader, let participantCoordinator {
                    NavigationStack {
                        ParticipantFormView(reader: participantReader, coordinator: participantCoordinator,
                            onSaved: { if participantCoordinator.savedParticipant == nil { Task { await flow.loadParticipants() } } },
                            onCreated: { row, identity in Task { await flow.selectCreatedParticipant(row, identity: identity) } })
                    }
                }
            }
            .onChange(of: flow.identity) { _, _ in showingAddParticipant = false }
            .onChange(of: flow.participantsIdentity) { _, _ in
                showingAddParticipant = false
                flow.synchronizeParticipantIdentity()
                guard scenePhase == .active, flow.hasCurrentSession else { return }
                Task { await flow.loadParticipants() }
            }
            .onChange(of: flow.confirmation) { _, value in
                if value == nil { showingConfirmation = false }
            }
            .onDisappear { flow.leave() }
        }
        .accessibilityIdentifier("registration.form.sheet")
    }
    @ViewBuilder private var recoveredOrderSection: some View {
        if let destination = flow.recoveredOrderDestination, let orderReader {
            let readIdentity = orderReader.identity
            Section {
                CYPillButton("profile.orders.detail", style: .secondary) {
                    guard recoveredOrderDestination == nil, resultOrderDestination == nil, orderDestination == nil,
                          scenePhase == .active, flow.recoveredOrderDestination == destination,
                          orderReader.identity == readIdentity, orderReader.isConfigured else { return }
                    recoveredOrderDestination = .init(destination: destination, readIdentity: readIdentity)
                }
                .disabled(scenePhase != .active || !orderReader.isConfigured ||
                    orderReader.identity?.accountID != destination.identity.accountID ||
                    orderReader.identity?.epoch != destination.identity.epoch)
                .accessibilityIdentifier("registration.recovered.openOrder")
            }
        }
    }
    @ViewBuilder private var resultOrderSection: some View {
        if let destination = flow.resultOrderDestination, let orderReader {
            let readIdentity = orderReader.identity
            Section {
                CYPillButton("profile.orders.detail", style: .secondary) {
                    guard resultOrderDestination == nil, orderDestination == nil,
                          scenePhase == .active, flow.resultOrderDestination == destination,
                          orderReader.identity == readIdentity, orderReader.isConfigured else { return }
                    resultOrderDestination = .init(destination: destination, readIdentity: readIdentity)
                }
                .disabled(scenePhase != .active || !orderReader.isConfigured ||
                    orderReader.identity?.accountID != destination.identity.accountID ||
                    orderReader.identity?.epoch != destination.identity.epoch)
                .accessibilityIdentifier("registration.result.openOrder")
            }
        }
    }
    @ViewBuilder private var alreadyRegisteredSection: some View {
        if RegistrationCheckoutFacts(activity: flow.activity, ticket: flow.selectedTicket).viewerAlreadyRegistered {
            Section {
                Label("registrationParity.alreadyRegistered", systemImage: "checkmark.seal")
                    .font(.headline)
                    .accessibilityIdentifier("registration.alreadyRegistered")
                // Source goMySignups: an entry only, never an automatic redirect.
                if let mySignupsDestination {
                    NavigationLink { mySignupsDestination() } label: { Text("registration.w206.viewMySignups") }
                        .accessibilityIdentifier("registration.viewMySignups")
                }
            }
        }
    }
    /// Ticket card: cover tile, activity name, date + venue, perforation, selected ticket and its price.
    private var activitySection: some View {
        let checkout = RegistrationCheckoutFacts(activity: flow.activity, ticket: flow.selectedTicket)
        let copy = CoreLoopCopy(locale: locale)
        let summary = flow.activity.summary
        let name = summary.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let start = summary.startDate.flatMap { $0.isEmpty ? nil : $0 }
        let dateText = QuestifyCardText.date(start, locale: locale, displayTimeZone: .current) ?? start
        return Section {
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: CYSpacing.md) {
                    Color.clear.frame(width: 72, height: 72)
                        .overlay { E1CoverArt(seed: name, symbol: "ticket", imageURL: summary.imageURL, debugLabel: false) }
                        .clipShape(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        if name.isEmpty { Text("registrationParity.activityNamePending").font(CYTypography.cardTitle) }
                        else { Text(verbatim: name).font(CYTypography.cardTitle).lineLimit(2) }
                        if let dateText {
                            Label { Text(verbatim: dateText) } icon: { Image(systemName: "calendar") }
                                .font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                        }
                        // Source: the session's 集合点 row appears only when the selected ticket supplies it.
                        if let meetingPoint = checkout.meetingPoint {
                            Label { Text("registrationParity.meetingPointValue \(meetingPoint)") } icon: { Image(systemName: "flag") }
                                .font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                                .accessibilityIdentifier("registration.activity.meetingPoint")
                        }
                        Label {
                            if let venue = checkout.venue { Text(verbatim: venue) } else { Text(verbatim: "—") }
                        } icon: { Image(systemName: "mappin.and.ellipse") }
                            .font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                            .accessibilityIdentifier("registration.activity.venue")
                    }
                    Spacer(minLength: 0)
                }
                .padding(CYSpacing.lg)
                E1Perforation()
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: copy.t("票种", "Ticket")).font(CYTypography.meta).foregroundStyle(CYColor.textTertiary)
                        Text(verbatim: flow.selectedTicket?.name ?? "—").font(CYTypography.bodyMedium).foregroundStyle(CYColor.textPrimary)
                    }
                    Spacer(minLength: CYSpacing.sm)
                    Text(verbatim: ticketPriceText(copy)).font(CYTypography.dataXL).foregroundStyle(CYColor.textPrimary)
                        .minimumScaleFactor(0.7).lineLimit(1).layoutPriority(1)
                }
                .padding(CYSpacing.lg)
                .accessibilityElement(children: .combine)
            }
            .background(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous).fill(CYColor.bgElevated))
            .overlay(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous).stroke(CYColor.borderSubtle))
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0)).listRowBackground(Color.clear)
        } header: { E1IconHeader(systemImage: "calendar", title: copy.t("活动信息", "Activity")) }
    }
    private func ticketPriceText(_ copy: CoreLoopCopy) -> String {
        guard let ticket = flow.selectedTicket else { return "—" }
        if ticket.price == 0 { return copy.t("免费", "Free") }
        return E1Money.yuan(ticket.price, locale: locale) ?? "—"
    }
    /// Total shown in the pinned summary bar: the server quote when present, else the listed ticket price.
    private var summaryTotalText: String {
        let copy = CoreLoopCopy(locale: locale)
        if flow.quoteEnabled, case .received(let quote) = flow.quoteState {
            if let text = E1Money.yuan(quote.payAmount, locale: locale) { return text }
            return "—"
        }
        return ticketPriceText(copy)
    }
    private var showsCheckoutBar: Bool {
        if !flow.hasCurrentSession || flow.hasRetainedIntent { return false }
        if case .pending = flow.durableCreation { return false }
        return true
    }
    /// One-line, human reason why the primary button cannot proceed yet (nil when it can).
    private func blockReason(_ copy: CoreLoopCopy) -> String? {
        guard let block = flow.confirmationBlock else { return nil }
        switch block {
        case .missingConsent: return copy.t("请先勾选上方的确认项", "Tick the confirmation above to continue")
        case .invalidForm: return copy.t("请先补全参与人信息", "Complete the participant details to continue")
        case .soldOut: return copy.t("该票种已售罄", "This ticket is sold out")
        case .signupClosed: return copy.t("报名已截止", "Registration is closed")
        case .quoteUnavailable: return copy.t("正在核对价格…", "Checking the price…")
        case .paymentRequired: return copy.t("这笔报名需要付款，当前只开放免费报名", "This sign-up needs payment. Only a free sign-up is open")
        case .intentAlreadySubmitted: return copy.t("已提交报名", "Already submitted")
        default: return copy.t("暂时无法继续", "Not available right now")
        }
    }
    @State private var blockedTaps = 0
    private var checkoutBar: some View {
        let copy = CoreLoopCopy(locale: locale)
        return VStack(spacing: CYSpacing.sm) {
            HStack(spacing: CYSpacing.md) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: copy.t("合计", "Total")).font(CYTypography.meta).foregroundStyle(CYColor.textTertiary)
                    Text(verbatim: summaryTotalText).font(CYTypography.dataXL).foregroundStyle(CYColor.textPrimary)
                        .lineLimit(1).minimumScaleFactor(0.6).layoutPriority(1)
                }
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    let blocked = flow.confirmationBlock != nil
                    Button {
                        focusedField = nil
                        if blocked { blockedTaps += 1; return }
                        if flow.prepareConfirmation() { showingConfirmation = true }
                    } label: { Text("registration.form.review").frame(maxWidth: .infinity, minHeight: 44) }
                    .buttonStyle(.cyPrimary)
                    // Blocked keeps the full primary look (never a grey slab); the flow ignores the tap and the reason sits below.
                    .cyHaptic(.warning, trigger: blockedTaps)
                    .accessibilityAddTraits(blocked ? .isButton : [])
                    .accessibilityHint(blockReason(copy) ?? "")
                    .accessibilityIdentifier("registration.form.review")
                }
            }
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                if let reason = blockReason(copy) {
                    Label { Text(verbatim: reason) } icon: { Image(systemName: "info.circle") }
                        .font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("registration.form.blockReason")
                }
            }
        }
        .padding(.horizontal, CYSpacing.lg).padding(.vertical, CYSpacing.md)
        .background(.bar)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }
    private var participantSection: some View {
        Section {
            if participantReader?.isConfigured == false {
                Text("auth.notConfigured")
            } else if flow.participantsState == .loading {
                CYLoadingStateView(rows: 1).accessibilityLabel(Text("registration.form.loadingParticipants"))
            } else if flow.participantsState == .unavailable {
                Text("registration.form.participantReadFailed").foregroundStyle(.secondary)
                CYPillButton("registration.form.reloadParticipants", style: .secondary) { Task { await flow.loadParticipants() } }
                    .accessibilityIdentifier("registration.form.reloadParticipants")
            } else if flow.participantProjectionIsCurrent, !flow.participants.isEmpty {
                Picker("registration.form.savedParticipant", selection: Binding<Int?>(
                    get: { flow.selectedParticipantID },
                    set: { if let id = $0 { flow.selectParticipant(id: id) } else { flow.useManualEntry() } }
                )) {
                    Text("registration.form.manualEntry").tag(Optional<Int>.none)
                    ForEach(flow.participants) { participant in
                        Text(verbatim: participant.fullName).tag(Optional(participant.id))
                    }
                }.accessibilityIdentifier("registration.form.participantPicker")
            }
            if let participantReader, let participantCoordinator,
               participantReader.identity != nil, participantReader.identity == participantCoordinator.identity {
                if case .outcomeUnknown = participantCoordinator.state {
                    Button { focusedField = nil; showingAddParticipant = true } label: {
                        Text("participant.recovery.inspect", tableName: "ProfileParticipantRecovery")
                    }.disabled(!flow.canEdit).accessibilityIdentifier("registration.form.inspectParticipant")
                } else if participantReader.isConfigured, participantCoordinator.canPrepare {
                    CYPillButton("participant.form.add", style: .secondary) { focusedField = nil; showingAddParticipant = true }
                        .disabled(!flow.canEdit).accessibilityIdentifier("registration.form.addParticipant")
                }
            }
            TextField("registration.form.name", text: Binding(get: { flow.draft.realName }, set: flow.setName))
                .textContentType(.name).textInputAutocapitalization(.words)
                .focused($focusedField, equals: .name).submitLabel(.next)
                .onSubmit { focusedField = .phone }
                .accessibilityIdentifier("registration.form.name")
            TextField("registration.form.phone", text: Binding(get: { flow.draft.phone }, set: flow.setPhone))
                .textContentType(.telephoneNumber).keyboardType(.phonePad)
                .focused($focusedField, equals: .phone)
                .accessibilityIdentifier("registration.form.phone")
            if !flow.draft.phone.isEmpty, flow.draft.validation == .invalidPhone {
                Text("registration.form.phoneHint").font(.caption).foregroundStyle(CYColor.dangerText)
            }
        } header: { E1IconHeader(systemImage: "person.crop.circle", title: CoreLoopCopy(locale: locale).t("参与人信息", "Participant")) }
        .disabled(!flow.canEdit)
    }
    private var ticketSection: some View {
        Section {
            if flow.activity.tickets.isEmpty {
                Text("registration.form.noTickets").foregroundStyle(.secondary)
            } else {
                Picker("registration.form.ticket", selection: Binding<Int?>(
                    get: { flow.selectedTicketID },
                    set: { if flow.selectTicket(id: $0) { Task { await flow.requestQuote() } } }
                )) {
                    ForEach(flow.activity.tickets) { ticket in
                        Text(verbatim: ticket.name).tag(Optional(ticket.id))
                    }
                }.disabled(!flow.canEdit).accessibilityIdentifier("registration.form.ticketPicker")
                if let ticket = flow.selectedTicket {
                    RegistrationAmountRow(key: "registration.form.ticketPrice", amount: ticket.price)
                    if let description = ticket.description, !description.isEmpty { Text(verbatim: description) }
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        if flow.signupClosed {
                            Text("registration.form.signupClosed").foregroundStyle(.secondary)
                                .accessibilityIdentifier("registration.form.signupClosed")
                        }
                    }
                    if ticket.isSoldOut {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text(LocalizedStringKey(RegistrationUIWaitlistGuidance.soldOutKey(
                                available: flow.waitlistAvailable, status: flow.waitlistStatus,
                                outcomeUnknown: flow.waitlistOutcomeUnknown, now: context.date)))
                                .foregroundStyle(.secondary).accessibilityIdentifier("registration.form.soldOutGuidance")
                        }
                    } else if ticket.remainingInventory == nil {
                        Text("registration.form.inventoryUnknown").foregroundStyle(.secondary)
                    }
                }
            }
        } header: { E1IconHeader(systemImage: "ticket", title: CoreLoopCopy(locale: locale).t("票种", "Ticket")) }
    }
    @ViewBuilder private var waitlistSection: some View {
        if flow.selectedTicket?.isSoldOut == true || flow.waitlistStatus != nil {
            Section {
                if !flow.waitlistAvailable {
                    Text("registration.waitlist.disabled").foregroundStyle(.secondary)
                } else {
                    if flow.isReadingWaitlist || flow.isMutatingWaitlist { CYLoadingStateView(rows: 1).accessibilityLabel(Text("registration.waitlist.loading")) }
                    if flow.waitlistOutcomeUnknown { Text("registration.waitlist.unknown").foregroundStyle(.secondary) }
                    if let status = flow.waitlistStatus {
                        Text(LocalizedStringKey("registration.waitlist.state." + status.state.rawValue))
                        if status.eligibility != .eligible {
                            Text(LocalizedStringKey("registration.waitlist.eligibility." + status.eligibility.rawValue)).foregroundStyle(.secondary)
                        }
                        if status.state == .offered, let deadline = status.expiresAt {
                            TimelineView(.periodic(from: .now, by: 1)) { context in
                                if deadline > context.date {
                                    LabeledContent("registration.waitlist.remaining") {
                                        Text(timerInterval: context.date...deadline, countsDown: true).monospacedDigit()
                                    }
                                } else { Text("registration.waitlist.state.EXPIRED") }
                            }
                            CYPillButton("registration.waitlist.reviewOffer", style: .secondary) { Task { await flow.reviewWaitlistOffer() } }
                                .disabled(!flow.canEdit || flow.isReadingWaitlist)
                                .accessibilityIdentifier("registration.waitlist.reviewOffer")
                        }
                        if status.registrationID != nil {
                            if let destination = flow.waitlistOrderDestination, let orderReader {
                                CYPillButton("profile.orders.detail", style: .secondary) {
                                    guard scenePhase == .active, orderDestination == nil, resultOrderDestination == nil, recoveredOrderDestination == nil,
                                          flow.waitlistOrderDestination == destination, orderReader.isConfigured,
                                          orderReader.identity?.accountID == destination.identity.accountID,
                                          orderReader.identity?.epoch == destination.identity.epoch else { return }
                                    if let presentation = RegistrationWaitlistOrderPresentation(destination: destination, readIdentity: orderReader.identity) {
                                        orderDestination = .init(presentation: presentation)
                                    }
                                }
                                .disabled(scenePhase != .active || !orderReader.isConfigured || orderReader.identity?.accountID != destination.identity.accountID || orderReader.identity?.epoch != destination.identity.epoch)
                                .accessibilityIdentifier("registration.waitlist.openOrder")
                            }
                        }
                    } else if flow.block == .waitlistUnavailable { Text("registration.waitlist.unavailable") }
                    CYPillButton("registration.waitlist.refresh", style: .secondary) { Task { await flow.loadWaitlist() } }
                        .disabled(!flow.canEdit || flow.isReadingWaitlist)
                        .accessibilityIdentifier("registration.waitlist.refresh")
                    if let ticket = flow.selectedTicket {
                        // §27.6 request a host; the result is the reread waitlist state, never this reply.
                        ClubHostRequestButton(activityID: flow.activity.summary.id, ticketID: ticket.id,
                                              reload: { Task { await flow.loadWaitlist() } })
                    }
                    if flow.canJoinWaitlist {
                        CYPillButton("registration.waitlist.join", style: .secondary) { Task { await flow.joinWaitlist() } }
                            .accessibilityIdentifier("registration.waitlist.join")
                    }
                    if flow.canCancelWaitlist {
                        Button("registration.waitlist.cancel", role: .destructive) {
                            if flow.prepareWaitlistCancellation() { showingWaitlistCancellation = true }
                        }
                            .accessibilityIdentifier("registration.waitlist.cancel")
                    }
                }
            } header: { Text("registration.waitlist.title") } footer: { Text("registration.waitlist.noAutoPayment") }
        }
    }
    private func reloadCoupons() async {
        guard let couponUsability else {
            couponPhase = .empty
            return
        }
        couponPhase = .loading
        do {
            let rows = try await couponUsability()
            if Task.isCancelled { return }
            couponPhase = rows.isEmpty ? .empty : .ready(rows)
        } catch is CancellationError {
            return
        } catch {
            couponPhase = .failed
        }
    }
    private var quoteSection: some View {
        Section {
            // Source 订单金额 is the selected ticket's listed price; unknown stays unknown.
            // Source k9 p1 N-11: 订单金额 only appears when a deduction row follows; with no quote it is the only amount.
            if flow.selectedTicket != nil && showsOrderAmount {
                RegistrationAmountRow(key: "registrationParity.orderAmount",
                    amount: RegistrationCheckoutFacts(activity: flow.activity, ticket: flow.selectedTicket).orderAmount)
            }
            if !flow.quoteEnabled {
                Text("registration.form.quoteDisabled").foregroundStyle(.secondary)
            } else if flow.isQuoting {
                CYLoadingStateView(rows: 1).accessibilityLabel(Text("registration.form.quoting")).accessibilityIdentifier("registration.form.quoting")
            } else {
                switch flow.quoteState {
                case .received(let quote):
                    if Self.positive(quote.memberDiscountYuan) {
                        RegistrationAmountRow(key: "registration.form.memberDiscount", amount: quote.memberDiscountYuan, deduction: true, currencyCode: RegistrationUIMoney.yuanCurrencyCode)
                    }
                    if let note = RegistrationCheckoutClubBenefit.from(quote)?.noteKey {
                        LabeledContent("registrationParity.clubBenefit") { Text(LocalizedStringKey(note)) }
                            .accessibilityIdentifier("registration.fees.clubBenefit")
                    }
                    if Self.positive(quote.couponDeductYuan) {
                        RegistrationAmountRow(key: "registration.form.couponDiscount", amount: quote.couponDeductYuan, deduction: true, currencyCode: RegistrationUIMoney.yuanCurrencyCode)
                    }
                    // Source R11 p1 F-10 / P-32: no points (or a ¥0 ticket) means no points row at all, never "−¥0".
                    if showsPointsRow(quote) {
                        RegistrationAmountRow(key: "registration.form.pointsDiscount", amount: quote.pointsDeductYuan, deduction: true, currencyCode: RegistrationUIMoney.yuanCurrencyCode)
                        if flow.usePoints {
                            LabeledContent("registration.form.pointsUsed") {
                                Text(verbatim: String(quote.pointsUsed)).monospacedDigit().foregroundStyle(CYColor.textPrimary)
                            }
                        }
                        Toggle("registration.form.usePoints", isOn: Binding(
                            get: { flow.usePoints },
                            set: { if flow.setUsePoints($0) { Task { await flow.requestQuote() } } }
                        )).disabled(!flow.canEdit).accessibilityIdentifier("registration.form.usePoints")
                    }
                    // OWN-D-01.b: the server quoted no deduction, so the toggle went off. Say which of the two reasons applies.
                    if let refusal = flow.pointsRefusal {
                        Text(LocalizedStringKey(refusal.localizationKey)).font(.caption).foregroundStyle(CYColor.textSecondary)
                            .accessibilityIdentifier("registration.form.pointsRefusal")
                    }
                    RegistrationAmountRow(key: "registration.form.total", amount: quote.payAmount)
                        .font(CYTypography.cardTitle).monospacedDigit().accessibilityIdentifier("registration.form.total")
                    if let refundNotice = NonRefundable24hNotice.feeRowNotice(for: quote) {
                        Text(verbatim: CoreLoopCopy(locale: locale).tr(refundNotice))
                            .font(.caption)
                            .foregroundStyle(quote.requiresNonRefundableConfirmation ? CYColor.warningText : CYColor.textTertiary)
                            .accessibilityIdentifier("registration.fees.refundPolicy")
                    }
                    if !quote.isUsableForCreate { Text("registration.form.incompleteQuote").foregroundStyle(.secondary) }
                case .unavailable(let issue):
                    Text("registration.form.quoteFailed").foregroundStyle(.secondary)
                    RegistrationIssueText(issue: issue)
                case .idle, .loading:
                    Text("registration.form.quoteNeeded").foregroundStyle(.secondary)
                }
            }
            CYPillButton("registration.form.refreshQuote", style: .secondary) { Task { await flow.requestQuote() } }
                .disabled(!flow.quoteEnabled || !flow.canEdit || flow.isQuoting)
                .accessibilityIdentifier("registration.form.refreshQuote")
        } header: { E1IconHeader(systemImage: "yensign.circle", title: CoreLoopCopy(locale: locale).t("费用明细", "Price details")) }
    }
    private static func positive(_ amount: Decimal?) -> Bool { (amount ?? .zero) > .zero }
    private func showsPointsRow(_ quote: RegistrationQuote) -> Bool {
        // Source also hides the row when the viewer's point balance is 0; the quote carries no balance yet (Cursor).
        quote.pointsUsable && Self.positive(flow.selectedTicket?.price)
    }
    private var showsOrderAmount: Bool {
        guard flow.quoteEnabled, case .received(let quote) = flow.quoteState else { return true }
        return Self.positive(quote.memberDiscountYuan) || Self.positive(quote.couponDeductYuan) || showsPointsRow(quote)
    }
    /// Source 退款规则 (hengyin bde2745d0 / a34ba30c4): every paid ticket lists the platform's three tiers, read-only.
    /// Self-guided (mode 2) tickets count from the ticket start, others from the meeting time.
    @ViewBuilder private var refundTiersSection: some View {
        if let ticket = flow.selectedTicket, Self.positive(ticket.price) {
            let clock = ticket.selfGuided == true ? "mpfresh.registration.refund.beforeStart" : "mpfresh.registration.refund.beforeMeet"
            Section {
                LabeledContent {
                    Text("mpfresh.registration.refund.full", tableName: "MpFresh").foregroundStyle(CYColor.textPrimary)
                } label: { Text("mpfresh.registration.refund.over24 \(Text(LocalizedStringKey(clock), tableName: "MpFresh"))", tableName: "MpFresh") }
                .accessibilityElement(children: .combine).accessibilityIdentifier("registration.refundTiers.over24")
                LabeledContent {
                    Text("mpfresh.registration.refund.half \(50)", tableName: "MpFresh").foregroundStyle(CYColor.textPrimary)
                } label: { Text("mpfresh.registration.refund.within24 \(Text(LocalizedStringKey(clock), tableName: "MpFresh"))", tableName: "MpFresh") }
                .accessibilityElement(children: .combine).accessibilityIdentifier("registration.refundTiers.within24")
                LabeledContent {
                    Text("mpfresh.registration.refund.none", tableName: "MpFresh").foregroundStyle(CYColor.textPrimary)
                } label: { Text("mpfresh.registration.refund.afterStart", tableName: "MpFresh") }
                .accessibilityElement(children: .combine).accessibilityIdentifier("registration.refundTiers.afterStart")
            } header: {
                E1IconHeader(systemImage: "arrow.uturn.backward.circle", title: String(localized: LocalizedStringResource("mpfresh.registration.refund.title", table: "MpFresh", locale: locale)))
            }
        }
    }
    private var confirmationSection: some View {
        Section {
            if flow.creationPolicy.permitsCreation {
                if case .approved(let grant) = flow.creationPolicy {
                    Link("registration.waitlist.legalNotice", destination: grant.noticeURL)
                    if let complianceSignupDestination {
                        NavigationLink { complianceSignupDestination() } label: { Text("compliance.title") }
                    }
                }
                Toggle(LocalizedStringKey(flow.creationPolicy.isOfflineFixture ? "registration.form.fixtureConsent" : "registration.waitlist.reviewConsent"), isOn: Binding(get: { flow.consented }, set: flow.setConsent))
                    .disabled(!flow.canEdit).accessibilityIdentifier("registration.form.consent")
                if flow.creationPolicy.recordsServerConsent {
                    CYPillButton("registration.waitlist.recordConsent", style: .secondary) { Task { await flow.recordSignupConsent() } }
                        .disabled(!flow.canEdit || !flow.consented)
                        .accessibilityIdentifier("registration.waitlist.recordConsent")
                    if flow.isRecordingConsent { CYLoadingStateView(rows: 1).accessibilityLabel(Text("registration.waitlist.recordingConsent")) }
                    if flow.block == .missingConsent { Text("registration.waitlist.consentUnknown").foregroundStyle(.secondary) }
                }
            } else {
                Label("registration.form.creationDisabled", systemImage: "lock")
                    .accessibilityIdentifier("registration.form.creationDisabled")
                Text("registration.form.creationDisabledHint").font(.callout).foregroundStyle(.secondary)
                if let complianceSignupDestination {
                    NavigationLink { complianceSignupDestination() } label: { Text("compliance.title") }
                        .accessibilityIdentifier("compliance.signup.reviewSource")
                }
            }
            if flow.block == .confirmationChanged { Text("registration.form.confirmationChanged").foregroundStyle(.secondary) }
        } footer: { Text("registration.form.sharingPurpose") }
    }
}

private struct RegistrationAmountRow: View {
    @Environment(\.locale) private var locale
    let key: String
    let amount: Decimal?
    var deduction = false
    var currencyCode: String? = nil
    var body: some View {
        LabeledContent {
            if let text = RegistrationUIMoney.display(amount, locale: locale, currencyCode: currencyCode) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(verbatim: deduction && amount != .zero ? "−\(text)" : text)
                        .monospacedDigit().foregroundStyle(CYColor.textPrimary).accessibilityIdentifier(key + ".amount")
                    if currencyCode == nil { Text("registration.form.currencyUnknown").font(.caption).foregroundStyle(.primary) }
                }
            } else { Text("registration.form.unknownAmount").foregroundStyle(Color.primary) }
        } label: { Text(LocalizedStringKey(key)) }
    }
}

/// Do not display arbitrary Error descriptions, quote signatures, provider parameters,
/// credentials or contact fields. Verified structured server messages remain available.
private struct RegistrationIssueText: View {
    @Environment(\.locale) private var locale
    let issue: RegistrationCoordinatorIssue
    private var message: String? {
        switch issue {
        case .business(let failure): return failure.message
        case .http(let failure): return failure.response?.message
        default: return nil
        }
    }
    var body: some View {
        if let message, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text(verbatim: CoreLoopCopy(locale: locale).tr(message)).font(.callout).foregroundStyle(.secondary)
        }
    }
}

@MainActor
private struct RegistrationOperationSections: View {
    let flow: RegistrationUIFlow
    let revision:UInt64
    var orderReader: (any ProfileReading)? = nil
    var body: some View {
        if flow.retainedForAnotherActivity {
            Section { Text("registration.form.otherActivityIntent").foregroundStyle(.secondary) }
        }
        switch flow.creationState {
        case .idle: EmptyView()
        case .submitting:
            Section { CYLoadingStateView(rows: 1).accessibilityLabel(Text("registration.form.creating")) }
        case .outcomeUnknown:
            Section("registration.form.outcomeUnknown") {
                Text("registration.form.outcomeUnknownHint")
                    .accessibilityIdentifier("registration.form.outcomeUnknown")
                Text("registration.form.retainedIntentHint").font(.caption).foregroundStyle(.secondary)
                if let orderReader { RegistrationUncertainOrdersCheck(flow: flow, reader: orderReader) }
            }
        case .responseReceived(_, let result):
            Section("registration.form.createdResponse") {
                LabeledContent("registration.form.registrationID", value: String(result.registrationID))
                if let number = result.registrationNo, !number.isEmpty {
                    LabeledContent("registration.form.registrationNumber", value: number)
                }
                RegistrationAmountRow(key: "registration.form.total", amount: result.payableAmount)
                Text(LocalizedStringKey(result.hasPaymentParameters ? "registration.form.paymentNotStarted" : "registration.form.noPaymentProof"))
                    .foregroundStyle(.secondary)
                CYPillButton("registration.form.readStatus", style: .secondary) { Task { await flow.readKnownStatus() } }
                    .disabled(!flow.canReadStatus).accessibilityIdentifier("registration.form.readStatus")
                Text("registration.form.retainedIntentHint").font(.caption).foregroundStyle(.secondary)
            }
        }
        switch flow.readbackState {
        case .idle: EmptyView()
        case .loading: Section { CYLoadingStateView(rows: 1).accessibilityLabel(Text("registration.form.readingStatus")) }
        case .unavailable(_, let issue):
            Section {
                Text("registration.form.statusUnavailable")
                RegistrationIssueText(issue: issue)
            }
        case .received(let snapshot):
            Section("registration.form.serverStatus") {
                LabeledContent("registration.form.registrationStatus") {
                    Text(LocalizedStringKey(RegistrationUIStatus.registrationKey(snapshot.registrationStatus)))
                }
                statusRow("registration.form.registrationCode", snapshot.registrationStatus)
                statusRow("registration.form.paymentCode", snapshot.paymentStatus)
                statusRow("registration.form.verificationCode", snapshot.verificationStatus)
            }.accessibilityIdentifier("registration.form.statusSnapshot")
        }
    }
    private func statusRow(_ key: String, _ code: Int?) -> some View {
        LabeledContent {
            if let code { Text(verbatim: String(code)) }
            else { Text("registration.form.unknownStatus") }
        } label: { Text(LocalizedStringKey(key)) }
    }
}


/// One read-only look at the viewer's own orders after an unknown create outcome. A match is
/// not proof of this submission, so the retained request stays locked and nothing is retried.
@MainActor
private struct RegistrationUncertainOrdersCheck: View {
    let flow: RegistrationUIFlow
    let reader: any ProfileReading
    @Environment(\.scenePhase) private var scenePhase
    @State private var cache = RegistrationUncertainEvidenceCache()
    private var scope: RegistrationUncertainEvidenceScope? {
        .capture(flow: flow, reader: reader, isActive: scenePhase == .active)
    }
    var body: some View {
        let currentScope = scope
        let current = cache.isCurrent(currentScope)
        let evidence = current ? cache.evidence : nil
        let reading = current && cache.reading
        let failed = current && cache.failed
        CYPillButton("registration.w206.checkOrders", style: .secondary) {
            guard let capturedScope = scope else { return }
            let token = cache.begin(capturedScope)
            Task {
                do {
                    let result = try await flow.uncertainOutcomeEvidence(orders: reader)
                    try Task.checkCancellation()
                    cache.finish(result, for: token, current: scope)
                } catch {
                    cache.fail(for: token, current: scope, cancelled: error is CancellationError)
                }
            }
        }.disabled(currentScope == nil || reading || evidence != nil).accessibilityIdentifier("registration.checkOrders")
        .onChange(of: currentScope) { _, _ in cache.clear() }
        .onDisappear { cache.clear() }
        if reading { CYLoadingStateView(rows: 1).accessibilityLabel(Text("registration.form.readingStatus")) }
        if failed { Text("registration.w206.checkOrdersFailed").accessibilityIdentifier("registration.checkOrders.failed") }
        switch evidence {
        case .noMatchingOrder?:
            Text("registration.w206.noMatchingOrder").accessibilityIdentifier("registration.checkOrders.none")
        case .matchingOrders(let ids)?:
            Text("registration.w206.matchingOrders \(ids.count)").accessibilityIdentifier("registration.checkOrders.matches")
            ForEach(ids, id: \.self) { id in
                LabeledContent("registration.form.registrationID", value: String(id))
            }
            Text("registration.w206.matchNotProof").font(.caption).foregroundStyle(.secondary)
        case .notApplicable?, nil: EmptyView()
        }
    }
}

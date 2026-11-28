import SwiftUI

/// Design fixtures (`t5-baoming`) render as a screenshot of the real page: the 离线演示 note is hidden there while
/// the offline-fixture creation policy still keeps every write offline. UI-test fixtures keep the note.
private struct RegistrationHidesFixtureNoticeKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var registrationHidesFixtureNotice: Bool {
        get { self[RegistrationHidesFixtureNoticeKey.self] }
        set { self[RegistrationHidesFixtureNoticeKey.self] = newValue }
    }
}

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
    /// Design fixtures only (offline bundled MP cover); production never sets it.
    @Environment(\.e1ActivityHeroFixtureCover) private var fixtureCover
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.offlineWriteSession) private var offlineWriteSession
    @Environment(\.registrationHidesFixtureNotice) private var hidesFixtureNotice
    /// R11-PC-C-3: marketing-consent opt-in after a successful create (MP baoming.wxml:345-351).
    @Environment(\.marketingConsentService) private var marketingConsentService
    @StateObject private var model: RegistrationSheetModel
    @FocusState private var focusedField: Field?
    @State private var showingConfirmation = false
    @State private var showingNonRefundable = false
    @State private var nonRefundableConfirmed = false
    @State private var showingWaitlistCancellation = false
    @State private var showingAddParticipant = false
    @State private var showingTicketSheet = false
    @State private var showingParticipantSheet = false
    /// MP cy-empty 新增参与人信息 in the participant sheet: the add form opens once the sheet has closed.
    @State private var addAfterParticipantSheet = false
    @State private var showingPaymentPending = false
    @State private var toastMessage: String?
    /// Last `payment-readiness` answer for the selected paid ticket (acceptance R2 F-02).
    @State private var paymentReadiness: RegistrationPaymentReadiness?
    @State private var orderDestination: RegistrationWaitlistOrderVisit?
    @State private var resultOrderDestination: RegistrationResultOrderPresentation?
    @State private var recoveredOrderDestination: RegistrationRecoveredOrderPresentation?
    private let participantReader: (any ProfileReading)?
    private let orderReader: (any ProfileReading)?
    /// MP `baoming?ticketId=` (R7-PC-C2-3): the ticket the link names is selected when the sheet opens.
    private var preselectedTicketID: Int? = nil
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
         preselectedTicketID: Int? = nil,
         onReadback: @escaping (RegistrationStatusSnapshot) -> Void = { _ in }) {
        self.orderReader = orderReader
        self.preselectedTicketID = preselectedTicketID
        self.participantReader = participantReader; self.participantCoordinator = participantCoordinator
        self.couponUsability = couponUsability
        _model = StateObject(wrappedValue: RegistrationSheetModel(flow: {
            let flow = RegistrationUIFlow(
                activity: activity, coordinator: coordinator, participantReader: participantReader,
                currentIdentity: currentIdentity, quoteEnabled: quoteEnabled,
                creationPolicy: creationPolicy, waitlistService: waitlistService, onReadback: onReadback)
            flow.availablePoints = availablePoints
            // MKT-2-1: a pass's 去报名 starts on the pass ticket (MP `baoming?ticketId`); unknown ids are ignored.
            if let preselectedTicketID { flow.selectTicket(id: preselectedTicketID) }
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
                if flow.creationPolicy.isOfflineFixture && !hidesFixtureNotice {
                    Section { Label("registration.form.fixtureNotice", systemImage: "testtube.2").cyText(.body) }
                }
                if !flow.hasCurrentSession {
                    Section { Label("registration.form.sessionChanged", systemImage: "person.crop.circle.badge.exclamationmark") }
                } else {
                    // Source checkout banner: shown, never blocking (the viewer may register someone else).
                    CYScreenOfflineWriteSection(
                        routes: ["/api/registration/create", "/api/compliance/consents"],
                        session: offlineWriteSession.session
                    )
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
                            if flow.isReadingStatus { CYLoadingStateView(rows: 1, label: "registration.form.readingStatus") }
                            if flow.durableStatusFailed {
                                Text("registration.form.statusUnavailable")
                                    .accessibilityIdentifier("registration.recovered.statusUnavailable")
                                if let row = RequestReferenceRow(pathFragment: "/api/registration/info") { row }
                            }
                            if let snapshot = flow.durableStatus {
                                Text(LocalizedStringKey(RegistrationUIStatus.registrationKey(snapshot.registrationStatus)))
                            }
                        }
                        if case .pending(let regID?) = flow.durableCreation, let snapshot = flow.durableStatus, snapshot.paymentStatus != 2 {
                            RegistrationPaySection(
                                registrationID: regID,
                                payableAmount: flow.selectedTicket?.price,
                                quote: flow.quoteState.quoteValue,
                                quoteReceivedAt: flow.currentQuoteReceivedAt,
                                consented: flow.consented,
                                requiresFreshQuote: false,
                                channel: .standard,
                                onExpiredRebuild: { Task { await flow.requestQuote() } }
                            )
                        }
                        recoveredOrderSection
                    } else {
                        // Source order (MP baoming.wxml top-to-bottom): 参与人信息 → 活动信息 → 报名已截止 →
                        // 优惠 → 费用明细 (票种 → 儿童年龄 → 订单金额 → 权益 → 原价/减免 → 通行证 → 积分 → 总计) →
                        // 包含内容 → 退款规则 → 主持预约 → 候补 → 底栏 (商家暂停营业 → 信息共享同意 → 提交).
                        // MP baoming has no coupon block, so the read-only coupon list is not drawn here.
                        if flow.activity.tickets.isEmpty {
                            noTicketsBlock
                        } else {
                        participantSection
                        activitySection
                        signupClosedBlock
                        if flow.selectedTicket != nil {
                            G6PromotionCatalogSection(activityID: flow.activity.summary.id,
                                                      rewardCouponName: flow.quoteState.quoteValue?.completeRewardCouponName)
                        }
                        ticketSection
                        childAgeSection
                        quoteSection
                        deliverySection
                        refundTiersSection
                        hostReservationSection
                        waitlistSection
                        // R11-PC-C-5: a quote that lists channels without APP skips the readiness probe (MP quote-view.js:79-84).
                        // MP shows readiness on the pay button (检查支付服务… / 重新检查支付服务), so it sits by the footer.
                        RegistrationPaymentReadinessSection(price: flow.quoteState.quoteValue?.paymentChannelUnavailable == true ? nil : flow.selectedTicket?.price,
                                                            onResult: { paymentReadiness = $0 })
                        merchantClosedSection
                        confirmationSection
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .modifier(G6PromotionCatalogLoader(activityID: flow.activity.summary.id))
            .safeAreaInset(edge: .bottom, spacing: 0) { if showsCheckoutBar { checkoutBar } }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .themeDomain(.player)
            .cyDomainPageBackground()
            .appNavigationTitle("registration.form.title")
            .navigationBarTitleDisplayMode(.inline)
            // verify-r1 3.9 / D-06 (Figma 169:5885, Player/Sheet; owner Q10 keeps three header styles): grabber, the
            // 20 Bold title on the left, a round ✕ on the right. Not a 关闭 text pill with a centred title.
            .modifier(RegistrationPlayerSheetHeader(onClose: { flow.leave(); dismiss() }))
            .overlay { registrationPopups }
            .cyToast(verbatimMessage: $toastMessage)
            .sheet(isPresented: $showingTicketSheet) { ticketSheetContent }
            .sheet(isPresented: $showingParticipantSheet, onDismiss: {
                if addAfterParticipantSheet { addAfterParticipantSheet = false; showingAddParticipant = true }
            }) { participantSheetContent }
            .background { systemDialogs }
            .modifier(RegistrationOrderAndLifecycleModifier(
                flow: flow,
                preselectedTicketID: preselectedTicketID,
                orderReader: orderReader,
                participantReader: participantReader,
                participantCoordinator: participantCoordinator,
                scenePhase: scenePhase,
                orderDestination: $orderDestination,
                resultOrderDestination: $resultOrderDestination,
                recoveredOrderDestination: $recoveredOrderDestination,
                showingAddParticipant: $showingAddParticipant,
                showingWaitlistCancellation: $showingWaitlistCancellation,
                showingConfirmation: $showingConfirmation,
                showingNonRefundable: $showingNonRefundable,
                nonRefundableConfirmed: $nonRefundableConfirmed
            ))
        }
        .themeDomain(.player)
        .accessibilityIdentifier("registration.form.sheet")
        .cyDomainScreen(.player)
    }
    /// R10-PC-C-N8: 选择票种 is a system `List` in a `.sheet` (MP baoming.wxml ticket sheet, `openTicketSheet`); it commits on tap.
    private var ticketSheetContent: some View {
        NavigationStack {
            List {
                ForEach(flow.activity.tickets) { ticket in
                    Button {
                        showingTicketSheet = false
                        if flow.selectTicket(id: ticket.id) { Task { await flow.requestQuote() } }
                    } label: {
                        RegistrationPickerRow(title: ticket.name, subtitle: ticketPriceText(ticket.price),
                                              selected: ticket.id == flow.selectedTicketID)
                    }
                    .accessibilityIdentifier("registration.ticketSheet.row.\(ticket.id)")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(PlayCloseCopy.text("选择票种", "Select ticket", locale))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appLocalized("action.cancel", locale: locale)) { showingTicketSheet = false }
                        .accessibilityIdentifier("registration.ticketSheet.close")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    /// R10-PC-C-N8: 选择参与人信息 as a system `List` in a `.sheet`.
    /// MP baoming.wxml:283-309 order: loading / 加载失败 + 重试 → rows → 还没有参与人信息 (新增参与人信息) → footer 管理参与人信息.
    private var participantSheetContent: some View {
        NavigationStack {
            List {
                if flow.participantsState == .loading && flow.participants.isEmpty {
                    ProgressView { Text("registration.form.loadingParticipants") }
                        .frame(maxWidth: .infinity)
                } else if flow.participantsState == .unavailable {
                    // MP baoming.wxml:286 cy-inline-error 参与人信息加载失败 + 重试: one state, retry inside.
                    Section {
                        CYEmptyState(systemImage: "exclamationmark.triangle", "profile.participants.loadFailed",
                                     actionTitle: "action.retry", actionIdentifier: "registration.participantSheet.retry",
                                     kind: .failure) { Task { await flow.loadParticipants() } }
                    }
                }
                ForEach(flow.participants, id: \.id) { row in
                    Button {
                        showingParticipantSheet = false
                        flow.selectParticipant(id: row.id)
                        toastMessage = PlayCloseCopy.text("已选择参与人", "Participant selected", locale)
                    } label: {
                        RegistrationPickerRow(title: row.fullName, subtitle: row.mobilePhone,
                                              selected: row.id == flow.selectedParticipantID)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .overlay {
                if flow.participantsState == .received && flow.participants.isEmpty {
                    ContentUnavailableView {
                        Label("profile.participants.empty", systemImage: "person.crop.circle.badge.plus")
                    } actions: {
                        if canAddParticipant {
                            Button("mpr3.baoming.addParticipant") { addAfterParticipantSheet = true; showingParticipantSheet = false }
                                .buttonStyle(.bordered)
                                .accessibilityIdentifier("registration.participantSheet.add")
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { participantSheetFooter }
            .navigationTitle(PlayCloseCopy.text("选择参与人信息", "Select participant", locale))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appLocalized("action.cancel", locale: locale)) { showingParticipantSheet = false }
                        .accessibilityIdentifier("registration.participantSheet.close")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    private var canAddParticipant: Bool {
        guard let participantReader, let participantCoordinator, participantReader.isConfigured,
              participantReader.identity != nil, participantReader.identity == participantCoordinator.identity else { return false }
        return participantCoordinator.canPrepare && flow.canEdit
    }
    /// MP `cy-sheet` footer 管理参与人信息 → pages/address?mode=participant; the list re-reads on the way back.
    @ViewBuilder private var participantSheetFooter: some View {
        if let participantReader {
            VStack(spacing: 0) {
                Divider()
                NavigationLink {
                    ProfileParticipantsView(reader: participantReader, coordinator: participantCoordinator)
                        .onDisappear { Task { await flow.loadParticipants() } }
                } label: {
                    Text("mpr3.baoming.manageParticipants").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("registration.participantSheet.manage")
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(.bar)
        }
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
                // R11-PC-C-3: MP baoming.js:1300-1368 loads the offer whose owner is the activity host, off by default.
                if let marketingConsentService {
                    MarketingConsentOfferRow(ownerMemberID: flow.activity.hostMemberID, makeService: marketingConsentService)
                }
                if PlayAreaPopupCopy.paymentsOpen {
                    Button {
                        showingPaymentPending = true
                    } label: {
                        Text(verbatim: PlayCloseCopy.text("支付结果待确认", "Payment status pending", locale))
                            .cyText(.caption, weight: .semibold)
                            .foregroundStyle(CYColor.brandStrong)
                    }
                    .accessibilityIdentifier("registration.result.paymentPendingModal")
                }
            }
        }
    }
    @ViewBuilder private var alreadyRegisteredSection: some View {
        if RegistrationCheckoutFacts(activity: flow.activity, ticket: flow.selectedTicket).viewerAlreadyRegistered {
            Section {
                Label("registrationParity.alreadyRegistered", systemImage: "checkmark.seal")
                    .cyText(.cardTitle)
                    .accessibilityIdentifier("registration.alreadyRegistered")
                // Source goMySignups: an entry only, never an automatic redirect.
                if let mySignupsDestination {
                    NavigationLink { mySignupsDestination() } label: { Text("registration.w206.viewMySignups") }
                        .accessibilityIdentifier("registration.viewMySignups")
                }
            }
        }
    }
    /// Activity card: cover tile, activity name, date + venue. MP baoming.wxml (费用明细 note): the ticket row moved
    /// out of this card into 票种 / 费用明细, so the card only answers which activity this is.
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
                        .overlay {
                            if QuestifyCardArtwork.safeURL(summary.imageURL) == nil, let fixtureCover {
                                fixtureCover.resizable().scaledToFill().accessibilityHidden(true)
                            } else {
                                E1CoverArt(seed: name, symbol: "ticket", imageURL: summary.imageURL, debugLabel: false,
                                           fallbackImage: MPAsset.BannerCover.coverRoute, fallbackFills: false) // MP baoming.wxml:85
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        if name.isEmpty { Text("registrationParity.activityNamePending").cyText(.cardTitle) }
                        else { Text(verbatim: name).cyText(.cardTitle).lineLimit(2) }
                        if let dateText {
                            Label { Text(verbatim: dateText) } icon: { Image(systemName: "calendar") }
                                .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                        }
                        // Source: the session's 集合点 row appears only when the selected ticket supplies it.
                        if let meetingPoint = checkout.meetingPoint {
                            Label { Text("registrationParity.meetingPointValue \(meetingPoint)") } icon: { Image(systemName: "flag") }
                                .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                                .accessibilityIdentifier("registration.activity.meetingPoint")
                        }
                        // MP baoming.wxml:100 `onAddressTap`: the venue line opens the map when the activity has a place.
                        if let venue = checkout.venue, let mapURL = venueMapURL(venue) {
                            Link(destination: mapURL) {
                                Label { Text(verbatim: venue) } icon: { Image(systemName: "mappin.and.ellipse") }
                                    .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityHint(Text(verbatim: copy.t("在地图中打开", "Opens in Maps")))
                            .accessibilityIdentifier("registration.activity.venue")
                        } else {
                            Label {
                                if let venue = checkout.venue { Text(verbatim: venue) } else { Text(verbatim: "—") }
                            } icon: { Image(systemName: "mappin.and.ellipse") }
                                .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                                .accessibilityIdentifier("registration.activity.venue")
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(CYSpacing.lg)
            }
            .cyDomainCard(radius: CYRadius.lg, padding: 0)
            .listRowInsets(EdgeInsets(top: CYSpacing.xs, leading: 0, bottom: CYSpacing.xs, trailing: 0)).listRowBackground(Color.clear)
        } header: { E1IconHeader(systemImage: "calendar", title: copy.t("活动信息", "Activity")) }
    }
    /// Apple Maps link for the venue: the activity's coordinate when valid, else an address search (MP `openAddress`).
    private func venueMapURL(_ venue: String) -> URL? {
        let summary = flow.activity.summary
        var parts = URLComponents(string: "https://maps.apple.com/")
        if summary.hasValidCoordinates, let lat = summary.latitude, let lng = summary.longitude {
            parts?.queryItems = [URLQueryItem(name: "ll", value: "\(lat),\(lng)"), URLQueryItem(name: "q", value: venue)]
        } else {
            parts?.queryItems = [URLQueryItem(name: "q", value: venue)]
        }
        return parts?.url
    }
    private func ticketPriceText(_ price: Decimal?) -> String {
        let copy = CoreLoopCopy(locale: locale)
        guard let price, !price.isNaN, price >= .zero else { return copy.t("价格待定", "Price to be confirmed") }
        if price == .zero { return copy.t("免费", "Free") }
        return RegistrationUIMoney.display(price, locale: locale, currencyCode: RegistrationUIMoney.yuanCurrencyCode)
            ?? copy.t("价格待定", "Price to be confirmed")
    }
    private func gatedPayAmount(_ amount: Decimal?) -> String {
        guard let amount else { return "—" }
        if amount > .zero, !PlayAreaPopupCopy.paymentsOpen { return "—" }
        if amount == .zero { return CoreLoopCopy(locale: locale).t("免费", "Free") }
        return RegistrationUIMoney.display(amount, locale: locale) ?? "—"
    }
    /// R10-PC-C-N8: confirm, 本单不可退 and 退出候补 are system dialogs (MP uses `wx.showModal`, a native alert).
    private var systemDialogs: some View {
        Color.clear
            .alert(Text(verbatim: CoreLoopCopy(locale: locale).tr(NonRefundable24hNotice.modalTitle)),
                   isPresented: Binding(get: { showingNonRefundable && PlayAreaPopupCopy.paymentsOpen },
                                        set: { if !$0 { showingNonRefundable = false } })) {
                nonRefundableButtons
            } message: { Text(verbatim: CoreLoopCopy(locale: locale).tr(NonRefundable24hNotice.modalContent)) }
            .alert(Text(verbatim: confirmationTitle),
                   isPresented: Binding(get: { showingConfirmation && !(showingNonRefundable && PlayAreaPopupCopy.paymentsOpen) && flow.confirmation != nil },
                                        set: { if !$0 { showingConfirmation = false } })) {
                confirmationButtons
            } message: { Text(verbatim: confirmationMessage) }
            .confirmationDialog(Text(verbatim: PlayAreaPopupCopy.text("退出候补队列?", "Leave the waitlist?", locale: locale)),
                                isPresented: Binding(get: { showingWaitlistCancellation },
                                                     set: { if !$0 && showingWaitlistCancellation { showingWaitlistCancellation = false; flow.dismissWaitlistCancellation() } }),
                                titleVisibility: .visible) {
                waitlistQuitButtons
            } message: {
                Text(verbatim: PlayAreaPopupCopy.text(
                    "已保留的名额会立即让给下一位。之后还想来,可以重新排队,顺位从头算。",
                    "The place you were holding goes to the next person. You can join again later, and your place starts over.",
                    locale: locale))
            }
    }
    @ViewBuilder private var nonRefundableButtons: some View {
        let copy = CoreLoopCopy(locale: locale)
        Button(copy.tr(NonRefundable24hNotice.confirmButtonTitle)) {
            nonRefundableConfirmed = true
            showingNonRefundable = false
            showingConfirmation = true
        }
        .accessibilityIdentifier("registration.nonRefundable.confirm")
        Button(copy.tr(NonRefundable24hNotice.cancelButtonTitle), role: .cancel) {
            showingNonRefundable = false
            flow.cancelConfirmation()
        }
    }
    private var confirmationTitle: String {
        let titleKey = "registration.waitlist.confirmTitle"
        return appLocalized(String.LocalizationValue(stringLiteral: titleKey), locale: locale)
    }
    private var confirmationMessage: String {
        guard let review = flow.confirmation else { return "" }
        let base = "\(flow.activity.summary.name)\n\(flow.selectedTicket?.name ?? "")\n\(review.draft.trimmedName)\n\(review.draft.trimmedPhone)\n"
        let nonRefundableSuffix = (!PlayAreaPopupCopy.paymentsOpen && review.quote.requiresNonRefundableConfirmation)
            ? "\n\(CoreLoopCopy(locale: locale).tr(NonRefundable24hNotice.modalTitle)): \(CoreLoopCopy(locale: locale).tr(NonRefundable24hNotice.modalContent))"
            : ""
        return base + gatedPayAmount(review.quote.payAmount) + nonRefundableSuffix
    }
    @ViewBuilder private var confirmationButtons: some View {
        let confirmKey = "registration.waitlist.confirmCreate"
        Button(appLocalized(String.LocalizationValue(stringLiteral: confirmKey), locale: locale)) { confirmRegistration() }
            .accessibilityIdentifier("registration.form.confirm")
        Button(appLocalized("action.cancel", locale: locale), role: .cancel) {
            showingConfirmation = false; flow.cancelConfirmation()
        }
    }
    private func confirmRegistration() {
        guard let review = flow.confirmation else { showingConfirmation = false; return }
        let isPaidRegistration = review.quote.payAmount.map { $0 > .zero } ?? true
        showingConfirmation = false
        Task {
            if isPaidRegistration {
                await flow.confirmAndReadBack()
            } else {
                await SessionOfflineSyncModel.shared.performWriteOptIn(
                    environmentSession: offlineWriteSession.session,
                    routes: ["/api/registration/create", "/api/compliance/consents"]
                ) {
                    await flow.confirmAndReadBack()
                }
            }
        }
    }
    @ViewBuilder private var waitlistQuitButtons: some View {
        Button(PlayAreaPopupCopy.text("退出候补", "Leave waitlist", locale: locale), role: .destructive) {
            showingWaitlistCancellation = false
            Task { await flow.cancelWaitlist() }
        }
        .accessibilityIdentifier("registration.waitlist.confirmCancel")
        Button(PlayAreaPopupCopy.text("取消", "Cancel", locale: locale), role: .cancel) {
            showingWaitlistCancellation = false
            flow.dismissWaitlistCancellation()
        }
    }
    @ViewBuilder private var registrationPopups: some View {
        if showingPaymentPending, PlayAreaPopupCopy.paymentsOpen {
            PlayPaymentPendingModal(
                detailed: flow.resultOrderDestination == nil,
                onGoOrders: {
                    showingPaymentPending = false
                    toastMessage = PlayCloseCopy.text("请在“我的 - 订单”查看支付结果", "Check final status in Me > Orders", locale)
                },
                onClose: { showingPaymentPending = false }
            )
        }
    }
    /// R7-PC-C2-4 (MP baoming.wxml:106-107 `暂无可用票`): no ticket means nothing to quote or submit.
    @ViewBuilder private var noTicketsBlock: some View {
        activitySection
        Section {
            ContentUnavailableView("registration.form.noTicketsAvailable", systemImage: "ticket")
                .accessibilityIdentifier("registration.form.noTicketsAvailable")
        }
    }
    private var showsCheckoutBar: Bool {
        if !flow.hasCurrentSession || flow.hasRetainedIntent { return false }
        if case .pending = flow.durableCreation { return false }
        return !flow.activity.tickets.isEmpty
    }
    /// One-line, human reason why the primary button cannot proceed yet (nil when it can).
    private func blockReason(_ copy: CoreLoopCopy) -> String? {
        // Acceptance R2 F-01/F-02: "checking" only while a quote is in flight; a refusal shows the server sentence.
        if let notice = flow.checkoutFooterNotice(paymentReadiness: paymentReadiness) { return footerNoticeText(notice, copy) }
        guard let block = flow.confirmationBlock else { return nil }
        switch block {
        case .missingConsent: return copy.t("请先勾选上方的确认项", "Tick the confirmation above to continue")
        case .invalidForm: return copy.t("请先补全参与人信息", "Complete the participant details to continue")
        case .soldOut: return copy.t("该票种已售罄", "This ticket is sold out")
        case .signupClosed: return copy.t("报名已截止", "Registration is closed")
        case .quoteUnavailable: return copy.t("正在核对价格…", "Checking the price…")
        case .paymentRequired: return copy.t("这笔报名需要付款，当前只开放免费报名", "This sign-up needs payment. Only a free sign-up is open")
        case .intentAlreadySubmitted: return copy.t("已提交报名", "Already submitted")
        // R7-PC-C2-1: MP baoming.js:1717 toast('请选择儿童年龄').
        case .childAgeRequired: return copy.t("请选择儿童年龄", "Choose the child's age")
        // R11-PC-C-5: MP baoming.js:1425 paymentChannelState 'unavailable'.
        case .paymentChannelUnavailable: return copy.t("支付通道未就绪", "The payment channel isn't ready")
        default: return copy.t("暂时无法继续", "Not available right now")
        }
    }
    /// mp-activity r3 (MP baoming.wxml bmbottom cy-btn): when nothing blocks, the button says what it will do —
    /// 付款 (priced, quote in hand) / 确认价格并付款 (priced, quote pending) / 确认报名 (free). Blocked keeps the review key; the reason sits below.
    private func submitLabelText(_ copy: CoreLoopCopy, blocked: Bool) -> String? {
        // MP baoming.wxml:329 cy-btn label while `!canPay`: 请先勾选信息共享同意 / 请选择参与人信息 / 报名已截止.
        if blocked {
            switch flow.confirmationBlock {
            case .missingConsent?: return copy.t("请先勾选信息共享同意", "Turn on sharing consent first")
            case .invalidForm?: return copy.t("请选择参与人信息", "Choose a participant")
            case .signupClosed?: return copy.t("报名已截止", "Registration is closed")
            default: return nil
            }
        }
        guard let ticket = flow.selectedTicket else { return nil }
        if flow.quoteEnabled, case .received(let quote) = flow.quoteState, let amount = quote.payAmount {
            if amount == .zero { return copy.t("确认报名", "Confirm sign-up") }
            return PlayAreaPopupCopy.paymentsOpen ? copy.t("付款", "Pay") : nil
        }
        if ticket.price == 0 { return copy.t("确认报名", "Confirm sign-up") }
        return PlayAreaPopupCopy.paymentsOpen ? copy.t("确认价格并付款", "Confirm price and pay") : nil
    }
    private func footnoteReason(_ copy: CoreLoopCopy) -> String? {
        if flow.checkoutFooterNotice(paymentReadiness: paymentReadiness) != nil { return blockReason(copy) }
        switch flow.confirmationBlock {
        case .missingConsent?, .invalidForm?, .signupClosed?: return nil
        default: return blockReason(copy)
        }
    }
    private func footerNoticeText(_ notice: RegistrationCheckoutFooterNotice, _ copy: CoreLoopCopy) -> String {
        switch notice {
        case .checkingPrice: return copy.t("正在核对价格…", "Checking the price…")
        case .priceRefused(let message?): return copy.tr(message)
        case .priceRefused(.none): return copy.t("暂时无法获取价格，请重试", "Couldn't get the price. Try again")
        case .priceNeeded: return copy.t("请重新获取价格后继续", "Get the price again to continue")
        case .consentBeforePrice: return copy.t("请先同意报名告知，再获取价格", "Agree to the sign-up notice, then get the price")
        case .paymentUnavailable(let message): return message.map { copy.tr($0) } ?? copy.t("支付服务暂不可用", "Payment service unavailable")
        }
    }
    @State private var blockedTaps = 0
    private var checkoutBar: some View {
        let copy = CoreLoopCopy(locale: locale)
        return CYFooterBar {
            VStack(spacing: CYSpacing.sm) {
                // MP baoming.wxml:325-328 bmbottom_box: the separate, unticked sharing consent (PIPL Art. 23) sits
                // in the bottom bar directly above the button, so "tick it first" points at something in view.
                if flow.creationPolicy.permitsCreation {
                    Toggle(LocalizedStringKey("registration.r3.hostShareConsent"), isOn: Binding(get: { flow.consented }, set: flow.setConsent))
                        .font(.footnote)
                        .disabled(!flow.canEdit).accessibilityIdentifier("registration.form.consent")
                }
                CurA11yActions {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        let blocked = flow.confirmationBlock != nil
                        Button {
                            focusedField = nil
                            if blocked { blockedTaps += 1; return }
                            if flow.prepareConfirmation() {
                                if PlayAreaPopupCopy.paymentsOpen,
                                   flow.confirmation?.quote.requiresNonRefundableConfirmation == true,
                                   !nonRefundableConfirmed {
                                    showingNonRefundable = true
                                } else {
                                    showingConfirmation = true
                                }
                            }
                        } label: {
                            if let mpLabel = submitLabelText(copy, blocked: blocked) {
                                Text(verbatim: mpLabel).frame(maxWidth: .infinity, minHeight: 44)
                            } else {
                                Text("registration.form.review").frame(maxWidth: .infinity, minHeight: 44)
                            }
                        }
                        .buttonStyle(.cyPrimary)
                        // MP baoming.wxml:329 `disabled="{{!canPay}}"`: blocked draws the system disabled state; the reason sits below.
                        .disabled(blocked)
                        .cyHaptic(.warning, trigger: blockedTaps)
                        .onChange(of: blockedTaps) { _, _ in toastMessage = blockReason(copy) }
                        .accessibilityHint(blockReason(copy) ?? "")
                        .pageTemplateControl(
                            label: Text("registration.form.review"),
                            hint: blockReason(copy).map { Text(verbatim: $0) },
                            traits: .isButton
                        )
                        .pageTemplateReadingOrder(1)
                        .accessibilityIdentifier("registration.form.review")
                    }
                }
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    // The blocked button already names the step (MP cy-btn label); the footnote only adds other reasons.
                    if let reason = footnoteReason(copy) {
                        Label { Text(verbatim: reason) } icon: { Image(systemName: "info.circle") }
                            .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("registration.form.blockReason")
                    }
                    if flow.checkoutFooterNotice(paymentReadiness: paymentReadiness)?.offersQuoteRetry == true {
                        CYPillButton(verbatim: copy.t("重新获取价格", "Get the price again"), style: .secondary, compact: true) {
                            Task { await flow.requestQuote() }
                        }
                        .disabled(!flow.canEdit || flow.isQuoting)
                        .accessibilityIdentifier("registration.form.retryQuote")
                    }
                }
            }
        }
    }
    private var participantSection: some View {
        Section {
            if participantReader?.isConfigured == false {
                Text("auth.notConfigured")
            } else if flow.participantsState == .loading {
                CYLoadingStateView(rows: 1, label: "registration.form.loadingParticipants")
            } else if flow.participantsState == .unavailable {
                Text("registration.form.participantReadFailed").foregroundStyle(.secondary)
                CYPillButton("registration.form.reloadParticipants", style: .secondary) { Task { await flow.loadParticipants() } }
                    .accessibilityIdentifier("registration.form.reloadParticipants")
            } else if flow.participantProjectionIsCurrent, !flow.participants.isEmpty {
                // MP baoming.wxml:31-46: one 参与人信息 row opens the participant popup (native `.sheet`).
                Button {
                    focusedField = nil
                    showingParticipantSheet = true
                } label: {
                    RegistrationChoiceRow(title: "registration.form.savedParticipant", value: participantRowValue,
                                          detail: selectedParticipantRow?.mobilePhone)
                }
                .disabled(!flow.canEdit)
                .accessibilityIdentifier("registration.form.participantPicker")
            }
            if let participantReader, let participantCoordinator,
               participantReader.identity != nil, participantReader.identity == participantCoordinator.identity {
                if case .outcomeUnknown = participantCoordinator.state {
                    Button { focusedField = nil; showingAddParticipant = true } label: {
                        Text("participant.recovery.inspect", tableName: "ProfileParticipantRecovery")
                    }.disabled(!flow.canEdit).accessibilityIdentifier("registration.form.inspectParticipant")
                } else if participantReader.isConfigured, participantCoordinator.canPrepare, flow.participants.isEmpty {
                    CYPillButton("participant.form.add", style: .secondary) { focusedField = nil; showingAddParticipant = true }
                        .disabled(!flow.canEdit).accessibilityIdentifier("registration.form.addParticipant")
                }
            }
            // MP baoming.wxml:48-56: a selected participant is shown as the row itself (name + phone), no inline fields.
            if selectedParticipantRow == nil {
                TextField("registration.form.name", text: Binding(get: { flow.draft.realName }, set: flow.setName))
                    .textContentType(.name).textInputAutocapitalization(.words)
                    .focused($focusedField, equals: .name).submitLabel(.next)
                    .onSubmit { focusedField = .phone }
                    .accessibilityIdentifier("registration.form.name")
                // US launch r1: +86 / +1 picker; the draft keeps the server value (China bare digits, US E.164).
                PhoneCountryField("registration.form.phone", wire: Binding(get: { flow.draft.phone }, set: flow.setPhone),
                                  identifier: "registration.form.phone", focus: $focusedField, equals: .phone)
                if !flow.draft.phone.isEmpty, flow.draft.validation == .invalidPhone {
                    Text("registration.form.phoneHint").cyText(.meta).foregroundStyle(CYColor.dangerText)
                }
            }
        } header: { E1IconHeader(systemImage: "person.crop.circle", title: CoreLoopCopy(locale: locale).t("参与人信息", "Participant")) }
        .disabled(!flow.canEdit)
    }
    /// The saved participant the draft still holds (name and phone unchanged); nil while the player types their own.
    private var selectedParticipantRow: ProfileParticipant? {
        guard flow.participantProjectionIsCurrent, let id = flow.selectedParticipantID,
              let row = flow.participants.first(where: { $0.id == id }),
              row.fullName == flow.draft.realName, row.mobilePhone == flow.draft.phone else { return nil }
        return row
    }
    /// Saved participant name while the draft still holds it; 手动填写 once the player typed their own.
    private var participantRowValue: String {
        if let row = selectedParticipantRow {
            return row.fullName
        }
        return appLocalized("registration.form.manualEntry", locale: locale)
    }
    /// R7-PC-C2-1: MP baoming.wxml:155-161 (儿童年龄, sent as `childAge` with quote/create, js:1876),
    /// 206-212 + js:760-764 (商家暂停营业) and js:1871-1876 (通行证 row).
    /// 包含内容 = quote `delivery` rows (MP baoming.wxml:205-212, pages/activity/utils/quote-view.js:20-71).
    /// Split by MP position: 儿童年龄 sits right under the ticket row, 包含内容 after 费用明细,
    /// 商家暂停营业 in the bottom bar above the consent; 通行证 is a row inside 费用明细 (quoteSection).
    private var childAgeSection: some View {
        ActivityRegistrationGapSections(
            childAgeRange: flow.selectedTicket?.childAgeRange,
            selectedChildAge: childAgeBinding
        )
        .disabled(!flow.canEdit)
    }
    private var deliverySection: some View {
        ActivityRegistrationGapSections(
            deliveryItems: flow.quoteState.quoteValue?.delivery?.rows(locale: locale) ?? []
        )
    }
    /// MP baoming.wxml bottom bar `bm-closed` (aria-role alert): 商家暂停营业，暂不可报名.
    @ViewBuilder private var merchantClosedSection: some View {
        if flow.activity.merchantClosed {
            Section {
                Label("topicXcx.merchantClosed", systemImage: "exclamationmark.triangle.fill")
                    .cyText(.bodyCompact)
                    .foregroundStyle(CYColor.warningText)
                    .accessibilityIdentifier("registration.merchantClosed")
            }
        }
    }
    /// MP baoming.wxml 报名已截止 (cy-empty): page-level, not when sold out (候补 owns that) or already registered.
    @ViewBuilder private var signupClosedBlock: some View {
        if flow.signupClosed, flow.selectedTicket?.isSoldOut != true,
           !RegistrationCheckoutFacts(activity: flow.activity, ticket: flow.selectedTicket).viewerAlreadyRegistered {
            Section {
                ContentUnavailableView {
                    Label("registration.r3.signupClosedTitle", systemImage: "calendar.badge.exclamationmark")
                } description: {
                    Text("registration.form.signupClosed")
                        .accessibilityIdentifier("registration.form.signupClosed")
                }
            }
        }
    }

    private var childAgeBinding: Binding<Int?> {
        Binding(
            get: { flow.childAge },
            set: { if flow.setChildAge($0) { Task { await flow.requestQuote() } } }
        )
    }

    private var ticketSection: some View {
        Section {
            if flow.activity.tickets.isEmpty {
                Text("registration.form.noTickets").foregroundStyle(.secondary)
            } else {
                // MP baoming.wxml ticket row: one tappable row opens the ticket popup (native `.sheet`).
                Button {
                    focusedField = nil
                    showingTicketSheet = true
                } label: {
                    RegistrationChoiceRow(title: "registration.form.ticket", value: flow.selectedTicket?.name ?? "")
                }
                .disabled(!flow.canEdit)
                .accessibilityIdentifier("registration.form.ticketPicker")
                if let ticket = flow.selectedTicket {
                    // MP baoming.wxml:149-153 `money.amount(selectedTicket.price)`: the ticket price is always shown
                    // (¥ amount, 免费 when 0); a ticket without a server price reads 价格待定, never a bare dash.
                    LabeledContent {
                        Text(verbatim: ticketPriceText(ticket.price))
                            .monospacedDigit().foregroundStyle(CYColor.textPrimary)
                            .accessibilityIdentifier("registration.form.ticketPrice.amount")
                    } label: { Text("registration.form.ticketPrice") }
                    if let description = ticket.description, !description.isEmpty { Text(verbatim: description) }
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
    /// R9-PC-C2-1: MP baoming 主持预约 block (pages/activity/baoming/baoming.wxml:225-241; js:1083), its own section
    /// outside 候补: 状态, 付款截止 when awaiting payment, 撤销申请 (waitlist cancel) and 请求主持.
    private var hostReservation: ActivityHostReservationState? {
        guard let status = flow.waitlistStatus else { return nil }
        let value = status.hostReservation(ticketSoldOut: flow.selectedTicket?.isSoldOut ?? false)
        return value.isShown ? value : nil
    }
    @ViewBuilder private var hostReservationSection: some View {
        if let reservation = hostReservation {
            Section {
                LabeledContent("registration.hostReservation.status") {
                    Text(verbatim: reservation.statusText)
                        .foregroundStyle(reservation.awaitingPayment ? .primary : .secondary)
                }
                if reservation.awaitingPayment, let deadline = flow.waitlistStatus?.expiresAt {
                    LabeledContent("registration.hostReservation.payBy") {
                        Text(deadline, format: .dateTime.month().day().hour().minute())
                    }
                }
                if reservation.canCancel {
                    Button("registration.hostReservation.cancel", role: .destructive) {
                        if flow.prepareWaitlistCancellation() { showingWaitlistCancellation = true }
                    }
                    .disabled(!flow.canEdit || flow.isMutatingWaitlist)
                    .accessibilityIdentifier("registration.hostReservation.cancel")
                }
                if reservation.canRequest, let ticket = flow.selectedTicket {
                    ClubHostRequestButton(activityID: flow.activity.summary.id, ticketID: ticket.id,
                                          reload: { Task { await flow.loadWaitlist() } })
                }
            } header: { Text("registration.hostReservation.title") }
        }
    }
    private var showsWaitlistReadFailure: Bool {
        flow.block == .waitlistUnavailable && flow.waitlistStatus == nil && !flow.waitlistOutcomeUnknown
            && !flow.isReadingWaitlist && !flow.isMutatingWaitlist
    }
    @ViewBuilder private var waitlistSection: some View {
        if flow.selectedTicket?.isSoldOut == true || flow.waitlistStatus != nil {
            Section {
                if !flow.waitlistAvailable {
                    Text("registration.waitlist.disabled").foregroundStyle(.secondary)
                } else {
                    if flow.isReadingWaitlist || flow.isMutatingWaitlist { CYLoadingStateView(rows: 1, label: "registration.waitlist.loading") }
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
                    }
                    if showsWaitlistReadFailure {
                        // MP baoming.wxml:270-272 cy-inline-error 候补状态读取失败 + 重试: one state, retry inside.
                        CYEmptyState(systemImage: "exclamationmark.triangle", "registration.waitlist.loadFailed",
                                     actionTitle: "action.retry", actionIdentifier: "registration.waitlist.retry",
                                     kind: .failure) { Task { await flow.loadWaitlist() } }
                            .disabled(!flow.canEdit)
                    } else {
                        CYPillButton("registration.waitlist.refresh", style: .secondary) { Task { await flow.loadWaitlist() } }
                            .disabled(!flow.canEdit || flow.isReadingWaitlist)
                            .accessibilityIdentifier("registration.waitlist.refresh")
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
                CYLoadingStateView(rows: 1, label: "registration.form.quoting").accessibilityIdentifier("registration.form.quoting")
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
                    // R11-PC-C-2: §17.6 promotion rows (MP baoming.wxml:174-183, pages/activity/utils/quote-view.js:90-110):
                    // 原价 struck through only when it differs from the ticket price, then one deduction per server label.
                    if quote.showsMarketingAdjustments {
                        if let list = quote.listAmount, list != flow.selectedTicket?.price,
                           let text = RegistrationUIMoney.display(list, locale: locale, currencyCode: RegistrationUIMoney.yuanCurrencyCode) {
                            LabeledContent("registration.marketing.listAmount") {
                                Text(verbatim: text).strikethrough().monospacedDigit().foregroundStyle(.secondary)
                            }
                            .accessibilityIdentifier("registration.fees.listAmount")
                        }
                        ForEach(quote.marketingAdjustments) { adjustment in
                            RegistrationAmountRow(key: "registration.fees.adjustment", amount: adjustment.amount, deduction: true,
                                                  currencyCode: RegistrationUIMoney.yuanCurrencyCode, verbatimLabel: adjustment.label)
                        }
                    }
                    // MP baoming.wxml 费用明细 通行证 row (mkt.coveredByPass): after the reductions, before 积分.
                    if quote.coveredByPass {
                        LabeledContent("registration.pass.label") { Text("registration.pass.covered") }
                            .accessibilityIdentifier("registration.fees.coveredByPass")
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
                        Text(LocalizedStringKey(refusal.localizationKey)).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                            .accessibilityIdentifier("registration.form.pointsRefusal")
                    }
                    RegistrationAmountRow(key: "registration.form.total", amount: quote.payAmount)
                        .cyText(.cardTitle).monospacedDigit().accessibilityIdentifier("registration.form.total")
                    if let refundNotice = NonRefundable24hNotice.feeRowNotice(for: quote) {
                        Text(verbatim: CoreLoopCopy(locale: locale).tr(refundNotice))
                            .cyText(.meta)
                            .foregroundStyle(quote.requiresNonRefundableConfirmation ? CYColor.warningText : CYColor.textSecondary)
                            .accessibilityIdentifier("registration.fees.refundPolicy")
                    }
                    if !quote.isUsableForCreate { Text("registration.form.incompleteQuote").foregroundStyle(.secondary) }
                case .unavailable(let issue):
                    Text("registration.form.quoteFailed").foregroundStyle(.secondary)
                    RegistrationIssueText(issue: issue)
                    if let row = RequestReferenceRow(pathFragment: "/api/registration/quote") { row }
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
                if flow.creationPolicy.recordsServerConsent {
                    CYPillButton("registration.waitlist.recordConsent", style: .secondary) { Task { await flow.recordSignupConsent() } }
                        .disabled(!flow.canEdit || !flow.consented)
                        .accessibilityIdentifier("registration.waitlist.recordConsent")
                    if flow.isRecordingConsent { CYLoadingStateView(rows: 1, label: "registration.waitlist.recordingConsent") }
                    if flow.block == .missingConsent { Text("registration.waitlist.consentUnknown").foregroundStyle(.secondary) }
                }
            } else {
                Label("registration.form.creationDisabled", systemImage: "lock")
                    .accessibilityIdentifier("registration.form.creationDisabled")
                Text("registration.form.creationDisabledHint").cyText(.body).foregroundStyle(.secondary)
                if let complianceSignupDestination {
                    NavigationLink { complianceSignupDestination() } label: { Text("compliance.title") }
                        .accessibilityIdentifier("compliance.signup.reviewSource")
                }
            }
            if flow.block == .confirmationChanged { Text("registration.form.confirmationChanged").foregroundStyle(.secondary) }
        }
    }
}

/// R10-PC-C-N8: a system list row with a trailing checkmark for the picked value.
private struct RegistrationPickerRow: View {
    let title: String
    let subtitle: String?
    let selected: Bool
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: title).foregroundStyle(.primary)
                if let subtitle, !subtitle.isEmpty { Text(verbatim: subtitle).font(.subheadline).foregroundStyle(.secondary) }
            }
            Spacer()
            if selected { Image(systemName: "checkmark").foregroundStyle(.tint).accessibilityHidden(true) }
        }
        .contentShape(Rectangle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct RegistrationAmountRow: View {
    @Environment(\.locale) private var locale
    let key: String
    let amount: Decimal?
    var deduction = false
    var currencyCode: String? = nil
    /// R11-PC-C-2: server promotion label shown verbatim (MP baoming.wxml:179).
    var verbatimLabel: String? = nil
    var body: some View {
        LabeledContent {
            if let amount, amount > .zero, !PlayAreaPopupCopy.paymentsOpen {
                Text(verbatim: "—").foregroundStyle(CYColor.textPrimary).accessibilityIdentifier(key + ".amount")
            } else if let text = RegistrationUIMoney.display(amount, locale: locale, currencyCode: currencyCode) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(verbatim: deduction && amount != .zero ? "−\(text)" : text)
                        .monospacedDigit().foregroundStyle(CYColor.textPrimary).accessibilityIdentifier(key + ".amount")
                    if currencyCode == nil { Text("registration.form.currencyUnknown").cyText(.meta).foregroundStyle(.primary) }
                }
            } else { Text(verbatim: "—").foregroundStyle(Color.primary).accessibilityIdentifier(key + ".amount") }
        } label: {
            if let verbatimLabel { Text(verbatim: verbatimLabel) } else { Text(LocalizedStringKey(key)) }
        }
    }
}

/// Do not display arbitrary Error descriptions, quote signatures, provider parameters,
/// credentials or contact fields. Verified structured server messages remain available.
private struct RegistrationIssueText: View {
    @Environment(\.locale) private var locale
    let issue: RegistrationCoordinatorIssue
    private var message: String? { issue.serverMessage }
    var body: some View {
        if let message {
            Text(verbatim: CoreLoopCopy(locale: locale).tr(message)).cyText(.body).foregroundStyle(.secondary)
        }
    }
}

@MainActor
private struct RegistrationOperationSections: View {
    @Environment(\.analyticsEventClient) private var analytics
    let flow: RegistrationUIFlow
    let revision:UInt64
    var orderReader: (any ProfileReading)? = nil
    var body: some View {
        if flow.retainedForAnotherActivity {
            Section { Text("registration.form.otherActivityIntent").foregroundStyle(.secondary) }
        }
        switch flow.creationState {
        case .idle:
            // R11-PC-C-2: MP baoming.js:1495 app.tips(CONFLICT_TEXT[conflict]); the quote above is already new.
            if let conflict = flow.createConflictMessage {
                Section {
                    Label(conflict, systemImage: "arrow.clockwise.circle")
                        .foregroundStyle(.orange)
                        .accessibilityIdentifier("registration.form.createConflict")
                }
            }
        case .submitting:
            Section { CYLoadingStateView(rows: 1, label: "registration.form.creating") }
        case .outcomeUnknown:
            Section("registration.form.outcomeUnknown") {
                Text("registration.form.outcomeUnknownHint")
                    .accessibilityIdentifier("registration.form.outcomeUnknown")
                if let row = RequestReferenceRow(pathFragment: "/api/registration/create") { row }
                Text("registration.form.retainedIntentHint").cyText(.meta).foregroundStyle(.secondary)
                if let orderReader { RegistrationUncertainOrdersCheck(flow: flow, reader: orderReader) }
            }
        case .responseReceived(_, let result):
            // PC-C-2-1: a result in user terms (MP baoming.js:1932-1975 报名成功 / 待支付) that lands on the order
            // (MP redirects to orderinfo?id=<registrationId>). Engineering facts stay in DEBUG builds only.
            let awaitingPayment = (result.payableAmount ?? .zero) > .zero || result.hasPaymentParameters
            Section {
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    Label {
                        Text(LocalizedStringKey(awaitingPayment ? "registration.result.submitted" : "registration.result.success"))
                            .cyText(.sectionTitle)
                            .foregroundStyle(CYColor.textPrimary)
                    } icon: {
                        Image(systemName: awaitingPayment ? "clock.badge.checkmark" : "checkmark.circle.fill")
                            .foregroundStyle(awaitingPayment ? CYColor.textSecondary : CYColor.successText)
                    }
                    Text(LocalizedStringKey(awaitingPayment ? "registration.result.payHint" : "registration.result.successHint"))
                        .cyText(.body)
                        .foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("registration.result")
                if awaitingPayment { RegistrationAmountRow(key: "registration.form.total", amount: result.payableAmount) }
                if let orderReader {
                    NavigationLink {
                        ProfileOrderDetailView(id: result.registrationID, reader: orderReader)
                    } label: {
                        Text("registration.result.viewOrder").cyText(.button)
                            .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
                    }
                    .accessibilityIdentifier("registration.result.viewOrder")
                }
                #if DEBUG
                // DEBUG only (UI tests read these): the raw create response and the status read.
                Group {
                    Text("registration.form.createdResponse").cyText(.caption).foregroundStyle(CYColor.textSecondary)
                    LabeledContent("registration.form.registrationID", value: String(result.registrationID))
                    if let number = result.registrationNo, !number.isEmpty {
                        LabeledContent("registration.form.registrationNumber", value: number)
                    }
                    CYPillButton("registration.form.readStatus", style: .secondary) { Task { await flow.readKnownStatus() } }
                        .disabled(!flow.canReadStatus).accessibilityIdentifier("registration.form.readStatus")
                }
                #endif
            }
            .onAppear {
                guard !result.hasPaymentParameters else { return }
                var properties: [String: PlayWireValue] = ["registrationId": .integer(Int64(result.registrationID))]
                if let amount = result.payableAmount, let value = MiniProgramAnalytics.amount(amount) { properties["payableAmount"] = value }
                MiniProgramAnalytics.track(analytics, "signup_submit", bizType: "activity",
                    bizID: MiniProgramAnalytics.bizID(flow.activity.summary.id), pagePath: "/pages/activity/baoming/baoming",
                    properties: properties, idempotencyKey: "signup_submit_registration_\(result.registrationID)")
            }
            if (result.payableAmount ?? .zero) > .zero || result.hasPaymentParameters {
                RegistrationPaySection(
                    registrationID: result.registrationID,
                    payableAmount: result.payableAmount,
                    quote: flow.quoteState.quoteValue,
                    quoteReceivedAt: flow.currentQuoteReceivedAt,
                    consented: flow.consented,
                    requiresFreshQuote: flow.quoteState.quoteValue != nil,
                    channel: .standard,
                    onExpiredRebuild: { Task { await flow.requestQuote() } }
                )
            }
        }
        switch flow.readbackState {
        case .idle: EmptyView()
        case .loading: Section { CYLoadingStateView(rows: 1, label: "registration.form.readingStatus") }
        case .unavailable(_, let issue):
            Section {
                Text("registration.form.statusUnavailable")
                RegistrationIssueText(issue: issue)
                if let row = RequestReferenceRow(pathFragment: "/api/registration/info") { row }
            }
        case .received(let snapshot):
            Section("registration.form.serverStatus") {
                LabeledContent("registration.form.registrationStatus") {
                    Text(LocalizedStringKey(RegistrationUIStatus.registrationKey(snapshot.registrationStatus)))
                }
                #if DEBUG
                statusRow("registration.form.registrationCode", snapshot.registrationStatus)
                statusRow("registration.form.paymentCode", snapshot.paymentStatus)
                statusRow("registration.form.verificationCode", snapshot.verificationStatus)
                #endif
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
        if reading { CYLoadingStateView(rows: 1, label: "registration.form.readingStatus") }
        if failed { Text("registration.w206.checkOrdersFailed").accessibilityIdentifier("registration.checkOrders.failed") }
        switch evidence {
        case .noMatchingOrder?:
            Text("registration.w206.noMatchingOrder").accessibilityIdentifier("registration.checkOrders.none")
        case .matchingOrders(let ids)?:
            Text("registration.w206.matchingOrders \(ids.count)").accessibilityIdentifier("registration.checkOrders.matches")
            ForEach(ids, id: \.self) { id in
                LabeledContent("registration.form.registrationID", value: String(id))
            }
            Text("registration.w206.matchNotProof").cyText(.meta).foregroundStyle(.secondary)
        case .notApplicable?, nil: EmptyView()
        }
    }
}

@MainActor
private struct RegistrationOrderAndLifecycleModifier: ViewModifier {
    let flow: RegistrationUIFlow
    let preselectedTicketID: Int?
    let orderReader: (any ProfileReading)?
    let participantReader: (any ProfileReading)?
    let participantCoordinator: ParticipantMutationCoordinator?
    let scenePhase: ScenePhase
    @Binding var orderDestination: RegistrationWaitlistOrderVisit?
    @Binding var resultOrderDestination: RegistrationResultOrderPresentation?
    @Binding var recoveredOrderDestination: RegistrationRecoveredOrderPresentation?
    @Binding var showingAddParticipant: Bool
    @Binding var showingWaitlistCancellation: Bool
    @Binding var showingConfirmation: Bool
    @Binding var showingNonRefundable: Bool
    @Binding var nonRefundableConfirmed: Bool

    func body(content: Content) -> some View {
        content
            .onChange(of: flow.waitlistCancellation) { _, value in
                if value == nil { showingWaitlistCancellation = false }
            }
            .task(id: flow.identity) {
                flow.open()
                if let preselectedTicketID, flow.activity.tickets.contains(where: { $0.id == preselectedTicketID }) {
                    flow.selectTicket(id: preselectedTicketID)
                }
                // R7-PC-C2-4: an activity with no ticket is blocked (暂无可用票); never quote the bare activity.
                guard !flow.activity.tickets.isEmpty else { return }
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
            .cySheet(item: $orderDestination) { visit in Group {
                if let orderReader {
                    RegistrationWaitlistOrderSheet(presentation: visit.presentation, reader: orderReader,
                        isCurrent: { RegistrationWaitlistOrderVisit.permits(visit, current: orderDestination,
                            destination: flow.waitlistOrderDestination, isActive: scenePhase == .active) })
                        .themeDomain(.player)
                }
            }.cySheet(detents: [.large]) }
            .onChange(of: flow.waitlistReadKey) { _, _ in orderDestination = nil }
            .onChange(of: flow.waitlistOrderDestination) { _, _ in orderDestination = nil }
            .cySheet(item: $resultOrderDestination) { presentation in Group {
                if let orderReader {
                    RegistrationResultOrderSheet(presentation: presentation, reader: orderReader,
                        isCurrent: { resultOrderDestination == presentation &&
                            flow.resultOrderDestination == presentation.destination && scenePhase == .active })
                        .themeDomain(.player)
                }
            }.cySheet(detents: [.large]) }
            .cySheet(item: $recoveredOrderDestination) { presentation in Group {
                if let orderReader {
                    RegistrationRecoveredOrderSheet(presentation: presentation, reader: orderReader,
                        isCurrent: { recoveredOrderDestination == presentation &&
                            flow.recoveredOrderDestination == presentation.destination && scenePhase == .active })
                        .themeDomain(.player)
                }
            }.cySheet(detents: [.large]) }
            .onChange(of: flow.recoveredOrderDestination) { _, _ in recoveredOrderDestination = nil }
            .onChange(of: flow.resultOrderDestination) { _, _ in resultOrderDestination = nil }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { orderDestination = nil; resultOrderDestination = nil; recoveredOrderDestination = nil; flow.retireResultOrderNavigation() }
            }
            .cySheet(isPresented: $showingAddParticipant) { Group {
                if let participantReader, let participantCoordinator {
                    NavigationStack {
                        ParticipantFormView(reader: participantReader, coordinator: participantCoordinator,
                            onSaved: { if participantCoordinator.savedParticipant == nil { Task { await flow.loadParticipants() } } },
                            onCreated: { row, identity in Task { await flow.selectCreatedParticipant(row, identity: identity) } })
                    }
                    .themeDomain(.player)
                }
            }.cySheet() }
            .onChange(of: flow.identity) { _, _ in showingAddParticipant = false }
            .onChange(of: flow.participantsIdentity) { _, _ in
                showingAddParticipant = false
                flow.synchronizeParticipantIdentity()
                guard scenePhase == .active, flow.hasCurrentSession else { return }
                Task { await flow.loadParticipants() }
            }
            .onChange(of: flow.confirmation) { _, value in
                if value == nil { showingConfirmation = false; showingNonRefundable = false }
            }
            .onChange(of: flow.quoteState) { _, _ in nonRefundableConfirmed = false }
            .onDisappear { flow.leave() }
    }
}


/// verify-r1 3.9: the player sheet header in the navigation bar — title leading, round ✕ trailing — and the grabber.
private struct RegistrationPlayerSheetHeader: ViewModifier {
    let onClose: () -> Void
    @Environment(\.cyPalette) private var palette

    func body(content: Content) -> some View {
        let base = content.presentationDragIndicator(.visible)
        if #available(iOS 26, *) {
            base
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { title }
                        .sharedBackgroundVisibility(.hidden)
                    // The 32 pt grey circle is the control; the bar's own glass behind it would draw a second ring.
                    ToolbarItem(placement: .topBarTrailing) { closeButton }
                        .sharedBackgroundVisibility(.hidden)
                }
                .toolbar(removing: .title)
        } else if #available(iOS 18, *) {
            base
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { title }
                    ToolbarItem(placement: .topBarTrailing) { closeButton }
                }
                .toolbar(removing: .title)
        } else {
            base.toolbar { ToolbarItem(placement: .topBarTrailing) { closeButton } }
        }
    }

    private var closeButton: some View {
        Button("action.close", systemImage: "xmark", action: onClose)
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered).buttonBorderShape(.circle)
            .accessibilityIdentifier("registration.form.close")
    }

    private var title: some View {
        Text("registration.form.title")
            .cyText(.sectionTitle)
            .foregroundStyle(palette.textPrimary)
            .accessibilityAddTraits(.isHeader)
            .fixedSize()
            // A bar title: capped like the system inline title so it cannot push the close button off screen at AX sizes;
            // the Large Content Viewer shows it full size.
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .accessibilityShowsLargeContentViewer()
    }
}

/// One list row for a choice made in a sheet: title leading, current value trailing, disclosure chevron.
private struct RegistrationChoiceRow: View {
    let title: LocalizedStringKey
    let value: String
    var detail: String? = nil

    var body: some View {
        LabeledContent {
            HStack(spacing: 6) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(verbatim: value)
                        .foregroundStyle(.secondary)
                    if let detail, !detail.isEmpty {
                        Text(verbatim: detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                .multilineTextAlignment(.trailing)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        } label: {
            Text(title).foregroundStyle(.primary)
        }
        .contentShape(Rectangle())
    }
}

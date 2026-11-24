import SwiftUI

@MainActor final class OrderLifecycleScreenModel: ObservableObject {
    let coordinator: OrderLifecycleCoordinator
    @Published private(set) var revision = 0
    init(coordinator: OrderLifecycleCoordinator) { self.coordinator = coordinator }
    func load(id: Int) async { revision += 1; await coordinator.load(id: id); revision += 1 }
    func prepare(_ action: OrderLifecycleAction, orderID: Int) { coordinator.prepare(action, orderID: orderID); revision += 1 }
    func dismiss() { coordinator.dismissReview(); revision += 1 }
    func closePayment() { coordinator.closePaymentReturn(); revision += 1 }
    func invalidate() { coordinator.becameInactive(); revision += 1 }
    func confirm(_ id: UUID) async { revision += 1; await coordinator.confirm(reviewID: id); revision += 1 }
    func agreeToSignupNotice(orderID: Int) async { revision += 1; await coordinator.agreeToSignupNotice(orderID: orderID); revision += 1 }
}

/// A retained session-owned coordinator is injected; no view constructs a live writer.
@MainActor struct OrderLifecycleView: View {
    let id: Int
    @StateObject private var model: OrderLifecycleScreenModel
    @Environment(\.scenePhase) private var phase
    @Environment(\.locale) private var locale
    @Environment(\.orderTeamCreate) private var orderTeamCreate
    @Environment(\.dynamicTypeSize) private var typeSize
    private var c: CoreLoopCopy { CoreLoopCopy(locale: locale) }
    init(id: Int, coordinator: OrderLifecycleCoordinator) {
        self.id = id; _model = StateObject(wrappedValue: OrderLifecycleScreenModel(coordinator: coordinator))
    }
    private var coordinator: OrderLifecycleCoordinator { model.coordinator }
    var body: some View {
        List {
            if coordinator.isOfflineExample { Text("orderLifecycle.offline").cyText(.meta).accessibilityIdentifier("orderLifecycle.offline") }
            if let issue = coordinator.issue {
                Section {
                    Label {
                        if let serverMessage = coordinator.serverMessage, !serverMessage.isEmpty { Text(verbatim: serverMessage) }
                        else if issue == .reconsentRequired { Text(verbatim: c.t("活动报名的数据共享同意已更新，需要重新同意后才能支付。", "The activity sign-up data-sharing consent has changed. Agree again before paying.")) }
                        else { Text(LocalizedStringKey("orderLifecycle.issue." + issue.rawValue)) }
                    } icon: { Image(systemName: "exclamationmark.triangle") }
                        .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("orderLifecycle.issue")
                    if issue == .reconsentRequired {
                        Button(c.t("同意并继续", "Agree and continue")) { Task { await model.agreeToSignupNotice(orderID: id) } }
                            .accessibilityIdentifier("orderLifecycle.reconsent")
                    }
                    if let row = RequestReferenceRow(pathFragment: "/api/registration/") { row }
                }
            }
            if coordinator.accountID == nil { Text("orderLifecycle.issue.login") }
            else if coordinator.isLoading { CYSkeleton().listRowBackground(Color.clear).accessibilityLabel(Text("orderLifecycle.loading")) }
            else if let detail = coordinator.detail, detail.id == id {
                acceptedDetail(detail)
            } else if coordinator.issue == nil {
                // No accepted detail and no issue: unknown, never an empty order or a zero amount.
                Text(verbatim: OrderInfoPageModel.unknownMark).cyText(.sectionTitle).foregroundStyle(CYColor.textTertiary)
                    .accessibilityLabel(Text("orderLifecycle.amount"))
                    .accessibilityIdentifier(OrderInfoPageModel.unknownIdentifier)
            }
            Section {
                OrderDeliverySection(delivery: coordinator.detail?.id == id ? coordinator.detail?.delivery : nil)
                OrderPaymentReturnSection(loading: coordinator.isLoading,
                                           payment: coordinator.detail?.id == id ? coordinator.detail?.paymentStatus : nil,
                                           registration: coordinator.detail?.id == id ? coordinator.detail?.registrationStatus : nil,
                                           channels: coordinator.detail?.id == id ? coordinator.detail?.paymentChannels : nil)
                OrderPartialRefundSection(settlement: coordinator.detail?.id == id ? coordinator.detail?.settlement : nil)
            }
            Section {} footer: { Text("orderLifecycle.production.caution") } // native restyle r1: explanatory copy in a footer
        }
        .listStyle(.insetGrouped)
        .cyDomainScreen(.player)
        .cyHideTabBar(true)
        .safeAreaInset(edge: .bottom, spacing: 0) { pinnedPrimary }
        .listRowBackground(CYColor.bgElevated)
        .appNavigationTitle("orderLifecycle.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { Task { await model.load(id: id) } } label: { Label("orderLifecycle.refresh", systemImage: "arrow.clockwise") }
                    .disabled(coordinator.isLoading || coordinator.accountID == nil)
                    .accessibilityIdentifier("orderLifecycle.refresh")
            }
        }
        .task(id: coordinator.scope) {
            await model.load(id: id)
            #if DEBUG
            // Design fixtures only: `--design-auto-review` opens the first reviewable action so the confirm sheet can be shot.
            if ProcessInfo.processInfo.arguments.contains("--design-auto-review"), let d = coordinator.detail,
               let a = OrderLifecycleAction.allCases.first(where: { OrderLifecycleCoordinator.isReviewable($0, detail: d) }) {
                try? await Task.sleep(nanoseconds: 800_000_000); model.prepare(a, orderID: id)
            }
            #endif
        }
        .refreshable { await model.load(id: id) }
        .onDisappear { model.dismiss() }
        .onChange(of: phase) { _, value in
            if value != .active { model.invalidate() }
            else if !coordinator.isWaitingForPaymentProvider && coordinator.paymentReturn == nil { Task { await model.load(id: id) } }
        }
        .sheet(item: Binding(get: { coordinator.review }, set: { if $0 == nil { model.dismiss() } })) { review in
            OrderLifecycleReviewView(review: review, canSimulate: coordinator.canSimulate, canDispatch: coordinator.canDispatch,
                confirm: { Task { await model.confirm(review.id) } }, close: model.dismiss)
                .themeDomain(.player)
                .cySheet(detents: [.large])
        }
        .sheet(item: Binding(get: { coordinator.paymentReturn }, set: { if $0 == nil { model.closePayment() } })) { flow in Group {
            PaymentProviderReturnSheet(flow: flow) { _ in model.closePayment() }
                .themeDomain(.player)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        }
        .accessibilityIdentifier("orderLifecycle.detail")
    }
    /// The first reviewable action is the screen's one primary CTA, pinned above the home indicator.
    @ViewBuilder private var pinnedPrimary: some View {
        if let detail = coordinator.detail, detail.id == id,
           let action = OrderLifecycleAction.allCases.first(where: { OrderLifecycleCoordinator.isReviewable($0, detail: detail) }) {
            CYFooterBar {
                Button { model.prepare(action, orderID: id) } label: { Text(LocalizedStringKey("orderLifecycle.review." + action.rawValue)) }
                    .buttonStyle(CYOrderActionButtonStyle(primary: true))
                    .disabled(coordinator.isAttemptBlocking(action, orderID: detail.id))
                    .accessibilityIdentifier("orderLifecycle.review." + action.rawValue)
            }
        }
    }
    /// The accepted order detail, split out so the list body type-checks in reasonable time.
    @ViewBuilder private func acceptedDetail(_ detail: OrderLifecycleDetail) -> some View {
            summary(detail)
            payment(detail)
            if detail.summary().state == .pendingPayment, detail.id > 0 {
                RegistrationPaySection(
                    registrationID: detail.id,
                    payableAmount: detail.payableAmount,
                    consented: coordinator.issue != .reconsentRequired,
                    requiresFreshQuote: false,
                    channel: .standard
                )
            }
            timeline(detail)
            refund(detail)
            actions(detail)
            Section {
                NavigationLink { OrderPassPreviewView(orderID: id, coordinator: coordinator) } label: {
                    Label("orderLifecycle.pass.title", systemImage: "ticket")
                }.accessibilityIdentifier("orderLifecycle.pass.open")
            }
            if detail.teamOpen, let ownerID = detail.ownerID, let makeTeam = orderTeamCreate {
                Section {
                    NavigationLink { makeTeam(ownerID, detail.id) } label: {
                        Label("orderLifecycle.teamOpen", systemImage: "person.3")
                    }
                    .accessibilityIdentifier("orderLifecycle.teamOpen")
                }
            }
    }

    private func summary(_ detail: OrderLifecycleDetail) -> some View {
        let state = detail.summary()
        let fulfillment = FourShopCompensationPolicy.evaluateSoldContractFulfillment(
            registrationStatus: detail.registrationStatus,
            paymentStatus: detail.paymentStatus,
            verificationStatus: detail.verificationStatus
        )
        return Section {
            VStack(alignment: .leading, spacing: CYSpacing.lg) {
                OrderStatusChip(title: LocalizedStringKey("orderLifecycle.state." + state.state.rawValue), systemImage: "ticket", emphasized: true)
                    .accessibilityIdentifier("orderLifecycle.state")
                HStack(alignment: .center, spacing: CYSpacing.md) {
                    if !typeSize.isAccessibilitySize { OrderCoverTile(systemImage: "ticket", size: 64, seed: detail.title ?? "", fallback: MPAsset.EmptyState.iconTicketEmpty) }
                    Group {
                        if let title = detail.title, !title.isEmpty { Text(verbatim: title) }
                        else { Text("orderLifecycle.untitled") }
                    }
                    .cyText(.sectionTitle).foregroundStyle(CYColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                Group {
                    if let reason = state.serverReason { Text(verbatim: reason) }
                    else { Text(LocalizedStringKey(state.explanationKey)) }
                }
                .cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                if let notice = fulfillment.fulfillmentNotice {
                    Text(verbatim: c.tr(notice)).cyText(.caption).foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                // Revolut hero: unknown amount is an em dash, never 0.
                OrderAmountHero(label: "orderLifecycle.amount", amount: detail.payableAmount)
            }.padding(.vertical, CYSpacing.sm)
                .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
            OrderLifecycleField(label: "orderLifecycle.number", value: detail.registrationNumber)
            OrderLifecycleField(label: "orderLifecycle.ticket", value: detail.ticketName)
        }
        .listRowBackground(CYColor.bgElevated)
    }
    private func payment(_ detail: OrderLifecycleDetail) -> some View {
        let observation = OrderPaymentObservation(payment: detail.paymentStatus, registration: detail.registrationStatus)
        return Section("orderLifecycle.payment.title") {
            Text(LocalizedStringKey("orderLifecycle.payment." + observation.rawValue))
                .accessibilityIdentifier("orderLifecycle.payment.observation")
            if let explanation = UnknownPaymentState.explanation(payment: detail.paymentStatus, registration: detail.registrationStatus) {
                Text(verbatim: explanation).accessibilityIdentifier("orderLifecycle.payment.unknown")
            }
            Text("orderLifecycle.payment.caution").cyText(.meta).foregroundStyle(CYColor.textSecondary)
            OrderLifecycleField(label: "orderLifecycle.payment.deadline", value: detail.payExpireTime)
        }
    }
    private func timeline(_ detail: OrderLifecycleDetail) -> some View {
        let rows = detail.timeline()
        return Section("orderLifecycle.timeline.title") {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    HStack(alignment: .top, spacing: CYSpacing.md) {
                        VStack(spacing: 0) {
                            Image(systemName: row.done ? "checkmark.circle.fill" : "circle")
                                .font(.title3).foregroundStyle(row.done ? CYColor.textPrimary : CYColor.textTertiary)
                                .accessibilityHidden(true)
                            if index < rows.count - 1 {
                                Rectangle().fill(row.done ? CYColor.textSecondary : CYColor.borderStrong).frame(width: 2).frame(maxHeight: .infinity)
                            }
                        }
                        VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                            Text(LocalizedStringKey(row.labelKey)).cyText(.bodyCompact)
                                .foregroundStyle(row.done ? CYColor.textPrimary : CYColor.textSecondary)
                            // A completed step with no server time is an em dash (OrderInfoPageModel.snapshot rule).
                            if row.done || row.time != nil { Text(verbatim: row.time ?? OrderInfoPageModel.unknownMark).cyText(.caption).foregroundStyle(CYColor.textSecondary).monospacedDigit() }
                        }
                        .padding(.bottom, index < rows.count - 1 ? CYSpacing.lg : 0)
                        .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("orderLifecycle.timeline." + row.id)
                }
            }.padding(.vertical, CYSpacing.xs)
            Text("orderLifecycle.timeline.zone").cyText(.caption).foregroundStyle(CYColor.textSecondary)
        }
    }
    @ViewBuilder private func refund(_ detail: OrderLifecycleDetail) -> some View {
        if detail.refundApplication != nil || detail.refundReason != nil || detail.refundDeadline != nil {
            Section("orderLifecycle.refund.title") {
                if let payout = TicketExpiryAndOrderStatusRules.payoutSummary(
                    status: detail.refundApplication?.applicationStatus,
                    payoutStatus: detail.refundApplication?.payoutStatus,
                    refundAmount: detail.refundApplication?.amount,
                    applicationPresent: detail.refundApplication != nil
                ) {
                    LabeledContent(c.t("退款进度", "Refund status")) {
                        Text(verbatim: c.tr(payout.label))
                    }
                    Text(verbatim: c.tr(payout.hint)).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                }
                OrderLifecycleField(label: "orderLifecycle.refund.reason", value: detail.refundReason)
                OrderLifecycleField(label: "orderLifecycle.refund.deadline", value: detail.refundDeadline)
                if let amount = detail.refundApplication?.amount { LabeledContent("orderLifecycle.refund.amount") { AmountLabel(amount: amount) } }
                Text("orderLifecycle.refund.caution").cyText(.meta).foregroundStyle(CYColor.textSecondary)
            }
        }
    }
    private func actions(_ detail: OrderLifecycleDetail) -> some View {
        Section("orderLifecycle.actions") {
            let reviewable = OrderLifecycleAction.allCases.filter { OrderLifecycleCoordinator.isReviewable($0, detail: detail) }
            ForEach(OrderLifecycleAction.allCases, id: \.self) { action in
                if OrderLifecycleCoordinator.isReviewable(action, detail: detail), action != reviewable.first {
                    Button { model.prepare(action, orderID: id) } label: { Text(LocalizedStringKey("orderLifecycle.review." + action.rawValue)) }
                        .buttonStyle(CYOrderActionButtonStyle(primary: false))
                        .listRowInsets(EdgeInsets(top: CYSpacing.xs, leading: 0, bottom: CYSpacing.xs, trailing: 0))
                        .listRowBackground(Color.clear)
                        .accessibilityIdentifier("orderLifecycle.review." + action.rawValue)
                        .disabled(coordinator.isAttemptBlocking(action, orderID: detail.id))
                }
            }
            if let attempt = coordinator.attempt(orderID: detail.id) {
                switch attempt {
                case .submitted: ProgressView("orderLifecycle.attempt.submitted")
                case .outcomeUnknown: Text("orderLifecycle.attempt.unknown").accessibilityIdentifier("orderLifecycle.attempt.unknown")
                case .acknowledged:
                    Text("orderLifecycle.production.acknowledged")
                    if let message = coordinator.serverMessage { Text(verbatim: message) }
                case .paymentObserved(_, let observation):
                    Text(LocalizedStringKey("orderLifecycle.payment." + observation.rawValue))
                case .responseReceived(_, let observation):
                    if let message = coordinator.serverMessage { Text(verbatim: message) }
                    Text("orderLifecycle.attempt.received").accessibilityIdentifier("orderLifecycle.attempt.received")
                    OrderLifecycleField(label: "orderLifecycle.attempt.cancellation", value: observation.cancellationStatus)
                    OrderLifecycleField(label: "orderLifecycle.attempt.cash", value: observation.cashRefundStatus)
                    OrderLifecycleField(label: "orderLifecycle.attempt.points", value: observation.pointsRefundStatus)
                }
            }
        }
    }
}

struct OrderLifecycleField: View {
    let label: LocalizedStringKey
    let value: String?
    @Environment(\.dynamicTypeSize) private var size
    var body: some View {
        if let value, !value.isEmpty {
            if size.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) { Text(label).foregroundStyle(CYColor.textSecondary); Text(verbatim: value) }
                    .fixedSize(horizontal: false, vertical: true)
            } else { LabeledContent(label) { Text(verbatim: value).fixedSize(horizontal: false, vertical: true) } }
        }
    }
}

@MainActor private struct OrderLifecycleReviewView: View {
    let review: OrderLifecycleReview
    let canSimulate: Bool
    let canDispatch: Bool
    let confirm: () -> Void
    let close: () -> Void
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: CYSpacing.md) {
                        Image(systemName: review.action == .payment ? "creditcard" : review.action == .refund ? "arrow.uturn.backward.circle" : "xmark.circle")
                            .cyText(.display, weight: .regular).foregroundStyle(CYColor.textPrimary)
                            .frame(width: 72, height: 72).background(Circle().fill(CYColor.bgRaised)).accessibilityHidden(true)
                        Text(LocalizedStringKey("orderLifecycle.question." + review.action.rawValue))
                            .cyText(.sectionTitle).foregroundStyle(CYColor.textPrimary).multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
                        if review.action != .payment {
                            Text("orderLifecycle.refund.caution").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, CYSpacing.sm)
                    .listRowBackground(Color.clear)
                }
                Section {
                    OrderLifecycleField(label: "orderLifecycle.number", value: review.detail.registrationNumber)
                    LabeledContent("orderLifecycle.amount") { AmountLabel(amount: review.detail.payableAmount) }
                    OrderLifecycleField(label: "orderLifecycle.refund.reason", value: review.detail.refundReason)
                    OrderLifecycleField(label: "orderLifecycle.refund.deadline", value: review.detail.refundDeadline)
                }
                Section {
                    if canDispatch {
                        if review.action == .payment {
                            Button(LocalizedStringKey("orderLifecycle.production.confirm." + review.action.rawValue), action: confirm)
                                .buttonStyle(.borderedProminent).controlSize(.large).buttonBorderShape(.capsule)
                                .listRowBackground(Color.clear)
                                .accessibilityIdentifier("orderLifecycle.review.confirmProduction")
                        } else {
                            Button(LocalizedStringKey("orderLifecycle.production.confirm." + review.action.rawValue), role: .destructive, action: confirm)
                                .buttonStyle(.cyDestructive).frame(maxWidth: .infinity)
                                .listRowBackground(Color.clear)
                                .accessibilityIdentifier("orderLifecycle.review.confirmProduction")
                        }
                    } else if canSimulate && review.action != .payment {
                        Button("orderLifecycle.review.simulate", role: .destructive, action: confirm).buttonStyle(.cyDestructive).frame(maxWidth: .infinity).listRowBackground(Color.clear).accessibilityIdentifier("orderLifecycle.review.confirmFixture")
                    } else {
                        Button("orderLifecycle.review.disabled", action: {}).disabled(true).accessibilityIdentifier("orderLifecycle.review.disabled")
                    }
                }
            }
            .appNavigationTitle(key: "orderLifecycle.question." + review.action.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("orderLifecycle.review.close", action: close).accessibilityIdentifier("orderLifecycle.review.close") } }
            .accessibilityIdentifier("orderLifecycle.review.sheet")
        }
        .cyDomainSheet(detents: [.full])
        .cyDomainScreen(.player)
    }
}

/// One white primary CTA per screen; every other action is a quiet secondary button.
private struct CYOrderActionButtonStyle: ButtonStyle {
    let primary: Bool
    func makeBody(configuration: Configuration) -> some View {
        Group {
            if primary { configuration.label.modifier(CYOrderActionPrimaryLabel()) }
            else { configuration.label.modifier(CYOrderActionSecondaryLabel()) }
        }
        .scaleEffect(configuration.isPressed ? 0.97 : 1)
        .opacity(configuration.isPressed ? 0.85 : 1)
    }
}
private struct CYOrderActionPrimaryLabel: ViewModifier {
    func body(content: Content) -> some View {
        content.cyText(.label).foregroundStyle(CYColor.textOnAccent)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(CYColor.actionPrimaryBg, in: Capsule(style: .continuous))
    }
}
private struct CYOrderActionSecondaryLabel: ViewModifier {
    func body(content: Content) -> some View {
        content.cyText(.label).foregroundStyle(CYColor.textSecondary)
            .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
            .background(CYColor.actionSecondary, in: Capsule(style: .continuous))
            .contentShape(Capsule(style: .continuous))
    }
}

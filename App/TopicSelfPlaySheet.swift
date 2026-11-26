import SwiftUI

@MainActor private final class TopicSelfPlayModel: ObservableObject {
    let flow: TopicSelfPlayFlow
    @Published var revision = 0
    init(_ flow: TopicSelfPlayFlow) { self.flow = flow; flow.onChange = { [weak self] in self?.revision += 1 } }
}
private enum TopicRevealDestination: Hashable, Identifiable { case wallet, play; var id: Self { self } }
@MainActor struct TopicSelfPlaySheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: TopicSelfPlayModel
    var orders: (() -> AnyView)? = nil
    var tickets: (() -> AnyView)? = nil
    /// R7-PC-B1-12: 开始游戏 on the pass reveal (MP onRevealPlay → pages/play).
    var play: (() -> AnyView)? = nil
    @State private var revealDestination: TopicRevealDestination?
    init(flow: TopicSelfPlayFlow, orders: (() -> AnyView)? = nil, tickets: (() -> AnyView)? = nil, play: (() -> AnyView)? = nil) {
        _model = StateObject(wrappedValue: TopicSelfPlayModel(flow)); self.orders = orders; self.tickets = tickets; self.play = play
    }
    var body: some View {
        NavigationStack {
            Form {
                if model.flow.phase == .complete, model.flow.registrationID != nil {
                    // R7-PC-B1-12: MP cy-pass-reveal (index.wxml:511-513) after the order succeeds.
                    Section {
                        TopicPostPurchaseRevealView(model: TopicPurchaseRevealBuilder.model(topic: model.flow.topic),
                            onWallet: { if tickets != nil { revealDestination = .wallet } },
                            onPlay: { if play != nil { revealDestination = .play } else if tickets != nil { revealDestination = .wallet } })
                            .listRowInsets(EdgeInsets())
                    }
                }
                // Mini-program self-play-checkout order: 1 theme head, pass coverage, 2 single purchase,
                // 3 city passes covering this theme, participant, 7 breakdown.
                Section {
                    if let cover = model.flow.topic.imageURL, !cover.isEmpty {
                        CYCachedAsyncImage(cover)
                            .frame(maxWidth: .infinity).frame(height: 160).clipped()
                            .listRowInsets(EdgeInsets())
                            .accessibilityHidden(true)
                    }
                    Text(verbatim: model.flow.topic.name).cyText(.sectionTitle)
                        .fixedSize(horizontal: false, vertical: true)
                    if let place = model.flow.topic.addressName, !place.isEmpty {
                        Label { Text(verbatim: place) } icon: { Image(systemName: "mappin.and.ellipse") }
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Section {
                    MPPassCheckoutRows(topicID: model.flow.topic.id) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "largecircle.fill.circle").foregroundStyle(.primary).accessibilityHidden(true)
                                Text("mp.pass.checkout.single").cyText(.cardTitle)
                                Spacer()
                                TopicPrice(value: model.flow.topic.selfPlayPrice, label: "topic.selfPlayPrice").labelsHidden()
                            }
                            Text("contextSelfPlay.validity").cyText(.bodyCompact).foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isSelected)
                    }
                }
                if model.flow.pending == nil {
                    Section("contextSelfPlay.participant") {
                        TextField("contextSelfPlay.name", text: Binding(get: { model.flow.realName }, set: { model.flow.realName = $0; model.flow.changed() }))
                            .textContentType(.name).accessibilityIdentifier("contextSelfPlay.name")
                        TextField("contextSelfPlay.phone", text: Binding(get: { model.flow.phone }, set: { model.flow.phone = $0; model.flow.changed() }))
                            .keyboardType(.phonePad).textContentType(.telephoneNumber).autocorrectionDisabled().accessibilityIdentifier("contextSelfPlay.phone")
                    }.disabled(!model.flow.canEdit)
                    billSection
                    Section {
                        if let document = model.flow.document { Link("contextSelfPlay.noticeLink", destination: document.officialURL) }
                        else { Text("contextSelfPlay.documentUnavailable").cyText(.meta) }
                    }
                }
                if model.flow.pending != nil { billSection }
                if let key = model.flow.messageKey { Section { Text(LocalizedStringKey(key)).accessibilityIdentifier("contextSelfPlay.status") } }
                if let explanation = model.flow.paymentExplanation {
                    Section { Text(verbatim: explanation).accessibilityIdentifier("contextSelfPlay.payment.unknown") }
                }
                if model.flow.phase == .creating { ProgressView("contextSelfPlay.creating") }
                if let id = model.flow.registrationID {
                    Section {
                        LabeledContent("contextSelfPlay.order", value: String(id))
                        Button("contextSelfPlay.continuePayment") { Task { await model.flow.prepareExistingPayment() } }.disabled(model.flow.phase == .creating || model.flow.phase == .verifying || model.flow.phase == .complete || model.flow.pending?.paymentAttempted == true)
                        Button("contextSelfPlay.checkOrder") { model.flow.showReadback() }.disabled(model.flow.phase == .creating || model.flow.phase == .verifying)
                        Button("contextSelfPlay.reviewNewOrder") { Task { await model.flow.prepareNewOrderAfterClosure() } }.disabled(model.flow.phase == .creating || model.flow.phase == .verifying)
                        if let orders { NavigationLink("contextSelfPlay.orders") { orders() } }
                        if let tickets { NavigationLink("contextSelfPlay.tickets") { tickets() } }
                    }
                } else if model.flow.pending != nil, let orders {
                    NavigationLink("contextSelfPlay.orders") { orders() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if model.flow.pending == nil {
                    VStack(alignment: .leading, spacing: CYSpacing.sm) {
                        Group {
                            Toggle("contextSelfPlay.consent", isOn: Binding(get: { model.flow.consented }, set: { model.flow.consented = $0; model.flow.changed() }))
                        }
                        .disabled(!model.flow.canCreate)
                        .accessibilityIdentifier("contextSelfPlay.consent")
                        Button(action: { model.flow.prepare() }) {
                            Text("contextSelfPlay.review").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(!model.flow.canCreate)
                        .accessibilityIdentifier("contextSelfPlay.review")
                    }
                    .padding(.horizontal, Theme.Space.pageX)
                    .padding(.vertical, Theme.Space.s2_5)
                    .background(.bar)
                }
            }
            .navigationDestination(item: $revealDestination) { destination in
                switch destination {
                case .wallet: if let tickets { tickets() }
                case .play: if let play { play() }
                }
            }
            .navigationTitle("contextSelfPlay.title").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("action.done") { model.flow.leave(); dismiss() } } }
            .task { await model.flow.open() }
            .onDisappear { model.flow.leave() }
            .cySheet(item: Binding(get: { model.flow.review }, set: { if $0 == nil { model.flow.cancelReview() } })) { review in Group {
                NavigationStack {
                    Form {
                        Text(verbatim: model.flow.topic.name).cyText(.sectionTitle)
                            .fixedSize(horizontal: false, vertical: true)
                        TopicPrice(value: review.price, label: "topic.selfPlayPrice")
                        Text(verbatim: review.intent.realName); Text(verbatim: review.intent.phone)
                        Text("contextSelfPlay.consentReview"); Text("contextSelfPlay.paymentNotice")
                        Link("contextSelfPlay.noticeLink", destination: review.document.officialURL)
                        Button("contextSelfPlay.confirm") { Task { await model.flow.confirm(review) } }.accessibilityIdentifier("contextSelfPlay.confirm")
                        Button("action.cancel", role: .cancel) { model.flow.cancelReview() }
                    }.navigationTitle("contextSelfPlay.review").navigationBarTitleDisplayMode(.inline)
                }
                .presentationDragIndicator(.visible)
            }.cySheet() }
            .cySheet(item: Binding(get: { model.flow.paymentReview }, set: { if $0 == nil { model.flow.cancelPaymentReview() } })) { review in Group {
                TopicSelfPlayPaymentReviewSheet(review: review, confirm: { consent in Task { await model.flow.confirmExistingPayment(review, consented: consent) } }, cancel: model.flow.cancelPaymentReview)
            }.cySheet() }
            .cySheet(item: Binding(get: { model.flow.result }, set: { _ in })) { result in
                PaymentProviderReturnSheet(flow: result) { model.flow.closeResult($0) }
            }
        }
    }
    /// 7 明细: line price and 合计 (no currency symbol is inferred, same as TopicPrice).
    private var billSection: some View {
        Section {
            TopicPrice(value: model.flow.topic.selfPlayPrice, label: "topic.selfPlayPrice")
            LabeledContent {
                if let price = model.flow.topic.selfPlayPrice { Text(verbatim: NSDecimalNumber(decimal: price).stringValue).fontWeight(.semibold) }
                else { Text("topic.priceUnknown") }
            } label: { Text("mp.pass.checkout.total").fontWeight(.semibold) }
            Text("contextSelfPlay.paymentNotice").cyText(.meta)
        } header: { Text("mp.pass.checkout.bill") }
    }
}
@MainActor struct TopicSelfPlayUnavailableSheet: View {
    @Environment(\.dismiss) private var dismiss
    let topic: TopicDetail
    var body: some View {
        NavigationStack {
            Form {
                Text(verbatim: topic.name).cyText(.sectionTitle)
                    .fixedSize(horizontal: false, vertical: true)
                TopicPrice(value: topic.selfPlayPrice, label: "topic.selfPlayPrice")
                Text("contextSelfPlay.validity")
                Text("contextSelfPlay.unavailable")
            }.navigationTitle("contextSelfPlay.title").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("action.done") { dismiss() } } }
        }
    }
}

@MainActor private struct TopicSelfPlayPaymentReviewSheet: View {
    let review: TopicSelfPlayPaymentReview
    let confirm: (Bool) -> Void
    let cancel: () -> Void
    @State private var consented = false
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TopicPrice(value: review.price, label: "topic.selfPlayPrice")
                    Text("contextSelfPlay.paymentNotice")
                    Link("contextSelfPlay.noticeLink", destination: review.document.officialURL)
                }
                Section {
                    Group {
                        Toggle("contextSelfPlay.consent", isOn: $consented)
                    }
                    Button(action: { confirm(consented) }) {
                        Text("contextSelfPlay.continuePayment").frame(maxWidth: .infinity)
                    }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .listRowBackground(Color.clear)
                        .disabled(!consented)
                    Button("action.cancel", role: .cancel, action: cancel)
                }
            }.navigationTitle("contextSelfPlay.review")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

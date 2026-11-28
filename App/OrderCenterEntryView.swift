import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// G2 order center (`subpackageMember/orderinfo` → `order-center-entry`). An order number is looked
/// up with `api/order-center/detail`. A registration order opens the existing order detail; any other
/// kind shows the server's summary. Status is the server's text as sent: nothing here marks an order paid.
@MainActor final class OrderCenterEntryModel: ObservableObject {
    enum Phase: Equatable { case idle, loading, ready(OrderCenterSummary), failed(String) }
    let service: OrderCenterDetailService
    @Published private(set) var phase = Phase.idle
    private var generation = 0
    init(service: OrderCenterDetailService) { self.service = service }

    func load(_ outTradeNo: String) async {
        let trimmed = outTradeNo.trimmingCharacters(in: .whitespacesAndNewlines)
        generation += 1
        let mine = generation
        phase = .loading
        do {
            let summary = try await service.detail(outTradeNo: trimmed)
            guard mine == generation else { return }
            phase = .ready(summary)
        } catch {
            guard mine == generation else { return }
            phase = .failed(Self.messageKey(error as? OrderCenterIssue))
        }
    }

    /// The same states `reloadEntry` / `failed` show.
    static func messageKey(_ issue: OrderCenterIssue?) -> String {
        switch issue {
        case .invalidLink: return "orderCenter.issue.link"
        case .signInRequired: return "orderCenter.issue.signIn"
        case .forbidden: return "orderCenter.issue.forbidden"
        case .notFound: return "orderCenter.issue.notFound"
        case .malformed: return "orderCenter.issue.data"
        default: return "orderCenter.issue.network"
        }
    }
}

@MainActor struct OrderCenterEntryView: View {
    @StateObject var model: OrderCenterEntryModel
    /// A deep link fills this and loads at once, as the mini-program page does.
    var initialOutTradeNo: String = ""
    @Environment(\.mpParity) private var parity
    @Environment(\.locale) private var locale
    @State private var number = ""

    /// MP `order-center-entry` is a deep-link page: it has no number field. The field only shows
    /// when the page is opened from 设置 without a number (native lookup entry).
    private var isDeepLink: Bool { !initialOutTradeNo.isEmpty }

    var body: some View {
        Group {
            // MP wxml:2 `cy-scene-member-order-detail wx:if="{{id}}"`: a registration order shows its detail in place.
            if isDeepLink, case .ready(let summary) = model.phase, summary.kind == .registration, let detail = parity.orderDetail {
                detail(summary.id)
            } else {
                form
            }
        }
        .cyDomainScreen(.player)
        .task {
            guard !initialOutTradeNo.isEmpty, number.isEmpty else { return }
            number = initialOutTradeNo
            await model.load(initialOutTradeNo)
        }
    }

    private var form: some View {
        Form {
            if !isDeepLink {
                Section {
                    TextField(text: $number) { Text("orderCenter.number", tableName: "CreatorEditorUI") }
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .submitLabel(.search)
                        .onSubmit { lookUp() }
                        .accessibilityIdentifier("orderCenter.number")
                    Button { lookUp() } label: { Text("orderCenter.lookup", tableName: "CreatorEditorUI") }
                        .disabled(!canLookUp)
                        .accessibilityIdentifier("orderCenter.lookup")
                }
            }
            switch model.phase {
            case .idle: EmptyView()
            case .loading:
                // MP `cy-empty kind="loading"` 加载中.
                Section { ProgressView { Text("cy.state.loading") }.frame(maxWidth: .infinity) }
                    .listRowBackground(Color.clear)
            case .failed(let key):
                // MP `cy-empty` title + one action (重试).
                Section {
                    ContentUnavailableView {
                        Label { Text(LocalizedStringKey(key), tableName: "CreatorEditorUI") } icon: {
                            Image(systemName: "doc.text.magnifyingglass").accessibilityHidden(true)
                        }
                    } actions: {
                        Button { Task { await model.load(number) } } label: { Text("orderCenter.retry", tableName: "CreatorEditorUI") }
                            .buttonStyle(.bordered)
                    }
                }
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("orderCenter.issue")
            case .ready(let summary):
                if summary.kind == .registration, let detail = parity.orderDetail {
                    Section { NavigationLink { detail(summary.id) } label: { Text("orderCenter.openRegistration", tableName: "CreatorEditorUI") } }
                } else {
                    // MP order-center-entry card order: title → status → 金额 → 订单号 → 创建时间.
                    Section {
                        LabeledContent { Text(verbatim: summary.title) } label: { Text("orderCenter.title", tableName: "CreatorEditorUI") }
                        LabeledContent { Text(verbatim: summary.statusText) } label: { Text("orderCenter.status", tableName: "CreatorEditorUI") }
                        // MP order-center-entry wxml:9 `money.amount(summary.amountText)`: the amount carries ¥.
                        LabeledContent { Text(verbatim: MemberBalanceDisplay.text(summary.amountText, locale: locale)).monospacedDigit() } label: { Text("orderCenter.amount", tableName: "CreatorEditorUI") }
                        // MP wxml:10 `user-select`: the order number can be copied.
                        LabeledContent { Text(verbatim: summary.orderNo).textSelection(.enabled) } label: { Text("orderCenter.orderNo", tableName: "CreatorEditorUI") }
                        if let created = summary.createdAtText {
                            LabeledContent { Text(verbatim: LocaleDisplay.civil(created, locale: locale)) } label: { Text("orderCenter.created", tableName: "CreatorEditorUI") }
                        }
                    }.accessibilityIdentifier("orderCenter.summary")
                    // MP `entry-button open-type="contact"` 联系客服 under the summary card.
                    Section {
                        NavigationLink { ParticipationSupportView() } label: {
                            Label("participationSupport.title", systemImage: "message")
                        }.accessibilityIdentifier("orderCenter.support")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .cyPushedChrome(domain: .player)
        .navigationTitle(Text("orderCenter.navigation", tableName: "CreatorEditorUI")).navigationBarTitleDisplayMode(.inline)
    }

    private var canLookUp: Bool {
        OrderCenterDetailService.validOutTradeNo(number.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func lookUp() {
        guard canLookUp else { return }
        Task { await model.load(number) }
    }
}

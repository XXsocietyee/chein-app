import SwiftUI

@MainActor final class AccountCollectionScreenModel<Value>: ObservableObject {
    @Published private var revision: UInt64 = 0
    private let state = AccountCollectionReadModel<Value>()
    var isLoading: Bool { state.isLoading }
    var loadedScope: UUID? { state.loadedScope }
    func value(scope: UUID) -> Value? { state.visibleValue(scope: scope) }
    func issue(scope: UUID) -> AccountCollectionIssue? { state.visibleIssue(scope: scope) }
    func invalidate() { state.invalidate(); revision &+= 1 }
    func cancelPending() { state.cancelPending(); revision &+= 1 }
    func load(scope: UUID, currentScope: () -> UUID, operation: () async throws -> Value) async {
        revision &+= 1
        await state.load(scope: scope, currentScope: currentScope, operation: operation)
        revision &+= 1
    }
}
@MainActor final class AccountCollectionFavoritesScreenModel: ObservableObject {
    @Published private var revision: UInt64 = 0
    let state = AccountCollectionFavoritesModel()
    func invalidate() { state.invalidate(); revision &+= 1 }
    func cancelPending() { state.cancelPending(); revision &+= 1 }
    func refresh(reader: any AccountCollectionReading, pageSize: Int) async {
        let scope = reader.scope
        revision &+= 1
        await state.refresh(scope: scope, currentScope: { reader.scope }) {
            try await reader.favoriteTopics(pageNumber: 1, pageSize: pageSize)
        }
        revision &+= 1
    }
    func loadMore(reader: any AccountCollectionReading, pageSize: Int) async {
        let scope = reader.scope
        revision &+= 1
        await state.loadMore(scope: scope, currentScope: { reader.scope }) { page in
            try await reader.favoriteTopics(pageNumber: page, pageSize: pageSize)
        }
        revision &+= 1
    }
}
/// pages/mylike display marks taken from `AccountCollectionFavoritesPageModel` (unknown is an em dash, never 0 or 未知).
enum AccountCollectionFavoritesDisplay {
    static let unknownMark = AccountCollectionFavoritesPageModel.unknownMark
}
@MainActor final class AccountCollectionPostsScreenModel: ObservableObject {
    @Published private var revision: UInt64 = 0
    let state = AccountCollectionPostsModel()
    /// First-page body, kept only to classify it through `AccountCollectionFavoritesPageModel`. Never persisted or logged.
    private var firstPayload: Data?
    private var firstPageSize = 10
    func invalidate() { state.invalidate(); firstPayload = nil; revision &+= 1 }
    func cancelPending() { state.cancelPending(); revision &+= 1 }
    /// pages/mylike phase for the first page (loading / empty / error / unknown / ready). Nil before a body arrived
    /// or when the reader supplies no raw body (fixtures); the decoded rows then decide.
    var pagePhase: AccountCollectionFavoritesPostsState? {
        guard let firstPayload else { return nil }
        return AccountCollectionFavoritesPageModel.resolvePosts(loading: false, payload: firstPayload, failure: nil, pageSize: firstPageSize)
    }
    func refresh(reader: any AccountCollectionReading, pageSize: Int) async {
        let scope = reader.scope
        firstPayload = nil; firstPageSize = pageSize
        revision &+= 1
        await state.refresh(scope: scope, currentScope: { reader.scope }) { [weak self] in
            let page = try await reader.favoritePosts(pageNumber: 1, pageSize: pageSize)
            self?.firstPayload = page.rawPayload
            return page
        }
        revision &+= 1
    }
    func loadMore(reader: any AccountCollectionReading, pageSize: Int) async {
        let scope = reader.scope
        revision &+= 1
        await state.loadMore(scope: scope, currentScope: { reader.scope }) { page in
            try await reader.favoritePosts(pageNumber: page, pageSize: pageSize)
        }
        revision &+= 1
    }
}
struct AccountCollectionLoadKey: Hashable {
    let scope: UUID
    let configured: Bool
    let authenticated: Bool
    let query: String
    let id: Int?
    @MainActor init(reader: any AccountCollectionReading, query: String = "", id: Int? = nil) {
        scope = reader.scope; configured = reader.isConfigured; authenticated = reader.isAuthenticated
        self.query = query; self.id = id
    }
}

struct AccountCollectionIssueView: View {
    let issue: AccountCollectionIssue
    var retry: (() -> Void)? = nil
    /// Coupon wallet copy (mini-program coupon-wallet): 优惠券暂时没能打开 over the network or malformed line.
    var couponWallet = false
    /// mp-states r3 (MP mylike.wxml:19-20): 登录后查看收藏 with 登录, and 收藏加载失败 with the reason under it and 重试.
    var favorites = false
    @Environment(\.profileReadSignIn) var signIn
    private var favoritesFailed: Bool {
        favorites && issue != .login && issue != .notConfigured && issue != .unavailable
    }
    private var couponDetailKey: LocalizedStringKey? {
        guard couponWallet else { return nil }
        switch issue {
        case .network: return "accountCollection.coupon.network"
        case .failure: return "accountCollection.coupon.malformed"
        default: return nil
        }
    }
    private var titleText: Text {
        if favorites && issue == .login { return Text("accountCollection.favorites.signIn") }
        if favoritesFailed { return Text("accountCollection.favorites.failed") }
        if case .server(let message) = issue, !message.isEmpty { return Text(verbatim: message) }
        if couponDetailKey != nil { return Text("accountCollection.coupon.errorTitle") }
        return Text(LocalizedStringKey(issue.localizationKey))
    }
    var body: some View {
        let kind: CYStateKind = {
            switch issue {
            case .login, .notConfigured: return .generic
            case .network: return .offline
            default: return .failure
            }
        }()
        var layout = CYStateLayout(kind: kind, title: titleText)
        if let couponDetailKey { layout.detail = Text(couponDetailKey) }
        if favoritesFailed {
            if case .server(let message) = issue, !message.isEmpty { layout.detail = Text(verbatim: message) }
            else { layout.detail = Text(LocalizedStringKey(issue.localizationKey)) }
        }
        if favorites, issue == .login, let signIn {
            layout.primary = (title: LocalizedStringKey("auth.signIn"), action: signIn)
            layout.primaryStyle = .primary
        }
        if let retry, issue != .login, issue != .notConfigured {
            layout.primary = (title: LocalizedStringKey("accountCollection.retry"), action: retry)
            layout.primaryIdentifier = "accountCollection.retry"
        }
        return layout.accessibilityIdentifier("accountCollection.issue")
    }
}
struct AccountCollectionTitle: View {
    let value: String?
    let fallback: LocalizedStringKey
    var body: some View {
        if let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { Text(verbatim: value) }
        else { Text(fallback) }
    }
}
struct AccountCollectionCouponBadge: View {
    let status: AccountCollectionCouponStatus
    private var symbol: String {
        switch status {
        case .unused: return "ticket"
        case .used: return "checkmark.circle"
        case .expired: return "calendar.badge.exclamationmark"
        case .invalid: return "xmark.circle"
        case .unknown: return "questionmark.circle"
        }
    }
    var body: some View {
        OrderStatusChip(title: LocalizedStringKey("accountCollection.coupon.status." + status.rawValue),
                        systemImage: symbol, emphasized: status == .unused)
    }
}
struct AccountCollectionCouponDate: View {
    let label: LocalizedStringKey
    let value: String?
    var body: some View {
        if let day = AccountCollectionCoupon.calendarDay(value) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label).cyText(.meta).foregroundStyle(.secondary)
                Text(verbatim: day).font(.subheadline).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Refresh only the visible screen after foregrounding. Navigation away invalidates any
/// pending completion without destroying the list link that owns a pushed destination.
struct AccountCollectionReadLifecycle: ViewModifier {
    let key: AccountCollectionLoadKey
    let refresh: () async -> Void
    let cancel: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    @State private var visible = false
    @State private var needsRefresh = false
    func body(content: Content) -> some View {
        content
            .task(id: key) { await refresh() }
            .refreshable { await refresh() }
            .onAppear { visible = true; needsRefresh = false }
            .onDisappear { visible = false; cancel() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { needsRefresh = true }
                else if phase == .active, visible, needsRefresh {
                    needsRefresh = false
                    Task { await refresh() }
                }
            }
    }
}

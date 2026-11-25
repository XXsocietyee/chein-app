import SwiftUI

/// MKT-7-1 / flows-g1 `free-explore?requestId=`: MP `loadEntry` reads
/// `GET /api/free-explore/bundle/order/receipt?requestId=` after a purchase. When the reply echoes the same
/// `requestId` with `receipt == "FOUND"`, the page switches to that order's bundle detail (its `registrationId`).
/// Any other `receipt` is 购买结果确认中，请稍后刷新; a failed or mismatched read is 购买结果暂时读不到，请刷新.
/// The app's order detail already hosts the bundle read, so a found receipt lands there (no second renderer).
@MainActor struct FreeExploreReceiptResolveScreen: View {
    let requestID: String
    @ObservedObject var session: AppSession
    var onSignIn: () -> Void = {}

    private enum Phase: Equatable { case loading, signedOut, pending, failed, found(Int) }
    @State private var phase: Phase = .loading

    /// MP `index.js:29`: `/^[A-Za-z0-9_-]{1,64}$/`; anything else is a missing parameter.
    static func isValid(_ id: String) -> Bool {
        (1...64).contains(id.utf8.count) && id.utf8.allSatisfy {
            (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 95 || $0 == 45
        }
    }

    var body: some View {
        content
            .task(id: reloadKey) { await load() }
    }

    private var reloadKey: String {
        guard let context = session.currentRuntimeDependencyContext else { return "signedOut" }
        return "\(context.session.accountID)|\(context.session.epoch)|\(requestID)"
    }

    @ViewBuilder private var content: some View {
        switch phase {
        case .found(let registrationID):
            ProfileOrderDetailView(id: registrationID, reader: session.ownedOrderReader)
        case .loading:
            CYLoadingStateView(rows: 3)
                .cyPageTitle("bundle.receipt.title")
                .accessibilityIdentifier("freeBundle.receipt.loading")
        case .signedOut:
            CYStateLayout(kind: .generic, title: Text("freeBundle.catalog.signIn"),
                          primary: (title: "mp.common.signIn", action: onSignIn),
                          primaryIdentifier: "freeBundle.receipt.signIn")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .cyPageTitle("bundle.receipt.title")
        case .pending, .failed:
            CYStateLayout(kind: phase == .pending ? .generic : .failure,
                          title: Text(LocalizedStringKey(phase == .pending ? "freeBundle.receipt.pending" : "freeBundle.receipt.unreadable")),
                          primary: reloadAction,
                          primaryIdentifier: "freeBundle.receipt.reload")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .cyPageTitle("bundle.receipt.title")
                .accessibilityIdentifier(phase == .pending ? "freeBundle.receipt.pending" : "freeBundle.receipt.failed")
        }
    }

    private var reloadAction: (title: LocalizedStringKey, action: () -> Void) {
        (title: LocalizedStringKey("刷新"), action: { Task { await load() } })
    }

    /// The reply shape the MP checks before trusting a receipt. Returns nil for 确认中, throws for unreadable.
    static func registrationID(from data: PlayWireValue, requestID: String) -> Int?? {
        guard data["requestId"].text == requestID else { return .none }
        guard data["receipt"].text == "FOUND" else { return .some(nil) }
        guard let id = data["order"]["registrationId"].tolerantInteger, id > 0 else { return .none }
        return .some(id)
    }

    private func load() async {
        guard let context = session.currentRuntimeDependencyContext else { phase = .signedOut; return }
        phase = .loading
        let epoch = context.session.epoch, account = context.session.accountID
        let owner = session
        let service = MemberGapService(baseURL: context.baseURL, token: { [weak owner] in
            guard let now = owner?.currentRuntimeDependencyContext, now.session.epoch == epoch,
                  now.session.accountID == account else { return nil }
            return now.session.token
        }, transport: session.runtimeHTTPTransport)
        let reply = await service.fetchFreeExploreReceipt(requestID: requestID)
        guard !Task.isCancelled, let now = session.currentRuntimeDependencyContext,
              now.session.epoch == epoch, now.session.accountID == account else {
            if session.currentRuntimeDependencyContext == nil { phase = .signedOut }
            return
        }
        switch reply {
        case .ok(let data, _):
            switch Self.registrationID(from: data, requestID: requestID) {
            case .some(.some(let id)): phase = .found(id)
            case .some(.none): phase = .pending
            case .none: phase = .failed
            }
        case .unauthorized: phase = .signedOut
        case .refused, .unknown: phase = .failed
        }
    }
}

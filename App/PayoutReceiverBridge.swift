import SwiftUI

/// WP-01 / WP-05 wiring without growing `AppSession` or `AppCompositionRoot`. Requests leave through the reviewed
/// composition transport (`ChinaReviewedProductionTransport`), behind `PayoutReceiverTransport` (route list plus the
/// payout switch) and this app-side lease (`PayoutReceiverRouteGrant` plus `ReviewedAreaSwitch`).
@MainActor enum PayoutReceiverBridge {
    /// Payout area: open for DEBUG/TEST off the production host, closed on www.chengyinhub.com and in Release.
    static func payoutOpen(_ session: AppSession) -> Bool { ReviewedAreaSwitch.payoutOpen(session: session) }
    static func paymentsOpen(_ session: AppSession) -> Bool { ReviewedAreaSwitch.paymentsOpen(session: session) }
    /// CLB-settlement-05 (MP settlement/index.js:117-125; cy/fe-reference-settlement/index.js:41): the settlement **reads**
    /// (mine list, personal summary, direct ledger, FE payer list and export) move no money, so they are not behind the
    /// payout area. Bind, unbind, settle and withdraw stay TEST-only (AppLease / ReleaseMoneyWriteSwitch / FE money gate).
    static func readsOpen(_ session: AppSession) -> Bool { session.regionalConfiguration?.apiConfiguration != nil }

    /// The native app has no mini-program `wx.login`. Bind needs a one-time WeChat code; the WeChat SDK is not configured
    /// in this build, so this stays nil and bind answers 「请先完成微信登录」 instead of sending a request.
    static var weChatCode: (@MainActor () async -> String?)?

    static func service(_ session: AppSession) -> PayoutReceiverService? {
        guard let configuration = session.regionalConfiguration?.apiConfiguration else { return nil }
        let guarded = PayoutReceiverTransport(underlying: session.composition.makeTransport())
        return PayoutReceiverService(configuration: configuration, transport: AppLease(underlying: guarded, open: { [weak session] in
            guard let session else { return false }
            return payoutOpen(session)
        }))
    }

    /// Runs one call with the current token; a 401 expires the matching session like the other readers.
    static func call<T>(_ session: AppSession, _ body: (PayoutReceiverService, String) async throws -> T) async throws -> T {
        guard let service = service(session) else { throw PayoutReceiverIssue.closed }
        guard let token = session.token else { throw PayoutReceiverIssue.unauthorized }
        let stamp = session.sessionRevision
        do { return try await body(service, token) }
        catch let issue as PayoutReceiverIssue where issue == .unauthorized {
            session.expireIfMatching(error: APIError.unauthorized, stamp: stamp, credential: token)
            throw issue
        }
    }

    /// `POST /api/registration/payment-readiness`, read only while the payment area is open.
    static func paymentReadiness(_ session: AppSession) async -> RegistrationPaymentReadiness? {
        guard paymentsOpen(session), let configuration = session.regionalConfiguration?.apiConfiguration,
              let token = session.token else { return nil }
        let transport = PaymentReadinessLease(underlying: session.composition.makeTransport())
        return try? await RegistrationPaymentReadiness.read(configuration: configuration, transport: transport, token: token)
    }

    private struct AppLease: HTTPTransport {
        let underlying: any HTTPTransport
        let open: @MainActor () -> Bool
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            guard let route = PayoutReceiverRoute(request: request), PayoutReceiverRouteGrant.admits(route) else { throw APIError.notConfigured }
            // Owner 2026-11-14: status reads pass; the bind/unbind writes need the payout area open.
            if route.isPayout { guard await open() else { throw APIError.notConfigured } }
            return try await underlying.send(request)
        }
    }

    private struct PaymentReadinessLease: HTTPTransport {
        let underlying: any HTTPTransport
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            guard request.httpMethod == "POST", request.url?.query == nil,
                  let path = request.url?.path, PayoutReceiverRouteGrant.paymentReadPaths.contains(where: { path.hasSuffix("/" + $0) }) else {
                throw APIError.notConfigured
            }
            return try await underlying.send(request)
        }
    }
}

/// Copy for one `PayoutReceiverIssue`: a known code's own text, a human server sentence, or the screen's fallback.
struct PayoutReceiverIssueText: View {
    let issue: PayoutReceiverIssue
    let fallbackKey: String
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            if let key = issue.codeKey { Text(LocalizedStringKey(key), tableName: "PayoutReceiver") }
            else if let sentence = issue.serverSentence { Text(verbatim: sentence) }
            else if issue == .network { Text("payoutReceiver.error.network", tableName: "PayoutReceiver") }
            else if issue == .closed { Text("payoutReceiver.closed", tableName: "PayoutReceiver") }
            else { Text(LocalizedStringKey(fallbackKey), tableName: "PayoutReceiver") }
            if issue != .closed, issue != .unauthorized, let row = RequestReferenceRow(pathFragment: "/api/") { row }
        }
    }
}

/// Production and Release: the page stays, with one sentence, and sends nothing.
struct PayoutAreaClosedNote: View {
    @Environment(\.locale) private var locale
    var body: some View {
        Section {
            CYStatusChip(verbatim: payoutText("payoutReceiver.closed", locale), tone: .neutral, systemImage: "lock")
                .accessibilityIdentifier("payoutReceiver.closed")
        }
    }
}

/// `PayoutReceiver` table lookup in the view's environment locale (Foundation `String(localized:)` would not follow it).
func payoutText(_ key: String, _ locale: Locale) -> String {
    String(localized: LocalizedStringResource(String.LocalizationValue(key), table: "PayoutReceiver", locale: locale))
}

import SwiftUI
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Exit-swap gate. Admits `GET exit-options?registrationId=<this>&unitId=<n>` and a `POST exit-decision` whose body is
/// `SWAP_CONSENTED` with a target. A refund decision, another registration, or any other bundle route is refused.
@MainActor final class BundleExitSwapTransport: HTTPTransport {
    private let context: RuntimeDependencyContext
    private let registrationID: FreeExploreLaunchID
    private let underlying: any HTTPTransport
    private let current: () -> Bool
    private let denied: () -> Void
    private var active = true

    init(context: RuntimeDependencyContext, registrationID: FreeExploreLaunchID, underlying: any HTTPTransport,
         current: @escaping () -> Bool, denied: @escaping () -> Void) {
        self.context = context; self.registrationID = registrationID; self.underlying = underlying
        self.current = current; self.denied = denied
    }

    func admits(_ request: URLRequest) -> Bool {
        guard active, current(), request.httpBodyStream == nil,
              request.value(forHTTPHeaderField: "Authorization") == context.session.token,
              let url = request.url, let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.user == nil, parts.password == nil, parts.fragment == nil else { return false }
        let base = context.baseURL.appendingPathComponent("api/free-explore/bundle/")
        if request.httpMethod == "GET", request.httpBody == nil,
           parts.path == base.appendingPathComponent("exit-options").path,
           let items = parts.queryItems, items.count == 2,
           items.first(where: { $0.name == "registrationId" })?.value == registrationID.text,
           let unit = items.first(where: { $0.name == "unitId" })?.value, Int64(unit).map({ $0 > 0 }) == true {
            return true
        }
        guard request.httpMethod == "POST", parts.query == nil, parts.path == base.appendingPathComponent("exit-decision").path,
              let body = request.httpBody,
              let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              object["decision"] as? String == BundleExitDecision.swapConsented.rawValue,
              object["targetOfferId"] != nil, object["unitId"] != nil, object["idempotencyKey"] is String else { return false }
        return Set(object.keys).isSubset(of: ["unitId", "decision", "targetOfferId", "idempotencyKey"])
    }

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        try Task.checkCancellation()
        guard admits(request) else { throw APIError.notConfigured }
        let result = try await underlying.send(request)
        guard active, current() else { throw APIError.notConfigured }
        let code = (try? JSONSerialization.jsonObject(with: result.0) as? [String: Any])?["code"] as? Int
        if result.1 == 403 || code == 403 { active = false; denied(); throw APIError.notConfigured }
        return result
    }
}

/// 「换商家」: per unit, read exit options; when the merchant exited, consent a swap to one target.
/// The idempotency key is kept until the order shows that exit case (or a definite refusal clears it).
struct BundleExitSwapView: View {
    let host: FreeExploreBundleReadHost
    @Environment(\.locale) private var locale
    @State private var tools: (client: BundleAPIClient, service: any FreeExploreLaunchServing)?
    @State private var units: [FreeExploreLaunchOrder.Bundle.Unit] = []
    @State private var options: BundleExitOptions?
    @State private var pendingKey: (unit: FreeExploreLaunchID, target: FreeExploreLaunchID, key: String)?
    @State private var confirming: BundleExitOptions.Target?
    @State private var notice: String?
    @State private var error: String?
    @State private var busy = false

    private static let definiteRefusals: Set<String> = [
        "BUNDLE_MERCHANT_NOT_EXITED", "BUNDLE_STORE_UNAVAILABLE", "BUNDLE_SWAP_SHORTENS_VALIDITY",
        "BUNDLE_UNIT_UNAVAILABLE", "BUNDLE_RESERVATION_OFF", "BUNDLE_NOT_FOUND"
    ]

    var body: some View {
        List {
            if let notice { Text(verbatim: notice).foregroundStyle(CYColor.textSecondary) }
            if let error { Text(verbatim: error).foregroundStyle(CYColor.dangerText) }
            ForEach(units, id: \.id) { unit in
                Button { Task { await loadOptions(unit.id) } } label: {
                    Text(verbatim: PlayerCapabilityCopy.text("权益 #", "Unit #", locale) + unit.id.text + " · " + unit.status)
                }
                .disabled(busy || pendingKey != nil)
                .accessibilityIdentifier("bundle.exit.unit.\(unit.id.text)")
            }
            if let options {
                Section(PlayerCapabilityCopy.text("可换商家", "Swap to", locale)) {
                    if !options.merchantExited || options.targets.isEmpty {
                        Text(verbatim: PlayerCapabilityCopy.text("这家商家仍在营业，无需更换", "This merchant is still open", locale))
                            .foregroundStyle(CYColor.textSecondary)
                    }
                    ForEach(options.merchantExited ? options.targets : [], id: \.offerId) { target in
                        Button { confirming = target } label: {
                            Text(verbatim: (target.merchantName ?? "—") + (target.validEnd.map { " · " + $0.raw } ?? ""))
                        }
                        .disabled(busy || pendingKey != nil)
                        .accessibilityIdentifier("bundle.exit.target.\(target.offerId.text)")
                    }
                }
            }
        }
        .navigationTitle(PlayerCapabilityCopy.text("更换商家", "Swap merchant", locale)).navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: Binding(get: { confirming != nil }, set: { if !$0 { confirming = nil } })) {
            if let target = confirming {
                MemberBundleSwapConfirmSheet(merchantName: target.merchantName ?? "—") {
                    confirming = nil
                    Task { await swap(target) }
                }
            }
        }
        .task { await start() }
        .cyDomainScreen(.player)
    }

    private func start() async {
        do {
            let made = try host.makeExitSwap()
            tools = made
            await reload()
        } catch { self.error = "可换商家加载失败" }
    }

    private func reload() async {
        guard let tools else { return }
        do {
            let order = try await tools.service.order(registrationID: host.registrationID)
            units = order.bundle?.units ?? []
        } catch { self.error = "权益加载失败，请重试" }
    }

    private func loadOptions(_ unit: FreeExploreLaunchID) async {
        guard let tools, pendingKey == nil else { return }
        options = nil; error = nil
        do { options = try await tools.client.exitOptions(registrationID: host.registrationID, unitID: unit) }
        catch { self.error = "可换商家加载失败" }
    }

    private func swap(_ target: BundleExitOptions.Target) async {
        guard let tools, let options, !busy else { return }
        confirming = nil
        let key = pendingKey?.key ?? ("fx-swap-" + String(Int64(Date().timeIntervalSince1970 * 1000)) + "-"
            + String(UInt64.random(in: 1...UInt64(UInt32.max)) << 16, radix: 36))
        pendingKey = (options.unitId, target.offerId, key)
        busy = true; error = nil
        do {
            let command = try BundleExitDecisionCommand(unitId: options.unitId, decision: .swapConsented,
                                                        targetOfferId: target.offerId, idempotencyKey: String(key.prefix(64)))
            let row = try await tools.client.exitDecision(command)
            if row.targetOfferId == target.offerId { pendingKey = nil; self.options = nil; notice = "已更换商家"; await reload() }
        } catch FreeExploreLaunchFailure.response(_, _, let business, _) where business.map(Self.definiteRefusals.contains) == true {
            pendingKey = nil; self.options = nil; self.error = "更换未成功，请刷新"
        } catch {
            notice = "换店结果确认中，请稍后刷新"
        }
        busy = false
    }
}

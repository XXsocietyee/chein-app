import SwiftUI
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@MainActor struct PlayGapMiscSurfaces: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.locale) private var locale
    var body: some View {
        List {
            NavigationLink { PlayGapDevicePage(session: session) } label: { Text("playGap.device", tableName: "PlayGapMisc") }
            NavigationLink { PlayGapHomePage(session: session) } label: { Text("playGap.home", tableName: "PlayGapMisc") }
            NavigationLink { PlayGapReturnPage(session: session) } label: { Text("playGap.return", tableName: "PlayGapMisc") }
            NavigationLink { PlayGapProductPage(session: session) } label: { Text("playGap.product", tableName: "PlayGapMisc") }
            NavigationLink { PlayGapSmsPage(session: session) } label: { Text("playGap.sms", tableName: "PlayGapMisc") }
            NavigationLink { PlayGuardAppealLookupView() } label: {
                Text(verbatim: ChannelCopy.text("原局守卫申诉", "Guard Appeal", locale: locale))
            }
            .accessibilityIdentifier("playGap.guardAppeal")
        }
        .navigationTitle(Text("playGap.title", tableName: "PlayGapMisc"))
        .accessibilityIdentifier("playGap.surfaces")
    }
}

@MainActor struct PlayGapDevicePage: View {
    let session: AppSession
    @State private var keyText = ""
    @State private var line = "—"
    var body: some View {
        Form {
            Text("playGap.device.key", tableName: "PlayGapMisc")
            TextField("", text: $keyText)
            Button { Task { await loadStatus() } } label: { Text("playGap.device.status", tableName: "PlayGapMisc") }
            Button { Task { await challenge() } } label: { Text("playGap.device.challenge", tableName: "PlayGapMisc") }
            Text(verbatim: line).accessibilityIdentifier("playGap.device.line")
        }
    }
    private func loadStatus() async {
        guard let service = enrollment(enrollmentEnabled: true) else { line = "—"; return }
        do {
            let status = try await service.status(key: keyText.isEmpty ? nil : keyText)
            line = status.state.rawValue
        } catch {
            line = String(describing: error)
        }
    }
    private func challenge() async {
        guard NativeEnrollmentWire.validKey(keyText), let service = enrollment(enrollmentEnabled: true) else { line = "—"; return }
        do {
            let value = try await service.challenge(key: keyText)
            line = value.challengeID
        } catch {
            line = String(describing: error)
        }
    }
    private func enrollment(enrollmentEnabled: Bool) -> NativeEnrollmentService? {
        guard let context = session.currentRuntimeDependencyContext,
              let api = try? APIConfiguration(baseURL: context.baseURL),
              let scope = try? NativeEnrollmentScope(namespace: context.session.namespace, accountID: context.session.accountID, appID: "com.chengyinhub.chengyinApp", environment: "production") else { return nil }
        let owner = context.session
        return NativeEnrollmentService(api: api, transport: PlayGapTransport(session: session), scope: scope, owner: owner, enabled: true, enrollmentEnabled: enrollmentEnabled, revocationEnabled: true, current: { [session] in session.currentRuntimeDependencyContext?.session })
    }
}

@MainActor struct PlayGapHomePage: View {
    let session: AppSession
    @State private var label = ""
    @State private var latitude = ""
    @State private var longitude = ""
    @State private var version: Int64?
    @State private var line = "—"
    var body: some View {
        Form {
            Button { Task { await load() } } label: { Text("playGap.home.load", tableName: "PlayGapMisc") }
            Text("playGap.home.label", tableName: "PlayGapMisc")
            TextField("", text: $label)
            Text("playGap.home.latitude", tableName: "PlayGapMisc")
            TextField("", text: $latitude)
            Text("playGap.home.longitude", tableName: "PlayGapMisc")
            TextField("", text: $longitude)
            Button { Task { await save() } } label: { Text("playGap.home.save", tableName: "PlayGapMisc") }
            Text(verbatim: line).accessibilityIdentifier("playGap.home.line")
        }
    }
    private func load() async {
        guard let service = homeService() else { line = "—"; return }
        do {
            let snapshot = try await service.load()
            version = snapshot.version
            line = snapshot.status.rawValue
        } catch {
            line = String(describing: error)
        }
    }
    private func save() async {
        guard let service = homeService(), let expected = version, let point = try? PrivateHomePoint.parse(latitude: latitude, longitude: longitude) else { line = "—"; return }
        do {
            let mutation = try PrivateHomeMutation(expectedVersion: expected, label: label, point: point)
            let receipt = try await service.mutate(mutation)
            version = receipt.version
            line = receipt.decision.rawValue
        } catch {
            line = String(describing: error)
        }
    }
    private func homeService() -> PrivateHomeService? {
        guard let context = session.currentRuntimeDependencyContext, let api = try? APIConfiguration(baseURL: context.baseURL) else { return nil }
        let owner = context.session
        return PrivateHomeService(api: api, transport: PlayGapTransport(session: session), owner: owner, enabled: true, current: { [session] in session.currentRuntimeDependencyContext?.session })
    }
}

@MainActor struct PlayGapReturnPage: View {
    let session: AppSession
    @State private var line = "—"
    var body: some View {
        Form {
            Button { Task { await load() } } label: { Text("playGap.return.policy", tableName: "PlayGapMisc") }
            Text(verbatim: line).accessibilityIdentifier("playGap.return.line")
        }
    }
    private func load() async {
        guard let context = session.currentRuntimeDependencyContext,
              let approval = try? NativeHomeReturnApproval(context: context, expiresAt: Date().addingTimeInterval(600)) else { line = "—"; return }
        let service = NativeHomeReturnService(approval: approval, transport: PlayGapTransport(session: session), current: { [session] in session.currentRuntimeDependencyContext }, selected: { _ in approval })
        do {
            guard let policy = try await service.policy() else { line = "—"; return }
            line = policy.policyVersion
        } catch {
            line = String(describing: error)
        }
    }
}

@MainActor struct PlayGapProductPage: View {
    let session: AppSession
    @State private var rows: [PlayGapProduct] = []
    @State private var line = "—"
    var body: some View {
        Form {
            Text("playGap.product.digital", tableName: "PlayGapMisc")
            Button { Task { await load() } } label: { Text("playGap.product.load", tableName: "PlayGapMisc") }
            if rows.isEmpty { Text(verbatim: "—") }
            ForEach(rows) { row in
                Button { Task { await buy(row) } } label: { Text(verbatim: row.name) }
                    .accessibilityIdentifier("playGap.product.buy")
            }
            Text(verbatim: line).accessibilityIdentifier("playGap.product.line")
        }
    }
    private func load() async {
        guard let payload = try? await PlayGapHTTP.get(session: session, path: "api/marketing/product/list") else { line = "—"; return }
        rows = PlayGapProduct.parse(payload)
        line = rows.isEmpty ? "—" : String(rows.count)
    }
    private func buy(_ row: PlayGapProduct) async {
        guard ReviewedAreaSwitch.moneyPayments(host: session.currentRuntimeDependencyContext?.baseURL.host) else {
            line = NSLocalizedString("playGap.product.closed", tableName: "PlayGapMisc", comment: "")
            return
        }
        guard row.route != 2 else { line = row.reason ?? "—"; return }
        do {
            let quote = try await PlayGapHTTP.post(session: session, path: "api/marketing/product/quote", body: ["productId": row.id, "quantity": 1, "fulfillmentKind": 1])
            let modes = quote["data"]["availablePayModes"].array?.compactMap(\.integer) ?? []
            guard modes.contains(2), let sign = quote["data"]["quoteSign"].text, let expiry = quote["data"]["quoteExpiresAt"].integer else {
                line = NSLocalizedString("playGap.product.cash", tableName: "PlayGapMisc", comment: "")
                return
            }
            let order = try await PlayGapHTTP.post(session: session, path: "api/marketing/product/order", body: [
                "productId": row.id, "payMode": 2, "quantity": 1, "fulfillmentKind": 1,
                "quoteSign": sign, "quoteExpiresAt": expiry, "requestId": UUID().uuidString
            ])
            guard order["code"].integer == 200 else { line = order["msg"].text ?? "—"; return }
            let number = order["data"]["orderNo"].text ?? "—"
            let status = order["data"]["status"].integer.map(String.init) ?? "—"
            line = number + " " + status
        } catch {
            line = String(describing: error)
        }
    }
}

@MainActor struct PlayGapSmsPage: View {
    let session: AppSession
    @State private var phone = ""
    @State private var line = "—"
    var body: some View {
        Form {
            Text("playGap.sms.note", tableName: "PlayGapMisc")
            Text("playGap.sms.phone", tableName: "PlayGapMisc")
            TextField("", text: $phone)
            Button { Task { await send() } } label: { Text("playGap.sms.send", tableName: "PlayGapMisc") }
            Text(verbatim: line).accessibilityIdentifier("playGap.sms.line")
        }
    }
    private func send() async {
        guard phone.range(of: "^1\\d{10}$", options: .regularExpression) != nil else { line = "—"; return }
        do {
            let payload = try await PlayGapHTTP.form(session: session, path: "api/sms/send", fields: ["phone": phone])
            line = payload["msg"].text ?? "—"
        } catch {
            line = String(describing: error)
        }
    }
}

struct PlayGapProduct: Identifiable, Equatable {
    let id: Int
    let name: String
    let route: Int
    let reason: String?
    static func parse(_ payload: PlayWireValue) -> [PlayGapProduct] {
        let rows = payload["data"].array ?? payload["data"]["rows"].array ?? []
        return rows.compactMap { row in
            guard let id = row["productId"].integer, id > 0 else { return nil }
            let trimmed = row["productName"].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let name = trimmed.isEmpty ? "—" : trimmed
            return PlayGapProduct(id: id, name: name, route: row["purchaseRoute"].integer ?? 0, reason: row["purchaseRouteReason"].text)
        }
    }
}

private struct PlayGapTransport: HTTPTransport {
    let session: AppSession
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        try await ChinaReviewedProductionTransport(underlying: PlayGapURLSessionTransport()).send(request)
    }
}

private struct PlayGapURLSessionTransport: HTTPTransport {
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        let (data, response) = try await URLSession.shared.data(for: request)
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
    }
}

@MainActor private enum PlayGapHTTP {
    static func get(session: AppSession, path: String) async throws -> PlayWireValue {
        try await send(session: session, path: path, method: "GET", body: nil, contentType: nil)
    }
    static func post(session: AppSession, path: String, body: [String: Any]) async throws -> PlayWireValue {
        try await send(session: session, path: path, method: "POST", body: try JSONSerialization.data(withJSONObject: body), contentType: "application/json")
    }
    static func form(session: AppSession, path: String, fields: [String: String]) async throws -> PlayWireValue {
        let text = fields.map { key, value in
            let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
            return encodedKey + "=" + encodedValue
        }.joined(separator: "&")
        return try await send(session: session, path: path, method: "POST", body: Data(text.utf8), contentType: "application/x-www-form-urlencoded")
    }
    private static func send(session: AppSession, path: String, method: String, body: Data?, contentType: String?) async throws -> PlayWireValue {
        guard let context = session.currentRuntimeDependencyContext else { throw APIError.notConfigured }
        var request = URLRequest(url: context.baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(context.session.token, forHTTPHeaderField: "Authorization")
        if let contentType { request.setValue(contentType, forHTTPHeaderField: "Content-Type") }
        let (data, status) = try await PlayGapTransport(session: session).send(request)
        guard (200..<300).contains(status) else { throw APIError.httpStatus(status) }
        return try JSONDecoder().decode(PlayWireValue.self, from: data)
    }
}

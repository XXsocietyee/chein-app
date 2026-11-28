import Foundation

/// Owner correction 11-28 04:45 (mp-activity): CN pays with WeChat Pay **and Alipay**. The backend returns a
/// signed `orderString`; the app hands it to the Alipay SDK and the SDK answers through the app's URL scheme
/// (`<scheme>://safepay/...`). Like `WeChatSDKPaymentAdapter`, a provider answer only ends the wait: the caller
/// always reconciles the order on the server (order-status poll). No SDK binary is linked yet, so the adapter
/// stays unconfigured (and renders nothing) until a driver reports `isLinked` and the money switches allow it.
public struct AlipaySDKPaymentConfiguration: Equatable {
    public let appScheme: String
    public init(appScheme: String) throws {
        let scheme = appScheme.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !scheme.isEmpty, scheme.utf8.count <= 64,
              scheme.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) || $0 == "." || $0 == "-" || $0 == "+" }),
              scheme.unicodeScalars.first.map({ CharacterSet.letters.contains($0) }) == true else { throw APIError.invalidConfiguration }
        self.appScheme = scheme
    }
    /// Only the SDK's own return route (`safepay` host) on this app's scheme.
    public func acceptsURL(_ url: URL) -> Bool {
        url.scheme?.lowercased() == appScheme.lowercased() && url.host?.lowercased() == "safepay"
    }
}

/// The signed order string, transient. Never Codable, persisted, logged, or shown in UI.
public struct AlipaySDKPaymentRequest {
    public let orderString: String
    public init(parameters: [String: String]) throws {
        guard let value = parameters["orderString"] ?? parameters["order_string"], !value.isEmpty,
              value.utf8.count <= 8192, !value.contains("\n") else { throw APIError.invalidRequest }
        orderString = value
    }
}

@MainActor public protocol AlipaySDKPaymentDriving: AnyObject {
    var isLinked: Bool { get }
    /// `payOrder:fromScheme:callback:`; `result` receives the SDK `resultStatus` string.
    func pay(orderString: String, fromScheme: String, result: @escaping (String) -> Void)
    /// `processOrderWithPaymentResult:standbyCallback:` for the app-switch return.
    func handle(_ url: URL, result: @escaping (String) -> Void) -> Bool
}

@MainActor public final class AlipaySDKPaymentAdapter: TopicSelfPlayPaymentProviding {
    private struct Pending {
        let id: UUID
        let registrationID: Int
        let context: RuntimeDependencyContext
        let callback: (TopicSelfPlayProviderReturn) -> Void
    }
    private let driver: (any AlipaySDKPaymentDriving)?
    private let configuration: AlipaySDKPaymentConfiguration?
    private let allowed: () -> Bool
    private let context: () -> RuntimeDependencyContext?
    private let timeoutNanoseconds: UInt64
    private var pending: Pending?
    private var timeout: Task<Void, Never>?

    public init(driver: (any AlipaySDKPaymentDriving)? = nil, configuration: AlipaySDKPaymentConfiguration? = nil,
                allowed: @escaping () -> Bool = { false }, context: @escaping () -> RuntimeDependencyContext?,
                timeoutNanoseconds: UInt64 = 120_000_000_000) {
        self.driver = driver; self.configuration = configuration; self.allowed = allowed; self.context = context
        self.timeoutNanoseconds = max(1, timeoutNanoseconds)
    }

    public var isConfigured: Bool {
        guard allowed(), let context = context(), context.market == .china,
              ["player", "club"].contains(context.role), configuration != nil, driver?.isLinked == true else { return false }
        return true
    }
    public var pendingRegistrationID: Int? { pending?.registrationID }

    /// SDK `resultStatus`: 9000 returned (still not proof of payment), 6001 cancelled,
    /// 8000 / 6004 processing or unknown, anything else failed.
    public static func outcome(resultStatus: String) -> TopicSelfPlayProviderReturn {
        switch resultStatus.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "9000": return .returned
        case "6001": return .cancelled
        case "8000", "6004": return .unknown
        default: return .failed
        }
    }

    public func pay(registrationID: Int, parameters: [String: String]) async -> TopicSelfPlayProviderReturn {
        guard pending == nil, registrationID > 0, isConfigured, !Task.isCancelled,
              let captured = context(), let configuration, let driver,
              let request = try? AlipaySDKPaymentRequest(parameters: parameters) else { return .unknown }
        let attempt = UUID()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                if Task.isCancelled { continuation.resume(returning: .unknown); return }
                pending = Pending(id: attempt, registrationID: registrationID, context: captured, callback: { continuation.resume(returning: $0) })
                timeout = Task { [weak self] in
                    guard let self else { return }
                    do { try await Task.sleep(nanoseconds: self.timeoutNanoseconds) } catch { return }
                    self.finish(.unknown, id: attempt)
                }
                driver.pay(orderString: request.orderString, fromScheme: configuration.appScheme, result: { [weak self] status in
                    guard let self, self.current(attempt) else { return }
                    self.finish(Self.outcome(resultStatus: status), id: attempt)
                })
            }
        } onCancel: { Task { @MainActor [weak self] in self?.finish(.unknown, id: attempt) } }
    }

    public func acceptsURL(_ url: URL) -> Bool {
        guard let id = pending?.id, current(id) else { return false }
        return configuration?.acceptsURL(url) == true
    }

    /// Routes the app-switch return to the SDK; only while this adapter waits on an order.
    public func handle(_ url: URL) -> Bool {
        guard let id = pending?.id, acceptsURL(url), let driver else { return false }
        return driver.handle(url, result: { [weak self] status in
            guard let self, self.current(id) else { return }
            self.finish(Self.outcome(resultStatus: status), id: id)
        })
    }

    public func cancelPending() { if let pending { finish(.unknown, id: pending.id) } }

    private func current(_ id: UUID) -> Bool {
        guard let pending, pending.id == id else { return false }
        guard isConfigured, context() == pending.context else { finish(.unknown, id: id); return false }
        return true
    }

    private func finish(_ outcome: TopicSelfPlayProviderReturn, id: UUID) {
        guard let pending, pending.id == id else { return }
        self.pending = nil; timeout?.cancel(); timeout = nil; pending.callback(outcome)
    }
}

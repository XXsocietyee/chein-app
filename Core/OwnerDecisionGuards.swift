import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// WP-10 owner-decision guards. The server quote is the only point-to-yuan source.
/// Club bind needs a `wx.login` code, so native never sends `/api/club/personal-receiver/bind`.
public enum OwnerDecisionAILabel {
    public static let generated = "AI 生成"
    public static let assistedMark = "[AI 辅助生成]"

    /// `aiPlanToDraft.js`: a trace id keeps the mark on the draft. No trace adds nothing.
    public static func draftDescription(_ text: String, traceID: String?) -> String {
        guard let traceID, !traceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return text }
        if text.contains(assistedMark) { return text }
        return text.isEmpty ? assistedMark : text + "  " + assistedMark
    }

    /// Adopted templates show the author's name only. AI marks are not copied onto the credit.
    public static func adoptedAuthorName(_ name: String?) -> String? {
        guard var value = name?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        for mark in [generated, assistedMark, "  " + assistedMark] {
            value = value.replacingOccurrences(of: mark, with: "")
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

/// Author revenue (OWN-D-10). An empty list or a non-participant hides the tab.
/// A failed read is unavailable copy, never a numeric 0.
public enum OwnerDecisionRevenueGate {
    public static let unavailable = "收益暂不可用"
    public enum Phase: Equatable { case hidden, unavailable, ready }
    public static func phase(readFailed: Bool, participant: Bool, isEmpty: Bool) -> Phase {
        if readFailed { return .unavailable }
        if !participant || isEmpty { return .hidden }
        return .ready
    }
}

/// One chain per surface. Nothing here flips a surface onto the other chain.
public enum OwnerDecisionContentChain {
    public struct Surface: Equatable, Sendable {
        public let name: String
        public let chain: String
        public let path: String
        public let clientFile: String
    }

    public static let community = "/api/v1/community"
    public static let creativeSquare = "/api/creativesquare"

    public static let surfaces: [Surface] = [
        .init(name: "feed", chain: community, path: "api/v1/community/feeds/", clientFile: "Core/SquareService.swift"),
        .init(name: "notifications", chain: community, path: "api/v1/community/notifications", clientFile: "Core/SquareGovernanceService.swift"),
        .init(name: "enforcements", chain: community, path: "api/v1/community/me/enforcements", clientFile: "Core/SquareGovernanceService.swift"),
        .init(name: "appeals", chain: community, path: "api/v1/community/appeals", clientFile: "Core/SquareGovernanceService.swift"),
        .init(name: "capabilities", chain: community, path: "api/v1/community/capabilities", clientFile: "Core/SquareReportService.swift"),
        .init(name: "reports", chain: community, path: "api/v1/community/reports", clientFile: "Core/SquareReportService.swift"),
        .init(name: "compose", chain: creativeSquare, path: "api/creativesquare/action", clientFile: "Core/SocialActionContracts.swift"),
        .init(name: "detail", chain: creativeSquare, path: "api/creativesquare/info", clientFile: "Core/SquareService.swift"),
        .init(name: "like", chain: creativeSquare, path: "api/creativesquare/like", clientFile: "Core/SocialActionContracts.swift"),
        .init(name: "bookmark", chain: creativeSquare, path: "api/creativesquare/bookmark", clientFile: "Core/ProfileFavoriteRemoval.swift"),
        .init(name: "report", chain: creativeSquare, path: "api/creativesquare/report", clientFile: "Core/SocialActionContracts.swift"),
        .init(name: "delete", chain: creativeSquare, path: creativeSquare, clientFile: "Core/OwnerDecisionGuards.swift")
    ]

    /// Square delete stays in WP-04. This package does not retarget that client.
    public static let squareDeleteOwnedBy = "WP-04"
}

/// Ending text is the server fragment list, in the order the server sent it.
public struct OwnerDecisionEndingRender: Equatable {
    public static let playPath = "api/play/ending"
    public static let journeyPath = "api/play/journey/ending"
    public let sourcePath: String
    public let fragments: [String]

    public init(sourcePath: String, fragments: [String]) throws {
        guard sourcePath == Self.playPath || sourcePath == Self.journeyPath else { throw APIError.invalidRequest }
        self.sourcePath = sourcePath
        self.fragments = fragments
    }
}

/// Confirm copy from `utils/danger-actions.js` `club.personal-receiver.unbind`.
public enum OwnerDecisionReceiverCopy {
    public static let unbindTitle = "解除个人收款?"
    public static let unbindConsequence = "解除后新的俱乐部收入会暂停，重新绑定后继续"
    public static let unbindConfirm = "解除绑定"
    public static let unbindDone = "已解除绑定"
    public static let bindHandoff = "请在小程序完成绑定"
    public static let miniProgramPath = "pages/club/payout-receiver/index"
    public static let merchantPage = "pages/merchant/payout-account/index"
    public static let financePermission = "merchant:finance:read"
    public static let financePermissionAlias = "FINANCE_READ"
}

public struct OwnerDecisionReceiverStatus: Equatable {
    public enum Page: String, Equatable { case unbound, paused, bound }
    public let page: Page
    public let stateText: String
    public let payoutText: String
    public let pauseText: String
    public let canUnbind: Bool

    public static func shape(_ data: [String: Any]) -> OwnerDecisionReceiverStatus? {
        guard (data["available"] as? Bool) == true else { return nil }
        guard let state = data["receiverState"] as? String,
              state == "UNBOUND" || state == "CONSENTED" || state == "VERIFIED" else { return nil }
        let bound = state != "UNBOUND"
        let paused = (data["paused"] as? Bool) == true
        let page: Page = !bound ? .unbound : (paused ? .paused : .bound)
        let stateText = page == .unbound ? "未绑定" : (page == .paused ? "已暂停" : "已绑定")
        let payoutText = (data["payoutEnabled"] as? Bool) == true ? "" : "平台开通后开始"
        let pauseText: String
        if paused {
            pauseText = (data["pauseReason"] as? String) == "PERSONAL_BINDING_REQUIRED" ? "绑定尚未确认" : "绑定尚未确认"
        } else {
            pauseText = ""
        }
        return OwnerDecisionReceiverStatus(page: page, stateText: stateText, payoutText: payoutText,
                                            pauseText: pauseText, canUnbind: bound && (data["canUnbind"] as? Bool) == true)
    }
}

public struct OwnerDecisionMerchantAccount: Equatable {
    public enum Phase: Equatable { case unavailable, none, ready }
    public let phase: Phase
    public let stateText: String
    public let stateDesc: String
    public let signURL: String?
    public let maskedAccount: String
    public let checkedText: String

    private static let stateText: [String: String] = [
        "NONE": "未开通", "DRAFT": "待提交资料", "CHECKING": "资料校验中",
        "ACCOUNT_NEED_VERIFY": "待验证账户", "AUDITING": "审核中", "REJECTED": "已驳回",
        "NEED_SIGN": "待签约", "FINISH": "已开通", "FROZEN": "已冻结", "CANCELED": "已作废"
    ]

    public static func shape(_ data: [String: Any]) -> OwnerDecisionMerchantAccount? {
        if let available = data["available"] as? Bool, available == false {
            return OwnerDecisionMerchantAccount(phase: .unavailable, stateText: "—", stateDesc: "", signURL: nil, maskedAccount: "—", checkedText: "—")
        }
        guard (data["available"] as? Bool) == true, let state = data["state"] as? String, let label = stateText[state] else { return nil }
        if state == "NONE" {
            return OwnerDecisionMerchantAccount(phase: .none, stateText: label, stateDesc: "", signURL: nil, maskedAccount: "—", checkedText: "—")
        }
        let sign: String?
        if let raw = data["signUrl"] as? String, raw.hasPrefix("https://"), state == "NEED_SIGN" || state == "ACCOUNT_NEED_VERIFY" {
            sign = raw
        } else { sign = nil }
        let masked = (state == "FINISH" || state == "FROZEN") ? ((data["subMchidMasked"] as? String) ?? "—") : "—"
        let desc = state == "FINISH" ? "" : ((data["stateDesc"] as? String) ?? "")
        return OwnerDecisionMerchantAccount(phase: .ready, stateText: label, stateDesc: desc, signURL: sign,
                                            maskedAccount: masked.isEmpty ? "—" : masked, checkedText: "—")
    }

    public static func allowsFinance(_ permissions: [String]) -> Bool {
        let codes: Set<String> = [OwnerDecisionReceiverCopy.financePermission, OwnerDecisionReceiverCopy.financePermissionAlias]
        return permissions.contains { codes.contains($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }
}

public enum OwnerDecisionWriteResult: Equatable {
    case notSent
    case acknowledged
    case failed
    case unknown
}

/// Status and the merchant account read. Unbind and account writes stay behind the payout switch.
/// Bind is not a method that can reach the network.
public struct OwnerDecisionPayoutClient {
    public let configuration: APIConfiguration
    public let transport: any HTTPTransport
    public let token: String
    private let payoutOpen: Bool
    private let merchantWritesOpen: Bool

    public init(configuration: APIConfiguration, transport: any HTTPTransport, token: String,
                payoutOpen: Bool, merchantWritesOpen: Bool) {
        self.configuration = configuration
        self.transport = transport
        self.token = token
        let production = configuration.baseURL.host?.lowercased() == "www.chengyinhub.com"
        self.payoutOpen = payoutOpen && ReleaseMoneyWriteSwitch.payoutEnabled
        self.merchantWritesOpen = merchantWritesOpen && !production
    }

    public func status(clubID: Int) async -> OwnerDecisionReceiverStatus? {
        guard clubID > 0, AuthRequestBuilder.isValidToken(token) else { return nil }
        var parts = URLComponents(url: configuration.baseURL.appendingPathComponent("api/club/personal-receiver/status"), resolvingAgainstBaseURL: false)
        parts?.queryItems = [URLQueryItem(name: "clubId", value: String(clubID))]
        guard let url = parts?.url else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        guard let data = try? await deliver(request), let object = Self.object(data) else { return nil }
        return OwnerDecisionReceiverStatus.shape(object)
    }

    /// Native bind does not exist. This returns `.notSent` and does not touch the transport.
    public func bind() -> OwnerDecisionWriteResult { .notSent }

    public func unbind(clubID: Int) async -> OwnerDecisionWriteResult {
        guard clubID > 0, payoutOpen, AuthRequestBuilder.isValidToken(token) else { return .notSent }
        return await post("api/club/personal-receiver/unbind", body: ["clubId": clubID])
    }

    public func account() async -> OwnerDecisionMerchantAccount? {
        guard AuthRequestBuilder.isValidToken(token) else { return nil }
        var request = URLRequest(url: configuration.baseURL.appendingPathComponent("api/merchant/payout-account"))
        request.httpMethod = "POST"
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        guard let data = try? await deliver(request), let object = Self.object(data) else { return nil }
        return OwnerDecisionMerchantAccount.shape(object)
    }

    /// `/api/merchant/payout-account/save` does not exist on the backend (404); only `POST /api/merchant/payout-account` exists.
    /// This returns `.notSent` and does not touch the transport.
    public func saveAccount() async -> OwnerDecisionWriteResult { .notSent }

    private func post(_ path: String, body: [String: Any]) async -> OwnerDecisionWriteResult {
        var request = URLRequest(url: configuration.baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let data = try await deliver(request)
            guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return .unknown }
            let code = root["code"]
            if (code as? Int) == 200 || (code as? String) == "200" { return .acknowledged }
            if code == nil { return .unknown }
            return .failed
        } catch is CancellationError {
            return .unknown
        } catch {
            return error is APIError ? .notSent : .unknown
        }
    }

    private func deliver(_ request: URLRequest) async throws -> Data {
        if let url = request.url, ChinaReviewedRouteCapability.targetsChinaProduction(url) {
            try ChinaReviewedRouteCapability.refuseUnwiredChinaProduction(request)
        }
        let (data, status) = try await transport.send(request)
        guard (200...299).contains(status) else { throw APIError.httpStatus(status) }
        return data
    }

    private static func object(_ data: Data) -> [String: Any]? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let code = root["code"]
        guard (code as? Int) == 200 || (code as? String) == "200" else { return nil }
        return root["data"] as? [String: Any]
    }
}

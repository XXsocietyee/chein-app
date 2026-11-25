import Foundation

/// ADAPT-5: additional fail-closed deny-list entries naming the backend routes that actually exist
/// (baseline `hengyin@4ac8c249`, `ApiLoginController`/`ApiRegistrationController`). The original
/// `RegionalHighRiskWriteRoute` cases (`/api/user/sms/send`, `/api/pay/create`) are kept unchanged and
/// pinned by existing tests; this type only ADDS routes to the blocked set. Nothing here allowlists anything.
public enum Adapt5HighRiskWriteSupplement: String, CaseIterable, Sendable {
    /// `POST /api/sms/send`, request param `phone`, anonymous, `AjaxResult{code,msg}`.
    case smsSend = "/api/sms/send"
    /// `POST /api/registration/pay`, request param `id`, member token, `AjaxResult{code,msg,data}`.
    case registrationPay = "/api/registration/pay"
    /// `POST /api/registration/pay/app`, request param `id`, member token, `AjaxResult{code,msg,data}`.
    case registrationPayApp = "/api/registration/pay/app"

    public static var canonicalPaths: [String] { allCases.map(\.rawValue) }

    /// Every path the deny-list names: the original canonical routes plus the ADAPT-5 additions.
    public static var allBlockedPaths: Set<String> {
        Set(RegionalHighRiskWriteRoute.canonicalPaths).union(canonicalPaths)
    }

    public static func match(_ rawPathOrURL: String) -> Self? {
        Self(rawValue: RegionalHighRiskWriteRoute.normalizePath(rawPathOrURL))
    }

    /// Fail-closed default: true for any original or supplemental high-risk write path.
    public static func isBlockedByDefault(_ rawPathOrURL: String) -> Bool {
        allBlockedPaths.contains(RegionalHighRiskWriteRoute.normalizePath(rawPathOrURL))
    }

    /// `POST /api/registration/pay` with `id`. Blocked. Does not build or send a request.
    public static func refuseRegistrationPay(id: String) throws -> Never {
        _ = id
        _ = isBlockedByDefault(registrationPay.rawValue)
        throw Adapt5PayRefusal.blocked
    }
}

public enum Adapt5PayRefusal: Error, Equatable, Sendable {
    case blocked
}

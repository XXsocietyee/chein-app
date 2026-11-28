import Foundation
import Combine

/// P0-5 / P1-1 (audit 11-28). Kept out of `AppSession.swift` (size ratchet).
extension AppSession {
    /// The verified Universal Link origin. `QuestifyAppLinkDomain` comes from the `QUESTIFY_APP_LINK_DOMAIN` build setting
    /// (default `www.chengyinhub.com`, docs/release/owner-values.md). iOS delivers a Universal Link only when the
    /// associated-domains entitlement is signed in (`QUESTIFY_ASSOCIATED_DOMAINS = YES`) and the AASA file is hosted,
    /// so a verified origin here never opens links on its own.
    nonisolated static func verifiedLinkOrigins(_ bundle: Bundle = .main) -> Set<String> {
        let domain = bundle.object(forInfoDictionaryKey: "QuestifyAppLinkDomain") as? String
        guard let origin = AppUniversalLinkRouter.origin(domain: domain) else { return [] }
        return [origin]
    }

    /// One intake for chein:// and https links: chein deep links replay through `pendingDeepLink` (tab + destination),
    /// content and mini-program pages through `receiveNativeIntent` (HomeLanding push).
    func receiveAppLink(_ destination: AppLinkDestination) {
        switch destination {
        case .deepLink(let link): pendingDeepLink = link
        case .entry(let intent): receiveNativeIntent(intent)
        }
    }

    /// `POST api/login/wechat/app` (multipart `code`, ApiLoginController.loginWechatApp). Nil outside the reviewed
    /// China deployment, so the exchange can never run against an unreviewed host.
    var weChatExchangeService: WeChatAppAuthService? {
        guard composition.reviewed?.weChatSignInApproved == true,
              let configuration = regionalConfiguration?.apiConfiguration else { return nil }
        return WeChatAppAuthService(configuration: configuration, transport: compositionTransport)
    }

    func weChatReleaseGate(sdkLinked: Bool, configured: Bool) -> WeChatAppAuthGate {
        let reviewed = composition.reviewed
        return WeChatAppLaunch.gate(sdkLinked: sdkLinked, configured: configured,
                                    legalCatalog: reviewed?.legalCatalogApproved == true,
                                    appleAlternative: reviewed?.appleSignInApproved == true,
                                    exchangeWired: reviewed?.weChatSignInApproved == true && regionalConfiguration?.apiConfiguration != nil)
    }
}

/// One-shot presentation after WeChat sign-in. Not a credential and not read back as authorization.
@MainActor
private enum LinkedMiniProgramAccountNote {
    static var sessions: [ObjectIdentifier: Bool] = [:]
}

extension AppSession {
    var showsLinkedMiniProgramAccountNote: Bool {
        LinkedMiniProgramAccountNote.sessions[ObjectIdentifier(self)] == true
    }
    func noteLinkedMiniProgramAccount() {
        LinkedMiniProgramAccountNote.sessions[ObjectIdentifier(self)] = true
    }
    func clearLinkedMiniProgramAccountNote() {
        guard LinkedMiniProgramAccountNote.sessions.removeValue(forKey: ObjectIdentifier(self)) != nil else { return }
        objectWillChange.send()
    }
}

extension ReviewedAppDeployment {
    /// WeChat sign-in rides the same reviewed China gate as Sign in with Apple + SMS (App Store 4.8: Apple is offered
    /// wherever WeChat is). The US market has no WeChat row (P33: Apple → phone +1).
    var weChatSignInApproved: Bool { appleSignInApproved }
}

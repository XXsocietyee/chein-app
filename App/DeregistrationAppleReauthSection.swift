import SwiftUI
import AuthenticationServices

/// P0-6 (App Store 5.1.1(v)): verification step of 账号注销 for an account created with Sign in with Apple.
/// The backend reports `verificationMethod == "APPLE"` when the account has no bound phone and no WeChat
/// openid, so there is no number to text a code to. The person re-authenticates with the system Apple
/// button; the fresh `identityToken` (+ `authorizationCode`) goes to the review step and is posted only
/// after the explicit destructive confirmation. Nothing is stored on disk.
struct DeregistrationAppleReauthSection: View {
    let busy: Bool
    let enabled: Bool
    let onCredential: (String, String?) -> Void
    let onFailure: (Bool) -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Section {
            Text("compliance.apple.lead")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("compliance.apple.lead")
            SignInWithAppleButton(.continue, onRequest: configure, onCompletion: complete)
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(minHeight: 50)
                .clipShape(Capsule())
                .disabled(busy || !enabled)
                .opacity(busy || !enabled ? 0.5 : 1)
                .accessibilityIdentifier("compliance.apple.reauth")
        } header: {
            Text("compliance.apple.title")
        }
    }

    /// Re-authentication only proves the same Apple ID; no name or email is requested again.
    private func configure(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = []
    }

    private func complete(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let token = String(data: tokenData, encoding: .utf8), !token.isEmpty else {
                onFailure(false)
                return
            }
            let code = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
            onCredential(token, code)
        case .failure(let error):
            let cancelled = (error as? ASAuthorizationError)?.code == .canceled
            onFailure(cancelled)
        }
    }
}

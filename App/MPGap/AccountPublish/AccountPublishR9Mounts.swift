import SwiftUI

// r9 account-publish (Claude App): thin App-side hooks for the r9 fix queue
// (origin/audit/parity-r9-account-publish). Contracts stay in Core.

// MARK: - A6-01b bound phone (MP pages/addressinfo/addressinfo.js:59-72 `loadBoundPhone`)

extension AppSession {
    /// MP addressinfo.js:59-72: POST `/api/user/info` and read `data.phone || data.mobilePhone`.
    /// Returns nil when signed out, on any failure, or when the account has no bound phone.
    func participantBoundPhone() async -> String? {
        guard let memberID = account?.id, memberID > 0,
              let token = self.token, AuthRequestBuilder.isValidToken(token),
              let api = regionalConfiguration?.apiConfiguration else { return nil }
        do {
            let request = try AccountPublishMPContract.userInfoRequest(baseURL: api.baseURL, memberID: String(memberID), token: token)
            let (data, status) = try await runtimeHTTPTransport.send(request)
            guard (200..<300).contains(status),
                  let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
            let body = (root["data"] as? [String: Any]) ?? root
            let raw = (body["phone"] as? String) ?? (body["mobilePhone"] as? String) ?? ""
            let phone = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            return phone.isEmpty ? nil : phone
        } catch {
            return nil
        }
    }
}

// MARK: - A4-04b share 据点 / club hub (MP mylike.wxml:49-53 open-type="share"; talent/list/index.js:585-600)

/// One system share entry for a public page. Uses the universal link when Core types one; otherwise it
/// shares the MP page path text from the matching `PublicContentShareLink.*CopyText` helper.
struct R9PublicShareButton: View {
    let url: URL?
    let copyText: String?
    var identifier: String = "r9.share"

    var body: some View {
        if let url {
            ShareLink(item: url) { Label("fixr9.ap.share", systemImage: "square.and.arrow.up") }
                .accessibilityIdentifier(identifier)
        } else if let copyText {
            ShareLink(item: copyText) { Label("fixr9.ap.share", systemImage: "square.and.arrow.up") }
                .accessibilityIdentifier(identifier)
        }
    }
}

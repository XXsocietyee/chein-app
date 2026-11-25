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

// MARK: - A2-02b / A2-10 merchant subject (MP components cy/profile index.js:900-970 public-home probe,
// index.wxml:578-582 发起合作 bar, :2277-2283 onCoopInvite → coop/invite type=0 toId=memberId)

/// Probes `api/merchant/public-home` by the viewed member id (Core `SocialPublicProfile.merchantHomeTarget` shape).
/// A public merchant record swaps the page to `PublicMerchantHomeView`; anything else keeps the member profile.
/// A signed-in visitor (not the merchant themself) gets the bottom 发起合作 bar, which opens the coop invite with
/// type 0 and the merchant's member id; that page owns the publisher-topic check (MP `canInviteCoop`).
@MainActor struct R9MerchantAwareProfileHost<Profile: View>: View {
    @ObservedObject var session: AppSession
    let memberID: Int
    @ViewBuilder let profile: () -> Profile
    @State private var isMerchant = false
    @State private var opensCoopInvite = false

    private var showsCoopBar: Bool {
        guard isMerchant, let viewer = session.account?.id else { return false }
        return viewer != memberID
    }

    var body: some View {
        Group {
            if isMerchant, let owner = PublicMerchantOwnerID(memberID) {
                PublicMerchantHomeView(target: .ownerMemberID(owner), context: session.publicMerchantHomeContext)
            } else {
                profile()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showsCoopBar {
                SocialPublicProfileGapCoopBar { opensCoopInvite = true }
                    .background(CYColor.bgPage)
                    .accessibilityIdentifier("profile.merchant.coopInvite")
            }
        }
        .navigationDestination(isPresented: $opensCoopInvite) {
            MPReviewedPageScreen(page: "pages/coop/invite/index", query: ["type": "0", "toId": String(memberID)])
                .environmentObject(session)
        }
        .task(id: memberID) { await probe() }
    }

    private func probe() async {
        isMerchant = false
        guard let owner = PublicMerchantOwnerID(memberID) else { return }
        let reader = session.publicMerchantHomeContext.reader
        guard reader.isConfigured else { return }
        do {
            _ = try await reader.home(.ownerMemberID(owner))
            guard !Task.isCancelled else { return }
            isMerchant = true
        } catch {
            isMerchant = false
        }
    }
}

// MARK: - C-T6b template editor `from` / `scope` (MP pages/publish/temp/index.js:1392-1416,
// template-intro/index.js:291 `temp/index?scope=MERCHANT`)

extension AppSession {
    /// MP temp/index.js:1400: `operationScope = options.scope === 'MERCHANT' ? 'MERCHANT' : ''`. Only MERCHANT is
    /// written, onto both the shelf requests (`coordinator.operationScope`) and the submit payload (`draft.operationScope`,
    /// which `TemplateAuthoringContract` turns into `scope=MERCHANT`). `from` only changes labels (see `TemplateAuthoringView`).
    func templateAuthoringEditor(adopting source: DiscoveryPlayTemplate? = nil, from: String?, scope: String?) -> TemplateAuthoringCoordinator {
        let coordinator = templateAuthoringEditor(adopting: source)
        guard scope == "MERCHANT" else { return coordinator }
        coordinator.operationScope = "MERCHANT"
        if coordinator.draft.operationScope != "MERCHANT" {
            var draft = coordinator.draft
            draft.operationScope = "MERCHANT"
            coordinator.change(draft)
        }
        return coordinator
    }
}

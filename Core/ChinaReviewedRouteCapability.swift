import Foundation
import CoreFoundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// CB13. Each iOS `api/` call-site literal is live on production backend `014fc0d8`,
/// present only on the later public snapshot `147754ba`, or missing from both.
/// The China reviewed deployment calls a path only when it is live and not password
/// login, bank withdrawal, or virtual goods. The default build has an empty base URL
/// and never reaches this gate. The United States host is not invented.
public enum ChinaReviewedRouteMark: String, Equatable, Sendable {
    case liveInProduction = "live-in-production"
    case newBackendOnly = "new-backend-only"
    case missing
}

/// P2 play-runtime gates. Reviewed, and default off. They live outside `marks` and
/// `wiredPatterns` so this package does not change `callSiteCount` (995) or
/// `wiredPatternCount` (679). Other packages add their own rows later.
public enum PlayRuntimePortRouteGate {
    /// Missing `storyLocked` counts as locked only after this is turned on.
    public static let storyLockMissingCountsAsLocked = false
    #if DEBUG
    /// Unit tests flip this to prove both behaviors. Release builds ignore it.
    public static var testStoryLockMissingCountsAsLocked: Bool?
    #endif
    public static var storyLockMissingIsLocked: Bool {
        #if DEBUG
        if let testStoryLockMissingCountsAsLocked { return testStoryLockMissingCountsAsLocked }
        #endif
        return storyLockMissingCountsAsLocked
    }
    /// `GET /api/topic/free-explore/visit-config`. Reviewed (`live-in-production`). C-F6 MP-first (owner 2026-11-25):
    /// on, as the mini-program reads it (pages/publish/fabu/theme-fe-visit.js:40).
    public static let freeExploreVisitConfigRead = true
    /// `POST /api/topic/free-explore/visit-config`. C-F6 MP-first: on, as the mini-program saves it (theme-fe-visit.js:87).
    public static let freeExploreVisitConfigWrite = true
    public static let visitConfigPath = "/api/topic/free-explore/visit-config"
    public static let visitConfigMark = ChinaReviewedRouteMark.liveInProduction
}

public enum ChinaReviewedRouteCapability {
    public static let productionBackendCommit = "014fc0d83afe9f53cf4a8b1f9544bcf634e9ce6c"
    public static let publicSnapshotCommit = "147754ba8740abf208bda75cf86ed5901cac4c02"

    public static var callSiteCount: Int { marks.count }
    public static var liveInProductionCount: Int { marks.values.filter { $0 == .liveInProduction }.count }
    public static var newBackendOnlyCount: Int { marks.values.filter { $0 == .newBackendOnly }.count }
    public static var missingCount: Int { marks.values.filter { $0 == .missing }.count }
    /// Production patterns covered by live call sites, after password login, bank
    /// withdrawal, and virtual goods are removed. Prefix call sites expand here.
    public static var wiredPatternCount: Int { wiredPatterns.count }

    public static func mark(for path: String) -> ChinaReviewedRouteMark? {
        marks[literalKey(path)]
    }

    /// True only for a live production route the China reviewed deployment may call.
    /// A payment, payout, withdrawal, or virtual-goods write stays unreachable while its own
    /// Release switch is off, even if the path is later added to the wired catalog.
    public static func admitsChinaProductionCall(_ path: String) -> Bool {
        let key = normalized(path)
        // Prefix literals are not routes. Concrete children stay on their own keys.
        if key == "/api/workshop/purchased" || key == "/api/reward-pledge/versions"
            || key == "/api/friend/channel-invite" || key == "/api/friend/team-invite" { return false }
        if ReleaseMoneyWriteSwitch.blocks(key) { return false }
        // A forced-off money route opens only while its own Release switch is on (DEBUG/TEST off the production host).
        if forcedOff(key) != nil, !ReleaseMoneyWriteSwitch.opens(key) { return false }
        if wiredPatterns.contains(key) { return true }
        // F-14: TEST-backend-only topic publish routes, admitted only in a DEBUG/TEST E2E run (constant false in Release).
        if TestHostOnlyRouteAdmission.admits(key) { return true }
        if let kind = moneyAreaOwnerGrant[key], ReleaseMoneyWriteSwitch.isEnabled(kind) { return true }
        if playerJourneyOwnerGrant.contains(key) { return true }
        // Owner approval of the non-money player writes: the CITY board (gaps A). Member game
        // points only; no CITY route moves money.
        if CityGameProductionLease.paths.contains(key) { return true }
        if imRecipientPreviewGrant.contains(key) { return true }
        if channelsSocialOwnerGrant.contains(key) { return true }
        if beGapImOwnerGrant.contains(key) { return true }
        if creatorEditorAndOrderCenterOwnerGrant.contains(key) { return true }
        if key.hasPrefix("/api/topic/state-keys/"), isTopicStateKey(String(key.dropFirst("/api/topic/state-keys/".count))) { return true }
        if socialRoamOwnerGrant.contains(key) { return true }
        if wp09PresetGrant.contains(key) { return true }
        if playRuntimeOwnerGrant.contains(key) { return true }
        if videoBountyOwnerGrant.contains(key) { return true }
        if hostTipSurfaceGrant.contains(key) { return true }
        if playerParityBOwnerGrant.contains(key) { return true }
        if playerGapOwnerGrant.contains(key) { return true }
        if creatorStudioOwnerGrant.contains(key) { return true }
        if clubAndMerchantCoopOwnerGrant.contains(key) { return true }
        if playGapOwnerGrant.contains(key) { return true }
        if playCreatorTailOwnerGrant.contains(key) { return true }
        if admitsRewardPledge(key) { return true }
        if workshopModOwnerGrant.contains(where: { key == $0 || key.hasPrefix($0 + "/") }) { return true }
        if beGapMerchantOwnerGrant.contains(key) { return true }
        if merchantOpsWp03OwnerGrant.contains(key), admitsMerchantOpsWp03(key) { return true }
        if externalGameOwnerGrant.contains(key) || externalGameOwnerGrant.contains(externalGameGrantKey(key)) { return true }
        if wp04OwnerGrant.contains(key) { return true }
        if wp07CommerceOwnerGrant.contains(key) {
            // Quote and coupon usability are reads. Create and activate are payment writes:
            // ReleaseMoneyWriteSwitch.blocks already returned false above when money is off,
            // and a payment kind stays closed on www.chengyinhub.com even if this set lists it.
            return ReleaseMoneyWriteSwitch.kind(for: key) == nil
        }
        if wp06PartialPagesOwnerGrant.contains(key) { return true }
        if ownerDecisionGuardGrant.contains(key) { return true }
        if popupCloseOwnerGrant.contains(key) { return true }
        // Owner 2026-11-24: platform-pass order reads are on for players. Not a money write.
        if isPlatformPassOrderPath(key) { return true }
        if mpFirstCMAOwnerGrant.contains(key) { return true }
        return g6OwnerGrant.contains(key)
    }

    /// MP-first rule (owner 2026-11-25): non-money routes the mini-program itself sends. The server's checks decide.
    /// C-F6: the author's 到访方式 read/save (pages/publish/fabu/theme-fe-visit.js:40, :87).
    public static let mpFirstCMAOwnerGrant: Set<String> = [
        "/api/topic/free-explore/visit-config"
    ]

    /// Popup-closure owner grant: reviewed non-money routes surfaced by the popup parity closure pass
    /// (`beta/graduate`, `transfer-to-club`, owned clubs lookup, and official attendance read/commands).
    /// Money/payment/withdrawal/refund paths stay excluded and governed by `ReleaseMoneyWriteSwitch`.
    public static let popupCloseOwnerGrant: Set<String> = [
        "/api/topic/beta/graduate",
        "/api/topic/transfer-to-club",
        "/api/club/my",
        "/api/official/events/{}/attendance",
        "/api/official/events/{}/attendance/manage",
        "/api/official/command",
        "/api/official/command/query",
        "/api/official/command/cancel"
    ]

    /// HANDOVER 36, WP-07. Group/school quote and coupon usability are reads.
    /// Create and activate are listed and stay closed: they are payment kinds, so
    /// `ReleaseMoneyWriteSwitch` refuses them while money is off, including www.chengyinhub.com.
    public static let wp07CommerceOwnerGrant: Set<String> = [
        "/api/marketing/group-checkout/quote",
        "/api/marketing/group-checkout/create",
        "/api/marketing/product/activate",
        "/api/coupon/usability"
    ]

    /// WP-04 owner grant. Player content: coop invite receipts and the author's own square post.
    /// Marks stay as catalogued. Money and merchant writes are not in this set.
    public static let wp04OwnerGrant: Set<String> = [
        "/api/coop/invite/read",
        "/api/coop/invite/request",
        "/api/coop/invite/requests",
        "/api/coop/supply-stations",
        "/api/creativesquare/delete",
    ]

    /// Handover 35, WP-06. The twelve partial pages' non-money reads and the complaint report.
    /// Coupon publish and stop are listed so the player lease can see them; `ReleaseMoneyWriteSwitch`
    /// still refuses a money path first, and the player lease only forwards those two when
    /// `ReviewedAreaSwitch.merchantWrites` is open. That switch is false on www.chengyinhub.com.
    public static let wp06PartialPagesOwnerGrant: Set<String> = [
        "/api/user/address/list", "/api/user/address/info", "/api/user/address/action",
        "/api/user/address/delete", "/api/user/address/setDefault",
        "/api/publish/home", "/api/ai/theme/draft/quota",
        "/api/coop/complaint/topics", "/api/coop/complaint/mine", "/api/coop/complaint/report",
        "/api/coupon/mypublishlist", "/api/coupon/publish", "/api/coupon/stop",
        "/api/invoice/list", "/api/invoice/detail", "/api/invoice/orders/eligible", "/api/invoice/titles",
        "/api/invoice/apply", "/api/invoice/request",
        "/api/exploration-anniversary", "/api/monthly-recap",
        "/api/personal-exploration-export/prepare", "/api/personal-exploration-export/page",
        "/api/roam/passport/history", "/api/roam/stamp/create", "/api/roam/stamp/exchange",
        "/api/roam/share/snapshot", "/api/common/uploadOSS"
    ]

    /// WP-01 / WP-05, owner 2026-11-13: money ON for TEST/DEBUG only. Payout receiver, merchant payout account and the
    /// owner's settlement and receivable reads; registration payment and its readiness; bank withdrawal preflight and create.
    /// Each path, read or write, is admitted only while the Release switch of its area is on: Release constants are false,
    /// and the DEBUG/TEST derivation is false on the production host. Marks stay as they were.
    public static let moneyAreaOwnerGrant: [String: ReleaseMoneyWriteKind] = [
        // Owner 2026-11-14: receiver status and the merchant payout-account read are status reads, admitted
        // unconditionally through `ownerDecisionGuardGrant`; only the writes stay behind the payout switch.
        "/api/club/settlement/mine": .payout,
        "/api/club/personal-receiver/bind": .payout, "/api/club/personal-receiver/unbind": .payout,
        "/api/club-direct-merchant/club": .payout, "/api/club-direct-merchant/merchant": .payout,
        "/api/registration/payment-readiness": .payment, "/api/registration/pay": .payment, "/api/registration/pay/app": .payment,
        "/api/fund/preflight/bank-withdrawal": .withdrawal, "/api/fund/preflight/{}/confirm": .withdrawal,
        "/api/fund/preflight/{}/reject": .withdrawal, "/api/withdrawal/create": .withdrawal
    ]

    /// Contract §7 item 18. The six recipient-preview patterns (`IMPreviewRouteTemplates`).
    /// Marks stay `.missing`. A concrete id is admitted only through the existing `{}` normalizer;
    /// the conversation binding is the per-template lease, not this set.
    public static let imRecipientPreviewGrant: Set<String> = IMPreviewRouteTemplates.grantPatterns

    /// Owner approval 2026-11-13. Channels, channel messages, governance, notifications, admission, IM media attach,
    /// friends, the team shared resource pool and the in-team board, as served by hengyin `feature/im-channels`
    /// (`docs/channels/contract.md` §1–§8). These are non-money player/club social writes and their reads.
    /// Money is still refused first by `ReleaseMoneyWriteSwitch` and `forcedOff`; webhooks and the anchored audit log stay out.
    public static let channelsSocialOwnerGrant: Set<String> = [
        // §1 directory and management
        "/api/guilds/{}/{}/channels", "/api/guilds/{}/{}/channels/manage", "/api/channels/{}", "/api/channels/{}/archive",
        "/api/channels/{}/restore", "/api/channels/{}/permissions", "/api/channels/{}/permissions/{}/{}", "/api/channels/{}/effective/{}",
        "/api/channel-platform/requests/{}", "/api/channel-platform/governance/requests/{}", "/api/channels/{}/op-log",
        "/api/channels/{}/members", "/api/im/roles", "/api/im/roles/{}", "/api/im/members/{}/roles", "/api/im/roles/{}/members",
        // §2 messages
        "/api/im/messages", "/api/im/send", "/api/im/send-receipt", "/api/native/channels/read-through", "/api/im/message/edit",
        "/api/im/message/recall", "/api/im/message/request", "/api/im/message/mutations", "/api/im/message/context",
        "/api/im/message/{}/revisions", "/api/im/pins", "/api/im/pin", "/api/im/unpin", "/api/im/pins/sort", "/api/im/search",
        "/api/im/message/{}/attachment", "/api/im/message",
        // §3 progress board and privacy
        "/api/channel/{}/board", "/api/channel/{}/progress/overview", "/api/channel/{}/board/{}/top", "/api/channel/{}/board/{}/detail",
        "/api/channel/{}/board/{}/me/best", "/api/channel/{}/board/{}/me/recent", "/api/channel/{}/board/{}/version",
        "/api/progress/meter", "/api/privacy/progress", "/api/progress/requests/{}", "/api/progress/requests",
        "/api/channel/{}/progress/privacy",
        // §4 team pool, §5 in-team board (`/api/rank/list` is already in the journey grant)
        "/api/team/pool", "/api/team/pool/hint", "/api/team/pool/skip", "/api/team/pool/timer/start", "/api/team/pool/requests/{}",
        // §6.1–6.5 member state, moderation, appeals, reports
        "/api/channels/{}/member-state", "/api/channels/member-state-requests/{}", "/api/im/moderation/timeout",
        "/api/im/moderation/kick", "/api/im/moderation/ban", "/api/im/moderation/{}/revoke", "/api/im/moderation/actions",
        "/api/im/moderation/me", "/api/channel-platform/governance/moderation/requests/{}", "/api/im/appeals", "/api/im/appeals/{}",
        "/api/im/appeals/{}/evidence", "/api/im/appeals/{}/withdraw", "/api/im/report", "/api/channel-platform/governance/reports/requests/{}",
        // §6.7 chain and check-in (no rewards)
        "/api/im/chain/create", "/api/im/chain/join", "/api/im/chain/withdraw", "/api/im/chain/close", "/api/im/chain/info",
        "/api/im/interaction/request", "/api/im/channel/checkin", "/api/im/channel/checkin-status", "/api/im/channel/checkin-rank",
        "/api/im/channel/checkin-request",
        // §8.1 blacklist (fourth pass): reads plus unblock/settle; adding stays on /api/im/block
        "/api/native/blacklist/list", "/api/native/blacklist/current", "/api/native/blacklist/receipt",
        "/api/native/blacklist/unblock", "/api/native/blacklist/settle",
        // §6.8 notifications
        "/api/im/notify-pref", "/api/im/mute", "/api/im/read", "/api/im/notification-requests/{}", "/api/im/unread-summary",
        "/api/im/notify-log", "/api/im/read-state", "/api/im/read-receipt", "/api/im/mute-state", "/api/im/mute-receipt",
        // §6.10–6.11 admission, welcome, onboarding
        "/api/join-request/submit", "/api/join-request/cancel", "/api/join-request/approve", "/api/join-request/reject",
        "/api/space/leave", "/api/space/join-pause", "/api/invite/revoke", "/api/channel-platform/admission/requests/{}",
        "/api/welcome-screen/get", "/api/onboarding/get", "/api/onboarding/submit",
        // §6.14 IM media, polls, route share
        "/api/im/file/upload", "/api/im/file/receipt", "/api/im/file/scan", "/api/im/file/delete",
        // §7 item 18. Same patterns as `imRecipientPreviewGrant` / `IMPreviewRouteTemplates`. Not marked live.
        "/api/im/file/message/{}/authorization", "/api/im/file/message/{}/preview",
        "/api/im/video/upload", "/api/im/video/receipt", "/api/im/video/delete", "/api/im/video/policy",
        "/api/im/video/message/{}/authorization", "/api/im/video/message/{}/preview",
        "/api/im/voice/upload", "/api/im/voice/receipt", "/api/im/voice/delete", "/api/im/voice/message/{}/authorization",
        "/api/im/voice/message/{}", "/api/im/poll/create-receipt", "/api/im/route-share-source", "/api/im/device/attempts",
        // §8 friends (block list stays on the existing `/api/im/block` and `/api/im/unblock`)
        "/api/friend/list", "/api/friend/requests", "/api/friend/relationship", "/api/friend/request", "/api/friend/accept",
        "/api/friend/reject", "/api/friend/cancel", "/api/friend/receipt", "/api/friend/remove", "/api/friend/removal/receipt",
        "/api/friend/removal/settle", "/api/friend/metadata", "/api/friend/remark", "/api/friend/group/save",
        "/api/friend/group/delete", "/api/friend/group/list", "/api/friend/metadata/receipt", "/api/friend/metadata/settle",
        "/api/friend/directory", "/api/friend/directory/detail", "/api/friend/progress",
        "/api/friend/channel-invite/picker", "/api/friend/channel-invite/batch", "/api/friend/channel-invite/notice",
        "/api/friend/channel-invite/landing", "/api/friend/channel-invite/mine", "/api/friend/channel-invite/receipt",
        "/api/friend/channel-invite/command", "/api/friend/team-invite/picker", "/api/friend/team-invite/landing",
        "/api/friend/team-invite/mine", "/api/team/original-request", "/api/im/block", "/api/im/unblock"
    ]

    /// Owner correction 2026-11-13. The thirty capgraph templates, plus the webhook child routes the Core client sends.
    /// Non-money. Audit stays an unanchored projection; webhook test does not claim a delivery was sent.
    public static let beGapImOwnerGrant: Set<String> = [
        "/api/im/appeals/{}/evidence", "/api/im/appeals/{}/withdraw", "/api/im/audit-log", "/api/im/chain", "/api/im/channel",
        "/api/im/file/message", "/api/im/file/message/{}/authorization", "/api/im/file/message/{}/preview",
        "/api/im/members/{}/roles", "/api/im/message/{}/attachment", "/api/im/moderation", "/api/im/moderation/{}/revoke",
        "/api/im/notification-requests", "/api/im/poll/create-receipt", "/api/im/roles/{}/members",
        "/api/im/video/message", "/api/im/video/message/{}/authorization", "/api/im/video/message/{}/preview",
        "/api/im/voice/message", "/api/im/voice/message/{}", "/api/im/voice/message/{}/authorization",
        "/api/im/webhook", "/api/im/webhook/context", "/api/im/webhook/subscriptions", "/api/im/webhook/endpoints",
        "/api/im/webhook/subscriptions/{}", "/api/im/webhook/endpoints/{}",
        "/api/im/webhook/subscriptions/{}/rotate-secret", "/api/im/webhook/endpoints/{}/rotate-token",
        "/api/im/webhook/subscriptions/{}/deliveries", "/api/im/webhook/subscriptions/{}/deliveries/{}/retry",
        "/api/im/webhook/subscriptions/{}/test", "/api/im/webhook/endpoints/{}/logs",
        "/api/channel-platform/admission/requests", "/api/channel-platform/governance/moderation/requests",
        "/api/channel-platform/governance/reports/requests", "/api/channel-platform/governance/requests",
        "/api/channel-platform/requests", "/api/channels", "/api/channel/{}/board/{}"
    ]

    /// Owner approval 2026-11-13, G2 + G3. The order-center summary read and the creator topic
    /// editor calls. The invoice routes are already wired above. Pay, refund, and withdraw stay out.
    private static let creatorEditorAndOrderCenterOwnerGrant: Set<String> = [
        "/api/order-center/detail",
        "/api/topic/attribute-binding",
        "/api/topic/author-edit-detail",
        "/api/topic/author-saved-detail",
        "/api/topic/play-setup",
        "/api/topic/publish-draft",
        "/api/topic/share-code",
        "/api/topic/state-keys/named",
        "/api/topic/invite-chapters",
        "/api/topic/chapter/supply-terms",
        "/api/topic/host-qrcode"
    ]

    /// `PUT /api/topic/state-keys/{stateKey}` names a key such as `clue.door`, not a numeric id.
    public static func isTopicStateKey(_ segment: String) -> Bool {
        segment.range(of: "^(clue|relation|tag|counter)\\.[a-z][a-z0-9_]{0,47}$", options: .regularExpression) != nil
    }

    /// OWN-21.1 / OWN-21.2. Gameplay preset list, info and the personal draft write. Not a money path.
    public static let wp09PresetGrant: Set<String> = [
        "/api/preset/gameplay/list",
        "/api/preset/gameplay/info",
        "/api/preset/gameplay/draft"
    ]

    /// Capability gaps G4/G5 (capability-graph section 1), owner approval: non-money player reads and writes for
    /// community trust, community "mine" lists and undo actions, roam extras, template adoption/binding, map/search.
    /// The play lease (`ReviewedProductionGateLeases.playPaths`) names the same routes. No money path is here.
    static let socialRoamOwnerGrant: Set<String> = [
        "/api/community-trust/contributions/submit",
        "/api/community-trust/contributions/taxonomy",
        "/api/community-trust/reports/appeal",
        "/api/community-trust/safety/merchants/{}",
        "/api/community-trust/safety/ratings",
        "/api/community-trust/safety/taxonomy",
        "/api/v1/community/me/bookmarks",
        "/api/v1/community/me/posts",
        "/api/v1/community/posts/{}/actions/LIKE",
        "/api/v1/community/posts/{}/actions/BOOKMARK",
        "/api/v1/community/comments/{}/actions/LIKE",
        "/api/roam/session/records",
        "/api/roam/share/revoke",
        "/api/roam/shop/visitors",
        "/api/template/adopt-draft",
        "/api/template/adoption-detail",
        "/api/template/adoption-receipt",
        "/api/template/adoption-source",
        "/api/template/author-info",
        "/api/template/author-myinfo",
        "/api/template/topic-template/binding",
        "/api/template/topic-template/binding-status",
        "/api/template/topic-template/save-as",
        "/api/template/{}/market-submit",
        "/api/map/geocode",
        "/api/map/place-search",
        "/api/map/weather",
        "/api/search/unified"
    ]

    /// Parity package P-B (PlayerGapService.parityBPaths): organiser shared-run control, the lead's group member
    /// ticket scan and seat receipt, editor orient alternatives, the personal circle host, and the analytics batch.
    /// Payment, payout, withdrawal, and merchant-scope writes stay out.
    private static let playerParityBOwnerGrant: Set<String> = [
        "/api/game/session/shared/control",
        "/api/game/session/shared/export",
        "/api/game/session/shared/export/anchor",
        "/api/registration/scan_group_member_ticket",
        "/api/verify/seat/receipt",
        "/api/orient/task/alternative",
        "/api/topic/author-saved-detail",
        "/api/circle-theme/instance/configure",
        "/api/project/home",
        "/api/analytics/events/batch"
    ]

    /// WP-02 play/creator tail (PlayerGapService.creatorTailPaths, PlayExperienceService leader tools). The audit and guard
    /// appeal routes are non-money player/author routes on the play grant. The station release and chapter receipt run only
    /// under the `.leader` play capability, and the editions empty reason only where ReviewedAreaSwitch.moneyPayments opens,
    /// so neither reaches the production host from the player grant.
    private static let playCreatorTailOwnerGrant: Set<String> = [
        "/api/audit/timeline",
        "/api/audit/appeal",
        "/api/audit/appeal/receipt",
        "/api/audit/guard/reference",
        "/api/audit/guard/appeal",
        "/api/audit/guard/appeal/receipt",
        "/api/club/lead/release-station",
        "/api/club-compensation/editions/empty-reason"
    ]

    /// G7/G8 owner approval: non-money player reads and writes the mini-program calls (PlayerGapService).
    /// Payment readiness, payout receiver, club settlement, lead settle, and club host-only routes stay out.
    private static let playerGapOwnerGrant: Set<String> = [
        "/api/official/active-for-roam",
        "/api/official/signup-command",
        "/api/official/signup-command/query",
        "/api/official/signup-command/cancel",
        "/api/team/invite-qrcode",
        "/api/team/trail/state",
        "/api/team/trail/consent",
        "/api/team/trail/sync",
        "/api/registration/join_info",
        "/api/city/nodes/favorites",
        "/api/city/nodes/merchant/{}",
        "/api/activity/publish_precheck",
        "/api/media/asset/attribution",
        "/api/object-card/rename",
        "/api/user/player-code",
        "/api/club/event-ops/host/request",
        "/api/club/lead/arrive",
        "/api/club/lead/broadcast",
        "/api/club/post/like-state"
    ]

    /// Owner approval 2026-11-12. Player journey reads, the four public-catalog posts,
    /// seat invite/claim/cancel, and the boards those screens read.
    /// The affiliate summary GET is admitted. Referral-token issue, gift claim, and every money path stay out.
    private static let playerJourneyOwnerGrant: Set<String> = [
        // Owner approval 2026-11-13 (H7 U08-02): report-a-problem after a run. Non-money player write.
        "/api/play/feedback/submit",
        "/api/play/player-journey/report",
        "/api/play/player-journey/memory",
        "/api/play/player-journey/choices",
        "/api/play/player-journey/seats",
        "/api/rank/list",
        "/api/referral/landing/referral",
        "/api/referral/landing/gift",
        "/api/play/seat-invitations/invite",
        "/api/play/seat-invitations/claim",
        "/api/play/seat-invitations/{}",
        "/api/play/seat-invitations/{}/cancel",
        "/api/public-catalog/city/list",
        "/api/public-catalog/list",
        "/api/public-catalog/filters",
        "/api/public-catalog/info",
        "/api/marketing/affiliate/summary"
    ]

    /// Owner approval (G1 play runtime). Non-money player reads and writes the mini-program play page
    /// calls that were not wired: shared team help, the completed-run history read, and the circle
    /// record/answer writes. Check, setup, contact, gameplay and shared preview were already wired.
    /// Circle instance configure is a host write and stays out. Every money path stays out.
    private static let playRuntimeOwnerGrant: Set<String> = [
        "/api/play/help/shared",
        "/api/play/history",
        "/api/circle-theme/session/answer",
        "/api/circle-theme/session/record"
    ]

    /// Handover 14, stub-ledger row 24. Author video-bounty reads and the three non-money writes.
    /// Accrual amounts stay display-only. Payout, withdraw, redeem, and wallet stay out.
    /// Attribution reads are `hostTipSurfaceGrant` (WP-08). They are not payout.
    private static let videoBountyOwnerGrant: Set<String> = [
        "/api/video-bounty/submission/mine",
        "/api/video-bounty/accrual/mine",
        "/api/video-bounty/campaign/list",
        "/api/video-bounty/submission",
        "/api/video-bounty/submission/{}/appeal",
        "/api/video-bounty/submission/{}/cancel"
    ]

    /// HANDOVER 37, WP-08. Host tip config and unpaid intents, video-bounty attribution reads,
    /// the OTA channel-code redeem call, and author landing reads and writes.
    /// Payment and payout stay on `ReviewedAreaSwitch` / `ReleaseMoneyWriteSwitch` and are not in this set.
    /// `/api/host-tip/prepare` records an intent. A 501 `CHANNEL_NOT_ENABLED` is not a payment.
    public static let hostTipSurfaceGrant: Set<String> = [
        "/api/host-tip/config",
        "/api/host-tip/config/mine",
        "/api/host-tip/prepare",
        "/api/host-tip/intent/mine",
        "/api/host-tip/intent/{}/cancel",
        "/api/video-bounty/submission/{}/attribution",
        "/api/video-bounty/campaign/{}/attribution",
        "/api/channel/redeem",
        "/api/content-landing/info",
        "/api/content-landing/save",
        "/api/content-landing/translation/save"
    ]

    /// Owner 2026-11-24: GET `/api/platform-pass/orders` and the order detail. A read, not a money write.
    /// Purchase POST to the same path stays refused in `refuseUnwiredChinaProduction`.
    public static let platformPassOrderReadGrant: Set<String> = [
        "/api/platform-pass/orders",
        "/api/platform-pass/orders/{}"
    ]

    /// Capability gap G6 (owner approval). Roam/topic NPC reads, the two non-money V2 AI draft writes and their
    /// history read, and three marketing reads. Attribution claim, quote, order, pay,
    /// gift claim, and the roam NPC chat track stay out. Platform-pass order reads use `platformPassOrderReadGrant`.
    private static let g6OwnerGrant: Set<String> = [
        "/api/ai/npc/profile",
        "/api/ai/npc/event",
        "/api/ai/theme/draft/prepare",
        "/api/ai/theme/draft/execute",
        "/api/ai/theme/draft/recovery",
        "/api/marketing/promotions/catalog",
        "/api/marketing/revenue/author/mine",
        "/api/marketing/product/{}"
    ]

    /// Owner approval (U06 / U08-03 / U08-04, backend-app-r2): the creator's own feedback and maintenance tickets
    /// and the creator-scoped post-game outcome report. Author-only, no income, settlement or payout.
    /// Production does not serve these yet; the entries stay hidden until it does.
    private static let creatorStudioOwnerGrant: Set<String> = [
        "/api/creator/feedback",
        "/api/creator/maintenance/tickets",
        "/api/creator/maintenance/tickets/{}",
        "/api/creator/maintenance/tickets/{}/close",
        "/api/creator/maintenance/requests/{}",
        "/api/creator/analytics/post-game-outcome"
    ]

    /// Handover 20, owner correction 2026-11-13. The club and merchant-club paths the app names.
    /// Settlement export stays out: the screen calls it only when payout is on, and payout is off here.
    private static let clubAndMerchantCoopOwnerGrant: Set<String> = [
        "/api/club-compensation/quality/evidence",
        "/api/club/activity/cancel",
        "/api/club/activity/detail",
        "/api/club/activity/join",
        "/api/club/channels",
        "/api/club/events",
        "/api/club/events/Checkin",
        "/api/club/events/proxy-enroll",
        "/api/club/events/save",
        "/api/club/group-code",
        "/api/club/group-code/save",
        "/api/club/join-requests/apply",
        "/api/club/lead",
        "/api/club/notices",
        "/api/club/notices/send",
        "/api/club/post",
        "/api/club/post/operation",
        "/api/club/post/operation/comment",
        "/api/club/roles",
        "/api/club/workbench",
        "/api/coop"
    ]

    /// Handover 23. Non-money reads and native routes. Merchant intent, marketing order/pay/quote,
    /// and password login stay out. SMS send is `/api/sms/send`, not a password grant.
    static let playGapOwnerGrant: Set<String> = [
        "/api/city-game/action-budget/state", "/api/city-game/action-budget/command", "/api/city-game/action-budget/request/{}",
        "/api/city-game/acquisition/state", "/api/city-game/acquisition/titles", "/api/city-game/acquisition/quote/{}",
        "/api/city-game/acquisition/command", "/api/city-game/acquisition/request/{}",
        "/api/city-game/neutral-tasks/state", "/api/city-game/neutral-tasks/command", "/api/city-game/neutral-tasks/request/{}",
        "/api/city-game/onsite-tasks/state", "/api/city-game/onsite-tasks/command", "/api/city-game/onsite-tasks/request/{}",
        "/api/city-game/onsite-tasks/result/{}",
        "/api/city-game/arrival-evidence/state", "/api/city-game/arrival-evidence/merchant", "/api/city-game/arrival-evidence/command",
        "/api/city-game/arrival-evidence/request/{}", "/api/city-game/arrival-evidence/evidence/{}",
        "/api/city-game/merchant/operations/availability", "/api/city-game/merchant/operations/request/{}",
        "/api/game/session/view", "/api/game/session/command", "/api/game/session/receipt",
        "/api/play/check/roll", "/api/play/check/reroll", "/api/play/check/settle",
        "/api/play/theme/history", "/api/play/theme/card",
        "/api/play/city-orientation/answer", "/api/play/city-orientation/receipt",
        "/api/free-explore/bundle/catalog", "/api/free-explore/bundle/shelf",
        "/api/location-share/personal/context", "/api/location-share/personal/grants", "/api/location-share/personal/owned",
        "/api/location-share/personal/received", "/api/location-share/personal/received/events",
        "/api/location-share/personal/requests/{}", "/api/location-share/personal/requests/{}/revoke",
        "/api/location-share/personal/grants/{}/observations",
        "/api/roam/passport/history", "/api/roam/passport/record", "/api/roam/passport/summary",
        "/api/user/address/list", "/api/user/address/info", "/api/user/address/action", "/api/user/address/delete", "/api/user/address/setDefault",
        "/api/user/deregister/status", "/api/user/deregister/result", "/api/user/deregister/precheck", "/api/user/deregister/apply",
        "/api/sms/send",
        "/api/v1/community/capabilities", "/api/v1/community/feeds/{}", "/api/v1/community/posts/{}",
        "/api/v1/community/posts/{}/comments", "/api/v1/community/posts/{}/comments/{}",
        "/api/v1/community/posts/{}/comments/{}/approve", "/api/v1/community/posts/{}/actions",
        "/api/v1/community/posts/{}/actions/{}", "/api/v1/community/comments/{}/actions",
        "/api/v1/community/comments/{}/actions/LIKE", "/api/v1/community/me/enforcements",
        "/api/v1/community/notifications", "/api/v1/community/notifications/{}/read",
        "/api/v1/community/notification-preferences", "/api/v1/community/appeals",
        "/api/v1/community/guidelines/active", "/api/v1/community/drafts", "/api/v1/community/posts/{}/revisions",
        "/api/v1/community/reference-options/{}", "/api/v1/community/reports", "/api/v1/community/media/register",
        "/api/topic/cover/selection/current", "/api/topic/cover/upload", "/api/topic/cover/selection",
        "/api/topic/cover/selection/status", "/api/topic/cover/{}/content",
        "/api/support/tickets/list", "/api/support/tickets/detail",
        "/api/friend/directory", "/api/friend/directory/detail", "/api/friend/remark", "/api/friend/group/save",
        "/api/friend/group/delete", "/api/friend/metadata", "/api/friend/metadata/receipt", "/api/friend/group/list",
        "/api/friend/metadata/settle", "/api/friend/progress", "/api/friend/relationship", "/api/friend/removal/receipt",
        "/api/friend/remove", "/api/friend/removal/settle", "/api/friend/list", "/api/friend/requests", "/api/friend/receipt",
        "/api/friend/request", "/api/friend/accept", "/api/friend/reject", "/api/friend/cancel",
        "/api/registration/original-event",
        "/api/official/v2/events/{}", "/api/official/v2/events/{}/publish-check",
        "/api/npc/chat/delete",
        "/api/marketing/product/list", "/api/marketing/product/{}", "/api/marketing/product/orders",
        "/api/marketing/product/gifts/bought", "/api/marketing/product/gifts/received",
        "/api/content-draft/save", "/api/content-draft/restore", "/api/content-draft/list", "/api/content-draft/delete",
        "/api/common/uploadOSS/receipt",
        "/api/compliance/usage-records",
        "/api/native/device/enroll", "/api/native/device/enrollment-challenge", "/api/native/device/revoke", "/api/native/device/status",
        "/api/native/home", "/api/native/home/return/policy", "/api/native/home/return/runs", "/api/native/home/return/account",
        "/api/native/home/return/verify", "/api/native/home/return/restore", "/api/native/home/return/receipt"
    ]

    /// Handover 21, owner correction 2026-11-13. Points, badges and non-cash rewards stay callable.
    /// Cash value is refused by the server (`CASH_CLOSED`) and, when the area switch is off, by the screen.
    /// `/api/coupon` is the exact root. `command-receipt` and every other coupon child stay out.
    /// Opaque ids shorter than 32 characters and 64-hex award ids do not collapse, so the two trees match by prefix.
    public static func admitsRewardPledge(_ key: String) -> Bool {
        if key == "/api/coupon" { return true }
        if key == "/api/reward-pledge/versions" { return false }
        if key == "/api/rewards/noncash/subjects" || key == "/api/rewards/noncash/versions" { return false }
        if key == "/api/reward-pledge" || key.hasPrefix("/api/reward-pledge/") { return true }
        if key == "/api/rewards/noncash" || key.hasPrefix("/api/rewards/noncash/") { return true }
        return false
    }

    /// HANDOVER 22. Non-money workshop and mod reads. Purchased, paid install, and settlement/income
    /// stay off this set: the app calls those only when ReviewedAreaSwitch is on, which is never the production host.
    public static let workshopModOwnerGrant: Set<String> = [
        "/api/mod-installation",
        "/api/mod-owned-report",
        "/api/mod-upgrade",
        "/api/workshop/creator/pending-packages",
        "/api/workshop/creator/public-theme-use",
        "/api/workshop/owned",
        "/api/workshop/purchased/professional-targets",
        "/api/workshop/purchased/professional-operations"
    ]

    /// WP-10. Status and the merchant payout-account read are granted.
    /// Unbind is listed here and still fails first: `ReleaseMoneyWriteSwitch`
    /// blocks it while payout is off. Bind and `payout-account/save` are not in this set.
    public static let ownerDecisionGuardGrant: Set<String> = [
        "/api/club/personal-receiver/status",
        "/api/club/personal-receiver/unbind",
        "/api/merchant/payout-account"
    ]

    /// Owner correction 2026-11-13. Merchant-gap reads and the writes that stay behind
    /// moneyPayments, payout, merchantWrites, and passwordLogin. Money paths are listed
    /// here and still fail above: ReleaseMoneyWriteSwitch and forcedOff run first.
    /// /api/pay/create is not a digital-goods checkout. Marks stay missing.
    private static let beGapMerchantOwnerGrant: Set<String> = [
        "/api/merchant",
        "/api/merchant/authoring/draft-selection/list",
        "/api/merchant/authoring/draft-selection/resolve",
        "/api/merchant/authoring/drafts",
        "/api/merchant/authoring/drafts/{}",
        "/api/merchant/authoring/environment",
        "/api/merchant/authoring/jobs",
        "/api/merchant/authoring/jobs/cancel",
        "/api/merchant/authoring/main-line",
        "/api/merchant/authoring/player",
        "/api/merchant/authoring/player/{}/game",
        "/api/merchant/authoring/player/{}/requests/{}",
        "/api/merchant/authoring/public",
        "/api/merchant/authoring/releases",
        "/api/merchant/authoring/releases/{}/withdraw",
        "/api/merchant/city-value/event/{}/benefit",
        "/api/merchant/city-value/events",
        "/api/merchant/city-value/report",
        "/api/merchant/city-value/result/{}",
        "/api/merchant/crm/marketing-consents/result",
        "/api/merchant/insight",
        "/api/merchant/npc/avatar/generate",
        "/api/merchant/npc/avatar/status",
        "/api/merchant/npc/knowledge-review",
        "/api/merchant/npc/knowledge-review/request",
        "/api/merchant/npc/voice/revoke",
        "/api/merchant/npc/voice/script",
        // backend-final-gaps §1: the client calls these three children; the bare prefix is not a route.
        "/api/merchant/offer-withdrawal/request/current",
        "/api/merchant/offer-withdrawal/request/result",
        "/api/merchant/offer-withdrawal/request/withdraw",
        "/api/merchant/poi/detail",
        "/api/merchant/shop/apply",
        "/api/invoice",
        "/api/pay/create",
        "/api/asset/withdraw",
        "/api/us/auth/apple/challenges",
        "/api/us/auth/apple/exchange",
        "/api/us/auth/session"
    ]

    /// HANDOVER 33 WP-03. Appended after `beGapMerchantOwnerGrant`.
    /// Reads are admitted. Commerce order and order status stay on the payment switch and are not admitted.
    /// Claim submit, share code, and chapter invite revoke are merchant writes and stay closed on this host.
    static let merchantOpsWp03OwnerGrant: Set<String> = [
        "/api/merchant/claims/status",
        "/api/merchant/claims/submit",
        "/api/merchant/commerce/order",
        "/api/merchant/commerce/order/status",
        "/api/merchant/coupon-summary",
        "/api/merchant/npc/review",
        "/api/merchant/operators/invite/preview",
        "/api/merchant/share-code",
        "/api/merchant/chapter-application/invite/revoke"
    ]

    static func admitsMerchantOpsWp03(_ key: String) -> Bool {
        guard merchantOpsWp03OwnerGrant.contains(key) else { return false }
        if key == "/api/merchant/commerce/order" || key == "/api/merchant/commerce/order/status" { return false }
        if key == "/api/merchant/claims/submit" || key == "/api/merchant/share-code"
            || key == "/api/merchant/chapter-application/invite/revoke" { return false }
        return true
    }

    /// Handover 18, owner 2026-11-13. External HTML/JS games. Monetization is NONE.
    /// Catalog game ids are not numeric, so `externalGameGrantKey` folds that segment to `{}`.
    public static let externalGameOwnerGrant: Set<String> = [
        "/api/external-game/submissions",
        "/api/external-game/submissions/mine",
        "/api/external-game/submissions/{}",
        "/api/external-game/submissions/{}/cancel",
        "/api/external-game/submissions/{}/resubmit",
        "/api/external-game/catalog",
        "/api/external-game/catalog/{}",
        "/api/external-game/catalog/{}/package",
        "/api/external-game/catalog/{}/monetization",
        "/api/external-game/creator/summary",
        "/api/external-game/entitlements/mine",
        "/api/external-game/nodes/{}/binding",
        "/api/external-game/sessions/start",
        "/api/external-game/sessions/{}/result",
        "/api/external-game/signing-key",
        "/api/external-game/reports"
    ]

    /// Replaces the non-numeric identifier segment for catalog game ids, session ids, and order numbers.
    public static func externalGameGrantKey(_ normalizedKey: String) -> String {
        let parts = normalizedKey.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 5, parts[1] == "api", parts[2] == "external-game" else { return normalizedKey }
        if parts[3] == "catalog" || parts[3] == "sessions" || parts[3] == "orders" {
            var copy = parts
            copy[4] = "{}"
            return copy.joined(separator: "/")
        }
        return normalizedKey
    }

    public static func admitsChinaProductionCall(_ url: URL) -> Bool {
        guard targetsChinaProduction(url), let relative = relativePath(url) else { return false }
        return admitsChinaProductionCall(relative)
    }

    public static func targetsChinaProduction(_ url: URL) -> Bool {
        guard let base = URL(string: ReviewedMarketLaunch.chinaProductionBaseURL),
              url.scheme?.lowercased() == base.scheme?.lowercased(),
              url.host?.lowercased() == base.host?.lowercased(),
              url.port == base.port else { return false }
        let basePath = trimmed(base.path)
        let path = trimmed(url.path)
        return path == basePath || path.hasPrefix(basePath + "/")
    }

    /// Blocks a China production request that this deployment must not send.
    /// Other hosts, including every test double, are unchanged.
    public static func refuseUnwiredChinaProduction(_ request: URLRequest) throws {
        guard let url = request.url, targetsChinaProduction(url) else { return }
        // The order-list path is a player read. A write on that path is not admitted.
        if isPlatformPassOrderWrite(request) { throw APIError.notConfigured }
        guard admitsChinaProductionCall(url) else { throw APIError.notConfigured }
    }

    /// The order list and any order-number child. Order numbers are not always a numeric `{}` segment.
    public static func isPlatformPassOrderPath(_ key: String) -> Bool {
        let path = normalized(key)
        return path == "/api/platform-pass/orders" || path.hasPrefix("/api/platform-pass/orders/")
    }

    /// POST (or any non-read) to the platform-pass order path. The GET stays a player read.
    public static func isPlatformPassOrderWrite(_ request: URLRequest) -> Bool {
        guard let url = request.url else { return false }
        let key = normalized(relativePath(url).map { "/" + $0 } ?? url.path)
        guard isPlatformPassOrderPath(key) else { return false }
        let method = request.httpMethod?.uppercased() ?? "GET"
        return method != "GET" && method != "HEAD"
    }

    /// Password login, bank withdrawal, and virtual goods stay off even when the route is live.
    /// Those three map to capabilities China does not show. Every other hidden route has no
    /// capability, so it stays hidden as well.
    public static func forcedOff(_ path: String) -> String? {
        let key = normalized(path)
        if key == "/api/login" { return "password-login" }
        if key == "/api/withdrawal/create" || key.hasPrefix("/api/fund/preflight")
            || key == "/api/asset/withdraw" || key == "/api/club/settlement/withdraw"
            || key == "/api/wallet/withdraw" { return "bank-withdrawal" }
        if key == "/api/cart" || key.hasPrefix("/api/cart/")
            || key == "/api/product/info" || key == "/api/product/list"
            || key == "/api/registration/pay" || key == "/api/registration/pay/app"
            || key == "/api/pay/create" { return "virtual-goods" }
        return nil
    }

    public static func hidingCapability(for path: String) -> RegionalCapability? {
        switch forcedOff(path) {
        case "password-login": return .usernamePassword
        case "bank-withdrawal": return .merchantPayout
        case "virtual-goods": return .digitalContentPayment
        default: return nil
        }
    }

    /// Missing, new-backend-only, and forced-off routes are hidden. A live route that is not
    /// forced off is the only one the China reviewed deployment shows.
    public static func isHiddenFromChinaReviewed(_ path: String) -> Bool {
        !admitsChinaProductionCall(path)
    }

    /// Whether a feature that calls `path` is offered on this host.
    /// A nil base cannot call the route, so the feature stays hidden.
    /// The China production host offers a route only when `admitsChinaProductionCall` is true.
    /// Password login, bank withdrawal, and virtual goods stay hidden there.
    /// Any other host is a fixture. This does not invent a United States API URL.
    public static func offersFeature(_ path: String, baseURL: URL?) -> Bool {
        guard let baseURL else { return false }
        if targetsChinaProduction(baseURL) { return admitsChinaProductionCall(path) }
        return true
    }

    public static func literalKey(_ path: String) -> String {
        var raw = path
        if let query = raw.firstIndex(of: "?") { raw = String(raw[..<query]) }
        if let fragment = raw.firstIndex(of: "#") { raw = String(raw[..<fragment]) }
        if !raw.hasPrefix("/") { raw = "/" + raw }
        while raw.contains("//") { raw = raw.replacingOccurrences(of: "//", with: "/") }
        return raw
    }

    public static func normalized(_ path: String) -> String {
        let parts = literalKey(path).split(separator: "/", omittingEmptySubsequences: false).map { segment -> String in
            let text = String(segment)
            if !text.isEmpty, text.allSatisfy({ isASCIIDigit($0) }) { return "{}" }
            if text.count >= 2, text.hasPrefix("{"), text.hasSuffix("}") { return "{}" }
            if isOpaqueID(text) { return "{}" }
            return text
        }
        var joined = parts.joined(separator: "/")
        if joined.count > 1, joined.hasSuffix("/") { joined.removeLast() }
        return joined
    }

    private static func relativePath(_ url: URL) -> String? {
        guard let base = URL(string: ReviewedMarketLaunch.chinaProductionBaseURL) else { return nil }
        let basePath = trimmed(base.path)
        let path = url.path
        guard path == basePath || path.hasPrefix(basePath + "/") else { return nil }
        return String(path.dropFirst(basePath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private static func trimmed(_ path: String) -> String {
        path.count > 1 && path.hasSuffix("/") ? String(path.dropLast()) : path
    }

    private static func isASCIIDigit(_ character: Character) -> Bool {
        character.isASCII && character.isNumber
    }

    private static func isOpaqueID(_ segment: String) -> Bool {
        let count = segment.count
        guard (32...36).contains(count) else { return false }
        return segment.allSatisfy { character in
            character == "-" || character.hexDigitValue != nil
        }
    }

    private static let marks: [String: ChinaReviewedRouteMark] = [
        "/api/activity/cancel": .liveInProduction,
        "/api/activity/cancel_preview": .liveInProduction,
        "/api/activity/create-requests/read": .liveInProduction,
        "/api/activity/create-requests/resume-post-processing": .liveInProduction,
        "/api/activity/create-requests/submit": .liveInProduction,
        "/api/activity/delete": .liveInProduction,
        "/api/activity/info": .liveInProduction,
        "/api/activity/list": .liveInProduction,
        "/api/activity/publish": .liveInProduction,
        "/api/activity/update": .liveInProduction,
        "/api/activity/update_publish_status": .liveInProduction,
        "/api/ai/club/design": .liveInProduction,
        "/api/ai/merchant/insight": .liveInProduction,
        "/api/ai/npc/chat/data/delete": .liveInProduction,
        "/api/ai/npc/chat/data/export": .liveInProduction,
        "/api/ai/npc/merchant-chat": .liveInProduction,
        "/api/ai/npc/shop-chat": .liveInProduction,
        "/api/ai/npc/voice-chat": .liveInProduction,
        "/api/ai/safety/precheck": .liveInProduction,
        "/api/ai/template/fill": .liveInProduction,
        "/api/ai/theme/draft": .liveInProduction,
        "/api/ai/theme/draft/quota": .liveInProduction,
        "/api/ai/theme/draft/request": .liveInProduction,
        "/api/approved-topic-release/v1/prepare": .liveInProduction,
        "/api/approved-topic-release/v1/publish": .liveInProduction,
        "/api/approved-topic-release/v1/review/current": .liveInProduction,
        "/api/approved-topic-release/v1/review/prepare": .liveInProduction,
        "/api/approved-topic-release/v1/review/sources": .liveInProduction,
        "/api/approved-topic-release/v1/review/status": .liveInProduction,
        "/api/approved-topic-release/v1/review/submit": .liveInProduction,
        "/api/approved-topic-release/v1/status": .liveInProduction,
        "/api/asset/withdraw": .liveInProduction,
        "/api/badge/wall-v2": .liveInProduction,
        "/api/balance/list": .liveInProduction,
        "/api/capsules/create": .liveInProduction,
        "/api/capsules/delete": .liveInProduction,
        "/api/capsules/detail": .liveInProduction,
        "/api/capsules/list": .liveInProduction,
        "/api/capsules/receipt": .liveInProduction,
        "/api/cart/cart/add": .liveInProduction,
        "/api/cart/delete": .liveInProduction,
        "/api/cart/list": .liveInProduction,
        "/api/cart/order/settlement": .liveInProduction,
        "/api/cart/settlement": .liveInProduction,
        "/api/cart/update": .liveInProduction,
        "/api/category/list": .liveInProduction,
        "/api/channel-platform/admission/requests/": .liveInProduction, // prefix/action segment: children served on TEST r2 5c2017eef
        "/api/channel-platform/governance/moderation/requests/": .liveInProduction, // prefix/action segment: children served on TEST r2 5c2017eef
        "/api/channel-platform/governance/reports/requests/": .liveInProduction, // prefix/action segment: children served on TEST r2 5c2017eef
        "/api/channel-platform/governance/requests/": .liveInProduction, // prefix/action segment: children served on TEST r2 5c2017eef
        "/api/channel-platform/requests/": .liveInProduction, // prefix/action segment: children served on TEST r2 5c2017eef
        "/api/channel/{}/board": .liveInProduction,
        "/api/channel/{}/board/": .liveInProduction, // prefix/action segment: children served on TEST r2 5c2017eef
        "/api/channel/{}/board/{}": .liveInProduction, // prefix/action segment: children served on TEST r2 5c2017eef
        "/api/channel/{}/progress/overview": .liveInProduction,
        "/api/channel/{}/progress/privacy": .liveInProduction,
        "/api/channels/": .liveInProduction,
        "/api/channels/member-state-requests/{}": .liveInProduction,
        "/api/channels/{}": .liveInProduction,
        "/api/channels/{}/archive": .liveInProduction,
        "/api/channels/{}/effective/{}": .liveInProduction,
        "/api/channels/{}/members": .liveInProduction,
        "/api/channels/{}/op-log": .liveInProduction,
        "/api/channels/{}/permissions": .liveInProduction,
        "/api/channels/{}/permissions/{}/{}": .liveInProduction,
        "/api/channels/{}/restore": .liveInProduction,
        "/api/circle-theme/instance/review": .liveInProduction,
        "/api/circle-theme/instance/{}/offers": .liveInProduction,
        "/api/circle-theme/session": .liveInProduction,
        "/api/circle-theme/session/": .liveInProduction,
        "/api/circle-theme/session/join": .liveInProduction,
        "/api/circle-theme/session/{}/card": .liveInProduction,
        "/api/city-game/": .liveInProduction, // prefix/action segment: children served on TEST r2 5c2017eef
        "/api/city-game/acquisition": .liveInProduction, // prefix/action segment: children served on TEST r2 5c2017eef
        "/api/city-game/acquisition/": .liveInProduction, // prefix/action segment: children served on TEST r2 5c2017eef
        "/api/city-game/action-budget": .liveInProduction, // prefix/action segment: children served on TEST r2 5c2017eef
        "/api/city-game/action-budget/command": .liveInProduction,
        "/api/city-game/action-budget/request/{}": .liveInProduction,
        "/api/city-game/action-budget/state": .liveInProduction,
        "/api/city-game/arrival-evidence": .liveInProduction, // prefix/action segment: children served on TEST r2 5c2017eef
        "/api/city-game/arrival-evidence/": .liveInProduction, // prefix/action segment: children served on TEST r2 5c2017eef
        "/api/city-game/merchant/operations": .liveInProduction, // prefix/action segment: children served on TEST r2 5c2017eef
        "/api/city-game/merchant/operations/availability": .liveInProduction,
        "/api/city-game/merchant/operations/intent": .liveInProduction,
        "/api/city-game/merchant/operations/request/": .liveInProduction, // prefix/action segment: children served on TEST r2 5c2017eef
        "/api/city-game/neutral-tasks": .liveInProduction, // prefix/action segment: children served on TEST r2 5c2017eef
        "/api/city-game/neutral-tasks/": .liveInProduction, // prefix/action segment: children served on TEST r2 5c2017eef
        "/api/city-game/onsite-tasks": .liveInProduction, // prefix/action segment: children served on TEST r2 5c2017eef
        "/api/city-game/onsite-tasks/": .liveInProduction, // prefix/action segment: children served on TEST r2 5c2017eef
        "/api/city-game/player-rules": .liveInProduction,
        "/api/city-game/state/deltas": .liveInProduction,
        "/api/city-game/state/snapshot": .liveInProduction,
        "/api/city-game/task-history": .liveInProduction,
        "/api/city-game/team-participation": .liveInProduction, // prefix/action segment: children served on TEST r2 5c2017eef
        "/api/city-game/team-participation/command": .liveInProduction,
        "/api/city-game/team-participation/invite": .liveInProduction,
        "/api/city-game/team-participation/state": .liveInProduction,
        "/api/city-game/{}/request/{}": .liveInProduction,
        "/api/city-value/visits": .liveInProduction,
        "/api/city-value/visits/": .liveInProduction, // prefix/action segment: children served on TEST r2 5c2017eef
        "/api/city-value/visits/feedback": .liveInProduction,
        "/api/city-value/visits/services": .liveInProduction,
        "/api/city/nodes": .liveInProduction,
        "/api/city/nodes/complete": .liveInProduction,
        "/api/city/nodes/favorite": .liveInProduction,
        "/api/city/nodes/{}": .liveInProduction,
        "/api/city/nodes/{}/complete": .liveInProduction,
        "/api/city/nodes/{}/favorite": .liveInProduction,
        "/api/city/walking/target": .liveInProduction,
        "/api/club-compensation/editions": .liveInProduction,
        "/api/club-compensation/hours/report": .liveInProduction,
        "/api/club-compensation/quality/evidence": .liveInProduction,
        "/api/club/access/me": .liveInProduction,
        "/api/club/activity/cancel": .liveInProduction,
        "/api/club/activity/detail": .liveInProduction,
        "/api/club/activity/join": .liveInProduction,
        "/api/club/admission/receipt": .liveInProduction,
        "/api/club/badge/create": .liveInProduction,
        "/api/club/badge/grant": .liveInProduction,
        "/api/club/badge/list": .liveInProduction,
        "/api/club/badge/original-receipt": .liveInProduction,
        "/api/club/become-leader": .liveInProduction,
        "/api/club/calendar/sessions": .liveInProduction,
        "/api/club/channels": .liveInProduction,
        "/api/club/chat": .liveInProduction,
        "/api/club/create": .liveInProduction,
        "/api/club/crm/checkin/detail": .liveInProduction,
        "/api/club/crm/customers/count": .liveInProduction,
        "/api/club/crm/customers/detail": .liveInProduction,
        "/api/club/crm/customers/list": .liveInProduction,
        "/api/club/crm/customers/tag-remark": .liveInProduction,
        "/api/club/crm/topic-customers": .liveInProduction,
        "/api/club/crm/topic-manage-stats": .liveInProduction,
        "/api/club/detail": .liveInProduction,
        "/api/club/dissolution-blockers": .liveInProduction,
        "/api/club/dissolve": .liveInProduction,
        "/api/club/event-notification/audience-counts": .liveInProduction,
        "/api/club/event-notification/preview": .liveInProduction,
        "/api/club/event-notification/retry": .liveInProduction,
        "/api/club/event-notification/send": .liveInProduction,
        "/api/club/event-notification/status": .liveInProduction,
        "/api/club/event-ops/attendance/correct": .liveInProduction,
        "/api/club/event-ops/cancel": .liveInProduction,
        "/api/club/event-ops/occurrence/status": .liveInProduction,
        "/api/club/event-ops/roster": .liveInProduction,
        "/api/club/event-ops/series/create": .liveInProduction,
        "/api/club/event-ops/series/detail": .liveInProduction,
        "/api/club/event-ops/series/list": .liveInProduction,
        "/api/club/event-ops/series/occurrences": .liveInProduction,
        "/api/club/event-ops/series/original-result": .liveInProduction,
        "/api/club/event-ops/series/update-future": .liveInProduction,
        "/api/club/event-ops/topics": .liveInProduction,
        "/api/club/event-ops/waitlist/cancel": .liveInProduction,
        "/api/club/event-ops/waitlist/join": .liveInProduction,
        "/api/club/event-ops/waitlist/status": .liveInProduction,
        "/api/club/event-ops/waitlist/{}": .liveInProduction, // prefix/action segment: children served on TEST r2 5c2017eef
        "/api/club/events": .liveInProduction,
        "/api/club/events/Checkin": .liveInProduction,
        "/api/club/events/proxy-enroll": .liveInProduction,
        "/api/club/events/save": .liveInProduction,
        "/api/club/governance/ban": .liveInProduction,
        "/api/club/governance/cases/appeal": .liveInProduction,
        "/api/club/governance/cases/mine": .liveInProduction,
        "/api/club/governance/cases/report": .liveInProduction,
        "/api/club/governance/list": .liveInProduction,
        "/api/club/governance/owner/transfer": .liveInProduction,
        "/api/club/governance/unban": .liveInProduction,
        "/api/club/group-code": .liveInProduction,
        "/api/club/group-code/save": .liveInProduction,
        "/api/club/home": .liveInProduction,
        "/api/club/join": .liveInProduction,
        "/api/club/join-request/approve": .liveInProduction,
        "/api/club/join-request/reject": .liveInProduction,
        "/api/club/join-requests": .liveInProduction,
        "/api/club/join-requests/apply": .liveInProduction,
        "/api/club/lead/": .liveInProduction,
        "/api/club/lead/edit-ops": .liveInProduction,
        "/api/club/lead/team-progress": .liveInProduction,
        "/api/club/leaderboard": .liveInProduction,
        "/api/club/list": .liveInProduction,
        "/api/club/members": .liveInProduction,
        "/api/club/merchants": .liveInProduction,
        "/api/club/my": .liveInProduction,
        "/api/club/notices": .liveInProduction,
        "/api/club/notices/send": .liveInProduction,
        "/api/club/open-settings/member-post": .liveInProduction,
        "/api/club/open-settings/merchant-coop": .liveInProduction,
        "/api/club/open-settings/public-visible": .liveInProduction,
        "/api/club/open-settings/welcome-note": .liveInProduction,
        "/api/club/open-settings/welcome-note-receipt": .liveInProduction,
        "/api/club/post/": .liveInProduction,
        "/api/club/post/comment/list": .liveInProduction,
        "/api/club/post/delete": .liveInProduction,
        "/api/club/post/feed": .liveInProduction,
        "/api/club/post/history": .liveInProduction,
        "/api/club/post/list": .liveInProduction,
        "/api/club/post/operation/": .liveInProduction, // prefix/action segment: children served on TEST r2 5c2017eef
        "/api/club/post/operation/comment/": .liveInProduction, // prefix/action segment: children served on TEST r2 5c2017eef
        "/api/club/post/operation/receipt": .liveInProduction,
        "/api/club/post/repost": .liveInProduction,
        "/api/club/post/repost/undo": .liveInProduction,
        "/api/club/quit": .liveInProduction,
        "/api/club/recruit/overview": .liveInProduction,
        "/api/club/remove-member": .liveInProduction,
        "/api/club/roles/assign": .liveInProduction,
        "/api/club/roles/assign-receipt": .liveInProduction,
        "/api/club/roles/list": .liveInProduction,
        "/api/club/roles/revoke": .liveInProduction,
        "/api/club/roles/revoke-receipt": .liveInProduction,
        "/api/club/set-member-role": .liveInProduction,
        "/api/club/settings/notify-level": .liveInProduction,
        "/api/club/settlement/summary": .liveInProduction,
        "/api/club/settlements": .liveInProduction, // prefix/action segment: children served on TEST r2 5c2017eef
        "/api/club/settlements/export": .liveInProduction,
        "/api/club/topic-node-answer": .liveInProduction,
        "/api/club/topic-registrations": .liveInProduction,
        "/api/club/topic-setting/detail": .liveInProduction,
        "/api/club/topic-setting/end": .liveInProduction,
        "/api/club/topic-setting/save": .liveInProduction,
        "/api/club/topics": .liveInProduction,
        "/api/club/update-mine": .liveInProduction,
        "/api/club/workbench": .liveInProduction,
        "/api/comment/add": .liveInProduction,
        "/api/comment/delete": .liveInProduction,
        "/api/comment/like": .liveInProduction,
        "/api/comment/list": .liveInProduction,
        "/api/comment/report": .liveInProduction,
        "/api/common/banner": .liveInProduction,
        "/api/common/dict": .liveInProduction,
        "/api/common/infomation_detail": .liveInProduction,
        "/api/common/infomation_list": .liveInProduction,
        "/api/common/uploadOSS": .liveInProduction,
        "/api/common/uploadOSS/receipt": .liveInProduction,
        "/api/community-trust/reports/mine": .liveInProduction,
        "/api/community-trust/reports/submit": .liveInProduction,
        "/api/community-trust/reports/taxonomy": .liveInProduction,
        "/api/community-trust/reports/{}": .liveInProduction,
        "/api/compliance/consents": .liveInProduction,
        "/api/compliance/consents/latest": .liveInProduction,
        "/api/compliance/usage-records": .liveInProduction,
        "/api/config/features": .liveInProduction,
        "/api/content-draft/": .liveInProduction,
        "/api/coop/": .liveInProduction,
        "/api/coop/candidates": .liveInProduction,
        "/api/coop/candidates/received": .liveInProduction,
        "/api/coop/complaint/mine": .liveInProduction,
        "/api/coop/complaint/topics": .liveInProduction,
        "/api/coop/credit": .liveInProduction,
        "/api/coop/deposit/create/app": .liveInProduction,
        "/api/coop/deposit/refund/retry": .liveInProduction,
        "/api/coop/deposit/status": .liveInProduction,
        "/api/coop/finance": .liveInProduction,
        "/api/coop/list": .liveInProduction,
        "/api/coop/mybiz": .liveInProduction,
        "/api/coop/offer/withdraw": .liveInProduction,
        "/api/coop/perk-template/list": .liveInProduction,
        "/api/coop/perks/list": .liveInProduction,
        "/api/coop/pool/list": .liveInProduction,
        "/api/coop/pool/mine": .liveInProduction,
        "/api/coop/pool/received": .liveInProduction,
        "/api/coop/review/summary": .liveInProduction,
        "/api/coupon/": .liveInProduction,
        "/api/coupon/command-receipt": .liveInProduction,
        "/api/coupon/mypublishlist": .liveInProduction,
        "/api/coupon/myrecvlist": .liveInProduction,
        "/api/coupon/publish": .liveInProduction,
        "/api/coupon/qr-token": .liveInProduction,
        "/api/coupon/status": .liveInProduction,
        "/api/coupon/stop": .liveInProduction,
        "/api/coupon/verification": .liveInProduction,
        "/api/creativesquare/action": .liveInProduction,
        "/api/creativesquare/bookmark": .liveInProduction,
        "/api/creativesquare/info": .liveInProduction,
        "/api/creativesquare/like": .liveInProduction,
        "/api/creativesquare/list": .liveInProduction,
        "/api/creativesquare/report": .liveInProduction,
        "/api/creator/apply": .liveInProduction,
        "/api/creator/center": .liveInProduction,
        "/api/exploration-anniversary": .liveInProduction,
        "/api/exploration-goals/cancel": .liveInProduction,
        "/api/exploration-goals/create": .liveInProduction,
        "/api/exploration-goals/detail": .liveInProduction,
        "/api/exploration-goals/list": .liveInProduction,
        "/api/exploration-goals/receipt": .liveInProduction,
        "/api/free-explore/bundle/": .liveInProduction,
        "/api/free-explore/bundle/reservation": .liveInProduction,
        "/api/free-explore/bundle/reservation/": .liveInProduction,
        "/api/free-explore/bundle/transfer": .liveInProduction,
        "/api/free-explore/bundle/voucher/appeal": .liveInProduction,
        "/api/friend/": .liveInProduction, // prefix/action segment: children served on TEST r2 5c2017eef
        "/api/friend/accept": .liveInProduction,
        "/api/friend/cancel": .liveInProduction,
        "/api/friend/channel-invite/batch": .liveInProduction,
        "/api/friend/channel-invite/command": .liveInProduction,
        "/api/friend/channel-invite/landing": .liveInProduction,
        "/api/friend/channel-invite/mine": .liveInProduction,
        "/api/friend/channel-invite/notice": .liveInProduction,
        "/api/friend/channel-invite/picker": .liveInProduction,
        "/api/friend/channel-invite/receipt": .liveInProduction,
        "/api/friend/directory": .liveInProduction,
        "/api/friend/directory/detail": .liveInProduction,
        "/api/friend/group/delete": .liveInProduction,
        "/api/friend/group/list": .liveInProduction,
        "/api/friend/group/save": .liveInProduction,
        "/api/friend/list": .liveInProduction,
        "/api/friend/metadata": .liveInProduction,
        "/api/friend/metadata/receipt": .liveInProduction,
        "/api/friend/metadata/settle": .liveInProduction,
        "/api/friend/progress": .liveInProduction,
        "/api/friend/receipt": .liveInProduction,
        "/api/friend/reject": .liveInProduction,
        "/api/friend/relationship": .liveInProduction,
        "/api/friend/remark": .liveInProduction,
        "/api/friend/removal/receipt": .liveInProduction,
        "/api/friend/removal/settle": .liveInProduction,
        "/api/friend/remove": .liveInProduction,
        "/api/friend/request": .liveInProduction,
        "/api/friend/requests": .liveInProduction,
        "/api/friend/team-invite/landing": .liveInProduction,
        "/api/friend/team-invite/mine": .liveInProduction,
        "/api/friend/team-invite/picker": .liveInProduction,
        "/api/fund/preflight/bank-withdrawal": .liveInProduction,
        "/api/fund/preflight/{}/": .liveInProduction,
        "/api/fund/preflight/{}/confirm": .liveInProduction,
        "/api/fund/preflight/{}/reject": .liveInProduction,
        "/api/game/session/": .liveInProduction,
        "/api/game/session/command": .liveInProduction,
        "/api/game/session/merchant/entries": .liveInProduction,
        "/api/game/session/recap/export": .liveInProduction,
        "/api/game/session/receipt": .liveInProduction,
        "/api/game/session/view": .liveInProduction,
        "/api/growth/center": .liveInProduction,
        "/api/growth/leaderboard": .liveInProduction,
        "/api/growth/leaderboard/anonymous": .liveInProduction,
        "/api/guilds/{}/{}/channels": .liveInProduction,
        "/api/guilds/{}/{}/channels/manage": .liveInProduction,
        "/api/im/appeals": .liveInProduction,
        "/api/im/appeals/": .liveInProduction,
        "/api/im/appeals/{}/evidence": .liveInProduction,
        "/api/im/appeals/{}/withdraw": .liveInProduction,
        "/api/im/audit-log": .liveInProduction,
        "/api/im/block": .liveInProduction,
        "/api/im/chain/": .liveInProduction,
        "/api/im/chain/close": .liveInProduction,
        "/api/im/chain/create": .liveInProduction,
        "/api/im/chain/info": .liveInProduction,
        "/api/im/chain/join": .liveInProduction,
        "/api/im/chain/withdraw": .liveInProduction,
        "/api/im/channel/": .liveInProduction,
        "/api/im/channel/checkin": .liveInProduction,
        "/api/im/channel/checkin-rank": .liveInProduction,
        "/api/im/channel/checkin-request": .liveInProduction,
        "/api/im/channel/checkin-status": .liveInProduction,
        "/api/im/conversations": .liveInProduction,
        "/api/im/delete": .liveInProduction,
        "/api/im/device/attempts": .liveInProduction,
        "/api/im/file/message/": .liveInProduction,
        "/api/im/file/message/{}/authorization": .liveInProduction,
        "/api/im/file/message/{}/preview": .liveInProduction,
        "/api/im/file/receipt": .liveInProduction,
        "/api/im/file/scan": .liveInProduction,
        "/api/im/file/upload": .liveInProduction,
        "/api/im/ingame/resolve": .liveInProduction,
        "/api/im/ingame/summary": .liveInProduction,
        "/api/im/interaction/request": .liveInProduction,
        "/api/im/members/{}/roles": .liveInProduction,
        "/api/im/message": .liveInProduction,
        "/api/im/message/": .liveInProduction,
        "/api/im/message/context": .liveInProduction,
        "/api/im/message/edit": .liveInProduction,
        "/api/im/message/mutations": .liveInProduction,
        "/api/im/message/recall": .liveInProduction,
        "/api/im/message/request": .liveInProduction,
        "/api/im/message/{}/attachment": .liveInProduction,
        "/api/im/message/{}/revisions": .liveInProduction,
        "/api/im/messages": .liveInProduction,
        "/api/im/moderation/": .liveInProduction,
        "/api/im/moderation/actions": .liveInProduction,
        "/api/im/moderation/ban": .liveInProduction,
        "/api/im/moderation/kick": .liveInProduction,
        "/api/im/moderation/me": .liveInProduction,
        "/api/im/moderation/timeout": .liveInProduction,
        "/api/im/moderation/{}/revoke": .liveInProduction,
        "/api/im/mute": .liveInProduction,
        "/api/im/mute-receipt": .liveInProduction,
        "/api/im/mute-state": .liveInProduction,
        "/api/im/notification-requests/": .liveInProduction,
        "/api/im/notify-log": .liveInProduction,
        "/api/im/notify-pref": .liveInProduction,
        "/api/im/pin": .liveInProduction,
        "/api/im/pins": .liveInProduction,
        "/api/im/pins/sort": .liveInProduction,
        "/api/im/poll/close": .liveInProduction,
        "/api/im/poll/create": .liveInProduction,
        "/api/im/poll/create-receipt": .liveInProduction,
        "/api/im/poll/result": .liveInProduction,
        "/api/im/poll/vote": .liveInProduction,
        "/api/im/read": .liveInProduction,
        "/api/im/read-receipt": .liveInProduction,
        "/api/im/read-state": .liveInProduction,
        "/api/im/report": .liveInProduction,
        "/api/im/roles": .liveInProduction,
        "/api/im/roles/": .liveInProduction,
        "/api/im/roles/{}/members": .liveInProduction,
        "/api/im/route-share-source": .liveInProduction,
        "/api/im/search": .liveInProduction,
        "/api/im/send": .liveInProduction,
        "/api/im/send-receipt": .liveInProduction,
        "/api/im/start": .liveInProduction,
        "/api/im/unblock": .liveInProduction,
        "/api/im/unpin": .liveInProduction,
        "/api/im/unread-summary": .liveInProduction,
        "/api/im/unread-total": .liveInProduction,
        "/api/im/video/message/": .liveInProduction,
        "/api/im/video/message/{}/authorization": .liveInProduction,
        "/api/im/video/message/{}/preview": .liveInProduction,
        "/api/im/video/policy": .liveInProduction,
        "/api/im/video/receipt": .liveInProduction,
        "/api/im/video/upload": .liveInProduction,
        "/api/im/voice/message/": .liveInProduction,
        "/api/im/voice/message/{}": .liveInProduction,
        "/api/im/voice/message/{}/authorization": .liveInProduction,
        "/api/im/voice/receipt": .liveInProduction,
        "/api/im/voice/upload": .liveInProduction,
        "/api/im/webhook": .liveInProduction,
        "/api/im/webhook/": .liveInProduction,
        "/api/im/webhook/context": .liveInProduction,
        "/api/im/{}": .liveInProduction,
        "/api/invite/revoke": .liveInProduction,
        "/api/invoice/": .liveInProduction,
        "/api/join-request/approve": .liveInProduction,
        "/api/join-request/cancel": .liveInProduction,
        "/api/join-request/reject": .liveInProduction,
        "/api/join-request/submit": .liveInProduction,
        "/api/location-share/personal": .liveInProduction, // prefix/action segment: children served on TEST r2 5c2017eef
        "/api/login": .liveInProduction,
        "/api/login/apple": .liveInProduction,
        "/api/login/phone": .liveInProduction,
        "/api/login/wechat/app": .liveInProduction,
        "/api/logout": .liveInProduction,
        "/api/map/nearby": .liveInProduction,
        "/api/map/public-layers": .liveInProduction,
        "/api/map/reverse-geocode": .liveInProduction,
        "/api/marketing/affiliate/summary": .liveInProduction,
        "/api/marketing/product": .liveInProduction, // prefix/action segment: children served on TEST r2 5c2017eef
        "/api/marketing/product/list": .liveInProduction,
        "/api/marketing/product/orders": .liveInProduction,
        "/api/medal/wall": .liveInProduction,
        "/api/media/asset/list": .liveInProduction,
        "/api/media/asset/{}": .liveInProduction,
        "/api/media/asset/{}/preview": .liveInProduction,
        "/api/member/reputation": .liveInProduction,
        "/api/merchant/access/me": .liveInProduction,
        "/api/merchant/aftercare/detail": .liveInProduction,
        "/api/merchant/aftercare/list": .liveInProduction,
        "/api/merchant/aftercare/respond": .liveInProduction,
        "/api/merchant/authoring/draft-selection/list": .liveInProduction,
        "/api/merchant/authoring/draft-selection/resolve": .liveInProduction,
        "/api/merchant/authoring/drafts": .liveInProduction,
        "/api/merchant/authoring/drafts/{}": .liveInProduction,
        "/api/merchant/authoring/environment": .liveInProduction,
        "/api/merchant/authoring/jobs": .liveInProduction,
        "/api/merchant/authoring/jobs/cancel": .liveInProduction,
        "/api/merchant/authoring/main-line": .liveInProduction,
        "/api/merchant/authoring/player": .liveInProduction,
        "/api/merchant/authoring/player/": .liveInProduction, // prefix/action segment: children served on TEST r2 5c2017eef
        "/api/merchant/authoring/player/{}/game": .liveInProduction,
        "/api/merchant/authoring/player/{}/requests/{}": .liveInProduction,
        "/api/merchant/authoring/public": .liveInProduction,
        "/api/merchant/authoring/releases": .liveInProduction,
        "/api/merchant/authoring/releases/{}/withdraw": .liveInProduction,
        "/api/merchant/business-status": .liveInProduction,
        "/api/merchant/business-status/update": .liveInProduction,
        "/api/merchant/chapter-application/apply": .liveInProduction,
        "/api/merchant/chapter-application/audit": .liveInProduction,
        "/api/merchant/chapter-application/invitable": .liveInProduction,
        "/api/merchant/chapter-application/invite": .liveInProduction,
        "/api/merchant/chapter-application/invite/respond": .liveInProduction,
        "/api/merchant/chapter-application/mine": .liveInProduction,
        "/api/merchant/chapter-application/owner-list": .liveInProduction,
        "/api/merchant/chapter-application/owner-mine": .liveInProduction,
        "/api/merchant/chapter-application/withdraw": .liveInProduction,
        "/api/merchant/chapter-node/audit": .liveInProduction,
        "/api/merchant/chapter-node/live-checkin-code": .liveInProduction,
        "/api/merchant/chapter-node/mine": .liveInProduction,
        "/api/merchant/chapter-node/npc/detail": .liveInProduction,
        "/api/merchant/chapter-node/npc/save": .liveInProduction,
        "/api/merchant/chapter-node/npc/voice/enroll": .liveInProduction,
        "/api/merchant/chapter-node/npc/voice/reset": .liveInProduction,
        "/api/merchant/chapter-node/npc/voice/status": .liveInProduction,
        "/api/merchant/chapter-node/pending": .liveInProduction,
        "/api/merchant/chapter-node/poster-code": .liveInProduction,
        "/api/merchant/chapter-node/submit": .liveInProduction,
        "/api/merchant/city-node/claim": .liveInProduction,
        "/api/merchant/city-node/claim/cancel": .liveInProduction,
        "/api/merchant/city-node/claimable": .liveInProduction,
        "/api/merchant/city-node/list": .liveInProduction,
        "/api/merchant/city-node/offline": .liveInProduction,
        "/api/merchant/city-node/poster-code": .liveInProduction,
        "/api/merchant/city-node/save": .liveInProduction,
        "/api/merchant/city-node/template/submit": .liveInProduction,
        "/api/merchant/city-value/event/{}/benefit": .liveInProduction,
        "/api/merchant/city-value/events": .liveInProduction,
        "/api/merchant/city-value/report": .liveInProduction,
        "/api/merchant/city-value/result/{}": .liveInProduction,
        "/api/merchant/clubs": .liveInProduction,
        "/api/merchant/commerce/capabilities": .liveInProduction,
        "/api/merchant/coop-profile": .liveInProduction,
        "/api/merchant/coop-profile/save": .liveInProduction,
        "/api/merchant/crm/broadcast": .liveInProduction,
        "/api/merchant/crm/broadcast/preview": .liveInProduction,
        "/api/merchant/crm/campaigns": .liveInProduction,
        "/api/merchant/crm/campaigns/": .liveInProduction,
        "/api/merchant/crm/campaigns/coupons": .liveInProduction,
        "/api/merchant/crm/campaigns/preview": .liveInProduction,
        "/api/merchant/crm/campaigns/{}": .liveInProduction,
        "/api/merchant/crm/campaigns/{}/{}": .liveInProduction, // prefix/action segment: children served on TEST r2 5c2017eef
        "/api/merchant/crm/customers/61001/contact": .liveInProduction,
        "/api/merchant/crm/customers/61001/detail": .liveInProduction,
        "/api/merchant/crm/customers/list": .liveInProduction,
        "/api/merchant/crm/customers/tags/batch": .liveInProduction,
        "/api/merchant/crm/customers/{}/contact": .liveInProduction,
        "/api/merchant/crm/customers/{}/detail": .liveInProduction,
        "/api/merchant/crm/customers/{}/notes": .liveInProduction,
        "/api/merchant/crm/customers/{}/notes/hide": .liveInProduction,
        "/api/merchant/crm/customers/{}/tags": .liveInProduction,
        "/api/merchant/crm/customers/{}/tags/remove": .liveInProduction,
        "/api/merchant/crm/exports": .liveInProduction,
        "/api/merchant/crm/exports/74001/download": .liveInProduction,
        "/api/merchant/crm/exports/74001/status": .liveInProduction,
        "/api/merchant/crm/exports/{}/download": .liveInProduction,
        "/api/merchant/crm/exports/{}/status": .liveInProduction,
        "/api/merchant/crm/marketing-consents": .liveInProduction,
        "/api/merchant/crm/segments": .liveInProduction,
        "/api/merchant/dashboard": .liveInProduction,
        "/api/merchant/decor/save": .liveInProduction,
        "/api/merchant/desk/anchor": .liveInProduction,
        "/api/merchant/desk/anchor/save": .liveInProduction,
        "/api/merchant/desk/products": .liveInProduction,
        "/api/merchant/desk/products/detail": .liveInProduction,
        "/api/merchant/desk/products/sku/save": .liveInProduction,
        "/api/merchant/desk/receipt": .liveInProduction,
        "/api/merchant/desk/stores": .liveInProduction,
        "/api/merchant/events": .liveInProduction,
        "/api/merchant/finance/overview": .liveInProduction,
        "/api/merchant/finance/public-transfer-batch-detail": .liveInProduction,
        "/api/merchant/finance/public-transfer-batches": .liveInProduction,
        "/api/merchant/finance/redemption-detail": .liveInProduction,
        "/api/merchant/finance/redemptions": .liveInProduction,
        "/api/merchant/finance/settlement-entries": .liveInProduction,
        "/api/merchant/info": .liveInProduction,
        "/api/merchant/insight": .liveInProduction,
        "/api/merchant/list": .liveInProduction,
        "/api/merchant/marketing-home": .liveInProduction,
        "/api/merchant/merchant_registration": .liveInProduction,
        "/api/merchant/nearby": .liveInProduction,
        "/api/merchant/npc/avatar/generate": .liveInProduction,
        "/api/merchant/npc/avatar/status": .liveInProduction,
        "/api/merchant/npc/knowledge-review": .liveInProduction,
        "/api/merchant/npc/knowledge-review/request": .liveInProduction,
        "/api/merchant/npc/profile": .liveInProduction,
        "/api/merchant/npc/save": .liveInProduction,
        "/api/merchant/npc/voice/enroll": .liveInProduction,
        "/api/merchant/npc/voice/reset": .liveInProduction,
        "/api/merchant/npc/voice/revoke": .liveInProduction,
        "/api/merchant/npc/voice/script": .liveInProduction,
        "/api/merchant/npc/voice/status": .liveInProduction,
        "/api/merchant/offer-withdrawal/request/current": .liveInProduction,
        "/api/merchant/offer-withdrawal/request/result": .liveInProduction,
        "/api/merchant/offer-withdrawal/request/withdraw": .liveInProduction,
        "/api/merchant/operators/invite": .liveInProduction,
        "/api/merchant/operators/invite/accept": .liveInProduction,
        "/api/merchant/operators/invite/revoke": .liveInProduction,
        "/api/merchant/operators/list": .liveInProduction,
        "/api/merchant/operators/remove": .liveInProduction,
        "/api/merchant/operators/role": .liveInProduction,
        "/api/merchant/operators/roles": .liveInProduction,
        "/api/merchant/orders": .liveInProduction,
        "/api/merchant/poi/detail": .liveInProduction,
        "/api/merchant/predict/inbox": .liveInProduction,
        "/api/merchant/predict/settle": .liveInProduction,
        "/api/merchant/public-detail": .liveInProduction,
        "/api/merchant/public-home": .liveInProduction,
        "/api/merchant/relation-home": .liveInProduction,
        "/api/merchant/reviews/create": .liveInProduction,
        "/api/merchant/reviews/manage": .liveInProduction,
        "/api/merchant/reviews/public": .liveInProduction,
        "/api/merchant/reviews/reply/receipt": .liveInProduction,
        "/api/merchant/reviews/report": .liveInProduction,
        "/api/merchant/reviews/{}": .liveInProduction, // prefix/action segment: children served on TEST r2 5c2017eef
        "/api/merchant/shop/apply": .liveInProduction,
        "/api/merchant/subscription": .liveInProduction,
        "/api/merchant/todo-summary": .liveInProduction,
        "/api/merchant/upcoming-runs": .liveInProduction,
        "/api/merchant/update": .liveInProduction,
        "/api/merchant/verification-records": .liveInProduction,
        "/api/mod-commerce/": .missing, // intentionally closed on the backend: `ApiAppGapsWorkshopController` OFF stub (`WORKSHOP_COMMERCE_DISABLED`), 2/2 routes; GET `/
        "/api/mod-installation/": .missing, // intentionally closed on the backend: `ApiAppGapsWorkshopController` OFF stub (`WORKSHOP_FEATURE_NOT_ENABLED`), 2/2 routes; GET 
        "/api/mod-owned-report/licenses/": .missing, // intentionally closed on the backend: `ApiAppGapsWorkshopController` OFF stub (`WORKSHOP_FEATURE_NOT_ENABLED`), 2/2 routes; GET 
        "/api/mod-settlement/mine": .missing, // intentionally closed on the backend: `ApiAppGapsWorkshopController` OFF stub (`WORKSHOP_FEATURE_NOT_ENABLED`), 1/1 routes; GET 
        "/api/mod-settlement/mine/income": .missing, // intentionally closed on the backend: `ApiAppGapsWorkshopController` OFF stub (`WORKSHOP_FEATURE_NOT_ENABLED`), 2/2 routes; GET 
        "/api/mod-upgrade/": .missing, // intentionally closed on the backend: `ApiAppGapsWorkshopController` OFF stub (`WORKSHOP_FEATURE_NOT_ENABLED`), 2/2 routes; GET 
        "/api/monthly-recap": .liveInProduction,
        "/api/native/blacklist/current": .liveInProduction,
        "/api/native/blacklist/list": .liveInProduction,
        "/api/native/blacklist/receipt": .liveInProduction,
        "/api/native/blacklist/settle": .liveInProduction,
        "/api/native/blacklist/unblock": .liveInProduction,
        "/api/native/channels/read-through": .liveInProduction,
        "/api/native/device/enroll": .liveInProduction,
        "/api/native/device/enrollment-challenge": .liveInProduction,
        "/api/native/device/revoke": .liveInProduction,
        "/api/native/device/status": .liveInProduction,
        "/api/native/home": .liveInProduction,
        "/api/native/home/return": .liveInProduction,
        "/api/npc/chat/delete": .liveInProduction,
        "/api/object-card/list": .liveInProduction,
        "/api/official/broadcast": .liveInProduction,
        "/api/official/broadcast/{}/click": .liveInProduction,
        "/api/official/broadcast/{}/stats": .liveInProduction,
        "/api/official/can-publish": .liveInProduction,
        "/api/official/command": .liveInProduction,
        "/api/official/command/cancel": .liveInProduction,
        "/api/official/command/query": .liveInProduction,
        "/api/official/events": .liveInProduction,
        "/api/official/events/{}": .liveInProduction,
        "/api/official/events/{}/arrivals": .liveInProduction,
        "/api/official/events/{}/complete": .liveInProduction,
        "/api/official/events/{}/signup": .liveInProduction,
        "/api/official/invites": .liveInProduction,
        "/api/official/merchant-invites": .liveInProduction,
        "/api/official/my-events": .liveInProduction,
        "/api/official/my-published": .liveInProduction,
        "/api/official/publish": .liveInProduction,
        "/api/official/v2/events": .liveInProduction, // prefix/action segment: children served on TEST r2 5c2017eef
        "/api/official/v2/events/{}/publish-check": .liveInProduction,
        "/api/official/v2/organizer-invites/{}/{}": .liveInProduction, // prefix/action segment: children served on TEST r2 5c2017eef
        "/api/official/v2/parties/{}/{}": .liveInProduction,
        "/api/official/v2/party-inbox": .liveInProduction,
        "/api/onboarding/get": .liveInProduction,
        "/api/onboarding/submit": .liveInProduction,
        "/api/orient/safety/check": .liveInProduction,
        "/api/orient/scoring/appeal": .liveInProduction,
        "/api/orient/scoring/dispute": .liveInProduction,
        "/api/orient/scoring/mine": .liveInProduction,
        "/api/orient/scoring/receipt": .liveInProduction,
        "/api/orient/scoring/session/{}": .liveInProduction,
        "/api/orient/scoring/session/{}/leaderboard": .liveInProduction,
        "/api/orient/scoring/session/{}/settle": .liveInProduction,
        "/api/orient/scoring/session/{}/sync": .liveInProduction,
        "/api/orient/task/alternative/receipt": .liveInProduction,
        "/api/orient/task/alternative/submit": .liveInProduction,
        "/api/orient/task/state": .liveInProduction,
        "/api/orient/team/detail": .liveInProduction,
        "/api/orient/team/lobby": .liveInProduction,
        "/api/orient/team/ranking": .liveInProduction,
        "/api/pay/create": .liveInProduction,
        "/api/personal-exploration-export/page": .liveInProduction,
        "/api/personal-exploration-export/prepare": .liveInProduction,
        "/api/play/": .liveInProduction,
        "/api/play/action-receipt": .liveInProduction,
        "/api/play/advanced/action": .liveInProduction,
        "/api/play/advanced/leaderboard": .liveInProduction,
        "/api/play/advanced/start": .liveInProduction,
        "/api/play/advanced/state": .liveInProduction,
        "/api/play/advanced/time-window": .liveInProduction,
        "/api/play/answer": .liveInProduction,
        "/api/play/arrive": .liveInProduction,
        "/api/play/character": .liveInProduction,
        "/api/play/check/": .liveInProduction,
        "/api/play/checkin": .liveInProduction,
        "/api/play/city-orientation/": .liveInProduction, // prefix/action segment: children served on TEST r2 5c2017eef
        "/api/play/city-orientation/answer": .liveInProduction,
        "/api/play/city-orientation/receipt": .liveInProduction,
        "/api/play/companionLine": .liveInProduction,
        "/api/play/egg/collect": .liveInProduction,
        "/api/play/encounter": .liveInProduction,
        "/api/play/ending": .liveInProduction,
        "/api/play/growth": .liveInProduction,
        "/api/play/help": .liveInProduction,
        "/api/play/help/advanced/receipt": .liveInProduction,
        "/api/play/help/receipt": .liveInProduction,
        "/api/play/hint/unlock": .liveInProduction,
        "/api/play/journey/ask": .liveInProduction,
        "/api/play/journey/backpack": .liveInProduction,
        "/api/play/journey/casebook": .liveInProduction,
        "/api/play/journey/ending": .liveInProduction,
        "/api/play/journey/opening/complete": .liveInProduction,
        "/api/play/journey/stage-end": .liveInProduction,
        "/api/play/journey/thought/sync": .liveInProduction,
        "/api/play/leaderboard": .liveInProduction,
        "/api/play/my-completed": .liveInProduction,
        "/api/play/nodes": .liveInProduction,
        "/api/play/orient/session": .liveInProduction,
        "/api/play/orient/session/abandon": .liveInProduction,
        "/api/play/orient/session/current": .liveInProduction,
        "/api/play/orient/session/prepare": .liveInProduction,
        "/api/play/orient/session/receipt": .liveInProduction,
        "/api/play/orient/session/start": .liveInProduction,
        "/api/play/orient/session/task/{}/result": .liveInProduction,
        "/api/play/os/{}": .liveInProduction,
        "/api/play/photo": .liveInProduction,
        "/api/play/player-journey/choices": .liveInProduction,
        "/api/play/player-journey/memory": .liveInProduction,
        "/api/play/player-journey/report": .liveInProduction,
        "/api/play/player-journey/seats": .liveInProduction,
        "/api/play/preference/{}": .liveInProduction,
        "/api/play/preference/{}/submit": .liveInProduction,
        "/api/play/puzzle/hint": .liveInProduction,
        "/api/play/puzzle/reveal": .liveInProduction,
        "/api/play/route-action": .liveInProduction,
        "/api/play/route-state": .liveInProduction,
        "/api/play/rpg/status": .liveInProduction,
        "/api/play/run-session": .liveInProduction,
        "/api/play/run-session/": .liveInProduction,
        "/api/play/run-session/list": .liveInProduction,
        "/api/play/scan-entry": .liveInProduction,
        "/api/play/seat-invitations": .liveInProduction,
        "/api/play/sensor-result": .liveInProduction,
        "/api/play/tag/{}/confirm": .liveInProduction,
        "/api/play/tag/{}/correct": .liveInProduction,
        "/api/play/tag/{}/revoke": .liveInProduction,
        "/api/play/theme/": .liveInProduction,
        "/api/play/theme/action": .liveInProduction,
        "/api/play/theme/card": .liveInProduction,
        "/api/play/theme/history": .liveInProduction,
        "/api/play/theme/state": .liveInProduction,
        "/api/play/theme/support-matrix": .liveInProduction,
        "/api/points/list": .liveInProduction,
        "/api/points/result_list": .liveInProduction,
        "/api/preset/route/info": .liveInProduction,
        "/api/preset/route/list": .liveInProduction,
        "/api/privacy/progress": .liveInProduction,
        "/api/product/info": .liveInProduction,
        "/api/product/list": .liveInProduction,
        "/api/progress/meter": .liveInProduction,
        "/api/progress/requests": .liveInProduction,
        "/api/progress/requests/": .liveInProduction, // prefix/action segment: children served on TEST r2 5c2017eef
        "/api/progress/requests/{}": .liveInProduction,
        "/api/project/home": .liveInProduction,
        "/api/project/my": .liveInProduction,
        "/api/project/players": .liveInProduction,
        "/api/project/state-requests/context": .liveInProduction,
        "/api/project/state-requests/read": .liveInProduction,
        "/api/project/state-requests/submit": .liveInProduction,
        "/api/public-catalog/city/list": .liveInProduction,
        "/api/public-catalog/filters": .liveInProduction,
        "/api/public-catalog/ids": .liveInProduction,
        "/api/public-catalog/info": .liveInProduction,
        "/api/public-catalog/list": .liveInProduction,
        "/api/public-catalog/map": .liveInProduction,
        "/api/publish/home": .liveInProduction,
        "/api/publisher/identity": .liveInProduction,
        "/api/publisher/identity/status": .liveInProduction,
        "/api/rank/list": .liveInProduction,
        "/api/referral/landing/gift": .liveInProduction,
        "/api/referral/landing/referral": .liveInProduction,
        "/api/registration/cancel": .liveInProduction,
        "/api/registration/cancel-by-owner": .liveInProduction,
        "/api/registration/cancel-refund": .liveInProduction,
        "/api/registration/count_by_date": .liveInProduction,
        "/api/registration/create": .liveInProduction,
        "/api/registration/explore-completion": .liveInProduction,
        "/api/registration/info": .liveInProduction,
        "/api/registration/list": .liveInProduction,
        "/api/registration/merchant/cancel": .liveInProduction,
        "/api/registration/merchant/create": .liveInProduction,
        "/api/registration/merchant/info": .liveInProduction,
        "/api/registration/merchant/list": .liveInProduction,
        "/api/registration/merchant/select": .liveInProduction,
        "/api/registration/merchant/update": .liveInProduction,
        "/api/registration/my-joined": .liveInProduction,
        "/api/registration/original-event": .liveInProduction,
        "/api/registration/pay": .liveInProduction,
        "/api/registration/pay/app": .liveInProduction,
        "/api/registration/quote": .liveInProduction,
        "/api/registration/scan_dynamic_code": .liveInProduction,
        "/api/registration/scan_qr_code": .liveInProduction,
        "/api/registration/scan_qr_code_chapter": .liveInProduction,
        "/api/registration/scan_qr_code_station": .liveInProduction,
        "/api/reward-pledge": .liveInProduction, // prefix/action segment: children served on TEST r2 5c2017eef
        "/api/reward-pledge/": .liveInProduction, // prefix/action segment: children served on TEST r2 5c2017eef
        "/api/reward-pledge/awards": .liveInProduction,
        "/api/reward-pledge/awards/": .missing, // intentionally closed on the backend: `ApiAppGapsWorkshopController` OFF stub (`POLICY_CLOSED`), 1/1 routes; POST `/api/reward-p
        "/api/reward-pledge/drafts": .liveInProduction,
        "/api/reward-pledge/fulfilment/awards": .liveInProduction,
        "/api/reward-pledge/fulfilment/expire": .liveInProduction,
        "/api/reward-pledge/fulfilment/preview": .liveInProduction,
        "/api/reward-pledge/fulfilment/redeem": .liveInProduction,
        "/api/reward-pledge/fulfilment/resolve": .liveInProduction,
        "/api/reward-pledge/ops": .liveInProduction,
        "/api/reward-pledge/ops/": .liveInProduction, // prefix/action segment: children served on TEST r2 5c2017eef
        "/api/reward-pledge/pledges": .liveInProduction,
        "/api/reward-pledge/review": .liveInProduction,
        "/api/reward-pledge/review/": .missing, // intentionally closed on the backend: `ApiAppGapsWorkshopController` OFF stub (`POLICY_CLOSED`), 1/1 routes; GET `/api/reward-pl
        "/api/reward-pledge/versions/{}/hold": .liveInProduction,
        "/api/reward-pledge/versions/{}/withdraw": .liveInProduction,
        "/api/rewards/noncash": .liveInProduction,
        "/api/rewards/noncash/{}": .liveInProduction,
        "/api/rewards/noncash/cases": .liveInProduction,
        "/api/rewards/noncash/claims": .liveInProduction,
        "/api/rewards/noncash/claims/recover": .liveInProduction,
        "/api/rewards/noncash/subjects/{}": .liveInProduction,
        "/api/rewards/noncash/versions/{}": .liveInProduction,
        "/api/roam/badge/shop-streak": .liveInProduction,
        "/api/roam/checkin": .liveInProduction,
        "/api/roam/entry/nearby": .liveInProduction,
        "/api/roam/finish": .liveInProduction,
        "/api/roam/hangout/nearby": .liveInProduction,
        "/api/roam/nearby-exploreday": .liveInProduction,
        "/api/roam/nearby-runners": .liveInProduction,
        "/api/roam/passport/": .liveInProduction,
        "/api/roam/poi/discover": .liveInProduction,
        "/api/roam/pois": .liveInProduction,
        "/api/roam/presence": .liveInProduction,
        "/api/roam/presence-visibility": .liveInProduction,
        "/api/roam/reveal": .liveInProduction,
        "/api/roam/session": .liveInProduction,
        "/api/roam/share/snapshot": .liveInProduction,
        "/api/roam/shop/visit": .liveInProduction,
        "/api/roam/stamp/create": .liveInProduction,
        "/api/roam/stamp/exchange": .liveInProduction,
        "/api/roam/stamp/list": .liveInProduction,
        "/api/roam/stamp/received": .liveInProduction,
        "/api/roam/tiles": .liveInProduction,
        "/api/roam/tiles/page": .liveInProduction,
        "/api/role/info": .liveInProduction,
        "/api/sms/send": .liveInProduction,
        "/api/space/join-pause": .liveInProduction,
        "/api/space/leave": .liveInProduction,
        "/api/stats/club": .liveInProduction,
        "/api/support/tickets": .liveInProduction, // prefix/action segment: children served on TEST r2 5c2017eef
        "/api/team/applications": .liveInProduction,
        "/api/team/command": .liveInProduction,
        "/api/team/command/cancel": .liveInProduction,
        "/api/team/command/query": .liveInProduction,
        "/api/team/apply": .liveInProduction,
        "/api/team/create": .liveInProduction,
        "/api/team/disband": .liveInProduction,
        "/api/team/handle": .liveInProduction,
        "/api/team/info": .liveInProduction,
        "/api/team/join": .liveInProduction,
        "/api/team/join-mode": .liveInProduction,
        "/api/team/kick": .liveInProduction,
        "/api/team/my": .liveInProduction,
        "/api/team/my-applications": .liveInProduction,
        "/api/team/nearby": .liveInProduction,
        "/api/team/original-request": .liveInProduction,
        "/api/team/quit": .liveInProduction,
        "/api/team/report": .liveInProduction,
        "/api/team/withdraw": .liveInProduction,
        "/api/team/{}": .liveInProduction, // prefix/action segment: children served on TEST r2 5c2017eef
        "/api/template/author-requests/read": .liveInProduction,
        "/api/template/author-requests/submit": .liveInProduction,
        "/api/template/delete": .liveInProduction,
        "/api/template/draft": .liveInProduction,
        "/api/template/homeData": .liveInProduction,
        "/api/template/info": .liveInProduction,
        "/api/template/list": .liveInProduction,
        "/api/template/my-list": .liveInProduction,
        "/api/template/myinfo": .liveInProduction,
        "/api/template/personal-report": .liveInProduction,
        "/api/template/publish": .liveInProduction,
        "/api/template/report": .liveInProduction,
        "/api/template/topic-template/info": .liveInProduction,
        "/api/template/topic-template/list": .liveInProduction,
        "/api/template/topic-template/use": .liveInProduction,
        "/api/template/updateLibraryStatus": .liveInProduction,
        "/api/topic/attribute-author": .liveInProduction,
        "/api/topic/attribute-author/references": .liveInProduction,
        "/api/topic/attribute-author/request": .liveInProduction,
        "/api/topic/attribute-author/validate": .liveInProduction,
        "/api/topic/beta/graduate": .liveInProduction,
        "/api/topic/cancel": .liveInProduction,
        "/api/topic/cancel_preview": .liveInProduction,
        "/api/topic/chapter/finish": .liveInProduction,
        "/api/topic/chapter/recruit": .liveInProduction,
        "/api/topic/cover": .liveInProduction, // prefix/action segment: children served on TEST r2 5c2017eef
        "/api/topic/cover/selection": .liveInProduction,
        "/api/topic/cover/selection/current": .liveInProduction,
        "/api/topic/cover/selection/status": .liveInProduction,
        "/api/topic/cover/upload": .liveInProduction,
        "/api/topic/cover/{}/content": .liveInProduction,
        "/api/topic/create": .liveInProduction,
        "/api/topic/delete": .liveInProduction,
        "/api/topic/edit-detail": .liveInProduction,
        "/api/topic/edit-requests/read": .liveInProduction,
        "/api/topic/edit-requests/resume-post-processing": .liveInProduction,
        "/api/topic/edit-requests/submit": .liveInProduction,
        "/api/topic/host-node-answer": .liveInProduction,
        "/api/topic/info-to-merchant": .liveInProduction,
        "/api/topic/info-to-user": .liveInProduction,
        "/api/topic/like": .liveInProduction,
        "/api/topic/like_list": .liveInProduction,
        "/api/topic/list": .liveInProduction,
        "/api/topic/merchant-recruitment-chapters": .liveInProduction,
        "/api/topic/module-preflight": .liveInProduction,
        "/api/topic/pricing/confirm": .liveInProduction,
        "/api/topic/pricing/preview": .liveInProduction,
        "/api/topic/publish-check": .liveInProduction,
        "/api/topic/publish-status": .liveInProduction,
        "/api/topic/report": .liveInProduction,
        "/api/topic/state-keys": .liveInProduction,
        "/api/topic/transfer-to-club": .liveInProduction,
        "/api/topic/update": .liveInProduction,
        "/api/topic/update_user_status": .liveInProduction,
        "/api/topic/v2/create": .liveInProduction,
        "/api/topic/v2/update": .liveInProduction,
        "/api/topic/xp-budget": .liveInProduction,
        "/api/ugc/block": .liveInProduction,
        "/api/us/auth/apple/challenges": .liveInProduction,
        "/api/us/auth/apple/exchange": .liveInProduction,
        "/api/us/auth/session": .liveInProduction,
        "/api/user/address/": .liveInProduction,
        "/api/user/address/action": .liveInProduction,
        "/api/user/address/delete": .liveInProduction,
        "/api/user/address/info": .liveInProduction,
        "/api/user/address/list": .liveInProduction,
        "/api/user/address/setDefault": .liveInProduction,
        "/api/user/balance/list": .liveInProduction,
        "/api/user/deregister/": .liveInProduction,
        "/api/user/deregister/apply": .liveInProduction,
        "/api/user/deregister/cancel": .liveInProduction,
        "/api/user/deregister/precheck": .liveInProduction,
        "/api/user/deregister/status": .liveInProduction,
        "/api/user/follow-list": .liveInProduction,
        "/api/user/follow/action": .liveInProduction,
        "/api/user/info": .liveInProduction,
        "/api/user/invite_list": .liveInProduction,
        "/api/user/list": .liveInProduction,
        "/api/user/nickname/check": .liveInProduction,
        "/api/user/nickname/suggest": .liveInProduction,
        "/api/user/points/list": .liveInProduction,
        "/api/user/points/statistics": .liveInProduction,
        "/api/user/profile/review": .liveInProduction,
        "/api/user/public-info": .liveInProduction,
        "/api/user/setInviter": .liveInProduction,
        "/api/user/sms/send": .liveInProduction,
        "/api/user/update": .liveInProduction,
        "/api/userInfo": .liveInProduction,
        "/api/v1/community/appeals": .liveInProduction,
        "/api/v1/community/capabilities": .liveInProduction,
        "/api/v1/community/comments/{}/actions": .liveInProduction,
        "/api/v1/community/drafts": .liveInProduction,
        "/api/v1/community/feeds/{}": .liveInProduction,
        "/api/v1/community/guidelines/ack": .liveInProduction,
        "/api/v1/community/guidelines/active": .liveInProduction,
        "/api/v1/community/me/enforcements": .liveInProduction,
        "/api/v1/community/media/register": .liveInProduction,
        "/api/v1/community/notification-preferences": .liveInProduction,
        "/api/v1/community/notifications": .liveInProduction,
        "/api/v1/community/notifications/{}/read": .liveInProduction,
        "/api/v1/community/posts": .liveInProduction,
        "/api/v1/community/posts/{}": .liveInProduction,
        "/api/v1/community/posts/{}/actions": .liveInProduction,
        "/api/v1/community/posts/{}/comments": .liveInProduction,
        "/api/v1/community/posts/{}/comments/{}": .liveInProduction,
        "/api/v1/community/posts/{}/comments/{}/approve": .liveInProduction,
        "/api/v1/community/posts/{}/location": .liveInProduction,
        "/api/v1/community/posts/{}/publish": .liveInProduction,
        "/api/v1/community/posts/{}/revisions": .liveInProduction,
        "/api/v1/community/reference-options/{}": .liveInProduction,
        "/api/v1/community/reports": .liveInProduction,
        "/api/verify/citynode/issue": .liveInProduction,
        "/api/verify/citynode/receipt": .liveInProduction,
        "/api/verify/citynode/redeem": .liveInProduction,
        "/api/verify/dyncode/issue": .liveInProduction,
        "/api/verify/groupcode/issue": .liveInProduction,
        "/api/verify/groupcode/redeem": .liveInProduction,
        "/api/wallet/stages": .liveInProduction,
        "/api/welcome-screen/get": .liveInProduction,
        "/api/withdrawal/create": .liveInProduction,
        "/api/withdrawal/list": .liveInProduction,
        "/api/workshop/creator/pending-packages": .missing, // intentionally closed on the backend: `ApiAppGapsWorkshopController` OFF stub (`WORKSHOP_FEATURE_NOT_ENABLED`), 2/2 routes; GET 
        "/api/workshop/creator/pending-packages/": .missing, // intentionally closed on the backend: `ApiAppGapsWorkshopController` OFF stub (`WORKSHOP_FEATURE_NOT_ENABLED`), 2/2 routes; GET 
        "/api/workshop/creator/public-theme-use": .missing, // intentionally closed on the backend: `ApiAppGapsWorkshopController` OFF stub (`WORKSHOP_FEATURE_NOT_ENABLED`), 2/2 routes; GET 
        "/api/workshop/creator/public-theme-use/": .missing, // intentionally closed on the backend: `ApiAppGapsWorkshopController` OFF stub (`WORKSHOP_FEATURE_NOT_ENABLED`), 2/2 routes; GET 
        "/api/workshop/owned": .liveInProduction, // prefix/action segment: children served on TEST r2 5c2017eef
        "/api/workshop/owned/": .liveInProduction, // prefix/action segment: children served on TEST r2 5c2017eef
        "/api/workshop/owned/detail": .liveInProduction,
        "/api/workshop/owned/list": .liveInProduction,
        "/api/workshop/owned/package": .liveInProduction,
        "/api/workshop/purchased/detail": .liveInProduction,
        "/api/workshop/purchased/install": .liveInProduction, // prefix/action segment: children served on TEST r2 5c2017eef
        "/api/workshop/purchased/install/": .liveInProduction, // prefix/action segment: children served on TEST r2 5c2017eef
        "/api/workshop/purchased/installed-text/detail": .liveInProduction,
        "/api/workshop/purchased/list": .liveInProduction,
        "/api/workshop/purchased/professional-operations/cancel": .liveInProduction,
        "/api/workshop/purchased/professional-operations/history": .liveInProduction,
        "/api/workshop/purchased/professional-operations/status": .liveInProduction,
        "/api/workshop/purchased/professional-operations/submit": .liveInProduction,
        "/api/workshop/purchased/professional-targets/detail": .liveInProduction,
        "/api/workshop/purchased/professional-targets/list": .liveInProduction,
        "/api/workshop/v2/purchased/detail": .liveInProduction,
        "/api/workshop/v2/purchased/list": .liveInProduction,
    ]

    private static let wiredPatterns: Set<String> = [
        "/api/activity/cancel",
        "/api/activity/cancel_preview",
        "/api/activity/delete",
        "/api/activity/info",
        "/api/activity/list",
        "/api/activity/publish",
        "/api/activity/update",
        "/api/activity/update_publish_status",
        "/api/ai/club/design",
        "/api/ai/merchant/insight",
        "/api/ai/npc/chat/data/delete",
        "/api/ai/npc/chat/data/export",
        "/api/ai/npc/merchant-chat",
        "/api/ai/npc/shop-chat",
        "/api/ai/npc/voice-chat",
        "/api/ai/safety/precheck",
        "/api/ai/template/fill",
        "/api/ai/theme/draft",
        "/api/ai/theme/draft/quota",
        "/api/ai/theme/draft/request",
        "/api/badge/wall-v2",
        "/api/balance/list",
        "/api/capsules/create",
        "/api/capsules/delete",
        "/api/capsules/detail",
        "/api/capsules/list",
        "/api/capsules/receipt",
        "/api/category/list",
        "/api/circle-theme/instance/review",
        "/api/circle-theme/instance/{}/offers",
        "/api/circle-theme/session",
        "/api/circle-theme/session/join",
        "/api/circle-theme/session/{}/card",
        "/api/city/nodes",
        "/api/city/nodes/{}",
        "/api/city/nodes/{}/complete",
        "/api/city/nodes/{}/favorite",
        "/api/club-compensation/editions",
        "/api/club-compensation/hours/report",
        "/api/club/access/me",
        "/api/club/badge/create",
        "/api/club/badge/grant",
        "/api/club/badge/list",
        "/api/club/become-leader",
        "/api/club/calendar/sessions",
        "/api/club/chat",
        "/api/club/create",
        "/api/club/crm/checkin/detail",
        "/api/club/crm/customers/count",
        "/api/club/crm/customers/detail",
        "/api/club/crm/customers/list",
        "/api/club/crm/customers/tag-remark",
        "/api/club/crm/topic-customers",
        "/api/club/crm/topic-manage-stats",
        "/api/club/detail",
        "/api/club/dissolution-blockers",
        "/api/club/dissolve",
        "/api/club/event-notification/audience-counts",
        "/api/club/event-notification/preview",
        "/api/club/event-notification/retry",
        "/api/club/event-notification/send",
        "/api/club/event-notification/status",
        "/api/club/event-ops/attendance/correct",
        "/api/club/event-ops/cancel",
        "/api/club/event-ops/occurrence/status",
        "/api/club/event-ops/roster",
        "/api/club/event-ops/series/create",
        "/api/club/event-ops/series/detail",
        "/api/club/event-ops/series/list",
        "/api/club/event-ops/series/occurrences",
        "/api/club/event-ops/series/update-future",
        "/api/club/event-ops/topics",
        "/api/club/event-ops/waitlist/cancel",
        "/api/club/event-ops/waitlist/join",
        "/api/club/event-ops/waitlist/status",
        "/api/club/governance/ban",
        "/api/club/governance/cases/appeal",
        "/api/club/governance/cases/mine",
        "/api/club/governance/cases/report",
        "/api/club/governance/list",
        "/api/club/governance/owner/transfer",
        "/api/club/governance/unban",
        "/api/club/home",
        "/api/club/join",
        "/api/club/join-request/approve",
        "/api/club/join-request/reject",
        "/api/club/join-requests",
        "/api/club/lead/arrive",
        "/api/club/lead/broadcast",
        "/api/club/lead/edit-ops",
        "/api/club/lead/settle",
        "/api/club/lead/start",
        "/api/club/lead/team-progress",
        "/api/club/lead/unlock-chapter",
        "/api/club/lead/unlock-chapter-receipt",
        "/api/club/leaderboard",
        "/api/club/list",
        "/api/club/members",
        "/api/club/merchants",
        "/api/club/my",
        "/api/club/open-settings/member-post",
        "/api/club/open-settings/merchant-coop",
        "/api/club/open-settings/public-visible",
        "/api/club/open-settings/welcome-note",
        "/api/club/post/comment/create",
        "/api/club/post/comment/delete",
        "/api/club/post/comment/list",
        "/api/club/post/comment/report",
        "/api/club/post/create",
        "/api/club/post/delete",
        "/api/club/post/feed",
        "/api/club/post/history",
        "/api/club/post/like",
        "/api/club/post/like-state",
        "/api/club/post/list",
        "/api/club/post/pin",
        "/api/club/post/report",
        "/api/club/post/repost",
        "/api/club/post/repost/undo",
        "/api/club/post/update",
        "/api/club/quit",
        "/api/club/recruit/overview",
        "/api/club/remove-member",
        "/api/club/roles/assign",
        "/api/club/roles/list",
        "/api/club/roles/revoke",
        "/api/club/set-member-role",
        "/api/club/settlement/summary",
        "/api/club/topic-node-answer",
        "/api/club/topic-registrations",
        "/api/club/topic-setting/detail",
        "/api/club/topic-setting/end",
        "/api/club/topic-setting/save",
        "/api/club/topics",
        "/api/club/update-mine",
        "/api/comment/add",
        "/api/comment/delete",
        "/api/comment/like",
        "/api/comment/list",
        "/api/comment/report",
        "/api/common/banner",
        "/api/common/dict",
        "/api/common/infomation_detail",
        "/api/common/infomation_list",
        "/api/common/uploadOSS",
        "/api/community-trust/reports/mine",
        "/api/community-trust/reports/submit",
        "/api/community-trust/reports/taxonomy",
        "/api/community-trust/reports/{}",
        "/api/compliance/consents",
        "/api/compliance/consents/latest",
        "/api/config/features",
        "/api/content-draft/delete",
        "/api/content-draft/list",
        "/api/content-draft/publish",
        "/api/content-draft/restore",
        "/api/content-draft/save",
        "/api/coop/candidates",
        "/api/coop/candidates/confirm",
        "/api/coop/candidates/received",
        "/api/coop/complaint/mine",
        "/api/coop/complaint/report",
        "/api/coop/complaint/topics",
        "/api/coop/contact",
        "/api/coop/credit",
        "/api/coop/deposit/create",
        "/api/coop/deposit/create/app",
        "/api/coop/deposit/refund/retry",
        "/api/coop/deposit/status",
        "/api/coop/finance",
        "/api/coop/handle",
        "/api/coop/invite",
        "/api/coop/invite/read",
        "/api/coop/invite/request",
        "/api/coop/invite/requests",
        "/api/coop/list",
        "/api/coop/mybiz",
        "/api/coop/offer/circle-supply/pause",
        "/api/coop/offer/circle-supply/reconfirm",
        "/api/coop/offer/circle-supply/reconfirm-current",
        "/api/coop/offer/enroll",
        "/api/coop/offer/withdraw",
        "/api/coop/perk-template/delete",
        "/api/coop/perk-template/list",
        "/api/coop/perk-template/save",
        "/api/coop/perks/attach",
        "/api/coop/perks/list",
        "/api/coop/pool/apply",
        "/api/coop/pool/decline",
        "/api/coop/pool/list",
        "/api/coop/pool/mine",
        "/api/coop/pool/received",
        "/api/coop/pool/withdraw",
        "/api/coop/review/save",
        "/api/coop/review/summary",
        "/api/coop/supply-stations",
        "/api/coupon/mypublishlist",
        "/api/coupon/myrecvlist",
        "/api/coupon/publish",
        "/api/coupon/qr-token",
        "/api/coupon/status",
        "/api/coupon/stop",
        "/api/coupon/verification",
        "/api/creativesquare/action",
        "/api/creativesquare/bookmark",
        "/api/creativesquare/info",
        "/api/creativesquare/like",
        "/api/creativesquare/list",
        "/api/creativesquare/report",
        "/api/creator/apply",
        "/api/creator/center",
        "/api/exploration-anniversary",
        "/api/exploration-goals/cancel",
        "/api/exploration-goals/create",
        "/api/exploration-goals/detail",
        "/api/exploration-goals/list",
        "/api/exploration-goals/receipt",
        "/api/free-explore/bundle/catalog",
        "/api/free-explore/bundle/exit-decision",
        "/api/free-explore/bundle/exit-options",
        "/api/free-explore/bundle/merchant/reservation/{}/no-show",
        "/api/free-explore/bundle/merchant/reservations",
        "/api/free-explore/bundle/order",
        "/api/free-explore/bundle/order/receipt",
        "/api/free-explore/bundle/order/refund-quote",
        "/api/free-explore/bundle/reservation",
        "/api/friend/accept",
        "/api/friend/cancel",
        "/api/friend/list",
        "/api/friend/receipt",
        "/api/friend/reject",
        "/api/friend/relationship",
        "/api/friend/request",
        "/api/friend/requests",
        "/api/free-explore/bundle/reservation/receipt",
        "/api/free-explore/bundle/reservation/{}/cancel",
        "/api/free-explore/bundle/reservation/{}/cancel-quote",
        "/api/game/session/command",
        "/api/game/session/merchant/entries",
        "/api/game/session/recap/export",
        "/api/game/session/receipt",
        "/api/game/session/shared/control",
        "/api/game/session/shared/export",
        "/api/game/session/shared/export/anchor",
        "/api/game/session/shared/preview",
        "/api/game/session/view",
        "/api/growth/center",
        "/api/growth/leaderboard",
        "/api/im/block",
        "/api/im/conversations",
        "/api/im/delete",
        "/api/im/ingame/resolve",
        "/api/im/ingame/summary",
        "/api/im/messages",
        "/api/im/mute",
        "/api/im/poll/close",
        "/api/im/poll/create",
        "/api/im/poll/result",
        "/api/im/poll/vote",
        "/api/im/read",
        "/api/im/report",
        "/api/im/send",
        "/api/im/send-receipt",
        "/api/im/start",
        "/api/im/unblock",
        "/api/im/unread-total",
        "/api/invoice/apply",
        "/api/invoice/cancel",
        "/api/invoice/detail",
        "/api/invoice/list",
        "/api/invoice/orders/eligible",
        "/api/invoice/request",
        "/api/invoice/titles",
        "/api/invoice/titles/delete",
        "/api/invoice/titles/request",
        "/api/invoice/titles/save",
        "/api/invoice/titles/save-request",
        "/api/login/apple",
        "/api/login/phone",
        "/api/login/wechat/app",
        "/api/logout",
        "/api/map/nearby",
        "/api/map/reverse-geocode",
        "/api/medal/wall",
        "/api/media/asset/list",
        "/api/media/asset/{}",
        "/api/media/asset/{}/preview",
        "/api/member/reputation",
        "/api/merchant/access/me",
        "/api/merchant/aftercare/detail",
        "/api/merchant/aftercare/list",
        "/api/merchant/aftercare/respond",
        "/api/merchant/business-status",
        "/api/merchant/business-status/update",
        "/api/merchant/chapter-application/apply",
        "/api/merchant/chapter-application/audit",
        "/api/merchant/chapter-application/invitable",
        "/api/merchant/chapter-application/invite",
        "/api/merchant/chapter-application/invite/respond",
        "/api/merchant/chapter-application/mine",
        "/api/merchant/chapter-application/owner-list",
        "/api/merchant/chapter-application/owner-mine",
        "/api/merchant/chapter-application/withdraw",
        "/api/merchant/chapter-node/audit",
        "/api/merchant/chapter-node/live-checkin-code",
        "/api/merchant/chapter-node/mine",
        "/api/merchant/chapter-node/npc/detail",
        "/api/merchant/chapter-node/npc/save",
        "/api/merchant/chapter-node/npc/voice/enroll",
        "/api/merchant/chapter-node/npc/voice/reset",
        "/api/merchant/chapter-node/npc/voice/status",
        "/api/merchant/chapter-node/pending",
        "/api/merchant/chapter-node/poster-code",
        "/api/merchant/chapter-node/submit",
        "/api/merchant/city-node/claim",
        "/api/merchant/city-node/claim/cancel",
        "/api/merchant/city-node/claimable",
        "/api/merchant/city-node/list",
        "/api/merchant/city-node/offline",
        "/api/merchant/city-node/poster-code",
        "/api/merchant/city-node/save",
        "/api/merchant/city-node/template/submit",
        "/api/merchant/clubs",
        "/api/merchant/commerce/capabilities",
        "/api/merchant/coop-profile",
        "/api/merchant/coop-profile/save",
        "/api/merchant/crm/broadcast",
        "/api/merchant/crm/broadcast/preview",
        "/api/merchant/crm/campaigns",
        "/api/merchant/crm/campaigns/coupons",
        "/api/merchant/crm/campaigns/preview",
        "/api/merchant/crm/campaigns/{}",
        "/api/merchant/crm/customers/list",
        "/api/merchant/crm/customers/tags/batch",
        "/api/merchant/crm/customers/{}/contact",
        "/api/merchant/crm/customers/{}/detail",
        "/api/merchant/crm/customers/{}/notes",
        "/api/merchant/crm/customers/{}/notes/hide",
        "/api/merchant/crm/customers/{}/tags",
        "/api/merchant/crm/customers/{}/tags/remove",
        "/api/merchant/crm/exports",
        "/api/merchant/crm/exports/{}/download",
        "/api/merchant/crm/exports/{}/status",
        "/api/merchant/crm/marketing-consents",
        "/api/merchant/crm/segments",
        "/api/merchant/dashboard",
        "/api/merchant/decor/save",
        "/api/merchant/desk/anchor",
        "/api/merchant/desk/anchor/save",
        "/api/merchant/desk/products",
        "/api/merchant/desk/products/detail",
        "/api/merchant/desk/products/sku/save",
        "/api/merchant/desk/receipt",
        "/api/merchant/desk/stores",
        "/api/merchant/events",
        "/api/merchant/finance/overview",
        "/api/merchant/finance/public-transfer-batch-detail",
        "/api/merchant/finance/public-transfer-batches",
        "/api/merchant/finance/redemption-detail",
        "/api/merchant/finance/redemptions",
        "/api/merchant/finance/settlement-entries",
        "/api/merchant/info",
        "/api/merchant/list",
        "/api/merchant/marketing-home",
        "/api/merchant/merchant_registration",
        "/api/merchant/nearby",
        "/api/merchant/npc/profile",
        "/api/merchant/npc/save",
        "/api/merchant/npc/voice/enroll",
        "/api/merchant/npc/voice/reset",
        "/api/merchant/npc/voice/status",
        "/api/merchant/operators/invite",
        "/api/merchant/operators/invite/accept",
        "/api/merchant/operators/invite/revoke",
        "/api/merchant/operators/list",
        "/api/merchant/operators/remove",
        "/api/merchant/operators/role",
        "/api/merchant/operators/roles",
        "/api/merchant/orders",
        "/api/merchant/predict/inbox",
        "/api/merchant/predict/settle",
        "/api/merchant/public-detail",
        "/api/merchant/public-home",
        "/api/merchant/relation-home",
        "/api/merchant/reviews/create",
        "/api/merchant/reviews/manage",
        "/api/merchant/reviews/public",
        "/api/merchant/reviews/reply/receipt",
        "/api/merchant/reviews/report",
        "/api/merchant/subscription",
        "/api/merchant/todo-summary",
        "/api/merchant/upcoming-runs",
        "/api/merchant/update",
        "/api/merchant/verification-records",
        "/api/monthly-recap",
        "/api/object-card/list",
        "/api/official/broadcast",
        "/api/official/broadcast/{}/click",
        "/api/official/broadcast/{}/stats",
        "/api/official/can-publish",
        "/api/official/command",
        "/api/official/command/cancel",
        "/api/official/command/query",
        "/api/official/events",
        "/api/official/events/{}",
        "/api/official/events/{}/arrivals",
        "/api/official/events/{}/complete",
        "/api/official/events/{}/signup",
        "/api/official/invites",
        "/api/official/merchant-invites",
        "/api/official/my-events",
        "/api/official/my-published",
        "/api/official/publish",
        "/api/official/v2/events/{}/publish-check",
        "/api/official/v2/parties/{}/{}",
        "/api/official/v2/party-inbox",
        "/api/orient/safety/check",
        "/api/orient/scoring/appeal",
        "/api/orient/scoring/dispute",
        "/api/orient/scoring/mine",
        "/api/orient/scoring/receipt",
        "/api/orient/scoring/session/{}",
        "/api/orient/scoring/session/{}/leaderboard",
        "/api/orient/scoring/session/{}/settle",
        "/api/orient/scoring/session/{}/sync",
        "/api/orient/task/alternative/receipt",
        "/api/orient/task/alternative/submit",
        "/api/orient/task/state",
        "/api/orient/team/detail",
        "/api/orient/team/lobby",
        "/api/orient/team/ranking",
        "/api/personal-exploration-export/page",
        "/api/personal-exploration-export/prepare",
        "/api/play/achievements",
        "/api/play/action-context",
        "/api/play/action-receipt",
        "/api/play/advanced/action",
        "/api/play/advanced/leaderboard",
        "/api/play/advanced/receipt",
        "/api/play/advanced/start",
        "/api/play/advanced/state",
        "/api/play/answer",
        "/api/play/arrive",
        "/api/play/character",
        "/api/play/check/bargain",
        "/api/play/check/momentum",
        "/api/play/check/receipt",
        "/api/play/check/reroll",
        "/api/play/check/rest",
        "/api/play/check/roll",
        "/api/play/check/settle",
        "/api/play/checkin",
        "/api/play/companionLine",
        "/api/play/contact",
        "/api/play/encounter",
        "/api/play/ending",
        "/api/play/growth",
        "/api/play/help",
        "/api/play/help/advanced/receipt",
        "/api/play/help/receipt",
        // Owner-approved non-money player writes (2026-11-12): hint ladder use and skip, H8.
        "/api/play/help/skip",
        "/api/play/help/use",
        "/api/play/hint/unlock",
        "/api/play/journey/ask",
        "/api/play/journey/backpack",
        "/api/play/journey/call",
        "/api/play/journey/casebook",
        "/api/play/journey/ending",
        "/api/play/journey/opening/complete",
        "/api/play/journey/stage-end",
        "/api/play/journey/thought/sync",
        "/api/play/leaderboard",
        "/api/play/my-completed",
        "/api/play/nodes",
        "/api/play/orient/session",
        "/api/play/orient/session/abandon",
        "/api/play/orient/session/current",
        "/api/play/orient/session/prepare",
        "/api/play/orient/session/receipt",
        "/api/play/orient/session/start",
        "/api/play/orient/session/task/{}/result",
        "/api/play/os/{}",
        "/api/play/photo",
        "/api/play/preference/{}",
        "/api/play/preference/{}/submit",
        "/api/play/puzzle/hint",
        "/api/play/puzzle/reveal",
        "/api/play/route-state",
        "/api/play/rpg/status",
        "/api/play/run-session",
        "/api/play/run-session/clear",
        "/api/play/run-session/list",
        "/api/play/run-session/save",
        "/api/play/scan-entry",
        "/api/play/sensor-result",
        "/api/play/setup",
        "/api/play/tag/{}/confirm",
        "/api/play/tag/{}/correct",
        "/api/play/tag/{}/revoke",
        "/api/play/theme/action",
        "/api/play/theme/card",
        "/api/play/theme/gameplay-action",
        "/api/play/theme/gameplay-preview",
        "/api/play/theme/history",
        "/api/play/theme/replay",
        "/api/play/theme/state",
        "/api/play/theme/support-matrix",
        "/api/points/list",
        "/api/points/result_list",
        "/api/preset/route/info",
        "/api/preset/route/list",
        "/api/project/home",
        "/api/project/my",
        "/api/project/players",
        "/api/publish/home",
        "/api/publisher/identity",
        "/api/publisher/identity/status",
        "/api/registration/cancel",
        "/api/registration/cancel-by-owner",
        "/api/registration/cancel-refund",
        "/api/registration/count_by_date",
        "/api/registration/create",
        "/api/registration/explore-completion",
        "/api/registration/info",
        "/api/registration/list",
        "/api/registration/merchant/cancel",
        "/api/registration/merchant/create",
        "/api/registration/merchant/info",
        "/api/registration/merchant/list",
        "/api/registration/merchant/select",
        "/api/registration/merchant/update",
        "/api/registration/my-joined",
        "/api/registration/quote",
        "/api/registration/scan_dynamic_code",
        "/api/registration/scan_qr_code",
        "/api/registration/scan_qr_code_chapter",
        "/api/registration/scan_qr_code_station",
        "/api/roam/badge/shop-streak",
        "/api/roam/checkin",
        "/api/roam/entry/nearby",
        "/api/roam/finish",
        "/api/roam/hangout/nearby",
        "/api/roam/nearby-exploreday",
        "/api/roam/nearby-runners",
        "/api/roam/passport/history",
        "/api/roam/passport/record",
        "/api/roam/passport/summary",
        "/api/roam/poi/discover",
        "/api/roam/pois",
        "/api/roam/presence",
        "/api/roam/presence-visibility",
        "/api/roam/reveal",
        "/api/roam/session",
        "/api/roam/share/snapshot",
        "/api/roam/shop/visit",
        "/api/roam/stamp/create",
        "/api/roam/stamp/exchange",
        "/api/roam/stamp/list",
        "/api/roam/stamp/received",
        "/api/roam/tiles",
        "/api/roam/tiles/page",
        "/api/role/info",
        "/api/sms/send",
        "/api/stats/club",
        "/api/team/applications",
        "/api/team/apply",
        "/api/team/command",
        "/api/team/command/cancel",
        "/api/team/command/query",
        "/api/team/create",
        "/api/team/disband",
        "/api/team/handle",
        "/api/team/info",
        "/api/team/join",
        "/api/team/join-mode",
        "/api/team/kick",
        "/api/team/my",
        "/api/team/my-applications",
        "/api/team/nearby",
        "/api/team/quit",
        "/api/team/report",
        "/api/team/withdraw",
        "/api/template/delete",
        "/api/template/draft",
        "/api/template/homeData",
        "/api/template/info",
        "/api/template/list",
        "/api/template/my-list",
        "/api/template/myinfo",
        "/api/template/personal-report",
        "/api/template/publish",
        "/api/template/report",
        "/api/template/topic-template/info",
        "/api/template/topic-template/list",
        "/api/template/topic-template/use",
        // Owner-approved non-money template adoption (2026-11-13, H1): place to-dos and image credits.
        "/api/template/topic-template/binding",
        "/api/template/topic-template/binding-status",
        "/api/media/asset/attribution",
        "/api/template/updateLibraryStatus",
        "/api/topic/beta/graduate",
        "/api/topic/cancel",
        "/api/topic/cancel_preview",
        "/api/topic/chapter/finish",
        "/api/topic/chapter/recruit",
        "/api/topic/create",
        "/api/topic/delete",
        "/api/topic/edit-detail",
        "/api/topic/host-node-answer",
        "/api/topic/info-to-merchant",
        "/api/topic/info-to-user",
        "/api/topic/like",
        "/api/topic/like_list",
        "/api/topic/list",
        "/api/topic/merchant-recruitment-chapters",
        "/api/topic/pricing/confirm",
        "/api/topic/pricing/preview",
        "/api/topic/publish-check",
        "/api/topic/report",
        "/api/topic/state-keys",
        "/api/topic/transfer-to-club",
        "/api/topic/update",
        "/api/topic/update_user_status",
        "/api/topic/v2/create",
        "/api/topic/v2/update",
        "/api/topic/xp-budget",
        "/api/user/address/action",
        "/api/user/address/delete",
        "/api/user/address/info",
        "/api/user/address/list",
        "/api/user/address/setDefault",
        "/api/user/balance/list",
        "/api/user/deregister/apply",
        "/api/user/deregister/cancel",
        "/api/user/deregister/precheck",
        "/api/user/deregister/status",
        "/api/user/follow/action",
        "/api/user/info",
        "/api/user/invite_list",
        "/api/user/list",
        "/api/user/nickname/check",
        "/api/user/nickname/suggest",
        "/api/user/points/list",
        "/api/user/points/statistics",
        "/api/user/profile/review",
        "/api/user/public-info",
        "/api/user/setInviter",
        "/api/user/update",
        "/api/userInfo",
        "/api/v1/community/appeals",
        "/api/v1/community/capabilities",
        "/api/v1/community/comments/{}/actions",
        "/api/v1/community/drafts",
        "/api/v1/community/feeds/{}",
        "/api/v1/community/guidelines/ack",
        "/api/v1/community/guidelines/active",
        "/api/v1/community/me/enforcements",
        "/api/v1/community/media/register",
        "/api/v1/community/notification-preferences",
        "/api/v1/community/notifications",
        "/api/v1/community/notifications/{}/read",
        "/api/v1/community/posts",
        "/api/v1/community/posts/{}",
        "/api/v1/community/posts/{}/actions",
        "/api/v1/community/posts/{}/comments",
        "/api/v1/community/posts/{}/comments/{}",
        "/api/v1/community/posts/{}/comments/{}/approve",
        "/api/v1/community/posts/{}/location",
        "/api/v1/community/posts/{}/publish",
        "/api/v1/community/posts/{}/revisions",
        "/api/v1/community/reference-options/{}",
        "/api/v1/community/reports",
        "/api/verify/citynode/issue",
        "/api/verify/citynode/receipt",
        "/api/verify/citynode/redeem",
        "/api/verify/dyncode/issue",
        "/api/verify/groupcode/issue",
        "/api/verify/groupcode/redeem",
        "/api/wallet/stages",
        "/api/withdrawal/list",
    ]
}

/// CB93. A closed set of missing iOS literals whose production equivalents are already
/// admitted by `ChinaReviewedRouteCapability`. This is not a route table: a path is used
/// only when `admitsChinaProductionCall` is true. Password login, bank withdrawal, and
/// virtual goods are not in the set. An empty URL is not the China host, so it adapts nothing.
public enum ChinaReviewedRouteAdaptation {
    /// `NativeChannelManagementService` treats guild kind 1 as CLUB.
    public static let clubGuildKind = 1

    public struct Route: Equatable, Sendable {
        public let missing: String
        public let production: String
        public init(missing: String, production: String) {
            self.missing = missing
            self.production = production
        }
    }

    public static let routes: [Route] = [
        .init(missing: "/api/topic/detail", production: "/api/topic/info-to-user"),
        .init(missing: "/api/club/settlements", production: "/api/club/settlement/summary"),
        .init(missing: "/api/club/update", production: "/api/club/update-mine"),
        .init(missing: "/api/join-request/submit", production: "/api/club/join"),
        .init(missing: "/api/space/leave", production: "/api/club/quit"),
    ]

    public static func productionPath(forMissing path: String) -> String? {
        let key = ChinaReviewedRouteCapability.literalKey(path)
        guard let row = routes.first(where: { $0.missing == key }) else { return nil }
        guard ChinaReviewedRouteCapability.hidingCapability(for: row.production) == nil else { return nil }
        guard ChinaReviewedRouteCapability.admitsChinaProductionCall(row.production) else { return nil }
        return row.production
    }

    /// The reviewed China host only. An empty or non-China URL returns false.
    public static func admits(missing path: String, baseURL: URL) -> Bool {
        guard ChinaReviewedRouteCapability.targetsChinaProduction(baseURL) else { return false }
        return productionPath(forMissing: path) != nil
    }

    /// Rewrites a China-host request when the body is already the production contract.
    /// Join and leave stay on `ChannelAdmissionGovernanceClient` because their bodies differ.
    /// Other hosts, including every test double, are unchanged.
    public static func adapt(_ request: URLRequest) -> URLRequest? {
        guard let url = request.url, ChinaReviewedRouteCapability.targetsChinaProduction(url),
              request.httpMethod == "POST", let relative = relativeAPIPath(url) else { return nil }
        let key = ChinaReviewedRouteCapability.literalKey(relative)
        switch key {
        case "/api/topic/detail":
            guard formIdentifier(request.httpBody) != nil, productionPath(forMissing: key) != nil else { return nil }
            return retarget(request, production: "/api/topic/info-to-user")
        case "/api/club/settlements":
            guard settlementClubID(request.httpBody) != nil, productionPath(forMissing: key) != nil else { return nil }
            return retarget(request, production: "/api/club/settlement/summary")
        case "/api/club/update":
            guard isClubUpdateBody(request.httpBody), productionPath(forMissing: key) != nil else { return nil }
            return retarget(request, production: "/api/club/update-mine")
        default:
            return nil
        }
    }

    private static let clubUpdateKeys: Set<String> = [
        "id", "name", "city", "description", "keywords", "style", "clubType",
        "activityPrefs", "logo", "cover", "joinPolicy", "operationConfigUpdated",
        "prioritySignupEnabled", "memberReservedQuota"
    ]

    private static func formIdentifier(_ body: Data?) -> String? {
        guard let body, let text = String(data: body, encoding: .utf8), !text.contains("&"),
              text.hasPrefix("id=") else { return nil }
        let value = String(text.dropFirst(3))
        guard let number = Int(value), number > 0, value == String(number) else { return nil }
        return value
    }

    private static func settlementClubID(_ body: Data?) -> Int? {
        guard let object = jsonObject(body), object.count == 1 else { return nil }
        return positiveInteger(object["clubId"])
    }

    private static func isClubUpdateBody(_ body: Data?) -> Bool {
        guard let object = jsonObject(body), Set(object.keys).isSubset(of: clubUpdateKeys),
              positiveInteger(object["id"]) != nil else { return false }
        return true
    }

    private static func jsonObject(_ body: Data?) -> [String: Any]? {
        guard let body, let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else { return nil }
        return object
    }

    private static func positiveInteger(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        let int = number.intValue
        guard int > 0, number.doubleValue == Double(int) else { return nil }
        return int
    }

    private static func retarget(_ request: URLRequest, production: String) -> URLRequest? {
        guard let base = URL(string: ReviewedMarketLaunch.chinaProductionBaseURL),
              ChinaReviewedRouteCapability.admitsChinaProductionCall(production) else { return nil }
        var copy = request
        copy.url = base.appendingPathComponent(String(production.dropFirst()))
        guard let url = copy.url, ChinaReviewedRouteCapability.admitsChinaProductionCall(url) else { return nil }
        return copy
    }

    private static func relativeAPIPath(_ url: URL) -> String? {
        guard let base = URL(string: ReviewedMarketLaunch.chinaProductionBaseURL) else { return nil }
        let basePath = trimmed(base.path)
        let path = url.path
        guard path == basePath || path.hasPrefix(basePath + "/") else { return nil }
        return String(path.dropFirst(basePath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private static func trimmed(_ path: String) -> String {
        path.count > 1 && path.hasSuffix("/") ? String(path.dropLast()) : path
    }
}

/// One Release switch per money-moving write. All four stay off. This type does not
/// choose a payment provider or a payment route.
public enum ReleaseMoneyWriteKind: String, Sendable, CaseIterable {
    case payment
    case payout
    case withdrawal
    case virtualGoods
    /// Player refund and owner cancel-refund. Owner 2026-11-24: counts as money.
    case refund
    /// Host cancel that refunds unredeemed registrations. Preview is not this kind.
    case hostCancelRefund
}

public enum ReleaseMoneyWriteSwitch {
    #if DEBUG || TEST
    /// DEBUG/TEST only (owner 2026-11-13: money ON for TEST/DEBUG). The app installs a derivation from its host-based area
    /// switch; with none installed every kind stays off. Release builds compile the constants below instead.
    nonisolated(unsafe) public static var testDerivation: (@Sendable (ReleaseMoneyWriteKind) -> Bool)?
    public static var paymentEnabled: Bool { testDerivation?(.payment) ?? false }
    public static var payoutEnabled: Bool { testDerivation?(.payout) ?? false }
    public static var withdrawalEnabled: Bool { testDerivation?(.withdrawal) ?? false }
    public static var virtualGoodsEnabled: Bool { testDerivation?(.virtualGoods) ?? false }
    public static var refundEnabled: Bool { testDerivation?(.refund) ?? false }
    public static var hostCancelRefundEnabled: Bool { testDerivation?(.hostCancelRefund) ?? false }
    #else
    public static let paymentEnabled = false
    public static let payoutEnabled = false
    public static let withdrawalEnabled = false
    public static let virtualGoodsEnabled = false
    public static let refundEnabled = false
    public static let hostCancelRefundEnabled = false
    #endif

    public static func isEnabled(_ kind: ReleaseMoneyWriteKind) -> Bool {
        switch kind {
        case .payment: return paymentEnabled
        case .payout: return payoutEnabled
        case .withdrawal: return withdrawalEnabled
        case .virtualGoods: return virtualGoodsEnabled
        case .refund: return refundEnabled
        case .hostCancelRefund: return hostCancelRefundEnabled
        }
    }

    /// True when `path` is a money-moving write and that write's own switch is on. Virtual goods never open here.
    public static func opens(_ path: String) -> Bool {
        guard let kind = kind(for: path) else { return false }
        return isEnabled(kind)
    }

    /// True when `path` is a money-moving write and that write's own switch is off.
    public static func blocks(_ path: String) -> Bool {
        guard let kind = kind(for: path) else { return false }
        return !isEnabled(kind)
    }

    /// Reads, team or offer exits, and other non-money actions return nil.
    public static func kind(for rawPath: String) -> ReleaseMoneyWriteKind? {
        let key = ChinaReviewedRouteCapability.normalized(rawPath)
        switch key {
        case "/api/registration/pay", "/api/registration/pay/app", "/api/pay/create",
            "/api/merchant/commerce/order", "/api/merchant/commerce/order/status",
            "/api/marketing/group-checkout/create", "/api/marketing/product/activate",
            "/api/marketing/product/orders/{}/pay", "/api/platform-pass/orders/{}/pay",
            "/api/external-game/orders", "/api/external-game/orders/{}/confirm-test":
            return .payment
        case "/api/club/settlement/withdraw",
             "/api/club/personal-receiver/unbind", "/api/club/personal-receiver/bind":
            return .payout
        case "/api/withdrawal/create", "/api/asset/withdraw", "/api/wallet/withdraw":
            return .withdrawal
        case "/api/cart/cart/add", "/api/cart/add", "/api/cart/update", "/api/cart/delete", "/api/cart/order/settlement":
            return .virtualGoods
        case "/api/registration/cancel-refund", "/api/registration/cancel-by-owner",
             "/api/free-explore/bundle/order/refund":
            return .refund
        case "/api/activity/cancel":
            return .hostCancelRefund
        default:
            break
        }
        if key.hasPrefix("/api/fund/preflight") { return .withdrawal }
        if key.hasPrefix("/api/mod-commerce/"),
           key.hasSuffix("/payment") || key.hasSuffix("/native-dispatch") || key.hasSuffix("/native-transaction")
            || key == "/api/mod-commerce/native-transactions/restore" || key == "/api/mod-commerce/orders" {
            return .virtualGoods
        }
        return nil
    }
}

public struct ChinaReviewedProductionTransport: HTTPTransport {
    private let underlying: any HTTPTransport

    public init(underlying: any HTTPTransport) {
        self.underlying = underlying
    }

    public func send(_ request: URLRequest) async throws -> (Data, Int) {
        let outgoing = ChinaReviewedRouteAdaptation.adapt(request) ?? request
        try ChinaReviewedRouteCapability.refuseUnwiredChinaProduction(outgoing)
        do {
            return try await underlying.send(outgoing)
        } catch {
            if OfflineIdempotentWriteQueue.isPreSendUnreachable(error) {
                OfflineWriteCaptureContext.current?.recordIfPreSendOffline(request: outgoing, error: error)
            }
            throw error
        }
    }
}

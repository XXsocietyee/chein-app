# cursor/r8-wire

Base SHA: `f95850a46d846b2884841fd83483a164ccf224ef`.
`App/AppCompositionRoot.swift` stays 4177 lines. `App/AppSession.swift` stays 8171 lines.
String keys are in `Resources/Localizable.xcstrings` and `docs/port/strings/cursor-r8-wire.json` (`en` and `zh-Hans`).
No `swiftc`. Money paths still send nothing. `giftClaim` is untouched. `PlayStageAnalyticsGate.enabled` stays false. Settlement, payout, and withdrawal stay off.

`cursor/r8-player-content` is not on this SHA. Call sites that need types from that branch are left.

## Wired

| Site | File |
|---|---|
| Platform-code row when `ChannelRedeemSource.status` is true; `mode=code` page calls `redeemPlatformCode` (max 64, six result keys, 去玩). Gift claim is not this path. | `App/MPParityKit.swift`, `App/MPParityPassSession.swift`, `App/PassMarketViews.swift` |
| Pass cancel / confirm / refund-apply call `send*` only when `PlatformPass.orderWriteEnabled` is true for that kind. The default still hits the throwing methods and sends nothing. | `App/PassMarketViews.swift` |
| Order cover, team / seats / club, follow `POST /api/user/follow/action`, marketing-consent row via `ProfileOrderConsentOffer.pick`, settlement rows when `show` is true, party text, wallet-expired. | `App/ProfileOrdersView.swift`, `App/ProfileOrderSourceDetailSections.swift` |
| Companion cards from `WalletSeatInvitationSource.load`. Failed read shows nothing. Wallet-wide `ticketWallet.teams` section removed. | `App/TicketWalletView.swift` |
| No-game ticket (`hasGame == false`, ready, not cleared, not locked) presents the pass. Play button stays behind `hasGame`. | `App/TicketWalletDetailView.swift` |
| Participation cover prefers `templateBannerURL`, then the record cover. | `App/PlayerJourneyViews.swift` |
| Dispute entry uses `score.canDispute` and shows `disputeWindowDeadline`. Sync and settle stay off. | `App/OrientScoreReviewSection.swift` |
| Free-explore failure title prefers the server message. A store with `available == false` still shows, with 暂未开售. | `App/FreeExploreTopicCatalogScreen.swift` |
| Template shelf keyword field removed. The page stays. Refresh still uses an empty keyword. | `App/TemplateAuthoringMineView.swift` |
| Avatar dependencies on the settings profile editor and the public-profile self-edit access. | `App/ProfileSettingsProfileRoute.swift`, `App/ProfileSelfEditAccess.swift`, `App/AccountView.swift` |
| Cancellation sheet calls `noteSignedOut()` when the cancellation intent is nil, and the fresh-login empty state has a sign-in action. Denied copy was already the fragment keys. | `App/AccountComplianceViews.swift` |
| Presence read via `readPresence` on the latest local roam `serverSessionID`. `false` hides the off control. Nil or true keeps it. Disable is still the only write. | `App/AppSession+MemberPopups.swift`, `App/SettingsPrivacyLocationView.swift` |
| Signed-out viewer who already agreed locally sees `UsageConsentOfflineRecord.signedOutCopy`. | `App/UsageConsentGateView.swift` |
| Desk manual-code gate is `.live`. Resolve still does not redeem. | `App/QuestifyApp.swift` |
| Merchant events admit JSON `{}` and an empty `application/x-www-form-urlencoded; charset=utf-8` body. A POST with no content type stays rejected. | `App/AppCompositionRoot.swift`, `App/ReviewedMerchantWorkbenchReadRoute.swift` |
| Business-status save admits one form field `business_status=<int>`. JSON business-status stays rejected. NPC `personality` was not added. | `App/AppCompositionRoot.swift`, `App/ReviewedMerchantWorkbenchReadRoute.swift` |
| Roster row dials `ClubRosterMember.phone` with `tel:`. | `App/ClubRosterBucketContent.swift` |
| Role picker avatar uses `avatarURL`, and a missing URL still falls back to `d_profile`. | `App/ClubRoleAssignmentPicker.swift` |
| Topic merchant row shows `contactText` and copies `phone`. | `App/ClubTopicMerchantContent.swift` |
| Unused `ClubDetailOverviewFactsGridView` removed. Core `ClubDetailOverviewFactsGrid` stays. | `App/ClubDetailTabBar.swift` |
| Stamp camera exchange closure follows `RoamExperienceCapabilities.stampExchange` (already true) into `exchangeStamp`. The city-stamp dormant line is hidden while that flag is on. Album capture stays off. | `App/SessionRoamMediaViews.swift`, `App/RoamSubpageParityViews.swift` |
| `nearby.activeCount` label removed. The stat row under it stays. | `App/NearbyTeamViews.swift` |
| Finish-offer card tracks `finish_offer_shown` on appear and `finish_offer_click` on tap through `offer.trackPayload` and the existing analytics client. The stage gate stays off. Purchase stays gated. | `App/JourneyReportViews.swift` |

## Left

| Site | Why |
|---|---|
| `ActivityDetailAccess.cancelled` arm and `ActivityDetailFailure.notFound` | Those cases are not on this SHA. Adding the arm would not compile. `ActivityCancelledStateView` stays unmounted. |
| Player-content: `PlayerOrientSafetyDecision`, `allMissing`, `footCopy`, `organizerShopLogo`, `informationCopyText`, `canRecoverInapp`, chapter `locked`, pricing `productType == 2` hide, publisher latitude/longitude pin, leaderboard chip, official template flag, like-controller retarget, self-play create | Core types or the grant live on `cursor/r8-player-content`, which is not this tip. Quote, registration create, and pricing confirm still send nothing. |
| Gift claim, pay, refund execution, payout, withdrawal, paid registration, quote | Money stays off. `giftClaim` still throws `moneyOff`. |
| Platform-pass writes when the TEST derivation is off | Default sends nothing. |
| Settlement predict locks, review report, station, saveSku | Core receipts left those gates off. |
| Store-character writer / `reviewText` on the live hero | Giving the live screen a writer can enroll. Left off. |
| Coop center tab/topic, nearby merchant cover/logo/hours/capacity | Not mounted. No new file (pbxproj stays untouched). |
| City-node submit, template `from`/`scope`, support phase, merchant home probe, share `poi`/`clubHub`, participant phone, crop retry/reset, ticket summary, per-ticket times, square medals, team avatars, mode-switch copy | Still no App caller that can be added without a new screen or an `AppSession` line. `cityNodeSubmitPath` / `cityNodeBody` stay unused. |
| Club scan, settlement range bar, event capacity/`offerWindowText`, event hub actions, `httpsURL` share, paid registration payload, payout reads, withdraw support disable, group-code issue body, enroll `api/club/my`, one-club `resolveEntry`, merchant-apply vs home | Not mounted on the live screens. `httpsURL()` is still nil with no verified origin, so no host was invented. Withdrawal still sends nothing. |
| Stamp-exchange coordinator on `SessionRoamCityStampFlowView` | `RoamStampExchangeCoordinator` is still only built in tests. The camera path calls `exchangeStamp`. The flow page no longer shows the dormant line while the flag is on, and it still does not send without a coordinator. |
| Roam passport thumbnails, recruiting-team apply, nearby runners, map/BGM/narration/fog preferences, seat phone transfer, badge wall grid, object-card category sheet, remote stamp images | Not wired. `allowsRemoteImages` stays false. `CastRosterButton` stays unmounted. Seat gift claim stays off. |

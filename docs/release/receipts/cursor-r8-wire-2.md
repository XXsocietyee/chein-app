# cursor/r8-wire-2

Base SHA: `6afe54b4acee8786a9f3f3cbe8cd85d90be1e35a`. Cut from that commit. If `origin/ui/combined-r7` moves, this branch stays there.

`App/AppSession.swift` stays 8171 lines. `App/AppCompositionRoot.swift` stays 4177 lines. `tools/check_appsession_ratchet.py` ceilings were not raised. New glue is in existing files (`PlayRuntimeGapProduction.swift`, `TopicFavoriteHost.swift`), not those two.

No `swiftc`. `project.pbxproj` was not edited. Money stays off. Quote, registration create, and pricing confirm send nothing. `pricingGrantEnabled` stays false.

`activity.detail.missing` was already in `docs/port/strings/cursor-r8-player-content.json` (`en` “Activity not found”, `zh-Hans` “活动不存在”). No second fragment. `ActivityDetailView` already had one `.cancelled(canViewOwnOrders:)` arm with `ActivityCancelledStateView`. A second arm was not added.

These compile fixes were left as they are on this SHA:

- `ActivityService.swift` keeps `try` leading the `||` expression.
- `ProfileOrdersView` keeps `OrderCoverTile(url:size:)`.
- Wallet quick actions keep the `destination:` label.

## Wired

| Site | Where |
|---|---|
| Play entry calls `checkOrientSafety` and branches on `PlayerOrientSafetyDecision`. Proceed closes the prep sheet and starts. Refuse disables start. Retry leaves the sheet open. A nil environment (fixtures) proceeds without a request. `PlayerGapReply` drops `errorCode`, so the service now returns `OrientSafetyCheck` decoded from the same body. | `Core/MPGap/PlayerContent/PlayerContentGapService.swift`, `App/PlayRuntimeGapProduction.swift`, `App/PlayRuntimeGapViews.swift`, `App/PlatformConsumerSessionOwner.swift`, `App/SessionTopicBrowserView.swift` |
| `MerchantContentEditor` shows every `MerchantApplyXcx.allMissing` message, including a set-but-invalid cooperate slot. | `App/MerchantContentEditor.swift` |
| `TopicTemplateDeckPreviewView` renders `footCopy` / `checkCopies`. An unresolved catalog key keeps the Chinese sentence already on the model. | `App/MPGap/PlayerContent/TopicTemplateDeckPreviewView.swift` |
| Shop row shows `organizerShopLogo` (https only). Host and registrant rows show `avatarURL` (`memberAvatar` / `avatar`). | `App/ActivityPeopleSection.swift`, `App/ActivityDetailView.swift` |
| Information share toolbar uses `PublicContentShareLink.information(id:)`, else `informationCopyText(id:)`. Both nil hides the key. | `App/SocialGuideViews.swift` |
| Private broadcast calls `recoverBroadcast(id:)` which forwards to `OfficialEventService.recoverBroadcast(id:token:)`. The button shows when `canRecoverInapp` is true, confirms with `official.broadcast.recover` / `.body`, then re-reads stats. The row shows `summaryLine`. A failure uses `OfficialBroadcastStats.failureLine(serverMessage: nil)` because the service throws without a message. Mocks keep the protocol default (`APIError.notConfigured`). | `Core/OfficialEventReading.swift`, `App/GlobalSearchLinksAndTemplates.swift`, `App/OfficialPrivateViews.swift` |
| `TopicChapter.locked` shows a lock and does not open the chapter. When self-play purchase is offered, the row opens the existing paywall. | `App/TopicDetailView.swift` |
| 有人带 / 无人带, and the guided lead-cost section, hide when `PublisherPricingPreview.productType == 2`. `beginConfirm` still does not call `coordinator.confirm`. It still hits `PlayerContentMPContract.pricingConfirm`, which throws while the grant is off and sends nothing. | `App/PublisherLifecycleViews.swift` |
| My-project address sets `ll` when both `latitude` and `longitude` are finite, so Maps drops a pin. Address-only stays a `q` search. | `App/MyProjectTabViews.swift` |
| Official event detail passes `leaderboard.rows` and `chipText` (plus `myRank` / `isFinal`). The chip uses `official.leaderboard.provisional` or `official.leaderboard.final` when that key resolves, otherwise `chipText`. | `App/OfficialEventDetailView.swift`, `App/MPGap/PlayerContent/TopicAndOfficialGapSections.swift` |
| Topic-template head passes `PublicTopicTemplateDetail.isOfficial`. The play-template `isOfficial(parity)` path was not changed. | `App/DiscoveryTemplateDetailView.swift` |
| Favorite writes go through `TopicLikeHostController.miniProgramLikeRequest` (`id` then `type`, urlencoded) and then set `Authorization` and `Accept`. `TopicLikeOperationFactory` stays the multipart factory and is no longer this path. | `App/TopicFavoriteHost.swift` |
| `ActivityDetailFailure.notFound` shows `activity.detail.missing` and returns to the list. Other failures keep `activity.loadFailed` and retry. | `App/ActivityDetailView.swift` |

## Already on this SHA

Graduate and transfer in `App/AppSession+PopupsClose.swift` already call `PublisherLifecycleCoordinator.prepare` and `confirm` when the graduation or ownership grant is present. Those closures were not retargeted. They do not send quote, registration create, or pricing confirm.

## Left

| Site | Why |
|---|---|
| HomeFeed `clubLabel` / `statusLabel` / `feedTags` / `productType` | Not in this wire list. |
| Registration waitlist `hostReservation` | Not in this wire list. |
| `CommunityMemberReportClient` and turning on `.imRead` | Not in this wire list. Would touch `AppSession`. |
| Self-play `registrationCreate` | Money-adjacent create stays off. |
| Quote | Sends nothing. |
| Pricing confirm | Still refused. `coordinator.confirm` is not called. |
| Gift claim, pay, refund, payout, withdrawal, paid registration | Money stays off. |
| The rest of the Left table in `docs/release/receipts/cursor-r8-wire.md` | Not in this wire list. |

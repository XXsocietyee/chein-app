# Receipt: cursor/core-player-content (K5)

- Branch: `cursor/core-player-content`, cut from `origin/ui/combined-r7` at `7fdfad1f177fadb76f7fd54a82b27fa69b82f1f8`.
- Brief: `origin/design/handoff-r2:docs/briefs/wave-x10.md`. Newest owner=Cursor rows from `origin/audit/parity-r7-player-content`, then `origin/review/r7-rev-b` (rev-a has no findings table; rev-c player-content rows are Gemini MPGap). Older parity/gap receipts were read and not re-opened when r7 already restated them.
- Area: Core/ and Tests/ for player-content only. No App/ screen edits. No `project.pbxproj`. No `tools/current_ci_manifest.json`. No new Swift folder.
- swiftc was not run. This receipt does not claim a parse. Local verify is the test names below.
- Money writes stay on their existing grants. New report submit defaults off (`writesEnabled = false`). Publisher pricing/graduation/ownership grants were not issued.

## Closed in Core

| id | what landed |
|---|---|
| R7-PC-B4-2 | Confirm body can carry `ticketPrices` and sets `guidedPrice` to the minimum when there is more than one ticket. The pricing grant is still required; this does not turn it on. |
| R7-PC-B4-6 | `scope=MERCHANT` is sent on pricing preview and confirm when the caller passes it. Any other scope is refused. |
| R7-PC-A2-1 | `DiscoveryService.playTemplates` posts `pageNum` / `pageSize=50` and follows pages until a short page, `total`, a duplicate page, or 20 pages. Page 1 failure fails the load. A later page failure keeps the rows already collected. Keyword and `pack_type` stay caller-driven. |
| R7-PC-A5-4 | `SearchMapService.merchantCategories` posts `api/category/list` `{type:MERCHANT, parentid:0}`. `categories()` is still type `1`. |
| R7-PC-A5-7 | Map `api/activity/list` page size is 10 (`SearchMapActivityPage.pageSize`). Global search page size 12 is unchanged. |
| R7-PC-B1-8 | `TopicDetail` decodes publisher name/avatar, `contentPublisherType`, `userStatus`, `status`, `rejectReason`. `ownerReviewLabel` matches current `ownerStateText`. |
| R7-PC-B1-15 | Topic links accept `via=session` (`opensSessionPickerFirst`). `TopicXcxFacts.action(_:preferSession:)` opens signup when that flag is set and `activityList` is non-empty. |
| R7-PC-B1-19 | `ownerSaleRoute`: productType 2 opens the editor; other lifecycle-2 owner topics open pricing. Merchant publishers carry `scope=MERCHANT`. `opensPricing` is true only for the pricing route. |
| R7-PC-B6-1 | `pages/topic/catalog/index` is a reviewed page. Canonical `id` is the topic; anything else is home (`catalogDestination`). |
| R7-PC-B6-2 | Universal links under `/catalog` no longer return `.publicCatalog`. `/catalog?id=<canonical>` is topic content. Every other parsed catalog link is `pages/index/index`. Money-key refusals stay nil. |
| R7-PC-C1-2 | Core already allowed a nil token on `api/activity/info`. `PlayerContentCoreContractTests.testActivityInfoAllowsANilToken` pins no Authorization header. |
| R7-PC-C1-3 | Missing or non 0/1 `isSignUp` is `ActivityPrimaryAction.unavailable` (`activity.cta.unavailable` = "—"). Exact 0 stays 立即报名. |
| R7-PC-D1-2 | `MyProjectHTTPMutator.previewActivityCancel` form-posts `api/activity/cancel_preview` `{id, scope}`. `beginActivityCancel` stores the paid-player sentence on `confirmationText` and does not confirm when the count is missing. `ActivityHostCancel` stays JSON; the route allowlist pins that encoding. |
| R7-PC-D1-3 | MERCHANT `CreatorContentService.projects` also posts `api/registration/merchant/list` `{status:0}` and `api/merchant/chapter-application/mine`, then appends accepted joins. Either source failing fails the whole read. A join card whose `topic:<id>` is already in the owned page is skipped. Personal and club reads stay one request. |
| R7-PC-D2-2 | `informationList` posts `{pageNum:1, pageSize:10}`. `informationListReceipt` stays bodyless. |
| R7-PC-D9-2 | `CommunityMemberReportClient` builds GET `api/community-trust/reports/taxonomy` and JSON POST `api/community-trust/reports/submit` (`targetType`, `targetId`, `reasonCode`, `policyVersion`, `description`, `requestId`). Submit throws `APIError.notConfigured` until `writesEnabled` is set. `IMSafetyMenu.Item` is unchanged. `offersPeerReport` is true for a non-system conversation. |
| REV-B B-26 | `TopicClubShareLink` requires `id` or `topicId` plus `sourceClubId`. `clubCode` / `sourceChannelCode` is optional, trimmed, 1–64. Extra keys are ignored. |

Strings fragment: `docs/port/strings/cursor-core-player-content.json` (`activity.cta.unavailable`, `im.chat.more.reportPeer`).

## Tests (one per call touched)

- `api/template/list` — `PlayerContentCoreContractTests.testTemplateListPagesByFiftyUntilAShortPageAndDedupes` plus the page fields in `DiscoveryContractTests`.
- `api/category/list` MERCHANT — `testMerchantCategoryListPostsMerchantType`.
- `api/activity/list` pageSize 10 — `SearchMapPaginationTests.testActivityPageUsesExistingRouteExactPageAndNoMerchantOrDatePriceFields`.
- `api/topic/pricing/preview` and `api/topic/pricing/confirm` — `PublisherLifecycleTests.testPricingPreviewKeepsScopeAndConfirmUsesTheCheapestTicket`.
- `api/common/infomation_list` — `SocialAccountTests.testGuideListAndDetailUseSourceMisspellingAndBodyShapes`.
- `api/activity/info` — `testActivityInfoAllowsANilToken`.
- `api/activity/cancel_preview` — `testActivityCancelPreviewUsesFormAndBlocksConfirmWithoutACount`.
- `api/registration/merchant/list` — `testRegistrationMerchantListMergesAcceptedJoins`.
- `api/merchant/chapter-application/mine` — `testChapterApplicationMineMergesAPendingInvite`.
- `api/community-trust/reports/submit` — `testCommunityTrustReportSubmitStaysOffAndMatchesTheSheetBody`.
- `api/community-trust/reports/taxonomy` — `testCommunityTrustReportTaxonomyIsAGET`.

## For the Claude F-agent (App callers)

- Search map merchant filter must call `SearchMapService.merchantCategories()`, not `categories()`.
- `pages/topic/catalog/index`: canonical id opens the topic screen; otherwise home. `.publicCatalog` is no longer produced for `/catalog` links. `NativeEntryLandingView` still has the case; it is unused for new parses. Remove `PublicCatalogViews` when nothing else constructs that case.
- Activity primary action `.unavailable` must be a disabled "—", not the wallet button. `ActivityDetailView.primaryActionEnabled` and the else branch currently treat every non-signup, non-cancelled action as a wallet tap when the reader is `AppSession`.
- Activity not-found copy (R7-PC-C1-8): 活动不存在 and 返回活动列表 stay on the screen. Core does not invent that string.
- Guest activity read (R7-PC-C1-2): sign-in belongs on 立即报名, not a wall in front of `api/activity/info`. Core already sends the read with a nil token.
- My-project activity cancel: call `MyProjectMutationModel.beginActivityCancel(id:title:)` and show `confirmationText`. `begin(.cancelActivity)` and `confirmationMessage` do not include the paid-player count.
- Topic `via=session`: pass `preferSession: true` into `TopicXcxFacts.action` so the bar opens the session picker before self-play.
- Owner lifecycle 2: use `TopicXcxFacts.ownerSaleRoute`. `.editor` opens the topic editor (`pages/publish/fabu/index?id=` plus `scope=MERCHANT` when the scope is set). `.pricing` is the only case where `opensPricing` is true. Free-explore owners no longer match `opensPricing`, so the confirm-price row in `TopicXcxSections` stays hidden until this route is wired.
- IM peer report: insert 举报对方 from `IMSafetyMenu.offersPeerReport` and `im.chat.more.reportPeer`. Do not add an `IMSafetyMenu.Item` case until every App switch is updated. Keep `CommunityMemberReportClient.writesEnabled` false until a grant exists.
- IM silent read (R7-PC-D9-1): `performOrdinaryRead` already form-posts `conversation_id` and `read_to`, and `canWriteOrdinaryRead` stays default off. Call it after the first page only when that grant is on. Do not default the grant on.
- Wallet analysis (R7-PC-D6-1): page with `WalletAnalysisPagingPolicy` (`mpPageSize` 200, stop when the page is short or the oldest row is before the six-month cutoff). The App reader still uses a fixed budget.
- 主办分润 (R7-PC-D4-1): do not show a tab that renders "—" until a real coop-finance read grant exists. Do not invent the grant. The MPGap GET client is the wrong method.

## Leftovers

- P1 story/cast mounts (B-03, R7-PC-B1-11 `TopicCastRow`) stay on `cursor/r7-wiring`. That branch was not on origin. Not redone.
- Owner-gated writes: R7-PC-B2-1, B3-1, B4-1 grants stay dormant. Pricing confirm can now carry the ticket fields, but it still does not send without the existing grant.
- REV-B rows left to their areas: B-11 club settlement, B-12 / B-17 merchant inbox read (JSON body and `canWriteInboxConversationRead` are pinned by `WiringR6ClientTests`), B-13 / B-20 invoice, B-18 / B-19 / B-27 merchant public review, B-10 play arrival.
- REV-C MPGap contract rows stay with Gemini. `api/report/create` was not added.
- `ActivityHostCancel` still JSON-encodes cancel preview. My-project uses the new form method. The scene-play host path was not retargeted, because `MoneyParityLpCTests` and the route allowlist pin the JSON body.
- Template shelf stops after 20 pages (1000 rows) if `total` never arrives. The mini-program has no cap.
- Gap endpoints that are owner-gated or not verified on this pass stay unwired: recruit-slot qrcode, coop offer quota / sale-pause / display-terms, chapter-application offer remove, getwxbindphone, fe/reference-settlement note, `api/audit/`.
- In-flight `restyle/*`, `gap/*`, `port/*`, and `cursor/core-wiring-r6` were not edited. None of them already shipped these Core contracts.

# cursor/wire-player-content

Base: `origin/ui/combined-r7` `82388e4a5e7391e0c5a286735d6b30613a860ae8`.

Merged before any call-site edit, and their screen work is kept:

- `origin/fix/r3-player-content-a` `bd276cb3109a0e40b68a42224e83af974e9fbd5d` (merge `73d0a3b57f873cd0df2c6acd0ff2d94919e4acaa`)
- `origin/fix/r3-player-content-b` `f4eecc3a774a200e4825394ff4ac1813d597ef77` (merge `551eb404a7b45a926be0ca36a810c7b8e035d372`)

Read: `docs/release/receipts/cursor-core-player-content.md`. This VM has no `swiftc` or `xcodebuild`. This receipt does not claim a parse. `Questify.xcodeproj/project.pbxproj` and `tools/current_ci_manifest.json` were not edited.

`Core/TopicClubShareLink.swift` was not edited. The parser still binds `let clubCode` and calls `Self.clubCode(trimmed)`. `init(clubCode: String?)` is unchanged.

## Call sites

| Site | File | What it does |
|---|---|---|
| Merchant category filter | `App/SearchMapExplorerView.swift` | City 商家发现 loads `reader.merchantCategories()`. `SearchMapSessionReader` posts `SearchMapService.merchantCategories` (`type=MERCHANT`). Global search recovery still calls `categories()` (`type` 1). |
| Catalog screen | `App/MPReviewedPageScreen.swift` | `pages/topic/catalog/index` with a canonical id opens `SessionTopicDetailView`. Every other catalog link opens home. `PublicCatalogViews` stays, because `NativeEntryLandingView` still constructs `.publicCatalog`. |
| Disabled "—" | `App/ActivityDetailView.swift` | `ActivityPrimaryAction.unavailable` is a disabled button titled `activity.cta.unavailable` (`—`). It does not open the ticket wallet. |
| Guest sign-in on 立即报名 | `App/ActivityDetailView.swift`, `App/AppSession.swift`, `App/AppCompositionRoot.swift` | The activity page is no longer a sign-in wall. A guest `activityDetail` sends `api/activity/info` with a nil token when content-detail approval is on. Topic info stays signed-in. 立即报名 calls the Mine-tab sign-in and does not open registration. A signed-in account with no token still throws `unauthorized`. |
| `beginActivityCancel` + `confirmationText` | `App/MyProjectTabViews.swift`, `App/MyProjectMutationViews.swift` | Activity cancel calls `beginActivityCancel(id:title:)`. The confirm sheet shows `model.confirmationText` when it is set, and the mutation's `confirmationMessage` otherwise. |
| `preferSession` | `App/MPReviewedPageScreen.swift`, `App/PlatformConsumerSessionOwner.swift`, `App/TopicDetailView.swift`, `App/TopicXcxSections.swift` | `via=session` passes `preferSession: true` into both `TopicXcxFacts.action` calls, so the bar opens the session picker before self-play. |
| `ownerSaleRoute` | `App/TopicXcxSections.swift`, `App/TopicDetailView.swift`, `App/PlatformConsumerSessionOwner.swift` | Lifecycle 2 uses `TopicXcxFacts.ownerSaleRoute`. `.pricing` keeps the confirm-price sheet. `.editor` opens `pages/publish/fabu/index` with `id` and `scope` when set. The pricing grant is not turned on. |
| 举报对方 | `App/MessagingHistoryView.swift` | A `Choice.peerReport` row, not an `IMSafetyMenu.Item`, when `offersPeerReport` is true. Title `im.chat.more.reportPeer`. Selecting it does not call `submit` and does not set `writesEnabled`. |
| Wallet paging | `App/WalletIncomeAnalysisReader.swift` | Pages use `WalletAnalysisPagingPolicy.mpPageSize` (200) and stop when `shouldContinue` is false (short page, or the oldest Beijing `createTime` is before a six-month cutoff). A 40-page cap only stops a runaway full-page stream. This is a read. |

## Left off

- Pricing grant stays off. `PublisherPricingView` is still reached only through the existing pricing destination.
- `CommunityMemberReportClient.writesEnabled` stays `false`. `submit` still throws `APIError.notConfigured` until writes are enabled.
- IM ordinary-read grants were not changed.
- No money write was added. Wallet analysis only reads `api/user/balance/list`.
- Activity-not-found copy and the 主办分润 tab were not wired.

## Strings

`docs/port/strings/cursor-wire-player-content.json` and `Resources/Localizable.xcstrings` both have `en` and `zh-Hans` for `topicXcx.cta.edit` and `im.chat.more.reportPeerClosed`. `activity.cta.unavailable` and `im.chat.more.reportPeer` were already in the catalog.

## Checks

Python contract checks that were re-run here: wallet income closure, signed-in content details, activity/topic navigation, and the search-map helper pin. The search-map pin now matches `SearchMapReading.swift`, `SearchMapExplorerView.swift`, and the already-landed `SearchMapService.merchantCategories`. No Swift compiler was run.

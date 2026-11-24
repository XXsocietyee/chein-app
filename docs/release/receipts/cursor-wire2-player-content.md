# cursor-wire2-player-content

Base `b0ac0108d0a5a9739ababecbbc61284cae5a8043` (`origin/ui/combined-r7`, message starts "Integrate F-agent round 2"). Branch `cursor/wire2-player-content`. No pull request. No rebase.

Contracts stay in `Core/PlayerContentMPContract.swift`. The 41 pinning tests in `Tests/CoreTests/PlayerContentMPContractTests.swift` were not edited. No endpoint was added. `project.pbxproj` and `tools/current_ci_manifest.json` were not edited. `swiftc` was not run. This receipt does not claim a parse.

`PlayerContentMPContract.moneyEnabled` stays false. `PlayerContentMPContract.pricingGrantEnabled` stays false. `PublisherLifecycleGrants.dormant.pricing` stays nil. `WalletIncomeAnalysisReader` was not edited. View signatures of `SettingsView`, `MerchantVerifyRecordsSections`, `PlatformConsumerSessionOwner`, `RoamPOIActions`, `JourneyReportViews`, `TeamHomeView`, `TicketWalletView`, `TopicXcxSections`, `ClubDetailView`, and `ClubWorkbenchKit` were not edited. `TopicClubShareLink` still assigns `clubCode` with `Self.clubCode(trimmed)` and keeps `init(clubCode: String?)`.

## Refused, nothing sent

| contract | App call site | what happens |
|---|---|---|
| `POST api/registration/quote` | none added | `registrationQuote` still throws `Refusal.moneyDisabled` before a request exists. Activity signup (`RegistrationService`, owner type 2, `pages/activity/baoming`) was not retargeted. |
| `POST api/registration/create` | `AppSession.topicSelfPlayFlow` via `PlayerContentSelfPlayClient.create` | Calls `registrationCreate` (owner type 1). The flag throws. `TopicSelfPlayHTTPClient.create` is not called. Nothing is sent. |
| `POST api/topic/pricing/confirm` | `PublisherPricingView.beginConfirm` | Calls `pricingConfirm`. The flag throws. `coordinator.confirm` is not called for pricing. Nothing is sent. Graduate, transfer, and cancel still use the coordinator. |

## Call sites moved

URLs are rebuilt with `base.appendingPathComponent` so `/native` and `/prod-api` stay on the session base. `PlayerContentMPContract.make` replaces the path and would drop that prefix.

| site | contract |
|---|---|
| `AppSession.searchMapReader.search` (`PlayerContentSearchMapReader`) | `searchTopicList` (no `is_my`, page size 12), `searchActivityList` (`is_my` first, page size 12), `searchClubList`, `searchMerchantList` |
| `AppSession.searchMapReader.categories` | `categoryList(type: 1, parentID: 0)` |
| `AppSession.officialEventReader.events(city: nil)` | `officialEvents`. GET is adapted to `Accept: application/json` and no `Content-Type`, so the public catalog route still admits it. A changed reader scope throws `CancellationError` before a 401 is applied. |
| `AppSession.officialEventReader.myEvents` | `officialMyEvents` (same GET adaptation) |
| `AppSession.officialEventReader.canPublish` | `officialCanPublish` (same GET adaptation). A guest still returns false without a request. |
| `RoamPlaceExtrasProduction.performPublish` | `commentAdd` (owner type 4, urlencoded). The local review attempt still keeps its request id. That id is not a field on this body. |

`SearchMapService` itself is unchanged, so its multipart tests, including `is_my` on topic list, stay as they are. City search, city nodes, merchant categories (`type=MERCHANT`), nearby, and detail reads stay on `SearchMapSessionReader`. Official detail and the other official reads stay on `OfficialSessionReader`. A non-nil city still uses that reader because `officialEvents` has no city query. Comment list stays on `RoamPlaceCommentClient`.

## Left on the previous sender

| site | why it was not moved |
|---|---|
| Home feed `categories` and `discoveryCategories(type:)` | App tests pin the multipart body from `AuthRequestBuilder` (`parentid`, and `type` when present). `categoryList` is urlencoded and always sends `type`. |
| Discovery topic-template and play-template lanes | The composition gate admits topic-template list only as JSON `{}`, and play-template list is multipart with `keyword` and page size 50. `topicTemplateList` is an empty form. `templateList` / `searchGameTemplates` do not carry that page or keyword pair. |
| `PlayTopicPrepSection` / `PlayTopicSetup.read` | The setup GET is built inside `PlayRuntimeClient`. There is no App send of a prebuilt request that still satisfies the play gate. |
| Free-explore catalog | `FreeExploreLaunchService.catalog` builds the GET. `FreeExploreBundleLaunchView` only reads page readiness. |
| `MapSearchPlayerViews.unifiedSearch` and `SocialRoamMounts` `MapSearchPlayerService.Place` | Not this contract. `api/search/unified` is not a `PlayerContentMPContract` method. |
| `TopicLikeOperationFactory` | No App caller. The factory stays multipart. |
| Activity `RegistrationService.quote` / `create` | `pages/activity/baoming` is outside this slice. Those calls were not pointed at the refusing contract methods. |

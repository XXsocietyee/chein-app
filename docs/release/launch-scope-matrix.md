# Launch scope matrix

Track A1. Docs only. Product behavior is unchanged. Shipped composition stays `reviewed: nil`. Safety gates stay off. Password login, bank withdrawal, and virtual-goods purchase stay off.

## Counts

| Classification | Rows |
|---|---:|
| PROD-SERVED route rows | 602 |
| NEW-BACKEND-ONLY route rows | 335 |
| NONE entry rows (no network route) | 8 |
| Real `/api` route rows | 937 |

A route row is one normalised path the App or Core sources can build. An entry with several routes has one row per route. A NONE row is a release screen or action that builds no request.

NEW-BACKEND-ONLY rows whose release chrome is still on screen: **9** (two entries: public map layers, and the approved-topic-release recovery block). The other **326** NEW-BACKEND-ONLY rows have a hide proof below. All **8** NONE rows are on the release shell; they do not call the network, and they are not proven unreachable.

## Sources

`docs/release/backend-contract-for-ios.md` is not on `wip/gate-allowlist` (`0a84de0c6`). Appendix A is taken from `origin/cloud/doc-5` commit `59a8e1635`, file `docs/release/backend-contract-for-ios.md`. That appendix matches iOS path strings to hengyin `master` at `147754ba` ("统一资金十四天等待期"). It has 959 route rows: 606 with a controller method, 353 marked **MISSING**.

Production commit `014fc0d8` (`014fc0d83afe9f53cf4a8b1f9544bcf634e9ce6c`, hengyin, merge of PR 707) is 71 commits behind that master. The compare touches four API controllers. The only new mapping is `GET /api/author-write/receipt` on the added `ApiAuthorWriteReceiptController`. The iOS tree has no call for that path. The other three controller diffs do not add mappings. So an Appendix A row that names a controller is still a route in the production source tree.

This checkout has 937 real `/api` paths after dropping description strings (the same exclusions Appendix A names: prose about `/api/topic/detail`, `/api/order/*`, `/api/userInfo`, `/api/roam/tiles/page`, a bare `/api/`, a bare `/api/ai`, and a broken `api/channels/\(channelID` fragment). 602 are PROD-SERVED. 335 are NEW-BACKEND-ONLY (Appendix A **MISSING**, or absent from Appendix A). Three real paths are absent from Appendix A and are NEW-BACKEND-ONLY, not treated as served: `/api/community-trust/reports/submit`, `/api/merchant/npc/voice/reset`, `/api/registration/pay`.

The brief's "129 of 928" is not the count in Appendix A and is not the controller intersection at `014fc0d8` (about 580 exact path matches, 606 appendix matches). No 129-path allowlist is in this repo. Those source-present routes are not dropped to zero. A live gateway that served only 129 paths was not found here and was not probed.

There is no G01–G58 route catalog in this checkout. `G01` in `App/PlayComponents.swift` is a form style. `docs/owner-plan/gap-pl-4.md` uses G01–G03 as backend gap ids. NEW-BACKEND-ONLY below is the Appendix A gap, not a guessed G-list.

## How a row is marked

- **PROD-SERVED** — Appendix A names a backend controller method for the path, and that mapping is in hengyin `014fc0d8`.
- **NEW-BACKEND-ONLY** — the app can build the path, and Appendix A marks it **MISSING** or does not list it. Unknown is not counted as served.
- **NONE** — the release entry builds no request.

Dispatch proof for every NEW-BACKEND-ONLY row, cited once:

- `RegionalLaunchConfiguration.composition` calls `makeComposition(reviewed: nil, build: .current)` (`App/RegionalLaunchConfiguration.swift`, `composition`). `makeComposition` returns `.unconfigured` when `reviewed` is nil.
- `CompositionHTTPTransport.send` throws `APIError.notConfigured` when `deployment` is nil (`App/AppCompositionRoot.swift`, `send`, `guard let deployment`).
- `AppSession.init` assigns the session services to nil in the branch that runs when `composition.reviewed` has no API configuration (`App/AppSession.swift`, the `else` after `if let scope, let regional, let configuration`). `bootstrap` returns before reading the vault when `accountSessionService` is nil, so a stored token does not become an account.

That closes the network. Chrome is a separate check: a control that is still in the release tree and shows an unavailable state is not hidden.

## Release shell

Release `QuestifyApp` builds `SessionRootView` (`App/QuestifyApp.swift`). With `reviewed: nil` the first screen is `WelcomeView`. Guest browse (`welcome.browse`) sets `browsingAsGuest` and shows the five tabs. Login cannot finish, because the auth services are nil and `canUsePassword` is false outside DEBUG.

| Entry | What the user can open | Routes | Class | Chrome |
|---|---|---|---|---|
| Welcome language | `LanguageSwitcher` on the welcome toolbar | — | NONE | On screen. Local. |
| Player / merchant | `LoginView` | `/api/sms/send`, `/api/login/phone`, `/api/login/apple`, `/api/login/wechat/app`, `/api/userInfo`, `/api/logout` | PROD-SERVED | Password block is compiled out (`LoginView` renders it only when `session.canUsePassword`). Phone and Apple controls in `AuthChannelView` stay disabled (`EntryFlowTests.testUnconfiguredPhoneAndAppleCannotDispatch`). The login form also shows `auth.notConfigured`. |
| Password sign-in | Username and password fields | `/api/login` | PROD-SERVED | Off in the shipped binary. `AppSession.canUsePassword` is `false` outside DEBUG. `AppSession.init` sets `AuthService` to nil outside DEBUG. `EntryFlowTests.testUnconfiguredBuildHidesUnsupportedPassword` and `Adapt5PasswordLoginOffTests`. The path exists on the server and is still not shown. |
| Owner-draft guest | `OwnerDraftGuestView` from `welcome` | — | NONE | On screen. Local sign-in prompt. No draft request is built. |
| Settings | Gear on welcome | see NONE rows and the links below | mixed | Reachable. |
| Home tab | `SessionHomeFeedView` → `HomeFeedView` | `/api/activity/list` | PROD-SERVED | `ContentUnavailableView` `homeFeed.unavailable` when the reader is not configured (`HomeFeedView`). Toolbar search and the more menu stay. |
| Home search | `SessionGlobalSearchView` | SearchMapService paths, 9 PROD-SERVED plus `/api/map/public-layers` | mixed | Search shows `searchMap.notConfigured` and a disabled submit. `mapSection` is outside that branch, so city search, nearby, and merchant discover stay as links. |
| Public map layers | `MapPublicLayerCallerView` and `MapPublicLayerSectionView` | `/api/map/public-layers` | NEW-BACKEND-ONLY | **Not hidden.** See below. |
| Square | `SessionSquareBrowserView` | six `/api/v1/community` and `/api/creativesquare` and `/api/comment/list` and `/api/config/features` paths in `SquareService` | PROD-SERVED | `SquareIssueView` for `APIError.notConfigured`. |
| Official events | `OfficialEventsBrowserView` | seven `/api/official/*` paths in `OfficialEventService` | PROD-SERVED | `OfficialIssueView(.unconfigured)`. Inbox link stays in the toolbar. |
| Templates / Publish tab | `DiscoveryTemplateBrowserView` | eight `/api/template`, `/api/category/list`, `/api/common/*` paths in `DiscoveryService` | PROD-SERVED | `ContentUnavailableView` `discovery.unavailable` replaces the shelf, so purchase rows are not built. |
| Project editor | Home more menu → `ProjectEditLaunchView` | publishing paths in `PublishModesService` are PROD-SERVED; approved-topic-release paths are NEW | mixed | Launch screen links are always built. Opening a blank city or free-explore draft sets a snapshot (`ProjectEditCoordinator`, `topicID == nil`). |
| Approved-topic release | Recovery block inside that editor | eight `/api/approved-topic-release/v1/*` paths | NEW-BACKEND-ONLY | **Not hidden.** See below. |
| Roam tab | `RoamBrowserView` | seven `/api/roam` and `/api/map` and `/api/city` and `/api/merchant/public-detail` paths in `RoamService` | PROD-SERVED | Start tab shows `.notConfigured`. Passport tiles for goals and capsule stay; their twelve paths in `RoamPassportPrivateToolsReading` are PROD-SERVED and the page shows `RoamPrivateIssueView(.notConfigured)` because the service is nil. |
| Club tab | `ClubHomeView` | five `/api/club/home|my|list|detail|members` paths | PROD-SERVED | `ClubReadScreen` shows `club.unavailable` and does not build directory, create, or event links. `reload` returns when `isClubConfigured` is false. Refresh is disabled. |
| Club feed tab | `ClubCommunityFeedView` | `/api/club/post/feed` and the post list/comment/history paths | PROD-SERVED | The community value passed from `SessionRootView` is non-optional, so the segmented control is built. Load failure sets `club.community.loadError`. |
| Club post receipt | Pending reconcile on that feed | `/api/club/post/operation/receipt` | NEW-BACKEND-ONLY | Hidden on a fresh launch. The reconcile button is inside `if let pending = model.pendingRecord`. There is no pending record. |
| Messages bell | `SessionMessagingToolbarEntry` on the club bar | `/api/im/*` (mostly NEW-BACKEND-ONLY) and friend routes | NEW-BACKEND-ONLY | Hidden. The link is inside `if session.account != nil`. Bootstrap never sets an account. |
| Bank withdrawal | `SessionBankWithdrawalView` | `/api/withdrawal/create` and the other withdrawal paths in `BankWithdrawalAdapter` | PROD-SERVED | Off. `makeBankWithdrawalContext` returns nil unless `businessRuntimeFactory` permits `.bankPrepare` and `.bankConsentRead`. That factory is nil without an API configuration. The only navigation links live in `WalletCommerceViews`, which the guest root does not open. The environment destination on `SessionRootView` has no caller on this path. |
| Virtual goods / workshop pay | StoreKit and workshop purchase routes | `/api/workshop/*` and `/api/mod-commerce` | NEW-BACKEND-ONLY | Hidden. `makeWorkshopCommerceController` returns nil without `currentWorkshopOwnedContext`. `WorkshopCommerceComposition` defaults `enableApprovedStoreKit` to false. The shelf that would list a purchase is the discovery unavailable view. `workshopCreator.open` is inside `ForEach(rows)` in `TemplateAuthoringMineView`; a failed read leaves `rows` empty, so the button is not built. |
| Settings sound | `SettingsSoundPreferencesView` | — | NONE | On screen. Local store. |
| Settings legal | `SettingsLegalDocumentView` | — | NONE | On screen. `SettingsBundledLegalReader`. |
| Settings about | `SettingsAboutView` | — | NONE | On screen. Local. |
| Settings blocked rows | location consent, marketing consent, account deletion | — | NONE | On screen. `accountComplianceCoordinator` is nil without an API configuration, so `SettingsSupportSections` builds three `SettingsUnavailableFeature` links. Each opens `SettingsUnavailableFeatureView`, which shows `settingsNative.blocked.unavailable`. |

Login, home, square, official, templates, roam, and club-home routes above are PROD-SERVED. Their unavailable screens are the grant being off (`reviewed: nil`), not a missing production route. They do not need a NEW-BACKEND hide proof. They are still not a working first-launch client for those routes.

## Not proven hidden

These are the entries where a release control is still in the tree.

### `/api/map/public-layers` (NEW-BACKEND-ONLY)

1. Home more menu is always on `SessionHomeFeedView`, including when the feed is the unavailable view.
2. `SessionGlobalSearchView.task` assigns `publicLayers` to a `MapPublicLayerCaller` with no configuration check.
3. `GlobalSearchView.mapSection` is outside the `if !reader.isConfigured` branch. Once `publicLayers` is non-nil it builds `NavigationLink` to `MapPublicLayerCallerView` (`searchMap.publicLayers`).
4. `MapPublicLayerCallerView` is a form with a Load button. The button is disabled when `caller.accountID == nil`, so a guest cannot send, and the screen is still there.
5. City search and nearby links in the same section open `SearchMapExplorerView`. `AppSession.mapPublicLayerCoordinator` is a `lazy var` created even when `mapPublicLayerService` is nil, and the search reader is given that coordinator (`AppSession` search-reader construction). `SearchMapExplorerView` then embeds `MapPublicLayerSectionView`, which shows `mapPublicLayers.notConfigured` when `coordinator.isConfigured` is false.

Dispatch is still closed (`send` throws `.notConfigured`). The screen and the unavailable line are not hidden.

### `/api/approved-topic-release/v1/*` (eight NEW-BACKEND-ONLY paths)

`ProjectEditLaunchView` is in the home more menu with no configuration check. Its links open `ProjectEditView`. `ProjectEditCoordinator` sets a blank snapshot when `topicID` is nil. `ProjectEditView` then includes `ApprovedReleaseAuthorReadSection` whenever `snapshot != nil`. That section always builds `ApprovedReleaseOriginalRecoverySection`: a button disabled when `capture()` is nil, plus `recovery.unavailable` text (`App/ApprovedReleaseOriginalRecovery.swift`).

`makeApprovedReleasePreparationSource` returns nil unless `approvedReleaseRuntimeFactory` permits `.approvedTopicReleasePrepare` and an API configuration exists. The client is not created. The unavailable line is still in the editor.

The "check the approved snapshot" button is behind `submissionEvidence?.bundleAcknowledgment != nil`, so that one control is absent on a blank draft. The recovery block is not.

### NONE rows that stay on screen

These build no request. They are not proven unreachable:

| Entry | Symbol | Why it is still there |
|---|---|---|
| Language | `LanguageSwitcher`, settings language picker | Local preference. |
| Owner-draft guest | `OwnerDraftGuestView` | NavigationLink on `WelcomeView`. Copy and a sign-in button. |
| Sound | `SettingsSoundPreferencesView` | NavigationLink in `SettingsSupportSections`. Local store. |
| Legal documents | `SettingsLegalDocumentView` | One link per `SettingsLegalType`. Bundled reader. |
| About | `SettingsAboutView` | NavigationLink. Local. |
| Location consent | `SettingsUnavailableFeature.locationConsent` | Opens `SettingsUnavailableFeatureView`. |
| Marketing consent | `SettingsUnavailableFeature.marketingConsent` | Same unavailable page. |
| Account deletion | `SettingsUnavailableFeature.accountDeletion` | Same unavailable page. |

The three blocked settings rows are the ones that match "no dead button, no error screen" as a failure: the row is tappable and the destination says the feature is unavailable. Language, sound, legal, about, and the owner-draft prompt are working local UI, not a failed request.

## Hide proof for the other NEW-BACKEND-ONLY rows

326 paths. Each one is absent from production source (Appendix A **MISSING**, or not listed). None of them is sent:

1. Dispatch proof in the section above (`reviewed: nil` → `.unconfigured` → `send` throws `.notConfigured`).
2. `businessRuntimeFactory` is nil without `regionalConfiguration?.apiConfiguration` (`AppSession.businessRuntimeFactory`). Bank, publishing writes, IM channel features, and approved-release clients all require that factory or a reviewed permit. `LaunchFeatureFlags` are not consulted to turn a route on. `productionGatesEnabled` is never true on the shipped composition, because there is no reviewed deployment.
3. The messaging bell, the workshop purchase button, and the club receipt button are gated by account, a loaded row, or a pending record, as in the shell table. Guest browse has none of those.
4. DEBUG fixture hosts in `QuestifyApp` (`#if DEBUG`) are not in the release scene.

Families with the most NEW-BACKEND-ONLY paths (prefix of three segments):

| Family | NEW-BACKEND-ONLY | Paths in family |
|---|---:|---:|
| `/api/im` | 69 | 86 |
| `/api/merchant` | 35 | 142 |
| `/api/club` | 27 | 111 |
| `/api/friend` | 24 | 24 |
| `/api/city-game` | 22 | 22 |
| `/api/workshop` | 17 | 17 |
| `/api/topic` | 15 | 41 |
| `/api/native` | 12 | 12 |
| `/api/reward-pledge` | 12 | 12 |
| `/api/channels` | 10 | 10 |
| `/api/approved-topic-release` | 8 | 8 |
| `/api/play` | 6 | 58 |
| `/api/rewards` | 6 | 6 |
| `/api/channel-platform` | 5 | 5 |
| `/api/channel` | 4 | 4 |
| `/api/join-request` | 4 | 4 |
| `/api/city` | 3 | 7 |
| `/api/project` | 3 | 6 |

## Password, bank withdrawal, virtual goods

| Feature | Path class | Shipped state |
|---|---|---|
| Password login | `/api/login` is PROD-SERVED. Backend still requires a mini-program `code` (contract M-01). | Control and `AuthService` are compiled out of non-DEBUG builds. |
| Bank withdrawal | Withdrawal paths in `BankWithdrawalAdapter` are PROD-SERVED. | `makeBankWithdrawalContext` returns nil. No guest navigation. |
| Virtual goods | Workshop and `/api/mod-commerce` paths are NEW-BACKEND-ONLY. | StoreKit launcher is not built. Shelf rows are not built. |

No money gate was turned on. Password login, payout, withdrawal, virtual goods, and merchant/coop operator writes stay off.

Owner approval 2026-11-12 (`Yes, allow them`): the shipped China composition lifts the `PWaveReader` / `JourneyLoopSource` production-host refusal for player reads only. `ReviewedProductionGateLeases` constructs those readers when `playerWritesEnabled` is on and the market is China. The reads are the journey invite landing, the seats lobby, the run report, settle/rating, and the anonymous public catalog posts `api/public-catalog/city/list`, `list`, `filters`, and `info`. Seat invite, claim, and cancel keep the caller's saved request id until a 2xx or 4xx answer. Rating is `POST /api/comment/add` as form data, owner type 1 (topic) or 2 (session). Pass purchase, gift purchase, `POST /api/marketing/product/gifts/claim`, referral-token issue, and affiliate summary/payout stay unreachable. `ReleaseMoneyWriteSwitch.blocks` and `forcedOff` are unchanged. Door scan and binding stay false. Production gates alone do not construct the readers. See `docs/release/receipts/cloud-pwave.md`.

Owner approval 2026-11-12 (`Yes, all player writes`): the shipped China composition (`reviewedDeployment`, `playerWritesEnabled`) constructs each approved writer inside `ReviewedProductionGateLeases` and admits the matching request inside `ReviewedProductionFormMutationRoute`. A matching China build is required. The process-default `composition` stays unconfigured when the build does not admit China. Production gates alone do not turn the writers on. Unknown results stay on the caller's saved request id until a 2xx or 4xx answer. The writers are IM send and send-receipt, club join/apply/quit plus post and comment create/delete/like/report/repost, the `/api/v1/community/*` publish pipeline, profile edit and avatar, free registration, team command/query/cancel, the play loop including help and scan-entry, roam extras other than presence, likes, reports and appeals, and friends plus channel text send. Club role assign/revoke stay nil. `api/registration/create` is admitted only when the body has no `payChannel` and no positive amount; `RegistrationCoordinator.confirm` sends only a zero `payAmount` and does not set the app pay channel. `api/registration/pay`, `api/registration/cancel-refund`, withdrawal, payout, virtual goods, merchant/coop operator writes, and password login stay off. See `docs/release/receipts/cloud-w1.md`.

## Every route

Chrome `VISIBLE` means the release shell still shows that feature's control or unavailable line. Chrome `HIDDEN` means the dispatch proof above, plus the shell gates. First site is the earliest App or Core literal for that path, skipping files whose names contain Fixture or Synthetic when another site exists.

| Path | Class | Chrome | First site |
|---|---|---|---|
| `/api/activity/cancel` | PROD-SERVED | — | `App/AppCompositionRoot.swift:3942` |
| `/api/activity/cancel_preview` | PROD-SERVED | — | `App/AppCompositionRoot.swift:3939` |
| `/api/activity/create-requests/read` | NEW-BACKEND-ONLY | HIDDEN | `Core/ActivityCreateRequestContract.swift:6` |
| `/api/activity/create-requests/resume-post-processing` | NEW-BACKEND-ONLY | HIDDEN | `Core/ActivityCreateRequestContract.swift:7` |
| `/api/activity/create-requests/submit` | NEW-BACKEND-ONLY | HIDDEN | `Core/ActivityCreateRequestContract.swift:5` |
| `/api/activity/delete` | PROD-SERVED | — | `Core/BusinessRuntimeConfiguration.swift:332` |
| `/api/activity/info` | PROD-SERVED | — | `Core/ActivityEditing.swift:178` |
| `/api/activity/list` | PROD-SERVED | — | `App/AppCompositionRoot.swift:2627` |
| `/api/activity/publish` | PROD-SERVED | — | `Core/BusinessRuntimeConfiguration.swift:332` |
| `/api/activity/update` | PROD-SERVED | — | `Core/ActivityEditing.swift:179` |
| `/api/activity/update_publish_status` | PROD-SERVED | — | `Core/BusinessRuntimeConfiguration.swift:332` |
| `/api/ai/club/design` | PROD-SERVED | — | `Core/BusinessRuntimeConfiguration.swift:330` |
| `/api/ai/merchant/insight` | PROD-SERVED | — | `App/AppCompositionRoot.swift:4151` |
| `/api/ai/npc/chat/data/delete` | PROD-SERVED | — | `Core/NPCChatLogDeletion.swift:20` |
| `/api/ai/npc/chat/data/export` | PROD-SERVED | — | `Core/NPCChatData.swift:55` |
| `/api/ai/npc/merchant-chat` | PROD-SERVED | — | `Core/MerchantNPCAuthenticatedTransport.swift:29` |
| `/api/ai/npc/shop-chat` | PROD-SERVED | — | `Core/ShopNPCAuthenticatedTransport.swift:44` |
| `/api/ai/npc/voice-chat` | PROD-SERVED | — | `Core/ShopNPCAuthenticatedTransport.swift:43` |
| `/api/ai/safety/precheck` | PROD-SERVED | — | `Core/ProjectEditContract.swift:8` |
| `/api/ai/template/fill` | PROD-SERVED | — | `Core/BusinessRuntimeConfiguration.swift:331` |
| `/api/ai/theme/draft` | PROD-SERVED | — | `Core/BusinessRuntimeConfiguration.swift:329` |
| `/api/ai/theme/draft/quota` | PROD-SERVED | — | `Core/BusinessRuntimeConfiguration.swift:322` |
| `/api/ai/theme/draft/request` | PROD-SERVED | — | `Core/MerchantNPCThemeDraftRequestRead.swift:15` |
| `/api/approved-topic-release/v1/prepare` | NEW-BACKEND-ONLY | VISIBLE | `Core/ApprovedTopicReleaseDomain.swift:4` |
| `/api/approved-topic-release/v1/publish` | NEW-BACKEND-ONLY | VISIBLE | `Core/ApprovedTopicReleasePublicationClient.swift:7` |
| `/api/approved-topic-release/v1/review/current` | NEW-BACKEND-ONLY | VISIBLE | `Core/ApprovedTopicReviewRequest.swift:8` |
| `/api/approved-topic-release/v1/review/prepare` | NEW-BACKEND-ONLY | VISIBLE | `Core/ApprovedTopicReviewRequest.swift:5` |
| `/api/approved-topic-release/v1/review/sources` | NEW-BACKEND-ONLY | VISIBLE | `Core/ApprovedTopicReviewRequest.swift:4` |
| `/api/approved-topic-release/v1/review/status` | NEW-BACKEND-ONLY | VISIBLE | `Core/ApprovedTopicReviewRequest.swift:7` |
| `/api/approved-topic-release/v1/review/submit` | NEW-BACKEND-ONLY | VISIBLE | `Core/ApprovedTopicReviewRequest.swift:6` |
| `/api/approved-topic-release/v1/status` | NEW-BACKEND-ONLY | VISIBLE | `Core/ApprovedTopicReleasePublicationClient.swift:8` |
| `/api/asset/withdraw` | NEW-BACKEND-ONLY | HIDDEN | `App/RegionalEndpointAllowlistSectionView.swift:72` |
| `/api/badge/wall-v2` | PROD-SERVED | — | `Core/ProfileService.swift:74` |
| `/api/balance/list` | PROD-SERVED | — | `Core/WalletCommerceSafety.swift:313` |
| `/api/capsules/create` | PROD-SERVED | — | `Core/RoamPassportPrivateToolsReading.swift:54` |
| `/api/capsules/delete` | PROD-SERVED | — | `Core/RoamPassportPrivateToolsReading.swift:54` |
| `/api/capsules/detail` | PROD-SERVED | — | `Core/RoamPassportPrivateToolsReading.swift:53` |
| `/api/capsules/list` | PROD-SERVED | — | `Core/RoamPassportPrivateToolsReading.swift:53` |
| `/api/capsules/receipt` | PROD-SERVED | — | `Core/RoamPassportPrivateToolsReading.swift:53` |
| `/api/cart/cart/add` | PROD-SERVED | — | `Core/WalletCommerceSafety.swift:77` |
| `/api/cart/delete` | PROD-SERVED | — | `Core/WalletCommerceSafety.swift:79` |
| `/api/cart/list` | PROD-SERVED | — | `Core/WalletCommerceSafety.swift:314` |
| `/api/cart/order/settlement` | PROD-SERVED | — | `Core/WalletCommerceSafety.swift:80` |
| `/api/cart/settlement` | PROD-SERVED | — | `Core/WalletCommerceSafety.swift:314` |
| `/api/cart/update` | PROD-SERVED | — | `Core/WalletCommerceSafety.swift:78` |
| `/api/category/list` | PROD-SERVED | — | `App/AppCompositionRoot.swift:2627` |
| `/api/channel-platform/admission/requests` | NEW-BACKEND-ONLY | HIDDEN | `Core/ChannelAdmissionGovernanceClient.swift:16` |
| `/api/channel-platform/governance/moderation/requests` | NEW-BACKEND-ONLY | HIDDEN | `Core/BusinessRuntimeConfiguration.swift:197` |
| `/api/channel-platform/governance/reports/requests` | NEW-BACKEND-ONLY | HIDDEN | `Core/BusinessRuntimeConfiguration.swift:286` |
| `/api/channel-platform/governance/requests` | NEW-BACKEND-ONLY | HIDDEN | `Core/BusinessRuntimeConfiguration.swift:184` |
| `/api/channel-platform/requests` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeChannelManagementFinalForward.swift:85` |
| `/api/channel/{}/board` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeChannelProgressFinalForward.swift:161` |
| `/api/channel/{}/board/{}` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeChannelProgressService.swift:74` |
| `/api/channel/{}/progress/overview` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeChannelProgressFinalForward.swift:162` |
| `/api/channel/{}/progress/privacy` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeProgressPrivacyContracts.swift:17` |
| `/api/channels` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeChannelMentionTargets.swift:30` |
| `/api/channels/member-state-requests` | NEW-BACKEND-ONLY | HIDDEN | `Core/BusinessRuntimeConfiguration.swift:168` |
| `/api/channels/{}` | NEW-BACKEND-ONLY | HIDDEN | `Core/ChannelDirectoryCatalogProducer.swift:25` |
| `/api/channels/{}/archive` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeChannelManagementFinalForward.swift:109` |
| `/api/channels/{}/effective/{}` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeChannelManagementFinalForward.swift:82` |
| `/api/channels/{}/members` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeFriendChannelSourceFlow.swift:12` |
| `/api/channels/{}/op-log` | NEW-BACKEND-ONLY | HIDDEN | `App/AppSession.swift:144` |
| `/api/channels/{}/permissions` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeChannelManagementFinalForward.swift:82` |
| `/api/channels/{}/permissions/{}/{}` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeChannelManagementFinalForward.swift:113` |
| `/api/channels/{}/restore` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeChannelManagementFinalForward.swift:108` |
| `/api/circle-theme/instance/review` | PROD-SERVED | — | `Core/MerchantContentCommands.swift:59` |
| `/api/circle-theme/instance/{}/offers` | PROD-SERVED | — | `Core/PlayCircleRuntime.swift:52` |
| `/api/circle-theme/session` | PROD-SERVED | — | `Core/PlayCircleRuntime.swift:60` |
| `/api/circle-theme/session/join` | PROD-SERVED | — | `Core/PlayCircleRuntime.swift:59` |
| `/api/circle-theme/session/{}/card` | PROD-SERVED | — | `Core/PlayCircleRuntime.swift:65` |
| `/api/city-game` | NEW-BACKEND-ONLY | HIDDEN | `Core/CityPlayerReading.swift:84` |
| `/api/city-game/acquisition` | NEW-BACKEND-ONLY | HIDDEN | `Core/CityAcquisitionService.swift:79` |
| `/api/city-game/action-budget` | NEW-BACKEND-ONLY | HIDDEN | `Core/CityActionBudgetScopedTransport.swift:50` |
| `/api/city-game/action-budget/command` | NEW-BACKEND-ONLY | HIDDEN | `Core/CityActionBudgetRecovery.swift:131` |
| `/api/city-game/action-budget/request/{}` | NEW-BACKEND-ONLY | HIDDEN | `Core/CityActionBudgetReader.swift:45` |
| `/api/city-game/action-budget/state` | NEW-BACKEND-ONLY | HIDDEN | `Core/CityActionBudgetReader.swift:27` |
| `/api/city-game/arrival-evidence` | NEW-BACKEND-ONLY | HIDDEN | `Core/CityArrivalEvidenceService.swift:101` |
| `/api/city-game/merchant/operations` | NEW-BACKEND-ONLY | HIDDEN | `Core/CityMerchantOperationsService.swift:80` |
| `/api/city-game/merchant/operations/availability` | NEW-BACKEND-ONLY | HIDDEN | `Core/CityMerchantOperationsService.swift:140` |
| `/api/city-game/merchant/operations/intent` | NEW-BACKEND-ONLY | HIDDEN | `Core/CityMerchantOperationsService.swift:146` |
| `/api/city-game/merchant/operations/request` | NEW-BACKEND-ONLY | HIDDEN | `Core/CityMerchantOperationsService.swift:149` |
| `/api/city-game/neutral-tasks` | NEW-BACKEND-ONLY | HIDDEN | `Core/CityNeutralTaskService.swift:88` |
| `/api/city-game/onsite-tasks` | NEW-BACKEND-ONLY | HIDDEN | `Core/CityOnsiteTaskService.swift:94` |
| `/api/city-game/player-rules` | NEW-BACKEND-ONLY | HIDDEN | `Core/CityPlayerRulesClient.swift:43` |
| `/api/city-game/state/deltas` | NEW-BACKEND-ONLY | HIDDEN | `Core/CityOrderedMapScopedTransport.swift:49` |
| `/api/city-game/state/snapshot` | NEW-BACKEND-ONLY | HIDDEN | `Core/CityCurrentSnapshotReading.swift:203` |
| `/api/city-game/task-history` | NEW-BACKEND-ONLY | HIDDEN | `Core/CityTaskHistoryService.swift:68` |
| `/api/city-game/team-participation` | NEW-BACKEND-ONLY | HIDDEN | `Core/CityParticipationScopedTransport.swift:50` |
| `/api/city-game/team-participation/command` | NEW-BACKEND-ONLY | HIDDEN | `Core/CityParticipationCommandRecovery.swift:126` |
| `/api/city-game/team-participation/invite` | NEW-BACKEND-ONLY | HIDDEN | `Core/CityParticipationInvitationReading.swift:55` |
| `/api/city-game/team-participation/state` | NEW-BACKEND-ONLY | HIDDEN | `Core/CityParticipationStateReading.swift:133` |
| `/api/city-game/{}/request/{}` | NEW-BACKEND-ONLY | HIDDEN | `Core/CityOriginalReceiptReading.swift:94` |
| `/api/city-value/visits` | NEW-BACKEND-ONLY | HIDDEN | `Core/CityPlayerValueService.swift:61` |
| `/api/city-value/visits/feedback` | NEW-BACKEND-ONLY | HIDDEN | `Core/CityPlayerValueService.swift:67` |
| `/api/city-value/visits/services` | NEW-BACKEND-ONLY | HIDDEN | `Core/CityPlayerValueService.swift:59` |
| `/api/city/nodes` | PROD-SERVED | — | `Core/ManualMapReadApproval.swift:69` |
| `/api/city/nodes/complete` | NEW-BACKEND-ONLY | HIDDEN | `App/AppCompositionRoot.swift:3721` |
| `/api/city/nodes/favorite` | NEW-BACKEND-ONLY | HIDDEN | `App/AppCompositionRoot.swift:3720` |
| `/api/city/nodes/{}` | PROD-SERVED | — | `App/AppCompositionRoot.swift:3753` |
| `/api/city/nodes/{}/complete` | PROD-SERVED | — | `Core/ChallengePOISubmission.swift:59` |
| `/api/city/nodes/{}/favorite` | PROD-SERVED | — | `Core/RoamExperienceMutationContracts.swift:30` |
| `/api/city/walking/target` | NEW-BACKEND-ONLY | HIDDEN | `Core/CityWalkingAuthorityReader.swift:36` |
| `/api/club-compensation/editions` | PROD-SERVED | — | `Core/ClubGovernanceContracts.swift:129` |
| `/api/club-compensation/hours/report` | PROD-SERVED | — | `Core/ClubGovernanceCommands.swift:28` |
| `/api/club-compensation/quality/evidence` | NEW-BACKEND-ONLY | HIDDEN | `Core/ClubGovernanceCommands.swift:29` |
| `/api/club/access/me` | PROD-SERVED | — | `Core/ClubAccessAndSettlementParityAudit.swift:21` |
| `/api/club/activity/cancel` | NEW-BACKEND-ONLY | HIDDEN | `Core/ChannelDiscordMessaging.swift:3022` |
| `/api/club/activity/detail` | NEW-BACKEND-ONLY | HIDDEN | `Core/ChannelDiscordMessaging.swift:3022` |
| `/api/club/activity/join` | NEW-BACKEND-ONLY | HIDDEN | `Core/ChannelDiscordMessaging.swift:3022` |
| `/api/club/admission/receipt` | NEW-BACKEND-ONLY | HIDDEN | `App/AppCompositionRoot.swift:3158` |
| `/api/club/badge/create` | PROD-SERVED | — | `Core/ChannelDiscordMessaging.swift:3041` |
| `/api/club/badge/grant` | PROD-SERVED | — | `Core/ChannelDiscordMessaging.swift:3041` |
| `/api/club/badge/list` | PROD-SERVED | — | `Core/ChannelDiscordMessaging.swift:3041` |
| `/api/club/badge/original-receipt` | NEW-BACKEND-ONLY | HIDDEN | `Core/ClubBadgeManagementModels.swift:90` |
| `/api/club/become-leader` | PROD-SERVED | — | `Core/ClubGovernanceCommands.swift:9` |
| `/api/club/calendar/sessions` | PROD-SERVED | — | `Core/ClubGovernanceService.swift:123` |
| `/api/club/channels` | NEW-BACKEND-ONLY | HIDDEN | `Core/ChannelDiscordMessaging.swift:3008` |
| `/api/club/chat` | PROD-SERVED | — | `App/AppCompositionRoot.swift:4482` |
| `/api/club/create` | PROD-SERVED | — | `Core/ChannelDiscordMessaging.swift:3028` |
| `/api/club/crm/checkin/detail` | PROD-SERVED | — | `Core/ClubGovernanceContracts.swift:108` |
| `/api/club/crm/customers/count` | PROD-SERVED | — | `Core/ChannelDiscordMessaging.swift:3072` |
| `/api/club/crm/customers/detail` | PROD-SERVED | — | `Core/ClubGovernanceContracts.swift:107` |
| `/api/club/crm/customers/list` | PROD-SERVED | — | `Core/ChannelDiscordMessaging.swift:3072` |
| `/api/club/crm/customers/tag-remark` | PROD-SERVED | — | `Core/ClubGovernanceCommands.swift:10` |
| `/api/club/crm/topic-customers` | PROD-SERVED | — | `Core/ClubGovernanceContracts.swift:125` |
| `/api/club/crm/topic-manage-stats` | PROD-SERVED | — | `Core/ClubGovernanceContracts.swift:126` |
| `/api/club/detail` | PROD-SERVED | — | `Core/Adapt3ClubBackendAdapters.swift:97` |
| `/api/club/dissolution-blockers` | PROD-SERVED | — | `Core/ClubGovernanceContracts.swift:130` |
| `/api/club/dissolve` | PROD-SERVED | — | `Core/ClubGovernanceCommands.swift:31` |
| `/api/club/event-notification/audience-counts` | PROD-SERVED | — | `Core/ClubGovernanceContracts.swift:119` |
| `/api/club/event-notification/preview` | PROD-SERVED | — | `Core/ClubGovernanceContracts.swift:120` |
| `/api/club/event-notification/retry` | PROD-SERVED | — | `Core/ClubGovernanceCommands.swift:23` |
| `/api/club/event-notification/send` | PROD-SERVED | — | `Core/ClubGovernanceCommands.swift:22` |
| `/api/club/event-notification/status` | PROD-SERVED | — | `Core/ClubGovernanceContracts.swift:121` |
| `/api/club/event-ops/attendance/correct` | PROD-SERVED | — | `Core/ClubGovernanceCommands.swift:14` |
| `/api/club/event-ops/cancel` | PROD-SERVED | — | `Core/ClubGovernanceCommands.swift:13` |
| `/api/club/event-ops/occurrence/status` | PROD-SERVED | — | `Core/ClubGovernanceContracts.swift:114` |
| `/api/club/event-ops/roster` | PROD-SERVED | — | `Core/ClubGovernanceContracts.swift:115` |
| `/api/club/event-ops/series/create` | PROD-SERVED | — | `Core/ClubGovernanceCommands.swift:11` |
| `/api/club/event-ops/series/detail` | PROD-SERVED | — | `Core/ClubGovernanceContracts.swift:112` |
| `/api/club/event-ops/series/list` | PROD-SERVED | — | `Core/ClubGovernanceContracts.swift:111` |
| `/api/club/event-ops/series/occurrences` | PROD-SERVED | — | `Core/ClubGovernanceContracts.swift:113` |
| `/api/club/event-ops/series/original-result` | NEW-BACKEND-ONLY | HIDDEN | `Core/ClubSeriesOriginalResult.swift:9` |
| `/api/club/event-ops/series/update-future` | PROD-SERVED | — | `Core/ClubGovernanceCommands.swift:12` |
| `/api/club/event-ops/topics` | PROD-SERVED | — | `Core/ClubGovernanceContracts.swift:110` |
| `/api/club/event-ops/waitlist/cancel` | PROD-SERVED | — | `Core/RegistrationProduction.swift:20` |
| `/api/club/event-ops/waitlist/join` | PROD-SERVED | — | `Core/RegistrationProduction.swift:20` |
| `/api/club/event-ops/waitlist/status` | PROD-SERVED | — | `Core/RegistrationProduction.swift:20` |
| `/api/club/event-ops/waitlist/{}` | PROD-SERVED | — | `Core/RegistrationProduction.swift:262` |
| `/api/club/events` | NEW-BACKEND-ONLY | HIDDEN | `Core/ChannelDiscordMessaging.swift:3081` |
| `/api/club/events/Checkin` | NEW-BACKEND-ONLY | HIDDEN | `Core/ChannelDiscordMessaging.swift:3083` |
| `/api/club/events/proxy-enroll` | NEW-BACKEND-ONLY | HIDDEN | `Core/ChannelDiscordMessaging.swift:3084` |
| `/api/club/events/save` | NEW-BACKEND-ONLY | HIDDEN | `Core/ChannelDiscordMessaging.swift:3082` |
| `/api/club/governance/ban` | PROD-SERVED | — | `Core/ChannelDiscordMessaging.swift:1433` |
| `/api/club/governance/cases/appeal` | PROD-SERVED | — | `Core/ClubGovernanceCommands.swift:19` |
| `/api/club/governance/cases/mine` | PROD-SERVED | — | `Core/ClubGovernanceContracts.swift:117` |
| `/api/club/governance/cases/report` | PROD-SERVED | — | `Core/ChannelDiscordMessaging.swift:1421` |
| `/api/club/governance/list` | PROD-SERVED | — | `Core/ClubGovernanceContracts.swift:116` |
| `/api/club/governance/owner/transfer` | PROD-SERVED | — | `Core/ClubGovernanceCommands.swift:17` |
| `/api/club/governance/unban` | PROD-SERVED | — | `Core/ChannelDiscordMessaging.swift:1435` |
| `/api/club/group-code` | NEW-BACKEND-ONLY | HIDDEN | `Core/ChannelDiscordMessaging.swift:3055` |
| `/api/club/group-code/save` | NEW-BACKEND-ONLY | HIDDEN | `Core/ChannelDiscordMessaging.swift:3055` |
| `/api/club/home` | PROD-SERVED | — | `Core/ClubService.swift:14` |
| `/api/club/join` | PROD-SERVED | — | `App/AppCompositionRoot.swift:3156` |
| `/api/club/join-request/approve` | PROD-SERVED | — | `Core/Adapt3ClubBackendAdapters.swift:76` |
| `/api/club/join-request/reject` | PROD-SERVED | — | `Core/Adapt3ClubBackendAdapters.swift:76` |
| `/api/club/join-requests` | PROD-SERVED | — | `Core/ChannelDiscordMessaging.swift:3091` |
| `/api/club/join-requests/apply` | NEW-BACKEND-ONLY | HIDDEN | `Core/ChannelDiscordMessaging.swift:3015` |
| `/api/club/lead` | PROD-SERVED | — | `Core/PlayExperienceService.swift:155` |
| `/api/club/lead/edit-ops` | PROD-SERVED | — | `Core/ClubContextualOperations.swift:88` |
| `/api/club/lead/team-progress` | PROD-SERVED | — | `Core/ContextualOperationProduction.swift:46` |
| `/api/club/leaderboard` | PROD-SERVED | — | `Core/ClubGovernanceContracts.swift:131` |
| `/api/club/list` | PROD-SERVED | — | `App/AppCompositionRoot.swift:2627` |
| `/api/club/members` | PROD-SERVED | — | `Core/ClubBadgeManagementModels.swift:88` |
| `/api/club/merchants` | PROD-SERVED | — | `Core/CooperationFlowService.swift:26` |
| `/api/club/my` | PROD-SERVED | — | `Core/ChannelDiscordMessaging.swift:3001` |
| `/api/club/notices` | NEW-BACKEND-ONLY | HIDDEN | `Core/ChannelDiscordMessaging.swift:3048` |
| `/api/club/notices/send` | NEW-BACKEND-ONLY | HIDDEN | `Core/ChannelDiscordMessaging.swift:3048` |
| `/api/club/open-settings/member-post` | PROD-SERVED | — | `Core/ClubOperationsContracts.swift:9` |
| `/api/club/open-settings/merchant-coop` | PROD-SERVED | — | `Core/ClubOperationsContracts.swift:10` |
| `/api/club/open-settings/public-visible` | PROD-SERVED | — | `Core/ClubOperationsContracts.swift:8` |
| `/api/club/open-settings/welcome-note` | PROD-SERVED | — | `Core/Adapt3ClubBackendAdapters.swift:91` |
| `/api/club/open-settings/welcome-note-receipt` | NEW-BACKEND-ONLY | HIDDEN | `Core/ClubWelcomeNoteFlow.swift:344` |
| `/api/club/post` | PROD-SERVED | — | `Core/ClubCommunityService.swift:27` |
| `/api/club/post/comment/list` | PROD-SERVED | — | `Core/ClubCommunityReadRuntime.swift:13` |
| `/api/club/post/delete` | PROD-SERVED | — | `Core/ChannelDiscordMessaging.swift:1429` |
| `/api/club/post/feed` | PROD-SERVED | — | `Core/ClubCommunityReadRuntime.swift:12` |
| `/api/club/post/history` | PROD-SERVED | — | `Core/ClubCommunityReadRuntime.swift:14` |
| `/api/club/post/list` | PROD-SERVED | — | `Core/ClubCommunityReadRuntime.swift:11` |
| `/api/club/post/operation` | NEW-BACKEND-ONLY | HIDDEN | `Core/ClubPostOriginalRuntime.swift:13` |
| `/api/club/post/operation/comment` | NEW-BACKEND-ONLY | HIDDEN | `Core/ClubCommentOriginalRuntime.swift:13` |
| `/api/club/post/operation/receipt` | NEW-BACKEND-ONLY | HIDDEN | `Core/ClubCommunityPendingJournal.swift:410` |
| `/api/club/post/repost` | PROD-SERVED | — | `Core/ClubPostRepostToggle.swift:8` |
| `/api/club/post/repost/undo` | PROD-SERVED | — | `Core/ClubPostRepostToggle.swift:9` |
| `/api/club/quit` | PROD-SERVED | — | `App/AppCompositionRoot.swift:3157` |
| `/api/club/recruit/overview` | PROD-SERVED | — | `Core/ClubGovernanceContracts.swift:127` |
| `/api/club/remove-member` | PROD-SERVED | — | `Core/ChannelDiscordMessaging.swift:1431` |
| `/api/club/roles/assign` | PROD-SERVED | — | `Core/Adapt3ClubBackendAdapters.swift:109` |
| `/api/club/roles/assign-receipt` | NEW-BACKEND-ONLY | HIDDEN | `Core/ClubRoleAssignmentOriginal.swift:40` |
| `/api/club/roles/list` | PROD-SERVED | — | `Core/ChannelDiscordMessaging.swift:3035` |
| `/api/club/roles/revoke` | PROD-SERVED | — | `Core/Adapt3ClubBackendAdapters.swift:121` |
| `/api/club/roles/revoke-receipt` | NEW-BACKEND-ONLY | HIDDEN | `Core/ClubRoleRevocationOriginal.swift:40` |
| `/api/club/set-member-role` | PROD-SERVED | — | `Core/ClubOperationsContracts.swift:137` |
| `/api/club/settings/notify-level` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeChannelNotificationFinalForward.swift:91` |
| `/api/club/settlement/summary` | PROD-SERVED | — | `Core/ClubGovernanceContracts.swift:109` |
| `/api/club/settlements` | NEW-BACKEND-ONLY | HIDDEN | `Core/ChannelDiscordMessaging.swift:3098` |
| `/api/club/settlements/export` | NEW-BACKEND-ONLY | HIDDEN | `Core/ChannelDiscordMessaging.swift:3098` |
| `/api/club/topic-node-answer` | PROD-SERVED | — | `Core/ClubGovernanceContracts.swift:128` |
| `/api/club/topic-registrations` | PROD-SERVED | — | `Core/ClubGovernanceContracts.swift:134` |
| `/api/club/topic-setting/detail` | PROD-SERVED | — | `Core/ClubGovernanceContracts.swift:124` |
| `/api/club/topic-setting/end` | PROD-SERVED | — | `Core/ClubGovernanceCommands.swift:25` |
| `/api/club/topic-setting/save` | PROD-SERVED | — | `Core/ClubGovernanceCommands.swift:24` |
| `/api/club/topics` | PROD-SERVED | — | `Core/ClubGovernanceContracts.swift:122` |
| `/api/club/update` | NEW-BACKEND-ONLY | HIDDEN | `Core/ChannelDiscordMessaging.swift:3029` |
| `/api/club/update-mine` | PROD-SERVED | — | `Core/ClubOperationsContracts.swift:135` |
| `/api/club/workbench` | NEW-BACKEND-ONLY | HIDDEN | `Core/ChannelDiscordMessaging.swift:3066` |
| `/api/comment/add` | PROD-SERVED | — | `Core/ContextualOperationProduction.swift:59` |
| `/api/comment/delete` | PROD-SERVED | — | `Core/SquareGovernanceService.swift:117` |
| `/api/comment/like` | PROD-SERVED | — | `Core/SocialActionContracts.swift:169` |
| `/api/comment/list` | PROD-SERVED | — | `App/PublishTopicAndCommentModerationSectionView.swift:79` |
| `/api/comment/report` | PROD-SERVED | — | `Core/SocialActionContracts.swift:172` |
| `/api/common/banner` | PROD-SERVED | — | `App/AppCompositionRoot.swift:2627` |
| `/api/common/dict` | PROD-SERVED | — | `App/AppCompositionRoot.swift:2794` |
| `/api/common/infomation_detail` | PROD-SERVED | — | `Core/ProfileGuideRead.swift:26` |
| `/api/common/infomation_list` | PROD-SERVED | — | `Core/ProfileGuideRead.swift:25` |
| `/api/common/uploadOSS` | PROD-SERVED | — | `App/AppCompositionRoot.swift:3719` |
| `/api/common/uploadOSS/receipt` | NEW-BACKEND-ONLY | HIDDEN | `Core/BusinessRuntimeConfiguration.swift:278` |
| `/api/community-trust/reports/mine` | PROD-SERVED | — | `Core/MemberReportProgressContracts.swift:148` |
| `/api/community-trust/reports/submit` | NEW-BACKEND-ONLY | HIDDEN | `App/PublishTopicAndCommentModerationSectionView.swift:80` |
| `/api/community-trust/reports/taxonomy` | PROD-SERVED | — | `Core/MemberReportProgressContracts.swift:150` |
| `/api/community-trust/reports/{}` | PROD-SERVED | — | `Core/MemberReportProgressContracts.swift:149` |
| `/api/compliance/consents` | PROD-SERVED | — | `App/AppCompositionRoot.swift:3851` |
| `/api/compliance/consents/latest` | PROD-SERVED | — | `App/AppCompositionRoot.swift:3852` |
| `/api/compliance/usage-records` | NEW-BACKEND-ONLY | HIDDEN | `Core/UsageConsentRead.swift:38` |
| `/api/config/features` | PROD-SERVED | — | `Core/LaunchFeatureFlags.swift:121` |
| `/api/content-draft` | PROD-SERVED | — | `Core/VersionedContentDraftService.swift:7` |
| `/api/coop` | PROD-SERVED | — | `Core/CooperationFlowContracts.swift:294` |
| `/api/coop/candidates` | PROD-SERVED | — | `Core/CooperationService.swift:37` |
| `/api/coop/candidates/received` | PROD-SERVED | — | `Core/CooperationFlowService.swift:18` |
| `/api/coop/complaint/mine` | PROD-SERVED | — | `Core/CooperationFlowService.swift:22` |
| `/api/coop/complaint/topics` | PROD-SERVED | — | `Core/CooperationFlowService.swift:22` |
| `/api/coop/credit` | PROD-SERVED | — | `Core/CooperationFlowService.swift:21` |
| `/api/coop/deposit/create/app` | PROD-SERVED | — | `Core/CooperationFlowContracts.swift:474` |
| `/api/coop/deposit/refund/retry` | PROD-SERVED | — | `Core/CooperationFlowContracts.swift:476` |
| `/api/coop/deposit/status` | PROD-SERVED | — | `Core/CooperationFlowContracts.swift:475` |
| `/api/coop/finance` | PROD-SERVED | — | `Core/CooperationFlowService.swift:19` |
| `/api/coop/list` | PROD-SERVED | — | `Core/CooperationFlowService.swift:16` |
| `/api/coop/mybiz` | PROD-SERVED | — | `Core/CooperationFlowService.swift:19` |
| `/api/coop/offer/withdraw` | PROD-SERVED | — | `Core/MerchantOfferWithdrawal.swift:53` |
| `/api/coop/perk-template/list` | PROD-SERVED | — | `Core/CooperationFlowService.swift:20` |
| `/api/coop/perks/list` | PROD-SERVED | — | `Core/CooperationFlowService.swift:20` |
| `/api/coop/pool/list` | PROD-SERVED | — | `Core/CooperationFlowService.swift:16` |
| `/api/coop/pool/mine` | PROD-SERVED | — | `Core/CooperationFlowService.swift:17` |
| `/api/coop/pool/received` | PROD-SERVED | — | `Core/CooperationFlowService.swift:17` |
| `/api/coop/review/summary` | PROD-SERVED | — | `Core/CooperationFlowService.swift:21` |
| `/api/coupon` | PROD-SERVED | — | `App/AppSession.swift:4418` |
| `/api/coupon/command-receipt` | NEW-BACKEND-ONLY | HIDDEN | `App/AppCompositionRoot.swift:2800` |
| `/api/coupon/mypublishlist` | PROD-SERVED | — | `Core/CouponManagementContract.swift:15` |
| `/api/coupon/myrecvlist` | PROD-SERVED | — | `Core/AccountCollectionService.swift:27` |
| `/api/coupon/publish` | PROD-SERVED | — | `App/AppSession.swift:4385` |
| `/api/coupon/qr-token` | PROD-SERVED | — | `App/AppCompositionRoot.swift:4173` |
| `/api/coupon/status` | PROD-SERVED | — | `App/AppCompositionRoot.swift:4174` |
| `/api/coupon/stop` | PROD-SERVED | — | `App/AppSession.swift:4385` |
| `/api/coupon/verification` | PROD-SERVED | — | `Core/BusinessRuntimeConfiguration.swift:346` |
| `/api/creativesquare/action` | PROD-SERVED | — | `Core/SocialActionContracts.swift:150` |
| `/api/creativesquare/bookmark` | PROD-SERVED | — | `Core/ProfileFavoriteRemoval.swift:20` |
| `/api/creativesquare/info` | PROD-SERVED | — | `Core/ProfileFavoriteRemoval.swift:20` |
| `/api/creativesquare/like` | PROD-SERVED | — | `Core/SocialActionContracts.swift:175` |
| `/api/creativesquare/list` | PROD-SERVED | — | `Core/AccountCollectionService.swift:19` |
| `/api/creativesquare/report` | PROD-SERVED | — | `Core/SocialActionContracts.swift:178` |
| `/api/creator/apply` | PROD-SERVED | — | `Core/CreatorApplication.swift:50` |
| `/api/creator/center` | PROD-SERVED | — | `Core/CreatorContentService.swift:27` |
| `/api/exploration-anniversary` | PROD-SERVED | — | `Core/RoamPassportTools.swift:278` |
| `/api/exploration-goals/cancel` | PROD-SERVED | — | `Core/RoamPassportPrivateToolsReading.swift:56` |
| `/api/exploration-goals/create` | PROD-SERVED | — | `Core/RoamPassportPrivateToolsReading.swift:56` |
| `/api/exploration-goals/detail` | PROD-SERVED | — | `Core/RoamPassportPrivateToolsReading.swift:55` |
| `/api/exploration-goals/list` | PROD-SERVED | — | `Core/RoamPassportPrivateToolsReading.swift:55` |
| `/api/exploration-goals/receipt` | PROD-SERVED | — | `Core/RoamPassportPrivateToolsReading.swift:55` |
| `/api/free-explore/bundle` | PROD-SERVED | — | `App/BundleReadTransport.swift:37` |
| `/api/free-explore/bundle/reservation` | PROD-SERVED | — | `App/BundleCancelTransport.swift:44` |
| `/api/free-explore/bundle/transfer` | NEW-BACKEND-ONLY | HIDDEN | `App/BundleTransferTransport.swift:18` |
| `/api/free-explore/bundle/voucher/appeal` | NEW-BACKEND-ONLY | HIDDEN | `App/BundleAppealTransport.swift:31` |
| `/api/friend` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeFriendService.swift:127` |
| `/api/friend/accept` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeFriendService.swift:14` |
| `/api/friend/cancel` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeFriendService.swift:14` |
| `/api/friend/channel-invite` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeFriendChannelInviteService.swift:11` |
| `/api/friend/directory` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeFriendDirectoryService.swift:11` |
| `/api/friend/directory/detail` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeFriendDirectoryService.swift:11` |
| `/api/friend/group/delete` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeFriendMetadataContracts.swift:46` |
| `/api/friend/group/list` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeFriendMetadataService.swift:16` |
| `/api/friend/group/save` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeFriendMetadataContracts.swift:46` |
| `/api/friend/list` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeFriendService.swift:13` |
| `/api/friend/metadata` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeFriendMetadataService.swift:15` |
| `/api/friend/metadata/receipt` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeFriendMetadataService.swift:15` |
| `/api/friend/metadata/settle` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeFriendMetadataService.swift:17` |
| `/api/friend/progress` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeFriendProgressService.swift:11` |
| `/api/friend/receipt` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeFriendService.swift:13` |
| `/api/friend/reject` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeFriendService.swift:14` |
| `/api/friend/relationship` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeFriendRemovalService.swift:12` |
| `/api/friend/remark` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeFriendMetadataContracts.swift:46` |
| `/api/friend/removal/receipt` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeFriendRemovalService.swift:12` |
| `/api/friend/removal/settle` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeFriendRemovalService.swift:14` |
| `/api/friend/remove` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeFriendRemovalService.swift:13` |
| `/api/friend/request` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeFriendService.swift:14` |
| `/api/friend/requests` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeFriendService.swift:13` |
| `/api/friend/team-invite` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeFriendTeamInviteService.swift:7` |
| `/api/fund/preflight/bank-withdrawal` | PROD-SERVED | — | `Core/BankWithdrawalAdapter.swift:106` |
| `/api/fund/preflight/{}` | PROD-SERVED | — | `Core/BankWithdrawalConsentReader.swift:68` |
| `/api/fund/preflight/{}/confirm` | PROD-SERVED | — | `Core/BankWithdrawalAdapter.swift:135` |
| `/api/fund/preflight/{}/reject` | PROD-SERVED | — | `Core/BankWithdrawalAdapter.swift:163` |
| `/api/game/session` | PROD-SERVED | — | `Core/PlayExperienceService.swift:296` |
| `/api/game/session/command` | PROD-SERVED | — | `Core/MerchantContentCommands.swift:104` |
| `/api/game/session/merchant/entries` | PROD-SERVED | — | `Core/MerchantContentService.swift:311` |
| `/api/game/session/recap/export` | PROD-SERVED | — | `Core/PlayDirectorRecap.swift:67` |
| `/api/game/session/receipt` | PROD-SERVED | — | `App/AppSession.swift:3295` |
| `/api/game/session/view` | PROD-SERVED | — | `App/AppSession.swift:3144` |
| `/api/growth/center` | PROD-SERVED | — | `Core/GrowthCenterService.swift:16` |
| `/api/growth/leaderboard` | PROD-SERVED | — | `Core/GrowthCenterService.swift:27` |
| `/api/growth/leaderboard/anonymous` | NEW-BACKEND-ONLY | HIDDEN | `Core/GrowthCenterService.swift:22` |
| `/api/guilds/{}/{}/channels` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeChannelManagementFinalForward.swift:68` |
| `/api/guilds/{}/{}/channels/manage` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeChannelManagementService.swift:272` |
| `/api/im/appeals` | NEW-BACKEND-ONLY | HIDDEN | `Core/BusinessRuntimeConfiguration.swift:220` |
| `/api/im/appeals/{}/evidence` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeChannelAppealFlow.swift:98` |
| `/api/im/appeals/{}/withdraw` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeChannelAppealFlow.swift:99` |
| `/api/im/audit-log` | NEW-BACKEND-ONLY | HIDDEN | `App/AppSession.swift:127` |
| `/api/im/block` | PROD-SERVED | — | `App/AppCompositionRoot.swift:4187` |
| `/api/im/chain` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeChannelChain.swift:34` |
| `/api/im/chain/close` | NEW-BACKEND-ONLY | HIDDEN | `Core/BusinessRuntimeConfiguration.swift:237` |
| `/api/im/chain/create` | NEW-BACKEND-ONLY | HIDDEN | `Core/BusinessRuntimeConfiguration.swift:234` |
| `/api/im/chain/info` | NEW-BACKEND-ONLY | HIDDEN | `Core/BusinessRuntimeConfiguration.swift:232` |
| `/api/im/chain/join` | NEW-BACKEND-ONLY | HIDDEN | `Core/BusinessRuntimeConfiguration.swift:235` |
| `/api/im/chain/withdraw` | NEW-BACKEND-ONLY | HIDDEN | `Core/BusinessRuntimeConfiguration.swift:236` |
| `/api/im/channel` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeChannelCheckin.swift:178` |
| `/api/im/channel/checkin` | NEW-BACKEND-ONLY | HIDDEN | `Core/BusinessRuntimeConfiguration.swift:229` |
| `/api/im/channel/checkin-rank` | NEW-BACKEND-ONLY | HIDDEN | `Core/BusinessRuntimeConfiguration.swift:230` |
| `/api/im/channel/checkin-request` | NEW-BACKEND-ONLY | HIDDEN | `Core/BusinessRuntimeConfiguration.swift:231` |
| `/api/im/channel/checkin-status` | NEW-BACKEND-ONLY | HIDDEN | `Core/BusinessRuntimeConfiguration.swift:228` |
| `/api/im/conversations` | PROD-SERVED | — | `Core/Adapt1IMBackendAdapter.swift:14` |
| `/api/im/delete` | PROD-SERVED | — | `App/AppCompositionRoot.swift:4180` |
| `/api/im/device/attempts` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativePushAttemptRead.swift:67` |
| `/api/im/file/message` | NEW-BACKEND-ONLY | HIDDEN | `Core/BusinessRuntimeConfiguration.swift:244` |
| `/api/im/file/message/{}/authorization` | NEW-BACKEND-ONLY | HIDDEN | `Core/IMFileService.swift:70` |
| `/api/im/file/message/{}/preview` | NEW-BACKEND-ONLY | HIDDEN | `Core/IMFileService.swift:89` |
| `/api/im/file/receipt` | NEW-BACKEND-ONLY | HIDDEN | `Core/BusinessRuntimeConfiguration.swift:239` |
| `/api/im/file/scan` | NEW-BACKEND-ONLY | HIDDEN | `Core/BusinessRuntimeConfiguration.swift:240` |
| `/api/im/file/upload` | NEW-BACKEND-ONLY | HIDDEN | `Core/BusinessRuntimeConfiguration.swift:238` |
| `/api/im/interaction/request` | NEW-BACKEND-ONLY | HIDDEN | `Core/BusinessRuntimeConfiguration.swift:233` |
| `/api/im/members/{}/roles` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeChannelRoleFlow.swift:301` |
| `/api/im/message` | NEW-BACKEND-ONLY | HIDDEN | `Core/BusinessRuntimeConfiguration.swift:163` |
| `/api/im/message/context` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeChannelMessageFinalForward.swift:100` |
| `/api/im/message/edit` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeChannelMessageFinalForward.swift:84` |
| `/api/im/message/mutations` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeChannelMessageFinalForward.swift:107` |
| `/api/im/message/recall` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeChannelMessageFinalForward.swift:85` |
| `/api/im/message/request` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeChannelMessageFinalForward.swift:96` |
| `/api/im/message/{}/attachment` | NEW-BACKEND-ONLY | HIDDEN | `App/NativeChannelAttachmentPreviewAssembly.swift:15` |
| `/api/im/message/{}/revisions` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeChannelMessageFinalForward.swift:123` |
| `/api/im/messages` | PROD-SERVED | — | `Core/MessagingHistoryReadApproval.swift:67` |
| `/api/im/moderation` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeChannelModerationFlow.swift:61` |
| `/api/im/moderation/actions` | NEW-BACKEND-ONLY | HIDDEN | `Core/BusinessRuntimeConfiguration.swift:195` |
| `/api/im/moderation/ban` | NEW-BACKEND-ONLY | HIDDEN | `Core/BusinessRuntimeConfiguration.swift:202` |
| `/api/im/moderation/kick` | NEW-BACKEND-ONLY | HIDDEN | `Core/BusinessRuntimeConfiguration.swift:202` |
| `/api/im/moderation/me` | NEW-BACKEND-ONLY | HIDDEN | `Core/BusinessRuntimeConfiguration.swift:217` |
| `/api/im/moderation/timeout` | NEW-BACKEND-ONLY | HIDDEN | `Core/BusinessRuntimeConfiguration.swift:202` |
| `/api/im/moderation/{}/revoke` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeChannelModerationFlow.swift:66` |
| `/api/im/mute` | PROD-SERVED | — | `App/AppCompositionRoot.swift:4183` |
| `/api/im/mute-receipt` | NEW-BACKEND-ONLY | HIDDEN | `Core/BusinessRuntimeConfiguration.swift:281` |
| `/api/im/mute-state` | NEW-BACKEND-ONLY | HIDDEN | `Core/BusinessRuntimeConfiguration.swift:282` |
| `/api/im/notification-requests` | NEW-BACKEND-ONLY | HIDDEN | `Core/ChannelGovernanceProjection.swift:443` |
| `/api/im/notify-log` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeChannelNotificationFinalForward.swift:79` |
| `/api/im/notify-pref` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeChannelNotificationFinalForward.swift:75` |
| `/api/im/pin` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeChannelMessageFinalForward.swift:86` |
| `/api/im/pins` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeChannelMessageFinalForward.swift:101` |
| `/api/im/pins/sort` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeChannelMessageFinalForward.swift:88` |
| `/api/im/poll/close` | PROD-SERVED | — | `Core/BusinessRuntimeConfiguration.swift:310` |
| `/api/im/poll/create` | PROD-SERVED | — | `App/GroupPollViews.swift:169` |
| `/api/im/poll/create-receipt` | NEW-BACKEND-ONLY | HIDDEN | `Core/BusinessRuntimeConfiguration.swift:155` |
| `/api/im/poll/result` | PROD-SERVED | — | `Core/BusinessRuntimeConfiguration.swift:307` |
| `/api/im/poll/vote` | PROD-SERVED | — | `Core/BusinessRuntimeConfiguration.swift:309` |
| `/api/im/read` | PROD-SERVED | — | `App/AppCompositionRoot.swift:4181` |
| `/api/im/read-receipt` | NEW-BACKEND-ONLY | HIDDEN | `Core/BusinessRuntimeConfiguration.swift:279` |
| `/api/im/read-state` | NEW-BACKEND-ONLY | HIDDEN | `Core/BusinessRuntimeConfiguration.swift:280` |
| `/api/im/report` | PROD-SERVED | — | `App/AppCompositionRoot.swift:4185` |
| `/api/im/roles` | NEW-BACKEND-ONLY | HIDDEN | `Core/BusinessRuntimeConfiguration.swift:156` |
| `/api/im/roles/{}/members` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeChannelRoleFlow.swift:301` |
| `/api/im/route-share-source` | NEW-BACKEND-ONLY | HIDDEN | `Core/BusinessRuntimeConfiguration.swift:274` |
| `/api/im/search` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeChannelMessageFinalForward.swift:112` |
| `/api/im/send` | PROD-SERVED | — | `App/AppCompositionRoot.swift:4480` |
| `/api/im/send-receipt` | PROD-SERVED | — | `App/AppCompositionRoot.swift:4480` |
| `/api/im/start` | PROD-SERVED | — | `App/AppCompositionRoot.swift:4189` |
| `/api/im/unblock` | PROD-SERVED | — | `App/AppCompositionRoot.swift:4188` |
| `/api/im/unpin` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeChannelMessageFinalForward.swift:87` |
| `/api/im/unread-summary` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeChannelNotificationFinalForward.swift:76` |
| `/api/im/unread-total` | PROD-SERVED | — | `App/AppCompositionRoot.swift:4481` |
| `/api/im/video/message` | NEW-BACKEND-ONLY | HIDDEN | `Core/BusinessRuntimeConfiguration.swift:255` |
| `/api/im/video/message/{}/authorization` | NEW-BACKEND-ONLY | HIDDEN | `Core/IMVideoService.swift:74` |
| `/api/im/video/message/{}/preview` | NEW-BACKEND-ONLY | HIDDEN | `Core/IMVideoService.swift:93` |
| `/api/im/video/policy` | NEW-BACKEND-ONLY | HIDDEN | `Core/BusinessRuntimeConfiguration.swift:251` |
| `/api/im/video/receipt` | NEW-BACKEND-ONLY | HIDDEN | `Core/BusinessRuntimeConfiguration.swift:250` |
| `/api/im/video/upload` | NEW-BACKEND-ONLY | HIDDEN | `Core/BusinessRuntimeConfiguration.swift:249` |
| `/api/im/voice/message` | NEW-BACKEND-ONLY | HIDDEN | `Core/BusinessRuntimeConfiguration.swift:263` |
| `/api/im/voice/message/{}` | NEW-BACKEND-ONLY | HIDDEN | `Core/IMVoiceService.swift:58` |
| `/api/im/voice/message/{}/authorization` | NEW-BACKEND-ONLY | HIDDEN | `Core/IMVoiceService.swift:66` |
| `/api/im/voice/receipt` | NEW-BACKEND-ONLY | HIDDEN | `Core/BusinessRuntimeConfiguration.swift:261` |
| `/api/im/voice/upload` | NEW-BACKEND-ONLY | HIDDEN | `Core/BusinessRuntimeConfiguration.swift:260` |
| `/api/im/webhook` | NEW-BACKEND-ONLY | HIDDEN | `App/NativeWebhookRuntimeConfiguration.swift:15` |
| `/api/im/webhook/context` | NEW-BACKEND-ONLY | HIDDEN | `App/NativeWebhookRuntimeConfiguration.swift:14` |
| `/api/im/{}` | PROD-SERVED | — | `Core/IMExpandedService.swift:73` |
| `/api/invite/revoke` | NEW-BACKEND-ONLY | HIDDEN | `Core/ChannelAdmissionGovernanceClient.swift:15` |
| `/api/invoice` | PROD-SERVED | — | `Core/InvoiceLaunchContracts.swift:16` |
| `/api/join-request/approve` | NEW-BACKEND-ONLY | HIDDEN | `Core/ChannelAdmissionGovernanceClient.swift:11` |
| `/api/join-request/cancel` | NEW-BACKEND-ONLY | HIDDEN | `Core/ChannelAdmissionGovernanceClient.swift:10` |
| `/api/join-request/reject` | NEW-BACKEND-ONLY | HIDDEN | `Core/ChannelAdmissionGovernanceClient.swift:12` |
| `/api/join-request/submit` | NEW-BACKEND-ONLY | HIDDEN | `Core/ChannelAdmissionGovernanceClient.swift:9` |
| `/api/location-share/personal` | NEW-BACKEND-ONLY | HIDDEN | `Core/PersonalLocationShareHTTPService.swift:66` |
| `/api/login` | PROD-SERVED | — | `Core/APIConfiguration.swift:28` |
| `/api/login/apple` | PROD-SERVED | — | `Core/APIConfiguration.swift:30` |
| `/api/login/phone` | PROD-SERVED | — | `Core/APIConfiguration.swift:32` |
| `/api/login/wechat/app` | PROD-SERVED | — | `Core/APIConfiguration.swift:29` |
| `/api/logout` | PROD-SERVED | — | `Core/APIConfiguration.swift:34` |
| `/api/map/nearby` | PROD-SERVED | — | `App/AppCompositionRoot.swift:3734` |
| `/api/map/public-layers` | NEW-BACKEND-ONLY | VISIBLE | `App/AppCompositionRoot.swift:2037` |
| `/api/map/reverse-geocode` | PROD-SERVED | — | `Core/SearchMapService.swift:102` |
| `/api/medal/wall` | PROD-SERVED | — | `Core/ProfileService.swift:76` |
| `/api/media/asset/list` | PROD-SERVED | — | `Core/OwnMediaReview.swift:80` |
| `/api/media/asset/{}` | PROD-SERVED | — | `Core/ClubProfileMediaUpload.swift:213` |
| `/api/media/asset/{}/preview` | PROD-SERVED | — | `Core/OwnMediaAudioPreview.swift:45` |
| `/api/member/reputation` | PROD-SERVED | — | `Core/MemberScoreAppealReadContracts.swift:108` |
| `/api/merchant/access/me` | PROD-SERVED | — | `App/AppCompositionRoot.swift:759` |
| `/api/merchant/aftercare/detail` | PROD-SERVED | — | `Core/MerchantBusinessQuery.swift:79` |
| `/api/merchant/aftercare/list` | PROD-SERVED | — | `Core/MerchantBusinessQuery.swift:78` |
| `/api/merchant/aftercare/respond` | PROD-SERVED | — | `Core/MerchantBusinessMutation.swift:89` |
| `/api/merchant/authoring/draft-selection/list` | NEW-BACKEND-ONLY | HIDDEN | `Core/ProjectMerchantDraftSelection.swift:7` |
| `/api/merchant/authoring/draft-selection/resolve` | NEW-BACKEND-ONLY | HIDDEN | `Core/ProjectMerchantDraftSelection.swift:8` |
| `/api/merchant/authoring/drafts` | NEW-BACKEND-ONLY | HIDDEN | `Core/MerchantAuthoringService.swift:12` |
| `/api/merchant/authoring/drafts/{}` | NEW-BACKEND-ONLY | HIDDEN | `Core/MerchantAuthoringService.swift:21` |
| `/api/merchant/authoring/environment` | NEW-BACKEND-ONLY | HIDDEN | `Core/MerchantAuthoringService.swift:15` |
| `/api/merchant/authoring/jobs` | NEW-BACKEND-ONLY | HIDDEN | `Core/MerchantAuthoringService.swift:10` |
| `/api/merchant/authoring/jobs/cancel` | NEW-BACKEND-ONLY | HIDDEN | `Core/MerchantAuthoringService.swift:11` |
| `/api/merchant/authoring/main-line` | NEW-BACKEND-ONLY | HIDDEN | `Core/MerchantAuthoringService.swift:16` |
| `/api/merchant/authoring/player` | NEW-BACKEND-ONLY | HIDDEN | `Core/MerchantGamePlayerReadGrant.swift:46` |
| `/api/merchant/authoring/player/{merchantId}/game` | NEW-BACKEND-ONLY | HIDDEN | `Core/MerchantGamePlayerReadGrant.swift:19` |
| `/api/merchant/authoring/player/{merchantId}/requests/{requestId}` | NEW-BACKEND-ONLY | HIDDEN | `Core/MerchantGamePlayerReadGrant.swift:20` |
| `/api/merchant/authoring/player/{}/game` | NEW-BACKEND-ONLY | HIDDEN | `Core/MerchantGamePlayer.swift:79` |
| `/api/merchant/authoring/player/{}/requests/{}` | NEW-BACKEND-ONLY | HIDDEN | `Core/MerchantGamePlayer.swift:99` |
| `/api/merchant/authoring/public` | NEW-BACKEND-ONLY | HIDDEN | `Core/MerchantAuthoringService.swift:14` |
| `/api/merchant/authoring/releases` | NEW-BACKEND-ONLY | HIDDEN | `Core/MerchantAuthoringService.swift:13` |
| `/api/merchant/authoring/releases/{}/withdraw` | NEW-BACKEND-ONLY | HIDDEN | `Core/MerchantAuthoringService.swift:25` |
| `/api/merchant/business-status` | PROD-SERVED | — | `Core/MerchantOperationsService.swift:98` |
| `/api/merchant/business-status/update` | PROD-SERVED | — | `Core/MerchantBusinessMutation.swift:249` |
| `/api/merchant/chapter-application/apply` | PROD-SERVED | — | `Core/MerchantContentCommands.swift:63` |
| `/api/merchant/chapter-application/audit` | PROD-SERVED | — | `Core/MerchantContentCommands.swift:88` |
| `/api/merchant/chapter-application/invitable` | PROD-SERVED | — | `Core/ChapterReplacementInvitation.swift:52` |
| `/api/merchant/chapter-application/invite` | PROD-SERVED | — | `App/AppCompositionRoot.swift:3557` |
| `/api/merchant/chapter-application/invite/respond` | PROD-SERVED | — | `App/AppCompositionRoot.swift:3556` |
| `/api/merchant/chapter-application/mine` | PROD-SERVED | — | `Core/CooperationFlowService.swift:30` |
| `/api/merchant/chapter-application/owner-list` | PROD-SERVED | — | `Core/ChapterReplacementInvitation.swift:325` |
| `/api/merchant/chapter-application/owner-mine` | PROD-SERVED | — | `Core/ChapterReplacementInvitation.swift:340` |
| `/api/merchant/chapter-application/withdraw` | PROD-SERVED | — | `Core/MerchantContentCommands.swift:64` |
| `/api/merchant/chapter-node/audit` | PROD-SERVED | — | `Core/MerchantContentCommands.swift:92` |
| `/api/merchant/chapter-node/live-checkin-code` | PROD-SERVED | — | `Core/MerchantContentService.swift:309` |
| `/api/merchant/chapter-node/mine` | PROD-SERVED | — | `Core/MerchantContentService.swift:236` |
| `/api/merchant/chapter-node/npc/detail` | PROD-SERVED | — | `Core/MerchantContentService.swift:299` |
| `/api/merchant/chapter-node/npc/save` | PROD-SERVED | — | `Core/MerchantContentCommands.swift:99` |
| `/api/merchant/chapter-node/npc/voice/enroll` | PROD-SERVED | — | `Core/MerchantContentCommands.swift:102` |
| `/api/merchant/chapter-node/npc/voice/reset` | PROD-SERVED | — | `Core/MerchantContentCommands.swift:103` |
| `/api/merchant/chapter-node/npc/voice/status` | PROD-SERVED | — | `Core/MerchantContentService.swift:300` |
| `/api/merchant/chapter-node/pending` | PROD-SERVED | — | `Core/MerchantContentService.swift:275` |
| `/api/merchant/chapter-node/poster-code` | PROD-SERVED | — | `Core/MerchantContentService.swift:304` |
| `/api/merchant/chapter-node/submit` | PROD-SERVED | — | `Core/MerchantContentCommands.swift:89` |
| `/api/merchant/city-node/claim` | PROD-SERVED | — | `Core/MerchantCityNodeHub.swift:104` |
| `/api/merchant/city-node/claim/cancel` | PROD-SERVED | — | `Core/MerchantCityNodeHub.swift:104` |
| `/api/merchant/city-node/claimable` | PROD-SERVED | — | `Core/MerchantContentService.swift:289` |
| `/api/merchant/city-node/list` | PROD-SERVED | — | `Core/MerchantContentService.swift:286` |
| `/api/merchant/city-node/offline` | PROD-SERVED | — | `Core/MerchantCityNodeHub.swift:105` |
| `/api/merchant/city-node/poster-code` | PROD-SERVED | — | `Core/MerchantContentService.swift:332` |
| `/api/merchant/city-node/save` | PROD-SERVED | — | `App/MerchantCityNodeCreateView.swift:339` |
| `/api/merchant/city-node/template/submit` | PROD-SERVED | — | `App/AppCompositionRoot.swift:4011` |
| `/api/merchant/city-value/event/{}/benefit` | NEW-BACKEND-ONLY | HIDDEN | `Core/CityMerchantValueService.swift:57` |
| `/api/merchant/city-value/events` | NEW-BACKEND-ONLY | HIDDEN | `Core/CityMerchantValueService.swift:61` |
| `/api/merchant/city-value/report` | NEW-BACKEND-ONLY | HIDDEN | `Core/CityMerchantValueService.swift:51` |
| `/api/merchant/city-value/result/{}` | NEW-BACKEND-ONLY | HIDDEN | `Core/CityMerchantValueService.swift:53` |
| `/api/merchant/clubs` | PROD-SERVED | — | `Core/CooperationFlowService.swift:24` |
| `/api/merchant/commerce/capabilities` | PROD-SERVED | — | `Core/MerchantMarketingService.swift:149` |
| `/api/merchant/coop-profile` | PROD-SERVED | — | `App/AppCompositionRoot.swift:2800` |
| `/api/merchant/coop-profile/save` | PROD-SERVED | — | `App/AppCompositionRoot.swift:4011` |
| `/api/merchant/crm/broadcast` | PROD-SERVED | — | `Core/MerchantBusinessMutation.swift:252` |
| `/api/merchant/crm/broadcast/preview` | PROD-SERVED | — | `Core/MerchantEngagementContracts.swift:136` |
| `/api/merchant/crm/campaigns` | PROD-SERVED | — | `Core/MerchantBusinessMutation.swift:252` |
| `/api/merchant/crm/campaigns/coupons` | PROD-SERVED | — | `Core/MerchantEngagementContracts.swift:130` |
| `/api/merchant/crm/campaigns/preview` | PROD-SERVED | — | `Core/MerchantEngagementContracts.swift:135` |
| `/api/merchant/crm/campaigns/{}` | PROD-SERVED | — | `Core/MerchantEngagementContracts.swift:132` |
| `/api/merchant/crm/campaigns/{}/{}` | PROD-SERVED | — | `Core/MerchantEngagementContracts.swift:191` |
| `/api/merchant/crm/customers/61001/contact` | NEW-BACKEND-ONLY | HIDDEN | `App/MerchantEngagementFixtureSupport.swift:42` |
| `/api/merchant/crm/customers/61001/detail` | NEW-BACKEND-ONLY | HIDDEN | `App/MerchantEngagementFixtureSupport.swift:41` |
| `/api/merchant/crm/customers/list` | PROD-SERVED | — | `Core/MerchantBusinessQuery.swift:76` |
| `/api/merchant/crm/customers/tags/batch` | PROD-SERVED | — | `Core/MerchantBusinessMutation.swift:81` |
| `/api/merchant/crm/customers/{}/contact` | PROD-SERVED | — | `Core/MerchantEngagementContracts.swift:194` |
| `/api/merchant/crm/customers/{}/detail` | PROD-SERVED | — | `Core/MerchantBusinessQuery.swift:77` |
| `/api/merchant/crm/customers/{}/notes` | PROD-SERVED | — | `Core/MerchantBusinessMutation.swift:68` |
| `/api/merchant/crm/customers/{}/notes/hide` | PROD-SERVED | — | `Core/MerchantBusinessMutation.swift:71` |
| `/api/merchant/crm/customers/{}/tags` | PROD-SERVED | — | `Core/MerchantBusinessMutation.swift:74` |
| `/api/merchant/crm/customers/{}/tags/remove` | PROD-SERVED | — | `Core/MerchantBusinessMutation.swift:77` |
| `/api/merchant/crm/exports` | PROD-SERVED | — | `Core/MerchantBusinessMutation.swift:253` |
| `/api/merchant/crm/exports/74001/download` | NEW-BACKEND-ONLY | HIDDEN | `App/MerchantEngagementFixtureSupport.swift:37` |
| `/api/merchant/crm/exports/74001/status` | NEW-BACKEND-ONLY | HIDDEN | `App/MerchantEngagementFixtureSupport.swift:34` |
| `/api/merchant/crm/exports/{}/download` | PROD-SERVED | — | `Core/MerchantEngagementContracts.swift:195` |
| `/api/merchant/crm/exports/{}/status` | PROD-SERVED | — | `Core/MerchantEngagementContracts.swift:137` |
| `/api/merchant/crm/marketing-consents` | PROD-SERVED | — | `Core/AccountComplianceService.swift:263` |
| `/api/merchant/crm/segments` | PROD-SERVED | — | `Core/MerchantBusinessMutation.swift:252` |
| `/api/merchant/dashboard` | PROD-SERVED | — | `App/AppCompositionRoot.swift:759` |
| `/api/merchant/decor/save` | PROD-SERVED | — | `App/AppCompositionRoot.swift:4011` |
| `/api/merchant/desk/anchor` | PROD-SERVED | — | `Core/MerchantBusinessService.swift:23` |
| `/api/merchant/desk/anchor/save` | PROD-SERVED | — | `Core/MerchantDeskAnchorFlow.swift:19` |
| `/api/merchant/desk/products` | PROD-SERVED | — | `Core/MerchantBusinessService.swift:25` |
| `/api/merchant/desk/products/detail` | PROD-SERVED | — | `Core/MerchantBusinessService.swift:28` |
| `/api/merchant/desk/products/sku/save` | PROD-SERVED | — | `Core/MerchantBusinessMutation.swift:134` |
| `/api/merchant/desk/receipt` | PROD-SERVED | — | `Core/MerchantBusinessService.swift:34` |
| `/api/merchant/desk/stores` | PROD-SERVED | — | `Core/MerchantBusinessService.swift:22` |
| `/api/merchant/events` | PROD-SERVED | — | `App/AppCompositionRoot.swift:755` |
| `/api/merchant/finance/overview` | PROD-SERVED | — | `Core/MerchantBusinessQuery.swift:81` |
| `/api/merchant/finance/public-transfer-batch-detail` | PROD-SERVED | — | `Core/MerchantBusinessQuery.swift:85` |
| `/api/merchant/finance/public-transfer-batches` | PROD-SERVED | — | `Core/MerchantBusinessQuery.swift:84` |
| `/api/merchant/finance/redemption-detail` | PROD-SERVED | — | `Core/MerchantBusinessQuery.swift:88` |
| `/api/merchant/finance/redemptions` | PROD-SERVED | — | `Core/MerchantBusinessQuery.swift:82` |
| `/api/merchant/finance/settlement-entries` | PROD-SERVED | — | `Core/MerchantBusinessQuery.swift:83` |
| `/api/merchant/info` | PROD-SERVED | — | `App/AppCompositionRoot.swift:4038` |
| `/api/merchant/insight` | NEW-BACKEND-ONLY | HIDDEN | `App/MerchantDecorAndShopApplyWizardSectionView.swift:55` |
| `/api/merchant/list` | PROD-SERVED | — | `App/AppCompositionRoot.swift:2627` |
| `/api/merchant/marketing-home` | PROD-SERVED | — | `App/AppCompositionRoot.swift:4146` |
| `/api/merchant/merchant_registration` | PROD-SERVED | — | `Core/Adapt2MerchantTopicRoutes.swift:15` |
| `/api/merchant/nearby` | PROD-SERVED | — | `App/AppCompositionRoot.swift:890` |
| `/api/merchant/npc/avatar/generate` | NEW-BACKEND-ONLY | HIDDEN | `Core/MerchantBusinessMutation.swift:251` |
| `/api/merchant/npc/avatar/status` | NEW-BACKEND-ONLY | HIDDEN | `Core/MerchantOperationsService.swift:122` |
| `/api/merchant/npc/knowledge-review` | NEW-BACKEND-ONLY | HIDDEN | `Core/MerchantNPCKnowledgeReviewWriter.swift:52` |
| `/api/merchant/npc/knowledge-review/request` | NEW-BACKEND-ONLY | HIDDEN | `Core/MerchantNPCKnowledgeReviewWriter.swift:54` |
| `/api/merchant/npc/profile` | PROD-SERVED | — | `App/AppCompositionRoot.swift:4034` |
| `/api/merchant/npc/save` | PROD-SERVED | — | `App/AppCompositionRoot.swift:4011` |
| `/api/merchant/npc/voice/enroll` | PROD-SERVED | — | `Core/MerchantBusinessMutation.swift:250` |
| `/api/merchant/npc/voice/reset` | NEW-BACKEND-ONLY | HIDDEN | `Core/Adapt2MerchantTopicRoutes.swift:19` |
| `/api/merchant/npc/voice/revoke` | NEW-BACKEND-ONLY | HIDDEN | `Core/Adapt2MerchantTopicRoutes.swift:40` |
| `/api/merchant/npc/voice/script` | NEW-BACKEND-ONLY | HIDDEN | `Core/MerchantNPCAuthenticatedTransport.swift:32` |
| `/api/merchant/npc/voice/status` | PROD-SERVED | — | `App/MerchantDecorAndShopApplyWizardSectionView.swift:54` |
| `/api/merchant/offer-withdrawal/request` | NEW-BACKEND-ONLY | HIDDEN | `Core/MerchantOfferWithdrawalOriginalFlow.swift:24` |
| `/api/merchant/operators/invite` | PROD-SERVED | — | `Core/MerchantBusinessMutation.swift:99` |
| `/api/merchant/operators/invite/accept` | PROD-SERVED | — | `Core/MerchantBusinessMutation.swift:255` |
| `/api/merchant/operators/invite/revoke` | PROD-SERVED | — | `Core/MerchantBusinessMutation.swift:108` |
| `/api/merchant/operators/list` | PROD-SERVED | — | `Core/MerchantBusinessQuery.swift:90` |
| `/api/merchant/operators/remove` | PROD-SERVED | — | `Core/MerchantBusinessMutation.swift:105` |
| `/api/merchant/operators/role` | PROD-SERVED | — | `Core/MerchantBusinessMutation.swift:102` |
| `/api/merchant/operators/roles` | PROD-SERVED | — | `Core/MerchantBusinessQuery.swift:91` |
| `/api/merchant/orders` | PROD-SERVED | — | `Core/MerchantService.swift:81` |
| `/api/merchant/poi/detail` | NEW-BACKEND-ONLY | HIDDEN | `App/MerchantDecorAndShopApplyWizardSectionView.swift:51` |
| `/api/merchant/predict/inbox` | PROD-SERVED | — | `App/AppCompositionRoot.swift:784` |
| `/api/merchant/predict/settle` | PROD-SERVED | — | `Core/MerchantMarketingService.swift:189` |
| `/api/merchant/public-detail` | PROD-SERVED | — | `Core/Adapt2MerchantTopicRoutes.swift:13` |
| `/api/merchant/public-home` | PROD-SERVED | — | `App/AppCompositionRoot.swift:946` |
| `/api/merchant/relation-home` | PROD-SERVED | — | `Core/CooperationFlowService.swift:23` |
| `/api/merchant/reviews/create` | PROD-SERVED | — | `Core/MerchantBusinessMutation.swift:256` |
| `/api/merchant/reviews/manage` | PROD-SERVED | — | `Core/MerchantBusinessQuery.swift:80` |
| `/api/merchant/reviews/public` | PROD-SERVED | — | `Core/PublicMerchantReviews.swift:101` |
| `/api/merchant/reviews/reply/receipt` | PROD-SERVED | — | `Core/MerchantReviewOriginalReceiptReader.swift:98` |
| `/api/merchant/reviews/report` | PROD-SERVED | — | `Core/MerchantBusinessMutation.swift:256` |
| `/api/merchant/reviews/{}` | PROD-SERVED | — | `Core/MerchantBusinessMutation.swift:96` |
| `/api/merchant/shop/apply` | NEW-BACKEND-ONLY | HIDDEN | `App/MerchantDecorAndShopApplyWizardSectionView.swift:53` |
| `/api/merchant/subscription` | PROD-SERVED | — | `Core/MerchantMarketingService.swift:143` |
| `/api/merchant/todo-summary` | PROD-SERVED | — | `App/AppCompositionRoot.swift:759` |
| `/api/merchant/upcoming-runs` | PROD-SERVED | — | `Core/MerchantContentService.swift:272` |
| `/api/merchant/update` | PROD-SERVED | — | `Core/MerchantBusinessMutation.swift:248` |
| `/api/merchant/verification-records` | PROD-SERVED | — | `Core/MerchantBusinessQuery.swift:89` |
| `/api/mod-commerce` | NEW-BACKEND-ONLY | HIDDEN | `Core/WorkshopCommerceService.swift:125` |
| `/api/mod-installation` | NEW-BACKEND-ONLY | HIDDEN | `Core/ModInstallationService.swift:270` |
| `/api/mod-owned-report/licenses` | NEW-BACKEND-ONLY | HIDDEN | `Core/ModOwnedContentReport.swift:176` |
| `/api/mod-settlement/mine` | NEW-BACKEND-ONLY | HIDDEN | `Core/ModSettlementService.swift:129` |
| `/api/mod-settlement/mine/income` | NEW-BACKEND-ONLY | HIDDEN | `Core/ModSettlementService.swift:132` |
| `/api/mod-upgrade` | NEW-BACKEND-ONLY | HIDDEN | `Core/ModUpgradeService.swift:104` |
| `/api/monthly-recap` | PROD-SERVED | — | `Core/RoamPassportTools.swift:278` |
| `/api/native/blacklist/current` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeBlacklistService.swift:13` |
| `/api/native/blacklist/list` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeBlacklistService.swift:12` |
| `/api/native/blacklist/receipt` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeBlacklistService.swift:14` |
| `/api/native/blacklist/settle` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeBlacklistService.swift:16` |
| `/api/native/blacklist/unblock` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeBlacklistService.swift:15` |
| `/api/native/channels/read-through` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeChannelService.swift:41` |
| `/api/native/device/enroll` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeEnrollmentService.swift:11` |
| `/api/native/device/enrollment-challenge` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeEnrollmentService.swift:10` |
| `/api/native/device/revoke` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeEnrollmentService.swift:12` |
| `/api/native/device/status` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeEnrollmentService.swift:9` |
| `/api/native/home` | NEW-BACKEND-ONLY | HIDDEN | `Core/PrivateHomeService.swift:7` |
| `/api/native/home/return` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeHomeReturnService.swift:32` |
| `/api/npc/chat/delete` | NEW-BACKEND-ONLY | HIDDEN | `App/RegionalEndpointAllowlistSectionView.swift:74` |
| `/api/object-card/list` | PROD-SERVED | — | `Core/ObjectCardReading.swift:14` |
| `/api/official/broadcast` | PROD-SERVED | — | `Core/OfficialActionContracts.swift:101` |
| `/api/official/broadcast/{}/click` | PROD-SERVED | — | `Core/OfficialActionService.swift:85` |
| `/api/official/broadcast/{}/stats` | PROD-SERVED | — | `Core/OfficialEventService.swift:48` |
| `/api/official/can-publish` | PROD-SERVED | — | `Core/OfficialActionProduction.swift:32` |
| `/api/official/command` | PROD-SERVED | — | `App/AppCompositionRoot.swift:3956` |
| `/api/official/command/cancel` | PROD-SERVED | — | `App/AppCompositionRoot.swift:3956` |
| `/api/official/command/query` | PROD-SERVED | — | `App/AppCompositionRoot.swift:3955` |
| `/api/official/events` | PROD-SERVED | — | `Core/OfficialEventService.swift:17` |
| `/api/official/events/{}` | PROD-SERVED | — | `Core/OfficialActionProduction.swift:33` |
| `/api/official/events/{}/arrivals` | PROD-SERVED | — | `Core/OfficialActionContracts.swift:105` |
| `/api/official/events/{}/complete` | PROD-SERVED | — | `Core/OfficialActionContracts.swift:104` |
| `/api/official/events/{}/signup` | PROD-SERVED | — | `Core/OfficialActionContracts.swift:103` |
| `/api/official/invites` | PROD-SERVED | — | `Core/OfficialActionContracts.swift:102` |
| `/api/official/merchant-invites` | PROD-SERVED | — | `Core/CooperationFlowService.swift:28` |
| `/api/official/my-events` | PROD-SERVED | — | `Core/OfficialEventService.swift:28` |
| `/api/official/my-published` | PROD-SERVED | — | `App/AppCompositionRoot.swift:3918` |
| `/api/official/publish` | PROD-SERVED | — | `Core/OfficialActionContracts.swift:100` |
| `/api/official/v2/events` | NEW-BACKEND-ONLY | HIDDEN | `App/AppCompositionRoot.swift:3922` |
| `/api/official/v2/events/{}/publish-check` | PROD-SERVED | — | `Core/OfficialOrganizer.swift:197` |
| `/api/official/v2/organizer-invites/{}/{})` | NEW-BACKEND-ONLY | HIDDEN | `Core/OfficialActionContracts.swift:107` |
| `/api/official/v2/parties/{}/{}` | PROD-SERVED | — | `Core/OfficialActionContracts.swift:107` |
| `/api/official/v2/party-inbox` | PROD-SERVED | — | `Core/OfficialActionProduction.swift:35` |
| `/api/onboarding/get` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeChannelOnboarding.swift:14` |
| `/api/onboarding/submit` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeChannelOnboarding.swift:14` |
| `/api/orient/safety/check` | PROD-SERVED | — | `Core/OrientSessionService.swift:61` |
| `/api/orient/scoring/appeal` | PROD-SERVED | — | `Core/OrientSessionService.swift:136` |
| `/api/orient/scoring/dispute` | PROD-SERVED | — | `Core/OrientSessionService.swift:138` |
| `/api/orient/scoring/mine` | PROD-SERVED | — | `Core/MemberScoreAppealReadContracts.swift:106` |
| `/api/orient/scoring/receipt` | PROD-SERVED | — | `Core/OrientSessionService.swift:167` |
| `/api/orient/scoring/session/{}` | PROD-SERVED | — | `Core/MemberScoreAppealReadContracts.swift:107` |
| `/api/orient/scoring/session/{}/leaderboard` | PROD-SERVED | — | `Core/OrientSessionService.swift:92` |
| `/api/orient/scoring/session/{}/settle` | PROD-SERVED | — | `Core/OrientSessionService.swift:133` |
| `/api/orient/scoring/session/{}/sync` | PROD-SERVED | — | `Core/OrientSessionService.swift:103` |
| `/api/orient/task/alternative/receipt` | PROD-SERVED | — | `Core/OrientSessionService.swift:160` |
| `/api/orient/task/alternative/submit` | PROD-SERVED | — | `Core/OrientSessionService.swift:140` |
| `/api/orient/task/state` | PROD-SERVED | — | `Core/OrientSessionService.swift:114` |
| `/api/orient/team/detail` | PROD-SERVED | — | `App/AppCompositionRoot.swift:3911` |
| `/api/orient/team/lobby` | PROD-SERVED | — | `Core/OrientSessionService.swift:66` |
| `/api/orient/team/ranking` | PROD-SERVED | — | `App/AppCompositionRoot.swift:3914` |
| `/api/pay/create` | NEW-BACKEND-ONLY | HIDDEN | `App/RegionalEndpointAllowlistSectionView.swift:73` |
| `/api/personal-exploration-export/page` | PROD-SERVED | — | `Core/RoamPassportPrivateToolsReading.swift:57` |
| `/api/personal-exploration-export/prepare` | PROD-SERVED | — | `Core/RoamPassportPrivateToolsReading.swift:57` |
| `/api/play` | PROD-SERVED | — | `Core/PlayExperienceService.swift:115` |
| `/api/play/advanced/action` | PROD-SERVED | — | `Core/NativePlatformService.swift:30` |
| `/api/play/advanced/leaderboard` | PROD-SERVED | — | `Core/PlayAdvancedRuntime.swift:102` |
| `/api/play/advanced/start` | PROD-SERVED | — | `Core/PlayAdvancedRuntime.swift:83` |
| `/api/play/advanced/state` | PROD-SERVED | — | `App/AppSession.swift:3262` |
| `/api/play/advanced/time-window` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativePlatformService.swift:31` |
| `/api/play/answer` | PROD-SERVED | — | `Core/PlayService.swift:41` |
| `/api/play/character` | PROD-SERVED | — | `Core/CharacterCardReadRoute.swift:10` |
| `/api/play/check` | PROD-SERVED | — | `Core/JourneyContentService.swift:35` |
| `/api/play/checkin` | PROD-SERVED | — | `Core/PlayStoreDayService.swift:34` |
| `/api/play/city-orientation` | NEW-BACKEND-ONLY | HIDDEN | `Core/CityOrientationTaskOriginalSource.swift:169` |
| `/api/play/city-orientation/answer` | NEW-BACKEND-ONLY | HIDDEN | `Core/CityOrientationTaskOriginalTransport.swift:52` |
| `/api/play/city-orientation/receipt` | NEW-BACKEND-ONLY | HIDDEN | `Core/CityOrientationTaskOriginalTransport.swift:43` |
| `/api/play/companionLine` | PROD-SERVED | — | `Core/JourneyContentService.swift:42` |
| `/api/play/egg/collect` | NEW-BACKEND-ONLY | HIDDEN | `Core/JourneyContentService.swift:51` |
| `/api/play/encounter` | PROD-SERVED | — | `Core/JourneyContentService.swift:17` |
| `/api/play/ending` | PROD-SERVED | — | `Core/PlayExperienceService.swift:135` |
| `/api/play/growth` | PROD-SERVED | — | `Core/GrowthCenterService.swift:17` |
| `/api/play/hint/unlock` | PROD-SERVED | — | `Core/PlayExperienceService.swift:125` |
| `/api/play/journey/ask` | PROD-SERVED | — | `Core/JourneyNarrativeService.swift:35` |
| `/api/play/journey/backpack` | PROD-SERVED | — | `Core/JourneyNarrativeContracts.swift:29` |
| `/api/play/journey/casebook` | PROD-SERVED | — | `Core/JourneyNarrativeContracts.swift:29` |
| `/api/play/journey/ending` | PROD-SERVED | — | `Core/JourneyNarrativeContracts.swift:29` |
| `/api/play/journey/opening/complete` | PROD-SERVED | — | `Core/PlayJourneyOpening.swift:52` |
| `/api/play/journey/stage-end` | PROD-SERVED | — | `Core/JourneyNarrativeContracts.swift:29` |
| `/api/play/journey/thought/sync` | PROD-SERVED | — | `Core/ChapterThoughtSync.swift:36` |
| `/api/play/leaderboard` | PROD-SERVED | — | `Core/PlayExperienceService.swift:138` |
| `/api/play/my-completed` | PROD-SERVED | — | `Core/GrowthCenterService.swift:18` |
| `/api/play/nodes` | PROD-SERVED | — | `App/AppSession.swift:1237` |
| `/api/play/orient/session` | PROD-SERVED | — | `Core/OrientSessionService.swift:56` |
| `/api/play/orient/session/abandon` | PROD-SERVED | — | `Core/OrientSessionService.swift:130` |
| `/api/play/orient/session/current` | PROD-SERVED | — | `Core/OrientSessionService.swift:48` |
| `/api/play/orient/session/prepare` | PROD-SERVED | — | `Core/OrientSessionService.swift:128` |
| `/api/play/orient/session/receipt` | PROD-SERVED | — | `Core/OrientSessionService.swift:168` |
| `/api/play/orient/session/start` | PROD-SERVED | — | `Core/OrientSessionService.swift:129` |
| `/api/play/orient/session/task/{}/result` | PROD-SERVED | — | `Core/OrientSessionService.swift:132` |
| `/api/play/os/{}` | PROD-SERVED | — | `Core/PlayExperienceService.swift:184` |
| `/api/play/photo` | PROD-SERVED | — | `Core/PlayStoreDayService.swift:35` |
| `/api/play/preference/{}` | PROD-SERVED | — | `Core/PlayPreferenceRuntime.swift:61` |
| `/api/play/preference/{}/submit` | PROD-SERVED | — | `Core/PlayPreferenceRuntime.swift:68` |
| `/api/play/puzzle/hint` | PROD-SERVED | — | `Core/PlayExperienceService.swift:124` |
| `/api/play/puzzle/reveal` | PROD-SERVED | — | `Core/PlayExperienceService.swift:132` |
| `/api/play/route-action` | NEW-BACKEND-ONLY | HIDDEN | `App/PlayRouteMapView.swift:157` |
| `/api/play/route-state` | PROD-SERVED | — | `App/AppSession.swift:1239` |
| `/api/play/rpg/status` | PROD-SERVED | — | `Core/CharacterCardReadRoute.swift:11` |
| `/api/play/run-session` | PROD-SERVED | — | `Core/PlayExperienceService.swift:159` |
| `/api/play/run-session/list` | PROD-SERVED | — | `Core/PlayExperienceService.swift:162` |
| `/api/play/scan-entry` | PROD-SERVED | — | `Core/DoorReferralService.swift:45` |
| `/api/play/sensor-result` | PROD-SERVED | — | `Core/PlayExperienceService.swift:112` |
| `/api/play/tag/{}/confirm` | PROD-SERVED | — | `Core/PlayPreferenceRuntime.swift:75` |
| `/api/play/tag/{}/correct` | PROD-SERVED | — | `Core/PlayPreferenceRuntime.swift:74` |
| `/api/play/tag/{}/revoke` | PROD-SERVED | — | `Core/PlayExperienceService.swift:190` |
| `/api/play/theme` | PROD-SERVED | — | `Core/PlayThemeBackpackActions.swift:239` |
| `/api/play/theme/action` | PROD-SERVED | — | `Core/PlayThemeBackpackDispatch.swift:101` |
| `/api/play/theme/card` | PROD-SERVED | — | `Core/PlayThemeRecords.swift:131` |
| `/api/play/theme/history` | PROD-SERVED | — | `Core/PlayThemeRecords.swift:125` |
| `/api/play/theme/state` | PROD-SERVED | — | `Core/PlayThemeBackpack.swift:165` |
| `/api/play/theme/support-matrix` | PROD-SERVED | — | `Core/NativeRuntimeStructureAuthorPolicy.swift:6` |
| `/api/points/list` | PROD-SERVED | — | `Core/WalletCommerceSafety.swift:313` |
| `/api/points/result_list` | PROD-SERVED | — | `Core/WalletCommerceSafety.swift:314` |
| `/api/preset/route/info` | PROD-SERVED | — | `App/AppCompositionRoot.swift:3919` |
| `/api/preset/route/list` | PROD-SERVED | — | `App/AppCompositionRoot.swift:3918` |
| `/api/privacy/progress` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeChannelProgressFinalForward.swift:148` |
| `/api/product/info` | PROD-SERVED | — | `Core/WalletCommerceSafety.swift:314` |
| `/api/product/list` | PROD-SERVED | — | `Core/WalletCommerceSafety.swift:314` |
| `/api/progress/meter` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeChannelProgressFinalForward.swift:163` |
| `/api/progress/requests` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeChannelProgressFinalForward.swift:100` |
| `/api/progress/requests/{}` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeChannelProgressService.swift:68` |
| `/api/project/home` | PROD-SERVED | — | `App/AppCompositionRoot.swift:843` |
| `/api/project/my` | PROD-SERVED | — | `App/AppCompositionRoot.swift:873` |
| `/api/project/players` | PROD-SERVED | — | `App/AppCompositionRoot.swift:812` |
| `/api/project/state-requests/context` | NEW-BACKEND-ONLY | HIDDEN | `Core/BusinessRuntimeConfiguration.swift:322` |
| `/api/project/state-requests/read` | NEW-BACKEND-ONLY | HIDDEN | `Core/BusinessRuntimeConfiguration.swift:322` |
| `/api/project/state-requests/submit` | NEW-BACKEND-ONLY | HIDDEN | `Core/BusinessRuntimeConfiguration.swift:332` |
| `/api/publish/home` | PROD-SERVED | — | `App/ProjectEditCompositionRoute.swift:10` |
| `/api/publisher/identity` | PROD-SERVED | — | `Core/PublishModesContracts.swift:153` |
| `/api/publisher/identity/status` | PROD-SERVED | — | `Core/BusinessRuntimeConfiguration.swift:322` |
| `/api/registration/cancel` | PROD-SERVED | — | `App/AppCompositionRoot.swift:4170` |
| `/api/registration/cancel-by-owner` | PROD-SERVED | — | `Core/ClubOwnerRefundApprovedAccess.swift:13` |
| `/api/registration/cancel-refund` | PROD-SERVED | — | `App/AppCompositionRoot.swift:4171` |
| `/api/registration/count_by_date` | PROD-SERVED | — | `Core/ClubGovernanceService.swift:94` |
| `/api/registration/create` | PROD-SERVED | — | `Core/BusinessRuntimeConfiguration.swift:324` |
| `/api/registration/explore-completion` | PROD-SERVED | — | `Core/ExploreCompletionRead.swift:43` |
| `/api/registration/info` | PROD-SERVED | — | `App/AppSession.swift:5316` |
| `/api/registration/list` | PROD-SERVED | — | `Core/OwnedOrderRead.swift:63` |
| `/api/registration/merchant/cancel` | PROD-SERVED | — | `Core/MerchantContentCommands.swift:76` |
| `/api/registration/merchant/create` | PROD-SERVED | — | `Core/MerchantContentCommands.swift:72` |
| `/api/registration/merchant/info` | PROD-SERVED | — | `Core/MerchantContentService.swift:278` |
| `/api/registration/merchant/list` | PROD-SERVED | — | `Core/MerchantContentService.swift:276` |
| `/api/registration/merchant/select` | PROD-SERVED | — | `Core/MerchantContentService.swift:256` |
| `/api/registration/merchant/update` | PROD-SERVED | — | `Core/MerchantContentCommands.swift:75` |
| `/api/registration/my-joined` | PROD-SERVED | — | `Core/PlayerJourneyService.swift:19` |
| `/api/registration/original-event` | NEW-BACKEND-ONLY | HIDDEN | `Core/OwnedOrderRead.swift:65` |
| `/api/registration/pay` | NEW-BACKEND-ONLY | HIDDEN | `Core/Adapt5HighRiskWriteSupplement.swift:11` |
| `/api/registration/pay/app` | PROD-SERVED | — | `Core/Adapt5HighRiskWriteSupplement.swift:13` |
| `/api/registration/quote` | PROD-SERVED | — | `Core/RegistrationProduction.swift:19` |
| `/api/registration/scan_dynamic_code` | PROD-SERVED | — | `Core/BusinessRuntimeConfiguration.swift:346` |
| `/api/registration/scan_qr_code` | PROD-SERVED | — | `Core/BusinessRuntimeConfiguration.swift:346` |
| `/api/registration/scan_qr_code_chapter` | PROD-SERVED | — | `Core/BusinessRuntimeConfiguration.swift:346` |
| `/api/registration/scan_qr_code_station` | PROD-SERVED | — | `Core/BusinessRuntimeConfiguration.swift:346` |
| `/api/reward-pledge` | NEW-BACKEND-ONLY | HIDDEN | `Core/RewardPledge.swift:105` |
| `/api/reward-pledge/awards` | NEW-BACKEND-ONLY | HIDDEN | `Core/RewardPledge.swift:123` |
| `/api/reward-pledge/drafts` | NEW-BACKEND-ONLY | HIDDEN | `Core/RewardPledge.swift:56` |
| `/api/reward-pledge/fulfilment/awards` | NEW-BACKEND-ONLY | HIDDEN | `Core/RewardPledge.swift:53` |
| `/api/reward-pledge/fulfilment/expire` | NEW-BACKEND-ONLY | HIDDEN | `Core/RewardPledge.swift:55` |
| `/api/reward-pledge/fulfilment/preview` | NEW-BACKEND-ONLY | HIDDEN | `Core/RewardPledge.swift:51` |
| `/api/reward-pledge/fulfilment/redeem` | NEW-BACKEND-ONLY | HIDDEN | `Core/RewardPledge.swift:52` |
| `/api/reward-pledge/fulfilment/resolve` | NEW-BACKEND-ONLY | HIDDEN | `Core/RewardPledge.swift:54` |
| `/api/reward-pledge/ops` | NEW-BACKEND-ONLY | HIDDEN | `Core/RewardPledge.swift:109` |
| `/api/reward-pledge/pledges` | NEW-BACKEND-ONLY | HIDDEN | `Core/RewardPledge.swift:116` |
| `/api/reward-pledge/review` | NEW-BACKEND-ONLY | HIDDEN | `Core/RewardPledge.swift:117` |
| `/api/reward-pledge/versions` | NEW-BACKEND-ONLY | HIDDEN | `Core/RewardPledge.swift:121` |
| `/api/rewards/noncash` | NEW-BACKEND-ONLY | HIDDEN | `Core/NonCashRewardService.swift:17` |
| `/api/rewards/noncash/cases` | NEW-BACKEND-ONLY | HIDDEN | `Core/RewardPledge.swift:57` |
| `/api/rewards/noncash/claims` | NEW-BACKEND-ONLY | HIDDEN | `Core/RewardPledge.swift:48` |
| `/api/rewards/noncash/claims/recover` | NEW-BACKEND-ONLY | HIDDEN | `Core/RewardPledge.swift:49` |
| `/api/rewards/noncash/subjects` | NEW-BACKEND-ONLY | HIDDEN | `Core/RewardPledge.swift:96` |
| `/api/rewards/noncash/versions` | NEW-BACKEND-ONLY | HIDDEN | `Core/RewardPledge.swift:50` |
| `/api/roam/badge/shop-streak` | PROD-SERVED | — | `Core/RoamExperienceService.swift:41` |
| `/api/roam/checkin` | PROD-SERVED | — | `Core/RoamExperienceMutationContracts.swift:28` |
| `/api/roam/entry/nearby` | PROD-SERVED | — | `Core/RoamEntryNearby.swift:47` |
| `/api/roam/finish` | PROD-SERVED | — | `App/AppCompositionRoot.swift:3733` |
| `/api/roam/hangout/nearby` | PROD-SERVED | — | `Core/RoamNearbyEventsReadAccess.swift:30` |
| `/api/roam/nearby-exploreday` | PROD-SERVED | — | `Core/RoamService.swift:35` |
| `/api/roam/nearby-runners` | PROD-SERVED | — | `Core/RoamNearbyPlayersReadAccess.swift:30` |
| `/api/roam/passport` | PROD-SERVED | — | `Core/RoamPassportHistoryReading.swift:30` |
| `/api/roam/poi/discover` | PROD-SERVED | — | `App/AppCompositionRoot.swift:3733` |
| `/api/roam/pois` | PROD-SERVED | — | `App/AppCompositionRoot.swift:3735` |
| `/api/roam/presence` | PROD-SERVED | — | `Core/RoamExperienceMutationContracts.swift:27` |
| `/api/roam/presence-visibility` | PROD-SERVED | — | `Core/LocationShareContracts.swift:183` |
| `/api/roam/reveal` | PROD-SERVED | — | `App/AppCompositionRoot.swift:3733` |
| `/api/roam/session` | PROD-SERVED | — | `App/AppCompositionRoot.swift:3735` |
| `/api/roam/share/snapshot` | PROD-SERVED | — | `Core/RoamSubpagePresentation.swift:160` |
| `/api/roam/shop/visit` | PROD-SERVED | — | `App/AppCompositionRoot.swift:3734` |
| `/api/roam/stamp/create` | PROD-SERVED | — | `App/AppCompositionRoot.swift:3717` |
| `/api/roam/stamp/exchange` | PROD-SERVED | — | `App/AppCompositionRoot.swift:3718` |
| `/api/roam/stamp/list` | PROD-SERVED | — | `Core/RoamAlbumMetadataReadAccess.swift:29` |
| `/api/roam/stamp/received` | PROD-SERVED | — | `Core/ReceivedStampsAndPassportToolsAudit.swift:10` |
| `/api/roam/tiles` | PROD-SERVED | — | `Core/RoamExperienceService.swift:37` |
| `/api/roam/tiles/page` | PROD-SERVED | — | `Core/RoamExperienceService.swift:30` |
| `/api/role/info` | PROD-SERVED | — | `Core/MemberHome.swift:176` |
| `/api/sms/send` | PROD-SERVED | — | `Core/APIConfiguration.swift:31` |
| `/api/space/join-pause` | NEW-BACKEND-ONLY | HIDDEN | `Core/ChannelAdmissionGovernanceClient.swift:13` |
| `/api/space/leave` | NEW-BACKEND-ONLY | HIDDEN | `Core/ChannelAdmissionGovernanceClient.swift:14` |
| `/api/stats/club` | PROD-SERVED | — | `Core/ClubGovernanceContracts.swift:104` |
| `/api/support/tickets` | NEW-BACKEND-ONLY | HIDDEN | `Core/SupportTicketReadContracts.swift:103` |
| `/api/team/applications` | PROD-SERVED | — | `App/AppCompositionRoot.swift:3969` |
| `/api/team/apply` | PROD-SERVED | — | `App/AppCompositionRoot.swift:4077` |
| `/api/team/create` | PROD-SERVED | — | `Core/TeamContracts.swift:156` |
| `/api/team/disband` | PROD-SERVED | — | `Core/TeamContracts.swift:163` |
| `/api/team/handle` | PROD-SERVED | — | `App/AppCompositionRoot.swift:4077` |
| `/api/team/info` | PROD-SERVED | — | `Core/TeamReadApproval.swift:27` |
| `/api/team/join` | PROD-SERVED | — | `Core/TeamContracts.swift:160` |
| `/api/team/join-mode` | PROD-SERVED | — | `Core/TeamContracts.swift:166` |
| `/api/team/kick` | PROD-SERVED | — | `Core/TeamContracts.swift:162` |
| `/api/team/my` | PROD-SERVED | — | `Core/TeamReadApproval.swift:27` |
| `/api/team/my-applications` | PROD-SERVED | — | `App/AppCompositionRoot.swift:3969` |
| `/api/team/nearby` | PROD-SERVED | — | `App/AppCompositionRoot.swift:3969` |
| `/api/team/original-request` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeFriendTeamInviteService.swift:8` |
| `/api/team/quit` | PROD-SERVED | — | `Core/TeamContracts.swift:161` |
| `/api/team/report` | PROD-SERVED | — | `App/AppCompositionRoot.swift:3947` |
| `/api/team/withdraw` | PROD-SERVED | — | `App/AppCompositionRoot.swift:4077` |
| `/api/team/{}` | PROD-SERVED | — | `Core/NearbyTeamService.swift:38` |
| `/api/template/author-requests/read` | NEW-BACKEND-ONLY | HIDDEN | `Core/TemplateAuthoringRequestReceipt.swift:9` |
| `/api/template/author-requests/submit` | NEW-BACKEND-ONLY | HIDDEN | `Core/TemplateAuthoringRequestReceipt.swift:8` |
| `/api/template/delete` | PROD-SERVED | — | `Core/BusinessRuntimeConfiguration.swift:332` |
| `/api/template/draft` | PROD-SERVED | — | `Core/TemplateAuthoringContract.swift:33` |
| `/api/template/homeData` | PROD-SERVED | — | `Core/DiscoveryService.swift:29` |
| `/api/template/info` | PROD-SERVED | — | `Core/DiscoveryService.swift:54` |
| `/api/template/list` | PROD-SERVED | — | `Core/DiscoveryService.swift:38` |
| `/api/template/my-list` | PROD-SERVED | — | `Core/BusinessRuntimeConfiguration.swift:322` |
| `/api/template/myinfo` | PROD-SERVED | — | `App/AppCompositionRoot.swift:4038` |
| `/api/template/personal-report` | PROD-SERVED | — | `Core/ContentReportReasonRules.swift:10` |
| `/api/template/publish` | PROD-SERVED | — | `Core/TemplateAuthoringContract.swift:33` |
| `/api/template/report` | PROD-SERVED | — | `Core/ContentReportReasonRules.swift:9` |
| `/api/template/report-receipt` | NEW-BACKEND-ONLY | HIDDEN | `Core/TemplateContentReportContracts.swift:11` |
| `/api/template/topic-template/info` | PROD-SERVED | — | `App/AppCompositionRoot.swift:3606` |
| `/api/template/topic-template/list` | PROD-SERVED | — | `App/AppCompositionRoot.swift:3605` |
| `/api/template/topic-template/use` | PROD-SERVED | — | `Core/TopicTemplateUse.swift:13` |
| `/api/template/updateLibraryStatus` | PROD-SERVED | — | `Core/BusinessRuntimeConfiguration.swift:332` |
| `/api/topic/attribute-author` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeAttributeAuthorExtendedContract.swift:203` |
| `/api/topic/attribute-author/references` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeAttributeAuthorExtendedContract.swift:213` |
| `/api/topic/attribute-author/request` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeAttributeAuthorExtendedContract.swift:176` |
| `/api/topic/attribute-author/validate` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeAttributeAuthorExtendedContract.swift:254` |
| `/api/topic/beta/graduate` | PROD-SERVED | — | `Core/PublisherLifecycleCoordinator.swift:89` |
| `/api/topic/cancel` | PROD-SERVED | — | `Core/PublisherCancelAdapter.swift:17` |
| `/api/topic/cancel_preview` | PROD-SERVED | — | `Core/PublisherCancelAdapter.swift:20` |
| `/api/topic/chapter/finish` | PROD-SERVED | — | `Core/ClubGovernanceCommands.swift:27` |
| `/api/topic/chapter/recruit` | PROD-SERVED | — | `Core/ClubGovernanceCommands.swift:26` |
| `/api/topic/cover` | NEW-BACKEND-ONLY | HIDDEN | `App/OwnedTopicCoverCompositionRoute.swift:16` |
| `/api/topic/cover/selection` | NEW-BACKEND-ONLY | HIDDEN | `Core/OwnedTopicCoverClient.swift:46` |
| `/api/topic/cover/selection/current` | NEW-BACKEND-ONLY | HIDDEN | `Core/OwnedTopicCoverClient.swift:44` |
| `/api/topic/cover/selection/status` | NEW-BACKEND-ONLY | HIDDEN | `Core/OwnedTopicCoverClient.swift:47` |
| `/api/topic/cover/upload` | NEW-BACKEND-ONLY | HIDDEN | `Core/OwnedTopicCoverClient.swift:45` |
| `/api/topic/cover/{}/content` | NEW-BACKEND-ONLY | HIDDEN | `Core/ApprovedTopicSelectedCover.swift:43` |
| `/api/topic/create` | PROD-SERVED | — | `App/ProjectEditCompositionRoute.swift:12` |
| `/api/topic/delete` | PROD-SERVED | — | `Core/BusinessRuntimeConfiguration.swift:332` |
| `/api/topic/detail` | NEW-BACKEND-ONLY | HIDDEN | `App/PublishTopicAndCommentModerationSectionView.swift:78` |
| `/api/topic/edit-detail` | PROD-SERVED | — | `App/ProjectEditCompositionRoute.swift:11` |
| `/api/topic/edit-requests/read` | NEW-BACKEND-ONLY | HIDDEN | `Core/ProjectEditRequestContract.swift:9` |
| `/api/topic/edit-requests/resume-post-processing` | NEW-BACKEND-ONLY | HIDDEN | `Core/ProjectEditRequestContract.swift:10` |
| `/api/topic/edit-requests/submit` | NEW-BACKEND-ONLY | HIDDEN | `Core/ProjectEditRequestContract.swift:8` |
| `/api/topic/host-node-answer` | PROD-SERVED | — | `Core/StoryParticipation.swift:243` |
| `/api/topic/info-to-merchant` | PROD-SERVED | — | `Core/MerchantContentService.swift:247` |
| `/api/topic/info-to-user` | PROD-SERVED | — | `Core/Adapt2MerchantTopicRoutes.swift:17` |
| `/api/topic/like` | PROD-SERVED | — | `App/AppCompositionRoot.swift:4178` |
| `/api/topic/like_list` | PROD-SERVED | — | `Core/AccountCollectionService.swift:13` |
| `/api/topic/list` | PROD-SERVED | — | `App/AppCompositionRoot.swift:2627` |
| `/api/topic/merchant-recruitment-chapters` | PROD-SERVED | — | `Core/MerchantContentService.swift:251` |
| `/api/topic/module-preflight` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeAttributeAuthorHostTransport.swift:26` |
| `/api/topic/pricing/confirm` | PROD-SERVED | — | `Core/PublisherLifecycleCoordinator.swift:83` |
| `/api/topic/pricing/preview` | PROD-SERVED | — | `Core/PublisherLifecycleHTTP.swift:69` |
| `/api/topic/publish-check` | PROD-SERVED | — | `Core/NativeAttributeAuthorHostTransport.swift:25` |
| `/api/topic/report` | PROD-SERVED | — | `Core/ContentReportReasonRules.swift:8` |
| `/api/topic/state-keys` | PROD-SERVED | — | `Core/NativeAttributeAuthorHostTransport.swift:22` |
| `/api/topic/transfer-to-club` | PROD-SERVED | — | `Core/PublisherLifecycleCoordinator.swift:88` |
| `/api/topic/update` | PROD-SERVED | — | `App/ProjectEditCompositionRoute.swift:13` |
| `/api/topic/update_user_status` | PROD-SERVED | — | `Core/BusinessRuntimeConfiguration.swift:332` |
| `/api/topic/v2/create` | PROD-SERVED | — | `Core/BusinessRuntimeConfiguration.swift:345` |
| `/api/topic/v2/update` | PROD-SERVED | — | `Core/BusinessRuntimeConfiguration.swift:345` |
| `/api/topic/xp-budget` | PROD-SERVED | — | `Core/PublisherLifecycleHTTP.swift:69` |
| `/api/ugc/block` | NEW-BACKEND-ONLY | HIDDEN | `App/PublishTopicAndCommentModerationSectionView.swift:81` |
| `/api/us/auth/apple/challenges` | NEW-BACKEND-ONLY | HIDDEN | `Core/USAppleService.swift:92` |
| `/api/us/auth/apple/exchange` | NEW-BACKEND-ONLY | HIDDEN | `Core/USAppleService.swift:104` |
| `/api/us/auth/session` | NEW-BACKEND-ONLY | HIDDEN | `Core/USAppleService.swift:121` |
| `/api/user/address` | PROD-SERVED | — | `Core/ProfileParticipantTransport.swift:24` |
| `/api/user/address/action` | PROD-SERVED | — | `Core/ParticipantForm.swift:72` |
| `/api/user/address/delete` | PROD-SERVED | — | `Core/ParticipantForm.swift:73` |
| `/api/user/address/info` | PROD-SERVED | — | `Core/ProfileParticipantAccess.swift:8` |
| `/api/user/address/list` | PROD-SERVED | — | `Core/ProfileParticipantAccess.swift:8` |
| `/api/user/address/setDefault` | PROD-SERVED | — | `Core/ParticipantForm.swift:74` |
| `/api/user/balance/list` | PROD-SERVED | — | `Core/WalletCommerceSafety.swift:313` |
| `/api/user/deregister` | PROD-SERVED | — | `Core/AccountDeregistrationOriginal.swift:57` |
| `/api/user/deregister/apply` | PROD-SERVED | — | `App/AppCompositionRoot.swift:3831` |
| `/api/user/deregister/cancel` | PROD-SERVED | — | `App/AppCompositionRoot.swift:3828` |
| `/api/user/deregister/precheck` | PROD-SERVED | — | `App/AppCompositionRoot.swift:3827` |
| `/api/user/deregister/status` | PROD-SERVED | — | `App/AppCompositionRoot.swift:3824` |
| `/api/user/follow-list` | NEW-BACKEND-ONLY | HIDDEN | `Core/ProfileFollowListService.swift:8` |
| `/api/user/follow/action` | PROD-SERVED | — | `Core/SocialActionContracts.swift:145` |
| `/api/user/info` | PROD-SERVED | — | `Core/ProfileEditService.swift:27` |
| `/api/user/invite_list` | PROD-SERVED | — | `Core/ProfileInviteHistoryReadRoute.swift:30` |
| `/api/user/list` | PROD-SERVED | — | `Core/BusinessRuntimeConfiguration.swift:322` |
| `/api/user/nickname/check` | PROD-SERVED | — | `Core/ProfileNicknameAvailabilityService.swift:145` |
| `/api/user/nickname/suggest` | PROD-SERVED | — | `Core/ProfileNicknameAvailabilityService.swift:157` |
| `/api/user/points/list` | PROD-SERVED | — | `Core/ProfileInviteHistoryReadRoute.swift:31` |
| `/api/user/points/statistics` | PROD-SERVED | — | `Core/ProfileWeeklyPointsReadApproval.swift:43` |
| `/api/user/profile/review` | PROD-SERVED | — | `Core/ProfileCurrentReview.swift:127` |
| `/api/user/public-info` | PROD-SERVED | — | `Core/ProfilePublicInfoRead.swift:23` |
| `/api/user/setInviter` | PROD-SERVED | — | `Core/DoorReferralService.swift:57` |
| `/api/user/sms/send` | NEW-BACKEND-ONLY | HIDDEN | `App/RegionalEndpointAllowlistSectionView.swift:76` |
| `/api/user/update` | PROD-SERVED | — | `Core/ProfileEditService.swift:46` |
| `/api/userInfo` | PROD-SERVED | — | `Core/APIConfiguration.swift:33` |
| `/api/v1/community/appeals` | PROD-SERVED | — | `Core/SquareGovernanceService.swift:103` |
| `/api/v1/community/capabilities` | PROD-SERVED | — | `Core/ContentReportReasonRules.swift:11` |
| `/api/v1/community/comments/{}/actions` | PROD-SERVED | — | `Core/SocialActionContracts.swift:166` |
| `/api/v1/community/drafts` | PROD-SERVED | — | `Core/SquareWorkspaceService.swift:48` |
| `/api/v1/community/feeds/{}` | PROD-SERVED | — | `Core/SquareService.swift:37` |
| `/api/v1/community/guidelines/ack` | PROD-SERVED | — | `Core/SquareWorkspaceService.swift:112` |
| `/api/v1/community/guidelines/active` | PROD-SERVED | — | `Core/SquareWorkspaceService.swift:41` |
| `/api/v1/community/me/enforcements` | PROD-SERVED | — | `Core/SquareGovernanceService.swift:87` |
| `/api/v1/community/media/register` | PROD-SERVED | — | `Core/SquarePostVideoChain.swift:97` |
| `/api/v1/community/notification-preferences` | PROD-SERVED | — | `Core/SquareGovernanceService.swift:97` |
| `/api/v1/community/notifications` | PROD-SERVED | — | `Core/SquareGovernanceService.swift:92` |
| `/api/v1/community/notifications/{}/read` | PROD-SERVED | — | `Core/SquareGovernanceService.swift:105` |
| `/api/v1/community/posts` | PROD-SERVED | — | `Core/SquareWorkspaceService.swift:129` |
| `/api/v1/community/posts/{id}` | PROD-SERVED | — | `Core/SquareDeletionFlow.swift:16` |
| `/api/v1/community/posts/{postId}/comments/{id}` | PROD-SERVED | — | `Core/SquareDeletionFlow.swift:17` |
| `/api/v1/community/posts/{}` | PROD-SERVED | — | `Core/SquareDeletionFlow.swift:21` |
| `/api/v1/community/posts/{}/actions` | PROD-SERVED | — | `Core/SocialActionContracts.swift:181` |
| `/api/v1/community/posts/{}/comments` | PROD-SERVED | — | `Core/SocialActionContracts.swift:163` |
| `/api/v1/community/posts/{}/comments/{}` | PROD-SERVED | — | `Core/SquareDeletionFlow.swift:22` |
| `/api/v1/community/posts/{}/comments/{}/approve` | PROD-SERVED | — | `Core/SquareGovernanceService.swift:110` |
| `/api/v1/community/posts/{}/location` | PROD-SERVED | — | `Core/SquareWorkspaceService.swift:145` |
| `/api/v1/community/posts/{}/publish` | PROD-SERVED | — | `Core/SquareWorkspaceService.swift:136` |
| `/api/v1/community/posts/{}/revisions` | PROD-SERVED | — | `Core/SquareWorkspaceService.swift:55` |
| `/api/v1/community/reference-options/{}` | PROD-SERVED | — | `Core/SquareWorkspaceService.swift:60` |
| `/api/v1/community/reports` | PROD-SERVED | — | `Core/SquareReportService.swift:77` |
| `/api/verify/citynode/issue` | PROD-SERVED | — | `App/AppCompositionRoot.swift:4176` |
| `/api/verify/citynode/receipt` | PROD-SERVED | — | `Core/CityNodeRedemptionReceiptReading.swift:48` |
| `/api/verify/citynode/redeem` | PROD-SERVED | — | `Core/BusinessRuntimeConfiguration.swift:346` |
| `/api/verify/dyncode/issue` | PROD-SERVED | — | `Core/OrderLifecycleDormantAdapter.swift:39` |
| `/api/verify/groupcode/issue` | PROD-SERVED | — | `Core/Adapt3GroupCodeIssueAdapter.swift:20` |
| `/api/verify/groupcode/redeem` | PROD-SERVED | — | `Core/BusinessRuntimeConfiguration.swift:346` |
| `/api/wallet/stages` | PROD-SERVED | — | `Core/WalletCommerceSafety.swift:313` |
| `/api/welcome-screen/get` | NEW-BACKEND-ONLY | HIDDEN | `Core/NativeChannelWelcome.swift:9` |
| `/api/withdrawal/create` | PROD-SERVED | — | `Core/BankWithdrawalAdapter.swift:137` |
| `/api/withdrawal/list` | PROD-SERVED | — | `Core/WalletCommerceSafety.swift:314` |
| `/api/workshop/creator/pending-packages` | NEW-BACKEND-ONLY | HIDDEN | `Core/WorkshopCreatorPendingService.swift:175` |
| `/api/workshop/creator/public-theme-use` | NEW-BACKEND-ONLY | HIDDEN | `Core/WorkshopCreatorConsentService.swift:160` |
| `/api/workshop/owned` | NEW-BACKEND-ONLY | HIDDEN | `Core/WorkshopOwnedService.swift:81` |
| `/api/workshop/owned/detail` | NEW-BACKEND-ONLY | HIDDEN | `App/WorkshopOwnedReadRoute.swift:18` |
| `/api/workshop/owned/list` | NEW-BACKEND-ONLY | HIDDEN | `App/WorkshopOwnedReadRoute.swift:16` |
| `/api/workshop/owned/package` | NEW-BACKEND-ONLY | HIDDEN | `Core/WorkshopOwnedPackageService.swift:63` |
| `/api/workshop/purchased` | NEW-BACKEND-ONLY | HIDDEN | `Core/WorkshopPurchasedService.swift:85` |
| `/api/workshop/purchased/detail` | NEW-BACKEND-ONLY | HIDDEN | `App/WorkshopPurchasedReadRoute.swift:23` |
| `/api/workshop/purchased/install` | NEW-BACKEND-ONLY | HIDDEN | `Core/WorkshopPaidInstallService.swift:129` |
| `/api/workshop/purchased/installed-text/detail` | NEW-BACKEND-ONLY | HIDDEN | `Core/WorkshopPaidInstalledTextService.swift:93` |
| `/api/workshop/purchased/list` | NEW-BACKEND-ONLY | HIDDEN | `App/WorkshopPurchasedReadRoute.swift:16` |
| `/api/workshop/purchased/professional-operations/cancel` | NEW-BACKEND-ONLY | HIDDEN | `Core/WorkshopPaidProfessionalService.swift:206` |
| `/api/workshop/purchased/professional-operations/history` | NEW-BACKEND-ONLY | HIDDEN | `Core/WorkshopPaidProfessionalService.swift:207` |
| `/api/workshop/purchased/professional-operations/status` | NEW-BACKEND-ONLY | HIDDEN | `Core/WorkshopPaidProfessionalService.swift:205` |
| `/api/workshop/purchased/professional-operations/submit` | NEW-BACKEND-ONLY | HIDDEN | `Core/WorkshopPaidProfessionalService.swift:204` |
| `/api/workshop/purchased/professional-targets/detail` | NEW-BACKEND-ONLY | HIDDEN | `Core/WorkshopPaidProfessionalService.swift:203` |
| `/api/workshop/purchased/professional-targets/list` | NEW-BACKEND-ONLY | HIDDEN | `Core/WorkshopPaidProfessionalService.swift:202` |
| `/api/{}/cancel` | NEW-BACKEND-ONLY | HIDDEN | `Core/PublisherCancelAdapter.swift:3` |

## Excluded literals

These strings contain `api/` and are not routes. Appendix A drops the same description text.

| Literal | Site |
|---|---|
| `/api/topic/detail 完整承载富文本、坐标点位与章节结局布尔 fallback` | `App/PublishTopicAndCommentModerationSectionView.swift:97` |
| `/api/roam/tiles/page · pages/searchmap · pages/roam` | `App/NativeSupersetOverMiniProgramSectionView.swift:84` |
| `/api/order/* · 会员订阅与数字模组购买契约` | `App/NativeSupersetOverMiniProgramSectionView.swift:108` |
| `/api/userInfo 角色权限与 Realm 隔离校验` | `App/SevenDayLaunchCriticalPathSectionView.swift:86` |
| `/api` | `Core/MerchantAuthoringService.swift:399` |
| `/api` | `Core/BusinessRuntimeConfiguration.swift:30` |
| `/api` | `Core/ClubGovernanceService.swift:34` |
| `/api` | `Core/OperationAdapterSafety.swift:15` |
| `/api/channels/\(channelID` | `Core/NativeChannelManagementIntent.swift:65` |
| `/api/ai` | `Core/MerchantNPCOriginalDraftWriter.swift:9` |

## What this does not claim

Tests were not re-run. No simulator pass was done. The chrome findings are from reading the release view tree (`QuestifyApp` non-DEBUG branch, `SessionRootView`, and the views it builds), not from a screenshot. A route marked HIDDEN is not sent and was not found as an always-built control on that tree. A later navigation that this pass did not open could still show an unavailable line; the two VISIBLE entries are the ones this pass did open.


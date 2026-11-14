# Package 64 Final Sweep (`ui/h-sweep`)

Branch: `ui/h-sweep` (from `origin/ui/main` `6feee423a`)
Reference backend: `hengyin integration/backend-app-r2` (`https://8120-agqyfqxs5vwolymtoibzq3fhde.instabox.tech`)
Reference mini-program: `chengyinhub-xcx` (`HEAD:chengyinhub-xcx`)

This document records the codebase-wide sweep of `App/` and `Core/` for `TODO`, `FIXME`, `not available`, `coming soon`, `unavailable`, `BINDING STUB`, placeholder views, hard-coded hidden flags, and `EmptyView()` stubs on player/creator/merchant paths.

---

## 1. Resolved in `ui/h-sweep`

| Area | Location | Resolution |
|---|---|---|
| POI challenge submit (`POST /api/city/nodes/{id}/complete`) | `Core/ChallengePOISubmission.swift:39-124`, `App/ChallengePOIWriterFactory.swift:9-13`, `App/ChallengePOIView.swift:168-174, 260-330`, `App/CloudB3Production.swift:107-137` | Added `ChallengePOIHTTPWriter` porting `pages/play/poi-challenge/index.js` (`lat`, `lng`, `answer`, `photoUrl`, `code` form POST, `needRedeem` Bool confirmation check, mini prewrite rejection codes/messages). Injected foreground location via `playEmergencyLocationProvider` (WGS-84 → GCJ-02), set `photoRequired: node.validationMethod == 2`, hid `PlayWriteUnavailableBanner` when `ChallengePOIWriterFactory.isLive`, and installed the writer in `CloudB3RootModifier` (dual-granted in `ChinaReviewedRouteCapability` + `ReviewedPlayerWriteLeases.roamExtraPaths`). `PlayWriteAvailability.current(for: .challengeSubmit)` (`Core/PlayRPGPresentation.swift:26`) remains `isAvailable: false` for `PlayKitTimedChallengePage` (`/api/play/advanced/*`). |
| My-project list mutations (`subpackageA/pages/myproject/index.js`) | `Core/MyProjectMutations.swift:86-161`, `App/MyProjectMutationViews.swift:6-20`, `App/ReviewedPlayerWriteLeases.swift:648-650, 1470-1528`, `App/ReviewedProductionRoutes.swift:124-126`, `App/CloudB3Production.swift:119-135` | Added `MyProjectHTTPMutator` for all 7 list mutations (`api/activity/update_publish_status`, `api/topic/update_user_status`, `api/activity/cancel`, `api/activity/delete`, `api/topic/delete`, `api/template/delete`, `api/template/updateLibraryStatus` mapping `publish_status` to backend `status` `1`/`3`). Admitted non-money routes in `ReviewedPlayerWriteLeases.playPaths` + `acceptsMyProjectMutation` and `ReviewedProductionFormMutationRoute.accepts`. Gated `api/activity/cancel` (which triggers automatic paid-order refunds on backend) behind `ReviewedAreaSwitch.moneyPayments(apiHost:)`, and `scope == "MERCHANT"` behind `ReviewedAreaSwitch.merchantWrites(apiHost:)`. |
| Merchant workbench greeting + open status | `App/MerchantHomeView.swift:36, 169, 224-252, 505-534` | Removed `UIV-TODO` by rendering `"Hi，\(displayName)"` alongside the live `.businessStatus` `CYStatusChip` (`merchant.operations.statusOpen` / `merchant.operations.statusClosed`, navigating to `.businessStatus` when `operationsAccess.allows(.businessStatus)`). |
| Channel composer disabled attachment menu | `App/ClubChannelMessagingView.swift:682-685` | Removed dead `.disabled(true)` `club.channel.composer.attachments` placeholder `Menu`. Attachment upload/link cards stay deferred to Club IM owner below. |
| Character sheet edit/Adjust unavailable stub | `App/CharacterSheetDetailView.swift:6-86` | Removed the unrequested local Adjust/Edit controls and `PlayWriteUnavailableBanner(.characterSheetSave)` so the view faithfully matches the read-only mini-program (`subpackageMember/character/index.wxml`, `/api/play/character` is read-only). `CharacterSheetDraft` in `Core/PlayRPGPresentation.swift` is kept for existing unit/contract tests. |
| Stale binding stub comments | `App/AIGCDisclosure.swift:6-8`, `App/PlayThemePresentation.swift:3-6`, `App/PlayInPlayTools.swift:6-9`, `App/IMDriftEntries.swift:5-10` | Updated stale `BINDING STUB for Cursor` doc comments on environment keys already wired at root in `App/CloudB3Production.swift`. |

---

## 2. Verified Non-Stubs / Intentional Patterns Kept As-Is

| Pattern | Location | Why kept |
|---|---|---|
| `"Coming soon"` / `"即将上线"` copy | `Core/HomeSearchTabParity.swift`, `App/HomeSearchTabParityViews.swift`, `Resources/Localizable.xcstrings` (`homeFeed.upcoming`) | Intentional mini-program countdown section header (`即将上线`). |
| `@State private var hidden = true` | `App/PublicCatalogViews.swift:260, 288, 410` | Flash-of-unscaled-content guard cleared asynchronously inside `show(...)` on appear. |
| Already-wired seams | `App/TopicTemplateUseSection.swift:25-30`, `App/OrientScoreReviewSection.swift:21`, `App/CollectionAlbumViews.swift:60`, `App/ProfileComplaintPreparationView.swift:8` | Already wired in `AppCompositionRoot` / `CloudB3Production` / feature roots. |
| Runtime unavailability fallback views | `App/MapSearchPlayerViews.swift:126`, `App/ClubChatEntryView.swift:96` | Defensive fallbacks shown only when runtime session prerequisites are absent. |

---

## 3. Remaining Unresolved / Intentionally Gated Items

| Location | Symbol / Identifier | Precise Reason | Owner |
|---|---|---|---|
| `App/SettingsPrivacyLocationView.swift:45` | `member.privacy.presence.off` (`.disabled(true)`) | `api/roam/presence` and `api/roam/presence-visibility` writes are explicitly denied in `App/ReviewedPlayerWriteLeases.swift:56` (`Tests/ContractChecks/test_player_write_grant.py:45`) pending privacy/product signoff. | Roam / Privacy owner |
| `App/MerchantStoreCharacterView.swift:522` | `aiNPC.voice.hold` (`.disabled(true)`) | Hold-to-record live audio sampling is unimplemented natively; preset sample enrollment (`aiNPC.voice.useSample`) is active instead. | Merchant AI / Audio owner |
| `App/SquarePostVideoViews.swift:159-160` | `square.video.upload` (`.disabled(true)`) | Video OSS upload transport is unimplemented (`/api/common/uploadOSS` handles JPEG/PNG only). | Square / Media owner |
| `App/SquareDeletionViews.swift:5` | `SquareDeletionFlow` / `\.squareDeletion` | Kept dormant per `Tests/ContractChecks/test_w2_07_square_parity.py:51-67` (no host supplies `SquareDeletionCoordinator` yet). | Square / WP-04 owner |
| `App/StoryRuleEditorView.swift:433, 576`, `App/StoryParticipationWriterFactory.swift:9`, `App/TopicStoryParticipationHost.swift:1` | `PlayWriteUnavailableBanner` (`.storyJoin`, `.storyAnswer`), `StoryParticipationWriterFactory` | Backend has no player `/api/topic/join` route; `/api/topic/host-node-answer` and `/api/club/topic-node-answer` are host/club read endpoints (`pages/club/topic-story/index.js`), not player submission. | Play / Story owner |
| `App/ClubChannelMessagingView.swift:682-685` | Channel attachment picker (removed placeholder) | `/api/im/send` attachment upload and link-card composer UX are not yet implemented for club channels. | Club IM owner |
| `App/CooperationFlowEditors.swift:24` | `coopflow.submit.disabled` (`.disabled(true)`) | Terminal/unwritable cooperation state placeholder until cooperation write contract opens that form action. | Cooperation owner |
| `App/OrderLifecycleView.swift:332` | `orderLifecycle.review.disabled` (`.disabled(true)`) | Disabled review action shown when an order lifecycle item is ineligible or awaiting review route wiring. | Order Lifecycle owner |
| `App/FreeExploreCancelFactory.swift:8`, `App/BundleCancelCanceler.swift:10`, `App/BundleCancelView.swift:106` | `FreeExploreCancelFactory`, `BundleCancelCanceler` | Money-adjacent bundle cancellation stays behind bundle commerce review (`BNDMountGuardTests.swift`). | Bundle / Commerce owner |
| `App/BundleMerchantStallView.swift:20`, `App/BundleVoucherView.swift:4`, `App/BundleReviewComposeView.swift:34`, `App/BundleReviewListView.swift:13`, `Core/BundleOfferClient.swift:45` | Bundle stall, voucher, and review unavailable views | Marked `BLOCKED-BACKEND` (B-03) and awaiting reviewed bundle offer/voucher/review endpoints. | Bundle / Backend owner |
| `Core/MapCoreEntryHostRouter.swift:40-54` | `merchantSideQuests`, `personalFog`, `sharedLocation`, `cityOperation` | Unlaunched W14, W14.6, W13.5-W13.7, and W20 features awaiting backend services and privacy signoff. | Map / City Ops owners |
| `App/PlaySessionView.swift:67`, `App/PlayExperienceView.swift:429`, `App/RoamLiveSessionView.swift:175`, `App/SearchMapCanvas.swift:27` | `CYMapPlaceholder` | Intentional static kit placeholder backdrop when live interactive map canvas is off or unnecessary. | Map / Play Canvas owner |
| `App/OwnerDecisionFixtureHost.swift:5` | `OwnerDecisionFixtureHost` | Pre-existing fixture view without `#if DEBUG`, flagged by `Tests/ContractChecks/test_accessibility_hardening_wave.py:178` (`FPM7FixturesAreDebugOnly`). | WP-10 / Build Hygiene owner |
| Open `docs/release/completeness-matrix.csv` & money-gated routes | `/api/registration/payment-readiness`, `/api/audit/appeal*`, `/api/club-compensation/editions/empty-reason`, `/api/club/settlement/mine`, `/api/club/personal-receiver/*`, `/api/merchant/payout-account`, `/api/merchant/commerce/order*`, `/api/merchant/npc/review`, `/api/coop/invite/read|request*`, `/api/club/lead/release-station|unlock-chapter-receipt`, `/api/audit/guard/*`, `/api/creativesquare/delete`, plus `ReviewedAreaSwitch` money/payout writes | Endpoints still unimplemented on native client (`MISSING` / `IN-PROGRESS` matrix rows) or intentionally gated off on production (`www.chengyinhub.com`) until owner enables money/payout writes. | Release / Domain owners |

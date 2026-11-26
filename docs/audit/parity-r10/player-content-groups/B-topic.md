# Parity + native re-audit r10, group B (pages/topic/*)

- App: `origin/ui/combined-r7` @ `82bcf2c2d` (r9 audited `ebf6c160c`; 212 commits since). Group files were diffed `ebf6c160c..82bcf2c2d`, and every r9 queue row was re-read in code, not in commit messages.
- MP: `/home/user/hengyin/chengyinhub-xcx`. Paths are relative to `pages/topic/` unless they start with `pages/`, `utils/` or `subpackage`.
- Method: same lines and formula as r9. Page parity = (✅ + ⚠️) / (lines − N/A). Only lines whose status changed are listed.
- Native rule: `docs/briefs/native-r2.md` (everything Apple-native). Verdict per page: native (essentially no custom chrome), partly (system containers, some custom chrome), custom (custom chrome dominates). Group native % = (native 1, partly 0.5, custom 0) / pages. `CYColor.*` tokens and `.cyText` text styles are allowed by the brief (they resolve to system colours and Dynamic Type) and are not counted.
- MP-first rule (`owner-decisions-1124.md`): only pay / refund / payout / withdrawal / paid orders are "money, not a gap".

## 1. Per-page parity and native verdict

| page | r9 | r10 | native | non-Apple elements |
|---|---|---|---|---|
| topic/index | 53/59 (89.8%) | **54/59 (91.5%)** | custom | ~42 |
| topic/merchantinfo | 27/31 (87.1%) | **31/31 (100%)** | custom | 10 |
| topic/merchantapply | 13/17 (76.5%) | **15/17 (88.2%)** | native | 2 |
| topic/pricing | 11/18 (61.1%) | 11/18 (61.1%) | partly | 4 |
| topic/pricing/partner | 10/10 (100%) | 10/10 (100%) | partly | 2 |
| topic/catalog | 3/3 (100%) | 3/3 (100%) | native (redirect only, no UI) | 0 live (dead custom view, see R8-PC-B6-1) |
| **total** | **117/138 (84.8%)** | **124/138 (89.9%)** (+7 lines) | **50%** (3/6) | |

Changed lines:
- topic/index #6 guest reads public topic ❌ → ✅ (`c9da95476` App/AppCompositionRoot.swift:692 returns `.available` for a guest; :3537-3542 guest topic read; Core/TopicReading.swift:55-58; App/PlatformConsumerSessionOwner.swift:43-46, 97-103 sign-in only on 收藏/buy/review via `asSignedIn`, App/TopicDetailView.swift:640-643).
- topic/index #46 到店礼 ⚠️ → ✅ (`c9da95476` Core/TopicContracts.swift `derivativeBenefits` / `shopGift`; App/TopicXcxSections.swift:546-547, 616-620). This does not change the count (⚠️ already counted). Net topic/index: +1 (53 → 54).
- merchantinfo #5 apply, #7 withdraw, #8 respond, #22 invite ❌ → ✅ (`b06ebda26` Core/MerchantContentService.swift:124 defaults all four to `true`; AppSession.swift:7273 uses `.init()`; respond/invite exits AppCompositionRoot.swift:3558-3575 follow that approval; confirm enable MerchantContentViews.swift:617 now passes).
- merchantapply #5 map picker ❌ → ✅ (`8ee92d70d` App/MPGap/PlayerContent/PlayerContentRound4Views.swift:185-327: `MapReader` tap-to-pin, `MKLocalSearch` + `.searchable`, Cancel/Save toolbar, Save disabled until a real point, no default coordinate).
- merchantapply #7 photos ❌ → ✅ (`1a64faf06` PlayerContentRound4Views.swift:88-115, 162-179 upload via `playerContentImageUploader`, App/QuestifyApp.swift:474; append to `picUrl` ≤9, MerchantContentEditor.swift:229-232).
- merchantapply #12 submit create ⚠️ → ✅ (real coordinates and photos now reach `api/registration/merchant/create`; count unchanged).

## 2. r9 row status

| id | r9 sev | r10 status | evidence |
|---|---|---|---|
| R8-PC-B1-1 | P0 | open | App/GlobalSearchLinksAndTemplates.swift:529-539: `create` builds the contract then throws `.unavailable` on every path (only change: `sourceChannelCode` passed, `bb689268e`) |
| R7-PC-B2-1 | P0 | fixed (`b06ebda26` Core/MerchantContentService.swift:124; App/MerchantContentMPWriteRoute.swift:14-16; App/AppSession.swift:7407-7414) | apply/withdraw/respond/invite default on; no caller overrides |
| R7-PC-B3-2 | P0 | fixed (`8ee92d70d` App/MPGap/PlayerContent/PlayerContentRound4Views.swift:185-327) | pin follows tap or search; Save disabled until chosen |
| R7-PC-B4-1 | P0 | open | Core/RuntimeDependencyConfiguration.swift:115-128 still returns `PublisherLifecycleGrants(reads:ownership:graduation:)` with "Pricing mutations … stay off". Worse wording: Core/PlayerContentMPContract.swift:12-13 (`139e06853`) now ties `pricingGrantEnabled` to the money switch and calls pricing confirm "a payment write". MP pricing/index.js:419-460 is a final-price save, not money |
| R8-PC-B4-1 | P1 | open | App/PublisherLifecycleViews.swift:281-302 still a stub, `ticketPrices: []` at :291 |
| R7-PC-B1-4 | P1 | fixed (`c9da95476` App/AppCompositionRoot.swift:692, 3537-3542; Core/TopicReading.swift:55-58; App/PlatformConsumerSessionOwner.swift:43-46, 97-103) | |
| R7-PC-B1-5 | P1 | open | App/TopicDetailView.swift:463 `onStart` still opens the ticket wallet; MP index.js:722 goes to `/pages/play/index` |
| R7-PC-B1-6 | P1 | open | App/TopicXcxSections.swift:570 still `completedCount: 0, totalCount: 0`; no merchant cards |
| R7-PC-B1-7 | P1 | open | App/ContextualReviewComposer.swift:20-50 has no PhotosPicker |
| R7-PC-B1-12 | P1 | open | `TopicPostPurchaseRevealView` (PlayerContentRound4Views.swift:331) has no call site |
| R7-PC-B3-3 | P1 | open | no shop card in App/MerchantContentEditor.swift:243-262; `MerchantApplySuccessSummaryView` exists (App/MPGap/PlayerContent/PlayerContentRound2Views.swift:100) but has no call site |
| R9-PC-B3-1 | P1 | fixed (`1a64faf06` PlayerContentRound4Views.swift:88-115, 162-179) | |
| R7-PC-B4-3 | P1 | open | `TopicPricingGapSection` has no call site; App/PublisherLifecycleViews.swift:291 |
| R9-PC-B3-2 | P2 | fixed (`1ca7768fe` App/MerchantContentEditor.swift:118-119 `showsSubmit: false`; PlayerContentRound4Views.swift:141-153) | |
| R7-PC-B2-5 | P2 | open | App/MerchantContentViews.swift unchanged since r9 (raw LabeledContent at :234-276) |
| R7-PC-B1-13 | P2 | open | App/TopicDetailView.swift:383 opens the picker without a preselection |
| R7-PC-B1-18 | P2 | fixed (`c9da95476` Core/TopicContracts.swift `derivativeBenefits`; App/TopicXcxSections.swift:546-547, 616-620) | |
| R8-PC-B6-1 | P2 | open | App/PublicCatalogViews.swift still compiled; App/NativeEntryLandingView.swift:56 |
| R9-PC-BN-3 | P2 | open | App/ContextualReviewComposer.swift:30 fixed `32×32` |
| R9-PC-BN-4 | P2 | open | App/TopicDetailView.swift:488-492 `onTapGesture` + manual `.isButton` |
| R9-PC-BN-5 | P2 | fixed (`c9da95476` App/PlatformConsumerSessionOwner.swift:43-46) | the custom signed-out VStack is gone; guests read the page |

Of 21 r9 rows: **7 fixed, 0 partly, 14 open**.

## 3. Native findings per page

### topic/index — custom
Base is `List(.insetGrouped)` (App/TopicDetailView.swift:253, 549), but custom chrome dominates.
- App/TopicDetailView.swift:70 `CYLoadingStateView`.
- :134-137 `CYOptionSheet` / `CYOptionSheetItem` (club picker).
- :157, :163 `CYField` (contact name/phone); :174 `CYPrimaryButtonStyle`.
- :192, :205, :218, :236 `CYModal` (four custom modals).
- :260 `CYCard(variant: .elevated, radius:)` no-cover hero card; :280 `.clipShape(RoundedRectangle(CYRadius.xl))` gallery; :284 `CYDesignedCover`.
- :309-313 beta badge: hand-drawn `Capsule().fill(brandSoft)` with fixed padding.
- :478, :486, :534 `CYPillButton` (self-play, write review, paywall unlock).
- :488-492 `onTapGesture` + manual `.isButton` (R9-PC-BN-4).
- :552-553 `.scrollContentBackground(.hidden)` + `.background(CYColor.bgPage)`; :556-563 custom pinned tab overlay with `.background(palette.bgPage)`.
- :842 `CYEmptyState`; :844 `CYPillButton` (refused state).
- App/TopicXcxSections.swift:28-50 `CYTabs(.sticky)` custom tab strip; :75 horizontal `ScrollView` chips with :84 `RoundedRectangle` background and :109 `Capsule` background; :93, :238 `CYAvatarView`; :179 stat bar card `.background(bgElevated, in: RoundedRectangle(CYRadius.lg))`; :233 lineup horizontal `ScrollView`.
- App/TopicXcxSections.swift:336 `CYFooterBar` custom bottom bar; :348, :358, :364, :377, :383 `.buttonStyle(.cyPrimary)`; :318, :402-407 `cyHeroSource` hero morph with custom corner radius; :426-437 `TopicBarRecede` `.clipShape(RoundedRectangle(CYRadius.xl))`.
- App/TopicXcxSections.swift:581-583 route chip on `CYNight.lantern` / `CYNight.glassFill` (night palette) in a `Capsule`; :611 numbered `Circle()` fill; :639 `.clipShape(RoundedRectangle(CYRadius.sm))`.
- App/MPGap/PlayerContent/TopicRouteMapAndTeamsSection.swift:73-74 custom circle pins; :81 map `.clipShape(RoundedRectangle(CYRadius.lg))`; :110-111, :147-148 `bgSurface` + `RoundedRectangle` cards.
- App/ContextualReviewComposer.swift:30 fixed `32×32` star frame (R9-PC-BN-3). The composer itself is a `Form` (good).
- No `.preferredColorScheme(.dark)`, no gradients, no `.shadow`, no hex/CYRGB on this page.

### topic/merchantinfo — custom
`MerchantContentDocumentView` is `ScrollView` + `LazyVStack(spacing: 18)` + `.padding()` instead of a `List`.
- App/MerchantContentViews.swift:107-118 `ScrollView` + `LazyVStack` page body.
- :116, :704 `CYSkeleton`.
- :216 `CYConfirmSheet`.
- :285-301 rows as `VStack` with custom spacing; :301, :518 `CYEmptyState`.
- :526-538 `MerchantContentRowLinkStyle`: hand-drawn row with `bgSurface` + `RoundedRectangle(CYRadius.sm)` and a drawn chevron, applied to every row (:522).
- :616 `CYPillButtonStyle(.primary)` in the review sheet (the sheet itself is a `Form`, :589).
- Out of group but same file: `MerchantContentHomeView` :13 is also `ScrollView` + `LazyVStack`.

### topic/merchantapply — native
`MerchantContentEditView` is a `Form` (App/MerchantContentEditor.swift:72) with no CY components. The picker sheet is `Form` + `PhotosPicker` + `TextEditor` (PlayerContentRound4Views.swift:51-153), and the map sheet is `NavigationStack` + `Form` + `MapReader`/`Map`/`Marker` + `.searchable` + toolbar Cancel/Save (:218-292). The `onTapGesture` at :229 is the `MapReader` tap-to-pin pattern, not a button substitute.
- PlayerContentRound4Views.swift:118-124 photo strip: horizontal `ScrollView` with `.clipShape(RoundedRectangle(CYRadius.md))` thumbnails at a fixed `120×72`.

### topic/pricing — partly
`PublisherPricingView` is a `Form` (App/PublisherLifecycleViews.swift:48).
- :51, :55 `CYEmptyState` (missing topic, load error).
- :88 `CYPillButton` (recalculate floor / refresh minimum).
- :152 `CYPillButton` (confirm final price).

### topic/pricing/partner — partly
`PublisherPartnerView` is a `List` (App/PublisherLifecycleViews.swift:328).
- :340 `CYSkeleton`.
- :346 `CYPillButtonStyle(.secondary)` with a fixed `minHeight: 44`.

### topic/catalog — native (no UI)
MP catalog/index.js is a redirect stub (topic id → topic page, else home). The app has no live catalog screen. The dead `PublicCatalogViews` (App/PublicCatalogViews.swift:33-217, 446-510: `ScrollView`, `CYExploreGround`, `CYImageCard`, `CYErrorStateView`, `CYLoadingStateView`, `CYEmptyStateView`, `CYMorphButton`, `RoundedRectangle` backgrounds) is custom, but it is unreachable; deleting it is R8-PC-B6-1.

## 4. Group fix queue (r10)

| id | severity | MP file:line | app file:line | what to do | owner |
|---|---|---|---|---|---|
| R8-PC-B1-1 | P0 | pages/topic/index/index.js:1469 (`/api/registration/create`) | App/GlobalSearchLinksAndTemplates.swift:529-539; Core/PlayerContentMPContract.swift:12 | `create` throws on every path. A free (¥0 quote) self-play order is not money: delegate to `inner.create(intent)` for it. Paid totals are **money, not a gap**: follow `ReleaseMoneyWriteSwitch.paymentEnabled`, and when it is off show the unavailable state before the name/phone form | Cursor Core |
| R7-PC-B4-1 | P0 | pages/topic/pricing/index.js:419-460 | Core/RuntimeDependencyConfiguration.swift:115-128; Core/PlayerContentMPContract.swift:12-13 | Issue `pricing` in `publisherGrants` (as `131300ff6` did) and make `pricingGrantEnabled` true on its own, not tied to `moneyEnabled`. Pricing confirm saves the final price and waits for sale review; it is not a payment | Cursor Core |
| R8-PC-B4-1 | P1 | pages/topic/pricing/index.js:441-460 | App/PublisherLifecycleViews.swift:281-302 | Call `coordinator.confirm` (scope, ticketPrices). On 200 toast `res.msg` and go back; if it contains 支付资质 show the 终价已确认 alert; on error show `submitError` | Cursor Core |
| R7-PC-B1-5 | P1 | pages/topic/index/index.js:722 | App/TopicDetailView.swift:463 | After the safety check passes, open the play runtime for the topic, not the ticket wallet | Claude App |
| R7-PC-B1-6 | P1 | pages/topic/index/index.js:665-669, 765-780 | App/TopicXcxSections.swift:570 | Feed `completedCount`/`totalCount` from `/api/play/nodes` (bought only) and merchant cards from `/api/free-explore/bundle/catalog` (Core/MPGap/PlayerContent/PlayerContentGapService.swift:95-123) | Claude App |
| R7-PC-B1-7 | P1 | pages/topic/index/index.wxml:441-460 | App/ContextualReviewComposer.swift:20-50 | Add a ≤9 `PhotosPicker` section using `playerContentImageUploader`, send as `img_arr` | Claude App |
| R7-PC-B1-12 | P1 | pages/topic/index/index.wxml:511, 535-539; index.js:919 | App/MPGap/PlayerContent/PlayerContentRound4Views.swift:331 | Mount `TopicPostPurchaseRevealView` after a successful create (free now; paid follows the money switch), with the consent toggle | Claude App |
| R7-PC-B3-3 | P1 | pages/topic/merchantapply/index.wxml:56-60, 173-216; index.js:235 | App/MerchantContentEditor.swift:243-262; App/MPGap/PlayerContent/PlayerContentRound2Views.swift:100 | Add the shop card from `/api/merchant/info`, and mount `MerchantApplySuccessSummaryView` after create (查看承接进度 → registrations list) | Claude App |
| R7-PC-B4-3 | P1 | pages/topic/pricing/index.wxml:45-86, 104-109 | App/MPGap/PlayerContent/TopicAndOfficialGapSections.swift:48; App/PublisherLifecycleViews.swift:291 | Mount `TopicPricingGapSection` (per-ticket prices → `ticketPrices`, fee/到手, 结算待处理, sale status) | Claude App |
| R7-PC-B2-5 | P2 | pages/topic/merchantinfo/merchantinfo.wxml:120-372 | App/MerchantContentViews.swift:234-276, 476 | Designed rows for host recruit stats (nodeFilled/nodeTotal/pendingCount) and the other raw fields | Claude App |
| R7-PC-B1-13 | P2 | pages/topic/index/index.wxml:227 (`bmClick`) | App/TopicDetailView.swift:383 | Pass the tapped ticket into the session picker as the preselection | Claude App |
| R8-PC-B6-1 | P2 | pages/topic/catalog/index.js:1-10 | App/PublicCatalogViews.swift; App/NativeEntryLandingView.swift:56 | Delete the unreachable `PublicCatalogViews` and its host wiring (also removes its custom chrome) | Claude App |
| R9-PC-BN-3 | P2 | — (native) | App/ContextualReviewComposer.swift:30 | Use `@ScaledMetric` for the star size | Claude App |
| R9-PC-BN-4 | P2 | — (native) | App/TopicDetailView.swift:488-492 | Make the empty-review card a `Button` instead of `onTapGesture` + manual trait | Claude App |
| R10-PC-B-N1 | P2 | — (native) | App/TopicDetailView.swift:130-240 | Replace `CYOptionSheet` with `.confirmationDialog`/`Menu`, `CYModal` ×4 with `.alert`/`.sheet`+detents, `CYField` with `TextField` in a `Form` (`.textContentType`), `CYPrimaryButtonStyle` with `.borderedProminent` | Claude App |
| R10-PC-B-N2 | P2 | — (native) | App/TopicDetailView.swift:70, 260-313, 842-844 | Hero: drop `CYCard`, `CYDesignedCover` and the custom clip; one `Image` header row; beta badge as `Text` in `.secondary` or tinted `Label`; `CYLoadingStateView` → `ProgressView`/`.redacted`; refused state → `ContentUnavailableView` with `actions:` `.bordered` button | Claude App |
| R10-PC-B-N3 | P2 | — (native) | App/TopicDetailView.swift:478, 486, 534, 552-553 | `CYPillButton` ×3 → `Button` `.bordered`/`.borderedProminent`; drop `.scrollContentBackground(.hidden)` + `bgPage` so the inset grouped list uses the system background | Claude App |
| R10-PC-B-N4 | P2 | — (native) | App/TopicXcxSections.swift:28-50; App/TopicDetailView.swift:556-563 | Replace the sticky `CYTabs` overlay with `Picker(.segmented)` in the first section (or a toolbar `Menu` that scrolls to 详情/故事/路线) | Claude App |
| R10-PC-B-N5 | P2 | — (native) | App/TopicXcxSections.swift:60-250 | Hero chips, stat bar card and lineup: plain `LabeledContent`/`Label` rows (no `RoundedRectangle`/`Capsule` backgrounds), lineup as `NavigationLink` rows; keep `CYAvatarView` only if it is a plain image | Claude App |
| R10-PC-B-N6 | P2 | — (native) | App/TopicXcxSections.swift:270-437 | Bottom bar: `.safeAreaInset(edge: .bottom)` with `.background(.bar)`, price `Text` + one `.borderedProminent` button, others `.bordered`; drop `CYFooterBar`, `.cyPrimary`, `cyHeroSource` radius and `TopicBarRecede` clip | Claude App |
| R10-PC-B-N7 | P2 | — (native) | App/TopicXcxSections.swift:576-640 | Route note chip: `Text` in `.secondary` (no `CYNight` palette, no `Capsule`); stop number as `Label`/plain text; stop image without custom corner clip | Claude App |
| R10-PC-B-N8 | P2 | — (native) | App/MPGap/PlayerContent/TopicRouteMapAndTeamsSection.swift:60-150 | Pins → `Marker` (tint for done), no clip on the `Map`; team cards → `List` rows | Claude App |
| R10-PC-B-N9 | P2 | — (native) | App/MerchantContentViews.swift:104-118, 704 | `MerchantContentDocumentView`: `ScrollView`+`LazyVStack` → `List(.insetGrouped)` with `Section`s; `CYSkeleton` → `ProgressView` | Claude App |
| R10-PC-B-N10 | P2 | — (native) | App/MerchantContentViews.swift:285-301, 518-538 | Rows → `NavigationLink`/`Button` rows in the list (delete `MerchantContentRowLinkStyle`); `CYEmptyState` → `ContentUnavailableView` | Claude App |
| R10-PC-B-N11 | P2 | — (native) | App/MerchantContentViews.swift:216, 616 | `CYConfirmSheet` → `.confirmationDialog`; review confirm `CYPillButtonStyle` → `.borderedProminent` | Claude App |
| R10-PC-B-N12 | P2 | — (native) | App/MPGap/PlayerContent/PlayerContentRound4Views.swift:118-124 | Photo thumbnails without the custom corner clip and fixed frame (system grid or plain images in the section) | Claude App |
| R10-PC-B-N13 | P2 | — (native) | App/PublisherLifecycleViews.swift:51, 55, 88, 152 | Pricing: `CYEmptyState` ×2 → `ContentUnavailableView`; `CYPillButton` ×2 → `.bordered` / `.borderedProminent` | Claude App |
| R10-PC-B-N14 | P2 | — (native) | App/PublisherLifecycleViews.swift:340, 346 | Partner: `CYSkeleton` → `ProgressView`; `CYPillButtonStyle` → `.bordered` (drop fixed `minHeight`) | Claude App |

Open: **P0 2 · P1 7 · P2 19** (28 rows: 14 r9 rows still open + 14 new native rows). Fixed since r9: **7** (R7-PC-B2-1, R7-PC-B3-2, R7-PC-B1-4, R9-PC-B3-1, R9-PC-B3-2, R7-PC-B1-18, R9-PC-BN-5). No new functional gaps found.

Money: the paid part of R8-PC-B1-1 (self-play order with a non-zero total) is **money, not a gap**. Pricing confirm (R7-PC-B4-1) is not money, although Core now labels it as one.

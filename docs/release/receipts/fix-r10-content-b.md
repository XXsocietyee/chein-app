# Receipt: fix/r10-content-b (lane content-b, fix round r10)

- Slice: `docs/audit/parity-r10/player-content-groups/C-activity.md` §4 and `D-subpackages.md` §4 (on `origin/design/handoff-r2`): all P0 (none) + P1, then P2.
- Base: `origin/ui/combined-r7` @ `d9832ac50`, merged again before each push.
- MP source repo (`hengyin/chengyinhub-xcx`) is not reachable from this session. MP citations come from the audit rows and the earlier r9 receipt (`fix-r9-player-content.md` on `origin/ci/acceptance`).
- No compiler in the cloud: Swift build, XCUITest and VoiceOver NOT_RUN. Gates at push: `check_scaffold.py`, `check_a11y_lint.py`, `contract_ratchet.py --check` (results below).
- Strings: `Resources/Localizable.xcstrings` + fragment `docs/port/strings/fix-r10-content-b.json` (`registration.pass.covered`, `social.article.image`).
- Many rows were already closed on the tip by `fix/r9-player-content` (merged after the r10 audit snapshot `82bcf2c2d`). Those rows cite that SHA. Every one was re-checked in code on this base.
- Status words: **fixed** · **partly** · **blocked** (needs another owner or conflicts with a brief rule) · **merchant release** (none in this slice).

## P1

| id | status | SHA | app file:line | note |
|---|---|---|---|---|
| R9-PC-C1-2 | fixed | 579750de3 (tip) | App/ActivityDetailView.swift:711-745 | Host footer is 取消活动并退款. Money is on in Release now (`ReviewedAreaSwitch.openMoney`), so `activityHostCancelAccess` is non-nil whenever a host is installed and the live button shows; the disabled variant remains only for a missing host |
| R7-PC-C2-1 | partly | d582e632f | App/RegistrationSheetView.swift:141-145; Core/ActivityDetail.swift (`merchantClosed`); Core/RegistrationContracts.swift (`coveredByPass`) | 商家暂停营业 banner (MP baoming.js:760-764) and 通行证 row from quote `mkt.coveredByPass` (js:1871-1876) are mounted. **Open:** 儿童年龄 picker needs `childAge` on quote/create (`RegistrationQuoteRequest` / `RegistrationCreateIntent`, money path, signed quote) and ticket `childCount/childAgeMin/childAgeMax`; 包含内容 needs the quote `delivery` row shape. Not changed blind without the MP source |
| R9-PC-C2-1 | fixed | 4478e3472 (tip) | App/RegistrationSheetView.swift:642+ (`hostReservationSection`) | 主持预约 section |
| R7-PC-C1-6 | fixed | 11b55e20a (+ ef6471025 tip) | Core/ContextualReviews.swift:23-27; App/ContextualReviewComposer.swift:23-24, 66-72 | ≤9 photos + `img_arr` were in; Core cap now the MP 300 (UTF-16, `maximumContents`), composer clips whole characters to it. CoreTests pin 300 valid / 301 invalid |
| R10-PC-C6-1 | fixed | 695cd746c (tip) | App/GlobalSearchLinksAndTemplates.swift (`PlayerContentOfficialReader.recoverBroadcast`); Core/PlayerContentMPContract.swift:415-430 | POST `/api/official/broadcast/{id}/recover` restored in the production reader (Core contract builds the request). `OfficialEventReading`'s default still throws, only for readers that do not override |
| R10-PC-C6-2 | fixed | 695cd746c (tip) | App/OfficialPrivateViews.swift (`OfficialBroadcastInlineStatsRow`) | 安全恢复原投递 + confirm + inline error + stats re-read |
| R7-PC-D1-4 | fixed | 7d71f2209 (tip) | App/CreatorContentViews.swift; App/TemplateAuthoringMineView.swift | 模板 tab lists own-shelf rows inline |
| R10-PC-D-N13 | fixed | b8e2c23a8 (tip) | App/VideoBountyView.swift (`VideoBountyAppealSheet`) | system Form, no CYNight |

## P2 — parity

| id | status | SHA | app file:line | note |
|---|---|---|---|---|
| R9-PC-C1-1 | fixed | c22e01bc5 (tip) | App/MPGap/PlayerContent/PlayerContentRound2Views.swift (`ActivityCancelledStateView`) | |
| R7-PC-C1-5 | fixed | 48b65bc1a | Core/ActivityDetail.swift (`ActivityTicket.registrants`); App/ActivityPresentationComponents.swift (ticket card, `activity.ticket.registrants.<id>`) | MP index.wxml:89-96 lineup from `cmsRegistrationList` |
| R7-PC-C4-4 | fixed | c6a8f1a83 | App/PlayerGapViews.swift (`OfficialSignupCommandSection.run`) | after an APPLIED signup, `NativeNotificationPermissionAdapter.requestFromUserAction()` (only while undetermined) — MP official-detail/index.js:604-610 |
| R7-PC-C3-3 | fixed | 0d781059d (tip) | `official.bucket.upcoming` | 即将上线 |
| R7-PC-C4-5 | fixed | b3c239088 (tip) | `official.detail` | 活动详情 |
| R9-PC-C4-1 | fixed | ec64ed4ef (tip) | App/OfficialEventDetailView.swift | |
| R7-PC-C5-2 | fixed | 56da9bcf8 | App/OfficialActionViews.swift (`OfficialActionSheet.onBusyChange`, `OfficialInviteResponseActions.writing`) | 正在提交，请稍候 on the card, its buttons disabled while the sheet's write runs (MP index.js:177-193) |
| R9-PC-C6-1 | fixed | 1f06c015d (tip) | App/OfficialPrivateViews.swift:114 | |
| R9-PC-CN-1 | fixed | a22c8c50d (tip) | App/ActivityDetailView.swift | |
| R9-PC-CN-2 | fixed | 0aef2aedf (tip) | App/OfficialEventComponents.swift | |
| R9-PC-CN-3 | fixed | e6e9e8f5e (tip) | App/ActivityPeopleSection.swift; App/ContextualReviewComposer.swift | |
| R9-PC-D9-1 | fixed | b5f6908aa | App/MessagingHistoryView.swift (`openAttach`, `attachFocus`); App/IMExpandedViews.swift (`IMConversationControlsView.focus`) | 图片 → photo entry only, 位置 → location form only, 路线 → topic picker opens at once; 投票 unchanged |
| R9-PC-D4-1 | partly | 61f3d1269 | App/MPReviewedPageScreen.swift (`incomeOrganizerFinance`) | deep link now passes organizer finance (not for theme=merchant). **Open:** 主办分润 as the 4th filter segment — the 收益/主办分润 `WalletEarningsAccessibleTabs` is pinned by `WalletEarningsOverviewUITests`, `WalletEarningsSegmentHitAreaFlowTests` and `check_wallet_earnings_overview.py`; needs a coordinated test change |
| R9-PC-D5-1 | fixed | 7c2ae8e91 (tip) | App/WalletCommerceViews.swift (`WalletWithdrawPermissionGate`) | |
| R9-PC-D1-1 | fixed | a38979df5 (tip) | App/PublishingModesViews.swift | `PublishingProjectsView` kept only as fallback |
| R9-PC-D3-1 | fixed | c2dabfef5 | App/SocialGuideViews.swift (`SocialArticleMediaBlocks.segments`); App/MPGap/PlayerContent/PlayerContentRound2Views.swift (`SocialArticleRemoteImage`) | text / img / a in document order; images labelled 文章图片 |
| R7-PC-D2-4 | fixed | 243d3223a (tip) | App/SocialGuideViews.swift | |
| R9-PC-D9-2 | fixed | d87b7f6ec (tip) | App/CommunityMemberReportSheet.swift | |
| R9-PC-D7-1 | fixed | 9e02e49a6 (tip) | App/VideoBountyView.swift | |
| R9-PC-D7-2 | fixed | 188bb4a39 (tip) | App/VideoBountyView.swift | |

## P2 — native

Since the r10 audit the native-r2 sweeps on the tip rebuilt the shared wrappers on system components: `CYEmptyState` → `ContentUnavailableView` (App/DesignSystem/CYStates.swift:51), `CYLoadingStateView` → `ProgressView` (CYSharedStates.swift:33), `CYSkeleton`/`CYSkeletonBlock` → `.redacted(.placeholder)`, `CYPillButton` → `.borderedProminent/.bordered/.borderless` `.large` (CYPillButton.swift:8), `CYStatusChip` → secondary text / `Label`, `CYConfirmSheet` → system sheet + Form, `CYHeroHeader` → system title, `CYTabs` → segmented `Picker`, `CYListRow` → plain-style row. Rows whose remaining sites are only those wrappers count as fixed at the component level.

**Brief rule (owner 11-26): no visual redesign / do not restyle screens.** The leftover sites below are layout or surface changes (hero scrim, card surfaces, custom sheets, chat chrome); they are recorded as **blocked (design paused)**, not restyled in this lane.

| id | status | SHA | remaining site (this base) |
|---|---|---|---|
| R10-PC-C-N1 | blocked (design paused) | — | App/E1ActivityDetailParts.swift:55-66 `LinearGradient` scrim + `CYRadius.xl` clip (title sits on the photo; removing the scrim is a layout change) |
| R10-PC-C-N2 | partly | tip | `CYTabs` is a segmented Picker; App/E1ActivityDetailParts.swift:115, 149, 246 stats `ScrollView` strip + `cyDomainCard` remain (blocked, design paused) |
| R10-PC-C-N3 | partly | tip | App/ActivityDetailView.swift:398 one `questifyCardListRow` (info card) remains; `CYColor.bgPage`, card surfaces, tiles gone |
| R10-PC-C-N4 | fixed | a8c02e0a1 (+ tip) | 写评价 row is a `Label`; footer `CYPillButton` renders `.borderedProminent` |
| R10-PC-C-N5 | fixed | tip | no forced `.light`, `CYMapPlaceholder` or card surface left in App/ActivityDetailView.swift |
| R10-PC-C-N6 | fixed | tip | no `cyDomainCard` / clip / card surface left in App/ActivityPresentationComponents.swift |
| R10-PC-C-N7 | fixed (component) | tip | `CYPillButton` renders system buttons |
| R10-PC-C-N8 | partly | tip | `CYLoadingStateView` = `ProgressView`. App/RegistrationSheetView.swift:199, 222 `CYOptionSheet`, :394 `CYModal`, :167 `cyDomainPageBackground` remain (blocked, design paused) |
| R10-PC-C-N9 | blocked (design paused) | — | App/RegistrationSheetView.swift:310, 353 summary card (`RoundedRectangle` clip, `cyDomainCard`) |
| R10-PC-C-N10 | partly | tip | filter is a segmented `Picker`, empty is `ContentUnavailableView`; in-page `TextField` search kept on purpose (hides on 我的, MP), :126 `QuestifyCardButtonStyle`+`questifyCardListRow` remain |
| R10-PC-C-N11 | fixed | tip | no `CYStatusChip`/brand tint/`CYLoadSlot`/`Theme.Generated`/rounded box left in App/OfficialEventComponents.swift |
| R10-PC-C-N12 | partly | tip | App/OfficialEventDetailView.swift:162 `questifyCardListRow` remains; hero/mission card/chip/strip gone |
| R10-PC-C-N13 | partly | tip | App/OfficialEventDetailView.swift:289 `.background(.bar)` CTA bar remains (system material) |
| R10-PC-C-N14 | fixed | tip | inbox uses `ContentUnavailableView`, `Label`, no page background |
| R10-PC-C-N15 | fixed (component) | tip | no CY state/button wrappers left in App/OfficialActionViews.swift |
| R10-PC-C-N16 | partly | tip | App/OfficialPrivateViews.swift:162 `emptyRow` is a plain secondary row (no custom chrome) rather than `ContentUnavailableView` |
| R10-PC-C-N17 | partly | tip | states/sheet native; `CYConfirmConsequence` only feeds message text (:197, 427-445) |
| R10-PC-C-N18 | fixed | tip | no `CYFilterChip` / `CYPillButtonStyle` left |
| R10-PC-D-N1 | fixed | tip | App/CreatorContentViews.swift:189 segmented `Picker` |
| R10-PC-D-N2 | partly | tip | card chrome gone; :212 thumbnail corner clip remains |
| R10-PC-D-N3 | fixed (component) | tip | `CYEmptyState` = `ContentUnavailableView`; App/MyProjectTabViews.swift:99 `CYStateArt` (system state view) |
| R10-PC-D-N4 | fixed | tip | App/SocialGuideXcxParity.swift:20-50 plain `Label` rows, no `CYNight` |
| R10-PC-D-N5 | partly | tip | App/SocialGuideTemplateSection.swift:155 cover corner clip remains |
| R10-PC-D-N6 | partly | tip | App/SocialGuideViews.swift:41, 156-165 `SocialInformationArt` tile remains (blocked, design paused) |
| R10-PC-D-N7 | partly | tip | App/SocialGuideViews.swift:139 `.tint(CYDomainPalette(.player).brand)` remains (theme; not changed under the brief) |
| R10-PC-D-N8 | fixed | tip | no income card / badge chrome left in App/WalletCommerceViews.swift |
| R10-PC-D-N9 | partly | tip | plain list background gone; App/WalletCommerceViews.swift:172, 1228 `WalletEarningsHero` remains (blocked, design paused) |
| R10-PC-D-N10 | partly | tip | `orderCardSurface`/`CYListRow` gone; :226, 1177 `WalletQuickAction` circle buttons remain (blocked, design paused) |
| R10-PC-D-N11 | partly | tip | App/WalletEarningsParity.swift:31 `CYEmptyIllustration` art inside the system empty view |
| R10-PC-D-N12 | fixed | tip | App/WalletIncomeAnalysisView.swift:164 Swift Charts `BarMark` |
| R10-PC-D-N14 | fixed | tip | segmented `Picker`s, no `MPNightGround`/`CYMorphButton` |
| R10-PC-D-N15 | partly | tip | App/VideoBountyView.swift:237-287 `MPLoadSwitch`/`MPRows`, :248 `CYStatusChip` remain (blocked, design paused) |
| R10-PC-D-N16 | partly | tip | App/MessagingHomeView.swift:39 outbox `ScrollView` wraps a `ContentUnavailableView` |
| R10-PC-D-N17 | blocked (design paused) | — | App/IMInboxViews.swift:99, 196-294 `CYIMCoverArt` avatar art |
| R10-PC-D-N18 | partly | tip | option sheet built from `CYOptionSheetItem` (App/MessagingHistoryView.swift:684-710) and `CYConfirmConsequence` (:911) remain (blocked, design paused) |
| R10-PC-D-N19 | partly | tip | avatar `Circle` clips (:267, 563, 594) remain; `CYListRow`, states and page background gone |
| R10-PC-D-N20 | blocked (design paused) | — | App/MessageActionComposer.swift:184-216 morphing send button (blur), field background; :291 receipt bubble |

## Contract pins changed (intentional)

- `Tests/ContractChecks/test_activity_registration_parity_w2_06.py` — ticket CodingKeys now end in `cmsRegistrationList` (R7-PC-C1-5).
- `Tests/ContractChecks/test_social_account_contracts.py` — social key count 124 → 125 (`social.article.image`, R9-PC-D3-1).
- `Tests/ContractChecks/test_activity_reviews.py` — 写评价 row pin follows the `Label` (R10-PC-C-N4).
- `Tests/CoreTests/ContextualFlowTests.swift` — review text 300 valid / 301 invalid (R7-PC-C1-6).

## Gates (final push)

- `python3 tools/check_scaffold.py` → `PASS structural checks` (5190 Swift files, 19486 bilingual keys).
- `python3 -B tools/check_a11y_lint.py` → `PASS accessibility lint: 0 new`.
- `python3 -B tools/contract_ratchet.py --check` → 193 failing vs baseline 192; the one "new" id is
  `test_social_article_content.SocialArticleContentChecks.test_renderer_is_wired_only_to_existing_scoped_article_contents`,
  which **fails identically on the untouched base `origin/ui/combined-r7` @ d9832ac50** (checked in a clean worktree:
  ratchet there also reports it as the 1 new failure). Pre-existing, not caused by this lane; the stale pin is the
  `SocialReadScreen.onDisappear` token in App/SocialScreens. Left for the coordinator's baseline.
- No new Swift files, so `generate_project.py` was not needed. Swift build / XCUITest / VoiceOver: NOT_RUN (no compiler).

## Compile-risk notes for the coordinator

- `ActivityTicket` gained `registrants: [TopicRegistrant]`; `ActivityDetail` gained `merchantClosed: Bool`; `RegistrationQuote` gained `coveredByPass: Bool`. All three types only have `init(from:)` (no other initialisers found by grep).
- `OfficialActionSheet.init` and `IMConversationControlsView.init` gained defaulted parameters (`onBusyChange:`, `focus:`); existing call sites are unchanged.
- `ContextualReviewComposer.maximumContents` now reads `ContextualReviewDraft.maximumContents` (public static in Core).

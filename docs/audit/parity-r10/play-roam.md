# Parity + native audit r10: play-roam

Briefs: `origin/design/handoff-r2:docs/briefs/audit-parity-r9.md` (method), `native-r2.md` (owner: **everything native**), `owner-decisions-1124.md` (MP-first). Reviewer pass: no product code edited.

- **App audited:** `origin/ui/combined-r7` @ `82bcf2c2d` ("native r2 tokens"; r9 was `ebf6c160c`, 212 commits since).
- **MP:** `hengyin/chengyinhub-xcx`; MP file:line references carried from r9 (`06a1639d`), no MP drift re-diffed this round.
- **Area:** play runtime, roam home, free explore / live roam, city orienteering, the play-kit games (`PlayKitScreenKind`, 39 cases incl. the 6 legacy kits; "37 game kits" in the brief), journey, tools and P3 pages. Same 30-page list as r8/r9.
- **Method:** every r9 fix-queue row re-checked in code (grep + read at file:line). Native column: grep for every non-Apple element listed in `native-r2.md` (CY*/MP* chrome components, custom cards / corner radii / shadows, gradients, materials, hex / `CYRGB` / `Color(red:)`, fixed font sizes, custom inputs, forced dark outside the game stage), then a read of each hit.
- **Not compiled / not run** (no Swift toolchain). Runtime claims are from code reading.

## 1. Headline

| | r9 | **r10** | delta |
|---|---|---|---|
| Parity (present = ✅+⚠️+🔒) | 485/492 · 98.6 % | **488/491 · 99.4 %** | +3 lines, −1 denominator (badge-3d glow retired by native-r2) |
| Native % (native + ½ partly, 64 page + kit rows) | not measured | **25.8 %** (strict 0 %) | first measurement |
| P0 open | 0 | **0** | — |
| P1 open (parity) | 13 | **7** | −6 (ROAM-7, JSEAT-r8-1b, RTEAMS-3c, ROAM-8b, ROAM-9a, ROAM-9b fixed) |
| P2 open (parity) | ~44 | ~42 | SALBUM-r9-1 and roam tile-expand fixed |

- **Newly present (3):** roam passport tile expand (`789bfa7dd`, App/RoamHomeTabsView.swift `cyHeroSource`/`cyHeroDestination` → system zoom transition), seats phone transfer (`8cf39b57c`, App/JourneyLandingViews.swift:526-535, App/PlayerJourneyReadBindings.swift:271), my-teams leader applicant count (`bda928e91`, App/NearbyTeamViews.swift:520-561).
- **Retired (1):** badge-3d glow. `native-r2.md` "Remove: gradients, glows…". Decorative, no behaviour; not a gap.
- **Still not present (3):** POI share (RPOI-4, infra), seats save-invite image (P2), QA evidence table (QA-r9-1, P1).
- **Contract coverage** (Cursor checker on `ebf6c160c`, not re-run): play-roam 128 matched / 15 missing endpoint / 26 missing test.

## 2. r9 fix queue → r10 status (code-checked)

| r9 id | sev | r10 status |
|---|---|---|
| ROAM-7 | P1 | **fixed** (`83c3f2e91`): production gates issue both reads, App/AppCompositionRoot.swift:539-540 → App/ReviewedPlayerWriteLeases.swift:1208-1230; guest public GET admitted without a token in the transport (same commit). Device check still owed. |
| JSEAT-r8-1b | P1 | **fixed** (`8cf39b57c`): `JourneySeatsHost.transferHandler` App/JourneyLandingViews.swift:527-535 from `binding.transferSeat` App/PlayerJourneyReadBindings.swift:271; 转赠给同伴 shows at :668-674, sheet :697-699. |
| RTEAMS-3c | P1 | **fixed** (`bda928e91`): App/NearbyTeamViews.swift:520-561 → Core/NearbyTeamCoordinator.swift:103. |
| ROAM-8b | P1 | **fixed** (`af8d6da47`): App/RoamHomeTabsView.swift:620-631 + App/RoamPassportTileThumbnail.swift; empty → MP illustration. |
| ROAM-9a | P1 | **fixed** (`3a36313ae`): App/RoamLiveSessionView.swift:152-168, 45 s, GCJ-02, radius 3000, keeps rows on failure. |
| ROAM-9b | P1 | **fixed** (`3a36313ae`): tools sheet mounted App/RoamLiveSessionView.swift:130-150 as a system `Form` (App/MPGap/PlayRoam/RoamSessionToolsSheetView.swift:22). Runner rows inside it still custom (see native N-R9). |
| PLAY-6a | P1 | **open**: no App use of `PlatformBGMPreference` / `play.bgmOn` / `play.narrationOn`; `PlayToolsAndLeadSheetView` still unmounted (0 callers outside App/MPGap); play 游玩工具 is a `Menu` (App/PlayInPlayTools.swift:208-215). |
| OCARDS-3b | P1 | **open**: still `Menu {` App/ObjectCardViews.swift:42; `ObjectCardCategorySheetView` unmounted. Under native-r2 a toolbar `Menu` is the Apple control, so the fix is now: keep `Menu`, move it to the toolbar, keep MP category icons via `MPAsset`. |
| BWALL-3b | P1 | **open**: list/wall `Picker` still App/ObjectBadgeViews.swift:4-17, 169; default `.list` (:15). `046f727ce` only fixed images in the default list. |
| QA-r9-1 | P1 | **open**: `features` still `["hangman.pool", "qa.letterPool"]` Core/PlayContentCompatibility.swift:103; no `table`/`lastRule` decode or view. |
| JPROMO-3 | P1 | **open, re-scoped by native-r2**: `MPSectionHeader` App/MPParityKit.swift:439-447 is a hand-padded `Text`. Fix is now native: use `Section { } header: { Text }` (system header style) on every journey page; MP weight no longer drives a custom header. |
| JSEAT-8 | P1 | **open**: empty bar App/JourneyLandingViews.swift:585 + eyebrow :601. MP-first and native-r2 now agree: `.navigationTitle("开局大厅")`, drop the eyebrow and the 28 pt in-content title. |
| RPOI-5 / RROUTES-2 | P1 | **open**: no string sweep since r9 (`roam.detail` = 地点; `officialRoute.*` unchanged). |
| GROWTH-5 | P1 | **open**: App/GrowthCenterView.swift:23-24 "not drawn today"; :319-334 always `d_profile` with a custom `avatarRing` stroke. |
| RPOI-4 | P1 | **open, owner/infra** (universal-link domain + AASA). No `ShareLink` in App/RoamItemDetailView.swift. |
| SALBUM-r9-1 | P2 | **fixed** (`789bfa7dd`): App/RoamReceivedStampMetadataView.swift:225, 290 pass `scope.allowsRemoteImages` (default true, App/RoamStampViews.swift:27). |
| roam tile expand | P2 | **fixed** (`789bfa7dd`, system zoom transition; Reduce Motion → plain push). |
| badge-3d glow | P2 | **retired** (native-r2 removes glows). |
| seats save-invite image | P2 | **open** (no `ImageRenderer` / photo save in App/JourneyLandingViews.swift). |
| other P2 (SALBUM-6, TGOALS-4/-6, TANNIV-4, TEXPORT retry, GROWTH-9/LEADER-7, official-route #7, B3D-1, RTEAMS-1 polish, `TeamTrailModel.canRun`) | P2 | not re-verified line by line; `c42cf4d09` (SALBUM-6 paging) and `579cacf03` (leaderboard avatars) landed and likely close SALBUM-6 / LEADER-7. |

## 3. NATIVE column (owner rule: "everything native")

Scoring: **native** = no non-Apple element; **partly** = system `List`/`Form`/nav skeleton with some custom elements; **custom** = mostly custom chrome. Native % = (native + ½ partly) / rows.

**Correction to one sub-check:** player pages are **not** forced dark any more. `ThemeDomain.forcedColorScheme` returns `nil` for `.player` (App/Theme/Theme.swift:21-25, commit `82bcf2c2d`). `.cyGroupedSurface()` / `cyDomainPageBackground()` still paint a token background over the system grouped background (App/DesignSystem/CYFormSurface.swift:7, App/DesignSystem/CYScreenStyle.swift:48). This is noted once here and not repeated in each row.

**Forced dark outside the game stage (P1):** `.cyDomainScreen(.game)` forces dark (App/Theme/Theme.swift:23) on:
- the whole play runtime: App/PlayExperienceView.swift:116-134 (route map, backpack, node pages, Lists) and App/PlaySessionView.swift:45;
- every kit screen, forms included: App/PlayKitScreen.swift:388, :397.

Only the focused stage (`PlayKitScreenKind.isFocusedStage`, Core/PlayKitScreenContracts.swift:15) should stay dark.

**Tokens:** `.cyText` maps to Dynamic Type text styles, so it is accepted. `CYColor`/`CYNight` literals (`CYRGB`, App/DesignSystem/CYDesignTokens.swift:22, 68) are counted only where they paint custom surfaces.

### 3a. MP pages (30) + free explore / orienteering

| # | MP page | parity r10 | NATIVE | non-Apple elements (app file:line) |
|---|---|---|---|---|
| 1 | pages/roam/index | 36/36 | partly | `CYMapScaffold` RoamBrowserView.swift:494 (custom bottom panel, not `.sheet`+detents); `CYMapStreetGrid` :496; `CYGlassLabel` ×4 :504, :509, :518, :522; `CYGoLabel`/`CYGoPressStyle` :512-513; `.shadow` :502; custom search box (TextField `.plain` in a white Capsule) :354, :366; `CYSkeleton` :544; `CYEmptyState` :229, :549; `CYCoverArt` + RoundedRectangle :686-688; `.cyCelebrations` :52, :292; `.cyToast` :270; `.cyModalOverlay` :261; `.cyRootHeader` :739 (no `.navigationTitle`). RoamHomeTabsView.swift: **`Color(red:0.25,0.70,0.72)` :45**; shadow card :84-85; `CYImageCard` :267; `CYEmptyState` :337, :379; Capsule badge :607; RoundedRectangle :677, :702. RoamCityGuide.swift:92 `CYImageCard`. RoamPassportTileThumbnail.swift:17, :62 RoundedRectangle. No `MapUserLocationButton` (QuestifyDensityMap.swift:130). |
| 1b | free explore / live roam | (in 1) | partly | RoamLiveSessionView.swift: `CYMapScaffold` :112; `CYMapPlaceholder` :178; `CYFogLayer` :484, :486; `CYRoamStatusTag` :500; `.ultraThinMaterial` card :513-514; `CYGoPuck` :533, :538; `CYGoHoldPill` :543; `CYGoWave` :577 (decorative); `CYGlassButton` :567; `CYPillButton` :329; `CYSkeleton` :620; `CYStatusOfflineBanner` :186; `CYPermissionPrimerScreen` :441; `CYRevealToast` :412; `.cyCelebrations` :90, :408. Tools sheet (`Form`) native apart from runner avatar circle MPGap/PlayRoam/RoamSessionToolsSheetView.swift:71-74. |
| 1c | city orienteering (CityGamePanel, TeamOrientBoard, OrientScore, recovery, lobby) | (in play/roam) | custom | CityGamePanel.swift: `CYPillButton` ×7 :44, :85, :138, :177, :179, :189, :192; `.cyDomainCard` :50, :149, :182; `CYCityVerdict` :99; `CYCityTurnHUD` :101; `CYCityBoardRing` :106; RoundedRectangle :207. TeamOrientBoardView.swift: `CYStatusChip` :47, :90, :178; `CYPillButton` :49, :60, :92; RoundedRectangle :146, :198. OrientScoreView.swift: `CYCard` ×8 :217-422; `CYEmptyState` ×5 :149-166, :469; `CYListRow`+`CYRowIcon` :490. CityOrientationOriginalRecoveryView.swift: `CYHeroHeader` :10; `CYNoteBanner` ×6 :44, :65-73. OrientLobbyTeamsView.swift (List): `CYEmptyState` :25, :39. |
| 2 | pages/play/index (runtime) | 32/33 | custom | **forced dark over Lists** PlayExperienceView.swift:116 (List :340, :960) and PlaySessionView.swift:45; `CYMapScaffold` PlayExperienceView.swift:650; `CYGlassButton` :706, :710; `CYMedalScreen` :797; `CYMedalDeck` :1544; `CYRouteNodeRow` :307; `CYTaskStatusCard` :378, :1375; `CYStatusChip` ×8 :349-1568; RoundedRectangle answer cards :1154, :1315; TextField outside Form :1164, :1631; `CYSkeleton` :96, :404; `CYEmptyState` :101-112. PlayAdvancedView.swift: `CYPillButton` ×5 :45-98. PlayHUD.swift: material glass circles :222-226. PlayerGapViews.swift: `CYPillButtonStyle` ×10 :54-678. PlayToolsAndLeadSheetView.swift:71 `CYSheetHeader`. |
| 3 | pages/play/merchant | 20/20 | custom | PlayStoreDayMerchantView.swift: **LinearGradient** vignette :171; RoundedRectangle/UnevenRoundedRectangle :148, :174; `cyModalConfirm` ×4 :58, :85, :95, :360 (not `.confirmationDialog`); custom bg :43. |
| 4 | pages/play/circle | 3/3 | partly | PlayCircleRetiredLinkView.swift:8 `CYEmptyState`. |
| 5 | pages/play/poi-challenge | 14/14 | custom | ChallengePOIView.swift: ScrollView card page :339; `CYImageCard` :84, :236; `cyDomainCard` :134, :176; `CYChoiceRow` :160; **custom input** `.cyField` :168-170; `CYPillButton` ×5 :196-255; `CYStateLayout` :44. |
| 6 | subpackageRoam/citynode-code | 9/9 | custom | VerificationCodeView.swift: `CYHeroHeader` :45; `.cyHeroScreen` :36; `CYStatusChip` :55; `CYPillButton` ×4 :49, :104, :114, :118; `CYScanSweep` :90 (decorative); no List/Form/`.navigationTitle`. |
| 7 | subpackageRoam/history | 14/14 | custom | RoamHistoryViews.swift: ScrollView, `.cyNightGlass` :35; `CYNight` + hexagon cards :330, :332, :354, :409; `CYEmptyState` ×3 :44, :50, :365; RoamHistoryRemoteStatusBanner.swift:19 custom banner. |
| 8 | subpackageRoam/poi-detail | 19/20 | partly | RoamItemDetailView.swift (List skeleton): `CYEmptyState` ×5 :102-135; `.cyPlayerSheetGlass` :169; `.cyPageTitle` :538. RoamPOIActions.swift: `CYOptionSheet` :325 (not `.confirmationDialog`). |
| 9 | subpackageRoam/session | 15/15 | custom | RoamHistoryShareView.swift: `CYShareComposer` :49; `CYShareCardContent` :110, :118; `CYShareStat` ×4 :113-116; `CYPillButton` ×4 :169-298; `CYSectionHeader` :236. |
| 10 | subpackageRoam/nearby | 20/20 | custom | NearbyTeamMapViews.swift: `CYMapScaffold` :68; `CYPillButton` ×5 :49-275; `CYStatusChip` :149, :162; RoundedRectangle :54, :298. |
| 11 | subpackageRoam/citystamp | 12/12 | partly | RoamStampCameraView.swift (Form): `CYPillButton` ×5 :80-214; `CYStatusChip` :74; `CYScanMark`/`CYOrbitDots` :350-351. RoamSubpageParityViews.swift: TextField outside Form :434; stamp slip RoundedRectangle ×5 :563-625 + `.shadow` :605. |
| 12 | subpackageRoam/my-teams | 17/17 | custom | NearbyTeamViews.swift: `CYMapScaffold` :85; ScrollView `.cyDomainCard` :306, :438; `CYPillButton` ×8 :314-591; `CYStatusChip` ×6; **TextField outside Form** :324-325; `CYSheetContainer` :651. |
| 13 | subpackageRoam/official-routes | 7/7 | custom | OfficialRouteViews.swift: `CYStateLayout` ×5 :25-84; `.cyStaggeredAppear` :12, :36 (decorative); ScrollView. |
| 14 | subpackageRoam/official-route | 9/9 | custom | OfficialRouteViews.swift: `CYShareCardContent` :108-124; E1OfficialRouteParts.swift: RoundedRectangle :44, :71, :154; `.cyDomainCard` :92. |
| 15 | subpackageJourney/landing | 23/23 | custom | JourneyLandingViews.swift: `MPNightGround(glow:)` :313; `MPCard` :98; `MPSectionHeader` :91; `MPRow/MPRows` :336; `MPBottomBar` :345; `CYMorphButton` :350; `CYLoadingStateView` :299; `CYEmptyState` :302. |
| 16 | subpackageJourney/seats | 22/23 | custom | JourneyLandingViews.swift: `MPCard/MPRow` :623, :635, :669; `CYHoldToStartButton` + `MPBottomBar` :692; `CYStatusTag` :714; empty title :585 + eyebrow :601. |
| 17 | subpackageJourney/promo | 12/12 | custom | JourneyLandingViews.swift: `MPNightGround` :956; `MPCard` :968; `MPRow` ×4 :971-993; `MPSectionHeader` :983, :991; `MPGatedNote` :980. |
| 18 | subpackageJourney/settle | 26/26 | custom | JourneyReportViews.swift: `CYResultPhase` :966; `CYMomentSeal` :990; decorative CYMotion :960-1229; custom TextField box :1127-1130; `CYPillButton` ×4 :1169-1191; share-card LinearGradient :1279 (export image, OK). |
| 19 | subpackageJourney/report | 24/24 | custom | JourneyReportViews.swift: `MPNightGround` :491; `MPCard` :320, :568; `MPDivider` ×9; `MPRow` ×7 :570-603; `MPBottomBar` :625, :635. |
| 20 | subpackageTools/exploration-goals (+ capsule) | (55/55 for 20–23) | partly | RoamPassportPrivateToolsViews.swift: `CYSkeleton` :671, :330, :526; `CYStatusChip` :678; `CYEmptyState` :690. |
| 21 | subpackageTools/exploration-export | | partly | RoamExplorationExportView.swift: `CYPillButton` ×5 :323, :354, :359, :380, :384; `CYEmptyState` :339, :370. |
| 22 | subpackageTools/anniversary | | partly | RoamPassportToolsViews.swift: `CYSkeletonBlock` ×3 :240-242 (else List + DatePicker). |
| 23 | subpackageTools/monthly-recap | | partly | RoamPassportToolsViews.swift: hand-drawn bar chart :807-820 (use Swift Charts); circle buttons :669, :681; on-screen share card **LinearGradient** :890, RoundedRectangle :891, :910. |
| 24 | subpackageP3/growthcenter | 19/19 | partly | GrowthCenterView.swift: `CYCelebrationCenter`/`CYLevelUpMoment` :54, :101, :103 (confetti); `listRowBackground` ×3 :115, :232, :248; custom header :187; avatar ring :334; GrowthCenterComponents.swift `CYEmptyState` :29, :37, :48. |
| 25 | subpackageP3/leaderboard | 14/14 | partly | GrowthLeaderboardView.swift: `CYTabs(.chip)` :270 (use segmented `Picker`); **`Color(red:)` ×3** :295-296; `cyDomainCard` :190; custom empty VStack :45-58. |
| 26 | subpackageP3/stamp-camera | 13/13 | partly | RoamStampCameraView.swift: custom shutter :143-152; `CYPillButton` :80-214; `CYPermissionPrimerScreen` :170. |
| 27 | subpackageP3/stamp-album | 15/15 | custom | RoamStampViews.swift: ScrollView :162; `.cyFoilSheen` :219, :431; `.cyNewPulse` :220, :406; perforated tilted tiles :212-292; FAB `.shadow` :247-248; `CYFlipCard` :401; **LinearGradient** :420-421; `CYAlbumProgressRing` :351; `CYAlbumPager` :380. RoamReceivedStampMetadataView.swift `.regularMaterial` :119. |
| 28 | subpackageP3/badge-wall | 14/14 | custom | ObjectBadgeViews.swift: `CYFoilMedal` :187, :341; `cyFoilSheen` :196; `cyNewPulse` :198; `CYFlipCard` :332; **LinearGradient** :344; spring scale :347-348; `CYInfoCard` :406; list/wall `Picker` :169. |
| 29 | subpackageP3/badge-3d | 10/10 (glow retired) | partly | SceneKit stage accepted. 2D fallback ObjectBadgeViews.swift: `CYHeroHeader` :425-426; `rotation3DEffect` turntable :430; `CYListRow(card:)` :458. |
| 30 | subpackageP3/object-cards | 14/14 | partly | ObjectCardViews.swift: `CYFlipCard` :145; `cyFoilSheen` :150, :247; RoundedRectangle :188, :241; `CYFactRow` ×3 :211-214. ObjectCardPileView.swift: tilted pile + `.shadow` :29-71. Category sheet tile grid MPGap/PlayRoam/ObjectCardCategoryAndRenameSheets.swift:39-63. |

**Pages:** 0 native · 13 partly · 17 custom (rows 1–30) → **native 21.7 %** (strict: 0 %). Free explore 1b: partly. Orienteering 1c: custom.

### 3b. Game kits (`PlayKitScreenKind`, 39 kinds incl. 6 legacy; shell App/PlayKitScreen.swift)

Shell (all kits): forced dark App/PlayKitScreen.swift:388, :397; review panel RoundedRectangle :154; `cyModalConfirm` :79; `CYPillButton` :283; `.questifyPrimary` :137, :303; ScrollView/VStack shell :139-143, not `Form`.

| kit(s) | stage? | NATIVE | non-Apple elements (app file:line) |
|---|---|---|---|
| coinFlip | stage | partly | `CYPillButton` PlayKitDecisionProgressViews.swift:21 |
| diceRoll | stage | partly | material RoundedRectangle :42; `CYPillButton` :65 |
| random | stage | partly | `CYStatusChip` :86; material RoundedRectangle :90; `CYPillButton` :100 |
| dailySign | **form, forced dark** | partly | bare TextField :106 |
| walk | progress | custom | `CYNight` RoundedRectangle tiles :120-151; `CYStatusChip` :142 |
| bingo | progress | custom | `CYNight` cells :160, :175, :250; `CYScratchCard` :236 |
| reaction · countdown · stopwatch · typeIn | stage (typeIn input = form) | custom | PlayKitTimedChallengeView.swift: `CYHeroHeader` :34; `CYPillButton` ×6 :139-251; custom TextField box :102-106; white/black rings :126-127, :211-229 |
| ballShake · quietHold · compass · shout | stage | partly | PlayKitSensorChallengeView.swift: `CYPillButton` ×4 :45-73; `CYStatusChip` :42; decorative meters :147, :178-187 |
| qa | stage | partly | PlayKitQuestionForms.swift: `CYChoiceRow` :26; `.cyField` :37 |
| qa · accusation (Questo) | stage | custom | PlayKitQuestoViews.swift: RoundedRectangle ×8 :481-657; `rotation3DEffect` :514; `CYPillButton` ×6 :580-662 |
| qa · hangman (Questo) | stage | custom | PlayKitQuestoViews.swift: Capsule keys :66-83; RoundedRectangle :187-372; `CYPillButton` :205, :208 |
| branch | form | partly | `CYChoiceRow` PlayKitQuestionForms.swift:60 |
| estimate | form | partly | shell only |
| pricePair | form | partly | RoundedRectangle :113 |
| hiddenObject | stage | partly | key image RoundedRectangle :258-259 |
| predict | form | partly | `CYChoiceRow` :162; `.questifyPrimary` :236 |
| trueFalse | stage | partly | PlayKitNewGameForms.swift `CYChoiceRow` :7, :23; `CYNight` :51 |
| imageGuess | stage | custom | blur :61, :65; `CYPillButton` :99; `.cyField` :108-109 |
| jigsaw | stage | custom | `CYNight` tiles :208-218; `CYPillButton` :232 |
| scratchCard | stage | custom | `CYScratchCard` :139 |
| profile | **form, forced dark** | custom | PlayKitPersonalForms.swift: RoundedRectangle cards :50, :89; `CYPillButton` :55, :63; `.cyField` :110-112 |
| note | **form, forced dark** | custom | `CYInfoCard` :141; `.cyField` :147 |
| photoCheck | **form, forced dark** | custom | `CYStepIndicator` :241; `CYPillButton` ×8 :244-337; `CYNoteBanner` :264, :269 |
| scan | stage | partly | PlayKitSpatialRevealView.swift: `CYPillButton` :25; material :117, :231 |
| sort · match · classify | stage | partly | PlayKitReasoningForms.swift: `CYNight` RoundedRectangle :36; material :65 |
| compare | form | partly | PlayCompareView.swift: `CYPillButton` :29, :42; `cyModalConfirm` :56; `cyDomainCard` :94 |
| steps | **Form, forced dark** | partly | NativeMotionReminderViews.swift: `CYRowIcon` :13; `CYSectionHeader` :14; `CYPillButton` ×4 :76-122 |
| timeWindow | **Form, forced dark** | partly | `CYRowIcon` :174; `CYSectionHeader` :175; `CYDestructiveButtonStyle` :220; `CYPillButton` :223-269 |
| blindTaste | form | partly | PlayKitLegacyViews.swift Circle :41 |
| diyName | **form, forced dark** | custom | TextField in RoundedRectangle box :86-89 |
| slowTask | stage | custom | `CYScratchCard` :125 |
| silentOrder | stage | partly | `CYStatusChip` :24 |
| musicCorner | form | partly | `CYStatusChip` :11 |
| album sheet | stage | custom | PlayKitAlbumView.swift: `CYNight.glow` :46; flip :67; `.shadow` :102 |

**Kits:** 34 rows → 0 native · 20 partly · 14 custom → **native 29.4 %**.

### 3c. Area native %
64 rows (30 pages + 34 kit rows): 0 native · 33 partly · 31 custom → **native 25.8 %** (strict 0 %). r9 did not measure this.

## 4. Severity counts (r10)

| | parity | native | total open |
|---|---|---|---|
| **P0** | 0 | 0 | **0** |
| **P1** | 7 (8 queue rows, QA split) | 14 | **21** |
| **P2** | ~42 (carried) | 15 | ~57 |

Native is P1 when a whole surface is custom or forced dark outside the stage. It is P2 for component swaps inside an otherwise-native page. Native is not a go-live blocker under the r9 rules; the owner decides.

## 5. Fix queue (one agent-hour each)

Owner key: **Claude App** · **Cursor Core**. MP refs for native rows point at the MP page whose structure is kept; the visual change keeps every request, string, `MPAsset` and `accessibilityIdentifier`.

| id | sev | MP file:line | app file:line | what to do | owner |
|---|---|---|---|---|---|
| PLAY-6a | P1 | pages/play/index.wxml (游玩工具 sheet) | App/PlayInPlayTools.swift:208-215; App/MPGap/PlayRoam/PlayToolsAndLeadSheetView.swift:71 | Bind `PlatformBGMPreference` (`play.bgmOn`), `play.narrationOn`, `PlayReducedMotionPreference`. Mount the sheet as a `Form` with `Toggle`s; replace `CYSheetHeader` with `.navigationTitle` + `.cancellationAction`. | Claude App |
| QA-r9-1a | P1 | pages/play/utils/client-capabilities.js:27; playkit-view.js:606-609 | Core/PlayContentCompatibility.swift:103 | Decode `table`, `rules`, `lastRule` on PICK segments; declare `qa.table`. | Cursor Core |
| QA-r9-1b | P1 | pages/playkit/components/playkit-qa/index.wxml:62-100 | App/PlayKitQuestionForms.swift:20-40 | Native evidence table: `List` of rules + record rows; tap toggles strike (`.strikethrough`) and restore; highlight `lastRule` with a tinted `Label` after a wrong pick. | Claude App |
| OCARDS-3b | P1 | subpackageP3/object-cards/index/index.wxml:14-16, 45-52 | App/ObjectCardViews.swift:40-55 | Keep a system `Menu` but put it in a `ToolbarItem`, labelled with the MP category icon (`MPAsset`); delete the custom tile grid (MPGap/PlayRoam/ObjectCardCategoryAndRenameSheets.swift:39-63). | Claude App |
| BWALL-3b | P1 | subpackageP3/badge-wall/index/index.wxml:46-63, 97 | App/ObjectBadgeViews.swift:4-17, 169, 187-198 | Drop the list/wall `Picker`; one `LazyVGrid` (2 col) in 已点亮 / 未解锁 `Section`s showing `ObjectBadgeTileArtwork` + `Text`, with `.grayscale` for locked; remove `CYFoilMedal`, `cyFoilSheen`, `cyNewPulse`, `cyDomainCard`. | Claude App |
| JSEAT-8 | P1 | subpackageJourney/pages/seats/index.wxml:3-4 | App/JourneyLandingViews.swift:585, 601 | `.navigationTitle("开局大厅")`; remove the eyebrow and the 28 pt in-content title. | Claude App |
| RPOI-5/RROUTES-2 | P1 | subpackageRoam/poi-detail/index.json:3; official-routes/index.wxml:7-11 | Resources/Localizable.xcstrings `roam.detail`, `roamSub.w208.poi.*`, `officialRoute.*` | Use the MP nouns verbatim (zh-Hans); en follows. | Claude App |
| GROWTH-5 | P1 | subpackageP3/growthcenter/index/index.wxml:17-21 | App/GrowthCenterView.swift:23-24, 151-155, 319-334 | Draw the session avatar (reuse `ProfileCurrentAvatarView`), `d_profile` fallback; drop the custom `avatarRing` stroke. Cursor relaxes `test_growth_source_contract` for this view. | Claude App (+ Cursor test) |
| RPOI-4 | P1 | subpackageRoam/poi-detail/index.js:52-66 | App/RoamItemDetailView.swift (toolbar) | Owner picks the universal-link domain + AASA; then add a `ShareLink`. | owner (infra) |
| N-PLAY-DARK | P1 | pages/play/index.wxml (page) | App/PlayExperienceView.swift:116-134; App/PlaySessionView.swift:45 | Remove `.cyDomainScreen(.game)` / `.cyPushedChrome(domain: .game)` / `.tint(CYColor.gameAccent)` from the runtime shell, backpack, route map and node pages; they follow system Light/Dark with the system accent. | Claude App |
| N-KIT-DARK | P1 | pages/playkit/components/* | App/PlayKitScreen.swift:380-400 | Apply `.game` only when `kind.isFocusedStage` (Core/PlayKitScreenContracts.swift:15). Form kits (profile, note, photoCheck, dailySign, diyName, steps, timeWindow, branch, estimate, predict, pricePair, compare) follow the system. Replace `cyModalConfirm` :79 with `.confirmationDialog`. | Claude App |
| N-KIT-FORMS | P1 | pages/playkit/components/playkit-profile, -note, -photo | App/PlayKitPersonalForms.swift:9-165, 239-337 | Rebuild profile / note / photoCheck as `Form { Section { TextField(axis: .vertical) } footer: { validation } }`; drop `.cyField`, RoundedRectangle cards, `CYInfoCard`, `CYStepIndicator`, `CYNoteBanner`, `CYPillButton` ×8 → one `.borderedProminent`. | Claude App |
| N-KIT-CHOICE | P2 | playkit-qa / -branch / -predict / -truefalse | App/PlayKitQuestionForms.swift:26, 37, 60, 162; App/PlayKitNewGameForms.swift:7, 23, 109; App/PlayKitLegacyViews.swift:86-89 | Replace `CYChoiceRow` with `List` rows (`Button` + `checkmark`) or `Picker(.inline)`; `.cyField` TextFields → plain `TextField` in a `Section`. | Claude App |
| N-KIT-BUTTONS | P2 | playkit stage kits | App/PlayKitTimedChallengeView.swift:34-251; App/PlayKitSensorChallengeView.swift:42-73; App/PlayKitDecisionProgressViews.swift:21-100 | `CYPillButton` / `CYHeroHeader` / `CYStatusChip` → `.borderedProminent` / `.bordered` Button, `.navigationTitle`, secondary `Text`. Stage stays dark. | Claude App |
| N-KIT-QUESTO | P2 | playkit-qa (Questo hangman/accusation) | App/PlayKitQuestoViews.swift:56-372, 481-662 | Remove `rotation3DEffect` :514 and RoundedRectangle cards; accusation = `List` of suspects with `Button`s; hangman keys = `.bordered` `.controlSize(.small)` Buttons in a `LazyVGrid`. | Claude App |
| N-PLAY-MAP | P1 | pages/play/index.wxml (map) | App/PlayExperienceView.swift:650-710, 1154-1164, 1315 | Replace `CYMapScaffold` + `CYGlassButton` with `Map` + `.sheet(presentationDetents([.height(120), .medium, .large]))` + `presentationBackgroundInteraction(.enabled)` + `MapUserLocationButton`; answer cards → List rows. | Claude App |
| N-ROAM-MAP | P1 | pages/roam/index.wxml (map, search) | App/RoamBrowserView.swift:354-366, 494-549, 739; QuestifyDensityMap.swift:130 | Apple Maps pattern: `Map` + detented `.sheet`; `.searchable` for the capsule search; `CYGlassLabel`/`CYGoLabel` → toolbar `Button`/`Menu`; add `MapUserLocationButton`; `.cyRootHeader` → `.navigationTitle`. | Claude App |
| N-ROAM-HOME | P2 | pages/roam/index.wxml:186-205 | App/RoamHomeTabsView.swift:45, 84-85, 267, 607, 677, 702 | Remove `Color(red:)` :45, shadow card, `CYImageCard`, Capsule badge (`.badge`); tiles as `NavigationLink` `Label` rows with the `MPAsset` thumbnail. | Claude App |
| N-ROAM-LIVE | P1 | pages/roam/index.wxml (roam scene) | App/RoamLiveSessionView.swift:112, 178, 484-577 | Replace `CYMapScaffold`, material card, `CYGoPuck`/`CYGoHoldPill`/`CYGoWave`/`CYGlassButton` with `Map` + detented sheet + one `.borderedProminent` Start/End `Button` (hold → `.confirmationDialog`). Keep `CYFogLayer` only as the map overlay (game layer). | Claude App |
| N-ORIENT | P1 | subpackageCity (city orientation) pages | App/OrientScoreView.swift:143-490; App/CityGamePanel.swift:37-214; App/TeamOrientBoardView.swift:40-198 | `CYCard` ×8 → `List` `Section`s with `LabeledContent`; `CYPillButton` → system buttons; `CYStatusChip` → `Label`; `CYEmptyState` → `ContentUnavailableView`. Split: OrientScore (1 h), CityGamePanel + TeamOrientBoard (1 h). | Claude App |
| N-RCODE | P2 | subpackageRoam/citynode-code/index.wxml | App/VerificationCodeView.swift:34-164 | `Form` + `.navigationTitle`; remove `CYHeroHeader`, `CYScanSweep`; system buttons. | Claude App |
| N-RHIST | P1 | subpackageRoam/history/index.wxml | App/RoamHistoryViews.swift:35-409; RoamHistoryRemoteStatusBanner.swift:19 | `List` of `NavigationLink` rows (SF Symbol, semantic colours); remove night glass + hexagons; banner → `Section` footer `Label("…", systemImage: "info.circle")`. | Claude App |
| N-RPOI | P2 | subpackageRoam/poi-detail/index.wxml | App/RoamItemDetailView.swift:102-169, 538; App/RoamPOIActions.swift:320-344 | `CYOptionSheet` → `.confirmationDialog`; `CYEmptyState` → `ContentUnavailableView`; `.cyPageTitle` → `.navigationTitle`. | Claude App |
| N-RSESS | P2 | subpackageRoam/session/index.wxml | App/RoamHistoryShareView.swift:49-298 | Stats as `LabeledContent` in a `List`; `ShareLink` with the rendered image; drop `CYShare*` chrome on screen. | Claude App |
| N-RNEAR | P1 | subpackageRoam/nearby/index.wxml | App/NearbyTeamMapViews.swift:49-298 | `Map` + `Marker` + detented sheet; system buttons; `ProgressView`. | Claude App |
| N-RTEAMS | P1 | subpackageRoam/my-teams/index.wxml | App/NearbyTeamViews.swift:85-716 | ScrollView of `cyDomainCard` → `List` `Section`s; join-code TextFields :324-325 → `Form`; `CYSheetContainer` :651 → `.sheet` + detents; `CYPillButton` ×8 → system. Split map (with N-RNEAR) / list (1 h). | Claude App |
| N-ROUTES | P2 | subpackageRoam/official-routes, official-route | App/OfficialRouteViews.swift:12-124; App/E1OfficialRouteParts.swift:44-154 | `List` + `NavigationLink`; remove stagger animation; `CYStateLayout` → `ProgressView`/`ContentUnavailableView`. | Claude App |
| N-RSTAMP | P2 | subpackageRoam/citystamp; subpackageP3/stamp-camera | App/RoamStampCameraView.swift:74-351; App/RoamSubpageParityViews.swift:434, 563-625 | System buttons; TextField into the `Form`; remove slip RoundedRectangle/shadow and `CYScanMark`/`CYOrbitDots` (use `.symbolEffect`). | Claude App |
| N-JOURNEY-1 | P1 | subpackageJourney/pages/landing, promo | App/JourneyLandingViews.swift:91-369, 928-1002; App/MPParityKit.swift:439-447 | Replace `MPNightGround`/`MPCard`/`MPRow`/`MPSectionHeader`/`MPDivider`/`MPGatedNote` with `List { Section(header:) { LabeledContent } footer: }`; CTA in `.safeAreaInset` as `.borderedProminent`. Closes JPROMO-3. | Claude App |
| N-JOURNEY-2 | P1 | subpackageJourney/pages/seats | App/JourneyLandingViews.swift:543-805 | Same conversion; `CYHoldToStartButton` → `.borderedProminent` + `.confirmationDialog`. With JSEAT-8. | Claude App |
| N-JOURNEY-3 | P1 | subpackageJourney/pages/settle, report | App/JourneyReportViews.swift:248-673, 838-1200 | `List` sections; remove `CYMomentSeal`, `CYResultPhase`, decorative CYMotion; custom TextField box :1127 → `Form`; keep the share-card gradient only in the exported image. Split settle / report (1 h each). | Claude App |
| N-MERCHANT | P2 | pages/play/merchant.wxml | App/PlayStoreDayMerchantView.swift:43-190, 58-360 | Remove gradient hero; `List` with an `MPAsset` image row + `LabeledContent`; `cyModalConfirm` ×4 → `.confirmationDialog`. | Claude App |
| N-POICH | P2 | pages/play/poi-challenge.wxml | App/ChallengePOIView.swift:44-339 | `List(.insetGrouped)`; `.cyField` → `TextField` in `Section`; `CYChoiceRow` → checkmark rows; system buttons. | Claude App |
| N-ALBUM | P1 | subpackageP3/stamp-album/index/index.wxml:22 | App/RoamStampViews.swift:162-503 | `List` + `LazyVGrid` of plain `MPAsset`/remote thumbnails; remove foil, pulse, perforation, tilt, FAB shadow (camera → toolbar), `CYFlipCard` + LinearGradient detail → `List` with image row + `LabeledContent`. Split grid / detail. | Claude App |
| N-OCARDS | P2 | subpackageP3/object-cards/index/index.wxml | App/ObjectCardViews.swift:35-253; App/ObjectCardPileView.swift:29-71; App/SessionObjectCardsView.swift:34 | Detail: `List` image row + `LabeledContent` (no flip/foil); remove tilted pile/shadow (keep the grid path); `CYListRow` → `NavigationLink` `Label`. | Claude App |
| N-GROWTH | P2 | subpackageP3/growthcenter, leaderboard | App/GrowthCenterView.swift:54-248; App/GrowthLeaderboardView.swift:45-307; App/GrowthCenterComponents.swift:29-48 | Remove confetti/level-up cover (`.sensoryFeedback(.success)`), `listRowBackground`; `CYTabs(.chip)` → segmented `Picker`; podium `Color(red:)` ×3 → system `.yellow/.gray/.brown` or none; `CYEmptyState` → `ContentUnavailableView`. | Claude App |
| N-TOOLS | P2 | subpackageTools (4 pages) | App/RoamExplorationExportView.swift:323-384; App/RoamPassportPrivateToolsViews.swift:671-690; App/RoamPassportToolsViews.swift:240-242, 669-910 | System buttons, `ProgressView`/`.redacted`, `ContentUnavailableView`; recap bars → Swift Charts `BarMark`; gradient share face only in the export image. | Claude App |
| N-B3D | P2 | subpackageP3/badge-3d | App/ObjectBadgeViews.swift:425-464 | 2D fallback: `.navigationTitle`, `Section` rows, no `rotation3DEffect` turntable. | Claude App |
| seats-save | P2 | subpackageJourney/pages/seats/index.wxml (save invite image) | App/JourneyLandingViews.swift (invite sheet) | `ImageRenderer` → `ShareLink` (Save Image is in the share sheet). | Claude App |

**Design-system follow-up (coordinator):** retiring the CY* chrome components (`CYMapScaffold`, `CYPillButton`, `CYEmptyState`, `CYSkeleton`, `CYStatusChip`, `CYFlipCard`, `cyFoilSheen`, `CYCelebrationCenter`, `MPCard/MPRow/MPNightGround`) is the end state. Per-page rows above swap the call sites; delete the types once grep shows 0 callers.

## 6. Go-live blockers (P0)
**None.** Parity P0 = 0, and native findings are P1 or P2. Still to check on a device: ROAM-7 production reads and the stamp write path against the test server.

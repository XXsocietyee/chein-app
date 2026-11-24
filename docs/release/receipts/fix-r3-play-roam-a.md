# fix-r3 play-roam, half a (F-agent, App/ layer): receipt

- Branch: `fix/r3-play-roam-a`, from `origin/ui/combined-r7` (7fdfad1f1). `origin/restyle/r5-play-roam-city` (dcbc93064, which already holds `restyle/r6-system-rest`) was merged first because it touches the same files (brief: build on the restyle branch).
- Brief: `design/handoff-r2:docs/briefs/wave-x10.md`. Handbook rules applied: native iOS structure, App layer only, no Core/Tests edits, strings in a fragment.
- Half a = the first 15 pages of the round-1 audit list (`audit/parity-play-roam`): pages/roam, play/index, play/merchant, play/circle, play/poi-challenge, subpackageRoam citynode-code, history, poi-detail, session, nearby, citystamp, my-teams, official-routes, official-route, subpackageJourney landing.
- Gap sources used, newest first: `audit/parity-r7-play-roam` (FIX QUEUE, Claude rows + appendices), `review/r7-rev-{a,b,c}` (no App-layer row lands in these 15 pages; REV-C items are Gemini's parked MPGap views), round-1 audit, receipts `fix-parity-play-roam` / `fix-parity2-play-roam`.
- Strings: `docs/port/strings/fix-r3-play-roam-a.json` (3 keys; 加入码 reuses the catalog key `gap.team.joinCode`). Fixture routes: `docs/port/accept/f-play-roam-a.txt`.

## Fixed

| id | page | what changed | files |
|---|---|---|---|
| ROAM-3 | roam/index | `RoamBrowserView(presentedAsSheet:)`. As the City root's 漫游护照与工具 sheet: inline sheet title + one ✕ (cancellation), no second map / GO / large 漫游 root title, opens on the 漫游护照 tab, no 地图/列表 toggle. The deep-link page keeps the tab-root header. | RoamBrowserView, QuestifyApp (passes `presentedAsSheet: true`), RoamHomeFixtureSupport (`--uitesting-roam-home-sheet`) |
| ROAM-4 | roam/index | Live roam is map-first (PL-20): full-bleed fog map ground, the HUD as the glass card in the top controls, the status / consent / nearby / trace list in the shared `CYMapScaffold` three-detent panel; the start/pause/end bar, toolbar and inline title are unchanged. | RoamLiveSessionView |
| ROAM-10 | roam/index | Map title: no `minimumScaleFactor(0.6)` (wraps to 2 lines). Raw styles → tokens: item row status/address/no-coordinates, retained notice, peek teams-failed line, finished-story italic body, ticket `NO.0n` caption. | RoamBrowserView, RoamHomeTabsView, RoamLiveSessionView |
| PLAY-2 | play/index | `PlayStoryMapGround`: the CYMapScaffold `map:` slot draws the route's stops + dashed order line from `PlayRouteMapPresentation` (non-interactive, VoiceOver-hidden decoration; the panel list carries the same facts). Placeholder when no coordinates. Full route map stays one push away. | PlayExperienceView |
| PLAY-3 | play/index | ⋯ 游玩工具 menu row 扫码到达 (MP `onScanArriveFromTools`) while a single stop is current; it opens that stop, whose scan task owns the camera + `api/play/checkin`. | PlayInPlayTools, PlayExperienceView |
| PLAY-4 | play/index | HUD distance uses the MP units in Chinese (utils/geo.js: 米 / 公里), m / km in English. Default argument keeps the existing unit tests (`R4PlayFlowTests`) valid. | PlayHUD |
| PLAY-8 | play/index | Leader row 展示整团码 (MP `leadShowGroupCode` → scene qr-group-code) pushes the club group-code page for this activity (`pages/club/group-code/index?activityId=`), which owns issue + access checks. | PlayExperienceView |
| PLAY-9 | play/index | 13 raw `.font(.headline/.subheadline/.body/.caption)` → `.cyText(.cardTitle/.bodyCompact/.body/.meta)`. | PlayExperienceView |
| PLAYC-r7-1 | play/circle, play/index | Circle redirect and `pages/play/index` links carry `inviteCode` (sanitized by `PlayCircleLegacyLink`) and `registrationId`/`regId`. `SessionPlayRuntimeView(inviteCode:registrationID:)`: the invite is consumed once per opened link through the existing `PlayCircleCoordinator.loadOffers()` + `open(inviteCode:)` (`api/circle-theme/session/join`); the registration feeds `PlayExperienceView.entryCode` (入场码). | MPReviewedPageScreen, SessionPlayRuntimeView |
| RCODE-3 | citynode-code | The node name (or 据点 default) is the system inline title; the in-content heading and the unused `RoamCityVoucherHeading` are gone. | VerificationCodeView, RoamSubpageParityViews |
| RHIST-5 | history | Hero total `.data2XL`; run-card title `.cardTitle` via a new `RoamRunCardTitle(style:)`. | RoamHistoryViews, RoamSubpageParityViews |
| RPOI-2 | poi-detail | Favorite shows once: the 我的进度 action row's toggle when writes exist, else the node card's state line; the extra 已收藏 label is gone. | RoamItemDetailView, RoamSubpageParityViews |
| RPOI-6 | poi-detail | Inline title = the place's name (地点 only while unknown); in-list name row removed; merchant name/role and offline note on tokens; rejected-message label token. | RoamItemDetailView, RoamPOIActions |
| RSESS-5 | session | Share sheet: `CYHeroHeader` → system inline title `roam.share.title`; privacy line kept as body copy. | RoamHistoryShareView |
| RSTAMP-5 | citystamp | One title (inline nav); content starts with the `date · place` `.meta` line. | RoamSubpageParityViews |
| RTEAMS-3 (a) | my-teams | 我的队伍 tab toolbar 加入码 → existing `TeamInvitationEntryView` (Session host passes it; sign-in hand-off reused). | NearbyTeamViews, SessionNearbyTeamView |
| JLAND-8 | journey landing | Type ladder per MP wxss: tile name `.sectionTitle`, inviter `.label` secondary, rule key `.body` secondary, rule value `.bodyMedium` primary. | JourneyLandingViews |
| JLAND-9 (P2) | journey landing | Title pill wraps to 2 centred lines (rounded rect) instead of overflowing. | JourneyLandingViews |

Accessibility / Dynamic Type sweep on the 15 pages' files: no icon-only button without a label (the one hit, storeDay ⋯, is labelled on the next line), no `.font(.system(size:))`. New controls carry labels/identifiers (`play.tools.scanArrive` + hint, `playx.lead.showGroupCode`, `nearby.mine.joinCode` (identifier), `roam.passportSheet.close`).

## Left, with reasons

| id | why | owner |
|---|---|---|
| ROAM-8 | Passport photo tiles need (1) the latest track thumbnail / latest stamp image, which `RoamPassportHome` does not carry, (2) the MP illustrations (see MP assets below), (3) the owner ruling on the extra 徽章墙 / 时光胶囊 tiles. The grouped List stays meanwhile (native rule). | Cursor (Core fields) + C7 (assets) + owner |
| RTEAMS-1 | The topic page's team card exists only in Gemini's parked `App/MPGap/PlayerContent/TopicRouteMapAndTeamsSection.swift`; no live host to push `OrientLobbyTeamsView` from. Mount it there when the section is un-parked. | Gemini |
| RTEAMS-3 (b) | Leader `· N 个申请` needs a per-team applicant count; `NearbyTeamCoordinator.loadApplicants` fills one shared list. Request: a count read per leader team (MP POST applicants, not the MPGap GET). | Cursor |
| RTEAMS-5 | The duplicate `nearby.activeCount` row is pinned by `Tests/ContractChecks/test_nearby_mine_read_provenance.py:16`, and `nearby.expiry.rule` `.font(.footnote)` by `test_nearby_deadline_text.py:17`. Tests are Cursor's layer: please relax that assertion, then delete the row and move the expiry rule to `.cyText(.meta)`. | Cursor, then F |
| PLAYPOI-6 (P2) | `ChallengePOIView` has no `mediaScope` / `makeExternalMaps` from its hosts; switching to `PlatformExternalMapHost` without them would show "gated" instead of today's Apple Maps link. Needs host plumbing from RoamItemDetailView / MPReviewedPageScreen. | F (next round) |
| poi-detail #20 (P2) | The `.signIn` action error has no 登录 CTA; the action runs inside the place sheet, and a tab switch from inside it is not verified without a device. | F (next round) |
| PLAYM-2, RHIST-r7-1, RPOI-3, JREPORT-*, JSEAT-* | Contract / Core items in the r7 queue (Cursor), or pages in half b. | Cursor / half b |
| ROAM-7, RPOI-4, RPOI-5, RROUTES-2, JLAND-r7-1, RSTAMP-2, SCAM-1, SALBUM-1 | Owner decisions (guest read, share domain, noun glossary 据点/节点/地点 and 线路/路线, gift claim, `mediaUpload` / `stampExchange`, image policy). | owner |
| ROAM-13, RNEAR-2 | Whole features queued to Gemini (city strip; map-first nearby sheet). | Gemini |
| official-route #7 (P2) | No `imgUrl` on the route node model, so no thumbnail can be drawn. | Cursor |

Covered in flight, not touched (brief: skip): `restyle/*` (merged r5, visual), `gap/g1-player` parked MPGap screens (ROAM-9 tools sheet, PLAY-6 tools sheet, RPOI action-row shell, RHIST merged list), `cursor/*`, `port/*`.

## Core requests for Cursor
1. `RoamPassportHome`: latest track thumbnail and latest stamp image (ROAM-8).
2. Per-team pending-applicant count for leader rows on my-teams (RTEAMS-3b).
3. Relax `test_nearby_mine_read_provenance` line 16 and `test_nearby_deadline_text` line 17 (RTEAMS-5).
4. `PlayCircleCoordinator`: a standalone `join(inviteCode:)` that does not need the offers read (MP `_consumeInviteCode` posts the join before any read). Today PLAYC-r7-1 consumes the invite through `open(inviteCode:)`, which only runs once offers (≥ 3) are loaded.
5. Official route node `imgUrl` (official-route #7).

## MP assets needed (for C7 / `cursor/mp-assets`; none are in `App/Assets.xcassets` yet)
Static MP images referenced by these 15 pages. Brand/feature art, not screenshots:
- `subpackageRoam/assets/icons/{history,stamp,goals}.png` (passport tiles, Fluent Emoji 3D, MIT) and `subpackageRoam/assets/photos/event.webp` (官方活动 card, CC0) — ROAM-8.
- `images/roam/intro-ticket-{route,map,team}.svg` (start-tab tickets; the app uses SF Symbols today), `images/cy_logo_mark.png` (roam page + share card).
- `images/cover-route.svg` (play / task-list default cover), `pages/play/assets/pack-foil.png` (free-exploration card pack).
- `subpackageRoam/citystamp/mailbox.png` (citystamp send step), `subpackageRoam/components/cy/share-card/route-art.png` (session share card).
- `images/home-route-city-placeholder.jpg` (nearby default cover).
Once `MPAsset` accessors exist, swap the SF Symbols on the roam tickets and passport tiles in RoamHomeTabsView and the citystamp mailbox in RoamSubpageParityViews.

## Verification (cloud, no compiler)
- Every API used was grepped on the branch first: `CYMapScaffold(detent:map:controls:floating:panel:)`, `PlayRouteMapPresentation(snapshot:)` / `segments` / `mappedStops`, `CYMapRegion.boundingRegion(coordinates:)`, `PlayCircleCoordinator.loadOffers()/open(inviteCode:)`, `PlayCircleLegacyLink.resolve`, `PlayEntryCodeContext(registrationID:openTicketWallet:)` (argument order of `PlayExperienceView` memberwise init checked), `TeamInvitationEntryView(makeCoordinator:onLogin:)`, `AppSession.makeTeamCoordinator()`, `MPReviewedPageScreen(page:query:)`, `cyPageTitle(verbatim:)`, `appLocalized(_:locale:)`, `cyText` on `Text` and `View`.
- `tools/check_typography_lint.py`: PASS (no count increased).
- `tools/check_scaffold.py`: fails identically on the base (52b08c7c7) and this branch (pbxproj not regenerated; integrator step).
- Contract checks (`python3 -m unittest discover -s Tests/ContractChecks`), base 52b08c7c7 vs branch: 196 failures+errors on both, identical sorted lists, **0 new**. The first branch run found 2 new (a pinned `.footnote` line and a `nearby.*` key outside the catalog); both fixed and the two suites re-run green.
- Acceptance workflow: not run from the cloud (no `gh` here); fixture routes are in `docs/port/accept/f-play-roam-a.txt` for the coordinator's run. Routes for the live-session tap and the circle-link query are best-effort and may need the coordinator's adjustment.
- New Swift files: none (no `tools/generate_project.py` change needed).

## Round 2 (2026-11-24)

Brief: `design/handoff-r2:docs/briefs/fix-r3-round2.md` (+ `wave-x10.md`, `owner-decisions-1124.md`).

- **Sync:** merged `origin/ui/combined-r7` 82388e4a5 (Cursor Core K1–K10, W1 wiring, C7 MP assets). Two conflicts: `App/PlayExperienceView.swift` (kept both my `PlayStoryMapGround` and Cursor's W1 `PlayExperienceCastMounts`); `tools/check_typography_lint.py` (took the newer r7 version). Merged again before the final push.
- **Strings:** fragment `docs/port/strings/fix-r3-play-roam-a.json` now 16 keys (en + zh-Hans). The perk header uses `playMerchant.perk.title` in the default table: `test_w2_19_playMerchant` requires every `playStoreDay.*` key used in the view to be in `Resources/PlayStoreDay.xcstrings`, which is not a fragment.

### Fixed in round 2

| id | page | what changed | files |
|---|---|---|---|
| PLAYM-2 | play/merchant | Cursor's `PlayStoreDayNode.perk` is shown as the MP 本店权益 card (gift art `MPAsset.FeatureIcon.gift`, name, `redeemRule`) between the consent and 商家信息 sections. While `redeemBlockedNotice` is set, the `.verify` primary CTA is the disabled server line (MP `.mp-cta__main.is-dead`) instead of 出示核销码. Fixture scenarios `perk` / `perkBlocked`. | PlayStoreDayMerchantView, PlayStoreDayMerchantFixtureHost |
| RPOI-3 | poi-detail | MP `cy_roam_poi_checkin_pending:v1` journal on the check-in action, through Cursor's `RoamPendingCheckInJournal`: `begin` before the POST (fresh attempt needs an empty slot; 重新现场核验 reuses the attempt), `clear` on a receipt, `step` on a rejection (known pre-write message → clear, or keep an earlier unknown; any other failure → `markUncertain`). On each node read a pending record is settled when `completed != needRedeem` (已确认当前已完成 / 待核销), otherwise kept with the MP status line. UI: 打卡结果待确认 + 查询当前状态 (re-reads the node) + 重新现场核验 → 开始现场核验 under the same attempt; storage failure shows the MP 本地存储异常 copy and sends nothing. Store: `RoamPendingCheckInDefaults` (UserDefaults; record = v, ownerId, poiId, attemptId, uncertain — no coordinates, answers, photos or scan text), catalogued in `docs/ops-safety/client-data-catalog.json`. `AppSession.makeRoamPOIActions` passes `ownerID` (session account id) and the store (no line added: ratchet 8171). | RoamPOIActions, RoamItemDetailView, AppSession, client-data-catalog.json |
| RHIST-r7-1 | history | Checked: no App caller of `fetchRoamHistory` remains (Cursor removed it); merged history stays on `RoamPassportHistoryReadRoute`. Nothing to change. | — |
| poi-detail #20 (P2) | poi-detail | `.signIn` check-in error now has 登录: closes the place sheet, then switches to 我的 (`rootTabSwitch(.mine)`), shown only when the root tab switch is available. | RoamPOIActions |

### MP assets applied (mapping.md rows ticked)

| ✓ | MPAsset | where |
|---|---|---|
| ✓ | `FeatureIcon.introTicketRoute` / `introTicketMap` / `introTicketTeam` | roam start-tab tickets NO.01–03 (`RoamHomeIntroCards`); NO.04 官方路线 has no MP ticket art and keeps its symbol |
| ✓ | `FeatureIcon.history` / `stamp` / `goals` | passport tiles 历史 / 印章 / 目标 (`RoamHomeTabsView.tileArt`); 徽章 / 时光胶囊 have no MP image (cy-icon) and keep symbols |
| ✓ | `BannerCover.event` | 官方活动 play card thumbnail (`RoamHomeTabsView.playCard`) |
| ✓ | `MapMarker.pinMerchant` / `pinPark` / `pinStreet` / `pinShop` / `pinLandmark` | roam map place pins, by the MP `categoryKey` (type 2 → merchant; tags roam:park / roam:street / roam:shop; else landmark). New `RoamPinCategory`, optional `SearchMapPin.category` (default nil, so search / nearby / city maps are unchanged), `QuestifyMapPinSymbol.mpArt(_:)` (44 pt hit area kept, selected = scale + checkmark) |
| ✓ | `MapMarker.dotCluster` | roam map cluster anchor (count capsule unchanged) |
| ✓ | `Other.mailbox` | citystamp write step, above 投进信箱 (`RoamCityStampFlowView`) |
| ✓ | `BannerCover.routeArt` | roam session share card and official-route share card (no cover → MP route illustration); `CYShareCardContent.mpRouteArt` (default false, other cards unchanged) |
| ✓ | `BadgeMedal.trophy` | play reward topic medal without a server image (`CYMedalItem.mpDefault = .trophy`) |
| ✓ | `BadgeMedal.glassBadge` | play reward new badges without an image (`.glassBadge`, was SF `seal.fill`) |
| ✓ | `Other.packFoil` | free-exploration card pack body (topic name printed in black, MP x-fix7 P-6); the SF `rectangle.stack.fill` stand-in is gone |
| ✓ | `BannerCover.coverRoute` | station artwork with no photo (`PlayStationArtwork`, MP `cy-cover-fb`) |
| — | `BrandLogo.cyLogoMark` | MP uses it on the roam opening animation (no app host) and the share-card badge (`CYShareCard` brand row is text; left to the share-card owner) |
| — | `BannerCover.nearbyCard` | MP `MOCK_IMG` is a demo-data image; real rows stay empty (MP L05-022 "不拿占位图冒充店面") |
| — | `BannerCover.homeRouteCityPlaceholder` | MP nearby card-strip default; the app has no nearby card strip yet (RNEAR-2, Gemini) |
| — | `MapMarker.roamPushpin`, `dot*` single dots | MP canvas share-image decoration / far-zoom single dots; the native map uses clusters instead of solo dots |
| — | `Other.printerBody` / `printerSlot` | wxss background of the citystamp printer; `RoamStampSlipView` tear/scratch layout not redrawn this round |
| — | `TabIcon.iconRoam*` / `iconTabRoam*` | global tab bar (`CYDomainTabBar`), not a play-roam page |
| — | medal-screen `gl*` / `mic*`, `dTopic*`, `laurel` | medal screen / mock data / journey rank board: not in half a's pages |

System-control glyphs (✕, share, search, chevrons, ⋯) stay SF Symbols.

### Owner decisions (1124) on half a

- #9 two-decimal money: no money is drawn on the 15 pages (the store-day perk is a name and a rule). The journey promo amounts (`PlayerJourneyPromoBinding.yuan`) already print two decimals.
- #8 GPS arrival lock: A2-01 is fixed on r7 (`PlayArrivalService(runtime:location: RuntimeNativeLocationProvider(enabled: true))`); no App change needed here.
- #10 pilot gate for game kits: the P4 mounts are Cursor's (`cursor/r7-wiring`); there is no per-event gate in Core yet → request below.
- #7 cast on fixtures / #12 money TEST-only: nothing here sends cast or money (`makeCastCoordinator` stays `enabled: []`; JLAND-r7-1 claim stays behind `moneyOff`).

### Still left (round 2)

| id | why | owner |
|---|---|---|
| JLAND-r7-1 | Claim flow is money (owner #3/#12: not on). `JourneyLandingClaim` is ready; mount when the owner opens claims. | owner, then F |
| RTEAMS-3 (b), RTEAMS-5 | Unchanged: no per-team applicant count in Core; `test_nearby_mine_read_provenance:16` still pins the duplicate row. (`.font(.footnote)` is legal again under the r7 lint, so only the row removal is blocked.) | Cursor |
| ROAM-8 | MP tile images are in, but the passport still lacks the latest track thumbnail / stamp image fields and the photo-tile layout ruling. | Cursor + owner |
| PLAYPOI-6 (P2) | Unchanged (needs `makeExternalMaps` plumbing into `ChallengePOIView`). | F (next round) |
| official-route #7 | Unchanged: no node `imgUrl`. | Cursor |
| review r7-rev-a/b/c | No Claude-owned row lands in half a's pages (rev-a rows are Cursor's; rev-b Claude rows are P3/P5 topic / registration; rev-c is parked MPGap). | — |

### Core requests for Cursor (round 2)

6. Owner #10: a per-event pilot gate (default off) for the ported P4 game-page kits, read by the P4 mounts on play/index.
7. Owner #9: `PlayerJourneyPromoBinding.yuan` could reuse `MoneyDisplay.yuan` (one shared formatter); it is already two decimals.

### Verification (round 2, cloud, no compiler)

- APIs grepped on the branch before use: `RoamPendingCheckInJournal.{storageKey,read,begin,markUncertain,clear,step,photoKey}`, `RoamPendingCheckInStoring`, `RoamPendingCompleteStep`, `RoamPendingCheckInRecord.attemptID`, `PlayStoreDayNode.perk` / `redeemBlockedNotice`, `PlayStoreDayPerk`, every `MPAsset.*` accessor used (and its imageset: PNG/JPG/PDF only, no WebP), `RoamNodeDetail.{completed,needRedeem,canInteract,isPublished}`, `PlayExperienceSession.accountID`, `CYCoverArt(seed:symbol:showsDebugLabel:showsGlyph:cornerRadius:)`, `RootTabSwitch.isAvailable`, `CYRadius.sm/xl`, `CYSpacing.minTouchTarget/xxs`.
- Contract checks, merge base b52f057dd vs branch: the first run found 5 new failures (UserDefaults store not catalogued ×2, AppSession line ratchet ×2, the pinned `QuestifyMapPinSymbol(symbol: anchor.symbol, selected: anchor.id == selectedID)` string); all fixed and those suites re-run green. Full-suite result is in the commit log of the last push.
- `tools/check_typography_lint.py`: PASS. `tools/audit_client_ops_surfaces.py --check`: PASS.
- Fixture routes added under "Round 2" in `docs/port/accept/f-play-roam-a.txt`.

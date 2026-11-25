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
- Contract checks (`python3 -m unittest discover -s Tests/ContractChecks`), merge base b52f057dd vs branch: 202 failures+errors on both, identical sorted lists, **0 new**. The first run found 5 new failures (UserDefaults store not catalogued ×2, AppSession line ratchet ×2, the pinned `QuestifyMapPinSymbol(symbol: anchor.symbol, selected: anchor.id == selectedID)` string); all fixed and those suites re-run green.
- `tools/check_typography_lint.py`: PASS. `tools/audit_client_ops_surfaces.py --check`: PASS.
- Fixture routes added under "Round 2" in `docs/port/accept/f-play-roam-a.txt`.

## Round 3 (2026-11-24 evening)

Brief: `design/handoff-r2:docs/briefs/fix-r3-round3.md` (+ `wave-x10.md`, `fix-r3-round2.md`, `owner-decisions-1124.md`).

- **Sync:** `git merge origin/ui/combined-r7` (b0ac0108d): fast-forward (my round 2 was already inside it). Merged again before the final push.
- **Strings:** no new keys. The pending card uses the catalog keys `roam.poi.pending.*` (already in `Resources/Localizable.xcstrings`, en + zh-Hans) and `auth.signIn`. Cursor's raw `"查询当前状态"` / `"重新现场核验"` literals are replaced by those keys.

### Round 3 · re-applied

Each hunk of my round-2 commits (50329715e, 3cde18d10, 8966aa096) was checked against b0ac0108d.

| round-2 item | state on b0ac0108d | re-applied on top of Cursor's / restyle's API | files |
|---|---|---|---|
| RPOI-3 pending check-in | Cursor's `RoamPOIActionModel` journal kept (`adopt(ownerID:)`, `armReverify`, `noteReloaded`, `RoamPendingCheckInDefaults`). Lost: storage-error state, settle-on-read by `completed != needRedeem`, recovered line, MP status line, the plain 打卡 row hidden while pending. | Model: `storageFailed` (read/begin throw → MP 本地存储异常, nothing sent), `pendingRecovered` (已确认当前已完成 / 待核销), `pendingNotShown` (MP `pendingStatusText`); `noteReloaded(poiID:completed:needRedeem:)` settles only when completed ≠ needRedeem (call site passes `detail.needRedeem`). View: one `pendingRows` card (title/message/status + 查询当前状态 + 重新现场核验) on catalog keys; the plain 打卡 row is hidden while a record is pending or storage is broken. No second journal and no AppSession change (Cursor's `checkInOwnerID` path is used). | RoamPOIActions, RoamItemDetailView |
| poi-detail #20 登录 CTA | lost | `.signIn` error row: 登录 → `dismiss()` + `rootTabSwitch(.mine)` when available | RoamPOIActions |
| Roam map pins by MP `categoryKey` | restyle replaced `QuestifyMapPinSymbol` with `CYMapMarker` (MP dot/pin set by SF symbol); my `art` image branch was dropped, so `.mpArt` was a no-op | `QuestifyMapPinSymbol.mpKind(_:)` passes `RoamPinCategory.markerKind` into `CYMapMarker(symbol:kind:selected:)` (unselected dot-<category>, selected pin-<category>, clusters `.cluster`). Same MP art as restyle, but the category comes from the place's MP `categoryKey`, not the symbol. | SearchMapCanvas, QuestifyDensityMap |
| Medal MP defaults (trophy / glass badge) | restyle's `CYMedalGlyph` (by symbol) replaced `item.mpDefault`: topic medal showed `medal3d` instead of the MP trophy | `item.mpDefault?.image ?? CYMedalGlyph.image(for:)` | CYMedalStack |
| PLAYM-2 本店权益 | duplicated: Cursor added a second perk card (verbatim 本店权益) and a blocked line that replaced **every** CTA | Removed the duplicate; kept the round-2 card (catalog key, MP gift art) and the `.verify`-only blocked CTA (MP `.mp-cta__main.is-dead`) | PlayStoreDayMerchantView |
| Assets: tickets, passport tiles, event card, mailbox, share route art, pack foil, cover-route | present | — | — |
| Client-data catalog row for the journal | present | — | — |

### Fixed in round 3

| id | what changed | files |
|---|---|---|
| MP-asset bug (mine, round 2) | `glass-badge.png` (and `glass-success.png`) are MP `cy-frames` sprite sheets (6 × 4 frames, 672 × 448). Drawing them whole showed 24 tiny badges. New `CYSpriteStill` crops frame 0; used by the medal face (`MPDefault.glassBadge`, and the restyle's `seal` / `seal.fill` glyph) and the medal-screen stat cells. | CYMedalStack |

### Checked, nothing to change / not mounted (with reasons)

| item | why |
|---|---|
| owner #10 pilot gate | Done on r7 (`PlayKitPilotGate.allows(eventID:)` on `gameStage`); my Core request 6 is closed. |
| flows-g1 `pages/play/index` → mount `PlayToolsAndLeadSheetView` (PLAY-6) | Its lead rows would be a second implementation of the inline 领队 section (which has review/confirm and `performLead`), and its BGM / 旁白 / reduce-motion toggles have no app state to bind (they would be dead controls). Native ⋯ menu + leader section cover scan-arrive, chapters, SOS, group code, settle. Needs: preference state in Core before a sheet makes sense. |
| flows-g1 `pages/roam/index` → `RoamSessionToolsSheetView` (ROAM-9) / `RoamCityStripTabView` (ROAM-13) | ROAM-9: fog / map-style / reduce-motion / presence bindings have no live-session state (presence is a start-time consent in `RoamLiveSessionView`); runners need `PlayRoamGapService` wiring (Cursor). ROAM-13: Gemini's queue in the r7 audit. |
| flows-g1 `subpackageRoam/nearby` → `NearbyTeamsMapSheetView` (RNEAR-2) | The nearby page already has a native map (`NearbyTeamMapSection`); the parked view is a pins-only shell (audit: Gemini queue). |
| flows-g1 history → `RoamMergedHistoryListView` (RHIST-1/2) | Native `RoamHistoryView` already reads `RoamPassportHistoryReadRoute` and has loading / error / denied / empty / unfinished / local-unreadable states; the parked list would duplicate it. |
| mapping.md new rows on half a | `Other.glassSuccess` (play run-end celebration) has no app host (the run-end hero is a whole feature). Template shelf tabs, leaderboard memojis (`GrowthLeaderboardView`) and member-journey icons (`mycanyu`, `PlayerJourneyViews`) are not on half a's 15 pages. `printerBody` / `printerSlot` unchanged (see round 2). |
| review/r7-rev-a/b/c, audit/parity-r7-play-roam | No commits since round 2; every Claude P1 row of half a is fixed or listed below. |
| PLAYPOI-6 (P2) | Closed as native: `ChallengePOIView` opens Apple Maps (the `wx.openLocation` analogue). `PlatformExternalMapHost` without a `makeExternalMaps` host shows "gated", a regression. |

### Still left (round 3)

| id | why | owner |
|---|---|---|
| RTEAMS-1 | Topic page still has no team card (`TopicRouteMapAndTeamsSection` unmounted, player-content's page). | Gemini / player-content |
| RTEAMS-3 (b), RTEAMS-5 | Unchanged: `NearbyTeamOwnedRow` has no pending count; `test_nearby_mine_read_provenance:16` and `test_nearby_deadline_text:17` still pin the row / `.font(.footnote)`. | Cursor |
| ROAM-8 | Passport still lacks latest track thumbnail / stamp image. | Cursor + owner |
| official-route #7 | No node `imgUrl`. | Cursor |
| JLAND-r7-1 | Money (owner #3/#12). | owner |
| ROAM-9, PLAY-6 sheets | See above: need preference / live-session state. | Cursor (state), then F |

### Core requests for Cursor (round 3)

8. Play preferences (BGM, 旁白 autoplay, reduce-motion override) and roam live-session preferences (fog on/off, map style) as app state, so the PLAY-6 / ROAM-9 tools sheets can bind real values.
9. Unchanged from round 1/2: 1 (passport thumbnails), 2 (per-team applicant count), 3 (relax the two tests), 4 (`PlayCircleCoordinator.join(inviteCode:)`), 5 (node `imgUrl`).

### Verification (round 3, cloud, no compiler)

- APIs grepped on b0ac0108d before use: `CYMapMarker(symbol:kind:selected:)`, `CYMapMarkerKind` cases, `RoamPendingCheckInJournal.{read,begin,clear,markUncertain}` (all `throws`), `RoamNodeDetail.needRedeem`, `RootTabSwitch.isAvailable` / `callAsFunction(.mine)` (as in ClubGovernanceViews), `CYSpacing.xxs`, `MPAsset.BadgeMedal.{trophy,glassBadge}`, `CYMedalItem.mpDefault`. `CYSpriteStill` name grepped: unused in App/ and Core/.
- Contract checks (`python3 -m unittest discover -s Tests/ContractChecks`), base b0ac0108d vs branch: 112 failures + 105 errors on both, identical sorted lists, **0 new**.
- `tools/check_typography_lint.py`: PASS.
- Fixture routes: "Round 3" block in `docs/port/accept/f-play-roam-a.txt`.

## Round 4 (2026-11-25)

Brief: `design/handoff-r2:docs/briefs/fix-r3-round4.md` (+ `wave-x10.md`, `owner-decisions-1124.md`). Gemini is out of quota, so this round also covers Gemini's MP-alignment work (flows, images, copy) for half a's 15 pages.

- **Sync:** checked out `origin/fix/r3-play-roam-a`, merged `origin/ui/combined-r7` 4ef0a2840 (clean). Merged again before the final push.
- **MP source:** `hengyin/chengyinhub-xcx` 3a131849.
- **Strings:** fragment `docs/port/strings/fix-r3-play-roam-a.json` now 64 keys (en + zh-Hans). It includes **15 rows from Gemini's `docs/mp-gap/copy-diff-g1.md` that never reached the catalog** (every one checked against the MP file:line; `Resources/Localizable.xcstrings` still had the old value). The store-day page uses its own table, so its MP copy is in `tools/build_play_store_day_catalog.py` and the regenerated `Resources/PlayStoreDay.xcstrings` (a fragment cannot reach that table; `test_w2_19_playMerchant` passes).
- **Method for copy:** a script compared every catalog key and literal used by the 15 pages' App files with the MP text of the page, its `usingComponents` (recursive) and its `require`d utils. 293 strings were not verbatim; each was paired with its closest MP line, and the 40 that are the same message worded differently were changed. The rest are app-only states (gates, permissions, native share / photo-save, TEST-only writes) with no MP counterpart and stay as they are.

### 1. Flows (flows-g1 / flows-g2 edges for half a)

| MP edge | app now | change |
|---|---|---|
| roam passport → `official-routes` (MP `_loadOfficialRoutes`: a passport play card after 官方活动, only when ≥ 1 route, `N 条路线`) | was a 4th intro ticket NO.04 | **moved** to the 漫游护照 tab as the MP card (`RoamHomePassportView.officialRoutesCard`); intro is NO.01–03 as in the MP |
| roam → nearby / my-teams, login (`switchTab member`) on the reviewed `pages/roam` host | nearby / my-teams pushes had no 登录; `onOpenAccount: {}` | **wired** `openSignIn` (r7 residual P2) |
| poi-challenge `onLoad(q.photo)` (nearby spot camera → challenge with the upload) | no prefill | **added** `ChallengePOIHostView(photoURL:)` + deep-link `photo=` (https only, open photo step only) |
| poi-challenge medal → `citystamp?kind=sign` / `badge-wall?badgeCode=` (`redirectTo`) | push | kept as push (native stack; back returns to the medal) |
| poi-challenge exit → back, fallback `nearby` | dismiss | OK |
| circle no topicId → 返回首页 (`reLaunch index`) | 返回首页 | copy/glyph aligned (below) |
| history guest → `cy-access-gate kind="login"` | local list shown to guests on the deep link | **added** 登录后查看 + 登录 on the deep-link host |
| landing 先逛逛 → `switchTab index` | hidden without a root tab switch | **falls back** to closing the page (JLAND-10) |
| citynode-code / history / session / citystamp / official-route(s) back → `navigateBack`, fallback `switchTab roam` | system back | OK |
| nearby → my-teams / team detail / activity / topic / citystamp / poi-challenge | present (place sheet hosts the challenge + citystamp) | OK |
| landing → play / activity / topic; my-teams → team detail; official-routes → official-route | present | OK |
| flows-g1 GAP-CLAUDE mounts: `RoamSessionToolsSheetView`, `RoamCityStripTabView`, `PlayToolsAndLeadSheetView`, `NearbyTeamsMapAndSheetView`, `RoamHistoryGapView` | not mounted | **unchanged, same reasons as round 3.** Re-checked: `Core/PlayPreferenceRuntime.swift` is the route-preference questionnaire, not BGM / 旁白 / reduce-motion / fog / map-style state, so the two tools sheets would still bind dead toggles. City strip needs `fetchCityStrip` wiring (Cursor). Nearby map sheet and merged history would duplicate the native pages. |

### 2. Image parity (MP image slots → app)

| page | MP slot (src / background / component) | app | state |
|---|---|---|---|
| roam | `images/roam/intro-ticket-{route,map,team}.svg` | `FeatureIcon.introTicket*` | ✓ (r2) |
| roam | `subpackageRoam/assets/icons/{history,stamp,goals}.png` (`cy-roam-photo`) | `FeatureIcon.history/stamp/goals` | ✓ (r2) |
| roam | `assets/photos/event` (官方活动 card) | `BannerCover.event` | ✓ (r2) |
| roam | 官方路线 card: first route `previewImg`, else `photo: 'goals'` | `E1CoverArt(imageURL:fallbackImage: FeatureIcon.goals)` | ✓ **r4** |
| roam | `entryActivity.cover \|\| /images/route_city_cover.png` | `RoamEntryCover` fallback `BannerCover.routeCityCover` (was SF `photo`) | ✓ **r4** |
| roam | `.entry-card__cover`: `item.cover \|\| /images/home-route-city-placeholder.jpg` | `RoamEntryCardView` `.fallbackArtwork(BannerCover.homeRouteCityPlaceholder)` | ✓ **r4** |
| roam | map pins `pin-*` / `dot-*` / cluster | `MapMarker.*` via `CYMapMarker` | ✓ (r2/r3) |
| roam | `avatar \|\| /images/d_profile.png` (tab-root avatar → 我的) | none: the native tab bar's 我的 tab is the entry | native structure |
| roam | `/images/cy_logo_mark.png` (opening animation) | no app host | — |
| play/index | `pages/play/assets/pack-foil.png` | `Other.packFoil` | ✓ (r2) |
| play/index | `medal.img \|\| /images/play/trophy.png`; glass-badge frames | `BadgeMedal.trophy`, `glassBadge` (one sprite frame) | ✓ (r2/r3) |
| play/index | station without photo → `cover-route` | `BannerCover.coverRoute` | ✓ (r2) |
| play/merchant | `heroImg` only when present (no default) | stand-in `mappin.circle` glyph removed | ✓ **r4** |
| play/merchant | 本店权益 gift | `FeatureIcon.gift` | ✓ (r2) |
| play/circle | `cy-empty kind="missing-param"` → `info` glyph | `info.circle` (was `exclamationmark.triangle`) | ✓ **r4** (cy-icon glyph → SF) |
| poi-challenge | `cy-medal-screen` `item.img` (place cover) else `mic_key.svg` | `CYImageCard(...).fallbackArtwork(BadgeMedal.micKey)` | ✓ **r4** |
| citynode-code | `cy-qr-voucher` centre `/images/cy_logo_mark.png` (`brightness(0)`, white circle 96/440, mark 56/440) | `VerificationQRCentreLogo` (template black mark), QR level H | ✓ **r4** (all `VerificationLocalQRCode` surfaces: the MP voucher draws it on every code) |
| citynode-code | error `/images/no_data.svg` | app error is text + 重试 (no art) | left: the shared voucher error layout is a text state in the app |
| history | `cy-empty kind="empty"` → `empty_state_bg.svg` + `empty_state_figure.svg` | `CYEmptyState(systemImage: "tray")` → `CYEmptyIllustration(.generic)` | ✓ **r4** |
| session | `share-card/route-art.png` | `BannerCover.routeArt` | ✓ (r2) |
| session | `share.mapImage` / `share.imagePath` (canvas) | native share card render | runtime image |
| poi-detail | gallery / featured / merchant logo / cover: remote only, no MP default | remote only | OK |
| nearby | `.mt-card__cover`: `item.img`, else `/images/home-route-city-placeholder.jpg` | `NearbyMapDiscoveryRow`: place + event rows always show a cover, default `homeRouteCityPlaceholder` | ✓ **r4** |
| nearby / my-teams | `avatarsOf` → `FACE = /images/d_profile.png` | `NearbyTeamFaces` → `AvatarDefault.dProfile` (was SF `person.crop.circle.fill`) | ✓ **r4** |
| citystamp | `mailbox.png` | `Other.mailbox` | ✓ (r2) |
| citystamp | `.sgprinter` `printer-body.jpg` + `.sgprinter__slot` `printer-slot.jpg` | `RoamStampPrinterView` (MP rpx sizes, stub after tear) | ✓ **r4** |
| official-routes / route | `item.cover` / `route.cover` only when present (no default) | cover only when `previewImage` is set (was generated art always) | ✓ **r4** |
| official-route | `cy-empty kind="empty"` | `CYStateLayout(emptyIllustration: .generic)` | ✓ **r4** |
| official-route | node `item.img` | — | left: no node `imgUrl` in Core (Cursor request 5) |
| landing | `inviter.avatar` else initial else `cy-icon tab-club`; tiles `cy-icon` | remote / initial / SF | cy-icon glyphs are CSS masks, not MP image files; SF stays |

System-control glyphs (✕, back, share, ⋯, search, chevrons) and `cy-icon` line glyphs stay SF Symbols.

### 3. Copy (zh-Hans = MP)

| page | keys → MP text |
|---|---|
| poi-challenge | `playx.poi.submit` 提交 · `answerPlaceholder` 在这里作答 · `photoShoot` 拍一张 · `completed` 地点勋章 (medal name fallback) · new `claimedAgain` 再完成一次不会重复发放. Removed: visible 正在加载地标挑战… (skeleton only), 第一步：现场拍照打卡 header, the extra 选择答案 sheet button |
| citynode-code | `roamSub.w208.voucher.defaultName` 节点 · new `renderFailed` 核销码二维码没能生成，请重试 · authority line hidden in the citynode scene |
| official-routes / route | 线路 throughout: `officialRoute.title` 官方线路, `detail.title` 线路详情, `list.error` / `detail.error` 线路加载失败 (no second line), `list.empty` 还没有上架的官方线路, `detail.notFound` 这条线路不存在或已下架, `detail.noNodes` 这条线路还没有节点, `list.open` 查看线路 %@, `share` 分享线路. The roam card stays 官方路线 (MP roam/index.js:799) + new `roam.passport.play.routes.count` %lld 条路线 |
| play/merchant (PlayStoreDay table) | `cta.confirmPending` 结果待确认 · 点这里确认 · `notice.arriveFirst` 先点「我已到店」，再开始任务 · `notice.noCoordinates` 这家还没填位置，暂时不能导航 · `crowd.unknown` — · steps 1/3 no sub line, step 2 sub = photoDesc once arrived (3 keys removed) |
| play/circle | missing state: no sub line (title 探索链接不完整, 返回首页) |
| history / session | `roam.historyLocal.finishPending` 上次漫游需要确认 · `roam.experience.noTrack` 这次没有记录到轨迹 · `roam.share.prepare` 生成足迹卡 · `roam.share.photoPermissionDenied` 在设置里允许保存到相册，返回后点“重试保存”。 · `roamSub.w208.shared.errorTitle` 这条足迹无法打开 (no sub) · history empty without the hint line |
| poi-detail | `roamSub.w208.poi.offline` / `offlineVoucher` 节点已下线，保留历史记录(，已打卡待核销的券仍可出码领取) · `poi.missing` 找不到这个节点 · `poi.unavailable` 节点未开放或已下线 (both without sub) · `roam.poi.location.unavailable` 暂时无法获取位置，请稍后重试。 |
| roam live | `roam.live.consentCard.body` …结束漫游即停止。 · `roam.live.locationQuality` 定位精度不足，请到开阔处等待定位稳定后重试。 · `roam.live.finishing` 正在结算 |
| play/index | `playHelp.skipped` 跳过 · 记 0 分 · 辅助完成 · `playx.node.untitled` 未命名地点 · `playx.answer.placeholder` 把你找到的字填在这里 (MP play/index.wxml:1228, vm 1 text answer) |
| citystamp | 你是第几位 removed (MP slip: 签号 + number) |
| Gemini copy-diff-g1 rows carried (15) | `playx.merchant.stat.wait`, `u10.roamFinish.medals`, `playx.circle.notice`, `playx.circle.loading`, `roamTools.clearCache.confirmTitle`, `templateVenue.park`, `nearby.error.apply.{ALREADY_JOINED,APPLY_BLOCKED,APPLY_PENDING}`, `nearby.error.handle.APPLY_BLOCKED`, `nearby.rejected.foot`, `roam.historyLocal.unfinishedHint`, `playkit.photo.fallbackRecorded`, `roam.live.finishing`, `nearby.actionFailed`. The other 6 rows of that file belong to other areas (baoming, report-detail, orient-score, playkit reaction, order lifecycle). |

Kept on purpose: `playCompat.refused.next` says "更新 App" where the MP says "更新小程序"; native permission / photo-save / share-sheet lines; gated-write notices.

### 4. P2 / P1 rows (audit/parity-r7-play-roam, Claude)

| row | change |
|---|---|
| poi-challenge #14 (P2) `photo=` prefill | done (flows table) |
| nearby residual P2 (reviewed roam host, no sign-in) | done |
| history #1 login gate | done on the deep-link host. Left: the 漫游护照 tile push (MP `ensureLoginFor` on every tile) — `RoamHomePassportView` has no session/sign-in input; needs the host to pass one |
| landing JLAND-10 (P2) 先逛逛 hidden | done (dismiss fallback) |
| landing row 21 (account switch re-read) | already present: re-read when the sign-in sheet closes (`PlayerJourneySignInBridge`) |
| official-routes / route #7 thumbnail | Cursor (node `imgUrl`) |
| poi-detail #19 share, #7 inline gallery, #16 parked pending | share domain is an owner decision (RPOI-4/5); #16 is done natively (r2/r3 pending card); #7 parked view |
| my-teams #10, RTEAMS-5 | unchanged (Cursor) |
| citystamp #4–#11 | gated writes (`mediaUpload` / `stampExchange`, owner) |

### 5. Accessibility

- `python3 -B tools/check_a11y_lint.py`: the only finding is `App/ClubKit/ClubWorkbenchKit.swift:261` (club area, present on the base 4ef0a2840); club-a already fixed it on `fix/r3-club-a` 9ba27a456. Nothing from this branch.
- New decoration is VoiceOver-hidden (QR centre logo, printer, covers, faces); `.accessibilityHidden(true)` sits after Image-only modifiers.

### Core / other requests (round 4)

10. Core still has no live-session preferences (BGM, 旁白 autoplay, reduce-motion override, fog, map style): request 8 stands; until then the PLAY-6 / ROAM-9 sheets stay unmounted.
11. `OfficialRouteFormat.distance` prints `km` in Chinese; the app maps it to `公里` locally (`OfficialRouteMeta`). A locale-aware Core formatter would remove that.
12. Integrator: `docs/port/strings/gap-g1-copy.json` (Gemini) was never merged into `Resources/Localizable.xcstrings`; my fragment carries the 15 play-roam rows, the other 6 belong to other areas.

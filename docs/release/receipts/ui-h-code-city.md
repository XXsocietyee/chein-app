# Receipt · ui/h-code-city · City Monopoly client and the map-first 漫游 tab

Worker A (Opus 5.5), Orca task `task_659366471010`. Branch from `origin/ui/main` f14040431 (unchanged at the time of
the last fetch, so no rebase). Pushed to `origin/ui/h-code-city`; `ui/main` was not touched.

Sources: Figma `0YyoybGnU1KG0657wdGCPX` page `00 Hand-off · 交付清单` (the frame list also lives in
`revise/skill-r2/js/_handoff.json`), `review/skill-r2.md` §3–§4 and "What works", `revise/skill-r2/LOG.md` and shots,
`review/verify-r1.md` batch 3, `tasks/E/city-monopoly-spec.md` (the v2 numbers; the brief's path
`redesign-backup-1116/city-monopoly-spec.md` does not exist). **Figma calls: 10 of 25** (1 `create_session`,
9 `get_screenshot` of hand-off frames). No `get_design_context` call was made.

Owner defaults applied: Q1 (mine = white; blue only for district 1), Q2 (flick or tap, no shake), Q3 (420 pt detent,
full deed on expand), Q5 (MapKit), Q6 (three notifications, widgets later), Q7 (2D d20), Q9 (漫游 root = map),
Q10 (no serial: the server issues none), Q11 (district hue only on band, cells, chip). 积分 is the only currency.

## What was built

- **Core** (`Core/CityBoardStore.swift`, new): one store that joins the two live reads (`/api/roam/territory/nearby`
  spaces + `/api/city-game/territory/map` layer), the 积分 HUD, season and rent into `CityPlace`s (open / mine / other /
  fogged, geohash-7 fog silhouettes, district colour slots 1–6), quote → confirm for claim / upgrade / challenge,
  shield, scout, loss detection, and one-sentence copy for every server reason. 8 new Core tests
  (`Tests/CoreTests/CityBoardStoreTests.swift`).
- **Client contract fixes against the live backend** (`integration/backend-app-r3`, deployed on TEST 8120). The
  existing City client could not have worked against it:
  | Route | App sent | Server reads | Fix |
  |---|---|---|---|
  | `GET territory/map` | `regionId`, `bbox`, `zoom` | `minLat`, `minLng`, `maxLat`, `maxLng` (≤ 0.5°) | new `territoryMapBounds` route + `CityMapBounds` |
  | `POST territory/claim/quote` | `propertyId` | `poiId` or `boardId` + `pointId` | quote body carries the target keys |
  | `POST upgrade|challenge/quote`, `scout`, `shield` | `propertyId` | `territoryId` | `territoryId` sent |
  | challenge result `mods` | array | map `{task, insight, warmup, assist}` | decoder accepts both |
  | `GET roam/territory/nearby` | decoded `items` | `territories` | decoder accepts both |
  | property card | `deedPhotoUrl`, `weeklyVisits` | `deedPhoto`, `visitsThisWeek` (+ `lat`, `lng`) | both names |
  | season | `dayIndex` | `day` | both |
  | — | — | `GET territory/points` (balance, pending, holdings, limit) | new route, added to the CITY lease |
- **City kit** (`App/CityKit/`, new folder): `CityDeedCard` (full / sheet / row / mini, real level, rent, holder,
  photo, district band, status badge), `CityLevelPips`, `CityOddsBar`, `CityD20Art` + throwable / tumbling die,
  `CityPin`, `CityMapLayer` (MapKit muted dark, cells as `MapPolygon`, fog as one `MKPolygon` with lit cells cut out,
  2.5 pt / dashed outlines under Increase Contrast or Differentiate Without Color), `CityMapLegend`,
  `CityHoldButton` (0.8 s, ring trim, VoiceOver / Reduce Motion activate at once), `CityMomentView` (beats at
  350 / 600 / 950 / 1 250 ms, tap to skip, Reduce Motion fade, announcement), seal, chips, banners, fact tables.
- **Screens**: 漫游 root (map, 迷雾 / 领地, stat line → board, 附近 drawer with hold-to-start, the shipped roam page
  one tap away as 漫游护照与工具 (app/test-roam-passport-sheet.png)), property sheets (420 pt detent, background interaction, primary pinned), claim
  (four live checks, in-app camera only, quote, reasons), challenge (odds bar when the quote carries DC, presence
  checks), dice moments, 圈下了, 被抢, 守住了, upgrade, shield, board home, 我的地盘, 收租明细 (+ notifications-off
  banner), the 首页 rail, and `CityNotifications` (protection-ending with 开护盾 / 稍后 actions, a 20:00 rent
  summary, place lost).
- DEBUG fixtures `App/DesignFixtures/CityKitFixtures.swift` (`--design-fixture city-*`, `-ax3` suffix for AX3).

## Hand-off frames

Shots: `/Users/fanning/chengyin-refs/code-final-shots/city/` (`index.md` maps every frame; `app/test-*` = shipped view
on TEST as player 9009 at the Guangzhou acceptance board; `app/fixture-*` = DEBUG fixture, labelled).

| Frame | View | Status | Screenshot |
|---|---|---|---|
| 210:8322 RoamRootView | `CityRoamRootView` | done | app/test-roam-root.png, app/test-roam-fog.png |
| 210:8239 HomeView rail | `CityHomeRail` in `HomeFeedView` | done | app/test-home-rail.png, app/fixture-city-home-rail.png |
| 204:21814 N01 | `CityBoardView` | partial: no 街区 progress rows, no 赛季榜 / 战队频道 / 收藏据点 rows (district read missing) | app/test-board.png |
| 204:21842 N02 loading | `CityBoardView` skeleton 220/60/52/52/72×3 | done (transient, not captured) | — |
| 204:21889 N03 empty | `CityBoardView` empty | done | app/fixture-city-board-empty.png |
| 204:23260 N07 | `CityMapLayer` | done | app/test-roam-root.png, app/test-roam-fog.png |
| 204:23400 N08 | `CityPropertySheet` open | done | app/test-property-open.png |
| 204:23542 N09 | protected | done | app/test-property-other.png |
| 204:23691 N10 | challengeable | done | app/fixture-city-property-challenge.png |
| 204:23832 N11 | mine | done | app/test-property-mine.png |
| 204:23956 N12 | unlit | done | app/fixture-city-property-unlit.png |
| 204:26708 N18 | `CityClaimSheet` | done | app/test-claim-sheet.png |
| 204:26816 N20 | camera | partial: system camera (`UIImagePickerController`, live only), no custom viewfinder | — |
| 204:26924 N21 | verify | partial: inline in the claim sheet (校验中), not a separate screen | — |
| 204:27073 / 204:27181 N23 / N24 | claim rejected | done (server reasons → sentences) | app/fixture-city-claim-rejected.png |
| 204:27271 N25 | not enough 积分 | done | app/fixture-city-claim-short.png |
| 204:26968 N22 | `CityClaimedMoment` | done | app/fixture-city-moment-claimed.png |
| 204:33843 N28 | `CityRentLedgerView` | done | app/test-ledger.png, app/fixture-city-ledger.png |
| 204:34178 N33 | ledger · notifications off | done (banner when denied; not captured) | — |
| 204:34263 N34 | `CityChallengeSheet` | done | app/fixture-city-challenge.png |
| 204:34304 N35 | OnSiteTaskView | **left**: the server has no task verifier (quote `task` is null) | — |
| 204:34340 N36 | ready | done | app/fixture-city-dice-ready.png |
| 204:34369 N37 | rolling | done (transient ≥ 1.2 s, not captured) | — |
| 204:34407 N38 | won | done | app/fixture-city-dice-won.png |
| 204:34440 N39 | lost roll | done | app/fixture-city-dice-lost.png |
| 204:34476 N40 | place lost | done (on a reload that finds the place gone) | app/fixture-city-place-lost.png |
| 204:34510 N41 | defended | partial: view built; no trigger without a defender push | app/fixture-city-defended.png |
| 205:8376 N46 | `CityMyPropertiesView` | done | app/test-mine.png |
| 205:8475 N47 | `CityShieldSheet` | done | app/fixture-city-shield.png |
| 205:8580 N48 | `CityUpgradeSheet` | done | app/fixture-city-upgrade.png |
| 205:8686 N49 | weathering sheet | left (weathering shows as a banner on N11 / N46) | — |
| 205:8786 N50 | upgrade-away sheet | left | — |
| 205:8866 N51 | released sheet | left (no release event read) | — |
| 207:2026 N64, 207:2106 N65, 207:2181 N66, 207:2683 N73 | attributes / titles | left: the existing `MemberAttributesSection` is unchanged | — |
| 431:6562 系统触点 | `CityNotifications` | partial: three local notifications; widgets are a later release | — |

## Missing endpoints / backend findings (not faked in the UI)

1. **District names** (and per-district progress): no read for `city_district`; the band says 街区 1…6 by slot.
2. **On-site challenge task**: `CityTaskVerifier` has no implementation and no submission route; N35 not built.
3. **Server push** for 被抢 (defender), 守住了 and a live 20:00 rent total: the app posts local notifications from
   what it read; nothing reaches a closed app except the protection-ending reminder.
4. **Deed serial** (`地契 · No. N`): not issued; dropped per Q10.
5. **Tier on open spaces**: `nearby` sends no tier, so an open place's price shows after the quote.
6. Backend bug: `claim/quote` with `boardId` + `pointId` for a point without `place_id` → HTTP 500 (NPE unboxing
   `poiId` in `CityMonopolyService.resolveTarget`, line 345). Points with a place work.
7. Real claims and challenges need App Attest, a pHash and account Lv3 (`APP_ATTEST_REQUIRED`, `PHOTO_HASH_MISSING`,
   `ACCOUNT_LEVEL_TOO_LOW` from TEST for 9001), so the simulator cannot reach the success moments on TEST; those
   shots are fixtures. Photo upload on TEST also has no OSS.
8. `nearby` returns the title and owner of a place whose map tile is fogged for the viewer (the map layer hides them).

## Shared changes (minimal, outside App/CityKit)

`App/QuestifyApp.swift` (roam tab = `SessionCityRoamRoot`; the RoamBrowserView construction moved to
`roamBrowser`, unchanged), `App/HomeFeedView.swift` (optional `cityRail`), `App/SessionHomeFeedView.swift` (passes the
rail), `App/DesignSystem/CYCityPalette.swift` (new: the City kit's literal colours, since raw `Color(...)` is only
allowed in DesignSystem), `App/DesignFixtures/DesignFixtureRegistry.swift` (one `city-*` case),
`tools/generate_project.py` (glob `App/CityKit/*.swift`), `Core/CityMonopolyContracts.swift`,
`Core/CityMonopolyService.swift`, `Core/CityGameHTTPService.swift` (lease path), `Core/RoamTerritoryContracts.swift`.

## Gates

| Gate | Result |
|---|---|
| `tools/check_scaffold.py` | PASS |
| `tools/contract_ratchet.py --check` | 185 failing vs baseline 184: the one new name, `test_workshop_paid_professional…bounded_paging`, already fails on clean `origin/ui/main` f14040431 (checked before any change). Our own new failure (raw `Color(...)` in App/CityKit) was fixed by moving the colours into `CYCityPalette`. |
| design lint | PASS (0 violations) |
| strings (`check_missing_string_keys`) | missing: 0 |
| a11y lint | PASS |
| Core `swift test --disable-sandbox` | 16982 tests (+8 new `CityBoardStoreTests`, all pass); **27 unique failures = baseline 27** (none in City Monopoly or roam code) |
| AppUnit, 4 shards (`test_sim`, shard xctestruns from the plans) | 6 / 15 / 30 / 24 failing. All 75 failing identifiers re-run together on this branch at low load: 70 fail. The same 75 on a clean f14040431 build (same worktree checked out detached, build-for-testing, same `OnlyTestIdentifiers`): **the same 70 fail, 0 branch-only**. No new AppUnit failures. |
| Builds | Questify Debug simulator build green; build-for-testing green |

Known rough edge: at the 附近 drawer's peek detent the `附近 · n` heading sits partly in the system tab bar's scroll-edge fade.

Accessibility pass: VoiceOver labels / traits on pins, drawer grabber, hold button, die (with a plain activation),
check rows (spoken states), deeds (one combined element); band ink 5.6–10.5:1 on the six district colours, secondary
ink on the neutral band; kit text uses text styles (Dynamic Type); rows stack and the moment stage hugs at
accessibility sizes (AX3 fixtures). Reduce Motion: every beat becomes a 200 ms fade; Reduce Transparency: opaque
chrome.

DerivedData `city-ag6` deleted at the end.

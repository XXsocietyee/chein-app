# Receipt · ui/r4-city · City Monopoly client + the 漫游 root (screens r4)

Branch `ui/r4-city`, cut from `origin/ui/h-code-r3-ops`. Brief: `origin/design/handoff-r2:docs/briefs/screens-r4.md`.
Backend source of the new fields: `hengyin` `origin/integration/backend-app-r3:qa/CITY-GAPS-R3.md` (fix/city-gaps-r3, live on TEST).
Swift is not installed in the cloud: nothing here was compiled. Every type, initializer and modifier was checked against the
existing code. The integrator builds, runs the tests and takes the shots in the checklist below.

Status words: **done** (code in place; shot pending the local run), **flagged** (behind a flag, waiting for owner approval),
**partial** (what is left is named), **left**.

## 1 · New backend fields (fix/city-gaps-r3)

| Item | Status | Notes |
|---|---|---|
| `districts[]` on map + nearby, `districtName` / `districtColorToken` on items and the property read | **done** | `CityDistrictInfo` (Core) decodes `{boardId, districtId, name, colorToken, colorIndex, ownableCount, safetyBlocked}`. `CityTerritoryMapResponse.districts`, `RoamTerritoryNearbyResponse.districts` (both default `[]`, tolerant decode). `CityBoardStore.load` keeps both lists; `merge(…, districts:)` resolves the name in this order: the layer item's `districtName`, the nearby item's, then `districts[]` by `boardId + districtId` (then `districtId` alone). |
| Real district name instead of 街区 N | **done** | `CityCopy.district` shows `CityPlace.districtName` when present, fogged tiles included (the backend sends names for fogged items, as public board metadata). **Placeholder seed:** the migration seeds `name = districtId` until real names go in, so `CityDistrictBook.usable` treats a name equal to the id (or blank) as no name, and the band keeps 街区 N. Without that, the TEST board would show "d3". |
| District colour key | **done** | `CityDistrictInfo.slot(index:token:)`: `colorIndex`, else the N of `district.cN`, wrapped into 1…6; any other token → nil → the client keeps its own stable slot (`CityDistrictSlots`, the same sorted order the migration uses). Order: the item's own token, then `districts[]`, then the client slot. The property drawer also takes the card's `districtColorToken`. |
| `deedSerial` → 地契 · No. N | **done** | On `CityTerritoryProperty` (map items, the command `property`), `CityTerritoryPropertyCard`, and `RoamTerritoryItem` (nearby). Merge: layer serial, else the nearby serial; **never on fogged items**. C1's band hook (`CityDeedCard.band`) shows `地契 · No. N` in place of the tier only when a serial exists. The claim moment and the challenge-won moment take `result.property.deedSerial` (`CityPlace.withDeedSerial`) when the reload has not caught up, so a first claim shows its new number at once. Takeover keeps the serial (server rule), and `handedOver` keeps it too. |
| cityTerritory DEFENDED inbox card → property sheet | **done** (render hook: see below) | `CityTerritoryNotice` (Core) parses the IM system card: visible, `msgType 3`, sender 0, `extra.cardType == "cityTerritory"`, a known `kind` (`DEFENDED`, `PLACE_LOST`, `RENT`, `RENT_SETTLED`), a title, `currency` POINTS or absent. `points` is a whole number ≥ 0 (booleans rejected); nil hides the line, and 0 hides it too (a failed on-site task pays no compensation; nothing shows a fake 0). `CityTerritoryNoticeCard` (CityKit) draws it in the message list's system-notice style (`MessagingBubble.noticeCard`: 36 pt icon disc, `cardTitle` headline, time, one body sentence, `bgElevated` 60 % on `CYRadius.md`) with a chevron when it links. Tap → `CityDeepLinks.shared.openProperty(territoryId)` + `rootTabSwitch(.roam)`; the 漫游 root pops its pushes, closes any sheet or moment, and opens the property drawer over the map (`CityBoardStore.locate` reads the property for its coordinate and reloads the board around it when the place is outside the loaded window). |

**Render hook for the owner / integrator (IM views are out of scope for this branch).** The brief forbids editing the IM
views, so the card is not yet inserted into the system conversation. The one-line hook, in
`MessagingHistoryView.MessagingBubble.body` (or its `noticeCard`):

```swift
if let notice = CityTerritoryNotice.parse(message: message, conversation: conversation) {
    CityTerritoryNoticeCard(notice: notice, stamp: ChatDisplay.stamp(message.createdAt))
} else if (conversation?.kind == .system || message.senderID == 0) && !isOwn { noticeCard } else { bubbleRow }
```

Until it lands, older-client behaviour holds: the server's `content` sentence shows as a plain system notice (the backend
made it a full sentence for exactly this case).

## 2 · Hold to start → live session over the SAME map (continuity pass 5)

**Status: flagged (needs owner approval).** `CityLiveOnMap.isEnabled` is **off** by default; on with the launch
argument `--city-live-on-map` or the defaults key `cityLiveOnMapV1`. Flag off = today's push to `RoamLiveSessionView`,
unchanged.

Why a flag: the structure does not allow moving only the presentation cleanly.
- `RoamLiveSessionController` has a **single** `onChange` observer, owned by the live page's private view model.
- The live page **pauses the walk in `onDisappear`**, and it owns the 3 s pulse loop, the consent card, location priming,
  the presence toggle, recovery, paused browsing and the finish report.

A real split (controls out of `RoamLiveSessionView`, a multi-observer controller) would rewrite the live page, which is
outside this area. So the flagged path keeps the session logic and changes only where the walk is shown:
- `CityLiveMapSession` chains onto the controller's observer instead of replacing it, and re-attaches when the root
  reappears.
- `CityLiveMapControls` drives the **same retained controller** (`session.makeRoamLiveSessionController()`) through its
  public calls only (`prepare`, `start`, `pulse` every 3 s while active and foreground or background-held, `pause`,
  `resume`, `finish`, `setForeground`), with the live page's offline write opt-in routes and its finish modal
  (`PlayAreaRoamFinishModal`).
- In place only when the live page has nothing to ask first: the stored consent `roamLivePurposeAcceptedV1` is true,
  location is not `.notDetermined`, and after `prepare()` the phase is `.ready` (no record), `.paused` (resumable) or
  running. Otherwise the hold pushes the live page as today.
- Presentation: the hold capsule and the pause pill share one matched geometry id (`city.live.capsule`), so the capsule
  becomes the pill on `CYMotion.hero`; the stats pill (用时 · 地盘 · 公里, "—" when unknown) grows up from it 120 ms later
  on `entrance` (scale from the bottom anchor, +24 pt, fade); the 附近 drawer slides away on `sheet` (the same move as
  for the property drawer) and its slot keeps its height; the tab bar hides as on the live page; the map and the camera
  do not move. Pause / resume swap in place with a medium impact on pause.
- Ending reverses it: the controls fold back into the capsule and the drawer returns. The live page then opens only
  when it has something to show: the finish report after `finished`, recovery, a denied location, or unavailable. A start
  refused while still `.ready` just folds back.
- Reduce Motion: no matched move. 200 ms cross-fades, and the stats pill fades.

Owner decisions needed: (a) approve the in-place overlay; (b) whether the finish report should also become in place
(today it is the live page's full report, opened after the fold-back); (c) for a full split, approve a multi-observer
`RoamLiveSessionController.onChange` and moving the controls out of `RoamLiveSessionView` (roam owner).

## 3 · City B.1 items C1 marked partial

None. In `docs/release/receipts/ui-h-code-r3-player.md` §2, every B.1 row is **done**. The only non-done City rows were
"District names and deed serial" (**hook**, finished in §1 here) and "Hold to start → live controls" (**left**,
flagged in §2 here).

## Production gating

Unchanged. City stays unavailable on production: no change to `CityGameProductionLease`, `ChinaReviewedRouteCapability`
or the reviewed-route gate. No new route is called. The deep link and the notice card do nothing when the store is
`.unavailable` (no service).

## Files

| File | Change |
|---|---|
| `Core/CityMonopolyContracts.swift` | **shared contract, additive only**: `CityDistrictInfo`; `districtColorToken` on `CityTerritoryProperty`; `districts` on `CityTerritoryMapResponse`; `districtName` / `districtColorToken` / `deedSerial` on `CityTerritoryPropertyCard` |
| `Core/RoamTerritoryContracts.swift` | **shared contract, additive only**: `districtName` / `districtColorToken` / `deedSerial` on `RoamTerritoryItem`; `districts` on `RoamTerritoryNearbyResponse` (the memberwise init gained a defaulted `districts:` argument) |
| `Core/CityBoardStore.swift` | `CityDistrictBook`; `merge(…, districts:)`; `load` keeps `districts[]`; `locate(territoryId:)` |
| `Core/CityTerritoryNotice.swift` | new: the cityTerritory card parser |
| `App/CityKit/CityTerritoryNoticeCard.swift` | new: the card and `CityDeepLinks` |
| `App/CityKit/CityLiveOnMap.swift` | new: the flag, `CityLiveMapSession`, `CityLiveMapControls`, `cityMatched` |
| `App/CityKit/CityRoamRootView.swift` | the deep link; the live overlay, drawer slide and capsule slot; `liveController` dependency |
| `App/CityKit/CitySessionWiring.swift` | passes the retained live controller |
| `App/CityKit/CityTokens.swift`, `CityDeedCard.swift`, `CityPropertySheet.swift`, `CityClaimFlow.swift`, `CityChallengeFlow.swift` | the district name for fogged tiles, the card's district and serial, `withDeedSerial` on the claim and challenge-won moments |
| `App/DesignFixtures/CityKitFixtures.swift` | `districts[]` plus serials in the fixture data; `city-notice`, `city-notice-open`, `city-live-on-map` |
| `Questify.xcodeproj/project.pbxproj` | the three new files, by `tools/generate_project.py` (test plans left as they were) |
| `Tests/CoreTests/CityBoardStoreTests.swift`, `Tests/CoreTests/CityTerritoryNoticeTests.swift` | Core tests |

No DesignSystem file was changed. No edits to global search, CYTabs, the IM views or the TopicDetail presenters.

## Skill rules applied

- **apple-design-motion**:
  - springs, not fixed easing (`CYMotion.hero` / `sheet` / `entrance` / `release`);
  - interruptible: the overlay toggles a state the next hold or tap can reverse mid-flight, and nothing blocks input;
  - press feedback: notice card scale 0.97, a haptic on pause;
  - a Reduce Motion fade instead of the big move.
- **apple-design-interaction / apple-design-os**:
  - one way back: ending folds the controls into the capsule they came from;
  - the tab bar hides during a walk, as on the live page;
  - 44 pt targets (52 pt pills, 44 pt glass circle);
  - the deep link lands on the map's own property drawer, not a new screen.
- **apple-design-foundations**:
  - CYTypography tokens only (`cardTitle`, `body`, `meta`, `caption`, `button`);
  - tabular digits on the live readings and on 积分;
  - "—" for unknown values, never 0.
- **apple-design-tactics**: the system notice style is reused, not a new card language; the result appears in place.
- **emil choreograph**:
  - one lead and its follower: the pill moves first and the stats pill follows by 120 ms (not uniform);
  - one entrance per container;
  - no stagger on the high-frequency notice list;
  - choreography never blocks the pause button.
- **emil gestures**: the hold stays the gate (0.8 s) and keeps its VoiceOver activation; no new gesture was added.
- **emil break-ui**:
  - edge data: a nil or 0 points line, a blank or placeholder district name, an unknown colour token, a fogged serial,
    a card without `territoryId` (no chevron, not tappable), a non-POINTS currency (rejected);
  - a refused start folds back.
- **emil write-swift**: value types for wire data; tolerant `try?` decode for the new arrays, so an older server or a bad
  array cannot fail the whole read.
- **mifb make-interfaces-feel-better**:
  - interruptible animations;
  - split and stagger the enter: the pill, then the stats;
  - a subtle exit (scale toward the anchor);
  - tabular numbers;
  - scale on press;
  - minimum hit area;
  - motion restraint: the map and camera do not move.

## Checks run here

- `python3 -B tools/check_scaffold.py`: PASS (structural checks, 4921 Swift files, the project matches the generator).
- `python3 -B tools/check_design_lint.py`: PASS (0 violations).
- `python3 -B tools/contract_ratchet.py --check`: 185 failing vs baseline 184. The one "new" id, `test_workshop_paid_professional…test_current_generic_draft_cas_reuses_real_reader_with_bounded_paging`, is the same pre-existing red named in `ui-h-code-r3-player.md` (red on `ui/main`). It is unrelated to City, so this branch adds no new failure.
- Not run (no Swift here): Core `swift test`, AppUnit, the build.

## LOCAL VERIFICATION CHECKLIST

Build: `ui/r4-city`, iPhone 16 Pro sim, dark. Fixture host: `--design-fixture <name>`.

1. **Core tests**
   - `swift test --filter CityBoardStoreTests` (new `testGapsR3DistrictsColourKeysAndDeedSerialReachThePlaces`, and the C1
     hook test still green);
   - `swift test --filter CityTerritoryNoticeTests` (3 new).
2. **District names**
   - `city-board` and the root with no fixture: rows and bands show **武康路** (d1) and **安福路** (d2); the d3 place
     (梧桐书店, placeholder seed "d3") still shows **街区 3**;
   - the fogged tile (d2) band shows 安福路 on the grey unlit band.
3. **Deed serial**
   - `city-property-mine` (t-wukang): band reads **武康路 · 地契 · No. 12**;
   - `city-property-challenge` (t-flower): **No. 3**;
   - `city-property-protected` (t-books): no serial, the tier name shows instead;
   - `city-property-unlit`: no serial.
4. **Colours**: d1 / d2 / d3 bands keep district/1 · 2 · 3; no hue change against r3 shots.
5. **Notice card**
   - `city-notice`: five cards. Expect:
     - DEFENDED with 守方补偿 +27 积分;
     - DEFENDED with no points line (0);
     - PLACE_LOST +36;
     - RENT +12 积分;
     - RENT_SETTLED with no chevron (no territory);
   - Large type: `city-notice-ax5`.
6. **Deep link**: `city-notice-open` → the map loads, then the property drawer for 武康大楼 rises over the SAME map, and
   the 附近 drawer slides away.
   - On TEST, signed in: trigger a failed challenge on a place you hold (second account), open 消息 → 系统通知, and check
     that the DEFENDED card shows (after the render hook above lands). Tap → the 漫游 tab opens with the drawer.
   - If messaging is a sheet, note whether it stays over the map (expected: the integrator decides whether to dismiss
     it).
7. **Live on the map** (flag on):
   - launch with `--design-fixture city-live-on-map --city-live-on-map`, location set to Allow
     (`xcrun simctl privacy booted grant location-always <bundle>`), and `defaults write <bundle> roamLivePurposeAcceptedV1 -bool YES`;
   - hold the capsule 0.8 s. Record a 60 fps screen capture and check:
     - the capsule morphs into the 暂停 pill;
     - the stats pill grows up from it about 120 ms later;
     - the 附近 drawer slides down and fades;
     - the tab bar hides;
     - the map and camera stay still;
     - 用时 ticks, and 地盘 / 公里 show "—" until known;
   - tap 暂停 → 继续 (medium haptic). Tap the flag → the finish modal → confirm → the controls fold back into the
     capsule, the drawer returns, then the live page opens with the finish report;
   - Reduce Motion on: cross-fades only;
   - flag off (no argument): the hold pushes the live page exactly as in r3;
   - consent not stored, or location not determined: the hold pushes the live page (consent card or priming);
   - pop the live page mid-walk (flag on): the root shows the paused controls in place.
8. **Production**: on a production build the 漫游 root still shows `城市大富翁在这个版本里没有开放。` and nothing in City
   calls the network.
9. **Edge data on TEST**:
   - a board point with no `place_id` now quotes (backend fix 1). Claim it, then check that the claimed moment shows
     地契 · No. N right away;
   - an older nearby response without `districts` still loads (tolerant decode).

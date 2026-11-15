# Receipt: Task B, City Monopoly numbers + attributes v2 (cloud)

- Branch: `ui/h-city-numbers-attr-cloud`, cut from `origin/ui/h-sys-citygame` at `336137aa`.
- Spec: `hengyin` `origin/docs/city-monopoly-spec`, `docs/delivery/backend-app-r2/CITY-MONOPOLY-SPEC.md` (v1.0 plus the owner ruling of 2026-11-15).
- Environment: Linux cloud container. **Swift is not installed, so nothing here was compiled or run.** The evidence is the Python structural checks and a Tree-sitter parse.

## What was done

### Currency rule
The app has one currency, points (积分). Every amount the spec writes as 城币 is modelled and labelled as points: claim price, rent, upgrades, challenge fee, shield, scout and the visitor reward. Formatting goes through `CityMonopolyFormat.points` ("120 积分" / "120 pts"). The City screens had no 城币 strings or fields before this work, so nothing needed remapping.

### Numbers (spec §2): `Core/CityMonopolyContracts.swift`
- `CityMonopolyTier` (T1–T4) holds the claim price and base rent. `CityMonopolyLevel` holds the Lv0–Lv3 names.
- `CityMonopolyRules` is a client copy of the frozen config. It is used only for previews; the server prices and decides everything. It covers:
  - upgrade cost and invested points;
  - rent formula with the multiplier cap of 4.0, time bands, set bonus, team bonus, charm bonus and weathering;
  - owner daily threshold and cap, and the grant split (100% / 50% / hard cap);
  - holding limit from the explore level;
  - claim protection (24 h, or 12 h in finale week), shield and scout cost;
  - challenge fee (finale and revenge discounts), DC, modifier cap, natural 20/1, the win-chance table and the fee split;
  - decay states and level drops, with lore grace days;
  - season phases and the reroll count.
- Wire models for §6.2: territory layer (with fog), deed card (rent multipliers decoded as a free-form dictionary), quote, evidence and command, command result (d20, mods, fee split), scout, shield, revenue page, season current, season leaderboard (top 10 plus the rows around me), and the visit-yield block on check-in.
- Optional `tier`, `upgradeLevel`, `districtId` and `decayState` on `RoamTerritoryItem`. Optional `territory` (rent produced, visitor reward, no-rent reason) on `RoamTerritoryCheckinReceipt`.

### Attributes v2 (spec §3): same file
- The six keys with display names and daily soft caps.
- AXP curve `need(L)` and `cum(L)`, checked against the spec table (Lv1 = 10, Lv25 = 670, Lv26 = 755, cum(50) = 91010), and level from AXP.
- Diminishing daily AXP, the title table (`ATTR_{KEY}_{LV}`), archetypes and the polymath rule.
- Response models for `GET /api/member/attributes`, the ledger and title equip. `MemberAttributeRow.levelProgress` gives progress within the current level.

### Client and lease: `Core/CityMonopolyService.swift`
- `CityMonopolyRoute` and `CityMonopolyService` follow the `RoamTerritoryService` pattern: same envelope, 401 handling, 1 MB limit and `RoamTerritoryError`.
- Writes carry an upper-case UUID `requestId` and `expectedVersion` where it is known.
- All routes are registered in `CityGameProductionLease.paths`, the registry `ChinaReviewedRouteCapability` admits from, in the same way as the earlier `/api/roam/territory/*` routes. `CityMonopolyRoute.leasePaths` mirrors the list, and a test keeps the two in sync.

### Screen models and haptics: `Core/CityMonopolyScreenModels.swift`, `App/CityMonopolyHapticPlayer.swift`, `App/DesignSystem/CYMotion.swift`
- `CityMonopolyTerritoryModel` reloads the points balance, the season, today's rent and the territory layer. It compares each layer with the previous one to detect a lost property and a new district majority or monopoly. It handles quote → GPS presence evidence → command, plus scout, shield, revenue and the season board.
- `MemberAttributesModel` loads the attributes, detects a level-up or an unlocked title, and handles equip and unequip.
- `CityPresencePreflight` gives distance, accuracy, dwell and photo hints using the spec's own wording (for example 「定位精度 41 m，需要 ≤ 25 m，走到开阔处」) and builds the evidence and samples.
- Haptics: the repo's existing haptics service is `CYHaptics`. I added two cases to it, `.error` and `.impactRigid`, because spec §5 needs both. `CityMonopolyHapticEvent` maps each §5 moment to cue sequences: claim, check passes and failures, rent count-up, takeover won/lost, property lost, defense held, upgrade, district control, attribute level-up and title unlock. Steps are spaced at least 120 ms apart (the `CYHaptics` cooldown). Under Reduce Motion only the closing cue plays. Decay reminders have no haptic, as the spec says.

### Views (existing components only, no restyle)
- `App/CityMonopolyTerritorySection.swift`, mounted in `RoamTerritoryView`, contains:
  - HUD: points balance, today's pending and settled rent, held/limit, season phase, countdown, score and rank;
  - deed card: tier, level, invested, rent, next upgrade price, challenge fee, holder with archetype and title, protection countdown, decay, multipliers, and DC with base win chance;
  - upgrade and challenge quotes, confirmed after a 60 s dwell sample (4 fixes, 20 s apart) with check chips;
  - scout, shield, rent ledger and the season solo board.
- Nearby cards in `RoamTerritoryView` show tier, level and decay chips and a 地产卡 toggle. Check-in copy shows the visitor reward and the reason no rent was produced.
- `App/MemberAttributesSection.swift` sits on the own-profile 成就 tab (`SocialPublicProfileView`, fed from `AccountView`). It shows archetype, equipped title, the six attribute rows (level, AXP progress bar, today's AXP against the soft cap, next unlock, season delta) and title equip/unequip. Each row has the spec's accessibility sentence.
- Factory: `AppSession.makeCityMonopolyService()` lives in `App/ReviewedCityGameLease.swift`. It is not in `AppSession.swift`, so that glue file did not grow.
- Strings use the screen's existing inline `ChannelCopy.text(zh, en)` pattern. No catalog keys were added, and the catalog checks still pass.

### Tests: `Tests/CoreTests/CityMonopolyTests.swift` (SwiftPM `QuestifyCoreTests`)
- Lease and route coverage, request encoding and validation.
- Every rule table (tier/upgrade/invested, the rent table and its cap, daily caps, challenge fee/DC/mods/win chance, decay).
- AXP curve, titles and archetype.
- Decoding of every new payload, including the shape variants.
- Service envelope and 401/409 mapping.
- Both screen models, using a fake `CityMonopolyReading`.
- Presence preflight and haptic sequence spacing.

## Files touched
New:
- `Core/CityMonopolyContracts.swift`
- `Core/CityMonopolyService.swift`
- `Core/CityMonopolyScreenModels.swift`
- `App/CityMonopolyHapticPlayer.swift`
- `App/CityMonopolyTerritorySection.swift`
- `App/MemberAttributesSection.swift`
- `Tests/CoreTests/CityMonopolyTests.swift`
- `docs/release/receipts/cloud-liveactivity-city.md`

Modified:
- `Core/CityGameHTTPService.swift` (lease paths)
- `Core/RoamTerritoryContracts.swift`
- `App/RoamTerritoryView.swift`
- `App/ReviewedCityGameLease.swift`
- `App/SocialPublicProfileView.swift`
- `App/AccountView.swift`
- `App/DesignSystem/CYMotion.swift`
- `Questify.xcodeproj/project.pbxproj`: hand-added file references and build files, in the same way as `336137aa`. The generator-equivalence check in `check_scaffold.py` passes.

## Check results (baseline on untouched `336137aa`, then after the changes)

| Check | Baseline | After |
|---|---|---|
| `python3 -B tools/check_scaffold.py` | exit 1: `App/AppSession.swift` 8187 lines > ratchet 8171 (AppSession ratchet). All earlier gates pass, including catalogs, project/generator equivalence, design lint, a11y and log redaction | exit 1, same single failure. `AppSession.swift` was not touched; all earlier gates pass |
| `build_page_route_table.py --check` (runs after the failing gate, so run separately) | PASS, 262 pages | PASS, 262 pages |
| `python3 -B tools/contract_ratchet.py --check` | exit 1: 188 failing, baseline file 186, **new 2**: `test_home_city_location_consent…test_glue_files_stay_at_the_ratchet_ceiling` and `test_ugc_1_2_completeness…test_appsession_ratchet_not_violated` (both from the same AppSession line count) | exit 1, identical: 188 failing, the same 2, no new failures |
| `tools/check_swift_syntax.py` (Tree-sitter, Python 3.12 venv with the pinned wheels) | whole repo: exit 2 (an existing file trips the grammar; `App/RoamBrowserView.swift` also segfaults the parser) | all 14 touched/new Swift files: PASS, 0 diagnostics |

`test_city_game_base` (it forbids `wallet`, `purchase` and similar in CITY lease paths) passes.

## Spec ambiguities and decisions
1. **City-coin wallet.** `GET /api/city-game/wallet` was dropped. Under the ruling there is only one balance, the member's points, and `test_city_game_base` forbids `wallet` in CITY routes. The HUD reads the balance from the growth center (`GrowthCenterReading.overview().center.points`), today's rent from `territory/revenue`, and the post-command `balance` from command results. The shop purchase and chance routes (§6.2) are not wired, because they were outside the requested scope (tiers, upgrades, rent, caps, protection, challenge, decay, season).
2. **Season carry/burn rules (§2.10 reset, `carry_rate`) and the 300 stipend.** These were written for a seasonal coin. The app shows only what the server returns and does no carry or burn maths for points. The backend needs to confirm how those rules translate under the points ruling.
3. **The spec's `visitorCoins` field** decodes into `visitorPoints`. Either key is accepted.
4. **Response envelopes the spec does not fix** are decoded tolerantly:
   - map: bare array or `{properties|items}`;
   - leaderboard: `top|entries` and `around|aroundMe`;
   - instants: epoch ms or ISO-8601;
   - `archetype`, `equippedTitle` and `nextUnlock`: string or object;
   - `mods[]`: int or `{source,value}`;
   - rent multipliers: a free-form `[String: Double]`;
   - `outcome`: mapped through a synonym table (`APPLIED`/`WON`/`LOST`/`REJECTED`…).
5. **`GET /api/member/attributes`.** The spec does not list owned titles, so an optional `titles[]` was added. Without it, only the equipped title shows. `axp` is read as lifetime AXP when it covers `cum(level)`, and as in-level AXP otherwise.
6. **Claim command.** Claiming still goes through the existing photo claim (`/api/roam/territory/claim`). The panel shows only the claim **quote**. `territory/claim/command` is modelled but not called from the UI, because the spec's evidence needs App Attest, in-app-camera signed metadata and pHash, and no such pipeline exists on this branch. Upgrade and challenge do send `.../command` with GPS dwell samples. `simulated` is always `false` and `attestAssertion` is always nil: `RoamDeviceFix` carries no `sourceInformation`, and App Attest is not wired.
7. **Weathering** halves rent after the 4.0 cap, so it always halves. The finale and revenge challenge discounts apply after the 30-point minimum.
8. **Defender-side moments.** "Property lost" and "district majority/monopoly" are detected by comparing territory layers between reloads. "Defense held" only plays after a successful shield. Real defense results need push or receipts, which the spec routes through notifications and which are not on this branch.
9. **Property path id.** `/api/city-game/territory/property/{}` is admitted on the China production host only when the id normalises to `{}`, meaning a 32–36 character hex/UUID id. A short property id like `prop-1` would be refused by `ChinaReviewedRouteCapability` in production, so the backend should use UUID property ids or this needs a query-parameter variant.
10. **Attributes on the profile** use the reviewed CITY lease (`makeCityMonopolyService`). The section is hidden when the CITY lease is off.
11. **Haptic approximations.** The Core Haptics rumble in the claim moment is not reproduced: `CYHaptics` has no pattern player. The 80 ms d20 tumble becomes 120–170 ms ticks to respect the 120 ms cooldown.

## Needs compile verification on the Mac
- Everything in this change. Swift was never compiled here. In particular:
  - the SwiftUI view builders in `CityMonopolyTerritorySection` and `MemberAttributesSection` (`let` inside builders, `LabeledContent` in a `Section`, the `CYProgressBar` and `CYStatusChip(verbatim:tone:systemImage:)` call sites);
  - `SensoryFeedback.impact(flexibility: .rigid)` and `.error` in `CYMotion`;
  - the `@MainActor` closure for `monopolyPointsBalance` that captures `session.growthCenterReader`.
- Run `swift test --filter CityMonopolyTests`, plus the existing `RoamTerritoryTests`, which decode the extended `RoamTerritoryItem` and check-in receipt.
- The earlier commit `336137aa` passed `CYPillButton` arguments as `fullWidth:` before `systemImage:`, which does not compile. The three cases in `RoamTerritoryView` are fixed here. Other parts of that commit were never compiled either, so check them at the same time.
- On a device, check the sequenced haptics and that the 60 s dwell sampling (4 fixes) behaves well with the GCJ-02 fix provider.

# Cloud X2b — contract ratchet, no new failures

Worker inventory of `Tests/ContractChecks` after these edits: **194 failing, baseline 194, new 0, fixed 0**. `docs/release/contract-failing-baseline.txt` was not raised. No previously failing id started passing, so no baseline line was removed. `python3 tools/contract_ratchet.py --update` was not run.

The four baseline crashes (`test_club_customer_keyword_debounce`, `test_project_edit_contracts`, `test_run129_navigation_diagnostics`, `test_run130_submission_evidence`) still fail at import because the club-product workflow hash changed. The workflow file was not edited and the hash was not re-pinned.

## App fixes (the check was right)

- Pasteboard. `NPCChatDataExport`, `PlayInPlayTools`, and `RoamNearbyParityExtras` assigned `UIPasteboard.general.string`. They now call `LocalPasteboard.copy`, which is the local-only pasteboard. The plain-assignment ban stays.
- Door referral. `AppSessionDoorEntry` had set `scanEnabled` from `playerWritesEnabled`. Production scan and binding are both `false` again. The disabled-gate strings are unchanged.
- Roam share snapshot. `api/roam/share/snapshot` is an anonymous read. It was listed in `ReviewedPlayerWriteLeases.roamExtraPaths` and is removed from that write set. The read route is unchanged.
- Settings row tap. The sound row is a navigation link. The UITest variable was named `sound`, so `sound.tap()` looked like a switch tap. The variable is `openSound`. The switch-tap gate is unchanged.
- Ops catalog. Three files already store device state and were missing from `docs/ops-safety/client-data-catalog.json`: `PassMembershipViews` (`pass_reveal_seen_v1`), `PlayThemePresentation` (`cy_playTitleCardSeen`, capped at 200 topic ids), and `SquareCloudComposerView` (compose drafts and pending request envelopes). Retention and deletion stay “pending privacy review / not verified per store”. Logout is not claimed to clear them.

## Checks updated (the app was already restyled)

Locators followed code that moved out of `AppSession` / `AppCompositionRoot` for the scaffold line ceiling. Grant match rules, money switches, `settlement: false`, the type-0 unlike body, and the session-fence count stay as written.

- Allowlist, payment gating, marketing entry, and native entry wiring now read `ReviewedPlayerWriteLeases.swift` and `AppSessionDoorEntry.swift`.
- Topic like may be named in the lease file. The type-0 body stays in `Core/TopicUnlike.swift`.
- `expireIfMatching` is internal so the door extension can call it. Logout and activity-detail fences still clear the vault; the activity slice still has two viewer-revision comparisons.
- Query admission is the full predicate in `AppCompositionRoot`, including `admitsPlayerWriteQuery`. That helper is still `playerWritesEnabled`, China, and only `api/v1/community/` and `api/friend/` prefixes.
- City board. Dice unknown value `cityGame.value.unavailable` is rendered from `CYCityBoard`. The other three unused city-game strings stay orphans. City fairness is mounted once, from `CityPlayerView` via `CityFairnessEntry()`.
- `String(localized:)` with a table is allowed only when that key exists in `Resources/<Table>.xcstrings` with `en` and `zh-Hans`. A bare `String(localized:)` still fails.
- Stamp camera view calls `StampCameraPageReady.captionUnits` only. `createPath` and `marksRouteLive` stay forbidden.
- Official events: the browser shows `page.visible`; the coordinator still filters with `query.visible(rows)`. Both HTTP methods are GET. `official.organizer.counts` is an accessibility identifier; the catalog key keeps the format arguments. Concatenated identifiers (`"official.inbox" + ".failed"`) are read as the full id.
- Free exploration keeps server order: filter the stores, then `ForEach` the enumerated array. No sort and no `prefix(6)`.
- Play task outcome is `PlayTaskOutcomeSection(..., openNode:)` and still sits before `if let node`.
- Social guide removed rows are `case .empty(.removed)` because `ProfileGuideRead` sets that phase. Create time is `page.createTimeDisplay`, which returns `SocialText.nonempty(row.createTime)` only when ready. The contract field stays `createTime`.
- Square workspace identifiers `activityPicker` and `draftsSheet` are not catalog keys. Square detail and my-like skip `share.title` / `share.entry` (the shared “转发帖文” string). Empty comments use `SquareDetailPageModel` keys.
- Non-cash fact rows are `Text(verbatim:)`, `fixedSize`, and `accessibilityIdentifier` inside the labeled row.
- Integrated acceptance skips three ledger rows (`dropFirst(3)`). Map overflow opens `roam.more` and taps the one “Show list only” button. Sign-out still requires the confirm sheet title and `settings.signOut.confirm` labeled “Sign out”.
- Crop page keys `pages.crop.*` are bilingual in `Localizable` and referenced by `MiniCropSession`. Template and mini crop views call `CropPageModel.facts`. Merchant and creator crop views still do not. Leftover Chinese sentences in the note stay out of the catalog.
- `informationDetail.state.unknown` on `ProfileCurrentReview` is still the em dash (the page-ready row). The restyled detail empty state looks the same key up from `Localizable` as a sentence.
- Search map side catalog gained the four keys already in `Localizable`: `searchMap.clearHistory.a11y`, `searchMap.endOfResults`, `searchMap.refreshResults`, `searchMap.unknownResults`.
- Team fragment gained `team.join.empty` and `team.join.emptyDetail` with the same English and Chinese as `Localizable`.
- Byte pins moved to the current files after the semantic asserts in the same tests still held: one customer insertion, customer span only, QR camera primer, verification issue detail, perks navigation, search and explorer restyle. Money, merchant selection, and password gates were not edited.

## Left failing on purpose

The 194 baseline ids, including the four workflow-hash import crashes. No money, merchant, password, or presence gate was weakened. `App/RegionalLaunchConfiguration.swift` grants were not edited.

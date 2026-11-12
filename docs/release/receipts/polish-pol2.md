# Polish pass pol2: Roam hub + finished history (code-only, uncompiled)

SHA: 24d825a30
Base: origin/ui/main 9ad1f1649. Branch ui/pol2. Files: RoamExperienceHubView, RoamExperienceComponents, RoamHistoryViews, RoamSubpageParityViews.
All accessibility identifiers unchanged; no new strings; no Core/network changes.

| Area | Before | After |
|---|---|---|
| Hub hero | tint glyph + title on plain list row | indigo→ink1 night hero card, rounded title, glass edge; no lantern on chrome |
| Offline notice | tertiary grey caption | night-glass capsule |
| Route sketch | 9 % accent slab, 4 pt accent line, flat dots | indigo→ink map ground, lantern 3 pt route with blurred glow trail (skipped under Low Power / Reduce Transparency), hot place dots, white end marker; honest empty label kept |
| History cards | domain-card slab | ink1 paper card (indigo falloff, 1 pt night edge), chevron affordance, rounded-bold stats in even columns, lantern medal marks |
| Summary total | largeTitle | 44-ish rounded heavy (largeTitle style, Dynamic Type safe) with numericText |
| Tools row (那年今日/回顾/导出) | system bordered buttons | night-glass tiles, 64 pt min, pressable |
| Denied state | bare label | night-glass notice |
| Hub↔detail continuity | plain push | cyHeroSource on record card, cyHeroDestination on detail (iOS 18+, off under Reduce Motion; live-finish entry keeps plain push) |
| Detail | ink card, yellow medal | RoamNightCard, lantern medal, ink1 medal rows with press style |

Not done / for integrator: compile; visual check on Questify-iPhone17 (default + RM); RoamLiveSessionView untouched.

## Hub tap bug (coordinator heads-up)
pol2 does not touch hub rows/NavigationLinks: only the hero Section (no gestures, no overlay hit-testing beyond a stroke overlay on a non-row view) changed. Rows are `NavigationLink { } label: { CYListRow(.. trailing: .none) }` where `CYListRow` applies `cyPressTracking()` (CYMotion.swift:154), a `simultaneousGesture(LongPressGesture(minimumDuration: 60, maximumDistance: 10))` inside a List NavigationLink. Unverified suspect (no simulator): it is the only gesture in the row path, and `.none` trailing rows have no chevron. First experiment for the integrator: set `\.cyPressHandled` true on the hub List (or drop cyPressTracking in CYListRow when inside a List) and re-run RoamExperienceFlowTests. If pol2's hero is the cause, revert the hero hunk in RoamExperienceHubView.swift (c0e173825).

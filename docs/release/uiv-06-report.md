# UIV-06 report: me / profile / settings group (NOT COMPILED)

Branch `cloud/uiv-06` from `origin/ui/own-1`. Method: `ui-agent-method.md` + `ui-standard.md` (wip/be-brief). Presentation only.
Reference screenshots read: `chengyin/docs/evidence/player-e2e-20260927/038..041`. `docs/delivery/page-polish-20261102/impl-player-me/shots` does NOT exist in the chengyin repo checkout, so it was not used.

## Screens
| iOS file | Mini-program page | Screenshot |
|---|---|---|
| SettingsView / SettingsSupportSections / SettingsPrivacyLocationView | pages/shezhi/shezhi | none found |
| GrowthCenterView (+Components) | subpackageP3/.../growthcenter/index | 038 |
| GrowthLeaderboardView | .../growthcenter/leaderboard | 039 |
| StampAlbumParityViews / RoamStampViews | .../stamp-album | 040 |
| ProfileBadgesView / ObjectBadgeViews | .../badge-wall | 041 |

## Diffs fixed
- Settings: 关于 moved ahead of privacy/compliance group (account deregistration), so destructive/compliance rows sit last, sign-out remains the final section. Account deletion stays reachable via the compliance section (`compliance.cancellation`).
- Settings privacy media status chips: raw `.orange/.green/.red` -> `palette.warning/success/danger` (text label already carries meaning).
- Leaderboard: metric/period `.menu` pickers -> `.segmented` (mini-program shows chips); rows rewritten to rank, name (+ "me" tag), trailing tabular score + unit, in one 44pt+ row instead of stacked LabeledContents; podium medal colours and "me" tag use palette tokens instead of yellow/gray/brown/tint.
- Badge detail: raw colour tint array -> palette tokens.
- All accessibilityIdentifier values and localisation keys unchanged. No new strings (no ui-strings-uiv-06.json needed).

## Diffs left
- Growth center is still an insetGrouped List; mini-program has a large-number hero card + rank link card (038). UIV-TODO: use CYBalanceHero for points section (needs compile check of its initialiser).
- Leaderboard has no podium hero for top 3 (039); only a medal mark in the row.
- Stamp album empty state (040) and badge wall wall/list segmented toggle (041) live in RoamStampViews/ObjectBadgeWallParityViews; not restructured.
- `GrowthAndLeaderboardParitySectionView.swift` is an audit view with raw colours and hard-coded zh strings; left untouched.
- Loading states are ProgressView, not CYSkeleton.
- Sign-out button not `role: .destructive` (SettingsAccountEntries is outside this group).
- Other raw colours in Profile* files (ProfileComplaintPreparationView red/green, ProfileOrdersView, ProfileParticipantsView `.tint(.blue)`, RoamStampViews accentColor) left for owners of those files.

## Compile risks
- `@Environment(\.cyPalette)` is used on GrowthLeaderboardRow, GrowthPodiumMark, OwnMediaRow, ObjectBadgeDetailView; the key exists in CYDomainPalette.swift (read-only computed from `themeDomain`). Verify the environment is set at the player root.
- `.pickerStyle(.segmented)` with 2 options each: check label widths at AX sizes.

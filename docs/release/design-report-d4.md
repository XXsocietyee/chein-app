# Design report D4 — clubs/channels + me/settings (resume after crash)

Branch `ui/d4`, rebased on `origin/ui/kit`. Builds: 0 errors (design-run.sh, one lock). Screens captured at default size, dark, `/Users/fanning/chengyin-refs/design-reports/d4/`.

## Pairing (page-map.csv)
- ClubDirectoryView / ClubRow ← `pages/talent/list/index` (俱乐部 tab; hub-like: native directory shows only the club-card list section). Ref: merchant-deep/003.
- ClubDetailView ← `pages/club/detail/index`. ClubChannelMessagingView has no direct mini page (merged into detail, 4th tab/Discord channels).
- SettingsView: no row in page-map; nearest sections from player-e2e 059/063 (grouped list).
- GrowthLeaderboardView ← `subpackageP3/pages/growthcenter/leaderboard/index` (ref player 039).

## Done (compare images)
| Screen | Fixture | Compare |
|---|---|---|
| Directory | d4-directory | compare-directory.png |
| Detail | d4-detail / d4-owner-detail | compare-detail.png |
| Channels | d4-channels | compare-channels.png |
| Settings | d4-settings | compare-settings.png |
| Leaderboard | d4-leaderboard | compare-leaderboard.png |
Growth (d4-growth) and badges (d4-badges) fixtures are registered but not yet captured; stamp album has no fixture.
Note: compare left images for detail/settings/channels are nearest-available evidence, not verified 1:1 pairs.

## Changes
Club card (cover banner, logo, heavy name, counts, host strip, one pill), card insets + hidden chevron in directory, channels neutral tokens, invisible "Accept rules" label fixed (black on white pill), settings grouped cards/sign-out confirm, 5 new strings in `ui-strings-d4.json`. DEBUG fixtures in `App/DesignFixtures/D4Fixtures.swift` (labelled synthetic); registry `make` is now `@MainActor`.

## Demoted controls
None removed; no controls added.

## Checklist (screens captured)
1 order ok (directory/leaderboard); 2 one primary (directory: Join pill; channels: Accept pill while rules unaccepted); 3 ok; 4 dark ok; 5 no violet; 6 kit tokens; 7 states: only content states captured; 8 XL not captured; 9 zh captured for directory/detail only, EN for others; 10 builds, no logic changes.

## Open issues
- Channels: sidebar takes ~half the width on iPhone and header title wraps ("club-news" / badge); needs compact-width collapse default. Rules gate banner is tall.
- Detail fixture shows the "application rejected" status (reader fixture), so the primary join pill is not visible in the capture.
- XL Dynamic Type, growth, badges, stamp album, enrollment/governance/operations, join/quit CYConfirmSheet not visually verified this session (machine-gentle resume).

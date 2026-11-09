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

## Round 2 (coordinator review of compare-channels.png)
Compare images (in `/Users/fanning/chengyin-refs/design-reports/d4/`): `compare-channels.png` (list EN | conversation EN | conversation XL), `compare-detail.png`, `compare-confirm.png` (mini-program quit dialog | zh | EN | XL zh). Reference crop: `ref-club-detail-quit.png`.
1. Channels: on compact width ONE pane. Channel list is its own screen (grouped rows: # / megaphone icon, name, unread/mention count); tapping a channel opens the full-width conversation. Regular width keeps two panes (260 pt list). Fixtures `d4-channels` (list) and `d4-channel-chat` (conversation).
2. Header: back + one-line truncating title + quiet caption ("Announcement · read only" / "Muted") + ONE overflow menu (mute, members & roles with count, report). Ids kept (`club.channel.muteButton`, `memberRosterButton`, `reportChannelButton`).
3. Rules/EULA: one compact row with a "Review rules" pill; full text + "Accept Channel Rules & EULA" in a CYConfirmSheet. Posting is still locked until accepted (composer lock text, `hasAcceptedRules` untouched). Row stacks vertically at accessibility sizes.
4. Messages: avatar + name + role badge + time on one line, body below full width, grouped by sender, 20 pt between groups. Composer pinned at the bottom with a "+" attachments menu.
5. Pairing corrected: the quit-dialog page pairs with ClubDetailView (compare-detail.png). Leave confirmation = CYConfirmSheet with title, existing localized message, consequence box with 3 icon rows (new optional `consequences:` param on CYConfirmSheet, default empty so other callers are unchanged), Cancel + solid red destructive button side by side (stacks when too wide). Join/apply confirmation unchanged. Fixture `d4-confirm`.
6. Captured: default size zh+EN, XL (accessibility-extra-large) for conversation (EN) and confirm (zh). The sheet content scrolls at XL.

Demoted: sidebar toggle with unread badge (unread now lives in the list screen), bell / flag / member-count buttons (now in the overflow menu), status chip (now caption), mute icon next to the title (now caption).
Caveats: the "+" attachments menu is visual only (Photo/Link entries disabled; no attachment logic exists). The leave-sheet message keeps the existing localized text ("Rejoining may require approval") rather than the mini-program's "no approval needed", which may be untrue for approval clubs. Consequence-row strings are inline via ChannelCopy (zh/EN) like the channel view; not yet in ui-strings-d4.json. Join confirmation sheet and the channel list at XL not separately captured. The XL zh confirm capture predates the white-label fix on the red button.

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
Growth/badges/stamps/enrollment/governance/operations/join: see Round 3 below.
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

## Round 3 (leftover screens) — all through DEBUG fixtures, real views
Compare images in `/Users/fanning/chengyin-refs/design-reports/d4/` (left = mini-program page from page-map.csv pair, then zh, EN, XL where noted); raw captures in `r3/`.
| Screen (pair) | Fixture | Compare |
|---|---|---|
| Growth center (`growthcenter/index`, ref 038) | d4-growth | compare-growth.png (ref, zh, EN), compare-growth-xl.png |
| Badge wall (`badge-wall/index`, ref 041) | d4-badges, d4-badges-empty, d4-badges-error | compare-badges.png (ref, zh, EN, error zh), compare-badges-xl.png |
| Stamp album (`stamp-album/index`, ref 040) | d4-stamps-empty, d4-stamps | compare-stamps.png (ref, empty zh, empty EN, 3 stamps zh) |
| Club join sheet (`club/detail`, ref 006) dark | d4-join-confirm | compare-join.png (ref, zh, EN, zh XL) |
| Quit sheet XL zh after white-label fix | d4-confirm | compare-quit-xl.png (ref, zh default, zh XL) |
| Enrollment (`club/enroll`) | d4-enroll | compare-enrollment.png (ref 010 settings sheet, zh, EN, zh XL) |
| Governance workspace (`club/detail` settings sheet, ref 010) | d4-gov | compare-governance.png (ref, zh, EN) |
| Operations / club edit (`club/edit`, ref 011) | d4-ops, d4-ops-create | compare-operations.png (ref, zh, EN) |
| Composer | d4-channel-chat | compare-composer.png (zh, EN) |
Fixtures: `D4MeFixture` (+badges empty/error, stamps), `D4ClubOpsFixture` (enroll/governance/operations; reuses the existing `ClubGovernanceFixtureAccess` / `ClubOperationsFixtureAccess` synthetic access), `D4ClubFixture.joinConfirm`. All `#if DEBUG`, registry names above.

### Changes
- Growth: score card is now a hero (small caption + 52 pt heavy rounded number), heavy section headers; every row, id and the leaderboard link kept (6 footprint rows, mini shows 4, nothing removed).
- Badges: summary line first (mini order), then a segmented 列表/墙 control (was a menu row); same selection logic.
- Stamp album: dark domain page background; empty-state camera action is a centred pill under the message (was left-aligned, detached).
- Governance workspace: single "Manage" list split into the mini-program settings-sheet sections "客户与项目" (customers & projects) and "成员与权限" (members & permissions); same links, ids and permission gates.
- CYConfirmSheet (kit): confirmations without consequences use a compact detent (0.36) instead of half-screen; accessibility sizes always open at `.large`; consequence icon column scales with Dynamic Type (fixes overlap at XL).
- Enrollment and operations views were already on kit tokens from earlier rounds; captured as-is, no layout change needed.

### Checklist for Round 3 screens
1 order: growth ok (score → footprint → badges), badges ok, stamps ok, join ok, governance ok (two sections as mini), enrollment/operations ok as far as the nearest reference goes. 2 one primary: stamps empty = camera pill; join/quit = confirm pill; other screens read-only or pure navigation lists. 3 <=3 other controls: growth = refresh + leaderboard; badges = refresh + segmented; stamps = toolbar camera. 4 dark. 5 no violet. 6 kit tokens. 7 states: badges empty/error, stamps empty/with data captured; growth loading/issue states not re-captured. 8 XL captured for growth, badges, stamps(zh XL raw `r3/stamps-zh-xl.png`), join, quit, enrollment; no clipping seen (sheets scroll). 9 zh+EN for all except badges-empty and stampsfull (zh only). 10 builds 0 errors, no logic changes.

### Composer + attachments menu (screen 5)
Not made real. The "+" menu stays Photo/Link **disabled**: `ChannelDiscordMessaging` only projects *received* attachments for display; there is no upload/send-with-attachment path in Core or the channel view, so enabling the items would require new logic. The fixture channel (`club-news`, announcement + rules unaccepted) shows the locked composer text, so the open "+" menu itself was not screenshotted; compare-composer.png shows the channel header/rules row/message list only.

### Open issues
- Mini-program detail rows in the settings sheet carry a sub-line and count chips (e.g. "2 个团"); the native rows have icon + title only (no strings/data for sub-lines without new copy). Not added.
- Operations (club edit) hero card: the banner/name block has a black lower half in the dark fixture (no cover image); reads as a clipped card.
- Governance section titles "客户与项目 / 成员与权限" are inline (zh/EN via ChannelCopy), not yet in `ui-strings-d4.json`.
- Growth: mini shows "总榜第 N 名" under the avatar and a hero subtitle; native shows the existing rank/percentage rows (no avatar data in the fixture).
- CYConfirmSheet is a shared kit file; the detent/ScaledMetric change affects all callers (compact only when no consequences).

## Round 4 (leftovers + EN/XL sweep)
Shots via design-batch.sh (one build, 28 shots EN default + accessibility-extra-large for 14 fixtures; contact sheet + `compare-operations-r4.png`, `compare-governance-r4.png`, `compare-final-r4.png`, per-page `r4/shots-<page>.png` in `/Users/fanning/chengyin-refs/design-reports/d4/`; raw `batch-<fixture>-<en|xl>.png`).
- Governance workspace rows now carry a one-line sub-line under the title (mini-program settings sheet); inline zh/EN via ChannelCopy, no counts (no data). Sub-lines only on the workspace list; other callers of `link()` unchanged.
- Operations hero: with no cover the half-black photo card is replaced by a compact identity card (mark, name, city, role chip); stacks vertically at accessibility sizes. Cover present keeps the image card.
- Club directory card: host strip + pill stack at accessibility sizes (Join was truncated).
- Mini-program refs: compare images use the existing mini ref/zh captures from round 3 (left panels); EN/XL are new. Not re-paired.
- Still open at XL: leaderboard "Sample me" row wraps and enrollment "Groups" row wraps awkwardly; "Club management" nav title truncates (system large title); directory search pill overlaps the next card at the scroll end; XL hero icon sits slightly left of the text column. Join/confirm and channel pages looked fine at XL. Governance/join strings still inline (not in ui-strings-d4.json).

## Round 5 (player-first fixes + club pages)
Two design-batch.sh runs (second = final; first had unquoted zh launch args and zh shots were invalid, EN/XL from it were used only to find the members-row issue). Shots + contact sheet in `/Users/fanning/chengyin-refs/design-reports/d4/` (`batch-*.png`, latest `contact-*.png`). Resources/Localizable.xcstrings was temporarily merged from `ui-strings-d4.json` for the batches only and reverted (UI files only), so the new keys render only once the integrator merges the json.
Fixed (verified at accessibility-extra-large):
- Leaderboard "Sample me" row: at accessibility sizes score drops under the name and the "Me" tag stacks (`GrowthLeaderboardView`).
- Enrollment "Groups" row: label above a large count at accessibility sizes (`ClubEnrollmentView`).
- Directory search: system `.searchable` overlay replaced by a pinned `safeAreaInset(.top)` capsule header (`ClubDirectoryView`), so it cannot cover the last card. New keys `club.directory.clearSearch`; field id `club.directory.search`. Behaviour unchanged (submit searches, empty clears).
- Governance strings moved out of inline ChannelCopy into `docs/release/ui-strings-d4.json`: 2 section titles + 14 sub-lines (`club.gov.section.*`, `club.gov.sub.<read>`), zh verified in gov-zh / gov-xl.
New fixtures: `d4-tab-posts|events|overview`, `d4-members` (real ClubDetailView/ClubMembersView, synthetic reader).
Pairs checked: club detail tabs ↔ `club/detail` 帖子/活动/概览 (M/021); members ↔ overview "成员 · N" + 成员管理 (M/054); governance ↔ settings sheet (M/054). Channel list: the mini-program has no channel list (Discord-style is native-only; M/067 is the IM inbox, not a pair). Invite/share: the mini-program uses WeChat's own forward panel (`open-type=share`, name-row icon + owner/admin "邀请成员 ›"); the native club pages have no share/invite surface at all and adding one (ShareLink + link) is new behaviour, so not done — needs a decision.
Still open: Members row at XL: "Fixture administrator" line centres (my `.multilineTextAlignment(.leading)` on the row did not take effect; memberRow needs its own alignment); enrollment nav title truncates ("Enrollment ro…") and the "Date to be set · Registered" line hyphenates at XL; tab picker (segmented) text is tiny at XL (system control).

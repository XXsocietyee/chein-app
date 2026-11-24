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

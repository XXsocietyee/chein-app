# mp-mpmissing: mini-program missing screens + per-screen audit, layout side (branch ui/mpmissing)

Source of truth: `liboyang42-cpu/hengyin` `chengyinhub-xcx` (pushed 2026-11-12). Base: `origin/ui/main`.
CODE-ONLY: nothing was built, run or tested on a simulator; the integrator compiles. No mini-program screenshots were shared.
Checks run: `tools/generate_project.py`, `tools/check_design_lint.py` (PASS), `tools/check_scaffold.py` (PASS),
`tools/build_page_route_table.py` (regenerated `Core/MiniProgramPages.swift`: +12 generated page cases, no hand edits in Core).

## Part 1: screens that were missing (mini-program page -> native file)

| mp page | native file / type | matched | gated |
|---|---|---|---|
| `subpackageA/pages/video-bounty/index` | `App/VideoBountyView.swift` `VideoBountyView` / `VideoBountyHost` | form only with campaignKey+topicId (platform chips TikTok / Reels / YouTube, link, optional group, field + submit errors, morph submit); tabs my submissions / plays and accruals; skeleton, error+retry, empty for each tab; status labels (8 codes); window end, review note; appeal sheet (required note) and cancel confirm; pull to refresh | accruals are "recorded" only + payout-off note; no withdraw anywhere |
| `subpackageMember/market/passes/index` | `App/PassMarketViews.swift` `PassMarketView` / `PassMarketHost` | points balance card (read-only, hidden when unknown), tabs on sale / my orders / gifts, member (platform pass) card -> reveal, product cards (kind, city, validity wording, works · seats, cash / points price), library row, order states (paid / awaiting first play / gift / pending + reason / cancelled / refunded / unknown), gifts sent / claimed with deadlines; loading / error / per-tab empty; quiet-refresh-failed strip | none needed (read-only) |
| `subpackageMember/market/pass/index` | `PassDetailView` / `PassDetailHost` + `PassTicketHero` | shard-assembled lantern pass hero (foil, Reduce Motion cross-fade), fact rows (type, city, validity, seats, user me / friend), playable works, for-me / gift chips, checkout summary (price / cash with closed-reason / points), quote states (loading, unavailable reason, registration-checkout route, buyable) | buy buttons OFF: pay modes shown as read-only capsules + "Purchases aren't available in the app yet". Unlock steps sheet and gift-token sheet not built (only reachable after a PAID order) |
| `subpackageMember/market/gift/index` | `PassGiftClaimView` / `PassGiftClaimHost` | badge pop + looping glow ring (static under Reduce Motion), ready / claimed / failed reason / unknown-result states, "view" after claim | claim OFF (`MPCommerceGate.claimsEnabled = false`): read-only note instead of the claim button |
| `subpackageMember/market/membership/index` | `App/PassMembershipViews.swift` `PassMembershipView` / `PassMembershipHost` | pass card (active / until), swaying key emblem, playable library row with count, plan radio cards with "best value" ribbon + selection spring, renew line, terms, merchant sentence, not-enabled, loading, error | open / renew OFF: footer shows the server-derived label (not on sale / device unavailable / open / renew) disabled + gate note |
| `subpackageMember/market/library/index` | `PassLibraryView` / `PassLibraryHost` | kind chips all / city / free (sliding pill), club-style photo cards (cover, ¥0-with-pass only when server says covered, city glass chip, kind · minutes), staggered entrance, loading / error+retry / merchant / off / empty | n/a |
| `subpackagePass/reveal/index` | `PassRevealView` | full reveal first time per account and after paid (shards fly in, key fuses with lantern glow, warm gradient rises, eyebrow / title / line / button staggered, Skip after 600 ms), idle state otherwise, Reduce Motion = end state at once, merchant sentence, paid copy only from server facts | n/a. Native uses SwiftUI motion, not the mini-program's baked frame sprites |
| `subpackageJourney/pages/landing/index` | `App/JourneyLandingViews.swift` `JourneyLandingView` / `JourneyLandingHost` + `JourneyDuoView`, `JourneyModeTilesView` | headline per kind, inviter ↔ you duo with travelling lights (static under Reduce Motion), seat number pop, title pill, how-to-play tiles (radio with matched-geometry dot, rules list), facts (invite valid / signup closed / claim by / seat), primary (view / buy own / enter run), browse-first, invalid (incl. "already claimed" calm state), missing link, error | gift / seat claim and "check claim result" OFF -> gate note |
| `subpackageJourney/pages/seats/index` | `JourneySeatsView` / `JourneySeatsHost` | lobby: topic head, play-as-me row, party N/M with seat circles (host badge, dashed open seats), invite sheet (cover card, inviter, seats left, ShareLink when a token exists), invited list with withdraw confirm, mode tiles (≥2 seats), go-to-start; loading / missing / denied (buyer only) / error | n/a |
| `subpackageJourney/pages/promo/index` | `JourneyPromoView` / `JourneyPromoHost` | buckets pending / confirmed / marked paid / reversed (+ multi-currency), held orders, deals (attributed / paid / refunded, unknown as —), invite links, empty, auth (sign in), error | payout-off note; no withdraw button |
| `subpackageJourney/pages/report/index` | `App/JourneyReportViews.swift` `JourneyReportView` / `JourneyReportHost` + `JourneyMemoryTimeline` | eyebrow (date · topic), result pill, 3 stats (nodes / time / score or "not scored"), rank row -> board sheet, hint penalty, backpack, memory timeline sheet (day once per change, dots, photos), seats link, nodes list (skipped / answer viewed / not scored), finished: wrap-up + share, in progress: refresh; legacy title; loading / missing / auth / gone / denied / error | n/a |
| `subpackageJourney/pages/settle/index` | `JourneySettleView` / `JourneySettleHost` + `JourneyShareCard` | 4-step dots; overview (trophy glow + bounce, rise-in text, score count-up), board panel rising from below, rate (5 stars spring in order, chips, 500-char field with counter, needs-stars / needs-text / server errors, thanks modal), share (post / story card with foil, ShareLink + done); back steps within the flow; loading / missing / auth / gone / error / not finished | n/a |
| `subpackageJourney/components/rank-board` | `JourneyRankBoardView` | scope segmented (team / everyone) + "more" sheet (teams / city / country / world / club), laurel hero with numeric roll + top N%, team stats, period all / week, basis + window header, rows (top-3 lantern, mine highlighted), unattributed note; loading / refreshing / error / empty (team wording) | n/a |

Entry points:
- Account (Mine): new `MPParityAccountLinks` section after member benefits (`App/AccountView.swift`): passes and gifts, invites and earnings, video bounty. Each row appears only when its binding is injected.
- Passes -> reveal -> membership -> library, passes -> pass detail, gift -> passes(gifts), report -> settle / seats are wired inside the hosts via `MPParityRoute` + `.mpParityRouteDestination`.
- Deep links: `MPParityRoute(miniProgramPath:query:)` parses all 13 pages (incl. `landing?k=r|g|s&t=&aid=&tid=`, `reveal?mode=paid&count=&until=`); `MPParityDestination(route:)` presents them.

## Part 2: per-screen copy / state audit (from mp-mpaudit)

| mp page | native file | fixed now |
|---|---|---|
| `subpackageMember/orient-score` | `App/OrientScoreView.swift` | round id line, settlement number + "corrections after settlement change only the shown score" note, timeline "entry N · node N" line, "Refresh score" button, optional "Choose another round" hook (`onChooseAnother`) |
| `pages/team/detail` | `App/TeamOrientBoardView.swift` | team ranking now has loading skeleton, inline error + retry, and "no team ranking yet" empty (was silently hidden on failure / empty) |
| `subpackageRoam/nearby` | `App/RoamNearbyParityExtras.swift`, `App/NearbyTeamViews.swift`, `App/RoamItemDetailView.swift` | "Report team" on nearby team cards (non-leader; reuses `TeamReportSubmission` / `teamOrientBoardAccess`, hidden without it); official place extras panel: place play card, Xiaohongshu copy-name row, info rows, "what people say online" cited quotes (copy source link), player reviews + empty sentence, my review (stars + 200 chars, after completion, not yet reviewed), photo credit disclosure. "Only theme teams" filter already existed (`NearbyMapDiscoveryFilter.layer == .team`) |
| `pages/search2/result` | `App/GlobalSearchView.swift` | end-of-results "That's everything" + "Refresh results"; VoiceOver label "Clear search history" |
| `pages/member/index` (Passport) | `AccountView` / `PassportView` | 0 / 2 copy gaps; nothing to fix |
| `pages/search2/index` | `GlobalSearchView` | category failure + clear history were present (rephrased) |

Strings: 318 new EN + zh-Hans keys in `Resources/Localizable.xcstrings` (`mp.*`, `searchMap.endOfResults|refreshResults|clearHistory.a11y`), appended without reordering. Accessibility identifiers on every new control; no existing identifier changed.

## Still needs logic (Cursor)

Bindings (protocol stubs, all in `App/`; inject via `.environment(\.mpParity, MPParityBindings(...))` at the player root):
- `VideoBountyBinding`: `/api/video-bounty/submission/mine`, `/accrual/mine`, submit (reason codes -> sentences), appeal, cancel.
- `PassMarketBinding`: `/api/marketing/product/list|orders|gifts/bought|gifts/received`, `/api/platform-pass` (merchant -> nil member), `/api/user/info.point`. Optional `pointsDestination` (points history) is not wired.
- `PassDetailBinding`: product + quote (SELF / GIFT). Order, cash pay, unlock steps and gift token stay unbound (purchase gate OFF).
- `PassGiftClaimBinding`: claim with a stable request id (UI gate OFF until owners enable it).
- `PassMembershipBinding`, `PassLibraryBinding`: `/api/platform-pass`, `/api/platform-pass/library?productType=`, merchant role. `revealAccountKey` for the per-account "seen" flag.
- `JourneyLandingBinding`: Core `PWaveReader.referralLanding / giftLanding`, `playModes`; claim writes are `writesNotAvailable` in Core.
- `JourneySeatsBinding`: `PWaveReader.seats`, choices, `/api/user/info`; invite / cancel writes (Core throws `writesNotAvailable`), `inviteShareURL`, go-to-start route, edit profile route.
- `JourneyPromoBinding`: `PWaveP2AffiliateCenter`.
- `JourneyReportBinding` / `JourneySettleBinding`: `PWaveReader.battleReport`, P8 memory, P9 boards, choices (team tab), `/api/comment/add` rating, referral issue for `shareURL`, topic name fill, leave (back / ticket wallet).
- `RoamPlaceExtrasBinding` via `\.roamPlaceExtrasProvider`: official place facts (game, info rows, cited quotes, photo credit), place reviews read + publish.
- Router: map `CheinDeepLink` / universal links to `MPParityRoute(miniProgramPath:query:)`; open report from completed-play history; `OrientScoreView(onChooseAnother:)` session list.

Audit items not fixed (need logic or product decisions):
- `pages/activity/baoming`: waitlist states (queued / read failed / seat held / give up), pending-payment order notice, host booking, member-only signup, coupon switch, participant info picker. Payment flow; gate stays OFF.
- `pages/activity/official-organizer`: organizer identity check, publish-check failed / unread, pending-request recovery (check / retry with original input / abort unexecuted request + note), recent recovery notes, pause-reason form.
- `pages/team/detail` + `pages/team/join` + `subpackageRoam/my-teams`: join code + team QR / mini-program code block, applicants list (loading / unread / empty), remove-member labels, pending-request recovery trio, "buy a ticket for this session", join-by-code entry on my-teams.
- `subpackageRoam/session`: footprint card generating / cannot open / regenerate link / back to this roam.
- Orient score: session picker, pending-operation recovery card, manual review requests, recoveries list, session leaderboard, dispute deadline, pending-review count, appeal / dispute / sync / settle writes (not in `OrientScoreSummary`).
- Topic page gaps from mp-mpaudit (reviews compose, share, Beta note) were not in this brief.

Compile risks for the integrator: none known; watch `MPChipTabs` generic inference, `String(localized:locale:)` in `JourneySettleView.submit`, and the `TeamOrientBoardSection` ranking `do/catch` rethrow of `CancellationError`.

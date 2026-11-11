# Finish 1: Today card real data + backlog-1 real defects

Branch `ui/e1p` from `origin/rc/20261108` (`1b9db04ca`). Code-only: no xcodebuild, no simulators; the integrator compiles.

## (a) Explore Today card

- `SessionHomeFeedView` now loads `session.ticketWalletReader.ticketWallet()` (same configured + authenticated gate as the wallet, re-run on reader scope change) and passes `todayTicket` plus `onOpenTodayTicket` (opens `TicketWalletView` in a sheet) to `HomeFeedView`.
- `HomeTodayCandidate.nextTicket(from:now:)` (App/HomeFeedView.swift) picks the earliest ready/pending, openable ticket whose start is a real instant between 3 h ago and 24 h ahead. A start with no zone and no verified source zone parses to nil and is skipped: unknown time never wins, the card stays "start a roam". Signed out, unconfigured, read failure or cancellation => nil. No mock data; fixtures untouched.
- **Club event: not wired.** The club home read (`ClubHomeEvent`: id/title/cover/clubId) carries no start date, so "today" is unknown by construction; the topic-list calendar needs club-governance permissions. `todayClubEvent` stays nil, so the card falls through to "start a roam". Needs a backend/read field with a start date.

## (b) backlog-1 real defects

1. Ticket wallet notice strip restored: rows whose action is not `.detail` (cancelled, expired, unknown, payment-unavailable) show `Label(sourceNoticeKey)` in the stub (`ticketWallet.sourceNotice.<id>`), and the stub is shown for them. `test_w2_04_p2_member_tools` re-pinned to require it.
2. Growth leaderboard entry hidden unless its route exists: `GrowthCenterReading.offersLeaderboard` (default true; session reader = `GrowthCenterService.offersLeaderboard`, which is false when `ChinaReviewedRouteCapability.mark` is `.missing` or the host does not offer the route; scoped reader delegates). `GrowthCenterView` hides `growth.openLeaderboard` when false. The normal-growth (anonymous, `.missing`) composition therefore hides the entry; the legacy contract stays shown.
3. Disclosure copy restored to the packet text (catalog, packet copy, `docs/roam-experience-localizations.json`): `shopNPC.voiceDisclosure` (microphone permission, nothing sent automatically), `shopNPC.transmissionDisclosure` (voice can incur transcription and AI cost), `shopNPC.pauseNotice`, `shopNPC.retryNotice` (retry does not prove the earlier request was cancelled; the interruption fragment test pins these), `roam.experience.historyUnreadable` ("not replaced").

Not changed (copy-owner decisions): `playkit.pricePair.currentChoice`, `merchant.crmDate.unrecognized`, `discovery.templateDetail.publisher.platform` ('城瘾' in English).

## Verification

Contract modules green: test_w2_04_p2_member_tools, test_growth_source_contract, test_growth_route_modes, test_shop_npc_interruption, test_square_journey_chat_integration, test_roam_experience_contracts, plus the home/growth/ticket/roam family. Ratchet: 258 failing, baseline 259, new 0, fixed 1 (shop_npc_interruption; baseline line removed). Not verified: Swift compile, UI behaviour, ticket date parsing against live data. Still failing in the family and not touched here: test_growth_center_index_page_ready, test_growth_leaderboard_page_ready, test_roam_route_replay, test_category_roam_registration (not confirmed pre-existing; see ratchet).

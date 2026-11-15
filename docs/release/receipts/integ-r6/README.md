# ui/h-integ-r6 integration receipt (2026-11-15)

Base `origin/ui/h-r5-build` 52d2e8f10. Merged in order: `ui/h-premerge-tests` 081c50085, `ui/h-audit-bugs` 74cd384b6,
`ui/h-tests-ci-r5` 24bc3b297, the ready `ui/h-*` feature branches (sys-random, extgame-money, ingame-channels,
mp-delta-5, zip-ports and others, merged by the previous Gemini integrator), `ui/h-popups-merchant` 4fc187d6e,
`ui/h-live-activity-cloud` 5e3b033d1, `ui/h-city-numbers-attr-cloud` b8b1c324c, `ui/h-r6-ratchet-cloud` 44e0e293a (docs only).
No visual restyling was done here.

## Build

Xcode 27 `build-for-testing`, scheme `QuestifyAppUnitTests` (builds `Questify` + `QuestifyLiveActivity.appex`), Debug,
simulator Questify-iPhone17-Lane2, arm64 (`ONLY_ACTIVE_ARCH=YES`; the x86_64 slice fails on GLTFKit2's Swift header):
**TEST BUILD SUCCEEDED**. `check_scaffold.py` and `check_design_lint.py` pass.

## Unit tests (4 shards, same simulator)

| tree | tests | passed | failed |
|---|---:|---:|---:|
| `ui/main` a31949367 (baseline, same machine) | 7743 | 7612 | 131 |
| `ui/h-integ-r6` (this receipt) | 7848 | 7725 | 123 |

121 failures are the same tests that fail on `ui/main` (the iOS 27 hosted-accessibility family in
`docs/release/cb3-appunit-groups.md` and its neighbours). 10 tests that fail on `ui/main` pass here.
Still open, not on `ui/main`:
- `PremergeScreensViewModelTests.testAppSessionMemberPopupClosuresSignedOutAndSignedIn` (new in h-premerge-tests;
  the presence/club requests fail behind the composition gate; never passed).
- `RoamAlbumIntentLifetimeTests.testActualOriginalCardPushPreservesScopeAndBackRefreshesMetadataOnce` (hosted-AX class;
  a different method of the same class fails on each run).

## Core tests (`swift test`)

`ui/main` traps the runner in `PlayerJourneyTests` after 10430 tests (49 failed). On this branch the runner completes:
16920 tests, 16815 passed, 101 failed after the fixes below. Open regressions against the part of `ui/main` that ran:
`OPTTriageClosureTests.testSourceBaselineCitesOWNOPT001` (h-tests-ci-r5 regenerated `completeness-matrix.md` without its
"Sources read" section). The new `h-sys-ainpc` tests `JourneyNarrativeTests.testDialogueAction...` (request refused before
send) and `testShopNPCReply...` (relation/effects decode to nil) fail; the first used to trap the whole runner and is now guarded.

## Fixes on this branch

- City Monopoly merge: `MemberTitle.id`, `RoamTerritoryView` initializer, `CYHaptics.impactRigid` on `HapticsService`.
- `MerchantHomeView`: one access read per child return (root re-appearance and child `onDisappear` arrive in either order).
- Test pins/fixtures updated to merged behaviour (679 wired patterns, popup sheets, audit feed removal, token values,
  offline money gate, play wire keys, zip-ports 403 withdrawal, merchant payout chrome).

## TicketWallet and map

`TicketWalletView` keeps the h-tests-ci-r5 fix (reader outside the stack, load on activation). On the TEST backend the
wallet loads its ticket (08). The live roam map renders its map layer, not black (07).

## Screenshots (Lane2)

Fixtures (`--design-fixture`): 01-home (d2-home), 02-activity-detail (e1-activity-detail), 03-ticket-wallet (e4-tickets),
04-play (d6-play), 05-merchant-home (merchant-home). Real app on TEST 8120 (`--e2e-test-host`, player fixture):
06-test-backend-home, 07-test-backend-roam-live-map, 08-test-backend-ticket-wallet.

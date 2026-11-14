# ui-cur-popups-play

Popup parity for play, topic, activity, registration, journey, and roam. Base is `origin/ui/h-design-v1` at `5d652cc08ac5ccc668db315fc57253b909b9e058`, which already contains `origin/ui/main` at `5ba7b0f2`. `ui/main` was not merged again. `ui/h-design-v1` was not moved.

Mini-program source: public `liboyang42-cpu/hengyin` `master` (`5149d4f`), directory `chengyinhub-xcx`. Rows are `modal.show`, `cy-modal`, `cy-option-sheet`, `cy-scene-sheet`, `cy-sheet`, and `toast()` (the `wx.showToast` / `wx.showModal` fallbacks live only in the shared `utils/toast.js` and `utils/modal.js`, outside this area). `<cy-modal-host>` mounts are not popups and are not rows.

## CSV counts

`docs/parity/popups-play.csv` — 233 rows.

| Status | Count |
|---|---|
| DONE | 66 |
| MISSING | 165 |
| DIFFERENT | 2 |

## What changed

Confirms and the nearby range picker on screens that already exist now use `CYModal` or `CYOptionSheet`. zh-Hans is the mini-program string. English is the natural line. Destructive confirms stay destructive. Cancel leaves the action unsent.

- Roam finish: `PlayAreaRoamFinishModal` on `RoamLiveSessionView`.
- Help view and skip: `CYModal` on `PlayHelpLadderPanel`.
- New-activity abandon: `PlayAreaActivityAbandonModal` on `ActivityPublishingView`.
- Seat-invite cancel: `PlayAreaSeatCancelModal` on `JourneySeatsView`.
- Waitlist leave: `PlayAreaWaitlistQuitModal` on `RegistrationSheetView`.
- Team apply, withdraw, and decline: `PlayAreaTeamReviewModal` on `NearbyTeamsView`.
- Nearby range: `PlayAreaNearbyRangeSheet` (1 / 3 / 5 / 10 / 20 km).
- Non-refundable order and host cancel-and-refund: same components, shown only while `ReviewedAreaSwitch.moneyPayments` is open. On `www.chengyinhub.com` the switch is closed, the confirm is not shown, and a positive amount is an em dash. The non-refundable line is the current mini-program sentence: 该场次已开始，支付后不可退款。确认继续下单？

DEBUG fixtures, Release-excluded via `App/DesignFixtures/PlayAreaPopupFixtures.swift`: `play-popup-roam-finish`, `play-popup-abandon-activity`, `play-popup-seat-cancel`, `play-popup-host-cancel`, `play-popup-host-cancel-unknown`, `play-popup-host-cancel-closed`, `play-popup-nonrefundable`, `play-popup-waitlist-quit`, `play-popup-nearby-range`, `play-popup-team-apply`, `play-popup-team-withdraw`, `play-popup-team-reject`. The closed host-cancel fixture is an em dash.

## Still open

DIFFERENT:

- `subpackageRoam/nearby/index.js:636` asks for an optional note and 提交申请. `NearbyTeamAction.apply` does not carry a note, so the shared confirm is 申请 / 取消.
- `pages/publish/activity/index.js:928` also asks 放弃未保存的修改？ when editing. `ActivityPublishingView` only confirms a new draft.

MISSING rows name the gap in the native-screen or native-equivalent column. No page was invented. Registration pay-result and the 50% refund confirm stay off: the quote has no refund-percent field, and money confirms stay behind the closed switch. `RegionalLaunchConfiguration`, `AppSession`, `AppCompositionRoot`, `ReviewedAreaSwitch`, and the contract baseline were not edited. `OwnerDecisionFixtureHost` was not re-added.

## Gates

- `python3 tools/generate_project.py`
- `python3 tools/check_design_fixture_release_exclusion.py --write`, then the check without `--write`
- `python3 tools/check_scaffold.py`
- `python3 tools/check_design_lint.py`

`swiftc` was not run. This receipt does not claim a typecheck.

# ui/cur-merchant-mode

Functional only. No restyle, recolor, respacing, or layout change. Design hold stays in effect.

Base: `origin/ui/main` `5ba7b0f2c5f10dea10905895da947c350b3e24ac`.

## (a) Merchant accounts request merchant mode

`MerchantRootModeCoordinator` still stores `requestedMode` as `.consumer` until a request finishes. A signed-in account whose `api/userInfo` role is `merchant`, or whose `userType` is `2`, now asks for merchant mode once through `adoptSignedInAccount` → `requestMerchantMode`. `SessionRootView` runs that from `.task(id: MerchantModeBoot)`, keyed by account, session revision, role, and userType.

`requestMerchantMode` still calls `merchantAccess()`. `resolvedRoute` still returns `.merchantTabs` only when `requestedMode == .merchant` and the verified access is active, `merchantID > 0`, and has a role. A role string or `userType` only chooses the request. It is not admission. `I00SessionAdmissionBaselineTests` is unchanged.

`switchToConsumerMode()` records that choice for the current account and session revision. A later `adoptSignedInAccount` for the same identity does not call `merchantAccess()` again. `requestMerchantMode` clears the hold and verifies again. `handleSessionChange` drops the hold when the account or session identity changes, or when the session is signed out, and still resets a live merchant grant in those cases. It does not record a consumer choice of its own. `revalidateMerchantMode` still tears down a mismatched grant without recording a consumer choice.

`RootTabBarParity.initialRequestedMode(role:userType:)` is the request predicate. `resolvedMode` is unchanged and still fails closed unless a merchant container is already preferred.

Not edited: `App/AppSession.swift`, `App/AppCompositionRoot.swift`, `App/RegionalLaunchConfiguration.swift`. `ReviewedAreaSwitch` was not redeclared. `moneyPayments`, `payout`, `merchantWrites`, and `passwordLogin` were not opened for `https://www.chengyinhub.com`. `docs/release/contract-failing-baseline.txt` was not raised.

## (b) Club public activities

No separate `api/activity/list` read fills the club public-activities section. No second topics client was added. The section already uses `ClubPublicTopicsReader`.

Checked:

- `App/ClubDetailView` events tab opens `SessionClubPublicActivityListView`.
- `SessionClubPublicActivityListView.body` keeps a reader from `AppSession.makeClubPublicTopicsReader(clubID:)`.
- `ClubPublicActivityListView.refresh` → `ClubPublicActivityListModel.load` → `ClubPublicTopicsReader.read(clubID:isCurrent:)`.
- `ClubPublicTopicsReader.read` POSTs `api/club/topics` with JSON body `{"id": <clubID>}`. Club id `0` does not match and does not send. The same read then rechecks `api/club/detail` for the same viewer. That follow-up is not `api/activity/list` and was left as it is.
- `ClubDetailEventsSection` and `ClubEventCalendarView` read governance `.topics` (`api/club/topics`) for the member calendar. They do not call `api/activity/list`.
- App and Core club files have no `api/activity/list` call. `SearchMapService`, `PlayFinishRouteRecommendation`, `ProductionPlayFinishRouteReader`, the home feed, and merchant featured activity options were not changed. Those `api/activity/list` calls belong to other screens.

Request the public-activities section sends:

`POST api/club/topics` with JSON body `{"id": <clubID>}`

## Tests

- `Tests/CoreTests/HomeSearchTabParityTests.swift`: `initialRequestedMode` for merchant role, `userType` 2, and a player account. Core tests import `QuestifyCore`.
- `Tests/AppUnitTests/MerchantWorkbenchRemindersTests.swift`: a merchant role and a `userType` 2 account request merchant mode; a player stays consumer; `switchToConsumerMode` sticks until `requestMerchantMode`; an account or session-revision change requests again; inactive `merchantAccess()` leaves `resolvedRoute` on `.consumerTabs`.
- `Tests/CoreTests/ClubPublicTopicsCurrentContractTests.swift`: `ClubPublicTopicsReader.read` sends `POST api/club/topics` `{"id":41}` and does not send `api/activity/list`. Club id `0` sends nothing. `ClubPublicTopicsRoute` rejects an `api/activity/list` URL.

`python3 tools/check_scaffold.py` and `python3 tools/check_design_lint.py` were run. This VM has no `swiftc`, so the Swift tests were not executed.

## 中文

商家账号登录后会请求一次商家模式，仍然要等 `merchantAccess()` 成功且 `merchantID > 0` 才进入商家 tab。手动切回玩家会记住，直到再请求商家模式，或账号/会话身份变了。俱乐部公开活动这一段本来就走 `POST api/club/topics`，正文 `{"id": 俱乐部 id}`，没有改成别的接口，也没有用 `api/activity/list`。本机没有 Swift 编译器，测试没有实际跑过。

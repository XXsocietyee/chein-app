# pages/coop/invite-detail/index

CB260 page-ready evidence. Map status stays `exists` (`App/CooperationInviteDetailView.swift`). No view was edited. No route was marked live.

- Contract already in the repo: `CooperationService.detail` rereads `api/coop/list` and keeps one row from the requested direction. `CooperationInviteDetailPage.readPath` is that path. `routeMarkedLive` is false. `opensNewInviteSurface` is false. No invite composer was added.
- `CooperationInviteDetailPage` projects that read into loading, empty, error, unknown, and ready. Not found is empty. A bad id, a duplicate id, and a malformed payload are unknown. Cancellation stays loading.
- `CooperationInviteCountFact` keeps a literal JSON 0 as `0`. Null, a missing field, a numeric string, a bool, a fraction, a negative, and `UNKNOWN` display as an em dash (`—`, U+2014) and are not stored as 0. A game slot does not fall through to the topic slot. A ready row with no slot object withholds the count. The existing `occupancy(for:)` nil rule is unchanged.
- Terms stay the existing share / fixed / traffic / unknown presentation. No legal sentence was added. Deposit still does not default a missing amount to 50. Countdown is not invented for an unzoned `expireTime`.

## Missing keys

These source lines have no entry in `Resources/Localizable.xcstrings`. They were not added to a ui-strings file, and no English wording was written for them.

| Key | Source text |
|---|---|
| `cooperation.detail.state.loading` | 正在加载协作详情 |
| `cooperation.detail.state.missing` | 打不开这条邀约 |
| `cooperation.detail.state.invalidId` | 邀约编号无效，请从协作邀请列表重新进入 |
| `cooperation.detail.state.absentId` | 缺少邀约编号，请从协作邀请列表重新进入 |
| `cooperation.detail.state.identity` | 邀约标识无法确认，请刷新后重试 |
| `cooperation.detail.state.errorTitle` | 协作详情没加载出来 |
| `cooperation.detail.state.listFailed` | 协作邀请没加载出来 |
| `cooperation.detail.state.network` | 网络不稳定，请检查连接后重试 |
| `cooperation.detail.state.notFoundDetail` | 它可能已经被撤回，或移到了另一侧。回列表看看最新的。 |
| `cooperation.detail.state.backToList` | 回协作邀请 |
| `cooperation.detail.countdown.remaining` | 邀约剩 |
| `cooperation.detail.countdown.expired` | 邀约已过期 |

The page model uses existing catalog keys for the phases it can name: `cooperation.loading`, `cooperation.unavailable`, `cooperation.malformed`, `cooperation.ambiguous`, and `CooperationIssue.key`.

## Tests

- `Tests/CoreTests/CooperationInviteDetailPageTests.swift`
- `Tests/ContractChecks/test_coop_invite_detail_page_ready.py`

`xcodebuild` was not run.

## Left

- `App/CooperationInviteDetailView.swift` still draws `CooperationInvitePresentation` and shows a slot only when `occupancy` is non-nil, so an unknown count is hidden there instead of shown as `—`.
- The view does not read `CooperationInviteDetailPage`.
- Countdown, and the missing keys above, stay unwired.
- The current public `utils/coop-invite-view.js` has no supply-station confirmation block. None was added.

# pages/club/join-requests/index

俱乐部入会申请审核. Native screen `App/ClubManagementView.swift`. Map status stays `gated`. This note does not mark that row live.

The existing review contract is `api/club/join-requests`, `api/club/join-request/approve`, and `api/club/join-request/reject`. `api/club/join-requests/apply` stays hidden. No new route was added. `POST /api/club/detail` already returns `pendingJoinRequestCount` for an owner or admin. `ClubRecord` now keeps that integer. Absent, null, `UNKNOWN`, a numeric string, a bool, an object, and a non-integer stay nil. A literal JSON `0` stays `0`.

`ClubJoinRequestsPageReady` binds the screen as hidden, loading, empty, error, unknown, or ready. It stays hidden when the review capability is absent, the viewer cannot govern, the entry is player-first, or the server denies access. A shown unknown count is an em dash (`—`, U+2014), never `0`. The list empty state is still the existing empty copy. `introPendingCount(0)` is unchanged.

## Missing EN + zh-Hans keys

These Core titles are still raw Chinese. Neither language has a catalog key for this page. Catalogs were not edited.

| Literal | Source |
|---|---|
| 网络连接失败 | `ClubOpsNetworkFailureClassifier.networkFailureTitle` |
| 这次处理没有完成 | `ClubJoinRequestRowIssuePresentation.issueTitle` |
| 重新核对 | `ClubJoinRequestRowIssuePresentation.actionTitle` |

`club.management.*`, `clubOpsJoin.failed`, `clubOpsJoin.stale`, `clubOpsJoin.retry`, `clubOpsJoin.retryStale`, `clubOpsJoin.approving`, `clubOpsJoin.rejecting`, and `clubOpsJN.join.*` already have `en` and `zh-Hans`. `重新核对` on `workshopPaidInstalledText.retry` is a different surface.

## Left

The view was not changed, so those three titles are still not catalog keys on screen. The manage link is unchanged. `showsMerchantChoice` and the money switches were not set. No Xcode build was run.

# cloud-l5 IM and Square

Branch `ui/cloud-l5-im-square`. Base `ui/main` `72d2eb9ec498de21ded7cf9215f2638d7195786f`.
Source: `liboyang42-cpu/hengyin` `chengyinhub-xcx` `1c80c5aea8f721ca8575e6108048495b100f5576`.
Logic only. No screen was restyled. Money stays off (`CloudL5Money.enabled` is false; payment, wallet, withdrawal, order and IAP paths are refused, including the coupon-wallet card target).

Nothing here was compiled or executed. This environment has no Swift toolchain, so `Tests/CoreTests/CloudL5IMSquareTests.swift` was not run.

`python3 tools/check_scaffold.py` exited 0:

```
PASS structural checks: 4465 Swift source files, 14711 bilingual keys, references, scheme, read-only expected project equivalence
```

Catalog coverage, release config, privacy manifest, design lint, the AppSession ratchet, and the page route table also passed in that same run.

## IM

| Rule | Source | Native |
| --- | --- | --- |
| Receipt ledger stores only the client id. `begin` / `current` / `complete` / `pending` / `abandon` / `invalidate`. | `utils/im-send-recovery.js` | `Core/IMSendRecoveryLedger.swift` |
| Send states are sending and failed. A failed or lost send does not call `POST api/im/send` again. | `subpackageB/pages/im/chat/index.js` `_sendMessage` | `Core/IMSendReceiptMerge.swift` `IMSendTranscript` |
| Explicit retry reads `POST api/im/send-receipt` first. `found === true` merges and completes. `found === false` resends the same client id. Anything else holds. | `onResend`, `_readReceipt` | `IMSendTranscript.retry` / `recover` |
| Remount recovery only merges a found message. A miss does not send. | `recoverPending` | `IMSendTranscript.recover` |
| Automatic recovery and retry share one in-flight receipt read. A late callback does not clear the newer read. Unconfirmed copy is only for a retry waiter. | `_readReceipt` | `IMReceiptQueryShare` |
| Same client id and sender replaces the row. History prepend does not. | `_mergeMessages` | `IMMessageMerge` |
| Card types `generic` / `route` / `signup` / `location`. Missing type-3 `cardType` is generic. Route text that is not `[路线] …` is unavailable and is not fetched. Signup fetches only while the cache slot is unknown. | chat `decorate`, `fetchTopics` | `IMCardDecode`, `IMSystemCardTarget.routeCache` |
| System card targets: activity notice, generic action, button action. Coupon wallet is recognized and not opened. | `system-card-target.js` | `IMSystemCardTarget` |
| Refresh pill `正在刷新消息` only for a silent reload of an already loaded list. A failed silent reload keeps the rows and says `没刷新成功，显示的是之前的消息`. Identity change or denial clears. | `subpackageB/pages/im/list/index.js` `loadConversations` | `IMRefreshPill` |
| Report progress from `GET api/v1/community/notifications`. Non-array is unusable, not empty. Newest `REPORT_*` row per report. Read is `POST api/v1/community/notifications/{id}/read` with an id of at most 96 characters. | `report-notices.js` | `IMReportNotices` |
| Message report itself stays `api/im/report` on `IMSafetyAction`. This lane does not add a second report write. | chat `doReport` | unchanged |

## Square

Legacy `/api/creativesquare/*` and `/api/comment/*` operations are planned as `/api/v1/community/*`, including PATCH and DELETE. The older creative-square calls used by the legacy lane are unchanged.

| Rule | Source | Native |
| --- | --- | --- |
| Feed, bookmarks, own posts, detail, comments. Page 2 without a recorded cursor is stale. | `utils/community-post-api.js` `send` | `CommunityV1Wire.list` / `detail` / `comments` |
| Like and bookmark: POST `posts/{id}/actions`, DELETE `posts/{id}/actions/{LIKE\|BOOKMARK}`. Like type other than 1 is refused. Unknown post is "refresh". | same | `like` / `bookmark` |
| Delete post and delete comment are DELETE with `expectedVersion` and `requestId`. | same | `deletePost` / `deleteComment` |
| Comment like: POST or DELETE `comments/{id}/actions`. | same | `likeComment` |
| Action request id is kept until a 2xx or 4xx code for that same id. 5xx, 3xx and a lost response keep it. A later proposed id does not replace a live one. | `stableCommand` | `CommunityCommandLedger` |
| Create is POST `posts`. Edit is PATCH `posts/{id}`. Activity link is `ACTIVITY_RECAP`, route link is `ROUTE_DISCOVERY`, topic link stays `MOMENT`. Unknown `data_type` and closed attachments are refused. The wire key is not reminted here. | `utils/community-submit-progress.js` | `CommunityV1Wire.publish` |
| Draft list is GET `drafts`. Publish is POST `posts/{id}/publish`. Unknown create matches one `clientRequestId` only when `hasMore` is false. | same | `drafts`, `publishDraft`, `CommunityDraftMatch` |
| `viewerFollowing` true/false becomes 1/0. Other values stay absent. Activity may carry a positive topic projection. Display text decodes the five entities. | `normalizePost`, `display-text.js` | `CommunityPostProjection`, `CommunityDisplayText` |
| Forward card only for a public published post. Otherwise the generic feed card, with no picture. | `pages/square/utils/square-share.js` | `SquareShareCard` |
| Follow freezes 0 or 1 before `POST api/user/follow/action`. In flight does not start another write. Comment follow is only `follow: 1`. Failure does not invert the row. | square detail `followClick` | `SquareFollowWrite` |
| Draft sheet returns the captured key. A bad index does nothing. Delete is not a second confirmation. | `cy/post-drafts` | `SquareDraftSheet` |
| Completed-activity picker. No topic selects immediately. A topic preview finishes once. Close retires it. | `activity-picker` | `SquareActivityPicker` (`api/play/my-completed`) |
| Route map: verified geometry is a road; one bad road point drops that chapter to a straight preview. No distance or reward math. | `utils/topic-route-preview.js`, `route-map` | `SquareRouteMap` (`api/topic/info-to-user`) |
| A community row is not a club repost. No community repost write was added. | `utils/club-post-repost.js` | existing `ClubPostRepostToggle` |

## Tests

`Tests/CoreTests/CloudL5IMSquareTests.swift`. Not run.

## Not wired into screens

The new types are the logic. Existing legacy creative-square reads stay on the legacy lane. Call sites that should adopt the v1 planner:

- IM send failure UI: `IMSendTranscript.recover` / `retry` instead of posting `api/im/send` again.
- IM list refresh: `IMRefreshPill.begin(silent:loaded:identityChanged:)`.
- IM system tab: `IMReportNotices.rows` / `entry`.
- Square publish and post actions: `CommunityV1Wire` (PATCH, DELETE, stable request id).

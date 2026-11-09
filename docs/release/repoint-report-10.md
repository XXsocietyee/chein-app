# Re-point report RP-10 (chunk 10, 29 routes) — NOT COMPILED

Base: `origin/wip/gate-allowlist`. Backend source read: `chengyin` master checkout (commit 014fc0d8 is not present in the clone, so
line numbers are from the local master; verify against the deployed commit). Controller dir: `chengyinhub-admin/src/main/java/com/chengyinhub/web/controller/api/` (abbrev `C/`); mini-program `chengyinhub-xcx/` (abbrev `XCX/`).
New files: `Core/RePoint10Routes.swift`, `Tests/CoreTests/RePoint10RoutesTests.swift` (fixtures SYNTHETIC). No existing file edited. No gate opened.

**Totals: REPOINTED 3 · TRUE-GAP 25 · NEEDS-OWNER 1**

| iOS route | production equivalent | evidence | status | new files |
|---|---|---|---|---|
| /api/topic/detail | POST `/api/topic/info-to-user`, form `id`, resp `AjaxResult{data:TopicInfoVO}` | C/ApiTopicController.java:1427-1720; XCX/pages/club/topic-detail/index.js:305-311 (form header) | REPOINTED | RePoint10Routes.swift (+Tests) |
| /api/ugc/block | POST `/api/im/block`, form `target_member_id`, resp `AjaxResult{msg}` | C/ApiImController.java:197; XCX/subpackageB/pages/im/chat/index.js:585 | REPOINTED | same |
| /api/user/sms/send | POST `/api/sms/send`, form `phone`, anonymous | C/ApiLoginController.java:513; XCX/utils/deregister-flow.js:138 | REPOINTED (stays on high-risk deny-list; builder only) | same |
| /api/us/auth/apple/exchange | CN `POST /api/login/apple` form `identityToken` only (no challenge/nonce, different response) | C/ApiLoginController.java:757; no XCX use | NEEDS-OWNER (is CN Apple login acceptable for US flow?) | — |
| /api/us/auth/apple/challenges | none; closest undeployed `cloud/be-g30` | grep of C/ | TRUE-GAP | — |
| /api/us/auth/session | none; `cloud/be-g30` | — | TRUE-GAP | — |
| /api/topic/edit-requests/{submit,read,resume-post-processing} | none (production has `/api/topic/create,update,v2/*`, `edit-detail`; no request-ledger). `cloud/be-g30` / `be-g18` | C/ApiTopicController.java mapping list; XCX none | TRUE-GAP ×3 | — |
| /api/topic/module-preflight | none; closest `cloud/be-g47` | — | TRUE-GAP | — |
| /api/user/follow-list | none (only `/api/user/follow/action` C/ApiUmsMemberController.java:881; counts in `/api/user/public-info`); `cloud/be-g32` | XCX only uses follow/action | TRUE-GAP | — |
| /api/welcome-screen/get | none; `cloud/be-g36` | — | TRUE-GAP | — |
| /api/workshop/** (17 routes: creator/pending-packages, creator/public-theme-use, owned, owned/detail, owned/list, owned/package, purchased, purchased/detail, purchased/install, purchased/installed-text/detail, purchased/list, purchased/professional-operations/{cancel,history,status,submit}, purchased/professional-targets/{detail,list}) | none; no workshop in XCX or any controller; closest `cloud/be-g11` (owned/creator only; purchased/professional have no branch identified) | grep of C/ and XCX/ | TRUE-GAP ×17 | — |

Notes: `/api/topic/detail` also appears as a display string in `App/PublishTopicAndCommentModerationSectionView.swift:78`; the live
detail readers already call `api/topic/info-to-user` (`Core/SignedInContentDetailRead.swift:16`). `be-g27` aliases topic/detail but is not deployed.
Limits: Jackson output and the 014fc0d8 line numbers were not verified; nothing compiled or run.

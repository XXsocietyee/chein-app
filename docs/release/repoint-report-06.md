# Re-point report 06 (NOT COMPILED)

Backend read: `chengyin` master 5e23cd52. **Commit 014fc0d8 is not in that checkout** (`git cat-file` fails), so "production" = this tree; owner should confirm it matches 014fc0d8. Mini-program: `chengyinhub-xcx`. Controllers: `chengyinhub-admin/src/main/java/com/chengyinhub/web/controller/api/`. Grep of all Java/JS for the iOS-only strings (`read-state`, `route-share`, `im/search`, `unpin`, `im/video`, `im/voice`, `im/webhook`, `location-share`, `public-layers`, `merchant/authoring`, `draft-selection`) found no route or caller. `ApiImController` serves only conversations, messages, send, read, delete, mute, unread-total, start, block, unblock, report.

CC = `ApiClubController.java`. Evidence column lists controller / mini-program lines.

| iOS route | production equivalent | evidence | status | new files |
|---|---|---|---|---|
| /api/join-request/submit | POST `/api/club/join`, JSON `{id, joinMessage}` -> `{state: pending|joined}`. Club kind only; no invite id, no request_id | CC:719-738; xcx pages/club/detail/index.js:2246 | REPOINTED (club kind only; others refused) | Core/RePoint06ClubJoin.swift, Tests/CoreTests/RePoint06ClubJoinTests.swift |
| /api/join-request/approve | POST `/api/club/join-request/approve`, JSON `{clubId, memberId}`; no remark | CC:842-846, 850+; xcx pages/club/join-requests/index.js:170 | REPOINTED (needs clubId+memberId, not application id; note refused) | same |
| /api/join-request/reject | POST `/api/club/join-request/reject`, JSON `{clubId, memberId}`; no reason code/note | CC:848; same xcx | REPOINTED (reason/note refused) | same |
| /api/join-request/cancel | none (applicant cancel absent) | grep CC, xcx | TRUE-GAP | - |
| /api/invite/revoke | only `POST /api/merchant/operators/invite/revoke` (merchant operator invite, different feature) | ApiMerchantOperatorController.java:188; xcx pages/merchant/team/index.js:643 | NEEDS-OWNER (not the same domain; do not map) | - |
| /api/im/roles | `POST /api/club/roles/list` `{clubId, activityId}` -> `{roles, assignments}`; club-scoped, not channel roles | ApiClubRoleController.java:106 | NEEDS-OWNER | - |
| /api/im/roles/{}/members | `POST /api/club/roles/assign` / `/roles/revoke` (club-scoped) | ApiClubRoleController.java:125,143 | NEEDS-OWNER | - |
| /api/im/read-state | `POST /api/im/read` (form `conversation_id`) marks read; no read-state query | ApiImController.java:111 | NEEDS-OWNER (set-only, no get) | - |
| /api/im/unread-summary | `POST /api/im/unread-total` returns a total only, no per-channel summary | ApiImController.java:160 | NEEDS-OWNER (total only) | - |
| /api/im/route-share-source | none | grep | TRUE-GAP | - |
| /api/im/search | none | grep | TRUE-GAP | - |
| /api/im/unpin | none (no pin route either) | grep | TRUE-GAP | - |
| /api/im/video/{message, message/{}/authorization, message/{}/preview, policy, receipt, upload} (6) | none | grep | TRUE-GAP | - |
| /api/im/voice/{message, message/{}, message/{}/authorization, receipt, upload} (5) | none (only AI-NPC `/voice-chat`, unrelated, ApiAiNpcController.java:270) | grep | TRUE-GAP | - |
| /api/im/webhook, /api/im/webhook/context | none (webhooks out of release scope) | grep | TRUE-GAP | - |
| /api/location-share/personal | none | grep | TRUE-GAP | - |
| /api/map/public-layers | `POST /api/map/nearby` is centre+radius (form `longitude, latitude, radius, limit`), no bbox/layers/cursor | ApiMapController.java:52; xcx pages/roam/index.js:329 | NEEDS-OWNER (different query model, merchant nodes only) | - |
| /api/merchant/authoring/{draft-selection/list, draft-selection/resolve, drafts, drafts/{}, environment, jobs, jobs/cancel} (7) | none | grep | TRUE-GAP | - |

No `cloud/be-gNN` branch was checked for these (not deployed anyway). iOS one-line switches to existing Core files: none.

Counts: REPOINTED 3, NEEDS-OWNER 6, TRUE-GAP 28 (37 routes; video 6 + voice 5 + webhook 2 counted individually).

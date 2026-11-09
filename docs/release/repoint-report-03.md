# Re-point report 03 (chunk-03.tsv, 34 routes) — NOT COMPILED

Method: grep of `chengyin` (checkout HEAD 5e23cd52; commit 014fc0d8 is NOT in this shallow clone, so "production = 014fc0d8" could not be diffed — controller evidence is from HEAD), `chengyinhub-xcx/**` for `url:`/path strings, and `ApiClub*Controller` mappings. Closest `cloud/be-gNN` branches were not inspected (not deployed anyway). Mini-program evidence for TRUE-GAP rows is absence-by-grep.

C = chengyinhub-admin/src/main/java/com/chengyinhub/web/controller/api, X = chengyinhub-xcx

| iOS route | production equivalent | evidence | status | new files |
|---|---|---|---|---|
| /api/club/settlements | POST /api/club/settlement/summary, JSON `{clubId}`; resp `data{settledAmountText,settledAmountStatus,unverifiedSettledCount,isOwner,topics[]}` | C/ApiClubSettlementController.java:70; X/pages/club/settlement/index.js:107 | REPOINTED (read only) | Core/RePoint03ClubSettlement.swift, Tests/CoreTests/RePoint03ClubSettlementTests.swift |
| /api/club/settlements/export | none | no controller/mini-program match | TRUE-GAP | - |
| /api/club/update | POST /api/club/update-mine, JSON body (Club entity, `id` selects club) | C/ApiClubController.java:457; X/components/cy/scene-club-edit/index.js:255 | REPOINTED | Core/RePoint03ClubUpdate.swift, Tests/CoreTests/RePoint03ClubUpdateTests.swift |
| /api/club/workbench | mini-program workbench is a redirect shell to club detail manage tab, i.e. `/api/club/detail` (already in iOS `backendEndpoints`) | X/pages/club/workbench/index.js (redirect, per scripts/shot-matrix.js:502); C/ApiClubController.java:572 | NEEDS-OWNER (no new route needed; owner to drop the native-only entry) | - |
| /api/club/join-requests/apply | `/api/club/join` (already listed) and `/api/club/apply`; semantics of "apply to join with approval" vs. production join not verifiable here | C/ApiClubController.java:719,414 | NEEDS-OWNER | - |
| /api/club/group-code, /save | none. Mini-program `group-code` page is the 团核销码 (`/api/verify/groupcode/issue`), a different feature from iOS 入群码 config | C/ApiVerifyController.java:249; X/pages/club/group-code/index.js:100 | NEEDS-OWNER (x2) | - |
| /api/community-trust/reports/submit | Same path IS served at HEAD: POST JSON `{targetType,targetId,reasonCode,policyVersion,description,evidenceAssetIds,requestId}`. Not present in the claimed TSV premise; unverified at 014fc0d8. iOS site is only a string default in a view, no client | C/ApiCommunityTrustController.java:36; system/.../CommunityReportSubmitRequest.java | NEEDS-OWNER | - |
| /api/club/events, /Checkin, /save, /proxy-enroll | none (event-ops are series/waitlist routes, different shape) | C/ApiClubEventOpsController.java | TRUE-GAP (x4) | - |
| /api/club/notices, /notices/send | none (only `event-notification/*`, different contract) | C/ApiClubEventNotificationController.java | TRUE-GAP (x2) | - |
| /api/club/open-settings/welcome-note-receipt | none; M-08 receipt half missing | doc-5 M-08 | TRUE-GAP | - |
| /api/club/post/operation, /comment, /receipt | none (production has post/create, update, comment/create without operation/receipt protocol) | C/ApiClubController.java:1722,1783,1841 | TRUE-GAP (x3) | - |
| /api/club/roles/assign-receipt, /revoke-receipt | none (assign/revoke exist, receipt reads do not) | C/ApiClubRoleController.java:125,143 | TRUE-GAP (x2) | - |
| /api/club/settings/notify-level | none | no match | TRUE-GAP | - |
| /api/common/uploadOSS/receipt | none (uploadOSS exists, no receipt) | C/ApiCommonController.java:102 | TRUE-GAP | - |
| /api/compliance/usage-records | none (only consents, consents/latest) | C/ApiComplianceController.java:60,107 | TRUE-GAP | - |
| /api/coupon/command-receipt | none | C/ApiCouponController.java (no such mapping) | TRUE-GAP | - |
| /api/free-explore/bundle/transfer, /voucher/appeal | none (iOS comment: EP-BND-24 not in backend) | App/BundleTransferTransport.swift:7 | TRUE-GAP (x2) | - |
| /api/friend, accept, cancel, channel-invite, directory, directory/detail, group/delete, group/list | none; no friend controller, no mini-program friend API (only unrelated `friendNum` strings) | grep | TRUE-GAP (x8) | - |

## Notes
- Adapters use their own wire structs and map into `ClubSettlementDetailRecord` / `ClubOperationsDraft`; no existing file was edited. Wiring into the gated transports is left to the owner (no one-line switch added).
- Unverified totals map to `nil` (UNKNOWN), never 0. `/api/club/settlement/withdraw` (money movement) deliberately not adapted.
- Tests are SYNTHETIC and uncompiled.

Counts: REPOINTED 2 · TRUE-GAP 27 · NEEDS-OWNER 5 (total 34)

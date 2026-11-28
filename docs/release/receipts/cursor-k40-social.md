# cursor-k40-social receipt

Lane: square, social, and IM. Branch `cursor/1128-k40-social`. The feature commit `e5f002095` is from `origin/ui/combined-r7` @ `a7c956335`. Before push the tip had moved to `543d9033b`, and that tip was merged in. PR base `ui/combined-r7`. No restyle. Merchant stays off the player-write grant. Money switches were not touched. `App/AppSession.swift` stays at 7977 lines. Play-config init order stays devices, sensors, artworkHosts.

Audits read: `origin/design/handoff-r2:docs/briefs/round3-1127.md`, `origin/audit/1128-plan:docs/audits/1128-plan.md` (social domain M-01…M-17), `origin/audit/1128-functions:docs/audits/1128-functions.md` (IM table and P1-7 / P1-28 / P2-6), `origin/audit/1128-ada:docs/audits/1128-ada.md` (d2-inbox, d2-square).

There is no Swift compiler in this environment. Nothing was built, and no live backend was called. Gates that ran: `contract_ratchet.py --check` (46 failing, baseline 46, new 0), `check_scaffold.py`, `check_appsession_ratchet.py`, `check_a11y_lint.py` (0 new), `check_design_consistency.py`. No `String(localized:)` was added. No secrets, no deploy, no SQL.

Player path under test is `RegionalLaunchConfiguration.reviewedDeployment` (China). `MPFirstSocialApprovalsTests` builds that composition. A literal US `reviewedDeployment` still issues no player writer.

Counts below cover the social-domain rows the plan did not already mark Done, plus function-audit P2-6 and the two ADA screens. **n = 3** closed here, **m = 14** already fixed, **k = 19** still open or skipped. Eleven rows the plan already marked Done (M-01a, M-06, M-07a, M-08b, M-08d, M-09b, M-11c, M-16, M-17a, M-17b, M-17e) were re-read and left as they are.

## Closed in this commit (n = 3)

| Row | What changed |
|---|---|
| M-01d | Player tabs inject `SquarePlayerDeletionHost.coordinator`. The approval is the two route templates `api/v1/community/posts/{id}` and `api/v1/community/posts/{postId}/comments/{id}`, and only when `MPFirstSocialApprovals.community` is non-nil (China player or club). Merchant, US, and signed-out get `.disabled()`, so `isAllowed` stays false and the v1 删除 row stays hidden. Transport already admits DELETE when the body has `requestId`. |
| M-11a | `squareGovernance()` rebuilds through `SquareGovernanceSessionBox` when the viewer or the grant changes. Reads, appeal, mark-read, and preferences are on with the community writer. Comment approve and own-comment delete stay off; those buttons render only when `service.allows` is true, so the release screen does not show them. The offline fixture still grants every capability, so the governance UI tests keep their buttons. |
| M-04b / P1-7 | App routes MEMBER, ACTIVITY, CLUB, MERCHANT, and SAFETY_RATING to `POST api/community-trust/reports/submit`. CONTENT and COMMENT stay on `POST api/v1/community/reports`. The submit path is in `reportPaths`, so the composition transport admits it (this also admits the IM 举报对方 submit, which already posted there). A 404 keeps the server message. The Java `report()` change could not be pushed; the full diff is below. |

Tests: `MPFirstSocialApprovalsTests.testReleaseCompositionIssuesSquareDeletionAndGovernanceForPlayersAndClubs`, `testCompositionTransportAdmitsDeletionGovernanceAndTrustReports`. `UGCContentSafetyServiceTests` expects the new routes. `test_w2_07_square_parity` now requires the player host instead of a dormant environment.

## Already fixed on the pin (m = 14)

| Row | SHA |
|---|---|
| M-01b like / bookmark | `535af06ec` |
| M-01c comment / reply / comment-like | `535af06ec` |
| M-02a composer | `535af06ec` |
| M-02b server drafts (`loadServer` when `grants.live`). The ~70% detent is a restyle and was not done. | `535af06ec` |
| M-02c images | `535af06ec` |
| M-03b reply write (the entry existed; the write was M-01c) | `535af06ec` |
| M-04a post / comment report, plus the client 已举报 lock | `535af06ec` |
| M-05 审核中 label is reachable once a player can publish; the feed reloads after publish | `535af06ec` |
| M-09a / P1-28 IM image send (`imRoutes[.imUpload]`, `imImageSelection: socialRole`) | `f85a43975` |
| M-13b like / bookmark send at once | `535af06ec` |
| M-14b IM list `.refreshable` → `prepareRefresh` | `e66571d1b` |
| M-17c profile 关注 | `56a76d956` |
| M-17d profile 私信 | `56a76d956` |
| P2-6 inbox no longer asks for a raw member id | `97ed47b2a` |

## Still open or skipped (k = 19)

| Row | Why it is still open |
|---|---|
| M-01e, M-12a, M-12b | Share and universal links need the owner domains (P1-1). Not this lane. |
| M-12c | Notification tap is local only until remote push exists. |
| M-03a, M-03c, M-08c, M-13a, M-13c, M-14a | Restyle (send icon, skeleton, inline cards, shared result sheet, haptics). Not done. |
| M-04c | Trust de-dup is still `(reporter, requestId)` only. A per-target open-report guard needs a mapper query. No SQL was written or run. The client 已举报 lock is already in `535af06ec`. |
| M-07b | No conversation-pin route and no MP pin. |
| M-08a | MP folds system into Direct. No third tab added. |
| M-09c | MP DMs have no polls. The channel poll host stays unavailable. |
| M-10 | Hangout join is the roam lane. |
| M-11b | Remote push needs the owner APNs keys (P1-9). |
| M-15 | 写评价 is the activity lane. |
| d2-inbox, d2-square | ADA visual (preview line, badges, shared PostRow, avatars). Not done. |

Function-audit IM rows 278–299 that the audit already marked Works were re-read against the pin and left alone. Rows 107 and 122 are M-04b. Row 293 is M-09a. Row 285 is P2-6. Row 300 (我的举报 unread) is M-11a.

## Backend: hengyin was not reachable

`git clone` and `gh repo clone` of `XXsocietyee/hengyin` both returned repository-not-found for this VM's git credentials. The file was read through the GitHub API at `us/r3-functional`. No branch `cursor/1128-be-k40-social` was pushed, and there is no backend SHA.

`CommunityPostServiceImpl.report` (lines 958–982) still looks up a post for every non-COMMENT target, so MEMBER / ACTIVITY / CLUB / MERCHANT / SAFETY_RATING return 404 `帖文不存在或不可见`. `CommunityTrustServiceImpl.submitReport` already accepts those types on `POST api/community-trust/reports/submit`. The iOS player now calls that route. Other clients that still POST `api/v1/community/reports` for those types keep 404 until this method is replaced.

Full diff, file `chengyinhub-system/src/main/java/com/chengyinhub/business/service/impl/CommunityPostServiceImpl.java`:

```diff
--- a/chengyinhub-system/src/main/java/com/chengyinhub/business/service/impl/CommunityPostServiceImpl.java
+++ b/chengyinhub-system/src/main/java/com/chengyinhub/business/service/impl/CommunityPostServiceImpl.java
@@ -971,12 +971,16 @@ public class CommunityPostServiceImpl implements CommunityPostService {
             }
             if (memberId.equals(number(value(comment, "author_id")))) throw error("不能举报自己的评论", 400);
             request.setTargetType("COMMENT");
+        } else if (!"CONTENT".equals(targetType)) {
+            // K40 P1-7 / M-04b: MEMBER, ACTIVITY, CLUB, MERCHANT, SAFETY_RATING are not posts.
+            // The post lookup below returns 404 "帖文不存在或不可见". Return the trust case instead.
+            return CommunityReportVO.from(communityTrustService.submitReport(memberId, request));
         } else {
             // S532-1:看得到的 LIMITED 帖也必须能举报,口径与 detail 一致(互动/评论/分享仍按既有 selectById,待 owner 定)。
-            CommunityPost post = "CONTENT".equals(targetType) ? readableById(request.getTargetId(), memberId) : null;
+            CommunityPost post = readableById(request.getTargetId(), memberId);
             if (post == null) throw error("帖文不存在或不可见", 404);
             if (memberId.equals(post.getAuthorId())) throw error("不能举报自己的帖文", 400);
             request.setTargetType("CONTENT");
         }
         return CommunityReportVO.from(communityTrustService.submitReport(memberId, request));
     }
```

COMMENT and CONTENT behaviour is unchanged, including the S532-1 LIMITED-post read. Unknown types then get the trust service's 400 `举报对象不合法` instead of a post 404. No schema change and no SQL.

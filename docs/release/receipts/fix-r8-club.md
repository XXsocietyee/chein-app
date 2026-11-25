# Receipt: fix-r8-club (2026-11-25)

Branch `fix/r8-club`, based on `origin/ui/combined-r7` (merged again before every push). It carries two worktree
branches merged in: `fix/r8-club-a-topic` (topic-detail, topic-story and event-ops) and `fix/r8-club-b-ops` (ops forms
and pages). Queue: `origin/audit/parity-r8-club:docs/audit/parity-r8/club.md` §3, rows owned by Claude App.

Nothing here was compiled; this environment has no compiler. Every type and initializer used was grepped on the
tree first. `tools/check_missing_string_keys.py` reports missing 0 and incomplete_locales 0.
`tools/generate_project.py` adds only the four new App files.
Strings fragments: `docs/port/strings/fix-r8-club.json`, `fix-r8-club-a.json`, `fix-r8-club-b.json`. Every key is
also in `Resources/*.xcstrings`, in en and zh-Hans.

## Closed / partial / open
### Club page (main thread)

| id | sev | status | where |
|---|---|---|---|
| CLB-detail-09 (+E11-E13) | P0 | closed | `ClubGapManagedProjectsDirectorSection` on 管理 via `ClubManagedProjectsMount` (App/ClubDetailR8Mounts.swift); topics from `api/club/topics`, sessions from each topic's `info-to-user` `activityList` (self-host shell dropped, 「名称 · M月D日 HH:mm」); 活动导演台 (owner/admin + `gameModuleEnabled`) opens topic-detail with `activityId`; mount at App/ClubDetailView.swift (manage tab, after ClubWorkbenchSection) |
| CLB-r7-A-04 | P2 | closed | same mount: 场次工具 → 现场名册与核销 (ClubOpsEventView) / 分配领队与核销员 (roles + activityLabel) / 通知本场成员 (notify composer) |
| CLB-G04 | P0 | partial | `ClubGapCoopPoolSection` on 管理 for the owner, read from `CooperationReading.pool()`; 我的合作 / 查看申请 → pool applications (`CoopFlowReadView .applications`). 申请带队 hidden: the app's pool application ends at a request preview (no submit) → for Cursor |
| CLB-G01 | P0 | closed | 邀约承接 (`ClubGapActivityAndScanActions`) under each 活动 card for a merchant viewer → `MerchantContentDocumentView(.project(topicID:))` (MP merchantinfo?topicId=&scope=MERCHANT); App/ClubPublicActivityListView.swift `undertake` |
| CLB-G06 | P1 | closed | gear (owner) in the toolbar → `ClubGapSettingsSheet` |
| CLB-G19 | P1 | closed | 改为转让主理人 → 成员治理 (governance `.members`); 解散 / 编辑 → club workspace |
| CLB-r7-A-06 | P2 | partial | 客户与项目 rows (查看客户 · 报名名册 · 活动运营 · 角色与权限) via `ClubGapSettingsSheet.clubTools(...)`; counts (customerCountText, topicCount, delegatedRoleCount) not shown |
| CLB-G08 | P1 | closed | `ClubGapMemberAvatarStrip` above 查看全部成员 (first 4 from `clubMembers`, +N), opens the members sheet |
| CLB-detail-22 | P1 | closed | 本团贡献榜 inline: MP `foldLeaderboard` (top 3 · ⋯ 中间 N 人 · rows around 我), 综合/里程/完成用时 sort menu, 你/我 chip, per-sort empty copy, 榜单加载失败 + 重试 (`ClubInlineLeaderboardModel`/`Rows`) |
| CLB-detail-20 | P2 | closed | empty 活动 state offers 发布主题 to owner / `club:activity:manage` |
| CLB-detail-37 | P2 | closed | header meta on `.bodyCompact` (MP 16 pt) |
| CLB-r7-A-07 | P2 | closed | member ⋯ menu offers 临时封禁 only to the owner (`ClubMemberAction.menu(canTempBan:)`, unit test added). Co-owner with `club:member:manage` is not distinguished in the members sheet (no access/me there) |
| CLB-topic-story-06 (copy), CLB-governance-05, CLB-edit-09, CLB-notify-10, CLB-r8-checkin-detail-01 | P1/P2 | closed (copy) | fix-r3-club-a/b fragment overrides applied to Resources/Localizable.xcstrings + the per-feature *.fragment.json sources; `tools/build_club_governance_catalog.py` and the two UITests that tapped 离开表单 / Leave form updated |
| CLB-G02 | P0 | open | needs a club-scoped verify workflow (Cursor); the `ClubGapActivityAndScanActions` scan button is ready, `scan=1` not acted on |
| CLB-G05 | P0 | open | `ClubCommunityOperation.create` has no refType/refId, and no `my-joined` options source for the composer → for Cursor |
| CLB-G10 | P0 | open | `ClubCommunityPost` does not decode `isFollowTheUser`, so the pill cannot know when to show → for Cursor (write can reuse `SocialActionCoordinator .toggleFollow`) |
| CLB-detail-14 | P1 | deferred | inlining the feed means turning `ClubCommunityFeedView` (ScrollView/LazyVStack with its own sheets and toolbar) into List sections inside ClubDetailView; not safe without a compiler pass |
| CLB-detail-35, CLB-detail-34, CLB-detail-11, CLB-payout-receiver-01 | — | owner decision | not taken |
| CLB-G13 | P0 | closed (needs a device check) | `ClubTopicDirectorEmbeddedMount` (App/ClubTopicDirectorMount.swift), mounted in ClubGovernanceViews topic detail when `activityId` is present and `canDirect`; it reads `PlayDirectorCoordinator`. The host is injected from 活动导演台 (ClubDetailR8Destination) and from the MP `topic-detail?activityId` link (MPReviewedPageScreen) |

### Topic-detail, story, event-ops (`fix/r8-club-a-topic`)

| id | sev | status | notes |
|---|---|---|---|
| CLB-G12 | P1 | closed | 更多 menu (编辑主题内容 / 确认终价 / 承接审核). 确认终价 is gated on `canDirect`; the pricing page re-checks |
| CLB-topic-detail-05 | P1 | partial | four round actions that open sheets. 台账 in the 核销 header is not done (ClubTopicDetail+Port.swift) |
| CLB-topic-detail-08 residual, CLB-r8-topic-detail-01, -02 | P2 | closed | chips; 主题 card; eta line (no kind chip: the server sends no kind) |
| CLB-topic-detail-10 | P1 | partial | customer rows with avatar, phone, 拨号 and status chip; 定向广播 is reachable only through the director tools |
| CLB-topic-story-04 | P1 | partial | `ClubGapStoryMapAddressRow` mounted; opening Maps needs coordinates (Cursor) |
| CLB-topic-story-06 / -08 / -09 | P1/P2 | closed | 第一章 numerals, one-line meta, compact stop cards, image play card with a scrim |
| CLB-G15 | P1 | partial | 主持小费 · 暂不可开通 row; paymentNotice / windowWarning need Core feeds |
| CLB-event-ops-02 | P1 | partial | cancel status and 本场名册 · N 人 inline; member rows are still on the pushed page |
| CLB-customers-07 | P2 | closed | filter chip row |
| CLB-notify-01 | P1 | closed | in-app workspace and session 通知 entries open the one composer |
| CLB-group-code-04 | P2 | partial | the topic-detail 出示团码 sheet carries the session label; the deep link's `activityName` is not done |
| CLB-topic-detail-06, CLB-customer-detail-04 | P1 | open | inline auto-save would bypass the command-form review and confirm step (pinned by test_club_topic_settings_return); needs an embeddable form or an inline-save API |
| CLB-governance-01, CLB-apply-11, CLB-topic-story-05, CLB-r7-C-03 | P1/P2 | open | governance-01 overlaps in-flight G16; apply-11 needs leaderName on the host status or the receipt; story-05 has no executor for `ClubNodeAnswerCall` (Cursor); C-03 not taken |
| CLB-event-ops-09 | P2 | open | needs a visual check |

### Ops forms and pages (`fix/r8-club-b-ops`)

| id | sev | status | notes |
|---|---|---|---|
| CLB-G17 / settlement-02, CLB-r7-D-01 | P0/P1 | partial | `ClubFEReferenceSettlementHost` with range and export, mounted on the club and personal settlement. 标记已结清 is behind `ClubFEReferenceMoneyWriteGate.allowsSettle = false` (TEST-only). Reads run in the payout area (DEBUG/TEST only). Real data hits the error state until Cursor fixes the list decode (see below) |
| CLB-settlement-04 | P1 | closed | personal topic rows → `CoopClubSettlementScreen` |
| CLB-governance-03, CLB-roles-04 | P1 | closed | direct submit for ban/unban/transfer/report/appeal/assign; 分配 names the missing field |
| CLB-r8-apply-01, CLB-r8-create-01 | P1 | closed | inline 提交没有完成 / 创建没有完成 + 重试 |
| CLB-edit-01, -05, -03 | P1/P2 | closed | pinned 保存修改, direct save, 保存失败 + 重新保存 / 继续编辑; legacy 设为管理员 removed (UITest replaced) |
| CLB-r8-group-code-01, -02 | P2 | closed | 生成中 card; 出码失败 + 重试 |
| CLB-r8-badges-01, -02, CLB-r8-governance-01, CLB-r8-roles-01 | P2 | closed | 链接已失效 + 返回; 勋章没有创建成功 |
| CLB-r8-join-requests-01, CLB-join-requests-06 | P2 | closed | per-row failure + 重试; 刷新 hidden on the requests-only page |
| CLB-notify-04 | P1 | closed | 网络连接失败 / 通知工具暂时不可用 |
| CLB-enroll-02, CLB-r8-enroll-01 | P1/P2 | closed | person → 核销详情 (UITest updated); inventory 0 → 「n 人」 |
| CLB-apply-05, CLB-create-02 rest, CLB-enroll-08, CLB-r7-A-08 | P1/P2 | open | no certImages upload; no status on the create receipt; enroll link requires clubId (Core); A-08 waits for `ClubSingleOwnedEntry` from fix/r3-club-b |

### Not taken (in flight on fix/r3-club-a/b, or owner decision)
CLB-group-code-05, CLB-notify-05, CLB-r7-D-05, CLB-G16, CLB-topic-detail-07 (r3). CLB-detail-11, CLB-payout-receiver-01,
CLB-detail-34, CLB-detail-35, CLB-apply-04 rest, CLB-settlement-05, CLB-workbench-03, CLB-r7-C-04 (owner decision).

## For Cursor
1. **G02:** club-scoped scan-verify workflow; the `scan=1` link is not acted on.
2. **G05:** `ClubCommunityOperation.create` with refType/refId, plus a `my-joined` options read for the composer.
3. **G10:** decode `isFollowTheUser` on `ClubCommunityPost`.
4. **G04:** a pool apply (`api/coop/pool/apply`) that submits; today `CoopPoolApplicationEditor` ends at a request preview.
5. **G17:** `ClubFEReferenceSettlementClient.list` must decode `{groups:[{rows}], totalOpenAmount, totalSettledAmount}` and take from/to. It also needs China-production grants for `/api/fe/reference-settlement/payer`, `/payer/export` and `/settle`.
6. **topic-story-04:** expose latitude/longitude on `ClubStoryStop`.
7. **topic-story-05:** an answer reader for `ClubNodeAnswerCall` (`api/topic/host-node-answer`), plus a host-scope topicOverview read.
8. **G15 / event-ops-06:** paymentNotice / windowWarning feeds and `sessionTicketCount` on the event-topic source.
9. **apply-05:** a certImages upload path.
10. **create-02:** status on the create receipt.
11. **enroll-08:** `MiniProgramPageLink` without clubId.
12. When fix/r3-club-a merges, recompute the span hash in `test_club_leaderboard_member_navigation`.

## Files (main thread)
App/ClubDetailR8Mounts.swift (new), App/ClubDetailView.swift, App/ClubPublicActivityListView.swift,
App/SessionClubPublicActivityListView.swift, App/ClubMembersView.swift, App/ClubKit/ClubMemberActionKit.swift,
App/MPGap/Club/ClubGapManageExtensions.swift, App/ClubCheckinRailView.swift, App/MPReviewedPageScreen.swift (G13
host only), Resources/Localizable.xcstrings, Resources/*Localizations.fragment.json (overrides),
tools/build_club_governance_catalog.py, Tests/AppUITests/ClubOperationsFlowTests.swift,
Tests/AppUnitTests/DesignR1ClubKitTests.swift. The forks' files are listed in their commits.

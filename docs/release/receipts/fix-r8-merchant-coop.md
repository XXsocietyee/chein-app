# Fix r8 — merchant-coop (Claude App rows)

- **Brief:** `origin/design/handoff-r2:docs/briefs/fix-r8.md` (+ `wave-x10.md`, `owner-decisions-1124.md`).
- **Queue:** `origin/audit/parity-r8-merchant-coop:docs/audit/parity-r8/merchant-coop.md`, owner = Claude App: 4 P0, 62 P1, 50 P2 (116 rows).
- **Branch:** `fix/r8-merchant-coop`, from `origin/ui/combined-r7` @ f5f3006d7. The in-flight round-4 F-agent branches `origin/fix/r3-merchant-coop-a` (dfa9570ff) and `origin/fix/r3-merchant-coop-b` (81de7e7f5) were merged first, so these hunks build on them rather than collide.
- **Work split:** three parallel clusters on local branches, merged here: coop/* pages (`fix/r8-merchant-coop-coop`), decor/node/relation/team (`fix/r8-merchant-coop-decor`), and the rest (this branch).
- **No compiler in the cloud.** Every type and initializer used was grepped on the tree first. No Core changes and no redeclared type names. New App files sit in `App/` (already globbed by `tools/generate_project.py`).
- **Strings** (xcstrings-shaped, en + zh-Hans, MP text):
  - `docs/port/strings/fix-r8-merchant-coop.json` (59 keys)
  - `docs/port/strings/fix-r8-merchant-coop-coop.json` (20 keys)
  - `docs/port/strings/fix-r8-merchant-coop-decor.json` (14 keys)
- **Money:** no money write is reachable. Deposit create / refund-retry are not mounted (see Left).

## Checks
- **ContractChecks**, test by test, base (r7 + r3-a/b merged) vs this branch, for every module that references a changed App file: **163 modules, 0 new failing tests.**
- **One test re-pinned, by the decor cluster:** `Tests/ContractChecks/test_merchant_station_submission_import.py`. It hashes `App/MerchantOperationsViews.swift`; the pin was changed with a comment, the way r3-b did it. Cursor owns Tests/, so please confirm.
- `tools/check_a11y_lint.py`: PASS, 0 current.
- `tools/check_typography_lint.py`: PASS.

## Closed

### P0
| id | what | files |
|---|---|---|
| MC8-29-3 | 移除成员 uses the MP destructive confirm 移除团队成员「名 · 岗位」？ with the MP consequences and the fixed reason 店主在经营团队页移除成员, instead of a typed reason. It still goes through the reviewed prepare → submit path, so it dispatches only after MC8-29-1. | MerchantTeamDangerConfirm (new), MerchantBusinessViews |
| MC8-29-4 | Same for 撤销邀请 (`operators/invite/revoke`, reason 店主在经营团队页撤销邀请) | same |
| MC8-33-1 | Topic-scoped 找商家: once the consented nearby search is ready, it reads `chapter-application/invitable` for the topic through the existing `MerchantContentService.load(.invitable)` and merges by memberId (MP `merge`). Nearby cards show 可承接 · 章节; invitable merchants outside the radius are appended after them. A failed topic read shows an inline note. | NearbyMerchantTopicSections (new), NearbyMerchantView |
| MC8-33-2 | 邀请补位 on merchants that have replacement candidates opens the existing C9 `ChapterReplacementInvitationEntry` for the topic. That flow is reviewed and default-closed, and posts `chapter-application/invite {chapterId, merchantMemberId, replacementOfOfferId}`. | same |

### P1
| id | what | files |
|---|---|---|
| MC8-01-1 | Workbench 项目 strip: the first 4 projects (status, type, N 张待核销, title, place), 全部 N, +N 更多项目 → 项目 list. Uses the existing `merchantProjects(access:)` read. | MerchantWorkbenchProjectCards (new), MerchantHomeView |
| MC8-02-1 | 店铺地址 is picked on the map (`PublishingPlacePicker` + `PublishingMapKitAdapter`) and writes address + `locationLat/Lng` into the draft | MerchantOnboardingView |
| MC8-04-1 | The dead manual-code block (client built `gate: .off`) is removed from verify-records. The row type is kept for the 更多 · 手输码 re-home. | MerchantVerifyRecordsSections |
| MC8-06-1 | A verifier without finance gets the 核销 segment (amounts redacted by the existing sections). The denied state shows only when the redemptions read is denied too. | MerchantLedgerSettlementOverview |
| MC8-06-2 | The ledger link's `view` picks the segment (settlement → 结算); a rejected link shows 链接已失效. `view=messages` opens 核销 (see For Cursor). | MPReviewedPageScreen |
| MC8-11-1 | 店铺参谋 greeting: 早上好/中午好/下午好/晚上好 by China time, store name, logo (from the insight `profile`) | MerchantInsightHeroSections (new), MerchantMarketingView |
| MC8-11-2 | 近7/30/90天 segmented switch, drawn from `trends.windows` (client-side, as in the MP; only shown when all three windows are valid) | same |
| MC8-11-3 | Daily heat grid (4 levels, 7 or 15 columns, decorative) with the start date and 今天 axis; 30 light cells when there are no trends | same |
| MC8-11-4 | 到店 / 打卡 / 核销 trio selects the hero metric | same |
| MC8-11-5 | 客源主题 bars (top 5, width relative to the first row, share %) after 到店时段 | same |
| MC8-11-6 | 俱乐部合作 pool cards (up to 3 `open` rows, 查看全部 / card → 合作中心 focused on the topic, inline retry). Read through the session's existing cooperation reader via a root mount hook. | MerchantCoopR8Environment (new), MerchantMarketingView, QuestifyApp |
| MC8-11-7 | 经营优化 cards for the actions this page can open: 承接一条主题路线 (合作中心) and 发一张到店券 (coupon:manage). 打卡点 and AI 店铺角色 have no destination in this environment, so they are not drawn (no dead entries). | MerchantInsightHeroSections |
| MC8-12-1 (App part) | 触达记录 shows 当前身份不能查看触达记录 when the grant has no marketing read/write, instead of the empty state | MerchantCampaignHistoryView |
| MC8-17-2 (App part) | 联系平台客服 is a tappable row (title + MP description) that opens the in-app support page, on refund and manual-case detail | MerchantAftercareParityViews, MerchantAftercareProgressView |
| MC8-19-1 | 看公开主页 on the 品牌中心 hub (decor cluster); the preview hook is injected on the decor deep link and on the workbench | MerchantOperationsViews, MerchantDecorR8Parity (new), MPReviewedPageScreen, MerchantHomeView |
| MC8-19-2 | 经营类目 multi-select sheet with the MP list; it edits the draft only | MerchantOperationsEditor, MerchantDecorR8Parity |
| MC8-19-5 | 联系运营开通 opens the reviewed support contact (profile writers) | MerchantOperationsViews, MerchantDecorR8Parity |
| MC8-20-1 | 暂时无法上传门店相册 + 去商家入驻 on the gallery deep-link host for an inactive identity | MerchantDecorLinkedPage, MerchantDecorR8Parity |
| MC8-26-9 | Camera QR scan (existing `NativeQRScanner`) feeds the submission id; a plain TextField replaces the SecureField and the raw-JSON instructions | MerchantGameNodeView |
| MC8-27-1 | The coop-center card also opens when the topic id arrives as a numeric string. It already pointed at the chapters view with 申请承接. | MerchantCoopCenterView |
| MC8-28-3 | Cross-club feed posts get like / comment / repost / share using `post.clubID` | ClubCommunityViews |
| MC8-29-7 | Already in place: the `?invite=` link opens `MerchantOperatorInvitationLandingView` (still needs MC8-29-2 to dispatch) | — |
| MC8-30-1 | `initialTopicID` on `CooperationBrowserView` seeds the topic filter after the inbox loads; the deep link passes topicId and `scope=MERCHANT` | CooperationBrowserView, MPReviewedPageScreen |
| MC8-30-4 | 回邀约 on pending received applications → invite page with the club locked (type 1) and the topic set | CooperationBrowserView, CoopListCardExtras (new) |
| MC8-30-6 | 再邀别人 under declined sent invites → 找商家 for the topic (new env `cooperationTopicNearbyDestination`) | CoopListParitySections, QuestifyApp |
| MC8-31-1 | `CoopFlowNewInvitationView` takes `initialType`, `lockedTarget` and `initialTopicID`; the deep link applies `CoopInviteLink` | CooperationContextualViews, CoopInvitePresetViews (new), MPReviewedPageScreen |
| MC8-31-3 | 还没有可关联的主题 + 先发布主题 → topic publish editor (env `coopTopicPublishDestination`) | same |
| MC8-31-4 | Locked-target row 已选定，发送前不可更换 replaces the picker | same |
| MC8-32-1 | The workbench inbox and the invite-detail deep link get the topic and project destinations | QuestifyApp, MPReviewedPageScreen |

### P2
| id | what | files |
|---|---|---|
| MC8-01-5 | Workbench toolbar ShareLink: the canonical public home `pages/userinfo/userinfo?userId=<ownerMemberId>&tab=about`, titled 店名 · 商家主页. It is offered only if the universal-link parser accepts the URL. | MerchantPublicHomeShare (new), MerchantHomeView |
| MC8-01-6 | `MPAsset.BrandLogo.cyLogoMark` as the project cover placeholder | MerchantWorkbenchProjectCards |
| MC8-02-4 | 开场屏 把你的店放进玩家的路线里 + 开始入驻 before step 1 of a fresh application (no 认领 link until MC8-02-3 exists) | MerchantOnboardingView |
| MC8-03-2 | Public merchant home toolbar ShareLink (real name, memberId) | PublicMerchantHomeView |
| MC8-08-2 | 打款凭证 {payVoucherNo} is a visible, selectable row above the copy action | MerchantSettlementProgressView |
| MC8-11-8 | One hero number (selected metric) with 环比 (持平 / ±n%) and 上期 above the trio (the attribution summary rows stay, see Left) | MerchantInsightHeroSections |
| MC8-11-10 | Already done in r3-a (`MerchantMPAvatar` → d_profile); the real avatar needs Core | — |
| MC8-13-6 | The review card drops the raw rating/content/createTime/version rows | MerchantBusinessRecordViews |
| MC8-13-7 | 回复 carries the MP send glyph (`MPAsset.FeatureIcon.iconSend`) | MerchantBusinessViews |
| MC8-14-10 | 复制 carries the MP copy glyph (`iconCopy`). The number is revealed through the existing audited contact flow. | MerchantCustomerContactEntry |
| MC8-15-7, MC8-16-1, MC8-18-5 | Already done in r3-a (MP empty art) | — |
| MC8-19-7, MC8-19-10, MC8-24-8, MC8-25-3, MC8-30-9, MC8-30-10, MC8-31-8 | Already done in r3-b; checked | — |
| MC8-19-9 | Featured activity name; 去发布一个活动 in the empty picker | MerchantFeaturedActivityPicker, MerchantOperationsEditor |
| MC8-19-11, MC8-20-3, MC8-21-1 | MP empty art on the hub, gallery and perks error states | MerchantOperationsViews, MerchantPerkTemplatesView |
| MC8-22-1 | 暂时无法编辑承接设置 + 去商家入驻 on the coop-setting deep-link host | MerchantDecorLinkedPage |
| MC8-23-8 | 去设置开启麦克风 when microphone permission is denied | MerchantStoreCharacterView |
| MC8-24-7, MC8-25-2 | 申请入驻 on the no-permission state when access/me says the identity is inactive | MerchantCityNodeHubView, MerchantCityNodeCreateView, MerchantCityNodeSessionBinding |
| MC8-24-9 | 保存打卡码 downloads the https poster and shares the picture | MerchantCityNodeHubView |
| MC8-28-4 | Relation guest state has 登录 | CoopRelationDiscoveryView |
| MC8-29-9 | Team member rows lead with `MerchantCoopMPThumb(avatar, .avatar)` (d_profile fallback) | MerchantBusinessViews |
| MC8-30-7 | Chapter-application rows link to the topic screen | CoopListParitySections |
| MC8-30-11 | One 还没有收到/发出协作邀请 + 去发起邀请 when every inbox section is empty | CooperationBrowserView |
| MC8-31-6 | 原请求 加载更多 (cursor paging) + 查看已发出邀请 | CooperationContextualViews |
| MC8-31-7 | A multi-target send ends on one summary → 我发出的 | CooperationFlowEditors |
| MC8-32-3 | Countdown line under the invite-detail hero | CooperationInviteDetailView |
| MC8-32-4 | Fixed by MC8-32-1 | — |
| MC8-32-5 | No `stationAccept` sender → disabled 暂不可提交 + gated note, not a dormant fallback | CooperationFlowEditors |
| MC8-33-5 | Topic mode is titled 邀请商家, with the topic name in a header row | NearbyMerchantTopicSections, NearbyMerchantView |

### Partial
| id | done | missing |
|---|---|---|
| MC8-19-8 | 门店相册 · N 张照片 | the perks count needs a perk read on the hub |
| MC8-30-5 | 发邀约 for confirmed registrations, with the merchant locked | `inviteState` hiding (not decoded) and `scope: MERCHANT` on `candidates/confirm` (Core) |
| MC8-30-8 | countdown + message lines | one card layout for every row |
| MC8-31-2 | the locked-topic row | only when the topic is on the loaded owned-topic pages (needs a by-id read) |
| MC8-33-8 | MP default cover + citylink mark, pin and chevron | clock row and real cover/logo need Core fields |
| MC8-33-3 | the deep link passes `topicId/topicName` into topic mode | — (closed; listed here because it pairs with MC8-33-1) |

## Left, with reasons
- **Core / contract (see For Cursor):**
  - MC8-02-2: no role-snapshot read of owned clubs.
  - MC8-02-3: the claim flow (search → status → submit with proofs) has no reviewed Core reader/writer; the parked Round4 client takes a raw token.
  - MC8-06-3: the parked `ClubFEReferenceSettlementClient.list` decodes a flat array, but the MP contract is `{groups[...], totalOpenAmount, totalSettledAmount}` with `from/to` (components/cy/fe-reference-settlement/view-model.js). Mounting it would always fail.
  - MC8-13-5: `MerchantReviewFilter` is Core.
  - MC8-17-5: no evidence URLs in Core.
  - MC8-19-3/-4/-6: no `wechatQrcode`/`address`/lat-lng/`businessLicense` writes or decodes.
  - MC8-20-2: the coordinator clears the document on reload.
  - MC8-23-2/-3/-4/-6: no photo upload, store-point setter, voice reset or recorder writer.
  - MC8-28-5: the relation model clears its value on reload.
  - MC8-30-2/-3, MC8-32-2: money. There is no reviewed TEST-only deposit create/retry.
  - MC8-31-5: the invite body has no `supplyStationId`.
- **Owner decision first:**
  - MC8-18-2 / MC8-18-3: settlement is off in every composition (MC8-18-1).
  - MC8-15-6: the edit sheet only makes sense once the X6 approval lands (MC8-15-1..5).
- **Pinned by tests (needs a Cursor re-pin):**
  - MC8-11-9: `test_merchant_insight_navigation` pins `.recruiting` + `focusedTopicID`.
  - MC8-15-8: `test_merchant_customer_detail` requires `refundTimeBoundary`.
  - MC8-17-3 / MC8-17-6: `MerchantBusinessEditor.swift` is hash-pinned.
  - MC8-29-8: `test_merchant_operator_roster` pins the count row.
- **Needs the engagement model on the customer page:**
  - MC8-14-4 / MC8-14-5: 我的分群 / 存为分群.
  - MC8-14-6: the export banner.
  - MC8-14-7: the 管理 menu with 触达记录.
  - `MerchantBusinessPage` has no engagement reader; wiring one is a composition change across protected files.
- **Other:**
  - MC8-14-8: one-tap phone. The contact reveal is the audited 准备→使用 privacy flow (pinned); not changed without a privacy ruling.
  - MC8-14-9: customer append paging needs a customers accumulator like `aftercareLoadedPages`, plus cross-page selection.
  - MC8-03-1: the app has no standalone roam POI detail host. Even `subpackageRoam/poi-detail?id=` is unsupported in `AuditedContentEntry` (play-roam area).
  - MC8-28-1 / MC8-28-7: a cross-club composer needs the member's club list plus a per-club write-evidence check.
  - MC8-11-8 (rest): the three attribution rows in `MerchantInsightAttributionSummary` stay, because `test_merchant_insight_attribution` pins that block. The hero now leads.

## For Cursor (Core)
1. Deposit: reviewed, TEST-only deposit create (`api/coop/deposit/create/app`) and refund retry (`deposit/refund/retry`) mutations, plus `depositStatus` polling (MC8-30-2/-3, MC8-32-2).
2. `CoopFlowMutation.invite` body: add `supplyStationId` (MC8-31-5).
3. Registrations: `scope: MERCHANT` on `candidates/confirm`, and decode `inviteState` (MC8-30-5).
4. `NearbyMerchantRow`: add `cover`, `logo` and `availableTime` (MC8-33-8). Optionally, move the invitable merge into the coordinator (MC8-33-1 is App-side today).
5. A by-id owned-topic read (MC8-31-2).
6. Merchant claim: a reviewed search / status / submit flow with proof upload (MC8-02-3). Owned clubs in the merchant role snapshot (MC8-02-2).
7. FE reference settlement: a Core reader for the real `{groups, totals}` contract with `from/to`, and the dispute/settle writers (MC8-06-3).
8. Ledger: a project-events read by `ownerType/ownerId` for `view=messages` (MC8-06-2).
9. Marketing access: decode `merchant:marketing:read` on `MerchantAccess` / `MerchantOperationsAccess`. Allow `.campaigns` reads with marketing read, not only `:write` (MC8-12-1; entry gating follows).
10. `MerchantReviewFilter.platform` (平台复审中) with `filterCounts["platform"]` (MC8-13-5).
11. Insight: `MerchantInsightRecentVisitor.avatar`, `MerchantProject.thumb` and the upcoming-runs read for the workbench 谁、哪天几点到店 line (MC8-11-10, MC8-01-1).
12. Aftercare: evidence preview URLs (MC8-17-5), and a reviewed `manual-case-detail` read (MC8-17-2, 工单编号/amount).
13. Store profile and character:
    - writable `wechatQrcode` / `address` with lat/lng, decoded `businessLicense`, and a QR upload (MC8-19-3/-4/-6);
    - StoreCharacter photo upload, `chooseStorePoint`, `npc/voice/reset` and recorded-sample enroll (MC8-23-2/-3/-4/-6).
14. Keep loaded values during reload: the operations coordinator (MC8-20-2) and `CoopRelationDiscoveryModel` (MC8-28-5).
15. Test re-pins:
    - `test_merchant_insight_navigation` (MC8-11-9 → `merchantCoopCenterDestination(.plaza, topicID)`);
    - `test_merchant_customer_detail` (MC8-15-8);
    - `MerchantBusinessEditor.swift` hash pins (MC8-17-3/-6);
    - `test_merchant_operator_roster` (MC8-29-8);
    - confirm the `test_merchant_station_submission_import.py` re-pin.

## Fixture routes worth a screenshot
These existing routes cover the changed screens (no new routes): `merchant-home` (项目 strip, share), `merchant-customers`, `t12-marketing-empty` / the insight fixture (greeting, hero, sources, pool, 经营优化), `cur9-ledger` (verifier and segment), `t12-reviews` (send glyph, card), `t12-aftercare` (support row), the nearby fixture (`DesignFixtureRegistry` NearbyMerchantView; topic mode needs a topic deep link).

# ui/h-r2-verify · round 2 app fixes receipt (2026-11-16)

Base `origin/ui/main` 200edb508. Plan: Fable's `review/verify-r1.md` (§2.1 app problems, §3 drift, §4 batches 1, 2, 3
and 6, §5 owner questions). Mac only: Xcode 27, Questify-iPhone17-Lane2 (2337B386), iOS 27, arm64, one DerivedData,
simulator sessions under `lockf /private/tmp/design-build.lock`. Screenshots: `/Users/fanning/chengyin-refs/r2-shots/`
(local, not committed), listed with sources and contrast figures in that folder's `index.md`. **TEST** = the real app
with `--e2e-test-host` (be-int 8120, signed in as fixture member 9003); **FIXTURE** in a file name = a design-fixture
host (real view, synthetic data). `ui/main` is not fast-forwarded.

Owner answers used (§5, confirmed 2026-11-16): Q1 keep `api/club/members`; **Q2 changed: keep the merchant identity
step** (真实姓名 + 身份证号); Q3 neutral switch tint; Q4 7-day numbers on the Today card; Q5 keep pushes; Q6 hide the
external-game price; Q7 build the map-first roam root; Q8 ¥560.00; Q9 首页 keeps 消息 and search; Q10 three sheet-header
styles.

Status words: **done** (with a screenshot), **partial**, **built, not mounted**, **left**.

## Batch 1 · readability (blocking)

| # | Item | Status | Evidence | What changed |
|---|---|---|---|---|
| 1.1 | N-01 two themes on one page | **done** | `14-publish-activity-TEST-from-player.png`, `11-topic-editor-TEST-from-player.png`, `03b-tab-publish-after-pop-TEST.png`, `19-merchant-onboarding-TEST-from-player-sheet.png`, `21-merchant-finance-from-merchant-root-FIXTURE.png` | Four causes, all fixed. (a) The role root forced its scheme unconditionally: `roleTheme` now owns a `CYShellSchemeArbiter`; in-window pages that call `themeDomain(_:)` register their scheme while their view is in the window (sheets excluded: a presented controller owns its scheme); shallowest request wins, ties go to the most recent; the root applies `.preferredColorScheme(requested ?? role)`. (b) A pushed page reads the NavigationStack's environment, not the pusher's: `cyDomainScreen(_:)` painted its ground from the outer (player) palette, and seven self-themed light pages (`ActivityPublishingView`, `ProjectEditView`, `TemplateAuthoringView`, `TemplateAuthoringReviewView`, `PublishingAIDraftSheet`, `CouponManagementEditor`, `CityNodeRedeemView`) read `cyPalette` from outside their own domain. Both fixed; the two editors now wrap the whole page in their domain. (c) The navigation bar keeps the stack's traits: pushed pages with a domain set `toolbarColorScheme`, and the root retints bar buttons when the scheme changes (back chevron now dark on light). (d) `themeDomain` carries its brand tint (a light sheet's 关闭 was white on white). Measured: 发布活动 status bar 19.1:1 (was 1.0), labels at body ink; topic editor status bar 19.1:1 (was 1.12), 城市定向 / 0·0·0 ink on white. Popping back restores the dark shell (20.5:1 white status bar). Note: the first build of the arbiter hung the app (an `@Observable` dictionary read and written from `updateUIView` re-ran the update forever); bookkeeping is now `@ObservationIgnored` and writes are deferred. |
| 1.2 | N-02 topic editor | **done** (stop-gap) | `11-topic-editor-TEST-from-player.png` | The 发布状态 card has no 提交审核 (`CYPublishStatusBar(showsSubmitButton:)`); the bar is a full-width secondary plus the primary; 查看已保存的原发布请求 only appears when it can be opened (no engineering sentence). The primary keeps the label 检查并提交 (UI tests and a contract pin the button line; renaming to 发布 is left for 3.4). |
| 1.3 | N-10 back circle over content | **done** | `16-club-detail-TEST-top.png`, `16b-club-detail-TEST-scrolled.png`, `08b-activity-detail-scrolled-FIXTURE-e1.png` | `cyHeroPushedChrome` puts the back control in the navigation bar (toolbar item, same identifier and custom action), so it gets the scroll-edge effect instead of floating over headings. No centred 活动详情 / 俱乐部详情: the object's name appears inline once the hero has scrolled away (`cyTracksHeroScroll`, iOS 18+). |
| 1.4 | N-11 text under the tab bar | **done** | `01-home-TEST.png`, `03-tab-publish-TEST.png`, `04-tab-club-TEST-at-limit.png` | Tab roots get `.scrollEdgeEffectStyle(.soft, for: .bottom)` and a page-colour fade (32 pt) under the floating bar. |
| 1.5 | MC-02 raw timestamps; N-16 balance | **done** | `17-club-members-TEST.png` (加入 11月16日), `05-tab-me-TEST.png` (¥560.00) | `ClubJoinDateDisplay` (wall-clock fields, no time-zone shift); `MemberBalanceDisplay` (`.currency(code: "CNY")`, two decimals). |
| 1.6 | N-06 engineering wording | **done** | `12-gameplay-editor-FIXTURE-t11.png` (封面会裁成 16:9), `18-merchant-workbench-FIXTURE-merchant-home.png` | 封面会裁成 16:9; 今天还没有数据 (and the Today card no longer needs it); the original-request row is hidden when unavailable; the club-limit page no longer shows 暂时无法保存修改。 |

## Batch 2 · regressions

| # | Item | Status | Evidence | What changed |
|---|---|---|---|---|
| 2.1 | N-05 merchant button shape | **done** | `19d-merchant-review-identity-masked-FIXTURE-MOF.png`, `14-publish-activity-TEST-from-player.png` | `CYDomainPalette.buttonCornerRadius` / `buttonMinHeight`: merchant and editor 12 pt rounded rectangle (merchant 46 pt), player capsule. One style, shape by domain. |
| 2.2 | N-08 club wizard | **partial** | `15-club-create-step1-FIXTURE-d4-ops-create.png`, `15b-club-create-step2-FIXTURE-d4-ops-create.png` | Header on the page: four-segment bar, 第n步，共4步 eyebrow, 28 pt title, 已选 n / 3 on step 2; check badge on the selected card; 上一步; 350 ms step animation (cross-fade with Reduce Motion). **Left:** 下一步 is not pinned (it still follows the content); the 关闭 pill still reads grey. |
| 2.3 | N-15 create at the limit | **done** | `04-tab-club-TEST-at-limit.png` | No 创建俱乐部 primary when the quota is full or over; the warning tag stays. The limit page states the real count (`club.ops.clubLimit.count`) with no save warning. No separate 管理我的俱乐部 button (the owned clubs are the first rows). |
| 2.4 | N-13 lobby | **done** | `10-lobby-FIXTURE-t5-seats.png`, `10b-lobby-FIXTURE-tap-nudge.png` | Button says 按住开始 (VoiceOver keeps 去起点); caption is a reassurance line; a tap nudges the ring and shows 按住 1 秒开始 for 2 s (caption only under Reduce Motion); 房主 is a readable crown tag (the seat was a disabled button, which dimmed it); 撤回 is in the row's ⋯ menu. |
| 2.5 | N-12 root headers | **partial** | `01-home-TEST.png`, `01b-home-more-menu-TEST.png`, `02-tab-roam-TEST.png` | 首页: search then 消息 only (owner Q9); language is in 设置; ＋ is the 发布 tab; 广场 / 官方活动 / 浏览模板 / 路线编辑器 moved into 更多玩法. 漫游: large left root title. **Left:** 消息 on 漫游 (its NavigationStack is inside `RoamBrowserView`, which has no session); 俱乐部 refresh → pull-to-refresh; the inline search field and the bar's search are still both on 首页 (R5; the bar button is pinned by a contract). |
| 2.6 | N-14 members screen | **done** | `17-club-members-TEST.png` | Roster card removed from 成员; role counts are the subtitle. `ClubRosterCard` mounted on 报名名册 (`ClubRosterBucketContent`, attendees by bucket) — mounted, not screenshotted (no roster on TEST for this account). **Left:** 邀请成员 (no invite flow exists to link to). |
| 2.7 | MC-14 double chevrons | **partial** | `16b-club-detail-TEST-scrolled.png` | One chevron on the club detail rows. **Left:** the stray hairlines inside the row cards. |
| 2.8 | N-07 Today card | **done** | `18-merchant-workbench-FIXTURE-merchant-home.png` | 待处理 large; 近 7 天收入 and 近 7 天日均 (window of 7 days) below it; no footnote; shop name 22 Bold, no centred 商家工作台 (iOS 18+). The 营业中 chip shows when the business-status read answers (the fixture has none). |
| 2.9 | N-09 gameplay editor title | **partial** | `12-gameplay-editor-FIXTURE-t11.png`, `12-gameplay-editor-FIXTURE-t11-XXL.png` | One inline title 编辑玩法模板; the section bar sits under the nav; cover scrim 45–70% black (white title 4.54:1 at the lightest point). **Left:** the 名称 field stays (UI tests drive `templateAuthor.field.title`); filled fields (3.5). |
| 2.10 | CF-49 raw URL fields | **left** | — | Not started. |

## Batch 3 · mount the kits

| # | Item | Status | Notes |
|---|---|---|---|
| 3.1 | PL-23 topic detail | **left** | `07-topic-detail-TEST.png` shows the old page on TEST: 图片暂不可用 overlapping the title, blue 城市定向 chip, 路线详情 title. Only the no-cover type label moved from blue to ink. |
| 3.2 | PL-20 live roam | **left** | Shipped `RoamLiveSessionView` still the List HUD. |
| 3.3 | PL-03 lobby cover / 怎么玩 | **left** | |
| 3.4 | CF-20/40/25 topic editor rebuild | **left** | Stop-gap 1.2 only. |
| 3.5 | CF-10/11/44 editor kit | **built, not mounted** | `EditorField`, `EditorCard`, `EditorCardFooter` unchanged. |
| 3.6 | MR-22 refund, MR-30 station | **left** | Money path; not touched. |
| 3.7 | PL-21 map-first roam root (Q7), PL-22 | **left** | `02-tab-roam-TEST.png` is the old page. |
| 3.8 | MC-22 header, MC-33 consequence sheet | **built, not mounted** | `ClubConsequenceSheet` has no call site. |
| 3.9 | D-06 registration sheet header | **done** | `09-registration-sheet-FIXTURE-e1-registration.png`: grabber, 20 Bold title left, round ✕ right (Player/Sheet, Q10). **Left:** 合计 / 票种 "—" still draw as white bars (N-16). |

## Owner Q2 · merchant identity step (new)

**done** — `19a-merchant-identity-empty-FIXTURE-MOF.png`, `19b-merchant-identity-invalid-masked-FIXTURE-MOF.png`,
`19b-merchant-identity-valid-masked-FIXTURE-MOF.png`, `19c-merchant-review-step5-FIXTURE-MOF.png`,
`19d-merchant-review-identity-masked-FIXTURE-MOF.png`.

- Five steps (店铺 → 营业 → 资质 → **身份** → 预览确认) with a five-segment bar.
- 真实姓名 (2–30 characters) and 身份证号: 18 characters, digits with a final digit or X, GB 11643 birth-date and
  MOD 11-2 check, client-side. Errors sit under the field they belong to; the privacy line reads
  仅用于商家资质审核，加密保存.
- The number is held in `MerchantIdentityNumber`, whose `description`, `debugDescription` and `Mirror` only show
  the mask (`110***********002X`); nothing logs it. Once you leave the field the raw `TextField` is removed from
  the view tree (an opacity-0 field still exposed the number to accessibility, found on the simulator and fixed);
  the masked row reads 已填写，已隐藏 to VoiceOver; `privacySensitive()`; no text-content type, autocorrection off.
- Review step: an 经营者身份 group with the name and the masked number, 修改 back to step 4.
- Request: `realName` and `idCardNumber` in the merchant application submit body, only when the step is valid
  (`fix/merchant-identity-r3` on the backend). Existing Core contract tests keep their exact field sets; new tests
  cover the checksum, masking (`dump`, `String(reflecting:)`, a whole draft printed) and the request fields.
- Not a money feature; stays behind the existing merchant flow.

## Batch 6 · evidence

- 36 PNGs in `/Users/fanning/chengyin-refs/r2-shots/`, with `index.md` and `contrast.py` (WCAG ratios from pixels;
  calibrated on the r1 shots: it reproduces verify-r1's 1.10, 1.23 and 1.26). TEST shots: 首页, 更多玩法, 漫游, 发布 (and
  after pop), 发布活动, topic editor, 我的项目 (load failure on TEST, as in r1), 俱乐部 at the limit, club detail (top and
  scrolled), members, 我的, merchant onboarding sheet, topic detail, welcome. Fixture shots: lobby (and tap nudge),
  club wizard steps 1–2, merchant workbench and 财务 from the merchant root, merchant identity and review, registration
  sheet, activity detail, gameplay editor. XXL: home (TEST), topic detail (TEST), lobby, gameplay editor.
- Light-page entry paths: from the player shell (发布活动, topic editor, 我的项目, merchant onboarding sheet) and from the
  merchant root (财务).
- Not shot: play HUD, hint, settle, wallet, payment result, refund, station, merchant tab bar, sheet at each detent.

## Gates

| Gate | Result |
|---|---|
| Build (Questify, Debug, Lane2, `OTHER_SWIFT_FLAGS=$(inherited) -disable-sandbox`) | BUILD SUCCEEDED |
| `tools/check_scaffold.py` | PASS (4893 Swift files, 16747 bilingual keys, project equivalence) |
| `tools/check_design_lint.py` | PASS (0 violations; one fixed font size caught and replaced with `.title`) |
| `tools/check_missing_string_keys.py`, `tools/check_a11y.py`, `build_design_r1_localizations.py --check` | 0 missing / PASS / CHECKED (generator updated, catalogs regenerated) |
| `tools/contract_ratchet.py --check` | 185 failing, baseline 184. The one "new" item is `test_workshop_paid_professional…bounded_paging`, already red on `ui/main` (integ-d-r1 receipt). Five contracts this branch tripped were fixed in code (`Button("action.close"` kept on registration; `if let joined = member.displayedJoinTime` token kept; `homeFeed.openOfficialEvents` identifier stays in `SessionHomeFeedView`; the `projectEdit.review` button line kept; 更多操作 renamed 邀请选项 because square detail pins it as missing copy), one updated deliberately (`test_club_create_host_application`: the limit copy now carries the count). |
| Core `swift test --disable-sandbox` | 16974 tests; **27 unique failures = baseline 27**. One new failure was found and fixed (`WP04OwnerDecisionGuardTests` forbids a `birthDate` symbol; the identity check's case is now `.dateField`, validity only). |
| AppUnit, 4 shards via XcodeBuildMCP `test_sim` (shard xctestruns built from the shard plans) | tests (failed): 1867 (7) / 1978 (16) / 2069 (26) / 2031 (25); 74 failing names vs the 73-name burn-down baseline (DES-ag9 bundles 05:30–05:34Z): **2 fixed, 3 new**. New: `MerchantOnboardingFixtureCounterTests.testReviewAndCancel…` — intended (a reapplication must fill the identity step); test updated, passes (focused run 33/33 with `VerifyR2AppFixTests`, `DesignR1MerchantKitTests` and the merchant onboarding classes). `RoamAnniversaryReadIntentTests.testActualRouteCoverForegroundAndBackRefreshOriginalDepthOnce` and `RoamPrivateReadDenialHostTests.testActualReceiptRefusalKeepsReceiptOnlyLockAndNoEmptyOrWriter` — hosted roam family ("did not settle", `InvalidTransition idle → failed(deinit)`), fail on re-run; reverting this branch's only roam change (the root header) did not change them, and the harnesses do not mount a role root. **Baseline, not caused by this branch:** re-run on a clean `origin/ui/main` 200edb508 build (same worktree checked out detached, build-for-testing, only these two tests via `test_sim`): both fail there with the same `did not settle` / `InvalidTransition idle → failed(deinit)` (result bundle `test_sim_2026-11-16T20-05-32-289Z…b4222003.xcresult`). They entered `ui/main` after the burn-down baseline was recorded. Net for this branch: no new AppUnit failures. |

## Skipped (owner 2026-11-16: design rounds first, then batch 3 against the final Figma)

- Batch 3 mounting work not started this round: 3.1 topic detail, 3.2 live roam, 3.3 lobby cover / 怎么玩, 3.4 topic
  editor rebuild (publish preview, one delete rule), 3.5 editor kit (`EditorField`, `EditorCard`, `EditorCardFooter`,
  `EditorSheetHeader`), 3.6 refund / station, 3.7 map-first roam root (Q7) and home cards, 3.8 club header and
  `ClubConsequenceSheet`.
- 2.10 media pickers for 题目图片 / 题目音频 (raw URL fields remain).
- From batches 1–2: 下一步 pinning and the grey 关闭 pill in the club wizard; 消息 on 漫游; club pull-to-refresh; the
  doubled search on 首页; 邀请成员 on 成员; hairlines inside club detail cards; the 名称 field in the gameplay editor;
  "—" drawn as white bars on the registration sheet; the clipped stat on activity detail (N-16).
- Q6 (hide the external-game price) not touched this round.
- Evidence not captured: play HUD, hint, settle, wallet, payment result, refund, station, merchant tab bar, sheets at
  each detent.
- The merchant onboarding fixture host is not under a role root, so its status bar is white on light there; the TEST
  path (sheet from the player shell) is correct.

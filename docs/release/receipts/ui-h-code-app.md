# ui/h-code-app · code worker B receipt (2026-11-16)

Base `origin/ui/main` f14040431. Scope: every hand-off frame on Figma `00 Hand-off · 交付清单` (file
`0YyoybGnU1KG0657wdGCPX`) except City Monopoly and the 漫游 tab root (worker A), plus verify-r1 batch 3 (3.1, 3.3, 3.4,
3.5, 3.6, 3.8), the batch 2 partials (2.2, 2.5, 2.7, 2.9, 2.10), owner defaults Q4 / Q8 / the sheet-header rule, and
the merchant PIPL consent. Sources: `review/skill-r2.md` §3–4, `revise/skill-r2/LOG.md` and `js/_handoff.json` (the
hand-off table, read offline), `review/verify-r1.md` batch 3. Figma calls used: 9 of 25 (1 session, 8 screenshots).

Mac only: Xcode 27, Questify-iPhone17-Lane2 (2337B386), iOS 27, arm64, one DerivedData (`DES-ag8-codeB`, deleted at
the end), builds and simulator sessions under `lockf /private/tmp/design-build.lock`. Screenshots (local, not
committed): `/Users/fanning/chengyin-refs/code-final-shots/app-B/` with `index.md`, Figma renders in `figma/`.
**TEST** = the shipped app on be-int 8120 signed in as fixture member 9003; **FIXTURE** = `--design-fixture` host
(shipped view, synthetic data). `ui/main` is not fast-forwarded.

Status words: **done** (screenshot next to it), **partial** (what is left is named), **left**.

## Owner defaults and rules

| Item | Status | Evidence | What changed |
|---|---|---|---|
| Q4 · capsule buttons on light pages (merchant and editor) | **done** | `02-182-7693-review-capsule-FIXTURE-MOF.png`, `08-237-59431-publish-activity-step1-TEST.png` | One place: `CYDomainPalette.buttonCornerRadius` is `nil` (capsule) for every domain (was 12 for merchant and editor, verify-r1 2.1). Test updated. |
| Sheet-header rule (handbook, three styles) | **done** (in the component) | unit test `testSheetHeaderStyleFollowsTheDomain` | `CYSheetHeaderStyle` gains `.merchant` (centred title, ✕ trailing) and `.automatic`, which picks editor / player / merchant from the sheet's theme domain. `CYResizableSheet` and its wrapper default to `.automatic`, so every shared sheet follows the rule without naming it. No merchant sheet was screenshotted. |
| Q8 · P, N1 and C1–C3 are the source of truth | applied | — | Frames built from the hand-off table only; frames marked Superseded, 还原 or Not for code were not built. |

## Merchant identity step · PIPL consent (Figma `182:7628`, `406:9580`)

**done** — `01a-182-7628-identity-unchecked-FIXTURE-MOF.png`, `01b-182-7628-identity-filled-unchecked-FIXTURE-MOF.png`,
`01c-406-9580-identity-checked-FIXTURE-MOF.png`.

- Under the two fields: an unchecked box and 我已阅读并同意《个人信息处理规则》. The rule is a link (opens the privacy
  rules document in a sheet); a tap anywhere else on the row toggles the box (selection haptic). VoiceOver reads it as
  one switch, 我已阅读并同意《个人信息处理规则》, with a custom action 打开《个人信息处理规则》.
- 下一步 on the identity step is disabled until the box is checked, with the hint 勾选同意后才能继续 above it (also the
  button's VoiceOver hint). The review step's submit and `prepare()` also refuse without consent.
- Request: `MerchantOnboardingDraft.identityConsent` (starts `false`, never restored on reapply).
  `jsonData()` sends `realName`, `idCardNumber` and `identityConsent: true` together, and only when the fields are valid
  and the box is checked. Core test: valid fields without consent send none of the three; with consent the body
  contains the JSON boolean `"identityConsent":true`.
- **TEST check (8120, loopback on the VPS, `/tmp/codeB-identity-verify.py`), synthetic checksum-valid ID
  `999999199001010040` (area 999999 does not exist), fresh TEST phone 13900000973 (member 990016):** the previous app
  body (no `identityConsent`) is refused with 请先勾选同意提供真实姓名与身份证号 and writes no identity row; the new app body
  (`identityConsent: true`, exactly the field set `jsonData()` sends, licence as a synthetic https URL) returns code 200
  更新成功 with no plaintext in the response; `identity/status` reads `registered: true`, `999***********0040`. 6/6.
  TEST state added: member 990016, pending merchant application 8008, one identity row, one consent record.
  The in-app submit itself cannot finish on TEST: step 3 needs a licence image upload and TEST has no media storage.

## Hand-off frames · Player (P)

| Frame | View | Status | Evidence / what is left |
|---|---|---|---|
| `204:15032` 开局大厅 | LobbyView | **done** | `03b-204-15032-lobby-FIXTURE-t5-seats.png` (final; `03-…` is the first pass). Eyebrow 开局大厅, 28 pt topic title, cover strip only when the read has a cover (no grey stand-in), 等队友加入 tag while seats are open, 怎么玩 card (N 站 · 约 N 分钟 · 需要到场) shown only when the facts are known. The seats read (`PlayerJourneySeatsVO`) has no stop count, duration or cover today, so on TEST the card and strip stay hidden rather than printing "—". |
| `289:2730`, `289:2804` lobby rest / holding | LobbyView | **done** (unchanged) | The 按住开始 hold control from r2 (verify-r1 2.4) is the Player/Hold Button rest and holding states. |
| `210:8452` 俱乐部 root | ClubsRootView | **partial** | `07-210-8452-clubs-root-TEST.png`. Club/List Card: 72 pt thumbnail r12, 17 pt name. **Left:** the meta as one line 「N 名成员 · 类型」 and the 下一场 line (the list read has no next activity); 帖文 / 俱乐部 is still a segmented control, not underline tabs; refresh button instead of pull-to-refresh (2.5). |
| `169:6954` 主题详情 (verify-r1 3.1) | TopicDetailView | **done** | `06b-169-6954-topic-detail-TEST.png` (final; `06-…` is the first pass with row dividers). Photo hero with no text over it (the title can no longer collide with 图片暂不可用); eyebrow + 28 pt title below; club line; up to four stat cells at 20 pt (评价 · 时长 · 站数 · 开放时间/里程, unknown facts left out); no blue type chip; no 路线详情 title (the name appears inline after the hero scrolls away); share in the bar beside the safety menu; sticky bar = price left (¥39 / 免费 / ¥X 起 / 已报名, 查看场次 › under the price) and one primary right. On TEST the photo is 图片暂不可用 because TEST has no image storage. |
| `210:8239` 首页 | HomeView | **left** | Not rebuilt this round (r2 state). |
| `210:8374` 发布 root | PublishRootView | **left** | r2 state. |
| `210:8603` 我的 root | MeRootView | **left** | r2 state. |
| `401:4731` play HUD | PlayHUDView | **left** | |
| `204:15044` 战报, `204:15096` 结算 | MatchReport / Settlement | **left** | |
| `210:10082` share badge, `210:10045` new badge | ShareBadge / NewBadge | **left** | |
| `396:4369` 选择票种, `396:4404` 提示, `396:4449` 队伍聊天 | sheets | **partial** | They are shared player sheets and pick up the sheet-header rule; not individually checked or shot. |
| `166:3280`, `169:4754` R1 error states; `204:30158` 收集册 | — | **left** | |

## Hand-off frames · Editor (C1–C3)

| Frame | View | Status | Evidence / what is left |
|---|---|---|---|
| `237:43689` 玩法模板编辑 (verify-r1 3.5, 2.9) | TemplateEditorView | **partial** | `04-237-43689-template-editor-FIXTURE-t11.png`. The name is edited on the cover (white field + pencil, `templateAuthor.field.title` kept), so the separate 名称 row is gone (2.9 done). `TemplateAuthoringField` text fields are now `EditorField` (label above, filled field, live counter); number fields keep the suffix layout. **Left:** collapsing valid sections into `EditorCard` summaries; `EditorCardFooter` on gameplay cards; `EditorSheetHeader` on every editor sheet. |
| `237:59431` 发布活动 step 1 | PublishActivityStep1View | **done** (Q4 only) | `08-237-59431-publish-activity-step1-TEST.png`: capsule 取消 / 下一步. Layout is r2's. |
| `237:31646` editor list, `239:31923`, `238:20393`, `249:16773`, `249:46938` (verify-r1 3.4) | topic editor and publish | **left** | Chapter cards, save chip, 列表 / 地图, publish preview with one confirmation sheet and the one delete rule were not started. r2's stop-gap (one submit, full-width bar) stands. |
| `238:16749`, `238:25435`, `237:71933`, `239:24018`, `247:17370`, `243:1964`, `243:3249` | C2 / C3 | **left** | |
| verify-r1 2.10 题目图片 / 题目音频 pickers | TemplateAuthoringDetailForms | **left** | Raw reference fields remain. A picker needs its own owner like the cover's, and TEST has no media storage to prove it. |

## Hand-off frames · Merchant (R4 / R5 优化)

| Frame | View | Status | Evidence / what is left |
|---|---|---|---|
| `182:7628`, `406:9580` identity step | IdentityStepView | **done** | see the consent section above |
| `182:7693` onboarding review | OnboardingReviewView | **done** (Q4) | `02-182-7693-review-capsule-FIXTURE-MOF.png` |
| `182:7328` workbench, `182:8065` 营销, `233:12260` 模板 root | merchant roots | **left** | Merchant/Root Header and the 扫码 primary were not touched (r2 state: shop name 22 Bold, Today card). |
| `186:5944`, `186:6119`, `186:6257` R5 cooperation | Coop views | **left** | |
| verify-r1 3.6 refund `183:1731`, station `233:9703` | merchant refund detail, station | **left** | Refund detail is the generic `MerchantBusinessPage`; the pinned 不同意 / 同意退款 ¥X bar needs the aftercare editor to take a preset decision. Money stays behind the existing switches. Figma renders saved in `figma/`. |

## Hand-off frames · Club (R3 优化)

| Frame | View | Status | Evidence / what is left |
|---|---|---|---|
| `204:24899`, `204:24850` 概览 (verify-r1 3.8 Club/Header) | ClubDetailView | **partial** | `09-204-24899-club-header-TEST.png`, `09b-204-24899-club-overview-TEST.png`. Cover banner; logo 52 + 22 pt name + 「类型 · N 名成员 · 公开加入」; host line 「主理人 X · 城市」 (only known facts; the three-tile grid on 概览 is gone, its identifiers moved to the header); role / pending / declined as tags with the decline reason; the creator no longer gets a 成员身份 group that only says 创建者不能退出自己的俱乐部. **Left:** 邀请朋友加入 + share circle (no invite or share flow exists for clubs), the 下一场活动 card, 勋章 row as a card, member avatars row. |
| `222:5684` consequence sheet (MC-33) | ClubConsequenceSheet | **left** | Still built, not mounted. Member removal and bans run through the governance command page, which already confirms; mounting the sheet in front of it would ask twice. Needs the governance command path to take the sheet as its confirmation. |
| `204:24591` create wizard (verify-r1 2.2) | CreateClubWizard | **partial** | `05-204-24591-club-create-step1-FIXTURE-d4-ops-create.png`: ✕ instead of the 关闭 text pill. **Left:** 下一步 pinned (the step state lives in a child of the Form; it needs lifting to pin with `safeAreaInset`). In the fixture host the bar glass draws light (grey circle); not checked on TEST because 9003 is at the club limit. |
| `223:3698` member sheet | MemberManageSheet | **left** | (2.6 邀请成员 still has no flow.) |
| `170:1744` club workbench | ClubWorkbenchView | **left** | |
| verify-r1 2.7 hairlines in club detail cards | — | **left** | |

## Gates

| Gate | Result |
|---|---|
| Build (Questify, Debug, Lane2, `OTHER_SWIFT_FLAGS=$(inherited) -disable-sandbox`, active arch, no indexing) | BUILD SUCCEEDED (final build after the lobby / topic follow-ups) |
| `tools/check_scaffold.py` | PASS (4893 Swift files, 16764 bilingual keys, project equivalence) |
| `tools/contract_ratchet.py --check` | 185 failing, baseline 184; the one "new" id is `test_workshop_paid_professional…bounded_paging`, already red on `ui/main` (r2-verify and integ-d-r1 receipts). No failure from this branch. |
| `tools/check_design_lint.py` | PASS (0 violations) |
| `tools/check_missing_string_keys.py`, `tools/check_a11y.py`, `build_design_r1_localizations.py --check` | 0 missing / PASS / CHECKED |
| Core `swift test --disable-sandbox` | 16974 tests (2 skipped); **27 unique failing tests = baseline 27**, none in code this branch touched. The changed `MerchantOnboardingContractTests.testIdentityStepBlocksAndIsSentOnlyWhenValid` passes. A first attempt was stopped at 17:37 on 11-16 when the shared disk fell to 176 MB free during the other worker's build; the second run (under a 6 GB disk guard, 11-18 03:23) completed, and its scratch build was deleted. |
| AppUnit, 4 shards via XcodeBuildMCP `test_sim` (xctestruns from the shard schemes) | tests (failed): 1868 (6) / 1979 (15) / 2070 (27) / 2032 (24); **72 failing names**. Against the r2-verify run's 74 names (its four DES-ag6 bundles, 19:30–19:36Z): **0 new**, 3 now pass (`MerchantOnboardingFixtureCounterTests.testReviewAndCancel…`, fixed by r2 after its run, and the two hosted-roam baseline names `RoamAnniversaryReadIntentTests.testActualRouteCoverForeground…` and `RoamPrivateReadDenialHostTests.testActualReceiptRefusal…`, which are intermittent). One name failed in shard 3 that is not in that list, `OwnAccountRefreshOrderingTests.testOlderSameRoleResponseCannotOverwriteNewerNickname`; re-run alone (OnlyTestIdentifiers) the whole class passes 12/12. It is the ordering class the burn-down receipt names for runner aborts in shard 3; this branch does not touch account refresh. |
| New tests | Core: consent holds back the identity fields and sends a JSON boolean. AppUnit: capsule for every domain, the identity step blocks on consent, the sheet-header style by domain; the HTTP journey asserts `"identityConsent":true` on the wire. |

Disk: the other code worker built in parallel; this worker's DerivedData (`DES-ag8-codeB`, 6.0 GB) was deleted once the
simulator work was done (free space 6.9 → 13 GB), and the stopped Core scratch build was deleted.

## Skipped or left (named, for the next round)

- Player: 首页, 发布 root, 我的 root, play HUD, 战报, 结算, share and new-badge screens, R1 error states, 收集册.
- Editor: topic editor rebuild and publish preview (3.4), Editor/Card collapse + footer + sheet header (rest of 3.5),
  C2 / C3 frames, the 2.10 media pickers.
- Merchant: workbench / 营销 / 模板 roots (Merchant/Root Header, 扫码), R5 cooperation pages, refund and station (3.6).
- Club: consequence sheet mount (3.8 second half), 下一步 pinned in the wizard, member sheet with 邀请成员, club
  workbench, hairlines in club detail cards, 邀请朋友加入 + share in the header (no flow exists).
- 2.5 leftovers: 俱乐部 pull-to-refresh instead of the refresh button; 消息 on 漫游 is worker A's root.
- The two copy items the owner parked were not touched (out of scope).

# Executor A+B (club) — coverage of review/r1-merchant-club.md groups A and B

File `0YyoybGnU1KG0657wdGCPX`. All new frames sit in row 1 of the route's existing section, right of the restored frames, 120 px gaps, label `<row> <state>` above; dark theme (MP-Dark); 393 wide (tall content drawn as one taller frame). Every frame carries an annotation with its spec id (B-Cxx-n) and anything that is a sample rather than seed data.

## State kit (shared)
R3 section `217:4466` "K 状态组件 · State kit": `K/State` 217:4511 (Error/Empty/Lock/Info), `K/Skeleton` 217:4574, `K/Inline Error` 217:8259, `K/Strip` 217:8268, `K/Result Pending Banner` 217:8272, `K/Alert` 217:8315 (Default/Destructive/Destructive · Input), sheet header 217:8316, `K/Result` 217:8336, `K/Option Row` 217:8351, `K/QR` 217:8352. Variable-bound: light inside an MP-Light frame. Details: `state-kit.md`.

## Frames drawn (spec items → frames)
| Spec | Section | Items in spec | Frames | Notes |
|---|---|---|---|---|
| B-C01 俱乐部 tab | R1 `96:3534` | 6 | 6 | 帖文, 帖文·空, 成员管理 sheet, 商家视角, 加载中, 更新中 |
| B-C02 俱乐部主页 | R3 `94:4778` (+ 管理 frames in `100:4257`) | 35 | 41 | tabs/visitor/approval/members/long board/sort, 6 管理 frames, 17 sheets, 4 generic |
| B-C03 主理人申请 | `94:945` | 8 | 9 | 新稿 H0 intro |
| B-C04 建团 | `94:946` | 10 | 13 | **Finding:** restored rows 063–066 show the apply flow (capture account not a host → redirect). Drew the real create steps 类型 / 方向 / 资料 / 城市 + results/gates |
| B-C05 俱乐部勋章 | `94:2802` | 7 | 7 | |
| B-C06 管理 tab blocks | `100:4257` | 4 | 4 | |
| B-C07 客户名册 | `94:2970` | 5 | 5 | generic |
| B-C08 客户详情 | `94:2845` | 6 | 6 | |
| B-C09 编辑资料 sheets | `94:5124` | 5 | 6 | + K9 放弃修改 |
| B-C10 报名名册 | `96:4263` | 5 | 5 | |
| B-C11 核销详情 | `96:4435` | 7 | 7 | |
| B-C12 活动运营 | `96:4495` | 13 | 14 | 已到场 and 未到场 split |
| B-C13 成员治理 | `97:3583` | 12 | 12 | |
| B-C14 团队核销码 | `97:3622` | 6 | 6 | |
| B-C15 入会申请 | `97:3656` | 5 | 5 | |
| B-C16 群发通知 | `97:3686` | 6 | 6 | |
| B-C17 个人收款 | `97:3781` | 6 | 6 | |
| B-C18 角色与权限 | `97:3807` | 9 | 9 | |
| B-C19 俱乐部结算 | `97:3844` | 6 | 6 | |
| B-C20 导演台 | `100:3823` | 27 | 30 | 7 state frames, 18 sheets/alerts, 4 generic, + 准备中·商家暂停 |
| B-C21 剧情与玩法 | `100:4051` | 7 | 7 | |
| B-N01 会费 | `233:3449` | 2 | 0 by me | already drawn by the group-E executor (233:3264, 233:3365); my duplicates removed |

Total new frames by this executor: about 216 (+ 10 kit components). Frame ids: `manifest.json` (partial) and the Figma sections above.

## Data and copy
Seed data from spec §4 (城瘾跑团, 海派城市漫游团, 南京东路猫咖驿站, ¥ amounts). Copy from the WXML/JS on `origin/integration/backend-app-r3`. Where the seed has no value, the frame shows a labelled sample and says so in its annotation (e.g. AI plan, long leaderboard numbers, rejection reasons, ticket rows). QA seed strings in restored frames (E2E 玩家小城, 13900000004, 商家二号) are replaced by 玩家小城 / 139****0004 / 申请人 9005 in my copies only; restored frames untouched.

## Other fixes made on the way
- `OPT/Tab Bar` selected tab was a solid white pill (icon + label invisible); set to ink 16% on R1/R6/N1/P (twice — something re-applies the solid fill; reported).
- `069 活动 · 空` CTA corrected to 发布主题 (WXML).
- R3 tidied: section heights fit their content, sections restacked with 240 px gaps, nothing loose.

## Not done / open
- Owner questions in spec §7 (merchant tab bar, 会费 route, merchantinfo tab names, club calendar) are outside A+B.
- No prototype wiring for the new frames (page P not touched).

# CB19 — public Codex branch triage

Base: `origin/rc/20261108` `67053ccb33c0e1ad35a7508f8546ae9076fd82e5` (RC tree `3588b12a8e8a2be199618de31c6df1b15ed4d3cf`).
Public tips: `liboyang42-cpu/chengyin-ios` `refs/heads/codex/*`, 93 branches, read 2026-11-08 PT.
Nothing was merged. Nothing was pushed to `main`, `master`, `rc/20261108`, or any `codex/*` branch.
No deploy. No view edit. `tools/current_ci_manifest.json` was not refreshed.

## Counts

| class | count |
|---|---:|
| merge-now | 0 |
| skip | 13 |
| needs-change | 80 |

## Rule

The release gate on this RC is not green, so this lane classifies only. A branch is not merged here even if it is merge-now. The gate fact is the one recorded for this RC (manifest audit / CI ledger still the known-red item; this lane did not re-run the gate and did not refresh the ledger).

For each public tip, `git merge-tree --write-tree 67053ccb33c0e1ad35a7508f8546ae9076fd82e5 <tip>` merges that tip into the RC:

1. **skip** — the tip is an ancestor of the RC, or the merge exits 0 and the result tree equals the RC tree `3588b12a8e8a2be199618de31c6df1b15ed4d3cf`. The branch does not change the RC.
2. **needs-change** — the merge exits 1 (conflicts). The branch has to be replayed onto this RC before it can be taken. A conflict-free merge whose result diff breaks a hard rule is also needs-change. No conflict-free merge changed the RC tree, so the hard-rule scan did not move any branch.
3. **merge-now** — the merge exits 0, the result tree differs from the RC, and the result diff (`git diff 67053ccb33c0e1ad35a7508f8546ae9076fd82e5 <result-tree>`) breaks none of the hard rules below. Those branches stay unmerged until the gate is green.

Hard rules that demote a conflict-free diff from merge-now to needs-change:

- CI ledger (`tools/current_ci_manifest.json`) or a gitleaks allowlist change.
- A workflow edit under `.github/workflows/`.
- A committed secret, a production deploy, or a production write.
- A deleted, skipped, or loosened test.
- Password login enabled in Release.
- A payment, payout, withdrawal, or virtual-goods write that is not behind its own switch.
- A gem wallet, a skip button, or a publishable accusation.
- `makeComposition(reviewed:)` turned on (safety gates stay off until WIRE-1).
- A view restyle. Visual UI stays with the coordinator.

## skip (13)

| branch | tip | why |
|---|---|---|
| `codex/ios-main-integration-20261101` | `f9ca1f42405122d54561193546a351753ac63c8b` | tip is an ancestor of the RC |
| `codex/ui-public-20261103-b02` | `83221a2cb5e363dc9b94fece7dcbeae31b7a38fd` | conflict-free merge, result tree equals the RC |
| `codex/ui-public-20261103-cl01` | `1c52eb0a5a29fefd9d6cabb64eb720125c4f08d3` | conflict-free merge, result tree equals the RC |
| `codex/ui-public-20261103-cl03` | `253106e668fb32c387a67ab3974b29a9fc3c0694` | conflict-free merge, result tree equals the RC |
| `codex/ui-public-20261103-d01` | `e46c1c20c13d98846967d3613048788abc5ff054` | conflict-free merge, result tree equals the RC |
| `codex/ui-public-20261103-g02` | `c4de07bf0e498f1442a065e09f7fc64a2d4b95b6` | conflict-free merge, result tree equals the RC |
| `codex/ui-public-20261103-g05` | `884ea88325e46b363509199b3cb433b8677ffac9` | conflict-free merge, result tree equals the RC |
| `codex/ui-public-20261103-g09` | `d369457f74e3e85abe6458ddfd8685f86d6df1a4` | conflict-free merge, result tree equals the RC |
| `codex/ui-public-20261103-m04` | `76e72fd833140f56344ef5ab9d0085a7e24250c7` | conflict-free merge, result tree equals the RC |
| `codex/ui-public-20261103-s01` | `4f703a019c38aa3f7ed1877104e0b52705f9ce17` | conflict-free merge, result tree equals the RC |
| `codex/ui-public-20261103-t01` | `e9ac9ff91130f154d38836be4e387902d0d46ce2` | conflict-free merge, result tree equals the RC |
| `codex/ui-public-20261103-t02` | `d7756eaede691172b43770c4d0dd4f27ac5a973d` | conflict-free merge, result tree equals the RC |
| `codex/ui-public-20261103-w01` | `fb41609c5cf5fb444c86521df2f52d6164cc7d04` | conflict-free merge, result tree equals the RC |

## needs-change (80)

| branch | tip | subject |
|---|---|---|
| `codex/b03-workshop-localization-20261105` | `06db0d9c7bcb7ce7db1b9d0e72b1fc6c6a7a309e` | Localize workshop upgrade presentation in English and Chinese |
| `codex/claude-review-61cfe710-20261104` | `7691588efe5f66c32af5001ebcb6bd3b3de49d05` | Publish complete source snapshot for review [skip ci] |
| `codex/commerce-order-summary-20261108` | `fdc091dfa46ceda5dc481ad08615164a1936b58e` | fix: retire stale merchant order summaries |
| `codex/ios-ci-repairs-20261105` | `ebbd3007f12b952eca69caf0079d6dbc3a278aa3` | ci: integrate exact finding audit and non-crashing failure diagnostics |
| `codex/ios-ci-strings-20261105` | `1a9ed8c05c868a2c355e466af98b9b5c2851e2b9` | Merge reviewed D1 and D2 catalog keys into isolated CI candidate |
| `codex/ios-core-failure-diagnostics-20261105` | `15b5d951dc671467ef517324e71af30151ae5a80` | test: preserve friend review failures without array trap |
| `codex/ios-gitleaks-exact-20261105` | `bce0504fb23012af2843aa306d8eb187fffb1b69` | ci: document four exact historical noncredential findings |
| `codex/ios-route-map-a11y-20261105` | `ee8fa447e59b5427ca3c08fb96bcd376ce033543` | test: use route map list control before equivalent stop navigation |
| `codex/l1-channel-test-symbols-20261104` | `7f29f907aa418749cb9f2f8349c66a3e673c6e6c` | test: correct channel ancestor fence production type references [skip ci] |
| `codex/l1-string-reconcile-20261105` | `7cb4d0f2054deff80240ed16622b5382ca2d4bc5` | fix: 逐键恢复钱包收益与漫游文案并保留 D6 修改 |
| `codex/l10-city-receipt-recovery` | `b56c4662b7b5140d2b915c46224faf7657bffea8` | docs(city): record exact remaining L10 dependencies and stop decision [skip ci] |
| `codex/l11-package-safety` | `48d64deae2f2dbb82b244116439bf064a5b922ba` | fix(l11): 安装原请求恢复拒绝后退场并保留持久意图 [skip ci] |
| `codex/l12-business-time-20261104` | `1a9e62ee50057b7213960ebebf4ab471c3164c4f` | Document L12 time validation, project handoff and remaining launch gaps [skip ci] |
| `codex/l12-official-device-dates-20261104` | `2a0ed4e5efedabcc5983c8321acdd4fd53544af9` | Record L12 market browse verification and acceptance gaps [skip ci] |
| `codex/l2-environment-inputs-eec-20261104` | `401626ef5949ec24de4bf0de9b9c93c7e0326ec1` | fix(config): isolate market and environment build inputs [skip ci] |
| `codex/l3-arb-import-safety-20261104` | `14e0ca8b37829c157d825349bfbbe0d6fbcf0a86` | fix(tools): preserve ARB import inputs and candidate output pairs [skip ci] |
| `codex/l3-localization-fragment-validation` | `c21484d5d7d65516b79192b5b3f2e70e0c24dca4` | Reject ambiguous localization fragments before catalog writes [skip ci] |
| `codex/l4-free-explore-integration-20261105` | `7fac954b16004214de953b9708ca6de6ce8d4f9b` | fix: 预约权限关闭时不创建未知操作并保留原回执恢复 [skip ci] |
| `codex/l4-free-explore-recovery-20261104` | `124aa7c53d68d442134e1d21b2ded3ab0a2900ab` | feat: 补齐自由探索原预约回执恢复与冻结合同交接 [skip ci] |
| `codex/l4-invoice-c6-recovery-20261105` | `bc2fa605ed868269f418ae954c82cf5524df81fb` | fix(invoice): align c6 string identifiers and gated original request recovery |
| `codex/l4-invoice-followup-20261105` | `d8bac81d6f80ac71898a4c1b69a6a5a16fbc9cf0` | feat: 迁移发票链路并保留回读不确定状态 [skip ci] |
| `codex/l4-invoice-launch` | `533b2a5c53bb19d7c0386ecc41b575c818498207` | feat: 按冻结合同接入发票与未知结果恢复 [skip ci] |
| `codex/l4-invoice-save-readback-20261105` | `09c3fe9fd0cd2a98d1f649ec70e22fc90277d2d3` | fix: 持久化已确认抬头并校验删除回执 [skip ci] |
| `codex/l4-invoice-ui-20261105` | `b78b872744678a6298624be5775d92d22ae737e5` | feat(invoice): add gated native invoice pages without shared wiring |
| `codex/l4-order-readback-owner-20261104` | `d4353b90ed8f9198326169f316810f643463898e` | fix(commerce): bind order readback to captured buyer [skip ci] |
| `codex/l4-registration-receipt-recovery-20261104` | `a03001f56455e13c547ea6349890ccd718738bbe` | fix: accept frozen registration consent absence before first agreement [skip ci] |
| `codex/l4-registration-supplemental-20261104` | `da18e17f64789d397a0c3d8903f8fe8f74922ce8` | feat(commerce): add three registration read adapters [skip ci] |
| `codex/l4-ticket-owner-readback-20261104` | `5f61523185894046efd3db18a226f5e0f27c2e4c` | Bind ticket detail readback to captured buyer [skip ci] |
| `codex/l5-advanced-durable-recovery-20261104` | `3bd955eb5d68ffdeeaa656ab5f8eac3d5b1ad904` | Preserve advanced original requests in isolated durable recovery [skip ci] |
| `codex/l5-advanced-original-recovery-20261104` | `02e39a739ebc48cbffab207eabbc1c725f59672f` | fix(play): preserve unresolved advanced originals on recovery errors [skip ci] |
| `codex/l5-backpack-scope-receipt-fix-20261104` | `06839e66134f085c1136784d3672f61b1ee363d7` | fix(play): retain unknown backpack actions on mismatched scope receipts [skip ci] |
| `codex/l5-circle-unknown-readback-20261104` | `c7c2ffc571b1ca8c3581633d276b29e882e8b1dc` | Keep unacknowledged circle writes unknown on shared card reads [skip ci] |
| `codex/l5-map-public-recovery-20261104` | `9f5cb05b56d43dda822b0f9b58ba99b0e81a79f3` | test: 修复地图恢复测试的 MainActor 异步发现 [skip ci] |
| `codex/l5-orient-followup-20261105` | `13714dd37dfa9353ddb52de7aad306c413fee729` | feat: 补齐定向会话发现选择与原键恢复 [skip ci] |
| `codex/l5-orient-scoring-20261105` | `fc9a0a2a95a1514fe8efad74e8d30fad6136fd79` | feat: 补齐定向计分同步个人榜与申诉恢复 [skip ci] |
| `codex/l5-orient-session-20261104` | `b5db490454a4b4393ccb1b724068aed24d215e18` | feat: 接入冻结合同的定向会话与持久恢复 [skip ci] |
| `codex/l5-personal-theme-backpack-20261104` | `06f2ad5485a6a185b1e410aa3a65ca0d3060631c` | feat(play): add personal backpack actions and durable recovery [skip ci] |
| `codex/l5-player-admission-20261104` | `4225bd2282b4c1b10810fc27911bd27415f22b5c` | Fix player submission admission and read lifetime [skip ci] |
| `codex/l6-coop-settlement-read-journey` | `c70e805ea303d95f4e3a16cf5728b44840ec4696` | docs(l6): record settlement journey tests and native validation limits [skip ci] |
| `codex/l6-review-unknown-readback` | `5249ed14b4ce816739a17aadb4a4425fc9bd6f82` | feat(l6): expose review current-state recovery and integration evidence [skip ci] |
| `codex/l7-backend-contract-audit-20261104` | `24d3f275d225e629dfaab1f12ce63f4dd0c1feae` | docs: 核验 L7 后端基线及入会合同边界 [skip ci] |
| `codex/l8-chain-gap-closure-20261105` | `d2c5e2a7471a988d5422eec9f882d7b6271bdb79` | fix: close channel chain lifecycle and scope gaps [skip ci] |
| `codex/l8-chain-launch-recovery` | `0d42ce6d49350f3393f19cf55474dee658105a2b` | fix: preserve chain recovery intent and reject conflicting roster pages [skip ci] |
| `codex/l8-chain-migration-20261105` | `1658f9dc9d9e0bf967002489424619f0c8f9c6c5` | fix: carry verified chain recovery patch onto launch integration base [skip ci] |
| `codex/l8-checkin-launch-20261104` | `8d16eadcc6c292bf976e0b467c46c76e3c631f03` | fix: fence channel check-in recovery and server snapshots [skip ci] |
| `codex/l8-checkin-recovery-gaps-20261105` | `72d083c3ead37c884a227f365596595afe82b3b1` | fix: preserve check-in receipts across errors and recovery visits [skip ci] |
| `codex/l8-history-gap-20261105` | `10183b220cd9e9f331ca012a2e013f88fd5a5435` | 修复: 补齐频道历史失效清理与已读回执状态 [skip ci] |
| `codex/l8-history-launch` | `096f78aa9bfd2ccacbf97bbc9e99d4381812eeed` | Fix channel history overlap and rejected-read recovery [skip ci] |
| `codex/l8-message-context-launch` | `ba46bd4fd7d46e446612ddc56fc561b82aac34fb` | fix: fence channel message context and validate navigation cursors [skip ci] |
| `codex/l8-message-projection-safety` | `9649e087fcf824142124e37ff0ef0ce9f903f707` | Fix channel unknown-message and stale-history isolation [skip ci] |
| `codex/l8-message-search-lifecycle` | `f892e1b805836b39b35f4f79cfb5d741c4e1031f` | Fence channel search caches and cancelled reads [skip ci] |
| `codex/l8-text-lifecycle-recovery-20261104` | `49034ee13e67d4fc824184a65779f7d44f5e04cf` | fix(l8): release retired text recovery leases without losing originals [skip ci] |
| `codex/l9-original-recovery-20261104` | `5d4a6b9f1c0c0e944d649f5646f502efd6c5ab96` | fix: 完整串行化系统通知权限生命周期与恢复 [skip ci] |
| `codex/owned-order-auth-correlation-20261108` | `7f702e2e675cf0613f64fc972cfccfe70557c4b9` | fix: correlate owned order read grants with current sign-in facts |
| `codex/owned-order-read-recovery-20261108` | `dcf7ff0313312c8a72460b489d2f2c198d6b007e` | fix: bind owned order presentation to reader and requested detail |
| `codex/owned-order-refund-facts-20261108` | `b917eb53d30b101406b3fdc1591c83323b215ee5` | feat: show owned order refund facts with explicit unknowns |
| `codex/p03-zerohp-20261105` | `11bc7c0ae67feaaa1ce5f8d25b72ff9f71f294e3` | fix: restore ZeroHP author candidate and state regressions [skip ci] |
| `codex/points-entry-recovery-20261108` | `33875fe53af92624dd29d78d087b6dc715285b86` | fix: fence wallet asset entry reads and recover current-owner failures |
| `codex/points-ledger-20261108` | `5dbe02dca67bd35917e8dd9cea9ac12cdbd49bbe` | docs: preserve registration hunk in portable JSON handoff |
| `codex/qa-receipt-recovery-20261108` | `68626f0c31162a0108df9eaf3d658c9f09cb83fd` | Add ordinary text QA original receipt recovery with isolated integration patch |
| `codex/qa-restart-receipt-20261108` | `f70c21008df877a374137407c0e59e8193c0308a` | Add redacted text QA restart journal and original receipt recovery handoff |
| `codex/qa-text-input-20261108` | `9c11addfc82c8ce7c7989247aac4046216b140b5` | Fence text QA content after read authority is withdrawn |
| `codex/recover-native-text-draft-20261104` | `e681843c1644074bdca49beead62511793003d4d` | Preserve native text draft recovery patch [skip ci] |
| `codex/story-audio-review-boundary-20261108` | `0f82e4c662fb6c4809684c27d2d17e4aa839cbb0` | fix: bind story audio review to source and retire interrupted consent |
| `codex/ui-public-20261103-b03` | `3db8cb9bf0604d095a03b77dbe5a487057ad9c32` | feat(ui): 改善工坊免费库状态与包详情提示 [skip ci] |
| `codex/ui-public-20261103-cl02` | `e800f2751ef044c054fdf19062d00d0ef4713cf4` | fix(ui): 改善俱乐部选择与反馈文字布局 [skip ci] |
| `codex/ui-public-20261103-g01` | `e9943dc784402dbc487c66b0155860b8df272878` | style(ui): 优化参与和游玩页面排版 [skip ci] |
| `codex/ui-public-20261103-g08` | `d0728a2657760bf0fb5b9f5848012b435d8aa058` | fix(ui): 改善地图状态提示与标题层级 [skip ci] |
| `codex/ui-public-20261103-i02` | `04b510cea844b4bbc612e5eb78c3f01007bf2351` | fix(ui): 改善资料草稿前后值的长文排版 [skip ci] |
| `codex/ui-public-20261103-m02` | `9d6d143e2fb250dd32c5b16e077a333dd0cd20af` | fix(ui): 优化商家评价照片、券表单和公开信息布局 [skip ci] |
| `codex/ui-public-20261103-m06` | `f354c399669791e8953b130942e159fe54e466b8` | style(ios): refine merchant template browsing and suggestion editing [skip ci] |
| `codex/ui-public-20261103-p02` | `15442058cf0c34be8f156bfa287cc7b59af7c315` | Improve editor form layout and accessibility [skip ci] |
| `codex/ui-public-20261103-p04` | `5f5f42fe755acc400299c7a08a485869265d7412` | ui: improve review and release text layout [skip ci] |
| `codex/ui-public-20261103-s02` | `9e5fe6d01e63a13b45a7df3416a0e64379c1d419` | fix(ui): improve message hint wrapping and list row sizing [skip ci] |
| `codex/ui-public-20261103-s04` | `cbcc46f9412bc6935a24fcac36437091e821e897` | fix(ui): improve poll option touch target and selection accessibility [skip ci] |
| `codex/ui-public-20261103-w02` | `5a434eb53964e75f433000923ffe96861983cf24` | fix(ui): 为空快照字段显示说明 [skip ci] |
| `codex/ui-public-20261103-x01` | `708690f4f638ae9ad8164a6ee45fb4f477d42c92` | style(ios): improve cooperation form and calendar readability [skip ci] |
| `codex/withdrawal-history-recovery-20261108` | `29114d24bad5433b4e9aab0625d60334a372eecf` | fix: present withdrawal history facts with scoped read recovery |
| `codex/withdrawal-support-recovery-20261108` | `48ac5f9c110607ef4105d71da71b358fa0f99d2a` | fix: bind withdrawal support reads and recovery to the current owner |
| `codex/word-fill-format-20261108` | `3ce17773c7a4a8906cbb0c21321d16d08390bdd8` | Add gated word-fill format parsing and native input |

## merge-now (0)

No public `codex/*` tip merges into this RC without conflicts and without an empty result.

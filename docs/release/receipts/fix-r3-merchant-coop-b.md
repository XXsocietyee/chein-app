# Receipt: fix/r3-merchant-coop-b (Claude F-agent, merchant-coop half b)

- **Brief:** `origin/design/handoff-r2:docs/briefs/wave-x10.md`
- **Base:** `origin/ui/combined-r7` @ 7fdfad1f1, with `origin/restyle/r3-merchant-creator` merged first (the brief says to build on the area's restyle branch).
- **Gap source:** `origin/audit/parity-r7-merchant-coop:docs/audit/parity-r7/merchant-coop.md`, FIX QUEUE rows owned by Claude.
- **Half b:** round-1 audit pages 19–35: `merchant/decor`, `decor/gallery`, `decor/perks`, `decor/coop-setting`, `decor/ai-npc`, `citynode`, `citynode/create`, `game-node`, `coop-center`, `relation`, `team`, `coop/list`, `coop/invite`, `coop/invite-detail`, `coop/nearby`, `coop/finance`, `coop/settlement-detail`.
  - The audit lists 35 pages, so "half" is ambiguous. `merchant/predict` (page 18) is left to half a.
- **Layer:** App/ only. No Core types were changed. The Core requests for Cursor are listed below.
- **Strings:** `docs/port/strings/fix-r3-merchant-coop-b.json`, 24 keys in xcstrings format. `Localizable.xcstrings` was not edited.
  - One value was changed in the separate `Resources/MerchantCityNode.xcstrings` table: `merchantCityNode.poster.hintPrint` zh 长按保存后张贴，长期有效 → 保存后张贴，长期有效 (MC7-24-3).
- **Fixture routes:** `docs/port/accept/f-merchant-coop-b.txt`.

## Shared piece (new file)
`App/MerchantCoopStateActions.swift`:
- environment hooks `merchantOpenApplication` and `merchantOpenSignIn`;
- `MerchantCoopActionState`, `MerchantCoopSignInState` and `MerchantCoopApplyState`. These are native `ContentUnavailableView` states with a 44 pt action.
- Sign-in falls back to `rootTabSwitch(.mine)`. A nil hook hides the button, so there is never a dead button.
- `MerchantHomeView` injects both hooks into the merchant stack (`openApplication` and `openSignIn`).

## Fixed
| id | page | what | files |
|---|---|---|---|
| MC7-19-3 | decor | Inactive identity: 去商家入驻 CTA. The extra 暂无有效经营身份 line is removed. | MerchantOperationsViews.swift |
| MC7-19-5 | decor | Denied state title 当前身份不能装修店铺 | MerchantOperationsViews.swift |
| MC7-19-6 | decor | Error state title 品牌中心加载失败 | MerchantOperationsViews.swift |
| MC7-20-2 | gallery | Uploads automatically on crop confirm and appends to the grid. The 确认上传 / 使用 steps, the realm line and the byte-count line are gone. | MerchantGalleryBatchView.swift |
| MC7-20-3 | gallery | Per-tile VoiceOver label 删除第N张图片 | MerchantGalleryGrid.swift |
| MC7-21-1 | perks | ¥ with two decimals and monospaced digits | MerchantPerkTemplatesView.swift |
| MC7-21-2 | perks | The form stays open while saving and closes on `.saved`. A failed or unconfirmed save shows inline with 重新查询. | MerchantPerkTemplatesView.swift |
| MC7-21-3 | perks | 重试删除 on the failed-delete banner | MerchantPerkTemplatesView.swift |
| MC7-21-4 | perks | Error title 权益加载失败 | MerchantPerkTemplatesView.swift |
| MC7-21-5 | perks | A hint under each invalid field | MerchantPerkTemplatesView.swift |
| MC7-21-6 | perks | `EditButton` and `onDelete`, so delete works without swipe. It still goes through the existing confirm. | MerchantPerkTemplatesView.swift |
| MC7-22-2 | coop-setting | After an acknowledged save: toast 承接设置已保存, then back to 品牌中心 | MerchantOperationsEditor.swift |
| MC7-23-3 | ai-npc | The saved photo avatar renders through AsyncImage. Only absolute https URLs load; a relative path keeps the placeholder. | MerchantStoreCharacterView.swift |
| MC7-23-4 | ai-npc | 性格设定 is a three-option list (温柔 / 可爱 / 毒舌). A tap saves through the existing confirm. | MerchantStoreCharacterView.swift |
| MC7-23-5 (part) | ai-npc | 试听原录音 / 暂停试听 of the enrolled sample (AVPlayer) | MerchantStoreCharacterView.swift |
| MC7-24-2 | citynode | 投放节点, 认领节点 and 上架/下线 show only with `merchant:project:manage`. If there is no access reader, or the read fails, they stay as before. | MerchantCityNodeHubView.swift |
| MC7-24-3 | citynode | ShareLink 保存打卡码 for the poster; hint copy is 保存后张贴 | MerchantCityNodeHubView.swift, MerchantCityNode.xcstrings |
| MC7-25-2 | citynode/create | 登录 opens sign-in (hook or 我的 tab). With neither available it is labelled 返回. | MerchantCityNodeCreateView.swift |
| MC7-26-3 | game-node | A playable station shows 本站运行 before the runbook | MerchantGameNodeView.swift |
| MC7-26-5 | game-node | No runbook card for a ROUTE station without a player task | MerchantGameNodeView.swift |
| MC7-27-2 | coop-center | The whole route card is the link. 看详情 is now a visual label. | MerchantCoopCenterView.swift |
| MC7-27-4 | coop-center | A failed refresh over a shown list keeps the list and shows a toast | MerchantCoopCenterView.swift |
| MC7-28-4 | relation | 合作 tab denied state: 申请入驻 | MerchantHomeView.swift (`MerchantFailureView.apply`), HomeSearchTabParityViews.swift |
| MC7-28-5 | relation | 重新加载 under the partial notice | CoopRelationDiscoveryView.swift |
| MC7-29-1 | team | Signed out: 登录后查看经营团队 + 登录 | MerchantBusinessViews.swift |
| MC7-29-2 | team | Denied: 当前身份不能查看经营团队 + 申请入驻 | MerchantBusinessViews.swift |
| MC7-29-7 (part) | team | Member actions in a trailing Menu (岗位…, divider, 移除) | MerchantBusinessViews.swift |
| MC7-29-11 | team | 邀请员工 is hidden unless `reader.canExecute(.inviteOperator…)` | MerchantBusinessViews.swift |
| MC7-30-1 / MC7-31-1 | coop list / invite | Signed-out issue: 去登录. The invite page shows one signed-out state. | CooperationComponents.swift, CooperationContextualViews.swift |
| MC7-30-3 | coop list | Removed the info-coloured action label from chapter-application rows, because the rows have no destination | CoopListParitySections.swift |
| MC7-31-5 | coop invite | Empty target list: 刷新合作对象 | CooperationContextualViews.swift |
| MC7-32-2 (part) | invite-detail | Real invite cover, dimmed when status ≥ 2 | CooperationInviteDetailView.swift |
| MC7-32-4 | invite-detail | 进入项目 links to the project destination when the list provides one | CooperationInviteActionSections.swift |
| MC7-33-7 | nearby | Empty state: 刷新附近商家 | NearbyMerchantView.swift |
| MC7-33-8 | nearby | Guest: 登录后查看附近商家 + 登录 | NearbyMerchantView.swift |
| MC7-34-2 | finance | Workbench row reads 分润明细. The accessibility id is unchanged. | CooperationFlowWorkbench.swift |

## Tests touched (re-pins and one assertion change, with comments in the files)
- `test_merchant_station_submission_import.py`: `App/MerchantOperationsViews.swift` sha re-pinned (MC7-19 states).
- `test_coop_fixture_lifecycle_diagnostic.py`: CoopRelationDiscoveryView normalized hash re-pinned (MC7-28-5).
- `test_retained_image_localization.py`: `MerchantGalleryBatchView` no longer has to show the realm and byte count. The new assertion is that it shows neither. `RetainedImageSelectionView` is still pinned (MC7-20-2).
- **Result:** in the 96 ContractChecks modules that reference changed files, run one module at a time against the merged base, there are **0 new failures** (base 176 failing → branch 176, the same set).
  - These modules cover the App files changed here, but not `Tests/ContractChecks/` as a whole.
  - The full-directory run was stopped part-way, so this check covers only those modules.
- `tools/check_typography_lint.py` PASS.
- `tools/check_scaffold.py` fails identically on the base, because the project needs regenerating (coordinator).

## Left, with reasons
**Owner / gate (not code):**
- MC7-23-1, 24-1, 25-1, 26-1, 29-3, 29-8: endpoint review and approvals.
- MC7-29-9 and 29-10 depend on 29-8 being supplied.

**Gemini:** MC7-33-4 and 33-5 (MC-G18 nearby 补位).

**Reverted because a contract test pins the opposite behaviour (owner or Cursor ruling needed):**
- MC7-29-6 (share the invite code): `test_merchant_operator_invitation_receipt` requires the code to stay memory-only, with no ShareLink and no clipboard.
- MC7-34-1 (player theme for finance): `test_global_chrome_domain_contract` requires a merchant domain on coop screens.

**Needs Core (request for `cursor/core-merchant-coop`):**
- MC7-23-5: a 清除声音 command for `npc/voice/reset`, with confirm.
- MC7-23-3: a base URL to resolve site-relative avatar paths.
- MC7-23-4: the `personality` enum (gentle / cute / savage) in the save payload. Today the Chinese label goes into `persona`, as in the MP fallback.
- MC7-27-3 and MC7-28-7: `MiniProgramPageLink` rules for coop-center (`tab`, `topicId`) and relation (`tab`, `topicId`).
- MC7-28-6: keep `CoopRelationDiscoveryModel.value` across a reload. Its `invalidate()` clears it.
- MC7-29-4: a reader for `operators/invite/preview` on `MerchantEngagementReading`.
- MC7-33-3: keep the nearby rows on a refresh failure.
- MC7-33-6: venue fields (cover, hours, capacity, 收费, suit types, coordinates) on `NearbyMerchantRow`.
- MC7-22-2: the coop-profile save has no readback (Core acknowledges only), so the auto-back runs on the acknowledgement.
- MC7-24-5 and MC7-25-3: the city-node hub and create screens do not know `identity.active` when denied, so 申请入驻 vs 返回 cannot be chosen.

**Deferred to other areas:**
- MC7-28-3 (`ClubCommunityViews.swift`): a club-owned file that `restyle/r2-club-social` also touched. Club F-agent.

**Not done this run (P2, or M-size that needs flow design):**
- MC7-19-2, 19-4, 19-7, 19-8, 19-9, 19-10 (decor hub rows, category multi-select, licence preview, inline toggle).
- MC7-27-1 (bell → 消息 home).
- MC7-29-7 header and avatar part.
- MC7-30-4, 30-5, 30-13 (invite card layout, copy phone, all-empty state).
- MC7-31-2 and 31-8 (unknown-outcome 原请求 and a send summary).
- MC7-32-1 and 32-5 (missing-invite copy, IM after contact).
- MC7-33-1 and 33-2 (topic title, consent persistence).

**In-flight branches:** `restyle/r3-merchant-creator` was merged as the base. `gap/*`, `cursor/*` and `port/*` were not touched.

## Acceptance
There is no compiler in the cloud. Every API used was grepped on the base. The coordinator compiles and returns exact errors.

---

# Round 2 (2026-11-24)

- **Brief:** `origin/design/handoff-r2:docs/briefs/fix-r3-round2.md`, plus `wave-x10.md` and `owner-decisions-1124.md`.
- **Sync:** merged `origin/ui/combined-r7` @ 97ee2bc9e. The one conflict, `tools/check_typography_lint.py`, was taken from r7.
- **The brief says r7 already has the K-branches and the C7 assets. It does not:** neither `cursor/mp-assets` nor `cursor/core-merchant-coop` is an ancestor of `ui/combined-r7` @ 97ee2bc9e. Both are merged into this branch so the APIs used here exist:
  - `origin/cursor/mp-assets` @ 05d527e12 (C7). One conflict in `tools/generate_project.py`: kept r7's `App/MPGap/**` glob and added `App/MPAssets/*.swift`.
  - `origin/cursor/core-merchant-coop` @ c9cbcd24b (K3). Clean merge.
  - Coordinator: these merge cleanly again when they land on r7.
- **Strings:** `docs/port/strings/fix-r3-merchant-coop-b.json`, now 60 keys (en + zh-Hans).
- **New App files** (covered by the `App/*.swift` glob): `CoopSupplyStationAcceptView.swift`, `CoopClubSettlementDetailView.swift`.

## MP assets (rows of `docs/mp-assets/mapping.md` applied)
- [x] `MPAsset.FeatureIcon.convenienceStore`, `.sparkles`, `.wavingHand`, `.speechBalloon`, `.forkAndKnifeWithPlate`, `.alarmClock`, `.nameBadge`, `.performingArts`: the ai-npc first-visit intro (MP `introSteps`) was missing in the app. It is now `StoreCharacterIntroSheet` in `MerchantStoreCharacterView.swift`: four paged steps, 跳过 / 下一步 / 知道了, and the seen flag `cy_ai_npc_intro_seen` (catalogued in `docs/ops-safety/client-data-catalog.json`).
- [x] `MPAsset.AvatarDefault.dProfile`: team member rows (MP team/index.wxml:65 `item.avatar || d_profile`). `MerchantCoopMPThumb` loads an https avatar and otherwise shows the MP default (`MerchantBusinessViews.swift`).
- [x] `MPAsset.BrandLogo.dLogo`: invite target rows (MP coop/invite/index.wxml:93,106). The candidate has no decoded `logo` yet, so the MP default always shows (Core request below).
- Not mine or not applicable:
  - The `MerchantBusinessViews.swift` reviews/customer icons are half-a pages (reviews, customer).
  - `iconBell`: the MP coop-center bell is `cy-icon`, not this asset.
  - `MerchantHomeView` rows are half a.
  - The relation composer avatar is in the club-owned feed composer (MC7-28-3).
  - Nearby venue card art needs MC7-33-6 Core fields.

## Fixed in round 2
| id | what | files |
|---|---|---|
| MC7-19-2 | 经营类目 is a multi-select of the MP `PREFERENCE_OPTIONS` plus any existing values, joined with 、, inside the existing field sheet (same limit, save and discard) | MerchantStoreFieldEntry.swift |
| MC7-24-4 | The decor 城市节点 row pushes the city-node hub (`merchantCityNodeHubDestination`). The old list remains only as the fallback when the hub is not injected. | MerchantOperationsViews.swift |
| MC7-24-1 / MC7-25-1 (interim) | With every city-node write path closed: one notice, and 投放 / 认领 / 撤回 / 上下线 are hidden instead of only toasting. The offline fixtures keep them. | MerchantCityNodeHubView.swift |
| MC7-26-1 (interim) | With writes closed, the existing notice replaces the invite, ready, pause, resume and verify actions (hidden, not disabled) | MerchantGameNodeView.swift |
| MC7-23-1 (interim) | 保存暂未开放 notice shown up front when `canSave` is false | MerchantStoreCharacterView.swift |
| MC7-26-4 (App) | Per-field errors under 准备清单, 接待容量, 服务日期 and 服务时段 from `readyFieldIssues`, after 确认准备完成 is tapped. Submit still goes through `ready()`. | MerchantGameNodeView.swift |
| MC7-27-1 | The coop-center bell pushes 消息 home (`SessionMessagingHome`). The sheet stays as the fallback. | MerchantCoopCenterView.swift, MerchantCoopCenterSessionBinding.swift |
| MC7-31-2 | 原请求 shows only after an unknown-outcome send (preview → `coopInviteOutcomeUnknown`), with the MP warning and human row copy (邀请已创建 / 结果仍待确认). Raw state and requestId are hidden. | CooperationContextualViews.swift, CooperationFlowEditors.swift |
| MC7-32-1 | Missing invite shows 这条邀约不在当前列表里了 + 回协作邀请 | CooperationComponents.swift, CooperationInviteDetailView.swift |
| MC7-32-3 (App) | 核销据点 row in 合作条款 (name, or 据点 #id), with the MP lock note | CooperationInviteDetailView.swift |
| MC7-30-6 (App) | Accept on a station invite → confirm screen + dialog → `CoopFlowService.acceptSupplyStation`. Same `ReviewedAreaSwitch.merchantWrites` gate and per-op `.handle` approval as every accept, so production stays closed and the button is disabled with 暂不可提交. No `.handle` 3-arg change. | CoopSupplyStationAcceptView.swift, CooperationInviteActionSections.swift, CoopFlowPreviewWrite.swift |
| MC7-32-5 | After 联系对方 succeeds, the preview pushes the returned `conversationId` chat (`MessagingHistoryView`, injected as `coopConversationDestination`) | CooperationFlowEditors.swift, QuestifyApp.swift |
| MC7-34-3 | Deep link `pages/coop/finance/index` → `CoopFinanceProfitView` (+ wallet reader) | MPReviewedPageScreen.swift |
| MC7-35-2 | Deep link `pages/coop/settlement-detail/index` → `MerchantSettlementDetailLink.resolve`. finance/ledger go to `CoopSettlementDetailView`. Missing params show 缺少结算记录信息 + 返回. | MPReviewedPageScreen.swift |
| MC7-35-1 (App) | `source=club` → `CoopClubSettlementDetailView`: reads `.clubSettlementSummary(clubID:personal:)`, finds the row by the link's record key, renders `CoopClubSettlementDetail` (MP `buildClubSettlementDetail` labels). States: loading, 结算记录不可见, and 结算详情加载失败 + 重试. No withdrawal. | CoopClubSettlementDetailView.swift |
| MC7-32-7 | Deep link invite-detail `inviteId` + `box` | MPReviewedPageScreen.swift |
| MC7-30-2 (part) | Deep link coop list opens on the linked `tab` | MPReviewedPageScreen.swift |
| MC7-31-10 (part) | Deep link `pages/coop/invite/index` opens the new-invitation page | MPReviewedPageScreen.swift |
| MC7-29-12 | Deep link `pages/merchant/team/index?invite=` → `MerchantOperatorInvitationLandingView` | MPReviewedPageScreen.swift |
| MC7-29-7 (avatar part) | Member row avatar with the MP default | MerchantBusinessViews.swift |
| Owner #9 | Two-decimal money through the one shared formatter `MoneyDisplay.plain`: invite fixed fee and owed deposit (were 0…8 places) and perks retail/cost. Finance and settlement were already two places via Core. | CooperationInviteActionSections.swift, MerchantPerkTemplatesView.swift |

## Owner decisions 2026-11-24, as they apply to merchant-coop half b
- **#9 two decimals:** done (above).
- **#12 / #3 / #6 money:** nothing here moves money. The station accept is not a money route, and it still sits behind the TEST-only `merchantWrites` gate and `ReleaseMoneyWriteSwitch`.
- **#5 merchant approvals in-app:** no endpoint grant was flipped (new gates default off). Where a grant is missing, the App now hides the dead actions behind one notice (24-1, 25-1, 26-1, 23-1). The grants themselves are still owner/coordinator: MC7-23-1, 24-1, 25-1, 26-1, 29-3 and 29-8.
- **#7, #8, #10** (cast, GPS arrival lock, game-kit pilot gate): play-area. No half-b page touches them.

## Review findings
- `review/r7-rev-a`, `-b` and `-c` have **no rows owned by Claude for merchant-coop**:
  - REV-A is play runtime.
  - REV-B's Claude rows are topic, messaging and ticket-wallet (P3/P5).
  - REV-C's Claude rows are integration (F-C02) and the club settlement mount (F-C21).
  - The merchant rows (B-11, B-12, B-18, B-19, B-27, F-C04/06/07/08/22/25) are Cursor or Gemini.
- Open P1 rows of `audit/parity-r7-merchant-coop` for half b, all closed above or listed below.

## Tests touched
- `Tests/ContractChecks/test_merchant_station_submission_import.py`: `App/MerchantOperationsViews.swift` sha re-pinned (MC7-24-4 only; comment in the file).
- `Tests/AppUITests/MerchantGameNodeFlowTests.swift` `testReadOnlyCompositionDisablesWrites`: now asserts that pause is **absent** rather than disabled (MC7-26-1; comment in the file). Cursor owns Tests/, so please confirm.
- `docs/ops-safety/client-data-catalog.json`: entry for the ai-npc intro flag (`test_ops_safety_contracts`).

## Still left, with reasons
- **Core requests (cursor/core-merchant-coop):**
  - MC7-19-4: expose `businessLicense` on the decor store profile, so the read-only 营业执照 row can render.
  - MC7-31-10 / MC7-30-2 full: apply invite presets (`type`, `toId`, `topicId`) and seed `CooperationInboxTopicFilter` from `CoopListLink` after the inbox loads. That needs App model hooks plus Core: a preset initializer on `CoopInvitationReadModel`, and a filter seed on the browser.
  - `logo` on `CoopFlowTargetCandidate` (invite target thumbnails).
  - Plus the round-1 Core list, unchanged.
- **Gemini:** MC7-33-4, 33-5 and 33-1 (topic context on nearby).
- **Owner/privacy:** MC7-33-2 (persist the nearby location-purpose consent; `test_runtime_dependency_wiring` pins the reset). MC7-29-6 and MC7-34-1 are still reverted, as in round 1.
- **P2 not done:**
  - MC7-19-7: inline 营业状态 toggle.
  - MC7-19-8: hub counts, which need counts the hub does not read.
  - MC7-19-9: featured activity name.
  - MC7-19-10: a 口碑 row; the hub has no reviews reader.
  - MC7-30-4, 30-5 and 30-13: coop list card layout, copy phone and the all-empty state.
  - MC7-31-8: send summary.
- **Do-not-touch:** there is no `cursor/wire-merchant-coop` branch, and `cursor-core-merchant-coop.md` hands these App call sites to the F-agent, so they were wired here.

## Round 2 final sync and checks
- Merged `origin/ui/combined-r7` again @ aee32a61f. Clean merge; this r7 now includes K1–K10, W1 and C7.
- `tools/check_a11y_lint.py`: **PASS** (0 new). Four findings came in with the round-1 `restyle/r3-merchant-creator` merge: `.font(...)` → `.cyText(...)` changed their signatures. The fix adds `.accessibilityHidden(true)` to these decorative glyphs:
  - `CYDesignComponents.swift` (reduce-motion ellipsis);
  - `ExternalGameImportView.swift` (header circle; the Button carries the label);
  - `MerchantPredictionInboxView.swift`;
  - `UGCSafetyComponents.swift`.
  - The three StoreCharacter state glyphs got the same change.
- `tools/check_typography_lint.py`: **PASS**.
- **ContractChecks:**
  - Scope: every module that references any of the 329 App/Core files this branch changes relative to r7 @ aee32a61f, run on r7 and on the branch.
  - Result: **39 failing on r7, 39 on the branch, the same set, 0 new.**
  - Not covered: the rest of `Tests/ContractChecks/`. A full-directory run was started, then stopped because r7 had moved under it.
- No compiler in the cloud. Every API used was grepped on the merged tree. The coordinator compiles.

---

# Round 3 (2026-11-24 evening)

- **Brief:** `origin/design/handoff-r2:docs/briefs/fix-r3-round3.md` (plus `wave-x10.md`, `fix-r3-round2.md`, `owner-decisions-1124.md`).
- **Sync:** `git merge origin/ui/combined-r7` @ b0ac0108d. It fast-forwarded: r7 already contained this branch's round 2 (6e8125bc8).
- **Strings:** no new keys this round. Every key used was already in `Localizable.xcstrings` or `docs/port/strings/fix-r3-merchant-coop-b.json`.

## Round 3 · re-applied
I checked each round-2 commit hunk by hunk against the new base (`git diff <c>^ <c>`, then compared the result with HEAD). None of this branch's files were on the brief's "restored whole to Cursor's side" list. Two overlaps had still produced a **second implementation**, and one merge hunk had dropped part of my change:

| id | what the merge left | re-applied on Cursor's wiring | files |
|---|---|---|---|
| MC7-30-6 | There were two station-accept paths. My `CoopSupplyStationAcceptView` was reached first. Cursor's `CoopFlowHandleEditor(supplyStationID:supplyStationName:flowReader:)` was unreachable for a station invite. Cursor's path also had no outcome UI and only toasted failures. The footer showed a third station-name row, which reused the a11y id `cooperation.detail.supplyStation` of the 合作条款 row. | Every accept now goes through Cursor's `handle(.accept)` → `CoopFlowHandleEditor`. In the editor: <br>• the 核销据点 row (name, or 据点 #id) and the MP lock note; <br>• the send prefers the TEST-only gated `coopFlowPreviewWrite.stationAccept()` (`merchantWrites` + per-op `.handle` approval + `ReleaseMoneyWriteSwitch`) and otherwise uses Cursor's `flowReader.acceptSupplyStation`, which is dormant in production; <br>• outcome rows: sent + 完成, unknown, the server message on failure, and a disabled button + 暂不可提交 when neither sender exists. <br>`CoopSupplyStationAcceptView.swift` is deleted. The duplicate footer name row is removed; the name stays in 合作条款. | CooperationFlowEditors.swift, CooperationInviteActionSections.swift, (deleted) CoopSupplyStationAcceptView.swift |
| MC7-35-1 | There were two club settlement-detail screens and two `case "pages/coop/settlement-detail/index"` in `MPReviewedPageScreen`. Cursor's `CoopSettlementDetailRoute` came first, so my case and `CoopClubSettlementDetailView` were dead. Cursor's `CoopClubSettlementScreen` had no retry, no back action, hard-coded zh labels, and matched `topicId` OR `id` regardless of the link. | Kept Cursor's route and `CoopClubSettlementScreen`, and moved my effect into it: <br>• MP `recordKey` matching (`MerchantSettlementDetailLink.recordKey`, passed by the route); <br>• missing → 结算记录不可见 + 返回; <br>• failed (with the server message) → 重试; <br>• pull to refresh; <br>• localized `merchantCoop.settlement.*` labels; <br>• merchant domain chrome. <br>My duplicate case, the `settlementMissing` helper and `CoopClubSettlementDetailView.swift` are deleted. | CoopSettlementDetailView.swift, MPReviewedPageScreen.swift, (deleted) CoopClubSettlementDetailView.swift |
| MC7-26-4 | The merge added an always-on `ForEach(c.readyFieldIssues)` list above 确认准备完成 and dropped my `readyAttempted = true`. My per-field errors therefore never showed, and the same issues showed unconditionally as a second list. | `readyAttempted = true` is restored on tap. The duplicate list is removed. Errors show under each field only after the tap (MP `cy-inline-error`). | MerchantGameNodeView.swift |
| (a11y) | `.accessibilityHidden(true)` was doubled on three StoreCharacter state glyphs (my round-2 hunk + the same restyle fix). | The duplicates are removed. | MerchantStoreCharacterView.swift |

Every other round-2 hunk (MC7-19-2, 24-1/25-1, 24-4, 23-1, 27-1, 31-2, 32-1, 32-3, 32-5, 34-3, 32-7, 30-2, 31-10, 29-12, 29-7, owner #9, the ai-npc intro and the MP default avatars) is present on the base unchanged.

The project was regenerated (`tools/generate_project.py`) for the two deleted files and the one new file.

## Round 3 · new
| id | what | files |
|---|---|---|
| flows-g2 (Claude edges, half b) | Deep links that used to land on 该页面暂未开放 now open the native screens: <br>• `pages/merchant/decor/index` → 品牌中心, with the session factory, the perks destination and the city-node hub (as on the merchant tab); <br>• `decor/gallery`, `decor/coop-setting` and `decor/ai-npc` → new `MerchantDecorLinkedPage`, which reads `access()` and opens the page only when `allows(...)` is true, and otherwise shows the decor hub states (登录 / 去商家入驻 / 当前身份不能装修店铺 / 品牌中心加载失败 + 重试); <br>• `decor/perks` → `MerchantPerkTemplatesHost` (executor only where merchant writes are open); <br>• `merchant/citynode` → hub; <br>• `citynode/create` → create; <br>• `merchant/game-node` → the 选择场次 entry list, or the station when `activityId` is present. <br>This closes the half-b flows-g2 rows: citynode 130/131/134, decor 150–170 (not 163 reviews, which is half a), merchant/index 183/186, marketing 207 and shezhi 280. Rows 76/114 (settlement-detail) were already routed. | MPReviewedPageScreen.swift, MerchantDecorLinkedPage.swift (new) |

The MP `redirectTo /pages/merchant/decor/index` after a sub-page save (rows 150, 152, 155, 170) is a native pop back to 品牌中心, which already happens.

## Round 3 · checked, nothing to do
- `review/r7-rev-{a,b,c}`: still no Claude rows for merchant-coop.
- `docs/mp-assets/mapping.md`: there are no new rows on half-b pages. The template-detail shelf tabs, leaderboard memojis and member-journey icons are other areas. The merchant rows on `MerchantBusinessViews.swift` are half-a pages (reviews, customer).
- `audit/parity-r7-merchant-coop`: every Claude P1 for pages 19–35 is either closed in rounds 1–3 or listed below.

## Round 3 · still left
- **Core (`cursor/core-merchant-coop`), new this round:**
  - `MiniProgramPageLink` needs rules for `pages/merchant/game-node/index` (`activityId`) and `pages/merchant/decor/index` (`view`). Both are still query-free, so those keys are rejected; the App case already reads `activityId`.
  - The router has a duplicate `case "pages/merchant/ledger/order-detail/index"` (half a / Cursor). The first case wins, so the MC7-07-2 `recordType` branch is dead. Not touched here.
- **Core, unchanged from rounds 1–2:**
  - MC7-19-4 (`businessLicense` on the decor profile);
  - MC7-23-3 (base URL);
  - MC7-23-4 (`personality` enum);
  - MC7-27-3 / 28-7 (link rules);
  - MC7-28-6;
  - MC7-29-4: the `invite/preview` path constant exists, but there is no reader on `MerchantEngagementReading`;
  - MC7-33-3;
  - MC7-33-6: `NearbyMerchantRow` still has no venue fields;
  - target `logo`;
  - invite presets.
- **MC7-23-5 清除声音:** Core now has `Adapt2MerchantNPCVoiceResetClient` (gate default off). It is not wired because every ai-npc write is still closed under MC7-23-1 (owner endpoint review). It should be wired together with that grant.
- **Owner/gate:** MC7-23-1, 24-1, 25-1, 26-1, 29-3 and 29-8 (→ 29-9, 29-10). The interim hide-behind-notice is in place.
- **Reverted pins:** MC7-29-6 and MC7-34-1 (unchanged).
- **Gemini:** MC7-33-1, 33-4 and 33-5.
- **Club F-agent:** MC7-28-3.
- **a11y lint on r7:** 17 new findings, all in files outside this half. The only merchant one is the Gemini file `MPGap/MerchantCoop/MerchantGapAIInsightViews.swift:146`. None are in files changed here.

## Round 3 checks
- **ContractChecks**, base vs branch:
  - Re-apply commit: 1 failing on both, the same set. Scope: modules referencing the changed editors, game-node and StoreCharacter.
  - Routes/settlement commit: 19 failing on both, the same set, 0 new. Scope: 75 modules referencing `MPReviewedPageScreen`, settlement, `MerchantOperationsHomeView`, the project or the generator.
  - This is not a full-directory run.
- `tools/check_typography_lint.py`: **PASS**.
- `tools/check_a11y_lint.py`: no finding in any file changed here. The 17 new findings are on the r7 base in other areas' files.
- **Fixture routes:** no new design fixtures exist for the new deep links, so `docs/port/accept/f-merchant-coop-b.txt` is unchanged. The deep links can be exercised with the MP page paths listed above.
- No compiler in the cloud. Every API used was grepped on the merged tree (`MerchantOperationsReading.access()`, `MerchantOperationsAccess.allows`, `AppSession.merchantOperationsDestination` / `merchantCityNodeHub()` / `merchantGameNodeService`, `MerchantPerkTemplatesHost`, `MerchantCityNodeCreateView(service:placeSearch:)`, `MerchantGameNodeEntryView(service:topicID:)`, `SessionMerchantGameNodeView`, `MerchantSettlementDetailLink.recordKey`, `CoopFlowPreviewWriteFactory.stationAccept`).

---

# Round 4 (2026-11-25)

- **Brief:** `origin/design/handoff-r2:docs/briefs/fix-r3-round4.md` (plus `wave-x10.md`, `owner-decisions-1124.md`). Gemini is out of quota, so its MP-alignment rows for half-b pages were taken here.
- **Sync:** `git merge origin/ui/combined-r7` @ 4ef0a2840 fast-forwarded (r7 already held round 3).
- **Strings:** `docs/port/strings/fix-r3-merchant-coop-b.json`, now 100 keys (en + zh-Hans). Overrides of existing keys are listed under Copy.
- **No Core changes.** No new Swift files (no generator change).

## Round 4 · flows (`docs/mp-gap/flows-g2.md`, half-b rows still marked for Claude)
| row | MP edge | app now | files |
|---|---|---|---|
| 108 | coop/invite `onResultSheetClose` → `redirectTo /pages/coop/list/index?tab=sent` | 协作列表's 发起邀约 is a programmatic push; 完成 on a sent single-target invite pops the invite page and switches the list to 我发出的 (`coopInviteSent` hook). Batch of several targets, deep link and workbench entries keep 完成 → dismiss. | CooperationBrowserView, CooperationContextualViews, CooperationFlowEditors, MerchantCoopStateActions |
| 105 | invite-detail `goDeposit` → back to the list (sent box stays on 我发出的) | already `dismiss()` back to the list, whose segment state is kept | — (checked) |
| 109 / 110 | `_navigateTo(url)` helpers (`?`) | invite → topic / merchantinfo, list → invite / invite-detail / nearby are all native pushes | — (checked) |
| 111 | nearby `openMerchantHome` → merchant public home | already `PublicMerchantHomeView` (sheet) | — (checked) |
| 131 | citynode/create `goConfigTemplate` → `publish/temp?from=citynode` | already `MerchantCityTemplateHandoff` | — (checked) |
| 166 | decor `onDenyBack` → back / reLaunch merchant index | system back; a deep-linked root sits on a pushed stack | — (N/A) |
| 114 / 115 / 138 | settlement-detail / coop-center `onNavBack` reLaunch fallbacks when the page is the stack root | the app never opens these as a stack root (deep links push), so system back covers them | — (N/A) |
| 222 | relation `goClub` → club detail `?id=&scope=MERCHANT` | already the relation profile destination (rows 218–221 OK) | — (checked) |

## Round 4 · image parity (MP image slots per half-b page)
Only system-control glyphs (chevron/arrow-right, close, check, plus, edit, camera, back, bell, clock, route, pin, qr-scan, lock/info/warning state glyphs) stay SF Symbols, as the handbook allows. `cy-empty` draws its bitmap art **only for `kind="empty"`** (components/cy/empty/index.js `KIND_DEFAULTS`); every other kind is a glyph.

| page | MP slot (file:line) | MP asset / fallback | app before | app now |
|---|---|---|---|---|
| decor | store logo `m.logo` (wxml:64) | server image, else first letter | profile editor | unchanged (no default asset) |
| decor | cover `m.coverImage` (wxml:71) | server image, else text 添加店铺封面 | profile editor | unchanged |
| decor | tag chip `dc-tag-ico` (wxml:146) | `pages/merchant/images/tags/*` via tag-library | text only | `MerchantTagIcons.image(for:)` (MPAsset.FeatureIcon.*) in the tag sheet's selected list and every option (MerchantDecorTagEditor) |
| decor | `wechatQr` (wxml:372) | server image | — | unchanged |
| gallery | photos (wxml:23) | server images | grid | unchanged |
| perks | `cy-empty kind="empty"` (wxml:51) | `empty_state_bg` + `empty_state_figure` | SF gift | `CYEmptyState("tray")` → `MPAsset.EmptyState` art |
| ai-npc | intro art `npc-intro/{a,b}.png` (wxml:131-132) | MPAsset.FeatureIcon.* | done in round 2 | unchanged |
| ai-npc | photo avatar (wxml:27) | server image, else canvas | AsyncImage (round 1) | unchanged |
| citynode | poster `qrcodeUrl` (wxml:126) | server image, else `cy-code-text` | grey SF qrcode on failure | `code` text fallback (MC7-24-6, below) |
| citynode | `cy-empty kind="empty"` 还没有节点 (wxml:67) | MP empty art | SF mappin.slash | `CYEmptyIllustration(.generic)` |
| game-node | `cy-empty kind="empty"` (wxml:21) | MP empty art | SF tray | `CYEmptyIllustration(.generic)` |
| coop-center | route cover (wxml:30) | server image, else bare gradient | AsyncImage, else plain fill | unchanged |
| coop-center | `cy-empty kind="empty"` ×2 (wxml:54,75) | MP empty art | SF tray | `CYEmptyIllustration(.generic)` |
| relation | composer avatar `myAvatar \|\| d_profile` (wxml:24) | MPAsset.AvatarDefault.dProfile | club-owned composer (MC7-28-3) | not touched (club F-agent) |
| relation | `cy-empty kind="empty"` 暂无可合作俱乐部 (wxml:65) | MP empty art | SF storefront / person.3 | `CYEmptyIllustration(.generic)` |
| team | member avatar `avatar \|\| d_profile` | MPAsset.AvatarDefault.dProfile | done in round 2 | unchanged |
| coop/list | invite/registration/pool cover (wxml:65,136,160) | server image, else blank `.inv-cover` box (`--cy-bg-card-2`) | generated `CYCoverArt` with an SF glyph | `CoopCoverPlaceholder` (plain `CYColor.bgRaised`) |
| coop/invite | target logo `logo \|\| d_logo` (wxml:84,93,146) | MPAsset.BrandLogo.dLogo | done in round 2 | unchanged |
| invite-detail | `invite.cover` (wxml:41-42) | server image; **no cover block** without one | generated art hero | real cover only; without one the topic name is a plain title |
| nearby | `cy-empty kind="empty"` 附近暂无商家 (wxml:42) | MP empty art | SF mappin.slash | `CYEmptyState("tray")` → MP art |
| finance | (none) | — | generated `CYCoverArt` thumbnails with yensign | removed |
| settlement-detail (club) | `cy-empty kind="empty"` 结算记录不可见 + 返回结算列表 (wxml:31) | MP empty art | SF doc.text.magnifyingglass + 返回 | MP empty art (`MerchantCoopActionState(emptyArt:)`) + 返回结算列表 |

## Round 4 · copy (MP text, zh-Hans)
A read-only sweep of the 17 half-b pages (titles, buttons, empty/error/permission states, toasts, dialogs) found 66 differing pairs. Applied:
- **Fragment overrides** (`docs/port/strings/fix-r3-merchant-coop-b.json`, existing keys overridden, page-only keys): `merchant.operations.wechat` 门店微信, `merchant.operations.discardTitle` 还没有保存, `merchant.operations.discardBody` 离开后，本次修改不会保留。, `image.galleryBatch.select` 添加相册图片, `merchant.perks.saved` 常备权益已保存, `merchant.perks.deleted` 常备权益已删除, `merchant.perks.form.save` 保存权益, `merchant.perks.discard.title` 还没有保存, `merchantCoop.coopSetting.saved` 已保存, `merchant.business.removeOperator` 移除, `merchant.operatorRoster.unavailable` 团队名单加载失败, `cooperation.list.official.failed` 官方邀约加载失败, `cooperation.list.incomplete` 邀请信息不完整, `cooperation.invite.terms.traffic` 引流合作（不产生现金结算）, `context.coop.chooseTopic` 选择我发布的主题, `cooperation.phone.copyFailed` 没能复制, `cooperation.detail.footer.ongoingFrozen` 合作进行中，条款已锁定, `cooperation.detail.cancelLocked` 已锁价，取消合作需联系客服, `merchantCoop.nearby.signIn` 登录后查看, `nearbyMerchant.locationDenied.title` 当前无法查看附近商家, `nearbyMerchant.locationDenied.detail` 需要定位权限才能找附近商家, `cooperation.nearby.failed` 附近商家加载失败, `cooperation.nearby.empty` 附近暂无商家, `nearbyMerchant.locationFailed` 定位服务暂不可用，请稍后重试, `cooperation.settlement.failed` 结算详情加载失败, `cooperation.settlement.back` 返回, `coopflow.discovery` 发现, `cooprelation.partial` 部分俱乐部资料暂不可用.
- **Separate tables** (edited in place, like round 1's `hintPrint`; JSON round-trip verified byte-identical before editing):
  - `Resources/MerchantCityNode.xcstrings`: permission.title / permission.manage 当前身份不能管理节点, permission.verify 当前身份不能核销, create.accessLoading 正在确认经营团队权限…, create.lede (full-width ，), create.accessFallback 商家权限没能读取, create.noCoordinate 请在地图上选择店门口, create.readbackMissing 申请已提交，审核状态更新中, create.leaveBody 玩法或店址还没有提交，确定离开吗？
  - `Resources/MerchantGameNode.xcstrings`: switchStation 切换, hero.untitled 未命名节点, invite.title 节点邀请, decline.title 拒绝节点邀请, decline.tip 拒绝原因将告知主办方, verify.idPlaceholder 提交编号, runbook.why (full-width ，), pause.noFallbackMessage 其他节点.
- **Not changed, with reasons:**
  - Shared keys used on other screens (a page-only key would be needed): `action.retry` (重新载入), `cooperation.refresh` (重试), `cooperation.loading`, `coopflow.read.failed`, `merchantCityNode.title` (成为城市节点), `coopflow.invite.title` (also the invite editor title), `coopflow.nearby.unavailable` (also the workbench).
  - Values pinned by tests: `merchantCityNode.create.readbackTitle` (test_w2_19_cityNode), `merchantGameNode.recap.completed` 保底完成 (test_play_player_team_status), `merchantGameNode.pause.tip` (MerchantGameNodeFlowTests), `merchantCoopCenter.plaza.error.title` / `official.error.title` / `inbox` (test_w2_19_coopCenter). Cursor owns Tests/; please re-pin to the MP text.
  - `merchantCityNode.poster.hintPrint` stays 保存后张贴 (round 1, MC7-24-3: the app has a real save button, not long-press).
  - Direction-specific or numbered MP copy the app does not model 1:1: `cooperation.invitations.empty` (还没有收到/发出协作邀请, needs MC7-30-13), `context.coop.targets` (③ 邀请对象), `context.picker.empty`, `merchantCoopCenter.deadline.open` (format string), `merchant.perks.form.name/cost` (placeholder vs label), `cooperation.phone.copy` (MP visible 复制 sits next to the number; the app button stands alone).

## Round 4 · P2 rows (audit `parity-r7-merchant-coop`, Claude + the Gemini rows for half b)
| id | what | files |
|---|---|---|
| MC7-19-7 | 营业状态 as an inline switch on 品牌中心 (MP cy-switch, no confirm), via the same reviewed `saveReviewed(.businessStatus)` the workbench uses; read back after every attempt; toast 营业状态已保存 / 营业状态保存失败 | MerchantOperationsViews.swift |
| MC7-19-10 | 口碑 row in the brand group → merchant reviews page. Owner only (access/me does not decode MARKETING_READ yet; Core request) | MerchantOperationsViews.swift, MerchantHomeView.swift, MPReviewedPageScreen.swift, MerchantCoopStateActions.swift |
| MC7-24-6 (Gemini row) | Poster without a usable image but with a server `code`: monospaced selectable code, 复制验证码 (LocalPasteboard), hint 二维码暂时不可用，可长按复制验证码 | MerchantCityNodeHubView.swift |
| MC7-25-4 (Gemini row) | The picked address is a button that opens the system map (MP `viewPicked` → openLocation) | MerchantCityNodeCreateView.swift |
| MC7-30-4 (part) | 核销据点 · {name} line on invite cards | CoopListParitySections.swift |
| MC7-30-5 | Released contact line (leaderName · phone) on cards; 复制合作方电话 as the card's context menu and a VoiceOver action | CoopListParitySections.swift, CooperationBrowserView.swift |
| MC7-30-12 (Gemini row) | 去收到的确认 on sent applications with status 3 switches the list to 收到的 | CooperationBrowserView.swift |
| MC7-31-8 (part) | A single-target send ends on 协作列表 · 我发出的 (flows row 108) | see flows |
| MC7-31-9 (Gemini row) | After a failed invite send: 主题条款没配好？去编辑主题(票价/内容) → `topicEditorDestination` (pages/publish/fabu?id=&scope=) | CooperationFlowEditors.swift |
| a11y | `ClubWorkbenchKit.swift:261` share glyph hidden (its ShareLink carries the label) so the lint is back to 0. Club-owned file, one-line change. | ClubKit/ClubWorkbenchKit.swift |

The Gemini parked views in `MPGap/MerchantCoop/MerchantGapRound4Views.swift` (`MerchantGapCityNodePosterAndMapViews`, `CoopGapListAndDepositActionsView`) cover the same rows; they were not mounted because the native screens now do it in place. They can be deleted by the coordinator.

## Round 4 · still left
- **P2 not done:**
  - MC7-19-8 (hub counts): the hub reads only `access()`; gallery and perk counts need extra reads.
  - MC7-19-9 (featured name, 去发布一个活动 in the empty picker): the editor rows are pinned by `test_merchant_decor_tag_picker`-style structure tests, and there is no merchant-scoped activity-publish destination in the editor's environment.
  - MC7-29-7 header (团队成员 · N 人): `test_merchant_operator_roster` pins the roster key set and the count row.
  - MC7-30-13 (one all-empty state): the chapter-application and official-invite sections load on their own, so the page cannot tell when every section is empty.
  - MC7-31-8 (one summary for a multi-target send): needs a batch send; today each draft has its own reviewed submit.
- **Core requests (new):** decode `merchant:marketing:read` on `MerchantOperationsAccess`/`MerchantAccess` (MC7-19-10); expose `code` on `MerchantCityNodePosterCode` (the App parses it locally for now).
- **Unchanged from round 3:** the Core list, owner/gate rows, reverted pins (MC7-29-6, MC7-34-1), club F-agent MC7-28-3 (also the relation composer `d_profile`).

## Round 4 checks
- `tools/check_a11y_lint.py`: **PASS, 0 current.**
- ContractChecks, run module by module on the base commit vs the branch for every module that references a changed App file, string table or fragment: **0 new failures**. One module goes from failing to passing (`test_merchant_station_submission_import`, `MerchantOperationsViews.swift` re-pinned with a comment). `test_merchant_decor_tag_picker` pins the editor's tag rows, so tag icons are only in the tag sheet.
- No compiler in the cloud. APIs used were grepped on the tree: `LocalPasteboard.copy`, `CYEmptyIllustration(kind:size:)`, `MerchantTagIcons.image(for:)`, `topicEditorDestination`, `MerchantBusinessPage(reader:journal:query:)`, `MerchantStoreBusinessStatus`, `MKMapItem.openInMaps`.

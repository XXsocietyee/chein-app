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

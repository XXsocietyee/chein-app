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

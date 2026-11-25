# Receipt: fix/r8-mp-first (owner MP-first rule, 2026-11-25)

Brief: `origin/design/handoff-r2:docs/briefs/owner-decisions-1124.md` § "MP-first rule", `fix-r8.md`, `wave-x10.md`.
Base: `origin/ui/combined-r7` (merged again before every push). MP: `hengyin/chengyinhub-xcx` @ 1b10b25f.
Queue: every row whose owner was **owner decision** in `origin/audit/parity-r8-<area>:docs/audit/parity-r8/*.md`
(member, account-publish, merchant-coop, club, player-content incl. groups A–D, play-roam).

No compiler in the cloud: every type, initializer label and property used was grepped on the tree first.
Contract checks touched by these commits were re-run with `python3 -m unittest` (see "Checks" at the end).

## Shared mechanism (merchant-coop + play-roam, coordinator)

| piece | file | what changed |
|---|---|---|
| Merchant business approval | `Core/MerchantBusinessProduction.swift` | `MerchantBusinessProductionApproval(mpFirstMarket:endpoints:actions:)` + `MerchantBusinessAction.mpFirst` (16 actions the MP sends; `saveSku` excluded). Still pinned to base URL, namespace and account; path must stay under `api/merchant/`. |
| Merchant engagement approval | `Core/MerchantEngagementProduction.swift` | `mpFirstAcceptInvitation` opens only `api/merchant/operators/invite/accept`. The grant initializer still refuses accept grants. |
| Live composition | `App/MerchantApprovals/MPFirstMerchantApprovals.swift`, `App/ReviewedPlayerWriteLeases.swift` (`sessionDependencies`) | China contexts now get `merchantBusinessApproval` + `merchantEngagementApproval` (default ON, `MPFirstMerchantApprovals.enabled`). |
| City / NPC / game-node gates | `Core/MerchantCityNPCParityGates.swift` | `MerchantCityNPCParityGates.mpFirst` (cityNodeWrites, stationCommands, storeCharacterSaves, storeVoiceEnrollment) and `reviewedEndpoints[.china] = mpFirstChinaEndpoints` (exact MP paths). Store-day proof/consent and the W04/W05 reform scopes stay OFF. |
| Composition firewall | `App/AppCompositionRoot.swift` (`guardedSend`) + `MPFirstMerchantWriteRoute` | Admits exactly the MP merchant POSTs above (CRM customer paths need one positive id; only aftercare respond may carry `refundId`). No pay / refund execution / payout / withdrawal path is admitted. |
| Roam stamp | `Core/RoamExperienceContracts.swift` | `RoamExperienceCapabilities.mediaUpload = true`, `stampExchange = true`. All other roam capabilities stay false. |

## Implemented (MP-first)

### merchant-coop
| id | MP evidence | app files | test |
|---|---|---|---|
| MC8-13-1..4 review reply / 修改回复 / 删除回复 / 举报 | pages/merchant/reviews/index.js:555-620; wxml:185-209 | approval + firewall above | `MPFirstMerchantApprovalTests.testMPFirstRequestShapesMatchTheMiniProgram`, `…PermitsEveryMPActionForAnyStoreAndTarget`; `MPFirstMerchantWriteRouteTests` |
| MC8-14-1 批量标签 | pages/merchant/customer/index.js:716 | same | same |
| MC8-15-1..5 tags add/remove, notes add/correct/hide | pages/merchant/customer/detail/index.js:178,230,262,300 | same | same (path + body keys pinned) |
| MC8-17-1 aftercare 同意/不同意/补充凭证 | pages/merchant/aftercare/detail/index.js:258-300 (toast 意见已提交，等待平台处理 — an opinion; the platform processes any refund) | same | same (`?refundId=` + `{decision, content, requestId}` pinned) |
| MC8-18-1 predict 给答案 | pages/merchant/predict/index.js:206-240 (`api/merchant/predict/settle {nodeId, playDay, settledOption}`; winners get the store's coupons, not cash) | `App/AppCompositionRoot.swift` `merchantMarketingGates.settlement = true`; `App/AppSessionDoorEntry.swift` passes `MerchantPredictionFileLocks` | `ReviewedHookWiring2Tests.testReviewedChinaCompositionEnablesReadsAndInsightButNeverSettlement` (now pins settlement on); `test_native_entry_wiring.py`, `test_account_marketing_entry_integration.py` |
| MC8-23-1 npc/save, decor/save, voice/enroll | pages/merchant/decor/ai-npc/index.js:533,744,942 | `App/MerchantStoreCharacterSessionBinding.swift` (`makeStoreCharacterWriter`, real `StoreCharacterServiceBackend` with `gates: .mpFirst`) | `StoreCharacterTests.testWritesAreDisabledByDefaultAndWithoutAllowlist` (now pins the China allowlist); `test_w2_19_aiNPC.py` |
| MC8-24-1..6 city node 投放/认领/撤回/上架·下线/认领 sheet | pages/merchant/citynode/index.js:318,360,483 | `Core/MerchantCityNodeHub.swift` (`MerchantCityNodeWriteGate` defaults to `.mpFirst`/China) | `MerchantCityNodeHubTests.testWritesStayDormantOutsideTheOfflineHarness` (now pins every MP path open in China, closed elsewhere / with `.disabled`) |
| MC8-25-1 city-node/save | pages/merchant/citynode/create/index.js:397 | same | `MerchantCityNodeHubTests.testSaveAvailabilityMatchesTheWriteGateForThePlacementRoute` |
| MC8-26-1..8 game node invite/ready/pause/resume/verify | pages/merchant/game-node (utils/game-session-client.js:395 command, :516 receipt) | `App/MerchantGameNodeSessionBinding.swift` (`MPFirstMerchantGameNodeService`: reads unchanged, writes via `MerchantGameNodeHTTPService` with `gates: .mpFirst` and a memory journal) | `MPFirstMerchantWriteRouteTests`; `test_w2_19_gameNode.py` (endpoint line) |
| MC8-29-1 岗位 / 移除 / 撤销邀请 | pages/merchant/team/index.js:626,718 | approval + firewall | `MPFirstMerchantApprovalTests` (role/remove/revoke shapes) |
| MC8-29-2 接受邀请 | pages/merchant/team/index.js:806-818 | engagement approval | `MPFirstMerchantApprovalTests.testMPFirstAcceptInvitationShapeAndApproval` |
| MC8-29-5 邀请员工 | pages/merchant/team/index.wxml:91, index.js:570 | shows again now that the approval exists | `MPFirstMerchantApprovalTests` |
| MC8-29-6 share the invite | pages/merchant/team/index.js:844-850 (`onShareAppMessage` 邀请你加入{门店}经营团队) | `App/MerchantOperatorInvitationReceiptView.swift` ShareLink; strings `docs/port/strings/fix-r8-mp-first.json` | `test_merchant_operator_invitation_receipt.py` (exactly one ShareLink, still no persistence) |

### play-roam
| id | MP evidence | app files | test |
|---|---|---|---|
| RSTAMP-2 citystamp upload → create → exchange | subpackageRoam/citystamp/index.js:255-300 | capabilities ON; `App/RoamStampCameraView.swift`: 存入集邮册 uploads then creates in one tap, and on the citystamp route exchanges at once (`startExchange`, retry reuses the created stamp id) | `StampCameraPageReadyTests.testWritesStayHiddenAndListStaysUnregistered`, `StampAlbumIndexPageModelTests`, `RoamExperienceContractTests` (pin ON); `test_roam_experience_contracts.py` |
| SCAM-1 stamp camera 存入集邮册 | subpackageP3/pages/stamp-camera/index/index.js:350-391 | same (one tap upload + create with the same idempotency key) | same |
| SCAM-2 no consent toggle, camera on arrival | subpackageP3/pages/stamp-camera/index/index.wxml:9-34 | `App/RoamStampCameraView.swift` (toggle removed, camera requested on appear; iOS permission prompt unchanged) | `test_cb224_stamp_camera_page_ready.py` (string catalog updated) |
| SALBUM-1 stamp images in 收集册 → 邮票 | subpackageP3/pages/stamp-album/index/index.wxml:19-23 | `App/RoamStampViews.swift` (metadata + received readers allow `picUrl`) | `RoamAlbumMetadataReadTests`, `RoamAlbumIntentLifetimeTests`, `RoamReceivedStampMetadataHostTests` (pin ON) |

## Money — kept TEST-only (merchant-coop + play-roam)
| id | MP evidence | why |
|---|---|---|
| JLAND-r7-1 gift / seat claim (409 → 自己购买) | subpackageJourney/pages/landing/index.js:143-220 | Claiming a paid gift/seat and the 自己购买 branch are paid orders; `MPCommerceGate.claimsEnabled` stays off until "money on" (owner #12). |
| MC8-32-2 coop deposit (listed for context, Claude App row) | pages/coop/invite-detail/index.wxml:185-186 | Deposit payment; stays behind the TEST money switch. |

## Genuinely needs the owner (merchant-coop + play-roam)
| id | MP evidence | why the MP behaviour can't simply be copied |
|---|---|---|
| RPOI-4 POI share | subpackageRoam/poi-detail/index.js:52-66 (`onShareAppMessage`, a WeChat share card) | iOS needs a universal-link domain + AASA file to make a shared link open the app; which domain is an owner/infra choice. |
| MC8-06-4 结算到账提醒 | pages/merchant/ledger/index.wxml:121-124 (WeChat subscribe message `coopSettle`) | WeChat subscribe messages don't exist on iOS; the twin is APNs, which needs a backend push contract. Owner: build push, or accept the difference. |

## Not owner decisions any more — follow the MP (left for the area Claude-App / Cursor agents)
These rows are UI/copy/read behaviour the MP already defines, so under the MP-first rule the MP wins. They were not gate flips, so they are handed back to the area queue with the MP evidence.

| id | MP evidence | what "follow the MP" means |
|---|---|---|
| MC8-01-2 财务 shortcut | pages/merchant/index/index.js:1658 (`goFinance` → `subpackageA/pages/assetcenter/earnings/index?theme=merchant`) | Point 财务 at the earnings screen; keep 账本 under 更多. MerchantHomeView needs an injected earnings destination (no session there). |
| MC8-01-4 更多 | pages/merchant/index/index.wxml:110 (half-sheet) | Present 更多 as a `.sheet` with a medium detent. |
| MC8-10-1 hero unknown | pages/merchant/marketing/index.wxml:39-46 | Show 0 + 营销数据暂未加载 + 点击重试 as the MP does. |
| MC8-33-6 nearby purpose | pages/coop/nearby/index.js:226-260 | Ask once, then auto-search; stop resetting `purposeAccepted` on disappear (update `test_runtime_dependency_wiring`). |
| MC8-34-1 coop finance domain | pages/coop/finance/index.js:23-28 | Re-apply `entryDomain == .player ? .player : .merchant` (reverted in 091657715). |
| JPROMO-3 journey card-title weight | subpackageJourney/styles/journey.wxss (`jn-sec__h`, `jn-row__v.is-strong`) | MP weight wins over the inset-grouped kit default. |
| JSEAT-8 seats bar title | subpackageJourney/pages/seats/index.wxml:4 | Use the MP title text. |
| ROAM-7 guest entry / nearby read | pages/roam/index.js:724 | MP reads entry/nearby as a guest; needs a guest read approval in the composition (for Cursor). |
| RPOI-5 / RROUTES-2 nouns | poi-detail/index.json:3; official-routes/index.wxml:7-11 | Use the MP nouns, then sweep `roam.detail`, `roamSub.w208.poi.*`, `officialRoute.*`. |
| GROWTH-5 growth avatar | subpackageP3/pages/growthcenter/index/index.wxml:17-21 (`profile.avatarUrl \|\| d_profile`) | Show the session avatar (reuse `ProfileCurrentAvatarView`), then relax `test_growth_source_contract`. |
| ROAM-8 passport tiles | pages/roam/index.wxml:186-205 | Latest track thumbnail + latest stamp image, MP tile layout (Cursor Core for the reads). |

## club, member, account-publish — see `docs/release/receipts/fix-r8-mp-first-cma.md`
Implemented: A3-01 profile image uploads (avatar, 探索作品, 联系二维码 via `uploadOSS`; `App/AppSession+ProfileAvatar.swift`), C-F6 到访方式 read/write gates ON, C-D12 TeamCommandWriter (already built on China; test pins it), C-F17 topic save goes direct to `api/topic/v2/create|update` like the MP on China production, plus MP copy/UI rows CLB-r7-C-04, B-SZ-13, PLY-21-8, MKT-4-1 copy, MKT-10-2, A-OBJ. Test: `Tests/AppUnitTests/MPFirstCMAGrantTests.swift`.
Money kept TEST-only: MKT-3-1, CLB-payout-receiver-01, CLB-settlement-05, MKT-4-6, R7-MEM-16-1 (refund / unpaid cancel), FIN-19-1.
Left for area agents (MP has them): **PLY-25-2 (P0) orient-score sync/settle/recovery** (open `ReviewedOrientScoreReviewLease.swift:16-19`, mount `OrientSessionCoordinator`, send `sessionId`), and the UI rows listed in that receipt.

## player-content — see `docs/release/receipts/fix-r8-mp-first-pc.md`
Implemented: R7-PC-B2-1 / B3-1 every `MerchantContentCommand` the MP sends (incl. city-node claim/cancel/offline/save, npc, station) — `MerchantContentWriteApproval` defaults ON, `permitsWrites` true on the real transport with a journal, firewall `App/MerchantContentMPWriteRoute.swift`; R7-PC-B1-1 topic 收藏; R7-PC-B4-1 / B1-2 pricing (a price save, not a payment), graduation, ownership grants; R8-PC-D4-1 主办分润 read; R7-PC-D5-1 提现 → customer-service contact; R7-PC-C1-10; R7-PC-C6-1; UI rows A3-1, R8-PC-A1-1, A2-8, D7-1, D3-5.
Money kept TEST-only: R8-PC-C1-2 host cancel with refunds; publisher cancellation refunds.
Left for area agents / Cursor: R7-PC-B1-4 guest topic read, R7-PC-D9-1 (`api/im/read` needs an MP-shaped IM Core path, not a grant flip), A1-9, D8-1, D2-4, merchant body gaps (`scope`, `templateId`, `limitNum: null`).

## Genuinely needs the owner — all areas (consolidated)
| id | area | MP evidence | why |
|---|---|---|---|
| RPOI-4 POI share | play-roam | subpackageRoam/poi-detail/index.js:52-66 | WeChat share card; iOS needs a universal-link domain + AASA. |
| MC8-06-4 结算到账提醒 | merchant-coop | pages/merchant/ledger/index.wxml:121-124 | WeChat subscribe message; iOS twin needs an APNs backend contract. |
| CLB-detail-11 带票分享 attribution | club | pages/club/detail wxml:497-504, js:3509-3545 | WeChat share attribution; needs universal links or "MP-only". |
| FIN-20-6 invite share | member | subpackageMember/myinvite/myinvite.js:22-28 | WeChat-only share attribution; no invite URL. |
| A3-05 phone bind | account-publish | gerenziliao.wxml:54-56, js:840-883 | WeChat `getPhoneNumber` doesn't exist on iOS; SMS bind is a new flow. |
| B-MK-01 master marketing toggle | account-publish | marketing-consent/index.wxml:18,24 | The MP has no master toggle (hand-off only). |
| R7-MEM-24-2 此刻环境 / 掷骰 | member | — (MP has neither) | App-only sections: keep or drop. |
| B-AG-04 legal wording | account-publish | — | Legal text, not an MP flow. |
| R7-PC-C4-4 activity-start reminder | player-content | pages/activity/official-detail/index.js:604-610 | WeChat subscribe message; choose APNs push or a local reminder. |

## Merge notes
- Two firewall branches now admit merchant writes: `MPFirstMerchantWriteRoute` (coordinator) and `MerchantContentMPWriteRoute` (player-content, stricter on `game/session/command` actions). Both are exact-path, POST-only, China + production gates + signed-in.
- One conflict in `App/ReviewedPlayerWriteLeases.swift` play paths: kept both the C-F6 visit-config path and `publisherLifecyclePaths`.
- Re-pin needed: `test_merchant_station_submission_import` hash of `Core/MerchantContentService.swift` (already failing on the base).

## For Cursor
- `MerchantContentService.permits` / `permitsWrites` still decide whether the city-node claim/cancel/offline/save **commands** dispatch (the gate above only stops hiding them). See the player-content section for `MerchantContentWriteApproval`.
- Game-node pending index is memory-only (`MerchantGameNodeMemoryJournal`): a durable journal would let a relaunch reconcile an unknown command.
- MC8-23-5 voice enroll clip upload and MC8-23-6 `api/merchant/npc/voice/reset` (no `StoreCharacterEndpoint.reset` yet; the reset path is in the reviewed allowlist and the firewall).
- Pre-existing contract-check failures seen on the base and unchanged by this branch: `test_c07_fulfillment_projections` (git-diff whitelist), `test_w2_19_gameNode.test_catalog_matches_used_keys_and_is_bilingual` (`merchantGameNode.ready.`), `test_merchant_operator_invitation_receipt` (3 exact-hash pins), `test_merchant_business_access_lifetime` (exact-inverse source).

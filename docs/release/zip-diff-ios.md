# iOS diff for owner package v3.5

Keyed to UI list **v3.5** (package created 2026-11-08 10:07 AM Pacific, `ui_version` 3.5).

| Source | Identity |
|---|---|
| iOS tree | `origin/train/ui` `6ba614a5dab10e00988d0bf83145fcf4b84e10a1` |
| Zip | `origin/wip/be-brief` `8031552a091e8af6b0fac035375ca076164c5357`, `docs/release/zip-v35/` |
| UI list sha256 | `2642f67a10df8a3a90abd0da4ecab4cb72b22a694ac62dcc96bab656dffdcb61` (`来源与校验.json`) |
| Package state | `DOCUMENT_AND_CANDIDATE_CONTRACT_HANDOFF_NOT_RUNTIME_ACCEPTANCE`. P-wave compile, tests, MySQL, and HTTP are NOT_RUN. |

Search covered `App/` and `Core/` Swift on this tree. A path in the Swift column is a file that search found. `—` means no Swift file implements that item.

## How a row was marked

- **Existing** — Swift on this tree already does what v3.5 requires for that item.
- **Needs change** — Swift implements that surface, and v3.5 states a concrete client change against a contract it treats as already specified.
- **Waiting backend** — v3.5 says the server fact, payload, authority, or behavior is missing, unfrozen, blocked, not implemented, or not a runtime fact. NOT_RUN candidate source is not a server fact. If v3.5 does not specify the behavior, the note names the missing fact.

Routes are quoted only when v3.5 names them. None were added.

## Row counts

| Group | Rows | Existing | Needs change | Waiting backend |
|---|---:|---:|---:|---:|
| U02–U08 | 31 | 5 | 8 | 18 |
| UG-01–UG-12 | 12 | 0 | 0 | 12 |
| P1–P9 | 9 | 0 | 0 | 9 |
| Chapter 17 | 6 | 0 | 0 | 6 |
| Chapter 18 | 8 | 0 | 0 | 8 |
| Chapter 23 | 4 | 0 | 0 | 4 |
| **Total** | **70** | **5** | **8** | **57** |

## U02–U08

| Item | Status | Swift file | Fact |
|---|---|---|---|
| U02-01 模板详情讲清实际采用条件 | Waiting backend | `App/DiscoveryTemplateDetailView.swift` | v3.5 says place, capability, and license increments follow the B2 contract and are not delivered yet; until then the detail shows 待补充 instead of an empty label. This detail screen has no evidence-level or license summary. |
| U02-02 采用时选择沿用地点还是换城配置 | Needs change | `Core/TopicTemplateUse.swift` | v3.5 says the current use response carries `data.topicId` as an object, plus binding intent, city, pending rebind slots, and `bindingIssues` (`error` blocks publish, `warn` must not). The typed result is a scalar topic id, the production writer is gated and sends nothing, and there is no keep-city versus rebind choice. UI: `App/TopicTemplateUseSection.swift`. |
| U02-03 地点待办与现场题重新确认 | Waiting backend | — | v3.5 marks the place-contract projection PROPOSED. Missing fact: the per-scene requirement, binding, confirmation identity, and the list of questions affected by a rebind. |
| U02-04 来源版本与采用更新 | Waiting backend | — | v3.5 marks source-lineage fields PROPOSED. Missing fact: source lineage and an immutable content identity that can offer continue-current, view-diff, or save-as-new-draft. |
| U02-05 素材署名、语言与公开预览 | Waiting backend | `App/TemplateMediaReviewPanel.swift` | v3.5 does not name the field contract for credit, authorization, requested versus actual language, or which regions are public. The media panel reviews a local selection only. |
| U03-01 复用发布检查并精确定位 | Waiting backend | `Core/ProjectEditIssueLocation.swift` | v3.5 marks the server chapter, block, field, and check-version increment PROPOSED, and says local `field` mapping must stay until that increment exists. This file maps local draft issue ids onto editor anchors. The topic publish-check list reader is `Core/NativeAttributeAuthorService.swift`. |
| U03-02 发布结果明确下一步 | Needs change | `App/TemplateAuthoringPublishResultPresentation.swift` | v3.5 says the result must separate public, in review, commercial review or pricing still open, and sale versus the reason it cannot be sold, and must not turn one status into all of those. The panel is a success check and an open-library action. |
| U03-03 我的项目保持多条状态一致 | Needs change | `Core/TemplateAuthoringShelf.swift` | The shelf maps personal draft, reviewing, approved, and rejected, plus market listed, unlisted, and rejected. v3.5 also requires the list, the detail, and the publish result to share one allowed-action map, and to separate delist, stop-sale, and delete. |
| U03-04 管理后台审核与模板状态 | Waiting backend | — | v3.5 specifies the Vue topic audit screens and does not specify an iOS behavior. |
| U04-01 同顺序呈现完整故事 | Existing | `Core/ChapterStoryContracts.swift` | Runtime chapters decode `blocks` and project text, image, audio, voice, and game segments in order, stopping at the first incomplete or unknown node. Opened from `App/PlayExperienceView.swift` via `App/ChapterStoryView.swift`. |
| U04-02 选择、证物与结局兑现 | Needs change | `App/PlayThemeBackpackView.swift` | Backpack contents and clue blocks render, `Core/PlayContracts.swift` keeps lock reasons, and `Core/PlayPlayerActionReview.swift` reviews a choice before submit. v3.5 requires the confirmed consequence, evidence get versus use, and expressive versus scored choices to stay separate. Search did not find that split. |
| U04-03 购买和开局前识别端能力 | Waiting backend | `Core/PlayContracts.swift` | v3.5 chapter 11 marks capability consumption PROPOSED, and section 10.3 says the owner has not ruled whether an undeclared capability blocks start. Missing fact: a unified compatibility object, and that ruling. `PlayChapter` decodes name, description, and audio only. |
| U04-04 图文音频与阅读恢复 | Needs change | `App/ChapterStoryView.swift` | Text, image, and audio render here; an audio control appears only when a URL exists; body text uses a system text style. v3.5 also requires image zoom and reading-position restore. The artwork view loads, fails, or shows a gated label, and does not zoom or restore a reading position. |
| U05-01 到达失败原因与恢复动作 | Waiting backend | `Core/PlayExperienceService.swift` | Arrive sends longitude, latitude, and optional accuracy, and keeps the sample time off the wire. v3.5 says the stable reason codes are not connected on the client, and this batch is not HTTP-verified. Missing fact: a verified reason code plus `retryable`, `refreshRequired`, and `newActionIdRequired`. |
| U05-02 地点关闭与批准替代 | Waiting backend | — | v3.5 marks approved-fallback fields PROPOSED. Missing fact: server-approved substitute nodes. An author `fallbackMode` is not that approval. `Core/CityArrivalEvidenceService.swift` is a separate issue and confirm flow. |
| U05-03 提交未知与重启恢复 | Existing | `Core/PlayActionReceipt.swift` | An unknown write reads `GET api/play/action-receipt` with the stored `routeActionId`. Code 520 stays pending and the journal stays unknown, not failed. A retry submits that same id. A confirmed receipt is acknowledged only when the returned node matches. The existing unknown section already says the result needs checking. |
| U05-04 下载与有限离线阅读 | Waiting backend | — | v3.5 section 23.3 says a revision, or a flag that online is not required, does not prove full offline play, and that flag still needs an integrated meaning. Missing fact: which resources of this content version are required, their verified state, and the offline range. `Core/OfflinePackOperation.swift` is a separate pack. |
| U06-01 邀请、席位与成员分别显示 | Waiting backend | `Core/TeamContracts.swift` | v3.5 chapter 11 marks `seats`, `invite`, and `viewer` PROPOSED for iOS. This team model has joined count, max members, expire time, invite code, and a leader flag. Missing fact: a unified seat payload. v3.5 forbids reintroducing claimable, reserved-application, and unpaid-occupied fields. |
| U06-02 我的角色与私密线索 | Existing | `App/JourneyRoleViewSection.swift` | The section renders only the validated encounter projection. It does not offer a role picker or fall back to author configuration. |
| U06-03 队长掉线、退队与接管 | Waiting backend | `Core/TeamContracts.swift` | v3.5 says this round must not add a captain-offline takeover entry, and that leave and handover copy comes from delivered refusal codes. Those codes were not found in Swift. Missing fact: the refusal-code readback, including handover failure. The team model has a leader flag and no handover action. |
| U06-04 组织者、商家与共同成果 | Needs change | `App/ClubActivityReportView.swift` | This is a club topic report. v3.5 requires who must act now, chapter release, pause, and shared results whose social proof names its population and time window, with organizer actions kept off merchant assets. Search did not find that panel. |
| U07-01 商品和报价讲清交付 | Waiting backend | `App/RegistrationSheetView.swift` | v3.5 chapter 11 marks the delivery object PROPOSED. The signup sheet quotes member, coupon, and points amounts and a pay total. Missing fact: a delivery description per purchase kind, and the mixed-ticket case that must say each ticket type is explained separately. |
| U07-02 支付返回后核对订单 | Existing | `App/OrderLifecycleView.swift` | Payment return is its own sheet. Paid is payment status, and registration acceptance is not relabeled as money paid (`Core/OrderLifecycleContracts.swift`). An unknown provider result stays a local pending attempt (`Core/OrderLifecycleCoordinator.swift`). |
| U07-03 已购工坊安装与正文 | Needs change | `App/WorkshopPaidInstallView.swift` | v3.5 says paid-install authority is missing, the screen shows the unavailable reason, and a client contract must not complete an install. The entry can open a confirm-and-submit flow when `App/WorkshopPaidInstallSessionBinding.swift` builds a controller. Search found no authority-unavailable state. |
| U07-04 取消和部分退款的实际影响 | Waiting backend | `App/OrderLifecycleView.swift` | The order screen shows a refund application amount and payout status. v3.5 marks the settlement summary PROPOSED. Missing fact: refund stage, pending versus processing versus completed amounts, and whether the amounts are complete. |
| U07-05 财务和创作者收入准确显示 | Waiting backend | — | v3.5 marks the B8 accrual fields PROPOSED and says this projection is not withdrawable, must not show 0 for an unknown read, and must not be added to the marketing allocation. Missing fact: `revenueState` and the server accrual sentence. No Swift reader for that projection was found. |
| U08-01 正式结果、私人照片与分享 | Needs change | `App/JourneyNarrativeView.swift` | An ending chapter renders from the play narrative. v3.5 requires a server-confirmed ending, completion method, rewards, and co-completers, with private review and public share as separate actions. Search did not find that split on the finish surface. |
| U08-02 下一场推荐与问题反馈 | Existing | `Core/PlayFinishRouteRecommendation.swift` | The finish card reuses the nearby-next-route read, stays off unless the server feature is on, and does not sample the device for the card. UI: `App/PlayFinishRouteCardView.swift`. |
| U08-03 创作者维护工作台 | Waiting backend | `App/TemplateAuthoringView.swift` | v3.5 marks the maintenance-ticket chain PROPOSED. Missing fact: problem to source content to fix draft to retest to new version to close. The authoring screen edits a template and is not that chain. |
| U08-04 二次报名看板 | Waiting backend | — | v3.5 chapter 11 marks the analytics adapter PROPOSED and assigns the board to Vue. Missing fact: an iOS behavior, and the mature versus retained read. v3.5 says an immature rate must not display as 0%. |
| U08-05 榜单和公开内容治理 | Waiting backend | `App/GrowthLeaderboardView.swift` | v3.5 marks new gameplay scores entering a board as PROPOSED and says the rank policy does not read score. Missing fact: a field contract for anomaly reason, photo consent, and purchased handling after takedown. The growth board and `App/PlayPlayerLeaderboardView.swift` already leave a missing rank unranked or hidden. |

## UG-01–UG-12

v3.5 says the new gameplay save, freeze, and receipt code is wired in a candidate pack and is NOT_RUN, and that the iOS client is still to be implemented. Search found none of hangman, accusation, hint ladder, run-level free quota, help receipt, skip, or clue transform in `App/` or `Core/`.

| Item | Status | Swift file | Fact |
|---|---|---|---|
| UG-01 逐字猜词 | Waiting backend | — | Missing fact: a verified public projection and submit result. v3.5 says the client catalog and renderer are not synced, and the client must not store or cut the answer locally. |
| UG-02 图像选项 | Waiting backend | — | Missing fact: a verified option image and alt on the player projection. v3.5 says a missing image shows text only. Author media references exist on `Core/TemplateAuthoringContract.swift` and are not a player renderer. |
| UG-03 凶手指认 | Waiting backend | — | Missing fact: a verified accusation projection. v3.5 says the template must not be marked publishable before runtime readback, and the client must not judge or count attempts locally. |
| UG-04 提前结案 | Waiting backend | — | Missing fact: a verified three-way ending (正常结案, 提前结案, 指认失败). v3.5 says an unreadable progress fact rolls back to 待确认 and must not be shown as failure. |
| UG-05 提示阶梯 | Waiting backend | `Core/PlayGameSessionRuntime.swift` | Missing fact: a verified layer list. The current hint action is the two-level `PLAYER_HINT` / `PLAYER_REVEAL` chain (`App/PlayPlayerAndCircleViews.swift`). v3.5 says an empty ladder keeps that chain, and an unknown layer type is unavailable. |
| UG-06 次数与免费额度 | Waiting backend | `App/TemplateLegacyHintFields.swift` | Missing fact: a verified per-run free quota. v3.5 says the player shows one server counter, a priced layer does not spend the shared count, and gems or coins are not a second wallet. The legacy fields are hint1, hint2, and answer reveal (`Core/TemplateLegacyHints.swift`). |
| UG-07 使用明细与净分 | Waiting backend | — | Missing fact: a verified help receipt. v3.5 says `NOT_SCORED` must not display 0, points charged stay off the puzzle net, and the UI must not say the net sets global rank. |
| UG-08 跳过 | Waiting backend | `Core/PlayGameSessionRuntime.swift` | Missing fact: a verified skip availability fact. v3.5 says the button appears only when the server allows it, skip is 0 plus assisted completion, and reveal is not skip. The runtime reveal action is the current reveal path. |
| UG-09 网络未知 | Waiting backend | `Core/PlayDurableRecovery.swift` | v3.5 names this file for the receipt model. The file is local encrypted play storage and does not grant network authority. Missing fact: a verified receipt for the new submits. The current unknown UI is `App/PlayExperienceView.swift` (see U05-03). |
| UG-10 谜面变换 | Waiting backend | — | v3.5 chapter 11 marks this PROPOSED and the body says it is not compiled or integrated. Missing fact: a verified `clueTransform.mode` of STANDARD, MIRROR, or REVERSE on the player question. |
| UG-11 作者配置面板 | Waiting backend | `App/TemplateLegacyHintFields.swift` | Missing fact: a verified ladder save under the result-feedback section, with one run-level free quota and no per-layer free count. The current author hints are the three legacy fields. |
| UG-12 管理后台审核、额度与明细只读 | Waiting backend | — | v3.5 marks this PROPOSED and specifies Vue topic audit and analytics. It does not specify an iOS behavior. |

## P1–P9

v3.5 section 24.3 says the P-wave source is not compiled, not unit-tested, and not run against a database or HTTP. Section 24.4 says P5’s used-seat release protection is unfinished and P9’s member rank is not implemented. No Swift file calls a player-journey, referral-landing, seat-invitation, or affiliate-summary reader.

| Item | Status | Swift file | Fact |
|---|---|---|---|
| P1 推荐/赠送落地 | Waiting backend | — | Missing fact: a verified referral or gift landing read. v3.5 says opening the link does not claim, pay, or start a run, and it does not name an existing invite-landing route. `App/DoorReferralViews.swift` is a door inviter and is not this landing. |
| P2 玩家推广中心 | Waiting backend | — | Missing fact: a verified affiliate summary. v3.5 says a null held amount and a false payout flag must not become a withdrawable balance, and multi-currency totals stay null. The handoff also says the player-revenue tests still have compile breaks. |
| P3 主题合集落地 | Waiting backend | `App/DiscoveryTemplateDetailView.swift` | v3.5 says this reuses the public catalog and that catalog HTTP is NOT_RUN, with the endpoints still to be confirmed. Missing fact: a verified public catalog read. This detail screen reads the topic-template info, not that catalog. |
| P4 玩法模式选择 | Waiting backend | `Core/TeamContracts.swift` | Missing fact: a verified mode-choice list. v3.5 says joining a team is not the mode choice, and section 25.1 says the shared hint, skip, timer, and team-score pool is not implemented and must stay hidden. |
| P5 票内席位报名与管理 | Waiting backend | `Core/TeamContracts.swift` | Missing fact: v3.5 section 24.4 says used-seat release protection, the database test gate, and the cleanup readback are unfinished, and the new migration has not run. Team joined-count is not a ticket seat. The release control must stay closed. |
| P6 城市包与时限通票 SKU | Waiting backend | — | Missing fact: a verified product quote and the frozen coverage and validity on the order. v3.5 says not to add a three-day trial or to describe a fixed-term pass as auto-renew. No marketing-product client was found. |
| P7 本局战报 | Waiting backend | `App/PlayFinishRouteCardView.swift` | Missing fact: a verified run report. v3.5 says an unknown score is not 0, an unattributed run does not inherit the current content, and an admin cohort is not a personal report. The finish card is the next-route recommendation, not that report. |
| P8 同行回忆 | Waiting backend | — | Missing fact: a verified per-run memory read and a private-photo consent fact. v3.5 says another member’s private photos stay hidden when that consent fact is absent. |
| P9 单关与队内榜 | Waiting backend | `App/TeamOrientBoardView.swift` | v3.5 says member rank is not implemented. Missing fact: member done-count, rank, ranked, and mine, under a member-rank basis. This view is the between-teams board v3.5 says is a different board. |

## Chapter 17

v3.5 says price, eligibility, and money come only from the server, and section 22 marks this commerce package NOT_RUN. Search found no marketing-product, gift-claim, group-checkout, or promotions-catalog client in `App/` or `Core/`.

| Item | Status | Swift file | Fact |
|---|---|---|---|
| 17.1 商品与通行证 | Waiting backend | — | Missing fact: a verified per-SKU sale, payment-method, and quote result. v3.5 says the client must not decide sale from the tier alone, and a successful payment is not activation. |
| 17.2 礼品 | Waiting backend | — | Missing fact: a verified gift claim. v3.5 says one payment grants one play admission, the buyer cannot play while the gift is unclaimed or claimed by someone else, and the claim must not reveal another person’s order. |
| 17.3 加座 | Waiting backend | — | Missing fact: the frozen extra-seat payload. v3.5 says the shared purchase patch is still being repaired and the client must not charge first. A self-play extra seat is not joining the original team. |
| 17.4 团体/学校 | Waiting backend | — | Missing fact: a verified group checkout. v3.5 says a null group or school eligibility is undeclared, not “does not host”. |
| 17.5 促销目录与展示 | Waiting backend | — | Missing fact: a verified promotion catalog. v3.5 says the client must not subtract list and price locally, must not use the device clock for the window, and must not render an empty offer block as “no promotion”. |
| 17.6 报价、建单与券 | Waiting backend | `App/RegistrationSheetView.swift` | v3.5 says the marketing quote and order contract is NOT_RUN, and zero-pay plus member-price stacking still need an owner decision. Missing fact: that decision, and a verified quote fingerprint. The signup sheet still shows a coupon-deduction row; v3.5 says the coupon amount does not reduce cash. |

## Chapter 18

v3.5 says this chapter is documents only, compile and HTTP are NOT_RUN, and there is no withdraw, balance, or payout. Search found no video-bounty, host-tip, or marketing-attribution client.

| Item | Status | Swift file | Fact |
|---|---|---|---|
| 18.A 作者端视频悬赏投稿 | Waiting backend | — | Missing fact: a verified submission read. v3.5 says an author cannot self-approve, and an approved row has no cancel. |
| 18.B 作者端我的应计 | Waiting backend | — | Missing fact: a verified accrual read whose payout state stays recorded-only. v3.5 says a failed read must not show 0. |
| 18.C 主持端小费配置 | Waiting backend | — | Missing fact: an enabled tip channel. v3.5 says the channel is off, the share percent stays 100 with no editor, and the fee bearer is a separate field. |
| 18.D 玩家端给主持小费 | Waiting backend | — | Missing fact: a payable tip channel. v3.5 says a disabled channel records intent and must not show payment success or open a pay page. |
| 18.E 运营后台 | Waiting backend | — | v3.5 specifies Vue menus and does not specify an iOS behavior. It also says ordinary operators stay forbidden until a role is seeded. |
| 18.F 原视频组核验 | Waiting backend | — | v3.5 specifies the Vue review desk. Missing fact: an iOS behavior. Unverified groups must not show an accrual amount. |
| 18.G 成交归因 | Waiting backend | — | Missing fact: a verified attribution aggregate. v3.5 says unbound and owner-not-set counts stay null and must not display as zero orders or zero money. |
| 18.I 推广来源凭据 | Waiting backend | — | Missing fact: a verified referral token and claim. v3.5 says the UI must not show or compute commission, and the endpoints are still to be confirmed. |

## Chapter 23

v3.5 titles this chapter as candidate source whose runtime is NOT_RUN.

| Item | Status | Swift file | Fact |
|---|---|---|---|
| 23.1 作者保存、发布及版本 | Waiting backend | `App/TemplateAuthoringPublishResultPresentation.swift` | Missing fact: v3.5 says publish replay parameters are still being repaired and the country and city freeze is not proven for linear and activity runs. The publish panel does not show a content revision identity. |
| 23.2 玩家到达与叙事 | Waiting backend | `Core/PlayExperienceService.swift` | The arrive request sends accuracy and deliberately does not invent a timestamp parameter. Missing fact: a verified contract that accepts a sample time and returns an arrival reading and reason code. v3.5 says skip does not produce an arrival narrative. |
| 23.3 预取清单与模板交付信息 | Waiting backend | — | Missing fact: a verified content manifest, and the meaning of the online-required flag, which v3.5 says is still to be clarified. A missing asset hash stays unverified. Template detail has no delivery block (`App/DiscoveryTemplateDetailView.swift`). |
| 23.4 新多作用域榜 | Waiting backend | `App/GrowthLeaderboardView.swift` | Missing fact: a verified multi-scope rank read. v3.5 says the new board counts completed nodes, does not replace the growth board, and must not fill an old run’s missing country or city from the current theme. The growth board remains the points and growth board. |

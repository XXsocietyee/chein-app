# mp-mine r3: tab 我的 against the MP (`pages/member/index/index` and the member subpackages)

- **Branch:** `mp/r3-mine`, cut from `origin/ui/combined-r7`.
- **Brief:** `design/handoff-r2:docs/briefs/round3-1127.md`, row mp-mine.
- **Source of truth:** `origin/mp-source:chengyinhub-xcx`. The root page mounts `subpackageMember/components/cy/profile` (`viewer="self"`).
- **Not done:** nothing was compiled, and no simulator run was made. Merchant rows are still gated and the merchant code is unchanged. The story-flow theme was not touched, and nothing was deployed.

## Gates (last run, on the final commit)

| Gate | Result |
|---|---|
| `tools/generate_project.py` | no project change |
| `tools/check_scaffold.py` | PASS |
| `tools/check_a11y_lint.py` | PASS, 0 new |
| `tools/contract_ratchet.py --check` | 52 failing, baseline 52 (after the combined-r7 merge), **new 0**, fixed 0 |
| `tools/check_design_consistency.py` | PASS (raw font 0, tracking 0) |

One contract pin needed care. `test_w2_04_orders` requires the literal `ProfileOrderSourceDetailSections(order: order)`, so the new section slots are passed through `.mpSlots(...)` and that call text is unchanged. The test was not edited.

## Root page: MP `cy-profile` (self, player) → `App/AccountView.swift` (Passport tab root)

| MP section, top to bottom | Native before | Difference | Fixed? |
|---|---|---|---|
| Identity header: avatar (edit), name, level badge, `Lv.N 城市探索者`, city, `连续探索` | `MemberIdentityCardSection` | Same content | — |
| 好友 / 关注 / 粉丝 row, hidden on one's own page when all three are 0 (1121 N5) | Always shown | Extra row at 0/0/0 | **Fixed.** It hides only for three known zeros. Unknown values still show "—" (`MemberHomeHeader.swift`). |
| Primary 票夹 button | Same (`member.card.tickets`) | — | — |
| Tabs 我的 · 帖文 · 成就 · 关于 (`TAB_LABELS`) | One long Form with no tabs, and sections in a different order | Structure | **Fixed.** A segmented `Picker` (`cyAdaptiveSegmented`, `account.mine.tabs`) uses the same keys as the public profile tabs. 帖文 only appears when the community bundle is injected, matching MP `communityReadable()`. |
| 我的 → 我的订单 | Orders section | Same place | Moved to the 我的 tab |
| 我的 → 我的项目 (preview + 管理全部) | Missing on Passport (it lived only in Settings) | Missing | **Fixed.** `ProfileSelfProjectsEntry` is the same preview the public 我的 tab uses. |
| 我的 → 视频悬赏 | `MPParityAccountLinks` | Was after 当前权益 | Moved to after the projects |
| 我的 → 我的资产 (账户余额 → earnings) and 通行证与礼品 | Assets section. On Passport the Wallet row was hidden in favour of a circle button. | Wallet entry was in the wrong place | **Fixed.** The Wallet row now shows on every host, under 我的资产. |
| 成就 → points, 总积分排名, 收集册 (勋章 / 邮票 / 藏品) | Passport overview with Wallet/Messages capsules, then the 收集册 section | The capsules were extra | **Fixed.** `showsActions: false` removes them. Messages stays in the toolbar entry. The stamps, badges and 收集册 now sit on 成就. |
| 关于 → 个人介绍 (编辑) / 兴趣标签 (添加兴趣) / 加入时间 | Only links | Missing | **Fixed.** New `MemberAboutSection` reads the identity card's own `/api/user/info` snapshot, so there is no second request. One new key: `member.about.addInterest`. |
| 关于 → 探索与更多 (我的优惠券, 邀请好友), 当前权益 | Collection links, then benefits | Same order | Moved to 关于 |
| (Settings-only in the MP) teams, guide, location share, complaint, report history, support | Spread through the page | Extra | **Fixed (continue).** Removed from 我的. Settings (`SettingsView.swift`, MP `pages/shezhi` order) already had 城瘾玩法 and 投诉建议. 个人位置共享 now follows 隐私与定位, and 我的举报 follows 我的申诉 (MP `appeal-mine` is modelled on `report-mine`). Teams and 客服工单 have no MP 我的/设置 row, so they sit with the app-only rows after 关于. The entry ids are now `settings.personalLocationShare`, `settings.reportMine` and `settings.teams`. `tools/check_personal_location_share.py` and `test_social_guide_templates` now read `SettingsView.swift`. |

## Subpages

The audit of 14 member subpackage pages was done read-only, and every change below was checked against the MP `.wxml`.

| MP page | Native view | Difference | Fixed? |
|---|---|---|---|
| `mycanyu` (我的参与) | `PlayerJourneyViews.swift` `ParticipationHistoryView` | 查看报名凭证 showed on every row; MP shows it only when `voucherAvailable` | **Fixed** (`row.id > 0`) |
| `mycanyu` | same | Filter tabs showed while signed out; MP keeps them behind the login gate | **Fixed** |
| `myinvite` (邀请记录) | `SocialInviteHistoryView.swift` | The hero showed even with no invitees; MP shows it only when `groups.length` | **Fixed** |
| `myinvite` | `Localizable.xcstrings` | `profile.inviteRewards.heroPending` zh-Hans was the English "Syncing" | **Fixed** (待同步) |
| `report-mine` (我的举报) | `SquareReportProgressView.swift` | Chips showed while loading, on error and on 全部-empty | **Fixed.** Filtered-empty still keeps the chips. |
| `report-mine` | same | The stage tag was a line above the title; MP puts it at the end of the title line | **Fixed** |
| `invoice/index` (我的发票) | `InvoiceLaunchHistoryView.swift` | The state and recovery banners were above the tabs; MP puts the tabs first | **Fixed** |
| `coupon-wallet` | `AccountCollectionCouponsView.swift` | The status badge was above the name; MP puts it at the end of the name line | **Fixed** |
| `points-history` (积分明细) | `WalletCommerceViews.swift` ledger row | The after-balance was in the left column; MP puts it under the delta | **Fixed** |
| `signup` (票夹) | `TicketWalletView.swift` | The empty state had no 去探索 | **Fixed.** Uses the existing `onExplore`. New key: `ticketWallet.emptyExplore`. |
| `appeal-mine` (我的申诉) | `MemberScoreAppealListView.swift` | 账号信誉 showed only after a clean load and had no chevron | **Fixed.** It shows whenever it is known, with a chevron. |
| `orderinfo` (订单详情) | `ProfileOrdersView.swift` + `ProfileOrderSourceDetailSections.swift` | Team, 商家消息 and 发票 were out of MP order | **Fixed.** The order is now team → 订单进度 → 商家消息 → 支付信息 → 发票 → 报名人 → 凭证. |
| `order` (我的订单) | `ProfileOrdersView` | Pending rows show 查看详情 rather than 立即支付; `pendingPayAmount` is not decoded | **Fixed (continue).** Core `ProfileOrder.pendingPayAmount` is `payableAmount` on `registrationStatus == 1`, as in MP OR-021. The 待付款 line uses it and hides when it is nil. Under the card, pending rows show 取消订单 (`.bordered`) and 立即支付 (`.borderedProminent`). Both open the existing reviewed `OrderLifecycleView` sheet. They show only when `cardPayNowShown` (payment switch on, which is the 11-26 owner decision) and a reviewed writer is mounted. Otherwise the 查看详情 pill stays. |
| `order` | same | The filter is hidden when there are no orders; MP always shows the tabs | **Fixed (continue).** `ProfileOrderFilterSection` sits above the empty state. The UI test `testTrueEmptyIsNotFilteredEmpty` asserts the picker. |
| `coupon/coupon` | `CouponManagementView` | The title reads 我发布的优惠券; MP says 优惠券 | Not done. This is a publisher/merchant-scoped screen, which is out of scope. |
| `coupon-wallet` | same | The shop line comes after the dates; MP puts it before | **Fixed (continue).** Order is now head → description → shop address → dates → code footer. The line shows when `shopAddress` is present and draws the address only, as MP `wallet-card__shop` does. The 导航 capsule is re-anchored with a custom `VerticalAlignment.couponShopLine` guide set on the shop line. Its default is the view's own centre, so without propagation it would sit at the card's vertical centre. This needs a simulator look. The 44 pt bottom spacer is gone. |
| `market/passes` | `PassMarketViews.swift` | The pass-order row drops `time` under the amount; the gift row has no `name` | **Fixed (continue).** The 通行证订单 row shows `time` under the amount. Core `PlatformPassGift.productID` (`productId`) and `name(nameByID:)` mirror MP `giftRow`. The gift title is name, else state, and the state moves to the sub line. |
| `tixianjilu`, `orient-score`, `character`, `complaint` | various | Already matched, or covered by the `mp-prme` receipt | — |
| `signup` | `TicketWalletView` | No avatar → 我的 button; no inline QR flip deck | Not done. This is a deliberate layout (NAT-12). |

## Re-scan of the remaining subpackageMember pages (continue)

Three read-only audits compared each page with the MP `.wxml` and `.js`, and I checked every finding below before acting on it. `free-explore` is covered by the `mp-journey-r3` receipt.

| MP page | Native view | Fixed now | Left (needs Core/network, or is gated) |
|---|---|---|---|
| `invoice-detail` | `InvoiceLaunchDetailView.swift` | Issuing-group tag reads 开具中 (new key `detailTag.issuing`). The non-MP big amount is removed from the status card. 抬头类型 hides when empty, and anything other than COMPANY reads 个人. | No skeleton while the detail loads. The shared pending banner is described below. |
| `invoice-apply` | `InvoiceLaunchApplyView.swift` | 已选订单 reads 「N 笔」 (new key `selectedCountValue %lld`). The bottom bar no longer repeats 总计. | The bar hides instead of disabling (Core `showsApplyAction`). Pending copy is in the top banner rather than in the bar. A confirmed 查询结果 and a successful submit do not go back to 我的发票. Unknown refusal codes drop the server `msg` (Core `InvoiceLaunchIssue`). |
| `invoice-titles` | `InvoiceLaunchTitlesView.swift` | — | The not-found copy should be 暂未查到这次保存. Add is hidden instead of disabled. There is no empty state while a save is pending. A failed delete ignores the server `msg`. |
| `invoice-title-edit` | `InvoiceLaunchTitleEditor.swift` | The masked-tax line and the 必填 footer are removed, so the form ends at 设为默认 as in the MP. | 保存 is hidden instead of disabled. There is no 重试 or server `msg` on a failed save. The query does not resend. The page does not re-read titles on open. |
| all four invoice pages | `InvoiceLaunchPresentation.swift` | — | **Shared:** one `model.unresolved` flag stands for any pending write. A pending apply therefore shows its banner on the title pages and blocks title writes (MP never blocks delete). This needs the coordinator keyed by `pending.kind` (Core `InvoiceLaunchCoordinator`). |
| `coupon-qr` | `CouponCodeView.swift` | The non-MP 出示给商家扫码核销 line and the 出示核销码不代表已核销 footer are removed. The name/description card shows only on the used, expired and revoked results. | Every error reads one fixed message where the MP gives the specific `errMsg`. Revoked (410) and signed-out have no 重试. The poll-error sub-line is missing. All of these need the coordinator to carry the reason. |
| `mycanyuinfo` | `PlayerJourneyViews.swift` `ParticipationDetailView` | Sections are in MP order: title and badges → cover → node / 接待时间 → 自由探索权益 → 角色卡 → 定向成绩 → 核销 stats → template → rules. The non-MP 参与日程 block is removed (contract test updated), along with the 核销进度 and 规则说明 headers. The cover is its own row, not a left thumbnail. | The countdown has no hours and no 活动 noun (Core `ProfileParticipationSchedule`). Unknown counts read — where the MP reads 0. 核验扫码, 取消参与 and 联系客服 are list rows, not the footer bar, and 取消参与 has no in-place cancel write. There is no 链接已失效 state for 403/404. 去修改 stays behind the merchant gate. |
| `report-detail` | `MemberReportProgressDetailView.swift` | The privacy line is inside the head card. 提交申诉 and 申诉已受理 come after the timeline. The evidence-count row is removed. 提交于 hides when the time is unknown. | The unknown-stage hint is missing. Timeline items should read 进入「stage」. A refresh clears the content (Core coordinator keeps no previous detail). There are no 403 or missing-param states. The appeal sheet has an extra 再试一次. |
| `market/pass` | `PassMarketViews.swift` | The non-MP 首次使用时激活 block is removed. | The 自己用 / 送给好友 tabs never show (`giftAllowed` is not decoded). There is no `/product/quote`: no cash or points rows and no requote state. Group/school products use a separate checkout panel. The error always says 重试. The guest bar is not shown for every product. These are purchase-adjacent and gated. |
| `market/gift` | `PassMarketViews.swift`, `MPParityKit.swift` | — | A guest sees a sign-in wall where the MP shows the gift and asks for login on 领取. In code mode there is a 兑换码 headline, a dead end for guests, the error does not clear while typing, and there is no hero icon. |
| `market/membership` | `PassMembershipViews.swift` | The facts list shows without plans. The 购买须知 header and the repeated buy label are removed. | A guest gets 加载失败, because Core `overview(token:)` requires a token. `validToText` is not decoded. The plan tag is not limited to 年卡 / 月卡. The no-channel copy differs (gated). |
| `market/pass-order` | `PassMarketViews.swift` | — | Refund terms are fixed text rather than read from `/api/platform-pass` `terms`. An empty reason disables 提交 instead of showing 请填写退款原因. |
| `market/library` | `PassMembershipViews.swift` | The card's top row (¥0 可玩, city) is now above the title, as in the MP. | There is no 城 mark and there are no tag chips (`PassLibraryCard` does not carry `tags`). Error copy is fixed (the server `msg` needs Core). |

## Coordinator visual check (14:13 UTC) — structure restored (continue 2)

The 14:13 build rendered `--design-fixture d2-me`. That fixture (`App/DesignFixtures/D2Fixtures.swift` `D2MeFixture`) still drew the bare identity card and then 当前权益, with no tabs. The identity card itself also carried the 积分 hero and the 连续打卡天数 row on every host.

| MP `cy/profile/index.wxml`, top to bottom | Native now | Fixed? |
|---|---|---|
| Large title 我的 (OWNER RULE 2), settings top-right | `.cyRootHeader(.mine)` in `AccountView` and now in the fixture (the fixture was an inline `account.title`) | **Fixed** (fixture) |
| Identity card: avatar (pen), name, role/level, city | `MemberIdentityCardSection` | — |
| 好友 / 关注 / 粉丝 (hidden at 0/0/0) | Same | — |
| `pc-actions`: [开始探索] [票夹] same size, both primary, then [···] | New `actionRow`: two `.borderedProminent` buttons with `maxWidth: .infinity`, then a `.bordered` `Menu` (···: 公开主页, 编辑资料). It stacks at accessibility sizes. 开始探索 = `onOpenGuideDestination(.roam)` (MP `onPrimaryCta` → `goRoam`). | **Fixed.** New keys: `member.card.startExplore`, `member.card.more`. |
| Tabs 项目 / 帖文 / 成就 / 关于 | Segmented `Picker` (`account.mine.tabs`). The first tab now reads 项目 (`account.mine.tab.projects`), so it no longer repeats the 我的 title. MP `TAB_LABELS.projects` is 我的; the wxml block is `TAB · 项目`, and the coordinator asked for 项目. | **Fixed** |
| 积分 + 连续打卡 inside the card | `showsMetrics: false` removes them from the card | **Fixed** |
| 成就 head: 积分 (→ 积分明细) + 如何获取积分, then 总积分排名 (累计打卡, → 成长中心) | New `MemberAchievementMetricsSection`: 积分 (→ ledger), 如何获取积分 (→ 积分任务 sheet), 连续打卡天数, 累计打卡, then the 成长中心 row, which moved here from 收集册. After that come stamps/badges and 收集册. | **Fixed** |
| 项目 → 我的资产: 账户余额 (P-49: ¥0, never "—") | The wallet row is now `LabeledContent` 账户余额 · ¥0.00, reading the card's `/api/user/info` snapshot (no new request) | **Fixed** |
| 关于 → 当前权益 | `MemberBenefitsSection` stays on 关于 only | — (fixture now shows it under 关于, not under the card) |

The fixture can open a tab with `-d2MeTab achievements` or `-d2MeTab about`. It shows 项目 · 成就 · 关于, because 帖文 needs the community bundle.

**MP note:** in the current wxml the self-player view hides 开始探索 (`(isSelf && isMerchantView)`) and the ··· (`!isSelf`), while `onPrimaryCta` still routes self → `goRoam`. The row follows the coordinator check. If the owner wants the literal current wxml, drop `onStartExplore`/`moreMenu` and it falls back to the single 票夹.

Gates: generate_project (no change), check_scaffold PASS, a11y lint 0 new, design consistency PASS (0 raw font, 0 tracking), missing string keys 0, contract ratchet 52/52 with **new 0**.

### Re-scan of 项目 (continue 2)

| MP `cy/profile` 项目 | Native before | Fixed? |
|---|---|---|
| 我的订单 → 我的项目 → 视频悬赏 → 我的资产 → 通行证与礼品 | 我的发票, 我的参与/已完成 and the host-tip/redeem/landing section sat between 订单 and 我的资产 | **Fixed.** `MPParityAccountLinks(part:)` splits into `.bounty` (promo / 视频悬赏, before 我的资产) and `.extras` (app-only rows, after it). The app-only rows (我的参与, creator rows on the legacy host, extras) now follow the MP sections. |
| 我的发票 is a 设置 row (MP `shezhi.js:221` → `invoice/index`) | Duplicated on 我的 | **Fixed.** Removed from 我的; Settings keeps `SettingsInvoiceEntry`. |

### Re-scan of 关于 (continue 2)

| MP `cy/profile` 关于 (wxml:498-560) | Native before | Fixed? |
|---|---|---|
| 个人介绍 → 兴趣标签 → (探索作品) → 加入时间 → 探索与更多 (我的优惠券, 邀请好友) → 当前权益 | The 公开主页/关注列表/编辑资料 section and the local cover sat before 探索与更多, and 邀请好友 came after 当前权益 | **Fixed.** Order is now `MemberAboutSection` → `AccountCollectionAccountLinks` (优惠券…) → 邀请好友 / 邀请人 → `MemberBenefitsSection` → app-only rows (公开主页, 关注列表, 编辑资料, cover, messages/clubs/player code, private home, sign-out). |

## Not done / next

- 探索作品 images on 关于: **blocked.** `NativeMediaGalleryEntry` with no reader falls back to `RetainedPublicImageReader()`, which is disabled and origin-gated by design, and the session has no approved case-picture reader (`ProfileEditView` gets `caseImageReader: nil` too). Enabling one is an appsec/config decision, not a layout fix.
- Simulator look needed: the `d2-me` fixture (`-d2MeTab achievements|about`) and the ··· `Menu` inside a `Form` row next to two `.borderedProminent` buttons.

## Strings

`docs/port/strings/mp-mine-r3.json` is merged into `Resources/Localizable.xcstrings`:
- `member.about.addInterest` (Add interests / 添加兴趣)
- `ticketWallet.emptyExplore` (Explore / 去探索)
- `profile.inviteRewards.heroPending` (zh-Hans changed to 待同步)

## Continue 3 (re-arm after the 15:09 check): Not-done rows from the subpage re-scan

Merged `origin/ui/combined-r7` (clean). The 我的 structure from the 14:13 check was already in place (tabs 项目/帖文/成就/关于, [开始探索][票夹][···], 积分/打卡 in 成就, 当前权益 in 关于), so this pass works the re-scan's Not done rows that need only view changes.

| MP page | Native view | MP says | Fixed now |
|---|---|---|---|
| `invoice-titles` | `InvoiceLaunchTitlesView.swift` | Footer 新增发票抬头 shows once loaded and is `disabled` while a save is pending or writing | **Fixed.** Shows on `facts.showsAdd`, disabled on `!facts.canAdd`. |
| `invoice-titles` (+ shared state section) | `InvoiceLaunchPresentation.swift` `InvoiceLaunchStateSection` | A missed title recheck: toast 暂未查到这次保存, and the inline error stays 上次保存结果未确认 · 确认前请勿修改抬头 · 查询结果 | **Fixed.** A title save that was not found reads 暂未查到这次保存 with the 确认前请勿修改抬头 line and keeps 查询结果. Apply/cancel keep 暂未查到这次申请 · 再查一次. New key `titleSave.notFound` in `InvoiceLaunchUI.xcstrings`. |
| `invoice-title-edit` | `InvoiceLaunchTitleEditor.swift` | 保存 stays and is `disabled="{{!canSubmit \|\| titlePending}}"`, loading while writing | **Fixed.** The toolbar 保存 stays while a save is unconfirmed and is disabled on pending, busy or invalid input. |
| `invoice-detail` | `InvoiceLaunchDetailView.swift` | `cy-skeleton type="form-section" count="2"` while the detail loads | **Fixed.** Two `CYSkeleton(.formSection)` sections (system redacted placeholder) until the detail arrives. |
| `market/pass-order` | `PassMarketViews.swift` `PassOrderRefusedWrites` | 提交申请 is always tappable; an empty reason answers 请填写退款原因 | **Fixed.** No longer disabled. An empty submit shows 请填写退款原因 in the footer (red, cleared on typing). |
| `market/gift` | `MPParityKit.swift` `.gift` route | A guest sees 好友送你一份通行证 · 领取; 领取 asks to sign in (`ensureLoginFor`) | **Fixed.** Guests get `PassGiftClaimView` in the ready state and 领取 opens sign-in. The separate sign-in wall is gone (`mp.gift.signIn` is now unused). |
| `mycanyuinfo` | `PlayerJourneyViews.swift` | Unknown order stats read 0 | **Kept, on purpose.** Core `ParticipationDetail.pendingText` documents "unknown statistics stay an em dash" and `test_w2_04_participation` pins it. A literal 0 still reads 0. Owner call if 0 is wanted. |
| `points-history` | `WalletCommerceViews.swift` `WalletLedgerView` | No 积分任务 row on the page; first load is `cy-skeleton type="list" count="3"` | **Fixed.** The 积分任务 link is gone from 积分明细 (如何获取积分 stays on 成就). First load shows three `CYSkeleton(.row)` placeholders. The balance hero stays: it is the zoom target from 成就 → 积分 (motion, not a section). |
| `market/membership` | `MPParityPassSession.swift` `MPParityPassMembershipModel`, Core `PlatformPass.overview` | The page loads `/api/platform-pass` for a guest too; only 购买 asks to log in | **Fixed.** `overview(token:)` takes `String?` (the shared `get` already sends no auth header for nil), and a guest reads the plans instead of 加载失败. The buy label stays gated. |
| `market/gift?mode=code` (兑换码) | `PassMarketViews.swift` `PlatformCodeRedeemPage` | `gf-hero`: gift icon (check when claimed, dimmed on error), `codeTitle` under it only when set; typing clears the error | **Fixed.** Hero section with `gift.fill` / `checkmark.circle.fill`, no default 兑换码 headline (the nav title says it), and the result line clears on typing. Guest dead end is still open: Core `ChannelRedeemSource.status(token:)` needs a token. |
| `report-detail` | `MemberReportProgressDetailView.swift` | `eventTitle`: 举报已提交 / 已提交申诉, else 进入「stage」, else 进度更新; an unknown stage hints 状态暂时无法识别，请稍后刷新 | **Fixed.** Timeline rows read 进入「调查中」 etc. (no separate stage sub-line), and the head card always shows a hint, with the unknown-stage copy for unrecognised stages. New keys in `MemberReportProgress.xcstrings`: `report.timeline.entered`, `report.stageHint.UNKNOWN`. |
| `market/library` | `PassMembershipViews.swift` `PassLibraryCardView`, `MPParityPassSession.libraryCard` | `lb-card__tags` under the data line | **Fixed.** Core already decoded `tags`; the card now carries them and shows one secondary footnote line (native r2: no capsules). The 城 logo mark is not added: the kind line (城市定向 / 自由探索) already names it. |

Still open from the re-scan table (need Core/coordinator work or are gated): invoice shared pending keyed by kind and the apply bar (Core `showsApplyAction` hides it while unresolved, pinned by `InvoiceLaunchApplyPageTests`), server `msg` passthrough (titles delete, coupon-qr), pass `giftAllowed`/quote, the 兑换码 guest path (Core `ChannelRedeemSource.status(token:)`), report-detail refresh/403/missing-param states (Core coordinator), participation countdown/footer bar.

## Continue 4 (coordinator sweeps 16:37 en-US and 16:53 zh-Hans)

Merged `origin/ui/combined-r7` (clean, 93 commits).

| Check | MP / brief | Native view | Fixed now |
|---|---|---|---|
| 16:37 `d2-me` en: **Start exploring** wraps into four lines inside the button | `pc-actions` [开始探索][票夹][···] one row; brief: one-line capsule labels, stack when the row does not fit | `App/MemberHomeHeader.swift` `actionRow` | **Fixed.** Labels are `.lineLimit(1)`; the row is a `ViewThatFits(in: .horizontal)` of the HStack and a VStack fallback (accessibility sizes always stack). Buttons stay `.borderedProminent` / `.bordered`, `.controlSize(.large)`. Needs a simulator look at 375 pt en. |
| 16:37 / 16:53: Me tabs show Projects / Achievements / About, **推文 (Posts) missing** | `TAB_LABELS` projects · posts · achievements · about; posts shows when `communityReadable()` | `AccountView` already shows 帖文 when the community bundle is injected (MP gate). The `d2-me` fixture hard-coded three tabs. | **Fixed (fixture).** `D2MeFixture` shows all four tabs (community-readable, as the MP normally is). 帖文 renders the MP `cy-empty` 还没有帖文 as a `ContentUnavailableView` (existing key `club.tab.feed.empty`: 还没有帖文 / No posts yet). `-d2MeTab posts` opens it. |
| 16:53 `e5b-badge-wall` zh: English badge names / conditions, raw `2026-10-01` | 收集册 → 徽章墙 (`badge-wall`) | `App/DesignFixtures/E5bFixtures.swift`, `App/ObjectBadgeViews.swift` `meta` | **Fixed.** Fixture names and unlock conditions follow the UI language. The obtained date reads 2026年10月1日 in zh (`Date.FormatStyle(date: .long)`, fixed UTC civil day, no literal CJK); other locales keep `LocaleDisplay.civil` (Oct 1, 2026). |

The real 我的 帖文 tab content (`SquareMineAccountLinks`: 我的帖文 / 我的收藏 rows) is still links rather than the MP inline post feed with the composer; that needs the author-posts reader mounted on Passport (`ProfileAuthorPostsSection` + `OwnProfileComposerHost`, as the public profile does). **Done in continue 5** (below).

Gates (continue 4, commit 403e13b0c): generate_project no change, check_scaffold PASS, a11y lint 0 new, design consistency PASS, check_l10n adds no CJK literal in my files, contract ratchet 52/52 **new 0** (a run overlapping a second ratchet showed 14–21 spurious catalog failures; the solo rerun and plain combined-r7 are both 52/0).

## Continue 5 (hourly re-arm)

Merged `origin/ui/combined-r7` (clean). The 17:24 sweep for mp-mine shows only the launch logo (coordinator: taken under load, ignore), so no new visual rows.

| MP page | Native view | MP says | Fixed now |
|---|---|---|---|
| `cy/profile` `TAB · 推文` (wxml 259-285) | `App/AccountView.swift` `postsTabSections` | Self: composer (发帖文 · 有什么新鲜好玩的分享吗？) → `cy-error` 帖文加载失败 · 重试 / `cy-empty` 还没有帖文 → own posts as the shared post card → own club posts | **Fixed.** 帖文 now mounts the same parts as the public profile's own-posts tab, in MP order: `OwnProfileComposerHost` (own account only) → `ProfileAuthorPostsSection` (`session.socialAccountReader` + `session.squareReader`; its own loading / error + 重试 / empty / load-more states) → `OwnProfileClubPostsSection` (MP `loadMyClubPosts`). The 我的帖文 / 我的收藏 full-list links stay after the feed (app-only). Tab still shows only with the community bundle (MP `communityReadable()`). No new strings. |
| `mycanyuinfo` → `scene-member-participation-detail` `cyinfobottom` (wxml 118-148) | `App/PlayerJourneyViews.swift` `ParticipationDetailView` | Fixed bottom bar: 开始游戏 → 取消参与 (`canCancel`) → 去修改 (`needModify`) → 联系客服 (`showContactService`) | **Fixed.** 取消参与 and 联系客服 moved from list rows into the existing `.safeAreaInset(.bottom)` bar, in MP order, as `.cySecondary(fullWidth:)` under the one `.cyPrimary` 开始游戏 (P3). Both keep their ids (`playerJourney.orderLifecycle`, `playerJourney.support`), so `testParticipationSupportStaysInSheetAndReturnsBeforeClose` still finds them. The app-only 订单进度 row stays in the list when cancelling is not open. 核验扫码 stays next to the 待核销/已核销 cells (same `showOrderStats` switch); in-place cancel write is still open (needs Core). Simulator look needed: bar height with three buttons. |

Gates: generate_project no change, check_scaffold PASS, a11y lint 0 new, design consistency PASS, contract ratchet 52/52 **new 0**.

## Continue 6 (coordinator sweep 18:15 UTC, build 95b4643ab)

Merged `origin/ui/combined-r7` (clean). Screens checked: `docs/sweeps/latest/mp-mine/sheet-en.jpg` (d2-me, e4-member, e4-self-medals, e4-settings, e4-tickets).

| Sweep row | MP / brief | Native file | Fixed now |
|---|---|---|---|
| `e4-tickets`: app quits right after launch (shot = iOS home screen) | Fix first, add a test that the fixture resolves | `App/TicketWalletFixtureSupport.swift`, `App/DesignFixtures/E1TicketFixtures.swift` | **Fixed.** `TicketWalletView` (and its detail and companion card) read `@EnvironmentObject AppSession`; the fixture hosts injected none, which is a launch-time crash. Both hosts now own a `@StateObject AppSession()` and inject it (the pattern other fixtures use). New UI test `Tests/AppUITests/Fixture_e4_ticketsTests.swift` launches `--design-fixture e4-tickets` in en and zh-Hans, waits for a `ticketWallet.row.*` and asserts the app is still `runningForeground`. |
| e4-* fixtures render dark while d2-me renders light | Fixtures must not force a colour scheme; player follows the system (`ThemeDomain.player.forcedColorScheme == nil`) | `App/DesignFixtures/DesignFixtureRegistry.swift` `wrap`, `E1TicketHolderFixture` | **Fixed.** `.preferredColorScheme(.dark)` removed from the e4 `wrap` and the e1 ticket-holder fixture. Other lanes' `wrapPlayer`/`wrapMerchant` (t5) are not mine and are listed below. |
| d2-me en: card buttons truncate ("Star…", "Tick…") | P22: one row of two equal single-line buttons + ···, stack when it does not fit | `App/MemberHomeHeader.swift` `actionRow` | **Fixed.** In the measured HStack each label is `.fixedSize(horizontal: true, vertical: false)`, so `ViewThatFits` sees the real one-line width and picks the stacked VStack instead of shrinking the labels. The VStack fallback keeps flexible labels. Needs a simulator look at 375 pt en. |
| e4-member: "Points —" | MP `pc-achievement-metrics` is `wx:if="{{profileMetricState === 'ready'}}"` | `App/MemberHomeHeader.swift` header `assets` and `MemberAchievementMetricsSection` | **Fixed.** The 积分 block hides while points are unknown (the ¥ column still shows when known). On 成就, 积分 / 连续打卡天数 / 累计打卡 each show only once known; the 成长中心 row stays. |
| e4-self-medals (public profile): "Relationship ? —" | The MP self page has no relationship line; other members carry it on 关注 | `App/SocialPublicProfileView.swift` | **Fixed.** The 关注关系 row shows only for another member, read-only, with a known `isFollowed`. The `?` unknown variant is gone (`social.relationshipUnknown` now unused). |
| e4-self-medals: "— Friends / Following / Followers" | MP `pc-stats` hides on one's own page at 0/0/0 (1121 N5) | same | **Fixed.** New `showsCounters(_:)`: hidden while all three are unknown, and on one's own page at three known zeros. |
| e4-settings: "Become a club host" is centred blue text above normal icon rows | One row pattern: icon + title + chevron (OWNER RULE 2) | `App/SettingsAccountEntries.swift` | **Fixed.** The button row is `Label` + `Spacer` + tertiary chevron in `.primary`, the same as the Settings search-result button rows; it shows a `ProgressView` in place of the chevron while `POST /api/club/my` is in flight. Id `settings.becomeClubHost` unchanged. |

Not changed, needs a look: the d2-me tab picker shows the menu fallback ("Profile section · Projects") in English, because four segments with "Achievements" do not fit at 375 pt and `cyAdaptiveSegmented` falls back to the system menu picker. Shortening the MP copy is not an option. An owner/ds-consistency call is needed if a scrolling tab strip is wanted instead.

### For other lanes
- mp-club: `d4-badges`, `d4-stamps` quitting at launch is likely the same cause: check those hosts for a view with `@EnvironmentObject AppSession` and no injection.
- ds-consistency: `DesignFixtureRegistry.wrapPlayer` (t5 fixtures) still forces `.dark`, and `wrapMerchant` forces `.light`.

## Continue 7 (hourly re-arm, sweep 18:54 UTC build 1300a48db)

Merged `origin/ui/combined-r7` (clean). The 18:54 sweep was built before Continue 6 landed (9ae58daa8 is not in 1300a48db), so the d2-me truncation (en "Star…" and now also zh "开…"), "Points —", "Relationship ? —", "— Friends" and the centred club-host row in `sheet-en.jpg` / `sheet-zh-Hans.jpg` are the pre-fix state; they need the next sweep to confirm. New this pass, from the same sheets:

| Screenshot | MP / brief | Native file | Fixed now |
|---|---|---|---|
| `zh-Hans-ia-passport.jpg`: badge rail reads "Night Owl / First Roam / Market" in the Chinese UI; the page renders dark while d2-me is light; inline title on a tab root | Fixture data in the launch language (16:53 sweep rule for e5b); fixtures follow the system appearance (18:15); tab root = large top-left title (OWNER RULE 2) | `App/DesignFixtures/IAFixtures.swift`, `App/DesignFixtures/DesignFixtureRegistry.swift` | **Fixed.** New `iaFixtureText(en, zh)` (same rule as e5b `tt`) for the ia-passport / ia-passport-ax5 badge names (夜猫子 / 第一次漫游 / 菜场常客); `.preferredColorScheme(.dark)` removed; the title goes through the shared `.cyRootHeader(.mine, titleKey: "tabBar.passport")` (large, the typography lint's tab-root rule). |
| `zh-Hans-e4-tickets.jpg`: card date reads raw `2030-04-20` | MP `subpackageMember/signup/index.js` writes dates as「M月D日」, never the raw server string | `App/TicketWalletView.swift` `TicketWalletRow.participateDateText` | **Fixed.** A `yyyy-MM-dd…` participate date is read as a Beijing calendar day and shown with `Date.FormatStyle(date: .abbreviated)` in the user's locale (2030年4月20日 / Apr 20, 2030); anything else stays as sent. The ticket titles ("Sample exploration ticket") are Core synthetic server data and stay. |
| `zh-Hans-e4-member.jpg`: nav title reads "Member fixture" (English, inline) in the Chinese UI | Tab root = large top-left title, both languages (OWNER RULE 2) | `App/MemberHomeFixture.swift` `MemberHomeFixtureHost` | **Fixed.** `.cyRootHeader(.mine)` (我的 / Me, large). The fixture still hosts only the identity card + 当前权益 (a component host for UI tests); the full MP order is shown by `d2-me`. |

Gates (this pass): generate_project no change, check_scaffold run, a11y lint PASS 0 new, contract ratchet 52 failing / baseline 52 / **new 0**, design consistency PASS, typography lint PASS.

### For other lanes
- ds-consistency / fixture owners: `tools/check_design_fixture_release_exclusion.py` already fails on `origin/ui/combined-r7` (audit list is missing `CityDiceFixture`, `CityFixtureMonopoly`, `CityKit*`, `D2MeFixture`, `E3PressStyle`, `FixR3PlayRoamBFixtures`, `R3InPlaceKitFixture`, `R4*`). Not changed here; `D2MeFixture` is the only mp-mine one, left so the audit list is updated in one place.

## Continue 8 (hourly re-arm, sweep 19:36 UTC build 3568fe51b)

Merged `origin/ui/combined-r7` (clean). The 19:36 sweep includes Continue 6 (9ae58daa8) but not Continue 7 (5826cc728), so the ia-passport title/appearance, e4-member title and the ticket date in `sheet-*.jpg` are still the pre-fix state. Screens checked: `docs/sweeps/latest/mp-mine/sheet-en.jpg`, `sheet-zh-Hans.jpg`.

| Screenshot | MP / brief | Native file | Fixed now |
|---|---|---|---|
| `zh-Hans-d2-me.jpg`, `en-d2-me.jpg`: the row no longer truncates, but it stacks 开始探索 and 票夹 as two full-width bars and leaves the ··· alone as a small capsule on a third line | MP `pc-actions` (wxml:96-112): 开始探索 is a text-only `pc-primary`, 票夹 has the coupon icon, same size; P22 stack rule | `App/MemberHomeHeader.swift` `actionRow` | **Fixed.** 开始探索 drops the `safari` icon (MP has none), which also gives the one-line row more room. When the row does not fit (or at accessibility sizes), 开始探索 takes the full width and [票夹][···] share the second line, so the ··· never sits alone. Labels in the stacked form may wrap to two lines instead of truncating. Needs a simulator look. |
| `*-e4-self-medals.jpg`: "Medal reads: 0" and a "Retire synthetic account" link under the public profile | No developer text on a player screen (19:50: "remove debug text from the visible fixture") | `App/ProfileSelfMedalsFixture.swift`, `DesignFixtureRegistry` | **Fixed.** New `showsTestControls` (default true for the UI tests that read the counter); the `e4-self-medals` design fixture passes false. |
| `*-ia-passport.jpg`: "Synthetic fixture: identity card goes here (MemberIdentityCardSection)" as the first card | Same | `App/DesignFixtures/IAFixtures.swift` | **Fixed.** The placeholder section is removed; the fixture hosts only the passport overview (the identity card is shown by d2-me). |
| `zh-Hans-e4-wallet-balance.jpg`: ledger reasons are English in the Chinese UI | 19:50: fixture data follows the UI language | `App/WalletCommerceFixtureHost.swift` `designLedger` | **Fixed.** Balance and points reasons go through `iaFixtureText(en, zh)` (周末城市漫步分成, 提现申请 …). The zh dates stay as the server sends them (`LocaleDisplay.civil` keeps Chinese unchanged by design, as the MP does). |
| `en-t5-order-center.jpg`: 杭州老城畅玩卡 and 已支付 in the English UI | Same | `DesignFixtureRegistry` `T5OrderCenterTransport` | **Fixed.** Title and status follow the launch language. |
| `*-e5b-badge-wall.jpg` renders dark while d2-me is light | 18:15: fixtures follow the system appearance | `App/DesignFixtures/E5bFixtures.swift` `E5bBadgeWallFixture` | **Fixed.** `.preferredColorScheme(.dark)` removed (the other e5b fixtures belong to mp-roam / a11y-dt and are left). |

Next pages in the area (no row before):

| MP page | Native view | Difference | Fixed? |
|---|---|---|---|
| `orient-score` (本局计分) | `App/OrientScoreView.swift` `OrientScoreReadyContent` | Order checked against wxml: 本局计分 · phase + total → dimensions → pending card → 结算结果 → 历史操作人工核对 (when any) → 本场榜单 → 计分时间线 → 计分申诉 → 成绩争议 → form. Native is the same order, inset-grouped `List`, text styles. | — (matches) |
| `character` (我的角色卡) | `App/CharacterCardReadbackView.swift` | MP puts 刷新角色卡 as the last section in the scroll (wxml:61); native pins it in a custom `safeAreaInset` bar with its own `bgPage` background. `CharacterSheetDetailView` already draws the in-list button when the host is `.refreshable`. | **Not done.** `CharacterCardReadbackView.swift` is byte-pinned in `docs/issue5-hunks/C02-ios-pbx.rnhunk.md` (`test_c02 … test_sha256_manifest_covers_exclusive_sources`); the change (`.refreshable { await model.load() }` + a failure footer on the refresh section) was reverted. Needs the pin owner to re-hash. |

Still open for the owner: in English the four Me tabs (Projects / Posts / Achievements / About) do not fit a segmented control at 375 pt, so `cyAdaptiveSegmented` shows the menu picker ("Profile section · Projects"). zh fits. Options: an English label shorter than "Achievements" (en-layout call) or accept the menu.

Gates (this pass): generate_project no change, check_scaffold PASS, a11y lint 0 new, design consistency PASS, typography lint PASS, contract ratchet 52 failing / baseline 52 / **new 0**.

### For other lanes
- mp-roam / a11y-dt: `E5bMomentFixture`, `E5bJoinFixture`, `A11yRoamAX5Fixture` still force `.preferredColorScheme(.dark)`.
- Core fixture owners: `Core/TicketWalletSyntheticFixtures.swift` ticket names ("Sample exploration ticket") are English in zh-Hans; shared with Core tests, so not changed here.

## Continue 9 (hourly re-arm, sweep 20:25 UTC build a250afd77)

Merged `origin/ui/combined-r7` (clean). The 20:25 sweep includes Continue 7 but was built before Continue 8 (77c732c08), so the ··· layout, the debug lines and the zh ledger reasons are still the pre-fix state there. Screens checked: `docs/sweeps/latest/mp-mine/zh-Hans-e4-tickets.jpg`, `zh-Hans-e4-wallet-balance.jpg`.

| Screenshot | MP / brief | Native file | Fixed now |
|---|---|---|---|
| `zh-Hans-e4-wallet-balance.jpg`: hero "128.50 CNY", rows "+58.00 CNY" / "128.50 CNY" | 20:25: amounts in zh as ¥, not "CNY"; MP profile wxml:226 shows ¥ | `App/WalletCommerceViews.swift` `WalletLedgerView` hero + `ledgerRow`; `App/WalletNumberLocalization.swift` | **Fixed.** New `WalletFormatting.symbolMoney(_:currency:)` puts the one-glyph symbol before the number (+¥58.00, ¥128.50) and keeps the sign first. The ledger hero shows ¥ in the leading symbol slot (same as `WalletEarningsHero`), rows and after-balance use it. Currencies without a one-glyph symbol and unknown currencies keep the old code suffix / unknown label. The shared `WalletFormatting.amount` is unchanged (pinned by `WalletNumberLocalizationTests`), so other wallet screens still read "… CNY"; see "For other lanes". |
| `zh-Hans-e4-tickets.jpg`: thumbnail is an empty grey box with a dot | 20:25: cover, or a `ticket` SF Symbol on `bgSurfaceSubtle` | `App/TicketWalletView.swift` `TicketWalletRow.coverIllustration` | **Fixed.** With no cover (and while / if the cover fails to load) the slot shows `ticket` in `.secondary` on `CYColor.bgSurfaceSubtle`, same size and corner radius. |
| `zh-Hans-e4-tickets.jpg`: "Sample exploration ticket" in the Chinese UI | 19:50 / 20:25: fixture data follows the UI language | `App/TicketWalletFixtureSupport.swift` | **Fixed.** The fixture reader maps the five Core synthetic names to zh (示例探索票 …) when launched in Chinese. Core JSON is unchanged, so the English UI tests that read "Sample exploration ticket" keep passing. |

### For other lanes
- ds-consistency / i18n: `WalletFormatting.amount` still renders "1,234.50 CNY" on the other wallet screens (earnings detail, withdrawal records, cart/checkout). Moving it to `symbolMoney` needs the `WalletNumberLocalizationTests` pins updated together.

Gates (this pass): generate_project no change, check_scaffold PASS, a11y lint 0 new, design consistency PASS, typography lint PASS, contract ratchet 52 failing / baseline 52 / **new 0** (the ledger detects an unknown delta by `row.changeBalance == nil`; `row.signedText(` stays out of the views per `test_wallet_number_localization`).

## Continue 10 (hourly re-arm, sweep 20:45 UTC build bb76e327c)

Merged `origin/ui/combined-r7` (clean). The 20:45 sweep includes Continue 8 but not Continue 9 (f273b1fd1), so the "CNY" ledger amounts and the grey ticket thumbnails in `sheet-*.jpg` are still the pre-fix state. Confirmed in the sheets: d2-me stacks [开始探索] over [票夹][···] (en) and fits one row (zh); the ia-passport, e4-member and badge-wall titles/appearance are fixed. Screens checked: `docs/sweeps/latest/mp-mine/sheet-en.jpg`, `sheet-zh-Hans.jpg`, `en-e4-self-medals.jpg`.

| Screenshot | MP / brief | Native file | Fixed now |
|---|---|---|---|
| `en-e4-self-medals.jpg`: name line reads "— City explorer" | MP `cy/profile` wxml:69 `<text wx:if="{{growthLevel > 0}}">Lv.{{growthLevel}} 城市探索者</text>`; no placeholders as data | `App/SocialPublicProfileView.swift` identity head | **Fixed.** The Lv line shows only for a known level > 0. |
| `*-e4-self-medals.jpg`: "Looks like you're offline. Showing what's saved." banner on a normal profile | Sweep fixtures are online player screens | `App/ProfileSelfMedalsFixture.swift` | **Fixed.** The design fixture (`showsTestControls: false`) reads online; UI-test hosts keep the offline example. |
| `*-e4-self-medals.jpg`: 帖文 empty reads 暂无动态。 / "No posts yet." | MP 推文 `cy-empty` copy 还没有帖文 | `App/ProfileAuthorPostsSection.swift` | **Fixed.** Uses the existing `club.tab.feed.empty` (还没有帖文 / No posts yet), identifier unchanged. |
| same: a "Refresh posts" button row above the posts | MP refreshes by pull-down only | same | **Not done.** `profile.postsRefresh.refresh` is driven by `ProfileAuthorPostsRefreshFlowTests` (taps it twice); moving it to `.refreshable` needs that test rewritten with the pull gesture. |

Still open for the owner: the en Me tab picker falls back to the menu ("Profile section · Projects") because four segments do not fit at 375 pt.

Gates (this pass): generate_project no change, check_scaffold PASS, a11y lint 0 new, design consistency PASS, contract ratchet 52 failing / baseline 52 / **new 0**.

## Continue 11 (half-hourly re-arm, sweep 21:09 UTC build 405948d58)

Merged `origin/ui/combined-r7` (clean). The 21:09 sweep was built before Continue 10 (e1668c680), so the self-medals "— City explorer", offline banner and 暂无动态 in `sheet-*.jpg` are the pre-fix state. No new mp-mine rows in the 21:20 coordinator sweep or the contract-cleanup table. Screens checked: `docs/sweeps/latest/mp-mine/sheet-en.jpg`, `sheet-zh-Hans.jpg`.

| Screenshot | MP | Native file | Fixed now |
|---|---|---|---|
| `*-t5-order-center.jpg`: 金额 reads a bare "168.00" | `subpackageMember/components/cy/order-center-entry/index.wxml:9` `money.amount(summary.amountText)` → ¥168.00 | `App/OrderCenterEntryView.swift` | **Fixed.** Uses the shared `MemberBalanceDisplay.text` (¥168.00 zh, CN¥168.00 en per the i18n r1 currency rule). |
| same: rows read 订单 → 订单号 → 状态 → 金额 → 创建时间 | MP card: title → status → 金额 → 订单号 → 创建时间, then the 联系客服 button | same | **Fixed.** Rows in MP order; a 联系客服 row (`ParticipationSupportView`, the same support page the participation footer opens; id `orderCenter.support`) follows the card. No new strings. |
| `en-d2-me.jpg`: 账户余额 reads CN¥0.00 | — | — | Kept: the app's i18n r1 rule names the currency outside Chinese (`CN¥`). |

| `components/cy/ai-chat-records` (Settings → AI 对话记录) | option sheet 导出对话记录 / 清除对话记录 (danger); empty export toasts 还没有对话记录 | `App/NPCChatDataReadSettingsEntry.swift` | **Fixed** the empty-export toast (还没有对话记录 / No chat records yet). Kept the app-only 查看 option (data access) first. Not done: MP clear toast names the count (已清除 N 条对话 / 没有需要清除的对话); `clearNPCChatLogs` returns no count. |

Every `subpackageMember` page now has a row; next runs re-scan the components (`ai-chat-records`, `scene-member-withdraw-history`, …).

Gates: generate_project no change, check_scaffold PASS, a11y lint 0 new, design consistency PASS, contract ratchet 52 failing / baseline 52 / **new 0**.

## Continue 12 (hourly re-arm, sweep still 21:09 UTC build 405948d58)

Merged `origin/ui/combined-r7` (clean). No new sweep since Continue 11, so no new visual rows; this pass re-scans the member components.

| MP page | Native view | MP says | Fixed now |
|---|---|---|---|
| `components/cy/scene-member-withdraw-history` (+ `tixianjilu` shell) | `App/WithdrawalHistoryView.swift` | Amount: L09-023 `moneyText` = −¥ with the site amount format, ¥0 for zero, never a bare "-12.00"; first load `cy-skeleton type="list" count="4"` | **Fixed.** Rows and the detail sheet use `WithdrawalAmountDisplay` (`.currency(code: "CNY")` in the UI locale: −¥12.30 zh, -CN¥12.30 en; ¥0.00 for zero; "—" when unknown). The skeleton shows four rows. `WithdrawalParityFlowTests` now checks "12.30" + "¥" instead of the bare "-12.30" (pin followed the MP format). Title, empty (还没有发起提现), login / denied / failed copy, statuses, load-more + 更多提现记录加载失败 · 重试 already matched. The day-grouped sections stay (layout, no new content). |

Gates: generate_project no change, check_scaffold PASS, a11y lint 0 new, design consistency PASS, contract ratchet 52 failing / baseline 52 / **new 0**.

## Continue 13 (half-hourly re-arm, sweep still 22:11 UTC build 8fa84e4d3)

Merged `origin/ui/combined-r7` (clean). No mp-mine rows in the 22:20 sweep or the contract-cleanup table; this pass continues the member components without a row.

| MP page | Native view | MP says | Fixed now |
|---|---|---|---|
| `components/cy/scene-member-order-history` | `App/ProfileOrdersView.swift`, `App/ProfileOrderFilterSection.swift` | Filter tabs on top (9 MP options in MP order) → skeleton → 订单加载失败 / 登录后查看订单 / 当前身份不能查看订单 → 还没有城市路线订单 + 去发现城市路线 → 当前筛选暂无订单 → cards (mode tag + state / name / time / place, 实付款 / 待付款 line, 取消订单 · 立即支付 / 取消并退款 · 查看详情 / 查看退款详情 / 查看处理进度, 已下架) | — (matches; the chip row is the system filter `Picker(.menu)` per G-053, same nine options in MP order) |
| `components/cy/scene-qr-coupon` | `App/CouponCodeView.swift` | Live code: `cy-qr-voucher` title = coupon name, desc 出示给商家扫码核销, then the code, 二维码 Ns 后自动刷新, 刷新二维码 | **Fixed.** The ready state shows the coupon name (when read) and 出示给商家扫码核销 / "Show this to the merchant to scan and redeem" above the code (existing key `couponCode.presentToMerchant`, id `couponCode.voucherHead`). Not-started, not-mine, used / expired / revoked results already matched. Kept: native 核销状态暂未更新 footnote for the MP poll inline error. |
| `components/cy/report-sheet` | `im.reportPeer.*` sheet (IM / profile report) | loading → reasons → form (举报原因 / 具体说明 / 被举报方看不到你的身份 / 换个原因 · 提交举报) → 举报已提交 / 提交结果未知 | — (copy and stages already ported) |
| `components/cy/scene-share-invite` + profile 关于 `探索与更多` (wxml:533-545) | `App/AccountView.swift` `aboutTabSections` | 探索与更多 = 我的优惠券 → **邀请好友** (personal code via `/api/user/player-code`) → 当前权益 | **Fixed.** The personal-code row (我的邀请码, BL-71) sat among the app-only rows below 当前权益; it now leads the 探索与更多 section as **邀请好友 / Invite friends** (`gift`, new key `account.inviteFriends`, id `account.playerCode` unchanged, destination unchanged), before the app-only 邀请记录 / 填写邀请人. Not done: the MP share card copy (一起探索城市里的新玩法, 分享链接) on the code page; `PlayerCodeAndJoinSection` belongs to the player-gap owner. |

Gates: generate_project no change, check_scaffold PASS, a11y lint 0 new, design consistency PASS, contract ratchet 52 failing / baseline 52 / **new 0**.
| `components/cy/scene-member-order-detail` | `App/ProfileOrdersView.swift` detail + `App/ProfileOrderSourceDetailSections.swift` | 订单明细 (订单号 / 票种 / 日期与时间 / 集合点) → 支付明细 → 和队友一起出发 (仅邀请可加入 switch, 叫上队友) → 订单进度 → 支付信息 → 开票 → 报名人 → 凭证与有效期 → 联系客服 · 复制订单号 → 去支付 / 查看记录 | — (spot-checked: sections, keys and order were ported in earlier rounds, FIN-16 / orderParity). Kept: the 仅邀请可加入 choice is the `team.invitationOnly` toggle on the next step (`TeamCreateView`), still chosen before the team is created, as the MP comment requires. Not done: MP note 场次已开始，只能建仅邀请队伍 (no `teamStarted` field in `ProfileOrder`). |
| `components/cy/pass-unlock` (market/pass post-purchase reveal) | `App/PassMarketViews.swift` | Animated unlock steps after a pass purchase | Not done: purchase-adjacent and gated (see `market/pass` row); no native reveal. |

## Continue 14 (hourly re-arm, sweep still 22:11 UTC build 8fa84e4d3)

Merged `origin/ui/combined-r7` (clean). Screens checked: `docs/sweeps/latest/mp-mine/sheet-zh-Hans.jpg`, `sheet-en.jpg`.

| Screenshot | MP / brief | Native file | Fixed now |
|---|---|---|---|
| `zh-Hans-d2-me.jpg`, `zh-Hans-e4-member.jpg`: name and city read "Synthetic member" / "Synthetic City" in the Chinese UI | 19:50: fixture data follows the UI language | `App/MemberHomeFixture.swift` `MemberHomeFixtureReader.identity()` | **Fixed.** `iaFixtureText` (示例会员 / 示例城市). The en UI tests (`MemberHomeFlowTests`) still read the English names. |
| `zh-Hans-e4-self-medals.jpg`: "Synthetic medal owner" in the Chinese UI | same | `App/ProfileSelfMedalsFixture.swift` | **Fixed** (示例勋章主人; `ProfileSelfMedalsFlowTests` runs in en). |
| `*-ia-passport.jpg`: tab root title reads 护照 / Passport while the real tab root (`AccountView`, `tabBar.mine`) and d2-me read 我的 / Me | OWNER RULE 2: one top-left title per tab root | `App/DesignFixtures/IAFixtures.swift` | **Fixed.** `.cyRootHeader(.mine)` with the tab's own title. |
| `zh-Hans-t5-order-center.jpg`, `zh-Hans-e4-wallet-balance.jpg`: dates read `2026-11-14 10:00` in zh, formatted in en | — | — | Kept: `LocaleDisplay.civil` leaves zh server dates unchanged by design (as the MP shows them). |

Gates: generate_project no change, check_scaffold PASS, a11y lint 0 new, design consistency PASS, check_l10n no failure in my files (6 failures are in other lanes' files: `ProjectEditPlaySetupRows`, `OfficialPrivateViews`, `SquareDetailView`), contract ratchet 52 failing / baseline 52 / **new 0**.

### For other lanes
- i18n-r3: `check_l10n.py` fails on combined-r7 in `App/MPGap/AccountPublish/ProjectEditPlaySetupRows.swift`, `App/OfficialPrivateViews.swift`, `App/SquareDetailView.swift`.

### Component coverage (Continue 14)

Remaining `subpackageMember/components/cy/*` without a row were traced to their mounting pages: `team-report-sheet` (`pages/team/detail`, `subpackageRoam/nearby` → mp-activity / mp-roam), `scene-game-coupon-wallet` (`pages/play` → mp-journey), `npc-avatar` / `npc-chat` / `scene-route-content` / `scene-play-activity-detail` (journey), `scene-roam-poi-detail` (roam), `coop-invite-sheet` (coop → mp-activity), `merchant-correction-sheet` (merchant, gated), `scene-deep-link` (mp-nav). `dot-qr` is the 票夹 inline QR (`signup` row: NAT-12, not done on purpose) and `pass-object` is part of `pass-unlock` (gated). Every page in the mp-mine area now has a row; later runs re-check the sweep.

## Continue 15 (half-hourly re-arm, sweep 23:20 UTC build b3b03703a)

No merge needed (branch already contains combined-r7). Screen checked: `docs/sweeps/latest/mp-mine/en-d2-me.jpg`.

| Screenshot | MP / brief | Native file | Fixed now |
|---|---|---|---|
| `en-d2-me.jpg`: stacked Me card reads [Start exploring] full width, then [Ticket wallet] + a small "···" capsule | 23:20: the two primary buttons equal width in both rows; "···" as a card item or a trailing icon button | `App/MemberHomeHeader.swift` `actionRow`, `moreButton` | **Fixed.** The ··· `Menu` moved to the trailing end of the identity row (name / level / city), as a `.bordered` circle icon button (`.large`, 44 pt). The action row is now only [开始探索][票夹]: side by side when they fit, else both full width stacked. MP content unchanged (same three controls, same menu items); only the ··· placement is native chrome. Needs a simulator look. |

Gates: generate_project no change, check_scaffold PASS, a11y lint 0 new, design consistency PASS, contract ratchet 52 failing / baseline 52 / **new 0**.

## Continue 16 (hourly re-arm, sweep 23:37 UTC build 793c3190b)

Merged `origin/ui/combined-r7` (clean). Screens checked: `docs/sweeps/latest/mp-mine/sheet-en.jpg`, `sheet-zh-Hans.jpg`. That build predates continue 15, so the Me card button row is not re-checked here.

| Screenshot | MP / brief | Native file | Fixed now |
|---|---|---|---|
| `en-d2-me.jpg`: the Me tabs are a "Profile section · Projects ⌃" menu in English. zh-Hans shows the segmented 项目 / 帖文 / 成就 / 关于. | MP tabs 项目 / 推文 / 成就 / 关于 are a tab row on every language. OWNER RULE 2: one pattern. | `App/AccountView.swift` `AccountMineTab`, `App/SocialPublicProfileView.swift` `profileTabs` | **Fixed.** `cyAdaptiveSegmented` falls back to the menu when one segment does not fit. A quarter of 343 pt is too narrow for "Achievements". The tab now uses its own key, `account.mine.tab.achievements` (en **Awards**, zh-Hans 成就, unchanged), on 我的 and on the public profile, so both tab rows read the same. The 成就 section header keeps `social.achievements`. UI tests that tap the public profile tab now tap "Awards". Needs a simulator look at 375 pt en. |
| `en-e4-member.jpg` / `en-ia-passport.jpg` | — | `MemberHomeFixture`, `IAFixtures` | Not done. These are standalone component fixtures (member card + benefits; passport overview with capsules), not the 我的 tab root. The real root is `d2-me`. Left as they are for the a11y-dt lane, which uses the passport fixture. |
| `en-*`: amounts read `CN¥0.00` / `CN¥168.00` | 20:25: zh shows ¥ | — | Kept. That is the en-US system currency format for CNY. zh shows ¥ (`zh-Hans-*`). |

Gates: generate_project no change, check_scaffold PASS, a11y lint 0 new, design consistency PASS, missing string keys 0, contract ratchet 52 failing / baseline 52 / **new 0**.

## Continue 17 (half-hourly re-arm, sweep 00:10 UTC build 283dd3b52)

Branch already contains combined-r7. That build has continue 15 (··· on the identity row) but not continue 16 (en **Awards** tab), so the en tab row still shows the menu fallback there. No mp-mine rows in the 23:50 / 00:20 coordinator sweeps. Screens checked: `docs/sweeps/latest/mp-mine/sheet-en.jpg`, `en-d2-me.jpg`, `zh-Hans-d2-me.jpg`.

| Screenshot | MP / brief | Native file | Fixed now |
|---|---|---|---|
| `en-d2-me.jpg`, `zh-Hans-d2-me.jpg`: Me card [开始探索][票夹] now equal width ✓ and ··· on the identity row ✓; but 票夹 / Ticket wallet has no glyph and its text sits right of centre (an empty icon gap) | MP `pc-ticket`: coupon icon + 票夹, same size and colour as the primary | `App/MemberHomeHeader.swift` `ticketsButton` | **Fixed.** The label is an explicit `HStack { Image("ticket"), Text }` centred in the full-width frame instead of a system `Label`. Same key, id and action. Needs a simulator look. |

| `*-e4-settings.jpg`: the account card reads "Mia Chen · Lv.7" in both languages, beside 示例会员 / Synthetic member Lv.3 on d2-me | 19:50: fixture data follows the UI language | `App/DesignFixtures/DesignFixtureRegistry.swift` `E4SettingsFixture` | **Fixed.** Same member as d2-me: `iaFixtureText("Synthetic member", "示例会员")`, Lv.3. No test reads the old name. |

Gates: generate_project no change, check_scaffold PASS, a11y lint 0 new, design consistency PASS, contract ratchet 52 failing / baseline 52 / **new 0**.

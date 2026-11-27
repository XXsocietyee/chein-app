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

Still open from the re-scan table (need Core/coordinator work or are gated): invoice shared pending keyed by kind, server `msg` passthrough (titles delete, coupon-qr, library), pass `giftAllowed`/quote, membership guest overview, library tags, report-detail coordinator states, participation countdown/footer bar.
| `points-history` | `WalletCommerceViews.swift` `WalletLedgerView` | No 积分任务 row on the page; first load is `cy-skeleton type="list" count="3"` | **Fixed.** The 积分任务 link is gone from 积分明细 (如何获取积分 stays on 成就). First load shows three `CYSkeleton(.row)` placeholders. The balance hero stays: it is the zoom target from 成就 → 积分 (motion, not a section). |
| `market/membership` | `MPParityPassSession.swift` `MPParityPassMembershipModel`, Core `PlatformPass.overview` | The page loads `/api/platform-pass` for a guest too; only 购买 asks to log in | **Fixed.** `overview(token:)` takes `String?` (the shared `get` already sends no auth header for nil), and a guest reads the plans instead of 加载失败. The buy label stays gated. |
| `market/gift?mode=code` (兑换码) | `PassMarketViews.swift` `PlatformCodeRedeemPage` | `gf-hero`: gift icon (check when claimed, dimmed on error), `codeTitle` under it only when set; typing clears the error | **Fixed.** Hero section with `gift.fill` / `checkmark.circle.fill`, no default 兑换码 headline (the nav title says it), and the result line clears on typing. Guest dead end is still open: Core `ChannelRedeemSource.status(token:)` needs a token. |

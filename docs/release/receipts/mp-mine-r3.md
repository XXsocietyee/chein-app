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

## Continue 18 (hourly re-arm, sweep 00:37 UTC build f8574edab)

Merged `origin/ui/combined-r7` (clean, 78 commits). That build has continue 16 (en **Awards**: the four tabs are now segmented in en ✓) but not continue 17. No new mp-mine rows in the 00:50 coordinator sweep. Screens checked: `docs/sweeps/latest/mp-mine/sheet-en.jpg`, `sheet-zh-Hans.jpg`.

| Screenshot | MP / brief | Native file | Fixed now |
|---|---|---|---|
| `*-d2-me.jpg` 项目 tab: only 我的资产 · 账户余额 | MP `cy/profile` wxml:182-245 for a self player: 我的订单 (only with orders) → **我的项目 header + 管理全部 (always)** → 视频悬赏 (hidden at 0) → 我的资产 → **通行证与礼品 (always for players)** | `App/DesignFixtures/D2Fixtures.swift` `D2MeFixture` | **Fixed (fixture).** The real `AccountView` (Passport host) already draws `ProfileSelfProjectsEntry` and `MPPassAssetsLink`; the fixture hand-drew only the balance. It now shows 我的项目 with the 查看全部项目 link, then 我的资产 with 账户余额 and 通行证与礼品, in MP order. |
| same, real screen | MP shows no preview, no empty text and no refresh button when there are no projects (block gated on `projectPreviewList.length \|\| projectErr`) | `App/ProfileSelfProjectsSection.swift` | **Not done.** The section draws `profile.selfProjects.empty` and a 刷新 button; both are driven by `ProfileSelfProjectsFlowTests` (taps refresh, waits for the empty text) and `test_profile_self_projects.py`. Moving refresh to pull-down needs those tests rewritten (same case as the posts refresh row, continue 10). |
| `zh-Hans-e4-wallet-balance.jpg`: dates `2026-11-06 18:20:00` | — | — | Kept: `LocaleDisplay.civil` leaves zh server dates as given (owner-approved, see continue 14). |

Gates: generate_project no change, check_scaffold PASS, a11y lint 0 new, design consistency PASS, contract ratchet 52 failing / baseline 52 / **new 0**.

## Continue 19 (half-hourly re-arm, sweep 01:10 UTC build 907570051)

Merged `origin/ui/combined-r7` (clean, 48 commits). The 01:20 coordinator sweep lists mp-mine as fixed (Me card: two equal buttons, ··· top-trailing). That build predates continue 18, so the d2-me 项目 tab still shows only 我的资产 there. Every `pages/member/*` and `subpackageMember/*` page now has a receipt row. The four without one (`cy-frames`, `cy-illus`, `cy/timeline`, `roleBadge`) are shared drawing primitives, not pages. Screens checked: `docs/sweeps/latest/mp-mine/sheet-zh-Hans.jpg`, `sheet-en.jpg`.

| Screenshot | MP / brief | Native file | Fixed now |
|---|---|---|---|
| `*-e4-member.jpg`: a second 我的 / Me root that shows the card with one full-width 票夹 (no glyph), no [开始探索], no tabs, and 当前权益 right under the card. This is the layout the 14:13 check removed. | MP `cy/profile`: card → [开始探索][票夹] → tabs 项目/推文/成就/关于; 当前权益 is in 关于 (wxml ~533) | `App/DesignFixtures/DesignFixtureRegistry.swift`, `App/DesignFixtures/D2Fixtures.swift` | **Fixed (fixture).** `e4-member` now mounts `D2MeFixture(initialTab: .about)`, the same MP structure as d2-me, opened on 关于 so 当前权益 is still the shot's subject. `MemberHomeFixtureHost` is unchanged for `MemberHomeFlowTests` (`--uitesting-member-parity`). |
| same: the single 票夹 button has no glyph | MP `pc-ticket`: icon + 票夹 | `App/MemberHomeHeader.swift` (single-button branch, used when 开始探索 has no destination) | **Fixed.** That branch now calls the shared `ticketsButton(…, fixedLabel: false)`: same glyph, centring, key, id and a11y control as the paired button. |

Gates: generate_project no change, check_scaffold PASS, a11y lint 0 new, design consistency PASS, contract ratchet 52 failing / baseline 52 / **new 0**.

## Continue 20 (hourly re-arm, sweep 01:40 UTC build a32387e9b)

Merged `origin/ui/combined-r7` (clean). That build predates continue 19 (e4-member still shows the old card), so it is not re-checked here. No mp-mine rows in the 01:20 / 01:50 coordinator sweeps, so this run starts the "next round" list (P23–P31, motion, states). Screens checked: `docs/sweeps/latest/mp-mine/sheet-zh-Hans.jpg`, `sheet-en.jpg`.

| Page / screenshot | Principle → MP | Native file | Fixed now |
|---|---|---|---|
| `*-e5b-badge-wall.jpg`: earned and locked badges mixed in one grid; header reads "3/6 · 已收集 3/6" (count twice) | P24 inside the MP badge-wall order: 已点亮 group, then 未解锁; locked = the badge's own shape desaturated **and dimmed** | `App/DesignFixtures/E5bFixtures.swift` `E5bBadgeWallFixture`, `App/ObjectBadgeViews.swift` `ObjectBadgeWallBadgeLabel` | **Fixed.** The fixture now draws the real wall's structure (`ObjectBadgeWallView`): ring + `CYCollectedLockedSummary` (已收集 3 · 未解锁 3), then 已点亮 / Unlocked and 未解锁 / Locked groups with the existing keys. Locked tile art keeps `.grayscale` and adds `.opacity(0.55)`; name and condition text keep full contrast. AX5 one-column layout unchanged. Before/after fixture: `e5b-badge-wall`, `a11y-badges-ax5`. |
| `*-e4-wallet-balance.jpg` (余额流水) | P23: balance on top, segmented 全部/收入/支出, month groups, source · time · signed amount (+ green, − primary) | `App/WalletCommerceViews.swift` | — Already meets P23; no change. zh dates stay as the server sends them (continue 14). |

Gates: generate_project no change, check_scaffold PASS, a11y lint 0 new, design consistency PASS, contract ratchet 53 failing / baseline 52 / new 1. The one new failure is `test_category_roam_registration…test_category_adapter_missing_duplicated_moved_or_assertion_drift_rejected`. It does not read any file this run touched (it bit-flips the category gate file), and run alone it passes (5 tests OK in 240 s), so this is a time-out under load, not a regression. `test_object_badge_wall_layout.py` pins (`.grayscale(badge.isLocked ? 1 : 0)`, no `.lineLimit(`) are kept.

## Continue 21 (half-hourly re-arm, sweep 02:10 UTC build 41374363f)

Merged `origin/ui/combined-r7` (clean, 57 files). That build predates continue 20, so the badge wall groups are not re-checked here. No mp-mine rows in the 02:05 / 02:20 coordinator notes. Every remaining Not done row is blocked: the byte pin on `CharacterCardReadbackView`, and the posts / projects refresh rows that UI tests drive. So this run works "Next round" item 2 (motion and feedback). Screens checked: `docs/sweeps/latest/mp-mine/sheet-zh-Hans.jpg`, `sheet-en.jpg`. The public profile (`e4-self-medals`) shows 帖文 / 成就 / 关于, with no 项目 tab. That matches the MP, because 项目 is self-only (wxml:154 `isSelf && activeTab === 'projects'`).

| Page | Principle → MP | Native file | Fixed now |
|---|---|---|---|
| 我的 tabs 项目 / 帖文 / 成就 / 关于 (`d2-me`) and public profile tabs (`e4-self-medals`) | Next round 2: a selection change gets `.sensoryFeedback(.selection)`. MP `cy-tabs` bind:change. | `App/AccountView.swift`, `App/SocialPublicProfileView.swift`, `App/DesignFixtures/D2Fixtures.swift` | **Fixed.** `.sensoryFeedback(.selection, trigger:)` on each segmented tab picker. The haptic is system-provided, so it needs no Reduce Motion fallback. Order, keys and ids are unchanged. |

Gates: generate_project no change, check_scaffold PASS, a11y lint 0 new, design consistency PASS, contract ratchet 52 failing / baseline 52 / **new 0**.

## Continue 22 (hourly re-arm, sweep 02:10 UTC build 41374363f)

Merged `origin/ui/combined-r7` (clean, 67 files). The sweep build is the same as in continue 21, and the 02:05 / 02:20 coordinator notes have no mp-mine rows. The blocked Not done rows are unchanged, so this run continues "Next round" item 2 (motion and feedback) on the 积分明细 / wallet ledgers.

| Page | Principle → MP | Native file | Fixed now |
|---|---|---|---|
| `subpackageMember/points-history` 全部 / 获得 / 使用 chips (`e4-wallet-points`), 余额流水 全部 / 收入 / 支出 (`e4-wallet-balance`) | Next round 2: a filter change gets `.sensoryFeedback(.selection)`. MP `cy-tabs variant="chip"` bind:change="onFilter". P23 already met: balance on top, month groups, reason · time, signed delta + after-balance trailing. | `App/WalletCommerceViews.swift` `WalletLedgerView` | **Fixed.** `.sensoryFeedback(.selection, trigger: direction)` on the direction picker. |
| `subpackageMember/income-detail` 收益 / 分佣 tabs and 全部 / 创作 / 品牌 filter (`e4-wallet-income`) | same | `App/WalletCommerceViews.swift` (revenue tabs, `WalletIncomeSegment` filter) | **Fixed.** `.sensoryFeedback(.selection, trigger:)` on both pickers. Keys, ids and order are unchanged. The haptic is system-provided, so it needs no Reduce Motion fallback. |
| `subpackageMember/market/pass` tabs and the pass detail 自己用 / 送朋友 switch | same; MP `cy-tabs` bind:change | `App/PassMarketViews.swift` | **Fixed.** `.sensoryFeedback(.selection, trigger: tab)` and `trigger: state.forGift`. Keys and ids are unchanged. |

Gates: generate_project no change, check_scaffold PASS, a11y lint 0 new, design consistency PASS, contract ratchet 52 failing / baseline 52 / **new 0**.

## Continue 23 (half-hourly re-arm, sweep 03:04 UTC build ad55acd94)

Merged `origin/ui/combined-r7` (already up to date). No mp-mine rows in the 03:15 coordinator note. Screens checked: `docs/sweeps/latest/mp-mine/sheet-zh-Hans.jpg`, `sheet-en.jpg`. Every earlier fix shows there (equal [开始探索][票夹] with glyph, four tabs, 我的项目 / 我的资产, badge groups, ¥ amounts in zh), and there are no new visual issues. The blocked Not done rows are unchanged, so this run works "Next round" item 3 (all states, with a design fixture for each).

| Page | MP states (`subpackageMember/signup/index.wxml`) | Native file | Fixed now |
|---|---|---|---|
| 票夹 / Ticket wallet (`e4-tickets`) | empty 还没有票 + 去探索 (wxml:51); error 票夹没能打开 + 重试 (wxml:44); no-permission 登录后查看票夹 + 登录 (wxml:48); loading 正在加载我的票 (wxml:40) | `App/TicketWalletFixtureSupport.swift`, `App/DesignFixtures/DesignFixtureRegistry.swift` | **Fixed (fixtures).** `TicketWalletView` already draws all four states. Only `e4-tickets` (content) was a design fixture, so the sweep never showed them. New ids `e4-tickets-empty`, `e4-tickets-error` and `e4-tickets-guest` mount the real view on the existing synthetic reader scenarios. They wire `onExplore` / `onSignIn` so the one MP action renders. With no argument, `TicketWalletFixtureHostView()` keeps the UI-test launch argument path unchanged. Coordinator: please add these ids to the mp-mine sweep. |
| 余额流水 / Balance ledger (`e4-wallet-balance`) | App ledger (MP has no standalone page; balance sits under 我的资产, profile wxml:226). States: empty, error + 重试 | `App/WalletCommerceFixtureHost.swift`, `App/DesignFixtures/DesignFixtureRegistry.swift`, `App/WalletCommerceViews.swift` `WalletLedgerView` | **Fixed.** New fixtures `e4-wallet-balance-empty` (`--wallet-ledger-empty`) and `e4-wallet-balance-error` (the first read fails with `--wallet-ledger-recover`, and 重试 recovers). They are passed through a new `stateArguments` on the host, and the launch line is unchanged. The balance empty state was a bare text row; it now uses the same `ContentUnavailableView` (tray) as the income and points ledgers, with the same key and id. `.assetPoints` keeps its text row (`WalletCommerceFlowTests` reads it as static text). No points-empty fixture: `.points` reads `api/user/points/list`, which the empty flag does not cover. |

Gates: generate_project no change, check_scaffold PASS, a11y lint 0 new, design consistency PASS, contract ratchet 52 failing / baseline 52 / **new 0**.

## Continue 24 (hourly re-arm, sweep 03:49 UTC build 733bfb368)

Merged `origin/ui/combined-r7` (46 commits, clean). The 04:00 coordinator note has no new mp-mine findings. Screens checked: `docs/sweeps/latest/mp-mine/sheet-en.jpg`, `sheet-zh-Hans.jpg`. The badge wall groups, the ¥ amounts and the equal Me buttons all show there, and there are no new visual issues. The blocked Not done rows are unchanged (the `CharacterCardReadbackView` byte pin, plus the posts / projects refresh rows that UI tests drive). So this run continues "Next round" item 3 (all states, with a design fixture for each).

| Page | MP states | Native file | Fixed now |
|---|---|---|---|
| 积分明细 / Points history (`e4-wallet-points`) | `subpackageMember/points-history/index.wxml:10-11`: error 积分明细加载失败 + 重试; empty 还没有积分记录 | `App/WalletCommerceFixtureHost.swift`, `App/DesignFixtures/DesignFixtureRegistry.swift` | **Fixed (fixtures).** `WalletLedgerView(.points)` already draws both states (`ContentUnavailableView` tray / `WalletIssueView` with one bordered 重试). The paged read `api/user/points/list` was not covered by the `--wallet-ledger-*` flags, so the sweep could not show the states. A new pair of flags, `--wallet-paged-ledger-empty` and `--wallet-paged-ledger-recover`, applies only to the paged `api/user/points/list` and `api/user/balance/list`. The `--wallet-ledger-*` flags that `WalletCommerceFlowTests` uses are unchanged. New ids are `e4-wallet-points-empty` and `e4-wallet-points-error`; in the error fixture, 重试 recovers to the rows. |
| 收益明细 / Income detail (`e4-wallet-income`) | `subpackageMember/income-detail`: empty per filter (`WalletPointsLedgerEmptyState`, R11-PC-D-2) | same | **Fixed (fixture).** New id `e4-wallet-income-empty` uses the same paged empty flag. |

Coordinator: please add `e4-wallet-points-empty`, `e4-wallet-points-error`, `e4-wallet-income-empty` (and the continue 23 ids `e4-tickets-empty`, `e4-tickets-error`, `e4-tickets-guest`, `e4-wallet-balance-empty`, `e4-wallet-balance-error`) to the mp-mine sweep.

Gates: generate_project no change, check_scaffold PASS, a11y lint 0 new, design consistency PASS, contract ratchet 52 failing / baseline 52 / **new 0**.

## Continue 25 (half-hourly re-arm, sweep 03:49 UTC build 733bfb368)

Merged `origin/ui/combined-r7` (30 commits, clean). The sweep build is the same as in continue 24, and the 04:20 / 04:30 coordinator notes have no mp-mine rows (the sign-in requirement is mp-nav's). The blocked Not done rows are unchanged, so this run continues "Next round" item 3 (all states, with a design fixture for each) on the 我的 tab content sections.

| Page | MP states (`subpackageMember/components/cy/profile/index.wxml`) | Native file | Fixed now |
|---|---|---|---|
| 我的项目 / My projects (`e4-self-projects`) | error 项目加载失败 + 重试 (wxml:192-195) | `App/ProfileSelfProjectsFixture.swift`, `App/DesignFixtures/DesignFixtureRegistry.swift` | **Fixed (fixtures).** The design fixture showed the UI-test controls ("Projects reads: N", "Retire synthetic account") and the offline banner, and its owner name and project titles were English in zh. The host now has `showsTestControls` (default true, so the UI tests are unchanged). The sweep ids pass false, which hides the controls and the offline banner. Names and titles use `iaFixtureText`, and en keeps the strings the UI tests read. New id `e4-self-projects-error` uses the `failure` scenario: the first read fails and 重试 recovers. No empty fixture, because the MP hides the block when there are no projects (the continue 18 Not done row). |
| 成就 · 成长记录 / Growth (`e4-self-growth`) | error 成长记录加载失败 + 重试 (wxml:364) | `App/ProfileSelfGrowthFixture.swift`, `App/ProfileSelfGrowthSection.swift`, `Resources/Localizable.xcstrings`, registry | **Fixed.** The fixture got the same `showsTestControls` / `iaFixtureText` treatment. New ids are `e4-self-growth-zero` (a new player with all zeros) and `e4-self-growth-error` (the first read fails; 重试 recovers). The section's whole-read failure used the shared growth-center title. It now uses the MP title through `failedTitle:` with the new key `profile.selfGrowth.failed` (成长记录加载失败 / Couldn't load your growth record). The partial center / progress issues keep the shared copy. |

Gates: generate_project no change, check_scaffold PASS, a11y lint 0 new, design consistency PASS, contract ratchet 52 failing / baseline 52 / **new 0**.

Coordinator: please add `e4-self-projects`, `e4-self-projects-error`, `e4-self-growth`, `e4-self-growth-zero` and `e4-self-growth-error` to the mp-mine sweep, together with the continue 23 / 24 ids.

## Continue 26 (hourly re-arm, sweep 04:46 UTC build 13a6690eb)

Merged `origin/ui/combined-r7` (conflicts: other lanes' receipts and `tools/check_design_consistency.py` taken from combined-r7; `DesignFixtureRegistry.swift` kept both sides' cases; xcstrings = combined-r7 plus `profile.selfGrowth.failed`; pbxproj regenerated). The 04:30 / 04:45 / 04:50 coordinator notes have no mp-mine rows. Screens checked: `docs/sweeps/latest/mp-mine/sheet-zh-Hans.jpg`, `sheet-en.jpg`: no new visual issues. zh dates on 余额流水 / 订单查询 stay the server text (`LocaleDisplay.civil` returns the MP `createTimeText` as-is in zh by design; shared Core helper, not changed). The blocked Not done rows are unchanged, so this run continues "Next round" item 3 (all states, with a design fixture for each).

| Page | MP states (`subpackageMember/components/cy/scene-member-withdraw-history/index.wxml`) | Native file | Fixed now |
|---|---|---|---|
| 提现记录 / Withdrawal history (`e4-wallet-withdrawals`; MP `subpackageMember/tixianjilu`) | skeleton while loading; empty 还没有发起提现 (wxml:20); error 提现记录加载失败 + 重试, denied 当前身份不能查看提现记录 (wxml:18) | `App/WalletCommerceViews.swift` `WalletWithdrawalsView`, `App/DesignFixtures/DesignFixtureRegistry.swift` | **Fixed.** The whole-read failure showed the shared wallet title; it now passes the MP titles through `failedKey: "withdrawal.history.failed.title"` and `deniedKey: "withdrawal.history.denied.title"` (existing keys, en + zh). The signed-out title stays the shared one, because `WalletCommerceFlowTests.testWithdrawal401ShowsSignInWithoutRetry` reads it. New fixture ids `e4-wallet-withdrawals-empty` (`--wallet-withdrawals-empty`) and `e4-wallet-withdrawals-error` (`--wallet-withdrawals-recover`: the first read fails, 重试 recovers). |

Gates: generate_project no change, check_scaffold PASS, a11y lint 0 new, design consistency PASS, contract ratchet 52 failing / baseline 52 / **new 0**.

Coordinator: please add `e4-wallet-withdrawals-empty` and `e4-wallet-withdrawals-error` to the mp-mine sweep.

## Continue 27 (half-hourly re-arm, sweep 05:15 UTC build a4142df0d)

Merged `origin/ui/combined-r7` (conflicts: other lanes' receipts, `tools/check_design_consistency.py`, xcstrings and pbxproj taken from combined-r7, which already holds every mp-mine key; `DesignFixtureRegistry.swift` kept both sides' cases; pbxproj regenerated). Coordinator sweep 11-28 ~05:35 has two mp-mine P2 rows; both are fixed here. Screens checked: `docs/sweeps/latest/mp-mine/en-ia-passport.jpg`, `en-e4-self-medals.jpg`.

| Finding | MP | Native file | Fixed now |
|---|---|---|---|
| Badge totals disagree: Me stats card "Badges 3 of 12" vs badge wall ring "3 / 6" (`ia-passport` vs `e5b-badge-wall`) | 勋章墙 counts lit + locked from one list | `App/PassportView.swift`, `App/DesignFixtures/DesignFixtureRegistry.swift` | **Fixed.** The card's collected count and its total now come from the same badge-wall list (`ObjectBadgeWallSummary.unlocked` / `.total`, new `badgeCollected` on `PassportOverviewContent`; the earned-rail count is only the fallback when the wall read fails). The `ia-passport` fixture total is 6, matching the badge wall fixture (3 lit, 3 locked) and `a11y-passport-ax5`. Stamps keep the album count (3 of 12 is the stamp album, a different list). |
| Public profile → Posts with no posts: blue "Refresh posts" row above a plain "No posts yet" line (`e4-self-medals`) | MP 推文 refreshes by pull-down only; empty `cy-empty` 还没有帖文 | `App/ProfileAuthorPostsSection.swift`, `App/SocialPublicProfileView.swift`, `App/AccountView.swift`, `App/ProfileAuthorPostsRefreshFixture.swift` | **Fixed** (closes the continue 10 Not done row). The refresh row is gone. The public profile refreshes the retained feed from `.cyRefreshable` on the 帖文 tab; the 我的 tab bumps `refreshTrigger` from its existing pull (`memberRefreshToken`); the UI-test host has `.refreshable`. Empty is a `ContentUnavailableView` (还没有帖文 / No posts yet, `text.bubble`), id `profile.postsRefresh.empty` unchanged. `ProfileAuthorPostsRefreshFlowTests` now pull the list instead of tapping the row; `test_profile_author_posts_refresh.py` asserts the pull contract. No "Share your first walk" action: the MP empty has no action, and the own-profile composer already sits above the section on the 帖文 tab. |

| 我的项目: a 刷新 row under the preview (continue 18 Not done row; same pattern) | MP refreshes by pull-down only | `App/ProfileSelfProjectsSection.swift`, `App/SocialPublicProfileView.swift`, `App/AccountView.swift` | **Fixed.** The 刷新 row is gone. `ProfileSelfProjectsEntry` / `ProfileSelfProjectsSection` take `refreshTrigger`; the 我的 tab passes `memberRefreshToken` and the public profile's pull (`refreshPage()`) bumps `pullRefreshToken`, so the preview reloads from the page's pull on both hosts. `ProfileSelfProjectsFlowTests.testRefreshFailure…` pulls the list instead of tapping the row. |

Not done: the 我的项目 empty `ContentUnavailableView` stays (the MP hides the block when empty; `ProfileSelfProjectsFlowTests.testTruncationAndEmpty…` reads the empty text, so removing it needs that test rewritten); `CharacterCardReadbackView` byte pin unchanged.

Gates: generate_project no change, check_scaffold PASS, a11y lint 0 new, design consistency PASS, contract ratchet 52 failing / baseline 52 / **new 0**.

## Continue 28 (11-28, hourly run)

Merged `origin/ui/combined-r7` (conflicts: other lanes' receipts and xcstrings taken from combined-r7, which has no branch-only mp-mine key missing; `DesignFixtureRegistry.swift` kept both sides' cases; pbxproj regenerated). Coordinator notes up to 05:50 have no new mp-mine rows; both 05:35 rows were closed in continue 27. Sweep build is still 7a7d2708a (before continue 27), so `docs/sweeps/latest/mp-mine/sheet-zh-Hans.jpg` / `sheet-en.jpg` still show the old posts refresh row and badge card count; nothing else new. Settings 成为商家 shows in the DEBUG sweep only (`PlayerLaunch.merchantCenterEnabled`, hidden in Release), so it stays as is.

| MP page | Native file | Difference | Fixed now |
|---|---|---|---|
| `subpackageMember/components/cy/profile` 项目 tab, 我的项目 (wxml:180-212) | `App/ProfileSelfProjectsSection.swift`, `Tests/AppUITests/ProfileSelfProjectsFlowTests.swift` | MP draws the preview only when `projectPreviewList.length \|\| projectErr`; no projects = header + 管理全部 link only. Native drew a `ContentUnavailableView` 还没有项目 under the header (continue 27 Not done row) | **Fixed.** The empty view is gone; the 查看全部项目 link stays, loading / error + 重试 / truncated unchanged. `testTruncationAndEmptyHaveDifferentTruthfulStates` now asserts the empty scenario shows the all-projects link, no empty text and no issue. |
| same, header link (wxml:186 `管理全部`, aria 管理全部项目) | `Resources/Localizable.xcstrings` `profile.selfProjects.all` | Native link read 查看全部项目 / View all projects | **Fixed.** 管理全部项目 / Manage all projects (MP copy; the row opens the projects manager with the 模板 tab). Same id and destination. |

Not done: `CharacterCardReadbackView` byte pin unchanged (needs the pin owner).

Gates: generate_project no change, check_scaffold PASS, a11y lint 0 new, design consistency PASS, contract ratchet 52 failing / baseline 52 / **new 0**, `test_profile_self_projects.py` 30 OK.

## Continue 29 (11-28, hourly run): function audit P1 / P2 rows

Merged `origin/ui/combined-r7` (conflicts: other lanes' receipts and pbxproj taken from combined-r7 and regenerated; `DesignFixtureRegistry.swift` kept both sides' cases; xcstrings kept both sides' keys, no duplicates). Per the OWNER 06:25 note, P0-5 / P0-6 stay with `fix/1128-wechat-login` / `fix/1128-apple-delete`; this run takes the mp-mine P1 / P2 rows of `origin/audit/1128-functions:docs/audits/1128-functions.md`. Level C (Settings / account rows) for all three.

| Audit item | MP | Native file:line | Fixed now |
|---|---|---|---|
| **P1-14** merchant page leaks in Release: the Settings account card of a merchant-role account opens `MerchantOperationsDocumentView(.decor)` | merchant is not in the first release | `App/ProfileSettingsProfileRoute.swift:31,40,149` | **Fixed.** The merchant `ProfileSettingsProfileAccess` init, `current(_:)` and the `.brand` destination all check `PlayerLaunch.merchantCenterEnabled` (false in Release, true in DEBUG/TEST so the existing unit tests keep their merchant cases). In Release the merchant account card is a plain, non-tappable card. Test: `Tests/ContractChecks/test_mine_p1_14_merchant_settings_gate.py`. |
| **P1-15** 填写邀请人 is a dead control (`enabled: false`, `bindingEnabled: false`) | `pages/index/index.js:454` POST `/api/user/setInviter` `{inviter_id}`, success on `code == 200` | `App/AppSessionDoorEntry.swift:27`, `App/NativeEntryLandingView.swift:15` | **Fixed.** The session's `DoorReferralService` is built with `bindingEnabled: true` (scan stays off), and the sheet is `enabled: true`. The flow is unchanged otherwise: one-time confirm dialog → `queue.manualBind` → multipart `inviter_id` → server `code == 200` before dismiss; rejected → `door.inviter.remoteFailure`. Route is `liveInProduction` in `ChinaReviewedRouteCapability`. When the deployment has no API config the page is a `ContentUnavailableView` instead of a bare text line. Pin updated with reason in `test_account_marketing_entry_integration.py`; new `test_mine_p1_15_inviter_binding.py`; request shape already in `DoorReferralTests` (`/api/user/setInviter`, `inviter_id`). |
| **P1-16** every SMS error is one generic message; backend sends code 500 + `errorCode` | — (backend `SmsVerificationService`) | `Core/AuthChannelService.swift:6-20,71,93,116`, `Core/AuthChannelCoordinator.swift:15-27,172` | **Fixed.** `StatusEnvelope` decodes `errorCode`; `AuthChannelError.sms(errorCode:)` maps SMS_RATE_LIMITED → `.rateLimited`, SMS_DAILY_LIMIT → `.smsDailyLimit`, SMS_INTL_NOT_CONFIGURED → `.smsRegionUnavailable` for both SMS sends (login + bound deregistration). New issues/keys `auth.channels.smsDailyLimit` (今日验证码发送次数已达上限，请明天再试。) and `auth.channels.smsRegionUnavailable` (暂不支持向该地区号码发送验证码…), en + zh. Unknown codes keep `businessCode`. Test: `AuthChannelServiceTests.testBackendSMSErrorCodesMapToTypedFailures`. The Alipay-login half is dropped (owner 04:45: no Alipay login). |
| **P2-5a** 私人主页 row always opens "disabled" (`ReviewedAppDeployment.privateHome` never set) | MP has no 私人主页 | `App/AccountView.swift:352` | **Fixed.** The section renders only when `privateHomeCoordinator != nil` (no dead control, OWNER RULE 2). The fixture host and UI test still mount the link with a coordinator. |
| P2-5b Apple full name dropped → every new Apple user is 城瘾用户 | — | `Core/AuthChannelService.swift` `loginWithApple` | **Not done.** Sign-in-with-Apple code is being changed by `fix/1128-apple-delete`; the backend field for the name is not confirmed. Next run: after the first Apple sign-in, send the credential `fullName` as the nickname through the existing profile update when the server nickname is the default. |
| P2-5c participants reject +1, legal zh-only for US, no bind-phone | — | backend regex / legal | Not done: backend (participant regex) and legal copy owner. |

Not done: `CharacterCardReadbackView` byte pin unchanged (needs the pin owner).

Gates: generate_project no change, check_scaffold PASS, a11y lint 0 new, design consistency PASS, contract ratchet 52 failing / baseline 52 / **new 0**.

## Continue 30 (11-28, half-hourly run): ADA audit rows for mp-mine

Branch was up to date with `origin/ui/combined-r7`. The twin run's continue 29 already closed P1-14 / P1-15 / P1-16 / P2-5a; this run's duplicate commits were dropped. P2-5b (Apple full name) stays Not done: Sign-in-with-Apple code belongs to `fix/1128-apple-delete` right now. This run takes the mp-mine rows of `origin/audit/1128-ada:docs/audits/1128-ada.md`.

| ADA row | MP | Native file | Level | Fixed now |
|---|---|---|---|---|
| e4-member (关于 → 当前权益): a player sees merchant capabilities (Publish coupons, In-store redemption) as locked rows | `subpackageMember/components/cy/profile/index.js:65-78` `buildBenefits`: 发布路线 · 到店核销 · 分支/条件玩法 · 博弈机制 · 开放门店为城市节点 · 勋章设计 · 建群 · 我的收益 (no 发布优惠券) | `Core/MemberHome.swift` `MemberBenefit`, `App/MemberHomeHeader.swift` `MemberBenefitsSection` | C | **Fixed.** The app-only 发布优惠券 row is gone (MP order is now exact; key `member.benefit.publishCoupons` removed). New `MemberBenefit.isMerchantCapability` (到店核销, 开放门店为城市节点): a player in Release does not see these rows while locked (`PlayerLaunch.merchantCenterEnabled` false); DEBUG / TEST keep the MP list, so the sweep still shows them. `MemberHomeTests` updated (the role-info case now unlocks only 发布路线). |
| e4-wallet-balance: the hero label "余额流水 / Balance ledger" repeats the nav title; EN reasons wrap because the amount column is wide | MP 我的资产 label 账户余额 (`cy/profile/index.wxml:230`) | `App/WalletCommerceViews.swift` `balanceHero`, `ledgerRow` | C | **Fixed.** Hero label is the new key `wallet.balanceHero` (账户余额 / Account balance); the title stays 余额流水. The amount column is `.fixedSize(horizontal:)` in the row layout (not at AX sizes, where the row already stacks), so the reason takes the rest of the width. Not changed: zh dates stay the server text through `LocaleDisplay.civil` (shared Core helper, decided in continue 26). |
| ADA fixture hygiene: `d2-me` / `e4-member` / `e4-settings` read "Synthetic member · Synthetic City" (EN) and 示例会员 · 示例城市 (zh); the city disagrees with the Hangzhou passes | — (fixture) | `App/MemberHomeFixture.swift:55`, `App/DesignFixtures/DesignFixtureRegistry.swift:355`, `Tests/AppUITests/MemberHomeFlowTests.swift` | B | **Fixed.** Member is Lin Yu / 林雨 in Hangzhou / 杭州 (real-length EN name, same city as the pass fixtures); the settings card uses the same name. `MemberHomeFlowTests` read the new strings. Core tests keep their own synthetic data. Not done: ticket fixture names ("Sample … ticket") are read by `TicketWalletFlowTests` / `RoamEnrolledChaptersFlowTests`; the ticket page itself (ADA e4-tickets: Upcoming/Past, pass card) is the next row. |
| ADA e4-tickets: add an Upcoming / Past `Picker`, a pass card, `ContentUnavailableView` | MP `signup/index.wxml:16-18` (F13) has one list of usable tickets and no status filter; empty = 还没有票 + 去探索 | `App/TicketWalletView.swift:75,128` | B | **Kept as MP (OWNER RULE: MP decides sections).** No Upcoming / Past split (that would add a section the MP does not have; unpaid / past live in 我的订单). Empty state already has the one 去探索 action. Not done: the pass-card look (cover art, perforation) for the row itself, and Add to Apple Wallet (no pkpass from the backend). |

Not done: P2-5b (Apple full name, waits on `fix/1128-apple-delete`), the ticket pass-card look, `CharacterCardReadbackView` byte pin.

Gates (each push): generate_project no change, check_scaffold PASS, a11y lint 0 new, design consistency PASS, contract ratchet 52 failing / baseline 52 / **new 0**.

## Continue 31 (11-28, hourly run): ADA audit rows for mp-mine (continued)

Merged `origin/ui/combined-r7` (conflicts: other lanes' receipts taken from combined-r7; `DesignFixtureRegistry.swift` kept both sides' cases; xcstrings = combined-r7 plus the branch-only keys, as JSON, no duplicates; pbxproj regenerated). The 06:25 – 07:05 coordinator notes have no new mp-mine rows. Screens checked: `docs/sweeps/latest/mp-mine/sheet-zh-Hans.jpg`, `sheet-en.jpg` (build ffeef67c7, before continue 30, so 发布优惠券 still shows there). P2-5b (Apple full name) is covered by `fix/1128-apple-delete` commit `1b9caf4ee` ("send Apple givenName/familyName on first Apple sign-in"); not duplicated here, waiting for the coordinator merge.

| ADA row | MP | Native file | Level | Fixed now |
|---|---|---|---|---|
| ia-passport (P0): badge glyphs change with the UI language (EN flag/sun, ZH lightning) and the art differs from the badge wall; names "First Roam" vs the wall's "First Stamp" | `subpackageMember` badge wall (`ObjectBadgeWallView`, server `badge.image`, MP `badge-demo.png` fallback) | `App/PassportView.swift` `PassportBadge`, `badgeObject`; `App/DesignFixtures/DesignFixtureRegistry.swift`, `E5bFixtures.swift` | B | **Fixed.** `PassportBadge` carries the server `iconUrl`; the passport rail draws `ObjectBadgeTileArtwork` (the wall's artwork, MP medal fallback) instead of `ClubBadgeArt`, whose emblem was picked from the localized name. One badge object on both screens, no locale-dependent glyph. Fixture names now match the wall (夜猫子 / 第一枚印章 / 菜场常客, total 6). |
| d2-me (P1, P22): both [开始探索][票夹] filled | MP `pc-actions` same size; look per OWNER RULE 2 / P22 (primary filled + secondary bordered) | `App/MemberHomeHeader.swift` `actionRow`, `ticketsButton`, new `MemberCardActionStyle` | B | **Fixed.** In the pair, 开始探索 stays `.borderedProminent` and 票夹 is `.bordered`, both `.large` and equal width in the row and in the stacked fallback. A lone 票夹 (member header without 开始探索) stays the one prominent action. |
| e4-settings (P1): every row is its own card, so the page is long and unlike iOS Settings | MP `pages/shezhi/shezhi.wxml:9-36`: one continuous `sz-menu` list, 退出账号 below it | `App/SettingsView.swift` `body` Form | C | **Partly fixed.** The Form uses the system `.listSectionSpacing(.compact)` (allowed by the `section spacing` gate), so the one-row groups sit tight and read as one list, as the MP does. MP row order unchanged. Not done: merging rows into shared sections — each entry (`SettingsIdentityApplicationEntries`, `ProfileSettingsFavoritesEntry`, `SettingsPrivacyLocationEntry`, `NPCChatDataReadSettingsEntry`, …) owns its own `Section` with sheets / dialogs attached; regrouping needs a row-only API per entry and a simulator check. The "AI chat records" row has no chevron on purpose: it is a Button that opens the MP option sheet, not a push. |
| e5b-badge-wall (P1): two earned badges show 已点亮 / "Unlocked" instead of a date; no Share | MP `subpackageP3/pages/badge-wall/index/index.wxml:56` meta = `item.locked ? (cond \|\| 尚未点亮) : (time \|\| 已点亮)`; the list view has no share | `App/DesignFixtures/E5bFixtures.swift` | B | **Fixed (fixture).** The wall already follows the MP rule (date when the server sends one, 已点亮 otherwise); the fixture now gives every earned badge an `unlockTime`, so the sweep shows dates. No Share added (the MP list has none; OWNER RULE). Per-badge art comes from the server `iconUrl`; the fixture has none, so the MP medal fallback shows. |
| t5-order-center (P1): a pre-filled order number field and a 查询 row above the result (form-like) | MP `subpackageMember/components/cy/order-center-entry/index.wxml:1-14`: opened with an order id; cy-empty for non-ready states, else one card (title → status → 金额 → 订单号 → 创建时间) and 联系客服. No lookup field | `App/OrderCenterEntryView.swift` `body` | C | **Fixed.** When the page is opened with an order number (deep link, fixture) the lookup section is not drawn, so it reads like the MP: summary card + 联系客服. The field stays only for the app-only manual lookup (no number given). States and retry unchanged. |

Gates: generate_project no change, check_scaffold PASS, a11y lint 0 new, design consistency PASS, contract ratchet 52 failing / baseline 52 / **new 0**.

Next (ADA, still open for mp-mine): e4-settings row regroup (above); e4-tickets pass-card look (the Upcoming / Past split stays out, see the twin run above); CN¥ vs ¥ in EN (cross-screen money formatter, ds-consistency; en-US `CN¥` is the system CNY symbol and avoids reading as JPY).

## Continue 32 (11-28, half-hourly run): t5-order-center vs the MP entry

Merged `origin/ui/combined-r7` (conflicts: other lanes' receipts and `Localizable.xcstrings` taken from combined-r7; the only branch-only key, `region.usLoginPending`, was removed upstream by P0-5 and is unused). The sweep in `docs/sweeps/latest` is still build ffeef67c7 and the brief has no coordinator notes after 07:05 for mp-mine. Screens checked: `docs/sweeps/latest/mp-mine/zh-Hans-t5-order-center.jpg`. CN¥ vs ¥ (ADA cross-screen): the mine screens already use the shared formatter; the hand-built "¥" paths the audit names are `E1CommerceComponents.swift` / `MPParityPassSession.swift` (mp-activity, see For other lanes).

| ADA row | MP | Native file | Level | Fixed now |
|---|---|---|---|---|
| t5-order-center (P1): pre-filled order number + 查询 row on a deep-link page (form-like); "check the MP list" | `subpackageMember/components/cy/order-center-entry/index.wxml:1-16`: a deep-link entry with no input; `wx:if id` shows `cy-scene-member-order-detail` in place; otherwise loading / `cy-empty` (title + one action) / summary card (title, status, 金额, 订单号 `user-select`, 创建时间) + 联系客服. The order *list* is 我的订单 (`scene-member-order-history`, already its own row above) | `App/OrderCenterEntryView.swift` | C | **Fixed (extends the twin run's continue 31 row above, which hid the field).** Opened from a link (`subpackageMember/orderinfo?outTradeNo=`), the page has no number field and no 查询 row, as the MP. A registration order shows its order detail in place (no extra "open registration" row). The failure state is a `ContentUnavailableView` (MP copy + 重试), loading sits on a clear row. Order number is selectable (MP `user-select`). The number field stays only for the native 设置 → 订单查询 entry (no number to start from); it submits from the keyboard (`.submitLabel(.search)`). |

For other lanes: mp-activity — ADA currency row: `E1CommerceComponents.swift:116` and `MPParityPassSession.swift:335` build "¥" by hand; use `MemberBalanceDisplay.text` / `LocaleDisplay.money`.

Gates: generate_project no change, check_scaffold PASS, a11y lint 0 new, design consistency PASS, contract ratchet 52 failing / baseline 52 / **new 0**.

Not done: e4-settings row regroup (needs row-only entry APIs + simulator check), e4-tickets pass-card look, `CharacterCardReadbackView` byte pin.

## Continue 33 (11-28, hourly run): e4-settings account row (ADA)

Branch fast-forwarded to `origin/ui/combined-r7` (8952067e9). The brief's 07:45 sweep has no mp-mine rows; `fix/1128b-club-mine` holds planning-audit #10–#14, #18, #29, #30 (not taken here). Screens checked: `docs/sweeps/latest/mp-mine/sheet-en.jpg`, `sheet-zh-Hans.jpg` (build 3348aa51f), `en-e4-settings.jpg`.

| ADA row | MP | Native file | Level | Fixed now |
|---|---|---|---|---|
| e4-settings: the account row is a grey "S" lettermark while Me shows the photo; level reads "Level 3 · City explorer" (EN) / "Lv.3 · 城市探索者" (ZH) vs Me "Lv.3 City explorer" / "Lv.3 城市探索者" | MP `pages/shezhi/shezhi.wxml:14` 个人资料 cell; Me identity card `cy/profile/index.wxml` avatar with `d_profile` fallback | `App/SettingsView.swift` `SettingsAccountCard`, new `SettingsAccountAvatar`; `Resources/Localizable.xcstrings` `settings.account.subtitle %lld` | C | **Fixed.** The row draws the user-info `avatar` (same read Settings already makes, `homeAccount(from:).avatar`, https only via `MemberIdentityCardSection.remoteAvatarURL`) over the MP default `d_profile`, like the Me card; no lettermark. Merchant view keeps `icon_lc_store`. Level line is now one string with the Me card: `Lv.%lld City explorer` / `Lv.%lld 城市探索者`. "Become a merchant" is already behind `PlayerLaunch.merchantCenterEnabled` (Release off; DEBUG sweep shows it). |

Gates: generate_project no change, check_scaffold PASS, a11y lint 0 new, design consistency PASS, contract ratchet 52 failing / baseline 52 / **new 0**.

Not done: e4-settings row regroup (needs row-only entry APIs + simulator check), e4-tickets pass-card look, `CharacterCardReadbackView` byte pin.

## Continue 34 (11-28, hourly run): e4-tickets pass card (ADA)

Merged `origin/ui/combined-r7` (clean, 22 files). The sweep in `docs/sweeps/latest` is still build 3348aa51f and the brief has no mp-mine rows after 07:05. Screens checked: `docs/sweeps/latest/mp-mine/zh-Hans-e4-tickets.jpg` (two plain rows with grey `ticket` glyph tiles, 60 % of the page empty).

| ADA row | MP | Native file | Level | Fixed now |
|---|---|---|---|---|
| e4-tickets (P1): two plain rows with placeholder glyph tiles; "nothing looks like a pass" | MP `subpackageMember/signup/index.wxml:57-70`: each ticket is one big card, cover (`wImg`, else `/images/cover-route.svg`) on the card, title · sub · F13 tag, tap opens the code | `App/TicketWalletView.swift` `TicketWalletRow`, new `TicketWalletPerforation`, ticket `ForEach` | B | **Fixed (closes the continue 31/32/33 Not done "pass-card look").** Each ticket is its own inset-grouped section: a full-width cover band (132 pt, 72 pt at AX sizes) with the MP route illustration when there is no cover — the same band and fallback as the pass sheet (`TicketPassSheet.header`), so wallet and pass are one object — then a dashed perforation hairline (`.separator`), then the unchanged MP facts (F13 tag, title, date, place, sub-line). Identifiers, navigation, locked/dimmed rules and order unchanged. Still no Upcoming / Past split (MP has none, continue 30 row). Add to Apple Wallet: no pkpass from the backend. |

Gates: generate_project no change, check_scaffold PASS, a11y lint 0 new, design consistency PASS, contract ratchet 52 failing / baseline 52 / **new 0** (`test_w2_04_ticket_wallet` detail-first pin made indentation-tolerant: the rows moved into per-ticket Sections).

Not done: e4-settings row regroup (needs row-only entry APIs + simulator check), `CharacterCardReadbackView` byte pin. Coordinator: please re-sweep `e4-tickets` (zh-Hans + en, and AX5 if a11y-dt adds it).

## Continue 35 (11-28, half-hourly run): e4-tickets session line (MP P-27)

Rebased onto the twin run's continue 34 (pass cards). No new mp-mine rows in the brief after 07:45 (the 12:25 AI items go to `fix/1128c-*`). P2-5b (Apple full name) is closed upstream: `1b9caf4ee` sends `givenName` / `familyName` from `AuthChannelAppleButton` to `POST /api/login/apple`. Screens checked: `docs/sweeps/latest/mp-mine/zh-Hans-e4-tickets.jpg`, `en-e4-tickets.jpg` (build 3348aa51f): the session ticket reads only 示例活动票 · 场次.

| MP page | Native file | MP sections | Level | Fixed now |
|---|---|---|---|---|
| `subpackageMember/signup/index.js` `walletCard` / `sessionLine` (P-27): a session card reads「M月D日 HH:mm · 地点」; only without a start time 场次 · 剩 N 天; upcoming keeps the type | `App/TicketWalletView.swift` `TicketWalletSubline.head`, new `TicketWalletTicket.walletSessionLine`; `App/TicketWalletFixtureSupport.swift` | ✓ (card line) | B | **Fixed.** The session ticket sub-line is the start (Beijing time, in the user's locale: 5月1日 19:30 / May 1, 7:30 PM) · place, as the MP; the separate place line is hidden when it is already in the session line (no duplicate). Route tickets, upcoming tickets and sessions without a start time are unchanged. The fixture session ticket now has a start time and place (西湖文化广场 / West Lake Culture Square) so the sweep shows the line. |

Gates: generate_project no change, check_scaffold PASS, a11y lint 0 new, design consistency PASS, contract ratchet 52 failing / baseline 52 / **new 0**.

Not done: e4-settings row regroup (needs row-only entry APIs + simulator check), `CharacterCardReadbackView` byte pin.

## Continue 36 (11-28, hourly run): e4-settings row regroup (ADA)

Merged `origin/ui/combined-r7` (clean). No new mp-mine rows in the brief (the 12:25 AI items go to `fix/1128c-*`). Sweep still build 3348aa51f; screen checked: `docs/sweeps/latest/mp-mine/zh-Hans-e4-settings.jpg` — every row (城瘾玩法, 位置共享管理, AI 对话记录, 投诉建议 …) is its own card.

| MP page | Native file | MP sections | Level | Fixed now |
|---|---|---|---|---|
| `pages/shezhi/shezhi.wxml:9-36` one continuous `sz-menu` | `App/SettingsView.swift` (new `SettingsEntrySection` + `\.settingsGroupedRows`), entries in `SettingsPrivacyLocationView.swift`, `NPCChatDataReadSettingsEntry.swift`, `AccountComplianceViews.swift`, `SettingsPostGovernanceView.swift`, `MemberScoreAppealListView.swift`, `SettingsInvoiceEntry.swift`, `ProfileSettingsFavoritesRoute.swift` | ✓ (same rows, MP order) | C | **Fixed (closes the continue 31–35 Not done "row regroup").** Entries now draw `SettingsEntrySection`: their own Section by default (other hosts and unit tests unchanged), only their rows when the Settings page groups them. Settings groups like iOS Settings: 城瘾玩法 · 我的收藏 · 邀请与收益; 隐私与定位 · 位置共享管理 · AI 对话记录 · 营销消息与优惠券 · 帖文处置与申诉; 投诉建议 · 我的申诉 · 我的举报 · 发票 / 订单查询. Row order, identifiers, tints, sheets and destinations unchanged. Legal / 注销 / 关于 (`SettingsSupportSections`) and the app-only rows keep their sections. |

Gates: generate_project no change, check_scaffold PASS, a11y lint 0 new, design consistency PASS, contract ratchet 52 failing / baseline 52 / **new 0**. `tools/check_personal_location_share.py` has 3 failures before and after this change (not ours).

Not done: `CharacterCardReadbackView` byte pin. Coordinator: please re-sweep `e4-settings` (zh-Hans + en) to confirm the grouped sections render as one list per group.

## Continue 37 (11-28, hourly run): d2-me identity card hairlines

Merged `origin/ui/combined-r7` (clean). Brief rows after 07:45 for mp-mine: the 13:15 "成为商家" Settings row goes to K12 (`cursor/1128-merchant-gate`), so skipped; the 13:15 票夹 "generic grey ticket glyph" note is from build 0446d1c4f, which predates our pass cards (`27099b8ae`, continue 34; now in combined-r7) — please re-sweep `e4-tickets`. Screens checked: `docs/sweeps/latest/mp-mine/zh-Hans-d2-me.jpg`, `en-d2-me.jpg`.

| MP page | Native file | MP sections | Level | Fixed now |
|---|---|---|---|---|
| `subpackageMember/components/cy/profile` identity card (wxml hero → name/level/city → 好友/关注/粉丝 → actions) | `App/MemberHomeHeader.swift` `MemberIdentityCardSection`, new `MemberCardSeparatorEdge` | ✓ (unchanged order) | B | **Fixed.** The card's list hairlines started at two different insets (under the city text ≈165 pt, then under 好友 ≈80 pt), so the card looked broken into pieces. The identity row, streak row, assets row and counters row now start their separator at the row's leading edge (`.alignmentGuide(.listRowSeparatorLeading)`, the same pattern as `OrderLifecycleView`), so every hairline in the card has one inset. No content, order or identifier change. |

Gates: generate_project no change, check_scaffold PASS, a11y lint 0 new, design consistency PASS, contract ratchet 52 failing / baseline 52 / **new 0**.

Not done: `CharacterCardReadbackView` byte pin. Coordinator: please re-sweep `d2-me` and `e4-tickets`.

## Continue 38 (11-28, half-hourly run): fixture names in the 13:03 sweep

Merged `origin/ui/combined-r7` (46 commits, clean). The 13:15 coordinator rows for mp-mine are closed (ticket glyph → pass cards in continue 34; 成为商家 belongs to Cursor K12). Every MP page in `pages/member/*` and `subpackageMember/*` already has a row in this receipt, so this run re-scans the sweep. Screens checked: `docs/sweeps/latest/mp-mine/sheet-en.jpg` (build 0446d1c4f): the public profile header reads "Synthetic medal owner" and the ticket wallet reads "Sample exploration ticket" / "Sample activity ticket".

| MP page | Native file | MP sections | Level | Fixed now |
|---|---|---|---|---|
| `subpackageMember/components/cy/profile` (own public profile, `e4-self-medals`) | `App/ProfileSelfMedalsFixture.swift`, `Tests/AppUITests/ProfileSelfMedalsFlowTests.swift` | ✓ (unchanged) | B | **Fixed (fixture).** The owner is Lin Yu / 林雨, the same member as `d2-me`; the medals read Hangzhou city medal / 杭州城市勋章 and City walker / 城市漫步者 in the UI language. UI tests read the new English names. |
| `subpackageMember/signup` (`e4-tickets`, detail) | `App/TicketWalletFixtureSupport.swift`, `Tests/AppUITests/TicketWalletFlowTests.swift`, `Tests/AppUITests/RoamEnrolledChaptersFlowTests.swift` | ✓ (unchanged) | B | **Fixed (fixture; closes the continue 30 Not done "Sample … ticket").** The fixture reader maps the Core synthetic names to real ticket names in both languages (West Lake Night Walk / 西湖夜游探索票, Riverside Night Ride / 滨江夜骑活动票, …). Core keeps its synthetic JSON for Core tests. |

For other lanes: `App/DesignFixtures/E2Fixtures.swift` `E2ChaptersHost` (mp-roam, 我的章节) decodes the Core JSON directly, so it still shows "Sample … ticket"; it could read through `TicketWalletFixtureReader`.

Gates: generate_project no change, check_scaffold PASS, a11y lint 0 new, design consistency PASS, contract ratchet 52 failing / baseline 52 / **new 0**.

Not done: `CharacterCardReadbackView` byte pin. Coordinator: please re-sweep `e4-self-medals` and `e4-tickets` (en + zh-Hans).

## Continue 39 (11-28, hourly run): planning-audit mine rows (`audit/1128-plan` domain "mine")

Merged `origin/ui/combined-r7` (49 commits, clean). No B lane branch exists yet (`mp/r3-mine-b`), so nothing to skip. The only Not done row (`CharacterCardReadbackView` byte pin) is still blocked. Sweep unchanged (build 0446d1c4f); re-checked `docs/sweeps/latest/mp-mine/zh-Hans-e4-wallet-balance.jpg` (raw `2026-11-06 18:20:00`: already fixed upstream by ds-consistency `72011dadb`, zh drops server seconds), `zh-Hans-d2-me.jpg`, `en-e4-self-medals.jpg` (predates continue 38), `en-t5-order-center.jpg`, `en-e5b-badge-wall.jpg`: no new mp-mine issue. This run takes the planning audit's mine table (O-xx) that no fix worker owns (`fix/1128b-club-mine` has O-08 withdrawal popup and O-14b invite list; O-02/O-05/O-07 are mp-activity).

| Audit row | MP source | Native file | Level | Result |
|---|---|---|---|---|
| O-01 order state classifier vs MP `utils/order-status.js` | `summarizeOrderState`, `orderClockNow` (U-033) | `Core/ProfileOrderHistoryFilter.swift` | C | **Already ported** (gap #28: cancelTime, topicCompleted, exploreProgress, serverNow, whole-day end, pass rules, refunded beats 人工售后). **Fixed now:** `showsUnusedPass` compared the start with the device clock while `historyState` used `serverNow`, so a phone whose clock is behind read 未开始 where the MP reads 可使用. It now uses `serverNow ?? now`. Test: `ProfileOrderHistoryFilterTests.testUnusedSelfPlayPassReadsReadyInsteadOfInProgress` (served pass case). |
| O-17 new participant cannot be created as default | `pages/addressinfo/addressinfo.js:28` (`isDefault: 0` on create), `.wxml` has no default switch | `Core/ProfileParticipantTransport.swift:54` | C | **Kept as MP.** The MP create always sends `isDefault: 0` (no control on the page; only edit keeps the loaded value), which is exactly what the app sends and admits. No change. |
| O-21b Me card reads "Lv.N" without 城市探索者 | `profile/index.wxml:69` | `App/MemberHomeHeader.swift` | B | **Already done**: the sweep shows `Lv.3 城市探索者` / `Lv.3 City explorer` (`zh-Hans-d2-me.jpg`, `en-e4-settings.jpg`). |
| 我的资产 card at ¥0 with no ledger rows (MP 1121 N5) | `profile/index.wxml` `pc-asset wx:if="!(balanceText === '0.00' && balanceFlowCount === 0)"`, `index.js loadUsageCounts` (`/api/user/balance/list` page 1) | `App/AccountView.swift` `mineTabSections`, new `MemberAssetsBalanceRow` + `MemberAssetsLedgerCountTask` | B | **Fixed.** The 账户余额 row folds away only for a known ¥0.00 balance with a known-empty 余额流水 (read through the existing wallet-history reader and its admitted `pageNum=1&pageSize=20` shape, re-read on every pull). An unread balance or a failed / unconfigured ledger read keeps the row at ¥0 (MP "没拉到照常出", P-49). The 我的资产 header and 通行证与礼品 stay, as in the MP. Typed `ViewModifier`, no untyped closure in the long body. Test: `Tests/AppUnitTests/MemberAssetsBalanceFoldTests.swift`. The `d2-me` fixture keeps its own static ¥0.00 row. |
| O-22 creator apply / reapply | none: no MP file calls `/api/creator/apply` or `/api/creator/center` (only `docs/architecture/current-api-inventory.md:89` names the removed `role/center` page) | `Core/CreatorApplication.swift`, `App/CreatorApplicationView.swift` | C | **Kept off (OWNER RULE: the MP decides what exists).** The submit grant stays nil, as pinned by `RuntimeDependencyTests:83` and `test_runtime_dependency_wiring.py:37`. Coordinator: if the owner wants creator apply in the app, it is a new feature, not MP parity. |
| O-11c activity edit from 我的项目 | `subpackageA/pages/myproject/index.js:508,580` | `App/MyProjectActivityEditEntry.swift` | C | **Done upstream** by `fix/1128b-social` #27 (`9ee19bd5a`). |
| O-04 order detail host card + rules table | `scene-member-order-detail/index.wxml:327-332` (`organizerLabel：name` text, refund prose) | `App/ProfileOrdersView.swift` | C | **Kept as MP**: the MP has text only; no table added. |
| O-03 hide participations 1 week after end | `subpackageMember/mycanyu` has no such filter | `App/PlayerJourneyViews.swift` | C | **Kept as MP** (product decision; the audit notes the MP does not do it either). |

Gates: generate_project no change, check_scaffold PASS, a11y lint 0 new, design consistency PASS, contract ratchet 52 failing / baseline 52 / **new 0**.

Not done: `CharacterCardReadbackView` byte pin. O-10 (stamp album server read) = P1-23, owned by mp-roam / `fix/1128b-maps`. Coordinator: please add `d2-me` with an empty ledger to a later sweep once a fixture reader exists.

## Continue 40 (11-28, half-hourly run): settings sub-sheets without a row

Merged `origin/ui/combined-r7` (68 commits, clean). Sweep unchanged (build 0446d1c4f, `docs/sweeps/latest/mp-mine/sheet-zh-Hans.jpg`); no coordinator notes for mp-mine after 13:15 (the 成为商家 row is K12, `cursor/1128-merchant-gate`; the 票夹 glyph was closed in continue 33). B lane (`mp/r3-mine-b` run 1) finished two A rows, marked here: the `ai-chat-records` clear-count toast **(B lane)** and the `scene-share-invite` copy + 分享链接 **(B lane)**. The `CharacterCardReadbackView` byte pin, P2-5c and the rows the B lane reviewed and left (pass-unlock, order-detail 场次已开始 note → mp-activity `TeamCreateView`) are unchanged. This run takes the three `pages/shezhi/components/*` pages that had no row.

| MP page | Native file | MP sections | Level | Result |
|---|---|---|---|---|
| `pages/shezhi/components/privacy-sheet` (隐私与定位) | `App/SettingsPrivacyLocationView.swift` | body → 《用户隐私保护指引》 → **更多隐私设置** (城市定位与更多隐私设置) → 附近的人位置分享 → 漫游定位 | C | **Fixed (order).** The own-media link (the MP's 更多隐私设置 target) sat last, after 漫游定位 and the app-only session holds. It now follows the home-city section, so the page reads body → guide → home city + own media → presence → roam, as the MP. Identifiers and destinations unchanged (`SettingsPrivacyLocationFlowTests` find `member.privacy.media` by id). |
| `pages/shezhi/components/post-governance` (帖文处置与申诉) | `App/SettingsPostGovernanceView.swift` | intro 复核前的处置不是最终结论 → states (loading / 登录 / 错误+重试 / 暂无) → rows (type · state, target · time · 至, note, 复核说明, 提交申诉 form) → 加载更多 | C | **Fixed.** The appeal form lacked the MP counter `{{reason.length}}/{{reasonMax}}`; it now shows `N/500` (footnote, monospaced digits, VoiceOver "N of 500 characters", id `settings.postGov.count`) on the same row as 取消 / 提交. Everything else was already present. Not done: the MP `pendingUnknown` warning (上次申诉的提交结果未确认…) needs the local pending-appeal store the MP keeps; the native submit has no such record yet. |
| `pages/shezhi/components/marketing-consent` (营销消息与优惠券) | `App/AccountComplianceViews.swift` (`.marketing`) | loading / error+重试 / empty 还没有商家消息 / per-merchant group (logo or initial + name, 站内活动消息 and 商家优惠券 switches) / inline 未更新 error | C | **Already ported** (B-MK rows: logo tile `merchantLogo` with initial fallback, two switches per merchant, saving disables all). No change. |

Gates: generate_project no change, check_scaffold PASS, a11y lint 0 new, design consistency PASS, contract ratchet (see commit).

Not done: `CharacterCardReadbackView` byte pin; post-governance `pendingUnknown` warning.

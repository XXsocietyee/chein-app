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
| `tools/contract_ratchet.py --check` | 104 failing, baseline 104, **new 0**, fixed 0 |

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
| (Settings-only in the MP) teams, guide, location share, complaint, report history, support | Spread through the page | Extra | Kept at the end of 关于, because moving them into Settings would change many entry points. See "Not done". |

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
| `order` (我的订单) | `ProfileOrdersView` | Pending rows show 查看详情 rather than 立即支付; `pendingPayAmount` is not decoded | Not done. Payment stays behind the reviewed gate (FIN-16), and adding the field needs Core. |
| `order` | same | The filter is hidden when there are no orders; MP always shows the tabs | Not done (low) |
| `coupon/coupon` | `CouponManagementView` | The title reads 我发布的优惠券; MP says 优惠券 | Not done. This is a publisher/merchant-scoped screen, which is out of scope. |
| `coupon-wallet` | same | The shop line comes after the dates; MP puts it before | Not done. The 导航 capsule overlay is anchored to the card bottom and would separate from the shop line. |
| `market/passes` | `PassMarketViews.swift` | The pass-order row drops `time` under the amount; the gift row has no `name` | Not done. The gift name needs a Core field. |
| `tixianjilu`, `orient-score`, `character`, `complaint` | various | Already matched, or covered by the `mp-prme` receipt | — |
| `signup` | `TicketWalletView` | No avatar → 我的 button; no inline QR flip deck | Not done. This is a deliberate layout (NAT-12). |

## Not done / next

- Moving the MP Settings-only rows (teams, guide, location share, complaint, report history, support) from 关于 into `SettingsView`.
- 探索作品 images on 关于. The snapshot's `casePictures` can be object keys; the public profile link shows them.
- The order list 立即支付 pill and `pendingPayAmount` (needs Core plus the payment gate owner).
- The coupon-wallet shop/date order (needs the nav capsule re-anchored).

## Strings

`docs/port/strings/mp-mine-r3.json` is merged into `Resources/Localizable.xcstrings`:
- `member.about.addInterest` (Add interests / 添加兴趣)
- `ticketWallet.emptyExplore` (Explore / 去探索)
- `profile.inviteRewards.heroPending` (zh-Hans changed to 待同步)

# Receipt: fix/r9-member (Claude App, member)

Source: `origin/audit/parity-r9-member:docs/audit/parity-r9/member.md`, Claude App rows. Base: `origin/ui/combined-r7` (merged at 82bcf2c2d, then 2446657fb).
Brief: `docs/briefs/fix-r9.md` and `native-r2.md` (everything native) on `design/handoff-r2`.

Nothing was compiled; the cloud VM has no Swift toolchain. Every declaration used was grepped first. `python3 tools/check_scaffold.py` prints `PASS structural checks` at each commit. Strings: `Resources/Localizable.xcstrings` plus `docs/port/strings/fix-r9-member.json`.
Money stays off. Pay, 立即支付, 取消并退款, refund execution and gift claim were not built or sent.

## Merges
- `origin/ui/combined-r7` 82bcf2c2d (native-r2 tokens). Conflicts:
  - `App/PlayerJourneyViews.swift`: kept the tip's bottom 去修改 button; it now routes to the PLY-23-4 `participationModifyEditor` hook when set, and to the reviewed MP page otherwise.
  - `App/ProfileOrderSourceDetailSections.swift`: kept the FIN-17-4 team create, seats count and follow, plus the tip's club-page link.
  - xcstrings and the fragment: key union.
- `origin/ui/combined-r7` 2446657fb (native-r2 sweeps). Conflicts:
  - `TicketWalletView`: kept the NIT-1 filter removal and the tip's native Section. `TicketWalletCompanionCard` is now a native row; the gradient and card chrome are gone.
  - `PassMarketViews`: took the tip's native order rows and kept the 5-1 reload hook.

## Rows

| id | status | SHA | app file |
|---|---|---|---|
| R9-MEM-STR-1 (a) | fixed | f26f3b40c | Resources/Localizable.xcstrings (21 member-a keys) |
| R9-MEM-STR-1 (b) | fixed | e94c04b0d | Resources/Localizable.xcstrings (22 member-b keys) |
| MKT-8-2 | fixed (by STR-1) | f26f3b40c | `accountCollection.coupons.title` zh = 优惠券 |
| MKT-9-2 | fixed | ec9c8a528 | App/CouponCodeView.swift |
| PLY-23-4 | fixed | 282353380 (+ merge) | App/PlayerJourneyViews.swift (`participationModifyEditor`, bottom 去修改 → `.navigationDestination`) |
| FIN-17-4 | fixed | 5043b2ced (+ merge) | App/ProfileOrderSourceDetailSections.swift `ProfileOrderTeamSeatClubSection` |
| R8-MEM-21-1 | fixed | 8b7cf1bb8 (+ merge 2) | App/TicketWalletView.swift companions Section; App/TicketWalletCompanionCard.swift (native row) |
| R9-MEM-NIT-1 | fixed | bd9469fe3 | App/TicketWalletView.swift (filterMenu / walletFilter / filtered removed) |
| R9-MEM-IOS-1 | fixed | 87ee71b9d | App/DesignSystem/CYStates.swift `CYEmptyState.body` → `ContentUnavailableView` |
| R7-MEM-24-2 | fixed | 7e1a04954 | App/CharacterSheetDetailView.swift (此刻环境 and 掷骰 removed) |
| PLY-23-6 | fixed | 6a51c25aa | App/PlayerJourneyViews.swift (cover = `record.cover`; banner in the 商家模板 section) |
| MKT-10-3 | fixed | 597ef5d4e | App/CouponManagementView.swift (`.sheet(item:)`, `[.medium, .large]`) |
| R9-MEM-5-1 | fixed | 100a5a2a7 | App/PassMarketViews.swift `PassOrderRefusedWrites.refuse` (notice only on refusal; `onWritten` reloads) |
| R9-MEM-3-1 | fixed | 5a93bbe0c | deleted App/PassRedeemCodeView.swift, `.passRedeemCode` (App/MPParityKit.swift) and 11 `mp.redeem.*` keys; project regenerated |
| R9-MEM-17-2 | fixed | 9458684d8 | App/ProfileOrderSourceDetailSections.swift `ProfileOrderSettlementCopy`; App/ProfileOrdersView.swift settlement rows |
| R7-MEM-7-1 | fixed | a5e9d9842 | App/FreeExploreTopicCatalogScreen.swift `rows(_:)` |
| R8-MEM-7-3 | fixed | e4beeb88a | App/FreeExploreBundleLaunchView.swift `errorText`; App/FreeExploreReceiptResolveScreen.swift `.failed(message:)` |
| R7-MEM-16-1 | fixed | c225362bd | App/ProfileOrdersView.swift `cardExitButton` (swipe action + context menu → `OrderLifecycleView` sheet). Native note: the MP draws two buttons on the card; the app card is one NavigationLink, so the action is a swipe action and context menu. |
| PLY-21-5 | fixed | c84a84ad6 | App/TicketPassSheet.swift card labels |
| R8-MEM-21-2 | fixed | b1dd3a9dd | App/TicketWalletView.swift `readFocusedRegistration` memberID check |
| FIN-19-1 | fixed | da181216b | App/WithdrawalHistoryView.swift 更多提现记录加载失败 · 重试 |
| MKT-7-3 | fixed | eb5e7a73e | App/FreeExploreBundleLaunchView.swift `startAtText` (other MKT-7-3 parts were already on the page) |
| PLY-25-2 | fixed elsewhere | a481048a4 | App/OrientScoreSettlementControls.swift `OrientScoreSettlementActions` (already mounted on the tip) |
| FIN-20-6 | fixed elsewhere | c1a70c209 | App/SocialInviteHistoryView.swift toolbar `ShareLink` (already on the tip) |
| R8-MEM-26-1 | blocked | — | The Core link rule on the tip keeps `subpackageMember/mytemplate/mytemplate` as a reviewed page (Core/MiniProgramPageLink.swift:124-126). That contradicts the cursor-r9-member receipt (rewrite to official-mine). The app route matches Core, so I left it alone. The owner or Cursor needs to decide. |
| MKT-3-1 | blocked | — | The Core half is not built: cursor-r9-member files gift claim as money, and the audit disagrees. Owner call. |

## Round 3 (parity-r10 queue, native-r2 EVERYTHING native)

Source: `origin/audit/parity-r10-member:docs/audit/parity-r10/member.md`, Claude App rows. Brief: `native-r2.md` on `design/handoff-r2`.
Same gates as above: nothing compiled, every declaration grepped, `check_scaffold.py` PASS at each commit.

### Merge
- `origin/ui/combined-r7` 2aa2141f8 (native-r2 restyle of the same screens), merge 354b9f8af. Conflicts were resolved on the tip's native components, keeping the r9 behaviour:
  - `CouponCodeView`: tip `List`. MKT-9-2 kept (no 出示 sheet; `issue` on appear / phase / foreground). The review phase shows a system `ProgressView` instead of `CYLoadingState`.
  - `CouponManagementView`: tip native rows. MKT-10-3 kept (`.sheet(item:)` with `[.medium, .large]`).
  - `ProfileOrdersView`: tip `insetGrouped` rows. R7-MEM-16-1 kept (swipe action + context menu), and R9-MEM-17-2 kept (`ProfileOrderSettlementCopy`).
  - `Localizable.xcstrings`: 3-way key union, tip order, new keys appended.
- Later tips were merged before each push.

### Rows

| id | status | SHA | app file |
|---|---|---|---|
| MKT-7-3b | fixed | fa230d1b6 | `App/FreeExploreBundleLaunchView.swift`: 取消预约 (BOOKED, quote→confirm form with the waiver toggle), 更换商家 (RESERVED/AVAILABLE units) and 商家评价 (per reservation), as sheets with `[.medium, .large]`. Gate: `BundleCommerceCatalog.shows`, the same as the 套餐 hub. `App/BundleCommerceMount.swift` `FreeExploreBundleAction(Sheet)`; `App/FreeExploreBundleReadEntry.swift` passes the host. The participation-detail mount stays read-only (no host passed). |
| NAT-6 | fixed | 8c9408404 | `App/InvoiceLaunchTitleEditor.swift`: 保存 → toolbar `.confirmationAction` |
| NAT-12 | fixed | 8c9408404 | `App/TicketWalletView.swift`: app-only glass carousel removed (MP signup/index.wxml has no swiper; the rows open the same tickets) |
| NAT-13 | fixed | 8c9408404 | `App/TicketPassSheet.swift`: `CYTicketPassShape` notch/tear removed; `Divider` + `secondarySystemGroupedBackground` |
| NAT-17 | fixed (mycanyu) | 8c9408404 | `App/PlayerJourneyViews.swift`: 查看报名凭证 `.bordered`; cover placeholder background removed |
| NAT-11 | fixed | ce2c6feb5 | `App/CharacterSheetDetailView.swift`: `List(.insetGrouped)`; capsules → secondary text |
| NAT-10 | fixed | f7f5d0670 | `App/OrientScoreView.swift`, `App/OrientScoreSettlementControls.swift`, `App/OrientScoreReviewSection.swift`, `App/MPGap/Member/OrientScoreGapViews.swift`: Sections; system button styles |
| NAT-9 | fixed | 1b868d8e6 | `App/FreeExploreBundleLaunchView.swift`: `List(.insetGrouped)`; chapter/store `Picker`; step indicator → section header; review sheet → `Form` + toolbar confirm/cancel |
| NAT-1, 2, 3, 4, 5, 7, 8, 14, 15, 16 | fixed on the tip | — | already native in `ui/combined-r7` (component-level `CYEmptyState`/`CYStateLayout`/`CYStatusChip`/`CYPillButton`/`CYSkeleton`, no `CYNight`/gradients in PassMarket/PassMembership, no `preferredColorScheme(.dark)` in `TicketPassPresentView`, no `CYTabs` on invoice/appeal) |
| FIN-17-4b | fixed earlier | 5043b2ced | `App/ProfileOrderSourceDetailSections.swift` follow → `followClubOwner` (`/api/user/follow/action`) |
| R8-MEM-26-1b | blocked (Cursor Core first) | — | `Core/MiniProgramPageLink.swift:124-126` still keeps the mytemplate rule; the App case follows Core |
| MKT-3-1b | not ours (Cursor Core) | — | — |

Native notes:
- The MP draws 取消预约 and 使用每月免费取消 as two buttons. The app has one 取消预约 that opens the existing quote form, where the waiver is a `Toggle`.
- The QR tile keeps its white fill, because the code needs it to scan.

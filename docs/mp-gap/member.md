# MP Gap Inventory — `member`

- **Base:** `origin/ui/combined-r6` vs MP `hengyin/chengyinhub-xcx/subpackageMember`
- **Excluded:**
  - **Port packages P1–P5** (`port/plan-r1:docs/port/ios-port-plan.md` §2.2): `TicketWalletDetailView` blank statusLabel & `MoneyDisplay` (P5), etc.
  - **Restyle (visual only):** `.cyText` typography roll-ups, `cyPageTitle` / `CYSheetHeader` chrome-only swaps, spacing/radius/color token swaps, pure copy tweaks.
  - **Cursor C2:** `MKT-7-2` (`POST /api/merchant/public-home`, `merchant/reviews/public`, `merchant/reviews/create`), `FIN-11-4` (`INVOICE_NOT_FOUND` in `InvoiceLaunchService`).
- **Owner-gated items** (translated UI only, action stays gated): `MKT-3-1` (gift claim), `MKT-4-1` / `MKT-4-6` (month-card-only ruling), `MKT-5-3` (platform-pass order cancel/refund), `MKT-9-2` (coupon code confirm step), `FIN-19-2` (withdrawal apply), `PLY-21-6` / `PLY-21-8` (wallet team/filter rulings), `PLY-25-2` (orient sync/settle).

---

## Functional Gaps (ordered largest-first for translation)

### 1. `MKT-7-1` / `MKT-7-3` — Free-explore bundle `topicId`/`requestId` entry, unified unit/reservation actions & 售后记录
- **MP page & file:line:** `subpackageMember/free-explore/index` (`index.wxml:31-104`, `index.js:26-41, 111-126`)
- **What it does:** Supports `free-explore?topicId=` (catalog-only mode before purchase) and `?requestId=` (receipt reader `GET /api/free-explore/bundle/order/receipt`); folds hub actions (`取消预约` / `更换商家` / `评价`) onto unit & reservation rows; displays unit status, validity, `有效期至`, and `售后记录` section.
- **API calls:** `GET /api/free-explore/bundle/order/receipt` (`{requestId}`), `GET /api/free-explore/bundle/catalog` (`{topicId}`), `GET /api/free-explore/bundle/order` (`{registrationId}`)
- **App screen:** `FreeExploreBundleLaunchView` / `BundleCommerceMount` / `MPReviewedPageScreen`
- **Type:** `NEW-SECTION`
- **Size:** `L`

### 2. `FIN-17-4` — Order detail team,同行席位, merchant consent & club follow/join rows
- **MP page & file:line:** `subpackageMember/orderinfo/orderinfo` (`orderinfo.wxml:125-145, 158-174, 205-214, 313-326`)
- **What it does:** Adds `叫上队友` / team section, `同行席位` link → `JourneySeatsHost`, `关注/加入俱乐部` row → club action coordinator, and `商家消息` consent row (read-only until endpoint verified).
- **API calls:** `GET /api/registration/detail` (`{id}`), `POST /api/club/follow` / `POST /api/club/join`
- **App screen:** `ProfileOrdersView` (`ProfileOrderDetailView`)
- **Type:** `NEW-SECTION`
- **Size:** `L`

### 3. `PLY-25-2` / `PLY-25-3` / `PLY-25-4` / `PLY-25-5` — Orient score leaderboard, node-id appeal & per-row appeal sheet (sync/settle owner-gated)
- **MP page & file:line:** `subpackageMember/orient-score/index` (`index.wxml:26-44, 52-64, 73-113`, `index.js:124-332`)
- **What it does:** Adds `看本场榜单` sheet (`OrientSessionService.leaderboard`); adds `漏记任务` numeric `节点编号` input (`nodeID`) to appeals; replaces inline appeal form with per-row `申诉这一条` → sheet (`500`-char counter, duplicate-pending check, `score.deadline`). Sync/settle (`canSync`/`canSettle`) UI translated behind owner gate.
- **API calls:** `GET /api/orient/scoring` (`{sessionId}`), `GET /api/orient/leaderboard`, `POST /api/orient/appeal` (`{sessionId, nodeId, reason}`)
- **App screen:** `OrientScoreView` / `OrientScoreReviewSection`
- **Type:** `NEW-SECTION`
- **Size:** `L` *(sync/settle owner-gated)*

### 4. `FIN-16-2` / `FIN-18-2` / `FIN-19-1` — Pagination & keep-on-refresh for Orders, Points Ledger & Withdrawal History
- **MP page & file:line:** `subpackageMember/order/order` (`order.js:216-226`), `points-history/index` (`index.js:34-48`), `tixianjilu/tixianjilu` (`tixianjilu.js:70-72`)
- **What it does:** Adds `pageNum`/`pageSize` pagination with bottom `加载更多` / infinite scroll on Orders, Points, and Withdrawal History, and swaps into temporary buffer on pull-to-refresh so failed refreshes keep existing rows + toast.
- **API calls:** `GET /api/registration/my` (`{pageNum, pageSize}`), `GET /api/points/list` (`{pageNum, pageSize}`), `GET /api/withdrawal/list` (`{pageNum, pageSize}`)
- **App screen:** `ProfileOrdersView` / `WalletCommerceViews` / `WithdrawalHistoryView`
- **Type:** `NEW-ACTION`
- **Size:** `M`

### 5. `MKT-5-3` — Platform-pass order cancel & refund-apply (owner-gated)
- **MP page & file:line:** `subpackageMember/market/pass-order/index` (`index.js:77, 116`)
- **What it does:** Translates cancel & refund-apply sheet UI (destructive `CYConfirmSheet` + 200-char reason field) for platform-pass orders; write remains disabled behind `PlatformPassReadOnlyTransport` / money gate.
- **API calls:** `POST /api/platform-pass/orders/{orderNo}/cancel`, `POST /api/platform-pass/orders/{orderNo}/refund-apply` (`{reason}`) *(gated)*
- **App screen:** `PassOrderDetailView`
- **Type:** `NEW-ACTION`
- **Size:** `M` *(owner-gated)*

### 6. `MKT-10-1` — Published coupons summary tiles (`累计领取` / `累计核销`)
- **MP page & file:line:** `subpackageMember/coupon/coupon` (`coupon.wxml:15`, `coupon.js:205-216`)
- **What it does:** Reads `/api/merchant/coupon-summary` and displays a 2-column `CYStatTile` summary row above the published coupons list (hidden on failure).
- **API calls:** `GET /api/merchant/coupon-summary`
- **App screen:** `CouponManagementView`
- **Type:** `NEW-SECTION`
- **Size:** `M`

### 7. `PLY-23-3` / `PLY-23-4` / `PLY-23-6` — Participation detail bundle entry, merchant-apply edit link & cover images
- **MP page & file:line:** `subpackageMember/mycanyuinfo/mycanyuinfo` (`component.wxml:29-31, 64-66, 101, 136`, `js:202-218, 675-677`)
- **What it does:** Adds `自由探索权益` row → `FreeExploreBundleLaunchView` for free-explore registrations; adds `去修改` link to merchant-apply edit (`mode=1`); renders `picUrl` header cover and `topicImgArr[0]` template banner.
- **API calls:** `GET /api/registration/detail` (`{id}`)
- **App screen:** `PlayerJourneyViews` / `ParticipationParityViews`
- **Type:** `NEW-SECTION`
- **Size:** `M`

### 8. `PLY-26-5` — Template shelf merchant operation scope
- **MP page & file:line:** `subpackageMember/mytemplate/mytemplate` (`mytemplate.wxml:2`, `mytemplate.js:98, 131, 365`)
- **What it does:** Passes `operationScope` (`MERCHANT` vs `PLAYER`) into list/delete/market-status requests and applies merchant domain chrome when in merchant mode.
- **API calls:** `POST /api/template/my/list` (`{operationScope}`), `POST /api/template/{id}/delete` (`{operationScope}`)
- **App screen:** `TemplateAuthoringMineView`
- **Type:** `NEW-ACTION`
- **Size:** `M`

### 9. `PLY-29-4` — Report detail appeal sheet (form → confirm → result with kept requestId)
- **MP page & file:line:** `subpackageMember/report-detail/index` (`report-detail/index.wxml:55-93`)
- **What it does:** Replaces inline appeal form with `提交申诉` sheet (`TextEditor` + `n/1000`, confirm step quoting reason, result states with persistent `requestId` across retries).
- **API calls:** `POST /api/report/appeal` (`{reportId, reason, requestId}`)
- **App screen:** `MemberReportProgressDetailView` / `CommunityTrustPlayerViews`
- **Type:** `NEW-SECTION`
- **Size:** `M`

### 10. Small (`S`) items
| ID | MP page & file:line | Function | API calls | App screen | Type |
|---|---|---|---|---|---|
| `MKT-3-1` | `subpackageMember/market/gift/index` (`index.js:27-46`) | Gift claim UI & `claimReasonText` mapping (owner-gated `MPCommerceGate`) | `POST /api/platform-pass/gift/claim` (`{token, requestId}`) | `PassMarketViews` | `NEW-ACTION` |
| `MKT-4-1` / `MKT-4-6` | `subpackageMember/market/membership/index` (`platform-pass.js:101-105`, `wxml:62-65`) | Month-card filter (`code == "MONTH"`) & single footer CTA `续买30天 ¥X` (pending owner ruling) | `GET /api/platform-pass` | `PassMembershipViews` | `NEW-ACTION` |
| `MKT-10-5` | `subpackageMember/coupon/coupon` (`coupon.wxml:10`, `coupon.js:202`) | Add `申请入驻` CTA for players on 403 forbidden state | None | `CouponManagementView` | `NEW-ACTION` |
| `FIN-16-7` | `subpackageMember/order/order` (`wxml:36, 51, 56, 77, 90`) | Remote cover image (`CYRemoteImage`) + tap address to open Maps + `查看处理进度` label | None | `ProfileOrdersView` | `NEW-ACTION` |
| `FIN-17-3` | `subpackageMember/orderinfo/orderinfo` (`wxml:216-237`) | Pre-check `POST /api/invoice/orders/eligible` for `NONE` invoice status before showing `暂不可申请` | `POST /api/invoice/orders/eligible` | `ProfileOrdersView` | `NEW-ACTION` |
| `FIN-17-8` | `subpackageMember/orderinfo/orderinfo` (`wxml:260-275`) | `亲子票` party row & `票夹已过期` notice in 凭证与有效期 | None | `ProfileOrderSourceDetailSections` | `NEW-SECTION` |
| `FIN-20-6` | `subpackageMember/myinvite/myinvite` (`myinvite.js:24-29`) | Toolbar `ShareLink` sharing personal invite link | None | `SocialInviteHistoryView` | `NEW-ACTION` |
| `PLY-21-5` | `subpackageMember/signup/index` (`index.js:762-801`) | Card sub-line (`类型 · 剩N天`), party / `已核销 x/y 家`, back-face expiry | None | `TicketWalletView` / `TicketPassSheet` | `NEW-SECTION` |
| `PLY-21-13` | `subpackageMember/signup/index` (`index.js:655-708`) | Horizontal swipe between stacked passes (`ScrollView` + `.viewAligned`) | None | `TicketPassSheet` | `NEW-ACTION` |
| `PLY-24-3` / `24-6` | `subpackageMember/character/index` (`index.wxml:61`, `index.js:84-91`) | Signed-out `登录` CTA & explicit `刷新角色卡` button | None | `CharacterCardReadbackView` | `NEW-ACTION` |
| `PLY-26-4` | `subpackageMember/mytemplate/mytemplate` (`wxml:18-32`) | Cover image / title-initial fallback on template cards | None | `TemplateAuthoringMineView` | `NEW-SECTION` |
| `PLY-28-5` | `subpackageMember/report-mine/index` | Mount `我的举报` entry under `我的 → 账号与安全` | None | `AccountView` (mount hook) | `NEW-ACTION` |
| `PLY-30-5` | `subpackageMember/appeal-mine/index` (`index.js:74-82`) | `打开本局计分` link from appeal detail → `OrientScoreView` | None | `MemberScoreAppealListView` | `NEW-ACTION` |

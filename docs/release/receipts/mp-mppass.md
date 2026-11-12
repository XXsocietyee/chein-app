# mp-mppass — Platform pass & market fidelity pass (inventory C #2)

Branch `ui/mppass`, rebased onto `origin/ui/mpmissing` (bf19c71d7) per the coordinator. The screens are the ones from ui/mpmissing.
This lane compared them line by line with `chengyinhub-xcx` at 7fe779ceb (2026-11-12) and fixed the gaps in place. My earlier separate
`PlatformPass*` screens were dropped (duplicates). Code-only: not compiled (integrator compiles). `swiftc -parse` is clean on every
touched file. `tools/generate_project.py`, `check_design_lint.py`, `check_scaffold.py` and `check_catalog_coverage.py` (gaps: 0) pass.
Payment, claim and payout stay OFF (`MPCommerceGate`). No screenshots were taken or shared.

## Fidelity verdict per mini-program page

| Mini-program page | Native | Verdict | Gaps found → fixed here |
|---|---|---|---|
| `subpackageMember/market/passes` | `PassMarketViews.swift` `PassMarketView/Host` | **MATCH** | onShow parity: coming back from detail, reveal or membership reloaded with a skeleton. It now refreshes quietly after the first load. The order is points card → tabs → (shop: member card → products → 游戏主题库 row; orders; gifts sent/claimed). Copy matches 1:1 |
| `subpackageMember/market/pass` (detail) | `PassDetailView/Host`, `PassTicketHero` | **MATCH (purchase gated)** | Added the result surfaces the mini-program shows after an order: **unlock steps** overlay (`PassUnlockStepsView`, 已到账 / 可玩主题 / 有效期 / 同行, 下一步 / 完成), **礼品已买好** sheet (`PassGiftReadySheet`: 领取前你和好友都不能游玩, **发给好友** ShareLink), and on close a redirect to passes 我的订单 / 礼品 (`dismissResult`). They are driven by new `PassDetailState.unlockSteps` / `giftShare` fields, which stay empty while the purchase gate is OFF. Pay modes remain read-only capsules + gate note (as on mpmissing) |
| `subpackageMember/market/gift` | `PassGiftClaimView/Host` | **MATCH (claim gated)** | 查看 now opens the order detail (`bindings.orderDetail(registrationID)`, mini-program `orderinfo?id=`) when the claim returned a registration, else passes 礼品 tab (was always the tab) |
| `subpackageMember/market/membership` | `PassMembershipViews.swift` `PassMembershipView/Host` | **MATCH (purchase gated)** | Active footer is now always 去主题库 (pp__foot). Before, without a library binding it fell back to the read-only 续期 label. Card, 可玩主题库 row (N 个主题 · 持证 ¥0), plans with 最划算, renew line, terms, merchant / off / loading / error all already matched |
| `subpackageMember/market/library` | `PassLibraryView/Host`, `PassLibraryCardView` | **MATCH** | Card anatomy completed to the club card: **城 mark** (top-left glass tile), **tag row** (kind, city) and **chevron** in the card foot. They were missing. Tabs 全部 / 城市定向 / 自由探索, ¥0 可玩 only on server `covered`, no count in title, all states already matched |
| `subpackagePass/reveal` | `PassRevealView` | **MATCH** | Merchant sentence was unreachable: the route never passed `isMerchant`. Now `MPParityDestination` passes `bindings.isMerchant`. Skip only in the full version, first-visit / paid logic, Reduce Motion end state, copy (赢取你的钥匙, paid copy from carried facts) already matched. Native SwiftUI key motion instead of baked frames (unchanged) |
| Theme checkout reorder (`pages/topic/components/cy/self-play-checkout`) | `TopicSelfPlaySheet.swift` + `MPPassCheckoutRows` (`App/MPPassEntries.swift`) | **ADDED → MATCH** | Was not on mpmissing. The order is now 主题头 (cover, name, place) → 你的通行证覆盖这个主题 · 本单 ¥0 → 单次购买 (selected) → 城市通票 rows covering the topic (→ pass detail) → 参与人 → 明细 (price, 合计, payment notice) → consent / review. All `TopicSelfPlayFlow` calls, payment sheets and `contextSelfPlay.*` identifiers are unchanged |
| Explore city-pass entry card (`pages/talent/list` storeCard, `utils/discover-store-card.js`) | `MPPassExploreCard` in `HomeFeedView` after the recommended block | **ADDED → MATCH** | Was not on mpmissing. Title (上海通票 / 城市通票), meta, ≤3 cover tags, price (¥N 起), 获取通票 → passes. One feed card, never a paywall. Hidden for merchants and when nothing is on sale |
| Mount: 我的 → 通行证与礼品 (`components/cy/profile` goPasses) | `MPPassAssetsLink` in `AccountView` wallet/assets section | **FIXED** | It sat in a separate "通行证与收益" section after member benefits and showed for merchants. The mini-program puts it under 资产 and hides it for `isMerchantView`. It is now an assets row, hidden for merchants. Promo and video bounty stay in `MPParityAccountLinks` |

## Bindings added for Cursor (`MPParityBindings`, App/MPParityKit.swift)
- `viewerIsMerchant` (roleGuard.isMerchantView): hides 我的 row / store card / checkout rows, merchant sentence on reveal.
- `passStoreCard` (`/api/marketing/product/list?limit=50` → discover-store-card rules), `passCheckoutCover(topicID)` (topic `platformPassCovered` + on-sale passes covering it).
- `orderDetail(registrationID)` destination for gift 查看.
- `PassDetailBinding.dismissResult()` (default no-op) and `PassDetailState.unlockSteps` / `giftShare`: fill only after a server PAID order once the purchase gate opens.
- Unchanged from mpmissing: pass market / detail / gift / membership / library bindings, `revealAccountKey`, points-history destination.

## Still open
- Nothing compiled or run; integrator build pending.
- Purchase / claim gates stay OFF by owner policy; the confirm-purchase dialog appears only when the gate opens (not built while OFF).

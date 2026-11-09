# CB257 page-ready — `pages/topic/pricing/index`

主题定价与分润配置. Native screen `App/PublisherLifecycleViews.swift` (`PublisherPricingView`). Map status on `rc/20261108`: exists.

Base `rc/20261108`. Branch `cursor/cb257`. Core and tests only. Views, ui-strings JSON, `Localizable.xcstrings`, the Xcode project, and `tools/current_ci_manifest.json` were not edited. No route was added and none was marked live. `api/topic/pricing/preview` and `api/topic/pricing/confirm` were already `live-in-production`. Payment, payout, and withdrawal stay off (`ReleaseMoneyWriteSwitch` is unchanged). `WelcomeView.showsMerchantChoice` stays `false`. This page is not on the player-first entry.

`swift` and `xcodebuild` are not on this machine. No Swift run is claimed. Existing tests were not deleted or weakened.

## What rc already had

- Preview and confirm bodies in `Core/PublisherLifecycleHTTP.swift` and `Core/PublisherLifecycleCoordinator.swift`. Confirm still needs the dormant `grants.pricing` slot. `RuntimeDependencyFactory.publisherGrants` still sets reads only.
- `PublisherPricingPreview` rejects a missing or string floor, including the string `"0"`, and keeps a numeric `0`.
- `TopicPricingXcx` floor, slider, delta, terms, and confirm blockers. `canConfirm == nil` was already unknown, not `false`.
- `PublisherLifecycleTests` for the exact preview and confirm bodies, dormant sends, and the unknown-outcome lock.

## What this pass adds

`TopicPricingXcx` now classifies one preview read:

| State | When |
|---|---|
| `loading` | A read is in flight and no preview is kept. |
| `empty` | The link has no topic id. Source `cy-empty` / `缺少主题信息`. Not an error and not a zero price. |
| `error(.load)` | The read failed and nothing is kept. |
| `error(.incomplete)` | The payload has no numeric `priceMin`. A string `"0"` stays incomplete. |
| `unknown` | The link is valid, nothing is in flight, and neither a preview nor a failure arrived. |
| `ready` | A numeric floor decoded. A later failure keeps that floor (`refreshFailed`) instead of substituting `0`. A refresh in flight sets `refreshing`. |

Unknown money uses `—` (U+2014). A literal zero formats as `0.00`. A missing `canConfirm` stays `.unknown` and is not stored as blocked. Guided team size `nil` or `0` still cannot submit; that missing size is not shown as a zero price. A literal reference price of `0` with samples stays `0.00`.

`showsPage` is false for a nil base and for `playerFirstEntry: true`. `showsEntry` also requires the existing owner + lifecycle `2` rule. A nil lifecycle does not become `0`. `showsConfirm` is false unless that page is shown and the caller already holds the pricing grant. This function does not create the grant.

## Missing catalog keys

These source strings are not in `Resources/Localizable.xcstrings`. The catalog was not edited. Generic `重试` already exists (`topic.retry` and others). `返回上一页` already exists on other screens (`team.page.goBack`, `cooperation.settlement.back`) and was not copied here.

| Key | Source string |
|---|---|
| `publisherPricing.missingTopic` | 缺少主题信息 |
| `publisherPricing.missingTopicDetail` | 当前链接没有携带主题参数，无法确认终价。 |
| `publisherPricing.loadFailed` | 定价信息加载失败 |
| `publisherPricing.stalePreview` | 最新定价暂未取回 |
| `publisherPricing.recalculateFloor` | 重新计算地板 |
| `publisherPricing.costFloor` | 成本地板 |
| `publisherPricing.floorIncludes` | 平台率、发起人预估保底、分成型比例和固定成本已计入；终价不可低于此值。 |
| `publisherPricing.floorShort` | 地板 |
| `publisherPricing.marginNote` | 终价高出成本地板的部分就是发起人毛利；结算保底只按本场真实核销商家数激活。 |
| `publisherPricing.phaseBlockedDetail` | 主题还没进入定价阶段：招募结束、合作阵容锁定后，才能确认终价并提交开售审核。 |
| `publisherPricing.phaseBlockedShort` | 主题还没进入定价阶段 |
| `publisherPricing.confirmFailed` | 终价确认失败 |
| `publisherPricing.incomplete` | 定价信息不完整，请稍后重试 |
| `publisherPricing.confirmRetry` | 确认失败，请重试 |
| `publisherPricing.confirmedAwaitingReview` | 终价已确认，请等待开售审核 |
| `publisherPricing.network` | 网络异常，请稍后重试 |
| `publisherPricing.lineupLocked` | 阵容已锁定，点开可查该合作方在本主题中的结算条款。 |

`publisherPricing.lineupLocked` is still a Chinese literal on `TopicPricingXcx.lineupLockedNote`, not a catalog key. The view does not read it.

Nearby keys that are not the source sentence: `publisherPricing.recalculateMinimum` is 重新计算最低价, `publisherPricing.minimumPrice` is 最低价, `publisherPricing.theFinalPriceCanTBe` is 终价不可低于此值, and `publisherPricing.youCanSetThePriceOnce` is 合作阵容锁定后可定价.

## Left

- `PublisherPricingView` still draws the form, the confirm button, and `¥` plus `NSDecimalNumber.stringValue` on its own. It does not read `screen`, `showsPage`, or `showsConfirm`. A nil pricing grant still leaves that button on screen. Hiding it is a view change.
- The empty, full-page error, and unknown states are model-only until a view binds them.
- The seventeen keys above are absent from the catalog.
- `grants.pricing` stays nil in the shipped factory. Confirm is not enabled. Payment, payout, and withdrawal are not enabled.
- Partner terms (`pages/topic/pricing/partner/index`) are a different page.
- No simulator pass and no `xcodebuild`.

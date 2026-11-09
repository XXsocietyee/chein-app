# CB102 merge queue

Base: `origin/rc/20261108` `027e4985c53164127fd7bfd2b4845efbfc4c9e0b`.

The five lanes were merged in this order, one `--no-ff` merge commit each. Every merge was clean. No conflict marker was written, and no hunk was hand-resolved.

`docs/release/cb89-ios-ci.patch` is in the tree and was not applied. `.github/workflows/ios-ci.yml` is still blob `3af977942405d29e9cae0fdafd75737f1a3408f8` (`runs-on: xcode-27` on the three macOS jobs). `tools/current_ci_manifest.json` is still blob `743958754af4608942e3a86019e71fa499eba78b`. Neither file was edited, and GitHub Actions was not rerun. `origin/ui/d7` was not merged. No test path was deleted, and no `func test` line was removed. This VM has no Xcode and no Swift, so this log is not a build and not an XCTest run. The checks below only read source.

`App/RegionalLaunchConfiguration.swift` is still blob `1f8b0dbfb76dedf475e1481964036a0137468919`. `shippedComposition` still returns `makeComposition(reviewed: nil, build: .current)` when `ReviewedMarketLaunch.admitsShippedChina` fails. `Config/Base.xcconfig` is still blob `05acfe55f73c078a9c70f1870ea4d4a7b5beb2eb`: `QUESTIFY_API_BASE_URL` and `QUESTIFY_SESSION_REALM` are empty, so that build stays on the nil path. `reviewedMarketDeployment` still sets `productionGatesEnabled: false`.

`ChinaReviewedRouteAdaptation.routes` is only the five CB93 pairs. Password login (`/api/login`), bank-card withdrawal (`/api/withdrawal/create`), and virtual goods (`/api/cart/list`, `/api/pay/create`, `/api/registration/pay`) are not in that list. `hidingCapability` still classifies those three groups.

## Lanes

| Order | Lane | Tip | Merge | Result |
|---|---|---|---|---|
| 1 | `origin/cursor/cb89` | `29bec5d87327fcfa4b47e0d14dabf088ce5ea972` | `dd8f52096022d68f70746eb40a8275c33188a528` | Clean. Adds `docs/release/cb89-ci-fallback.md` and `docs/release/cb89-ios-ci.patch`. The patch was not applied. |
| 2 | `origin/cursor/cb90` | `43ad834a72c54d65d44a6f2e0bda44a16d597065` | `4510f4c9040dc18cfe5c18c51a0e87f1535afa77` | Clean. Adds `docs/release/cb90-actions-billing.md`. |
| 3 | `origin/cursor/cb91` | `02561f7cd02191f0743f43d42adb456a90797c2d` | `db1b6b670275ea809f69f7c888f8aae1eeee76fb` | Clean. Adds `docs/release/cb91-core-triage.md`. No product source. |
| 4 | `origin/cursor/cb92` | `5cb334b5801de0523ff980108a6d28157e9b5d85` | `b5d36d70796a21f92745033335be81e4d8c11eee` | Clean. Adds `docs/release/cb92-appunit-triage.md`. |
| 5 | `origin/cursor/cb93` | `3e556dbf77a904ff35e1f5ad6e1278416057d37c` | `e86f5a4b7f7e6d3e9d9f9d4f79cc97212b7f2ad9` | Clean. Adapts five already-admitted China routes and adds `Tests/CoreTests/CB93RouteAdaptationTests.swift` plus `docs/release/cb93-route-batch.md`. |

## Conflicts

None.

## Not merged

`origin/ui/d7` was not merged. `docs/release/cb89-ios-ci.patch` was not applied to `.github/workflows/ios-ci.yml`.

# ui/cur-appsec-tests

Task 78. Tests only, on `ui/h-appsec` at `1c7e692ba66da021934f8428a477d6a4f7aeac65`. No restyle, layout, color, or spacing change. No second validator. `ReviewedAreaSwitch` is unchanged. `App/RegionalLaunchConfiguration.swift`, `App/AppSession.swift`, and `App/AppCompositionRoot.swift` are unchanged. `docs/release/contract-failing-baseline.txt` is unchanged.

## What the tests call

| Behavior | Existing type | Test |
|---|---|---|
| `%2e%2e`, `%252e`, `%00` | `DeepLinkAndUniversalLinkSafetyAudit.audit` | `AppSecParameterValidationTests` |
| raw `\`, `%2e%2e`, non-numeric ids | `NativeNavigationContract.parseInternal` | same |
| non-numeric `topicId` / `merchantId` / `clubId` | `DeepLinkAndUniversalLinkSafetyAudit` | same |
| paid-reveal query (`mode=paid`) and empty gift `token` | `MiniProgramPageLink` | same |
| empty `chein://gift/` and empty landing `t` | `CheinDeepLink` | same |
| decoded `0` (`topicId=0`, `aid=%30`, `tid=0`) stays rejected; empty `aid` stays absent | audit + `CheinDeepLink` + `MiniProgramPageLink` | same |
| bridge extra args, bad keys, control values, non-string payload | `ExternalGameBridgeHandler.handle` | same |
| logout clears the token store | `AppSession.logout` | `AppSecKeychainClearTests` |
| account-deletion expiry clears the token store | `AppSession.expireIfMatching` (the closure `accountComplianceCoordinator` already passes) | same |
| a stale stamp or a non-401 does not clear | same | same |
| unconfigured clear, and `KeychainTokenStore.clear` after write when the simulator entitlement exists | `KeychainTokenStore` | same |
| malicious `chein://mp/%2e%2e/...reveal...?mode=paid&token=` opens nothing | `MiniProgramPageLink(cheinURL:)` and `CheinDeepLink` inside the DEBUG fixture | `MaliciousCheinLinkFlowTests` |

Unknown on that fixture is the em dash `—` (`appsec.chein.closed`). A decoded `0` is not rewritten into a route. Money stays on the existing `ReviewedAreaSwitch`; the logout test asserts `moneyPayments(apiHost: ReviewedAreaSwitch.productionAPIHost)` is false. The UI test launches `--uitesting-module appsecChein` only. That path sets no session, so it does not open a network session and does not mention `www.chengyinhub.com`.

`MPParityRoute` already returns `.reveal(paid: nil)` for a paid query and rejects an empty gift token in `Tests/AppUnitTests/MPParityDeepLinkRouteTests.swift`. This branch does not add a second route type.

## Not present on this tip

- `CheinDeepLink` does not treat a gift token that decodes to `..` as path traversal. `chein://gift/%2e%2e` stays a token when the token rule passes. No new rejection was added.
- `ExternalGameBridgeHandler` storage keys use `^[A-Za-z0-9._-]{1,64}$`, so a key of `..` is not rejected. `%`, `\`, and `/` are. No new key rule was added.
- `URL(string:)` does not produce a value whose `absoluteString` contains a raw `\`. The backslash rejection the tests hit is `NativeNavigationContract.parseInternal`.
- Core has no session Keychain type. The clear lives on `KeychainTokenStore` and the existing `AppSession` methods above. No method was added to `AppSession`.

## Checks

- `python3 tools/generate_project.py` — ran, so the new App and test Swift files are in the generated project.
- `python3 tools/check_scaffold.py` — PASS.
- `python3 tools/check_design_lint.py` — PASS.

`swiftc` and XCUITest were not run. This VM cannot run them.

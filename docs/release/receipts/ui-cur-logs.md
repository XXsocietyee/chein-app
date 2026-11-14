# ui-cur-logs

Branch `ui/cur-logs`. Parent `3ac970ec20191014b4b9a8779a3a94b961e99c9c` (`origin/ui/main`).

`print`, `os_log`, `Logger`, and `NSLog` in `App/` and `Core/` must not emit a phone number, an OpenID, a token, or a street address. `Core/LogFieldRedaction.swift` masks those values in a string. Each call below passes the risky text through `LogFieldRedaction.redacted` and still logs the event. There is no second logger. No `os_log` or `Logger` call exists in `App/` or `Core/`.

`docs/release/contract-failing-baseline.txt` was not raised. No method was added to `App/AppSession.swift` or `App/AppCompositionRoot.swift`. `ReviewedAreaSwitch` was not redeclared. `www.chengyinhub.com` stays closed. This machine has no `swiftc`, so the new `LogFieldRedactionTests` were not executed.

## Redacted

| Call | What is masked |
|---|---|
| `App/RegionalLaunchConfiguration.swift:269` `NSLog` `[E2E] METHOD URL -> status ms body` | The URL (`absoluteString`, which can carry a `token` query) and the first 600 bytes of the response body, masked on line 268 (phone, OpenID, token, and street values). Status and latency stay. |
| `App/RegionalLaunchConfiguration.swift:274` `NSLog` `[E2E] METHOD URL -> error` | The URL and the error text. The failure is still logged. |
| `App/AppCompositionRoot.swift:2589` `NSLog` `[E2E] composition refused or failed` | The error text. Method and path stay. The failure is still logged. |
| `Core/PlayExperienceCoordinator.swift:859` `NSLog` `[E2E] reconcileRun failed` | `String(describing: error)`. The failure is still logged. |

The two calls in `App/RegionalLaunchConfiguration.swift` are the DEBUG `E2ETestHostTransport` logs only. `composition`, `shippedComposition`, the host check, and the money install are unchanged.

## Left

These calls do not interpolate a phone, an OpenID, a token, or a street address.

| Call | What it logs |
|---|---|
| `App/TemplateAuthoringSecureStorage.swift:19` `print` | `operation` and `osstatus` for the sealed creator fixture |
| `App/SocialActionViews.swift:259` `print` | Synthetic confirm phase |
| `App/ProfileFavoriteRemovalView.swift:23` `print` | Lifecycle scene, identity, finished, phase |
| `App/MerchantOnboardingFixtureSupport.swift:114` `print` | Diagnostic event, busy, locked, editing, step |
| `App/LoginView.swift:172` `print` | Integrated-login phase name |
| `App/MerchantBusinessLifecycleDiagnostics.swift:17` `print` | Scene and editor flags |
| `App/DesignSystem/CYShareComposerState.swift:107` `print` | Render milliseconds and ratio |
| `App/DesignSystem/CYMorphButton.swift:14` `print` | Haptic name and count |
| `Core/PlayExperienceCoordinator.swift:812` `NSLog` `restoreRun` | Mode, media flag, persistence flag, loaded, busy |
| `Core/PlayExperienceCoordinator.swift:867` `NSLog` `startRun` | canManage, owner, lease, pending, busy, recoveryFailed, phase |

## Lint

`tools/check_log_redaction.py` fails when a new `print`, `NSLog`, `os_log`, or `Logger` call in `App/` or `Core/` interpolates one of those fields unless the identifier is an argument of `LogFieldRedaction.redacted`. A field buried in the string passed to `redacted` still fails; pass the value itself. `tools/check_scaffold.py` runs this lint after `tools/check_design_lint.py`.

## 中文

`App/` 和 `Core/` 里的 `print`、`NSLog` 不再把手机号、OpenID、token 或街道写进日志。值在调用处交给 `LogFieldRedaction.redacted`，失败事件仍保留。没有新增日志框架。

`RegionalLaunchConfiguration.swift` 只改了 DEBUG 的两条 `[E2E]` 日志参数。启动组合、主机判断和金额开关没有改。`AppSession` 与 `AppCompositionRoot` 没有新增方法。合同失败基线没有抬高。本机没有 `swiftc`，没有跑 Swift 测试。

`tools/check_log_redaction.py` 会在新日志把上述字段直接插值时失败，并由 `check_scaffold.py` 调用。

# ui-cur-strings

Branch `ui/cur-strings`. Parent `e3264af9fc694cfadea419e59d31c790aa8163c1` (`origin/ui/main`).

## Scan

User-facing keys are the catalog lookups in `App/` and `Core/` that `tools/check_catalog_coverage.py` already treats as keys, plus a whole key passed as `String.LocalizationValue(stringLiteral:)`. Fixture, harness, preview, sample, stub, demo, and mock files are skipped. A literal that only builds a prefix (it ends in `.` or `_`) is not guessed.

`python3 -B tools/check_catalog_coverage.py` on this parent was `gaps: 0` (no key absent from the catalog its call reads, no untranslated unit, no format mismatch). The same lookup walk found no key used in `App/` or `Core/` that is absent from `Resources/Localizable.xcstrings` and the other `Resources/*.xcstrings` tables.

## Filled

| Key | Table | en | zh-Hans | Source of the Chinese |
|---|---|---|---|---|
| `u10.growth.unit.exp` | Localizable | EXP | 经验 | `growth.unit.exp` already uses 经验 for the same English |
| `merchantAuthoring.skuID` | MerchantAuthoring | SKU ID | 规格编号 | `merchant.desk.sku.skuIdentity` already uses 规格编号 for the same English |

`tools/add_u10_screens_localizations.py` keeps the same EXP / 经验 pair so a later run of that writer does not put the English back.

Keys filled: **2**. Keys that were absent from every catalog: **0**.

## Left unmatched

These used keys still have zh-Hans equal to the English. No other catalog entry has a different zh-Hans for that same English, so the Chinese was not invented.

| Key | Table | en and zh-Hans |
|---|---|---|
| `beGapIm.webhook` | Localizable | Webhook |
| `nativeEnrollment.app` | Localizable | App ID |
| `d7.webhook.detail.title` | NativeWebhook | Webhook |
| `d7.webhook.field.url` | NativeWebhook | URL |
| `d7.webhook.editor.httpsURL` | NativeWebhook | https://… |

The mini-program repo (`hengyin` / `chengyinhub-xcx`) is not on this machine, so those five were not taken from it.

## Gate

`tools/check_missing_string_keys.py` fails when a key used in `App/` or `Core/` is missing from the catalog that call reads, is only present in a different catalog, or that entry has no non-empty translated `en` or `zh-Hans`. `tools/check_scaffold.py` runs it immediately after `tools/check_catalog_coverage.py`, which is how `release-gate` and `native-ios` already run the other `tools/*.py` checks. `check_catalog_coverage.py` is unchanged. `docs/release/contract-failing-baseline.txt` was not edited.

No Swift file changed. `swiftc` is not installed on this machine, so `swiftc -parse` was not run.

## 中文

`App/` 和 `Core/` 里现有查找方式能对上的键，目录里都有。没有新增缺失键。

两处中文原先等于英文，已改成仓库里同一英文已有的译法：`u10.growth.unit.exp` 改为经验（与 `growth.unit.exp` 相同），`merchantAuthoring.skuID` 改为规格编号（与 `merchant.desk.sku.skuIdentity` 相同）。

Webhook、App ID、URL、`https://…` 没有另一条中文可沿用，保持原样。本机没有小程序仓库，没有从小程序补文案。

`tools/check_missing_string_keys.py` 在键缺失、表不对、或缺少 en / zh-Hans 时失败，并由 `check_scaffold.py` 调用。没有放宽原有门禁，也没有抬高 contract-failing baseline。没有改 Swift 文件。本机没有 `swiftc`，没有做 `swiftc -parse`。

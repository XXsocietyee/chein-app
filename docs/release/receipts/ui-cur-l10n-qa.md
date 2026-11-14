# ui-cur-l10n-qa

Branch `ui/cur-l10n-qa`. Started at `5d652cc08ac5ccc668db315fc57253b909b9e058` (`origin/ui/h-design-v1`). `ui/h-design-v1` was not moved. No merge of `ui/cur-t1-2`.

Localization only. No color, spacing, data-binding, grant, or money-switch edits. `App/RegionalLaunchConfiguration.swift`, `App/AppSession.swift`, `App/AppCompositionRoot.swift`, and `docs/release/contract-failing-baseline.txt` were not edited. No new Swift file. This machine has no `swiftc`; nothing here is a compile.

## Scan

Catalogs: every `Resources/*.xcstrings` (213 files, 24445 keys). `App/` has no `.xcstrings`.

Used keys: `python3 -B tools/check_missing_string_keys.py` and `python3 -B tools/check_catalog_coverage.py`. A used key is a catalog lookup in `App/` or `Core/` that those gates already treat as a key, plus a whole key passed as `String.LocalizationValue(stringLiteral:)`. Fixture, harness, preview, sample, stub, demo, and mock files are skipped.

Length: each zh-Hans string unit against the en unit on the same variation path. "Longer than twice" means `len(zh) > 2 * len(en)` in Unicode scalars. Button, tab, and chip titles were matched from `Button("…")`, `CYButton`, `CYPillButton`, `CYFilterChip`, `CYStatusChip`, and `CYTabItem` in `App/` and `Core/`.

## Counts

| Count | N |
|---|---|
| Keys given a missing zh-Hans | 0 |
| Keys given a missing en | 0 |
| English zh-Hans values translated | 2 |
| Controls allowed to wrap | 0 |
| Keys left untranslated | 14 wholly Latin values, grouped below |

`missing_keys: 0`, `wrong_table: 0`, `incomplete_locales: 0`, `gaps: 0`. No catalog entry was missing a non-blank translated `en` or `zh-Hans` unit.

No zh-Hans unit is longer than twice its en unit. Two units are exactly twice (`To` / `结束日期`, `To` / `结束时间`). Both are `DatePicker` labels, not a button, tab, or chip, and neither uses `lineLimit(1)` or a fixed text frame. The only button, tab, or chip title whose Chinese is longer than its English is `parityB.circle.save` (`Save` / `保存供给角色`, 4 vs 6). That toolbar button has no `lineLimit(1)` and no fixed frame, so it was not changed and the Chinese was not shortened.

## Translated

| Key | Table | en | zh-Hans before | zh-Hans after | Why this Chinese |
|---|---|---|---|---|---|
| `merchantAuthoring.product.sku` | MerchantAuthoring | SKU ID | SKU ID | 规格编号 | `merchantAuthoring.skuID` and `merchant.desk.sku.skuIdentity` already use 规格编号 for the same English |
| `media.selectLogo` | ClubProfileMedia | Choose logo · 1:1 | 选择 Logo · 1:1 | 选择标志 · 1:1 | `media.logo` in the same table is already 标志 · 1:1 |

`App/MerchantGamePlayerView.swift` shows SKU ID from a view-private pair, not from the catalog. Its Chinese side is now 规格编号. The English side is still SKU ID. No new symbol.

## Left untranslated

Wholly Latin zh-Hans values that are still words, names, URLs, or codes. Not guessed.

| Keys | zh-Hans | Why it stayed |
|---|---|---|
| `beGapIm.webhook`; `d7.channelManage.webhooks`; `d7.webhook.title`; `d7.webhook.detail.title` | Webhook | The rest of the Chinese catalog already says Webhook (`添加 Webhook`, `删除 Webhook`, `Webhook 地址`). 回调 or 网络钩子 would be a different product term. |
| `templateAuthor.prefab.scene.boot` | hello world | The prefab asks the player to type that English phrase (`PlayPrefabScenes.bootTarget`, and `playx.prefab.boot.instructions`). |
| `nativeEnrollment.app` | App ID | ID is the identifier token. The review sentence on the same screen already says App ID. `Resources/Localizable.xcstrings` is also the frozen catalog leaf in the admission inverse, so that token was not rewritten. |
| `d7.webhook.field.url` | URL | URL, not a sentence. |
| `d7.webhook.editor.httpsURL` | https://… | URL placeholder. |
| `merchant.categories.id %lld` | ID %lld | Code plus a number. |
| `growth.level.value %lld`; `square.levelBadge %lld`; `square.xcx.level %lld` | Lv.%lld | Level abbreviation already used for the square badges in both languages. |
| `mpd.aiChat.exportAI %@` | AI：%@ | Abbreviation. The colon is already the Chinese full-width colon. |
| `creatorStudio.version %lld` | v%lld | Version mark. |

Format counters (`%lld / %lld`, `%lld / 4000`, `+%lld`) have no English word to translate. Mixed strings that are already Chinese and only keep a field name, brand, or code (`Apple`, `DeepSeek`, `TOPIC_MEDAL`, `tag.name`, `Webhook` inside a Chinese sentence) were left as they are.

## Gate

`python3 tools/check_scaffold.py` and `python3 tools/check_design_lint.py` are the pre-push checks. `tools/current_ci_manifest.json` source-inventory hashes were updated for the three edited product files so the current snapshot still matches the tree. No new Swift symbol.

## 中文

目录里被 Swift 用到的键都有英文和简体中文，没有补缺失的一侧。

两处中文仍是英文，含义在本目录里已经有译法：`merchantAuthoring.product.sku` 改为规格编号（与 `merchantAuthoring.skuID` 相同）；`media.selectLogo` 的 Logo 改为标志（与同表 `media.logo` 相同）。商家对局页上直接写死的 SKU ID 中文也改为规格编号。

Webhook、hello world、App ID、URL、Lv.、ID、AI 没有另造译法。没有任何按钮、标签或芯片的中文长过英文的两倍，所以没有改换行。本机没有 `swiftc`，没有做编译。

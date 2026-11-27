# i18n r2 · lane `i18n-r2-strings` receipt (2026-11-27)

Branch `i18n/r2-strings` from `origin/ui/combined-r7`. Brief: `design/handoff-r2:docs/briefs/round2-1127.md` (row `i18n-r2-strings` + English sweep row). No compiler in the cloud; every API used already has a precedent in App/ (noted below).

## Gates (last run before the final push)

| Gate | Result |
|---|---|
| `python3 tools/generate_project.py` | ran, no project diff |
| `python3 tools/check_scaffold.py` | PASS (no FAIL lines; 20,063 bilingual keys) |
| `python3 -B tools/check_a11y_lint.py` | PASS, 0 new |
| `python3 -B tools/contract_ratchet.py --check` | 104 failing = baseline 104, **new 0**, fixed 0 |
| `python3 -B tools/check_l10n.py` | PASS: 0 CJK en values, 0 missing en; literal baseline **2795 → 2269** |
| `python3 tools/check_personal_location_share.py` | 2 failures, **already failing on the base branch** (`personal location sharing` phrase missing from the InfoPlist location string; `personalLocationShare.loadingEligibility` not rendered). I didn't touch either one. |

New strings: `docs/port/strings/i18n-r2-strings.json` (163 keys, merged into `Resources/Localizable.xcstrings`) and `docs/port/strings/i18n-r2-strings-widget.json` (2 keys, merged into `LiveActivityWidget/Localizable.xcstrings` with the same merge tool, `catalog_path` argument).

## Done

- **`PlaySharedPlanLifecycleView` rewritten in player words** (`App/PlaySharedPlanLifecycleView.swift`). The audit wording is gone: 原票轮, 权限代次, activity/session/team ids, request ids, the raw JSON payload disclosure, "原 PLAYER 写能力／command 端点", and "UNKNOWN 不是失败". Every line now comes from `sharedPlan.*` keys (en + zh-Hans). The Chinese uses the MP's own wording from `mp-source:chengyinhub-xcx/pages/play/theme-plan-list.wxml` and `utils/theme-plans.js`: 共同方案, 本队物资, 可用 · 锁定, 需求：, 前置条件已满足/未满足, 本队私有意向, 已确认托管, 本队首选, 本队接受, 本轮不选任何方案, 签署接受清单, 确认方案操作结果, 本场结局已确认, 共同操作完成，继续剧情, and the phase/policy names. Behaviour, buttons, accessibility identifiers, the sheets and the enable/disable logic are unchanged.
  - Core's pinned strings (`PlaySharedPlanAction.title/.consequence` and the `PlaySharedPlanLifecycle.message` values) stay as they are. The view shows them through `LocalizedStringKey(...)`, and catalog entries keyed by the Core Chinese give plain MP-style zh (e.g. 开始原操作任务 → 开始操作任务) plus English. Lists use `ListFormatter.localizedString(byJoining:)`, not 、.
  - `PlaySharedPlanR5HostView` (same feature): the 7 flagged literals now use `sharedPlanR5.*` keys. Its other audit lines were already catalog keys with English, so I left them.
- **`WorkshopCommerceView`**: the 26 licence/refund/combination-rights lines now come from `workshopCommerce.r2.*` keys in plainer words (US spelling "license"). Amounts still read `CUR 12.34` from the ledger (`reversalAmount`), and permission rows use per-permission keys.
- **「」 → locale-aware quotes**: new `appQuoted(_:locale:)` and `appJoinedPair(_:_:locale:)` in `App/AppLocalizedString.swift`. Chinese keeps the MP's 「」. Other locales use `Locale.quotationBeginDelimiter/EndDelimiter`, falling back to “ ”. Applied at `NativeGameKitsC.swift` (testimony + VoiceOver "，"), `PlayKitQuestoViews.swift` (same), `PlayKitLegacyViews.swift` (name suggestions; uses `locale: .current`, same as the `PlayKitNewGameForms.swift:58` precedent) and `RoamNearbyParityExtras.swift` (online quotes). `TemplateAdoptionViews.swift:198` was a zh-only verbatim sentence with 「」 and is now `templateAdoption.shelfNotice %@`.
- **`CYPermissionPrimer` location copy matches behaviour** in both languages: roam and city orienteering keep recording in the background with the iOS indicator until you pause or finish (as `SessionBackgroundLocationTracker` and `NSLocationWhenInUseUsageDescription` describe). Personal sharing is still disclosed. The points no longer claim "Never in the background". `CYStateKit.swift:339` had the same "only while the app is open" claim and is fixed too. Note added to `docs/roam-fog/location-permission-copy.md`.
- **`widget.community.inline` fallback**: `ViewThatFits(in: .horizontal)` tries the long line, then `widget.community.inline.short` ("3 unread · 5 posts" / "3 未读 · 5 动态"), then `widget.community.inline.unread` ("3 unread").
- **English sweep, d2-home**: the section header "Continue Game / Continue Exploration" is now **"Continue"**, and each row's eyebrow is its type, **"Game"** / **"Exploration"** (`Core/HomeSearchTabParity.swift`; `Tests/CoreTests/HomeSearchTabParityTests.swift` updated to match). zh keeps the MP's 继续游戏 / 继续探索. **"Player" chip**: the MP badge is "✓ 玩家" (the `icon-member.png` tick, `pages/index/index.wxml:41-47`), i.e. a role badge, not a checkbox. English now shows `person.crop.circle.badge.checkmark` next to "Player"; zh keeps the MP asset.
- **`CityKit/CityChallengeFlow`, `ClubChannelMessagingView`, `CoreLoopCopy`**: these were already bilingual (`copy(zh, en)` / a `zh: en` table). The checker missed them because of nested quotes inside interpolations, pairs split over two lines, and colon tables. I moved the nested defaults into small helpers (`selectedChannelName`, `composerPlaceholder`, `replyLine`), joined the split pairs and fixed the 护盾 title (its English half was an empty string). The en text changed only for "Report channel #name" (sentence case).
- **`NativeZeroHPAuthorPresentation` / `TemplateShelfArt`**: no change needed (see "Not done").
- **Gate fixes**: `tools/check_l10n.py` now (a) counts `"中文": "English"` translation-table entries as bilingual pairs, like the existing `t("中文", "English")` rule, and (b) treats a Chinese token that App code maps to a catalog key (`"生命值": "zeroHP.copy.017"`) as localized wherever it appears. I sampled 25 of the newly-accepted pairs and all were real translation tables. I also fixed 6 l10n failures that were already on base: `Chein (城瘾)` in 3 en values → "Chengyin" (catalog, `fix-r9-club-a.json`, `tools/build_auth_entry_catalog.py`); `CityLiveOnMap.swift:179` miles/km label; `E1CommerceComponents.swift:122` full-width yen prefix check now uses `\u{FFE5}`; `RegistrationStripePaySection.swift:78` pair joined.

## Not done

- `TemplateShelfArt` (120 literals): these are **lookup keys**. Chinese topic and game titles from the server are matched to bundled MP covers and never displayed (`art.js` binds by name). They must stay as they are; translating the names belongs to content/server.
- `NativeZeroHPAuthorPresentation`: already localized (Chinese Core diagnostics → `zeroHP.copy.*` in `ZeroHPAuthor.xcstrings`). The 8 literals left are regex/prefix parse tokens of Core messages.
- `CoreLoopCopy`: 16 literals left. They're `hasPrefix`/`hasSuffix` parse fragments of Core strings, not shown as is.
- `PlaySharedPlanR5HostView`: the rest of its audit-style zh (原身份或回执合同…, 重试同一原请求) already has English but would benefit from the same plain-words pass. I left it because it's outside the brief's named file.
- 2269 baselined literals remain overall (mostly internal readiness/diagnostic views and content data, same as the r1 receipt).

## Risks for first compile

- `PlaySharedPlanLifecycleView`: `Text(a) + Text(verbatim:) + Text(b)` concatenations, `Button(role:action:label:)`, `Section(LocalizedStringKey(...))`, `LabeledContent { } label: { }`, and `ListFormatter.localizedString(byJoining:)` (Foundation class method). `phaseKey`/`policyKey`/`intentStatusKey`/`outcomeKey` return `LocalizedStringKey` from literals or `LocalizedStringKey("prefix." + value)`. `result(_:label:)` now takes `LocalizedStringKey` and branches `if let title { Text(title) } else { Text(label) }`. I added `@Environment(\.locale) private var locale` for `appLocalized`.
- `appQuoted` uses `Locale.quotationBeginDelimiter` / `quotationEndDelimiter` (`String?`), plus `locale.language.languageCode?.identifier` (precedent `CoreLoopCopy.swift:7`).
- `WorkshopCommerceView`: `Text("key \(String(accountID))")`. `permission(_:_:)` builds `LocalizedStringKey("workshopCommerce.r2.permission." + name + ...)`. `reversalAmount` is a file-scope `private func`.
- `QuestBoardWidgets.swift`: `ViewThatFits` inside the `.accessoryInline` family. If the inline family ignores the fallback, it still renders the first (current) line.
- `ClubChannelMessagingView.replyLine(_:)` takes `MessagingMessage` (`senderID: Int?`, `senderName/content: String?`).
- `HomeSearchTabParityViews.swift`: the `if / else if / else` icon branch in the `Label` `icon:` builder.

## Owner questions

None blocking. The English brand in the 3 en strings is now "Chengyin" (r1 rule). If US users should search WeChat by the Chinese name, that needs a product decision.

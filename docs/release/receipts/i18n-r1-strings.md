# i18n r1 · lane `strings` receipt (2026-11-27)

Branch `i18n/r1-strings`, based on `origin/ui/combined-r7` (fc95e6a19). No compiler in the cloud: every API used is already in use elsewhere in App/ (see the "API precedent" notes). Gates run before each push: `check_scaffold.py`, `check_a11y_lint.py`, `check_l10n.py`, `contract_ratchet.py --check`.

## Counts

| Measure | Before | After |
|---|---|---|
| en values containing CJK, `Resources/Localizable.xcstrings` | 34 | 0 |
| en values containing CJK, side catalogs (AccountCompliance, AccountDeregistrationPresentation, AuthEntry ×3, ClubOpsJoinNotify, PublisherIdentityRegistration ×2, SocialParity) | 9 | 0 |
| keys missing en (all catalogs incl. widget) | 0 | 0 |
| hard-coded CJK literals in App/ (outside merchant/fixtures/previews/comments; catalog keys and inline `t("中文","English")` pairs count as localized) | 2847 in 248 files | 2795 in 243 files (ratchet baseline) |
| new catalog keys | — | 53 (`compliance.confirmWord` + 52 in `docs/port/strings/i18n-r1-strings.json`) |

## (1) CJK in en values

- Brand in English is **Chengyin** (matches existing `mpd.titleCard.brand`, `mpd.aiChat.exportTitle`, `widget.control.open`). `城瘾Hub` → `Chengyin Hub`. All 25 brand strings in `Resources/Localizable.xcstrings` and 7 in side catalogs.
- en/zh were swapped for `orientScore.reversed`, `orientScore.review.disputeEntry`, `orientScore.titlePhase %@`, `wallet.points.entryFallback`; `profile.inviteRewards.heroPending` had zh in en. Fixed (and in `docs/port/strings/fix-r3-member-b.json`).
- `merchantInsight.short.*` (次/单/位 suffixes) → ` check-ins`/` orders`/` visitors` (leading space, the code concatenates — `App/MerchantInsightHeroSections.swift:153`).
- `mp.seats.howTo.arriveNote` → "Walk into the place and tap I'm Here" (matches `playerGap.lead.arrive` / `roam.live.discover`).
- `merchantCoop.team.shareInvite %@ %@` path now uses English menu names.
- **Type-to-confirm account deletion**: en asked users to type 注销. `App/AccountDeregistrationImpactSection.swift:72-77` now accepts the localized `compliance.confirmWord` (en `DELETE`, zh `注销`, case-insensitive) or 注销 in any language. `compliance.typeToConfirm` / `c08.display.35` say "type DELETE".
- Source fragments and generators synced so regeneration keeps the fixes: `tools/build_auth_entry_catalog.py`, `docs/port/strings/{comp-r1-widgets,fix-r3-member-b,fix-r8-merchant-coop,fix-r8-mp-first}.json`, `docs/{settings-native,square,w2-11}-localizations.json`, `docs/parity/w2-07-localizations.json`, `docs/release/ui-strings-{e3-share,e4,pages-activity-official-detail-index}.json`, `Resources/{RuntimeDependency,ClubGovernance}Localizations.fragment.json`.
- `App/ObjectBadgeViews.swift:263` badge share text en said "on 城瘾" → "on Chengyin".

## (2) Hard-coded Chinese in player/club UI

- `App/DesignSystem/CYBusinessComponents.swift` — `CYTaskStatusCard` (the check-in card in `PlayExperienceView.swift:450,1634`): badges, method/receipt/offline/draft lines and all buttons now come from `cyTask.*` keys; default CTA via `CYTaskStatusCopy.defaultCTATitle`. `CYPublishStatusBar`: title, step titles, issue line, save chips, submit button from `cyPublish.*`. `Tokens.badgeTitle` now holds a catalog key (tests only check tones/colours).
- `App/CityParticipationFormView.swift:56-59` action labels localized (they also feed `确认操作：%@`).
- Catalog entries (no code change) for interpolated keys: `%lld 星`, `%lld 人`, `还差 %lld 人`, `%lld 岁`, `%lld 次引用`, `%lld 支队伍在线`, `附近活动 · %@`, photo-picker and certificate-image labels, `画廊列数：%lld`, creator RPG/recovery fields.
- `Text(verbatim:)` on strings that already had a catalog key (9 sites: `NativeSharedRecoveryAuthorView`, `NativeRpgPassiveRulesAuthorView`, `PlayerContentRound2Views` "更多", `CYBusinessComponents` "取消") now localize. `ClubGapRound4Views.swift:70,88` proof-image labels localized.
- API precedent: `Text("key \(x)")` → `key %@`/`%lld` (`PlayKitSensorChallengeView.swift:122`); `appLocalized(String.LocalizationValue(var), locale:)` (`MerchantInsightHeroSections.swift:153`); `String(format: appLocalized(...), …)` (`RoamHistoryShareView.swift:351`).
- Plurals: the scaffold contract requires a plain `stringUnit` per language, so no plural variations; counts use plural-neutral English ("Members: 3", "1 of 5 stars").

## (3) Widget, Live Activity, permission prompts

- `LiveActivityWidget/Localizable.xcstrings`: widget gallery and Control Center names in Title Case (Next Activity, Roam Streak, City Progress, Messages & Club, Start Roaming, Check In); `liveActivity.play.stop` "Stop" → "Current stop" (zh is 当前站点); Roaming; City orienteering; check-in intent description; zh typo 城因 → 城瘾.
- `Resources/InfoPlist.xcstrings` + `Config/Base.xcconfig` (kept identical, contract-tested): location, microphone and motion prompts rewritten in plain US English; pinned phrases kept (`keeps recording in the background`, `never shared with other players`, `NPC voice`, `sound peak`, `amplitude is measured on device without uploading audio`).

## (4) Gate

`tools/check_l10n.py` fails on CJK in any en value (all `Resources/*.xcstrings` + widget catalog), on a key without en, and on any App/ file whose hard-coded CJK literal count exceeds `tools/l10n_cjk_literal_baseline.json`. `--report` lists files; `--update` only lowers the baseline (`--allow-raise` to raise). Not yet wired into `check_scaffold.py` — coordinator's call.

## Not done / remaining (next round)

- 2797 baselined literals. Largest player-facing: `TemplateShelfArt`, `NativeZeroHPAuthorPresentation`, `RoamCityGuideCatalog` (content data), `CoreLoopCopy`, `CityKit/CityChallengeFlow`, `ClubChannelMessagingView`, `PlaySharedPlanLifecycleView` (team plan, audit-style wording 原票轮/权限代次 needs a product rewrite, not a translation), `WorkshopCommerceView` licence/refund lines.
- ~40 internal readiness/diagnostic `*SectionView` screens (e.g. `SevenDayLaunchCriticalPathSectionView`, `UnifiedOPT*`, `ReleasePreflightDiagnosticsView`) are hard-coded Chinese; several have no references. Left as is.
- 「」 quote wrappers in `NativeGameKitsC.swift:689`, `PlayKitLegacyViews.swift:99`, `PlayKitQuestoViews.swift:565`, `RoamNearbyParityExtras.swift:258` show CJK corner quotes in English.
- `App/DesignSystem/CYPermissionPrimer.swift` location primer says "Never in the background" while the system prompt says roam keeps recording in the background — contradiction (both languages).

## Owner questions

1. **English brand name**: catalogs now say **Chengyin**. Is that the US name? The home-screen name is still `INFOPLIST_KEY_CFBundleDisplayName = Questify` (`Config/Base.xcconfig:10`) in both languages; should en be "Chengyin" and zh-Hans "城瘾" (would add `CFBundleDisplayName` to `InfoPlist.xcstrings`)?
2. `authEntry.deregister.*` tells US users about Beijing time and the WeChat mini program. Is that right for the US build, or should those strings change with the US backend/login decision?
3. The account-deletion confirm word in English is `DELETE`. OK?

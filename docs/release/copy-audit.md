# Copy audit (e1, 2026-11-09)

Scope: `Resources/*.xcstrings` (EN + zh-Hans), `docs/release/ui-strings-*.json`, view string literals in `App/`, and the newest contact sheet of every worker in `chengyin-refs/design-reports/*/`. Glossary and voice: `glossary.md`.

Tooling already clean: `tools/check_catalog_coverage.py` → `gaps: 0` (no missing keys, no untranslated units, no format-specifier mismatches between EN and zh). No raw dotted key is used as a catalogue *value*. Dynamic key prefixes (254 found, e.g. `playBadge.open.`) are accessibility identifiers or enum-suffixed keys; none resolved to a missing key by static scan.

## A. Fixed in this branch (strings only)

| Issue | Count | Fix |
|---|---|---|
| `Questify` / `Chengyin` in visible EN text (privacy consent text, merchant review notices, "Hosted by …", "Questify player", etc.) | 22 strings | → 城瘾 (`Questify Assistant` → `城瘾 assistant`) |
| Share text used the wrong brand "成印" and "Chengyin" (`ObjectBadgeViews.swift:207`) | 1 | → 城瘾 |
| About screen name `Chengyin - 城瘾` | 1 | → `chein - 城瘾` |
| zh term drift: 线路 vs 路线 | 10 | → 路线 |
| zh term drift: 点评 vs 评价, 专题 vs 主题 | 5 | unified |
| zh 印章 in a stamp permission prompt (stamps are 邮票) | 2 | → 邮票 |
| zh text hard-coded in views with no EN (`Text("纬度")`, `"需求：" + …`, `"确认"`, …) | 23 literals | catalogue keys added (EN + zh) in `Localizable.xcstrings`; concatenations now `String(localized:)` |
| EN leaking into zh: `Beta`, `NEW`, `TEAM INVITATION` | 3 | → 测试版 / 新 / 组队邀请 |
| Mixed-language share/legal fragments | – | left (see C) |
| 20 most visible state strings rewritten (loading, offline, empty home/search/tickets/messages/clubs/orders/badges/roam/square/routes, route load errors, unconfirmed write, camera/location off ×2, consent summary/decline/check) | 28 keys | `ui-strings-e1.json` lists every key with EN/zh |

Build fixes found while merging (not copy): `E3Fixtures.swift` had a stray `#endif` after line 399, and `E1TicketCard.swift` was registered twice in the project file.

## B. Findings left for owners

1. **"original request / receipt / writer / installation" jargon**: 331 EN strings (Localizable 65, ModInstallation 28, PersonalLocationShare 21, MerchantAuthoring 17, CityOnsiteTask 14, NativeChannelNotification 14, CityAcquisition 12, NativeWebhook 12 …) and the matching zh 原请求/原回执. Mostly author and ops screens; reads like an API spec, not a person. Rewrite as "your earlier request" / "你之前的请求". Owners: author tools, merchant tools.
2. **Source-text keys equal to their value** (43): long English sentences used as keys (`Couldn't load this. Check your connection.`, creator/mod sentences). Fine functionally, but rewording the sentence orphans the key; prefer dotted keys. Plus 11 dev-note keys such as `Stage 0 基线与509条旧线索复核 (OPT-001..003)` and `Wave-2 (w2-01..w2-21) …` sitting in `Localizable.xcstrings`: not user-visible, remove from the catalogue.
3. **English kept inside zh values** (allowed technical terms, check each): `Webhook`, `SKU ID`, `App ID`, `URL`, `EXP` (growth.unit.exp → suggest 经验), `hello world` (template prefab sample), `Logo · 1:1` (ClubProfileMedia `media.logo` → 标志 · 1:1).
4. **zh in EN values**: `城瘾 · CityFog` share-card brand (roam.medalShare.brand, roamSub.w208.share.brand), and the "type 注销 to confirm" prompts (intentional: the user types the Chinese word). Make the share lockup `城瘾` only.
5. **`示例内容` / "Example content"** appears as a banner on many fixture pages; keep DEBUG-only.
6. **Bilingual concatenation** in a title: "Example city guide / 示例城市指南" (play detail fixture). One language per screen.
7. **City note naming**: EN used city stamp / daily verse / city note for 城市签; use *city note* (see glossary). Remaining EN: `roam.experience.cityStamp`, `roam.tools.recap.kind.stamps`, `creator.family.dailySign` (owner: roam).
8. **Mixed jargon in zh**: 勋章 vs 徽章 are both live (54 / 25). The code distinguishes medal vs identity badge, so both stay, but per-screen use one.
9. **Capitalisation**: a few EN strings are Title Case or ALL CAPS (`Official Routes`, `Route`, `TEAM INVITATION` eyebrow). Sentence case per glossary.
10. **Length**: EN button labels over 18 chars, e.g. "Allow camera access in Settings…" style labels in permission flows should be a short verb ("Allow camera"). Needs an owner pass with a lint (not run).

## C. Contact sheets (newest per worker; 76 sheets exist, 13 newest viewed)

| File (`design-reports/…`) | What is visible |
|---|---|
| `e2/contact-155753.png` | zh Game journal shows raw API identifiers in user text: `已获印章切片 (userStamps)`, `已完成任务切片 (completedTasks)`, `独立印章读取无回归 (loadUserStamps)`; uses 印章 not 邮票; zh stamp book shows EN fixture names `Synthetic city stamp`, `Synthetic reviewed stamp`; zh ticket wallet shows `Sample exploration ticket`, `Sample expired ticket`. Owner e2. |
| `e3/contact-144713.png` | zh Club details shows EN `Fixture club 81`, `Fixture type`, `Host / Fixture creator` (EN sheet is consistent). Owner e3 (DEBUG data, but a zh shot should show zh fixture names). |
| `e4/contact-160654.png` | zh About/Settings fine. DEBUG chips `Member fixture`, `Synthetic member`, `Synthetic sign out` are visible in the shots (labelled DEBUG: allowed). Marketing screen copy "营销偏好" correct in zh, EN body long. |
| `e5c/contact-153844.png` | zh Search home shows EN `Recent routes` heading and EN category chip `Synthetic culture`; results card `Synthetic topic / Offline night`; Roam list EN `Night market 1…` (fixtures). |
| `d2/contact-070208.png` | "Suggested searches / Categories / Find activities and topics on the map" (EN) above zh chips 骑行, 城市, 外滩 in one shot: mixed-language screen; welcome title bar shows the old `Questify` header (since replaced by the wordmark upstream). |
| `e5/contact-122143.png` | welcome wordmark `CHENGYIN` (old build; current upstream uses `chein 城瘾`). EN ok. |
| `e5b/contact-135300.png` | zh play guide detail: EN body `This is offline fixture content. No real route…` and EN `Synthetic route basics` under a bilingual title `Example city guide / 示例城市指南`. EN sheet shows the word "fixture" in user-facing text. |
| `d7/contact-074433.png` | Both languages show `(debug fixture)` inside template names and nav titles (`Cover (debug fixture)`): DEBUG-labelled, allowed; zh sheet has EN template names `Sample city walk`. |

Not viewed (older, superseded): `d4`, `e1`, `int` newest sheets and the other 63 older ones. Owners should re-shoot with `-preferences.language zh-Hans` before sign-off.

## D. Verification

`e1c` batch: 16 EN + 16 zh shots of the same 16 fixtures (messages empty, orders empty, favorites empty, notices empty, projects empty, offline, error, location/camera/notification permission, search home, tabs, about, privacy, profile-edit error, wallet income). Launch args `-preferences.language en|zh-Hans -AppleLanguages … -AppleLocale …`, one build. Outputs: `chengyin-refs/design-reports/e1c/batch-*.png` and the contact sheets.

## E. Round 2 (DES-e2, 2026-11-09)

### E1. Fixed in this branch (strings only)

| Issue | Where | Fix |
|---|---|---|
| Chinese passed as `verbatim:` / `Text(verbatim:)`, so it never localised and showed Chinese in EN (the catalogue already had the EN) | `CityOrderedMapView` (3 buttons/chip), `CityParticipationFormView` (5 buttons), `CityNodeRedeemView` (5 sentences), `MerchantCityNodeCreateView` ("去登录") | switched to localised initialisers |
| Status helpers returned plain `String` literals, never looked up (`可用/已暂停/不可用`, `尚无归属/本队/其他队伍/保留审核/尚未核定`) | `CityCurrentSnapshotView` | `String(localized:)` |
| Interpolated zh-only keys with no EN (剩余额度, 每次消耗, 骰子, 骰面, 坐标系, 纬度, 经度, 状态, 归属 …) | `CityActionBudgetView`, `CityCurrentSnapshotView`, `CityParticipationFormView` | 31 new keys EN + zh in `Localizable.xcstrings`, listed in `ui-strings-e1.json` |
| Share lockup `城瘾 · CityFog` in EN and zh | `roam.medalShare.brand`, `roamSub.w208.share.brand` | → `城瘾` |
| zh `EXP`; zh `Logo · 1:1` | `growth.unit.exp`, `media.logo` | → 经验; → 标志 · 1:1 |
| Missing catalogue key | `rewards.pledge.title` | added (Reward pledges / 奖励承诺) |

Lint after: `tools/check_catalog_coverage.py` → gaps 8 (all pre-existing, from other lanes: 8 `W8Text.t("zh","en")` inline literals in `BundleWalletView`, `BundleReviewComposeView`, `BundleTransferClaimView`, `RoamItemDetailView`: "我的预约", "提交申诉", "次卡钱包", "正在提交…", "评价", "转赠", "领取转赠", "商家忘记核销时，可提交审核。"). These render correctly in both languages through `W8Text`, but are not in the catalogue; owner e1/bundle lane should move them to keys.

### E2. Still open (owners)

1. **309 `Text(verbatim: "中文…")` literals** remain, nearly all in engineering/diagnostic `*SectionView.swift` panels (`WeChatAndAppleSignInNonce…`, `PerformanceSignpost…`, `CommerceOrderLifecycle…`, `ThreeDocumentMasterCrosswalk…`, `Reform…W02ToW20…`, `ProductionSigning…`, `FinalReleaseSignoff…` …). None of these views is referenced from a player route (checked by grep). They must stay unreachable in release (or `#if DEBUG`); if any is exposed, it is a ship-blocker for EN.
2. **Player-reachable but still jargon-heavy** (words like 原请求 / 原回执 / 权限代次 / 票轮 / UNKNOWN, `原 status 0`, `required`): `PlaySharedPlanLifecycleView` (10 interpolated zh-only keys with no EN: lines 18, 19, 33, 39, 72, 75, 76, 88, 102, 149), `MerchantOfferWithdrawalOriginalView` (lines 24, 35–39, 76, 85, 98–99 use `\(…)` with raw field names), `MerchantAuthoringView:57` (`权威回读`). Owner: team plan / merchant tools. Rewrite per glossary rule 6.
3. **Source keys that are Chinese sentences** (`Text("…")`) mean the zh text is the key; editing the sentence orphans the EN. New work should use dotted keys.
4. `#城瘾CityFog` hashtag (`RoamShareAlbumGuideView:45`) is pinned by `RoamShareAlbumGuideFlowTests`; change both together when marketing decides.
5. `SettingsView:83,258` `Text(verbatim: "简体中文")` is intentional (endonym).

### E3. Contact-sheet findings (newly viewed, 2026-11-09)

| File (`design-reports/…`) | Language | Visible problem |
|---|---|---|
| `d2/contact-063932.png` | zh | EN `Hi, Mia!`, `More ways to play`, `Sample neighborhood route · Sample district · From ¥12.5`, `Synthetic journey`, `Synthetic topic`, `Fixture conversation 1…7`, `Synthetic fixture · debug only`, `Synthetic pending/upcoming/completed`, `Fixture NPC`; `CITY 经营权与原回执` (jargon), `Unknown design fixture: d6-real-live` |
| `d2/contact-064651.png` | EN | Welcome header still `Questify`; `Live roaming` card `Example content`; `Synthetic …`/`Fixture …` fixtures (DEBUG-labelled `debug only`); `CITY ownership and original receipts` (jargon); tab `Actions left this round` fine |
| `d2/contact-063254.png`, `d2/contact-063643.png`, `d2/contact-065406.png` | – | Home-screen shots (app not in foreground); no usable copy. Re-shoot. |
| `e1/contact-151511.png` | zh | EN `Old Town Lantern Walk (o…`, `Lantern Market Quest (fixture)`, category chip `Synthet…`, `Sample native order`, `Fixture club 81`, `Fixture type`, `Fixture received message`, `Synthetic debit / Synthetic missing amount`, `Fixture identity`, `Synthetic city stamp`; shows 示例内容 banner (fine) |
| `e3/contact-211604.png` | zh | EN `Fixture club 81`, `Offline sample club description.`, `Fixture creator`, `Synthetic club story`, `Weekend walks`, `East Gate, Riverside Park`, buttons `Refresh source / Switch account / Replace reader / Finish detail` inside a zh screen (DEBUG fixture chips: confirm they are `#if DEBUG`) |
| `e4/contact-214521.png` | zh | zh settings/consent screens clean; zh sign-in sheet fine. Overlay toast `Synthetic sign out` over the complaints form (DEBUG). `Welcome back` EN body consistent. |
| `int/contact-tail.png` | EN | `A synthetic city walk / 一次示例城市漫步` bilingual title; `Example walker`; `Sample Person (debug fixture)` in invoice rows (DEBUG-labelled but lives in a release screen layout); `Official Routes` Title Case (glossary: sentence case → `Official routes`); `All —`, `Channels —` tab counts show a dash (correct: unknown). `Fixture NPC`, `Fixture club` |

Sheets with only older duplicates or empty home-screen captures (not re-read): `d2` ×4, `d4` ×5, `d7` ×5, `e1` first 11, `e2` first 9, `e3` first 11, `e4` first 11, `e5` ×2, `e5b` ×4, `e5c` ×1, `int` ×6. A mechanical scan was not possible without OCR; owners should re-shoot zh with `-preferences.language zh-Hans` and re-check the rows above.

Pattern across all workers: the zh runs show **EN fixture names** because DEBUG fixtures are English-only. Ask: give `E*Fixtures` a zh set keyed by `-preferences.language`, so a zh contact sheet is honest.

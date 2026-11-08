# UI-F09 report — settings / legal / privacy / deregister / participants / profile edit / favorites

**NOT COMPILED.** Branch `cloud/ui-f09` from `origin/wip/gate-allowlist`. Presentation only; theme = PLAYER DARK (forced at the role root, no per-view scheme).
Mini-program source was accessible (`chengyin/chengyinhub-xcx/pages/**`); WXML/WXSS read for every page.

**Screenshot note:** `docs/xcx-wechat-review-board-shots/settings.png` is NOT the 设置 list: it shows the 声音与触感 sheet (sound/haptics + ambient list, all "暂未接入"). No screenshot exists for the other seven pages (`artifacts/**` holds only merchant-ai-npc / route-flow / route-m5 shots). Layouts were therefore taken from WXML/WXSS only.

| page (mini_path) | screenshot | iOS file | matched | deliberately changed / not done |
|---|---|---|---|---|
| pages/shezhi/shezhi (6) | `settings.png` = sound/haptics sheet only (sound screen already mirrors it: info + 声音/触感 + 环境音 rows) | SettingsView, SettingsSupportSections, SettingsAccountEntries | Row order 个人资料 → 俱乐部主理人/商家 → 城瘾玩法 → 我的收藏 → 隐私与定位 → … → 用户服务协议 → 账号注销 → 关于 → 退出账号 (neutral, non-red) already present; ADDED 素材署名 block (SettingsAttributionsSection) under sign-out as in `.sz-attribution` (bottom of page); page ground = `CYColor.bgPage` via new `cyGroupedSurface()` | Extra native rows (notifications, language, region, invoice, NPC data, safety, sound) have no mini-program row and are kept (gated features stay gated). Mini 112rpx cell/gap rhythm replaced by native Form row metrics (Dynamic Type). Attribution is still also in About (ui-06 owns that file). |
| pages/deregister/index | none found | AccountComplianceViews, DeregistrationParityViews | Flow is the mini scene (precheck → SMS → apply → confirm); execute-after rows now use CY meta/secondary tokens | `AccountComplianceViews.swift` already changed by `cloud/ui-22` → NOT edited here to avoid conflict. |
| pages/agreement/index | none found | SettingsLegalDocumentView | Hierarchy title → intro → sections (heading 600 / body, loose leading) → 生效日期 footer; token fonts/colours, 16pt page gutter, `bgPage` ground, 24pt section rhythm | Native nav title kept (no WeChat capsule); version/source-notice rows kept (source-document honesty). |
| pages/privacy/index | none found | PrivacyProtectionView, SettingsPrivacyLocationView | Body paragraph → 隐私保护指引 link → roam location withdraw action (mini order) ; CY body/meta tokens, grouped dark surface | `SettingsPrivacyLocationView.swift` also changed by `cloud/ui-22` (only a one-line `.cyGroupedSurface()` added here — trivial to merge). Mini's side-by-side 暂不同意/同意 gate is the WeChat `agreePrivacyAuthorization` flow; iOS uses UsageConsent gate — not changed. |
| pages/address/address | none found | ProfileParticipantsView (also touched by ui-22) | Name (bold) + phone + caption 用于报名联系和到场核验 per row, empty state, pinned primary action 新增参与人信息; CY name/phone(tabular)/caption tokens, dark ground | Mini's visible 编辑 text + ✕ icon replaced by native swipe actions (Edit/Delete) — Apple-native, already existing. |
| pages/addressinfo/addressinfo | none found | ParticipantFormView | Fields 姓名/手机号, single primary save, inline progress/error states; summary row tokens, dark ground | Native Form field rows instead of 120rpx float label columns. |
| pages/gerenziliao/gerenziliao | none found | ProfileEditView | Order now 头像 → 昵称 → 手机号 → 城市签名 → 探索作品 → 联系二维码 → 路线偏好 → 保存 (introduction row moved after phone); dark ground | Mini editors are bottom sheets per field; iOS keeps its existing text-edit flow (logic untouched). Avatar upload remains gated. |
| pages/mylike/mylike | none found | AccountCollectionFavoritesView | 帖文/主题 fill tabs (segmented, page gutters), card list, per-tab empty/error/skeleton, 已加载全部 footers (CY meta tertiary), pull to refresh | Mini 16:9 cover-scrim card shape not rebuilt (shared QuestifyImageEntityCard). |

## Files touched (10)
New: `App/DesignSystem/CYFormSurface.swift` (`cyGroupedSurface()`, `cyDocumentSurface()`, `CYDocumentHeading`).
Edited: SettingsView, SettingsLegalDocumentView, PrivacyProtectionView, SettingsPrivacyLocationView, DeregistrationParityViews, ProfileParticipantsView, ParticipantFormView, ProfileEditView, AccountCollectionFavoritesView.

New string keys: 0 (`docs/release/ui-strings-ui-f09.json` not needed).
Overlap with wave 1/2: ProfileParticipantsView, SettingsPrivacyLocationView, AccountComplianceViews (ui-22). Previews not added (files have none; no compile available).

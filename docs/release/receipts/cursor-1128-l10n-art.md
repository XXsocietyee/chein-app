# K15 · localized art (`cursor/1128-l10n-art`)

Base: `origin/ui/combined-r7` at `e9296b463496d11cfce823002fe65e69cc8d34fd` (contains pin `882fca768`). Development region is `en` (`Questify.xcodeproj` `knownRegions`: en, zh-Hans, Base). English is the unlocalized asset; `zh-Hans` keeps the original pixels. No `String(localized:)` literals. `App/AppSession.swift` was not edited.

Inventory: every png, jpg, pdf, and svg under `App/`, `Resources/`, and `LiveActivityWidget` (548 unique files). SVG/PDF text streams were read as text. Rasters and rendered PDF pages were passed through Tesseract (`chi_sim+eng`). Hits that were a single unrelated character were opened and are shapes, not type. Three pictures (four bundled files) actually contain designed Chinese type.

| Path | Baked Chinese | What changed | Where it is shown |
|---|---|---|---|
| `App/Assets.xcassets/MP/banner-cover/pages_club_images_club_cover_default.imageset/` (`club_cover_en.png` / `club_cover_zh.png`) | 一起玩 / 打卡 · 组队 · 通关 | **en imageset.** Same illustration. Chinese glyphs cleared by copying the nearest dark-green background pixel; English set in Inter Bold / SemiBold: “Play together” / “Check in · Team up · Finish”. `zh-Hans` is the original PNG, byte-identical. No vector source, so the Latin face is not the original Chinese face. | Club detail header cover, when the club has no cover (`ClubDetailView.swift` `ClubDetailHeader`, `MPAsset.BannerCover.clubCoverDefault`). Level B. The cover stays `.accessibilityHidden`; the club name is the accessible name. |
| `App/Assets.xcassets/MP/banner-cover/images_d_frametu.imageset/` (`d_frametu_en.jpg` / `d_frametu_zh.jpg`) | 城瘾 (orange brush over the subway photo) | **en imageset.** Brush strokes removed (inpaint). “Chein” set in Inter Bold Italic in the same orange — the English brand already used on About. `zh-Hans` is the original JPEG, byte-identical. No brush source: the cleared patch is a soft reconstruction of the photo under the strokes, not a blank frame. | Bundled as `MPAsset.BannerCover.imagesDFrametu`. No live screen draws it (MP `mockData.js` only). |
| `App/Assets.xcassets/MP/banner-cover/pages_club_images_d_frametu.imageset/` (`d_frametu_en.jpg` / `d_frametu_zh.jpg`) | 城瘾 (same pixels as the row above) | **en imageset.** Same English JPEG and the same original `zh-Hans` JPEG. | Bundled as `MPAsset.BannerCover.dFrametu`. No live screen draws it. |
| `App/Assets.xcassets/MP/feature-icon/images_roam_intro_team.imageset/` (`intro-team.svg` / `intro-team-zh.svg`) | 队伍 | **en imageset.** SVG text is “Team” (8.5pt so it stays inside the existing green pill). `zh-Hans` keeps 队伍. The rest of the drawing is unchanged. | Catalog entry `MPAsset.FeatureIcon.introTeam`. No view references it on this branch. The roam intro tickets use `introTicketTeam` / `introTicketMap` / `introTicketRoute`, which are text-free icons. |

Nothing that still ships as the English (development) image was left with Chinese pixels. The `zh-Hans` variants keep the original Chinese on purpose.

## Checked and left because they are not text

| Path | What the sweep reported | Why it was left |
|---|---|---|
| `App/Assets.xcassets/MP/brand-logo/images_d_logo.imageset/d_logo.png` | Looks like a wordmark at a glance | Geometric G mark on transparent. No characters. Shown as the club-logo fallback (`ClubDetailView`). |
| `App/Assets.xcassets/MP/brand-logo/images_cy_logo_mark.imageset/cy_logo_mark.png` | Tesseract: 亿 | Same G mark. Login, About, pass market, official events. |
| `Resources/SettingsBrandMark.png` | Tesseract: 亿 | Same G mark, settings. |
| `App/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` | — | Concentric target. No type. |
| `App/Assets.xcassets/MP/banner-cover/images_home_banner_{2,club,friends,merchant}.imageset/` | — | Illustrations and memoji. No type. |
| `App/Assets.xcassets/MP/banner-cover/images_index_figma_reco_hero.imageset/reco-hero.jpg` | — | Illustration. No type. |
| `App/Assets.xcassets/MP/banner-cover/pages_merchant_images_merchant_coop_banner.imageset/merchant_coop_banner.jpg` | — | Photo. No type. |
| `App/Assets.xcassets/MP/empty-state/images_d_yhqon.imageset/d_yhqon.png` and `images_no_data` / `images_empty_state_figure` | Tesseract: 人 / 十 | Empty-state drawings. No type. |
| `App/Assets.xcassets/MP/feature-icon/images_roam_intro_{map,roam}.imageset/` and `images_roam_intro_ticket_{map,route,team}` | — | Drawings and stroke icons. The only intro SVG with a `<text>` node was `intro-team`. |
| The other 40 Tesseract single-character hits (十, 人, 口, 白, 四, 日, 加, …) on tab icons, tag PDFs, props, and `weixin-market.pdf` | One unrelated character each | Opened the ones that could have been labels (`weixin-market` is a shopping bag, `d_cyinfo1` a gamepad, `d_cyinfo2` a calendar, `d_sctb` an upload glyph, `flavor-stamp` coins, `interaction` a puzzle piece). Shapes, not type. |

No Swift call site assumes those pixels are Chinese. The club cover is the only one of the four that a player screen draws today.

## Gates

`python3 tools/check_scaffold.py` PASS. `python3 tools/check_a11y_lint.py` 0 new. `python3 tools/contract_ratchet.py --check` 46 failing, baseline 46, new 0. `tools/generate_project.py` was not run: no file outside the existing asset catalog was added.

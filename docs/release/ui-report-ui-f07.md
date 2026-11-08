# UI-F07 fidelity report — topic + activity mini-program pages

**NOT COMPILED.** Mini-program source (`chengyin/chengyinhub-xcx/pages/topic|activity`) was available and read (wxml; wxss skimmed for rhythm). Theme: PLAYER = dark (role root forces scheme; no per-view scheme added). Presentation only; no logic, routing, gating, identifiers or existing text keys changed.

Screenshots: the repo has no screenshot of any topic/activity page. Only `docs/xcx-wechat-review-board-shots/shell-topicadd.png` (creator topic-edit shell, not the player topic detail) exists; creator-route PNGs in `chengyinhub-xcx/artifacts/route-*` belong to the authoring flow (UI-09). So layouts below follow the WXML, not pixels.

| mini page | screenshot | iOS file | matched | deliberately changed |
|---|---|---|---|---|
| topic/index/index | none (shell-topicadd.png = creator shell, n/a) | TopicDetailView.swift, TopicXcxSections.swift | section order now follows the mini tabs: cover/`cover-brief` card (type, title, subtitle or hint) → category chips/club → beta → stat bar (hairline-separated label/big numeral/unit cells) → 详情: title/subtitle/venue/audio → 节点介绍 templates → 主题介绍 + 活动内容 → facts/records → 场次 sessions (name/time/meeting/refund left, price + seats right) → activities → 阵容 lineup (horizontal avatar/name/role cards) → availability → 评价 → 故事 chapters + paywall → 路线; bottom action bar | List stays one scroll with segmented jump tabs (no per-tab pages); WeChat capsule/back dropped; page bg `CYColor.bgPage`, insetGrouped cards; CY tokens replace `.secondary`/`Color.secondary`/`QuestifyPalette`; `.cyPrimary`/`.cySecondary` in bar; venue is a row, not a map-tap card |
| topic/merchantinfo, merchantapply, pricing, pricing/partner, components/* | none | MerchantContent*/PublisherLifecycle* (not in this agent's file set) | not touched | merchant (light) / publisher files are owned by other agents; topic components are WeChat sheets with SwiftUI equivalents already in place |
| activity/detail/index (scene-play-activity-detail) | none | ActivityDetailView.swift | hero, cancelled banner, meta, about, people, templates, tickets, reviews, bottom action already matched | page bg token, `.cyPrimary` bottom action |
| activity/baoming/baoming | none | RegistrationSheetView.swift | order already 参与人信息 → 活动信息 → 费用 → 候补 → 同意+支付 | Form bg token, `dangerText/warningText`, monospaced amounts, total row emphasised, `.cyPrimary` |
| activity/list/index | none | OfficialEventsBrowserView.swift, OfficialEventComponents.swift (card) | search, chip tabs, summary row, cards, empty/error | toolbar holds 我发布的/邀约 (no capsule); list bg token; status/progress tinted with tokens |
| activity/official-detail/index | none | OfficialEventDetailView.swift | hero card, facts strip, overview, **活动介绍 cards now before 详情信息** (mini order), tasks, rewards, collective, CTA | facts use numeric tokens; collective % `dataXL`; list bg token |
| activity/official-inbox/index | none | OfficialPrivateViews.swift (OfficialInboxView) | added mini `oi-hero` (eyebrow, headline, paragraph) above invites | tokens for warning/headline |
| activity/official-mine/index | none | OfficialPrivateViews.swift (OfficialPublishedView) | two counted sections; per-section empty now title + sub like `cy-empty` | status capsule uses `bgSurfaceSubtle` |
| activity/official-organizer (no wxml in mini) | none | OfficialOrganizerConsoleView.swift | not touched | — |

New string keys (4) in `docs/release/ui-strings-ui-f07.json`: `topicXcx.section.intro`, `officialInbox.hero.eyebrow|title|sub`.

Could not do: `#Preview`s (no synthetic fixtures added; existing fixture hosts untouched), map-tap venue card, topic components sheets, separate per-tab topic pages. Files overlapping other branches: TopicXcxSections, OfficialEventDetailView, OfficialPrivateViews (cloud/ui-24), RegistrationSheetView (cloud/ui-26) — expect merge conflicts for the integrator.

Files touched (8 + 2 new docs): ActivityDetailView, OfficialEventComponents, OfficialEventDetailView, OfficialEventsBrowserView, OfficialPrivateViews, RegistrationSheetView, TopicDetailView, TopicXcxSections; docs/release/ui-report-ui-f07.md, ui-strings-ui-f07.json. New component files: 0.

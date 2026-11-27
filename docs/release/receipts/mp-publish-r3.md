# Receipt: mp-publish (round 3) — tab 发布 follows the mini-program structure

Brief: `origin/design/handoff-r2:docs/briefs/round3-1127.md` (row `mp-publish`). Common rules are in `round2-1127.md`; design rules are in `design-principles.md`.
Base: `origin/ui/combined-r7`. Branch: `mp/r3-publish`. MP source: `origin/mp-source:chengyinhub-xcx`.
Scope: `pages/template/index`, the tabBar publish sheet, `pages/publish/*`, `pages/templatedetail/*` and `pages/publishkit`, player side only. Merchant features and the story-flow theme were not touched.

## Owner questions
- **Native Apple content?** Yes. The work uses `List`/`Section`, `Picker(.segmented)`, a toolbar `Menu`, `ContentUnavailableView`, `ProgressView` with a visible label, and system button styles. No custom chrome was added.
- **Same structure as the mini-program?** Before this round, no: the native 发布 tab opened on a creator dashboard, while the MP tab is the template shelf. It now matches. The rows below give the detail for each page.

## MP page → native view → differences → fixed?

| MP page | Native view | Difference (MP order first) | Status |
|---|---|---|---|
| `pages/template/index` (tab root) | `PublishTabRootView` | **Tab root.** MP shows the template shelf, with the bell in the header. Native showed a creator dashboard (继续上次的草稿 · 新主题/新玩法 · 专业手动 rows · 从模板开始 · 发布活动/我的项目/身份), and the shelf was one push away. | **Fixed.** The shelf (`DiscoveryTemplateBrowserView(isTabRoot: true)`) is now the root, with the large 发布 title and the bell (`SessionMessagingToolbarEntry`). |
| tabBar `tabBar__publish` → `cy-publish-sheet` | `PublishTabRootView.publishMenu` | **Publish entry.** MP has a floating "+" with 自由探索 / 城市定向 / 互动 / 返回. V3-44: the chosen type goes straight to the professional editor, with no quick setup. Native had no "+" for players. | **Fixed.** A toolbar "+" `Menu` offers 自由探索, then 城市定向 (each opens an empty `ProjectEditView` for that product), then 互动 (`sessionTemplateAuthoringEntry`: intro → naming → editor). Tapping outside the menu works as 返回. |
| same | `PublishTabRootView` ⋯ menu | **Extra items.** 我的项目 and 创作中心 are not on the MP page; the MP reaches them from 我的. | **Kept on purpose.** They sit behind the secondary ⋯ menu (P3), so creators keep a short path. |
| `templatedetail/shelf` header `sh-top` | `DiscoveryTemplateBrowserView` | **Order.** MP shows the 主题/玩法 tabs first, then the search pill. Native had search first. | **Fixed.** |
| same | same | **Extra block.** Native showed the `GameplayPresetSection` block at the top. MP has none: owner b4-21 removed 从预设开始 and the preset page (`template-intro/index.wxml`). | **Fixed.** The block is no longer on the shelf; its fixture `cur5-preset` still renders it. |
| shelf, topic tab | same | **Order and states.** MP: skeleton / error / empty replace the whole shelf; otherwise 精选 rail → tag row → 全部主题 + TOPIC_SHELVES. A chosen tag changes only what is below the tags, and the rail stays. Native put the tag row above the rail and dropped the rail once a tag was picked. | **Fixed.** |
| shelf, game tab | same | **Order and states.** MP: skeleton / error (玩法加载失败 + retry) / empty (还没有玩法), otherwise FEATURED_GAMES rail → tags → GROUPS shelves or the tag's games, all from paged `api/template/list`. Native put tags first. When the list was empty or failed, it fell back to `discoveryTemplateHome` shelves (精选/最新/推荐/必玩/热门), which the MP shelf never shows. | **Fixed.** The order now matches, the fallback and the unused `home` loader are gone, and the empty state has a refresh button, like the topic tab. |
| shelf wording (1121 N6 `shelfNoun`) | same | **Wording.** Players see 主题 / 玩法 (还没有主题, 主题加载失败, 搜索主题与玩法); merchants keep 主题模板 / 玩法模板. Native used the merchant words for everyone. | **Fixed.** New `discovery.player.*` keys are used when `templateTabScope == .consumer`. The English tab label "Routes" is now "Topics", in line with "All topics" and "Search topics and games". |
| `publish/template-intro` | `TemplateAuthoringIntroExperience` | **Covers.** MP shows featured covers only (canvas, aria 精选玩法封面); native added a category and title caption under each one. **Loading.** Native showed a bare spinner, which fails P10. | **Fixed.** Captions are removed, and VoiceOver still reads each play's name. Loading now says 正在加载精选示例. |
| `publish/activity` | `ActivityPublishingView` | **Step indicator.** MP has one step-dots row; native stacked two (an `ActivityPublishStepChecklist` card above the wizard chrome's progress header and step buttons). | **Fixed.** The duplicate checklist card is gone, and the wizard chrome serves as the step row. |
| same, step 2 | same | **Order.** MP: 合作者 → 票单 → 发布前摘要 → 添加票单 → 发布者实名. Native showed the summary last. | **Fixed.** |
| same, steps 0–1 | same | 标题 → 地点 → 日期 → 类型, then 说明 → 封面 → 选择模板. | Already matched. |
| `templatedetail/templatedetail` 详情 tab | `DiscoveryTemplateDetailView` | **Order.** MP: mosaic → 简介 → 审核反馈 + stat cards → 规则 → 怎么验证 → 难度·时长·人数 → 分类与适用场景 → 所需物料 → 创作者说 → 评价 → notice. Native had metadata first and 创作者说 second, and showed feedback/stats and verification after 规则 in one block. | **Fixed.** `DiscoveryTemplateDetailParitySections` and `DiscoveryPlayTemplatePresentationView` take an optional `part:` (default `.all`), so each block renders at the MP's position. |
| `templatedetail/topic-preview` | `DiscoveryTopicTemplateDeckHost` / `TopicTemplateDeckPreviewView` | **Missing content.** The MP intro lists named chapters (第N章 · name / 终章, with a guide of at most 60 characters, per `intro.js`) under the description; native had none. Loading had no visible words. | **Fixed.** `TopicTemplateIntroChapter` ports `buildIntro`/`heading`/`guide`, with English headings "Chapter N · …" / "Final chapter". `ProgressView` now shows 正在加载主题模板. |
| `templatedetail/topic-detail` | `PublicTopicTemplateDetailView` section in `DiscoveryTemplateDetailView` | **Missing mosaic.** MP opens the 详情 tab with a node-image mosaic when there are 2 or more images; native did not. | **Fixed.** A horizontal mosaic opens the same full-screen gallery. Loading words are visible. The rest (剧情 → stats → 节点 → 勋章 → 封面 credit) already matched. |
| `publish/fabu` page 1 | `ProjectEditView` | MP: 名称 + save state → 主题详情 → 模式 / 票务 cards → 角色 (city) → chapters & nodes → add chapter. Native: save chip + 列表/地图 → topic card → 设置 (模式, 票务 with `* 还有 N 项未填`) → 角色 → chapters. | **Top level matches.** The 2000-line editor internals (story-flow blocks, node sheet) were not re-audited this round. Story flow is on hold. |
| `publish/temp` | `TemplateAuthoring*` | — | **Not audited this round** (2079-line editor). |
| `publishkit/index` | — | Placeholder page that `reLaunch`es home; there is no entry to it. | Nothing to map. |

## Not done
- **`PublishingModesView`** (the pushed publish menu, used from home, merchant and deep links) still leads with 快速配置 (Quick setup), which MP V3-44 removed. `Tests/AppUITests/PublishingModesFlowTests` drives that flow, and XCUITest can't run here. The next step is for a lane with a simulator to make that menu the same three choices as the tab "+" and update the UI test.
- **`PublishRootContent`** (the old dashboard) has no caller now. It was left in place to avoid churn; it can be deleted together with `SessionPublishingModesView.isTabRoot`.
- **Template-intro catalog:** `docs/release/ui-strings-pages-publish-template-intro-index.json` still lists the retired identifier `creatorIntro.example.category.{index}`. The contract test reads that catalog; nothing renders it.
- **MP `chooseTopicMode` pre-checks:** the "+" menu does not repeat them (发布信息尚未就绪 / 当前身份不可发布主题). The editor's own capability check (`ProjectEditCoordinator` `canProPublish`, `projectEdit.capabilityBlocked`) answers these when the draft is published.

## Strings (en + zh-Hans), fragment `docs/port/strings/mp-r3-publish.json`
- New keys: `discovery.player.searchAll`, `discovery.player.emptyTopics`, `discovery.player.emptyGames`, `discovery.player.topicsFailed`, `discovery.player.gamesFailed`, `publishTab.publish.interaction`.
- Changed: `discovery.topics` English value, "Routes" → "Topics".

## Contract pins updated
- `test_template_intro_experience.test_catalog_keys_use_explicit_named_table`: the intro now also renders `creatorIntro.loading` (P10), so the test expects four named-table keys instead of three. The reason is noted in the test.

## Gates (last run on the branch head)
- **Project generation:** `python3 tools/generate_project.py` exits 0.
- **Scaffold:** `python3 tools/check_scaffold.py` passes.
- **Accessibility lint:** `python3 -B tools/check_a11y_lint.py` passes with 0 new findings.
- **Contract ratchet:** `python3 -B tools/contract_ratchet.py --check` shows 104 failing against a baseline of 104, with **new 0**.
- **Not run:** no Swift compiler is available here. The edits mirror existing patterns: `ViewModifier` with if/else, `navigationDestination(item:)` on a `Hashable` enum, `ProgressView { Text }`, and `@ViewBuilder` parts.
- **Nothing deployed.**

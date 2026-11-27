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
| same, pre-checks (continue pass) | `PublishTabRootView.choose(_:)` | **Missing.** MP `chooseTopicMode` / `choosePro` / `goTemplate` toast 发布信息尚未就绪，请稍后重试 when the `api/publish/home` snapshot is missing, and 当前身份不可发布主题 when `permission.canProPublish === false` (topic types only). | **Fixed.** The snapshot is read on appear and on account change (`.task(id:)`); a tap re-checks in MP order and shows the same words as a `cyToast`. A missing snapshot also starts a reload. MP's non-blocking 在架已满 toast is not repeated: the push would hide it, and the editor already shows `projectEdit.quotaFull`. New keys `publishTab.publish.notReady`, `publishTab.publish.identityBlocked`. |
| pushed publish menu (continue pass) | `PublishingModesView` | **Choices.** Led with 快速配置 and 专业手动 · 城市定向 / 自由探索 under 主题, 互动 under its own header. MP V3-44 has only 自由探索 · 城市定向 · 互动. | **Fixed.** One headerless section with the three MP choices in MP order (same labels as the tab "+"); each topic type opens the empty professional editor. 发布活动 / 我的项目 / 发布人登记 stay as a secondary section, since the MP reaches them from 我的项目 / club pages and this menu is the native path to them. `QuickPublishingView` itself is kept (unit-tested, no menu entry). |
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
| `publish/temp` (continue pass) | `TemplateAuthoringView`, `TemplateAuthoringGapRound4Section` | **Order.** MP (index.wxml:1213, owner 11-19): 玩法 → 参与方式 → 玩法设置 → 结果反馈 → 玩法规则 → 封面 / 模板信息 → 高级设置 (提示 · 完成奖励 · 互动工具). Native: save chip → cover/name → 模板信息 → 规则 → 玩法 (+ settings) → 参与方式 → reward/story → tools. **Visibility.** MP hides 模板信息 when opened from fabu (`from !== 'fabu'`); native always showed it. | **Fixed.** Order is now save chip (native status) → 玩法 → 参与方式 → 玩法设置 → relax / 可触发的结果 → 规则 → cover + name → 模板信息 → reward / story / voice → tools → media. `TemplateAuthoringGapRound4Section` takes `part:` (`.participation` / `.afterSettings`, default `.all`). The section bar (`EditorOutlineSection`) now follows page order: 玩法 · 规则 · 信息 · 奖励 · 反馈 · 工具; it opens on 玩法. 模板信息 is hidden when `from == "fabu"`. States (登录后编辑玩法模板, loading, error) and the 编辑玩法模板 title already matched. Field-level internals of each gameplay config card were not re-audited. |
| `publishkit/index` | — | Placeholder page that `reLaunch`es home; there is no entry to it. | Nothing to map. |

## Not done
- **Run on a simulator:** `PublishingModesFlowTests` was rewritten (see below) but XCUITest can't run here.
- **`publish/temp` field-level audit:** the order of the blocks now matches; the fields inside each gameplay config card (2079-line MP page) were not compared one by one. Native also keeps its 媒体 review section and the validation list, which the MP has no matching sections for.
- **`publish/fabu` internals:** top level matches; the editor internals were not re-audited, since story flow is out of scope.

## Done in the continue pass (previous Not done)
1. `PublishingModesView` = the three MP choices (row above).
2. `App/PublishRootContent.swift` deleted together with `SessionPublishingModesView.isTabRoot` / `openTemplates`. grep over App/ and Tests/ found no other references. Its entry was removed from `tools/typography_lint_baseline.json`.
3. `creatorIntro.example.category.{index}` was removed from `docs/release/ui-strings-pages-publish-template-intro-index.json`.
4. "+" pre-checks (row above).

## Strings (en + zh-Hans), fragment `docs/port/strings/mp-r3-publish.json`
- New keys: `discovery.player.searchAll`, `discovery.player.emptyTopics`, `discovery.player.emptyGames`, `discovery.player.topicsFailed`, `discovery.player.gamesFailed`, `publishTab.publish.interaction`.
- Changed: `discovery.topics` English value, "Routes" → "Topics".
- Continue pass: `publishTab.publish.notReady` (发布信息尚未就绪，请稍后重试), `publishTab.publish.identityBlocked` (当前身份不可发布主题).

## Contract pins updated
- `test_template_intro_experience.test_catalog_keys_use_explicit_named_table`: the intro now also renders `creatorIntro.loading` (P10), so the test expects four named-table keys instead of three. The reason is noted in the test.

## Tests edited to match MP-driven changes (continue pass)
- `Tests/AppUITests/PublishingModesFlowTests.swift`: the quick-draft test was replaced by `testMenuOffersTheThreeMiniProgramChoicesInOrder` (labels, MP order, topic type opens the editor, no 快速配置). The zh test now expects 自由探索 / 城市定向 / 互动 / 发布活动 and no 快速配置. The fixture host passes synthetic `makeProfessional` / `makeTemplateAuthoring`.
- `Tests/ContractChecks/test_activity_publishing_wizard.py`: `PREFIX_SHA` was re-pinned, because the menu body above `QuickPublishingView` changed. `QUICK_SHA` and `SUFFIX_SHA` are unchanged.
- `Tests/ContractChecks/test_template_intro_page_ready.py`: the test now expects 4 identifiers (was 5), and asserts that the retired category id is absent.
- `Tests/CoreTests/EditorKitModelTests.swift`: `EditorOutlineSection.allCases` now expects the MP page order.

## Gates (last run on the branch head)
- **Project generation:** `python3 tools/generate_project.py` exits 0.
- **Scaffold:** `python3 tools/check_scaffold.py` passes.
- **Accessibility lint:** `python3 -B tools/check_a11y_lint.py` passes with 0 new findings.
- **Contract ratchet:** `python3 -B tools/contract_ratchet.py --check` shows 52 failing against a baseline of 52, with **new 0** (continue pass, after merging `ui/combined-r7`).
- **Not run:** no Swift compiler is available here. The edits mirror existing patterns: `ViewModifier` with if/else, `navigationDestination(item:)` on a `Hashable` enum, `ProgressView { Text }`, and `@ViewBuilder` parts.
- **Nothing deployed.**

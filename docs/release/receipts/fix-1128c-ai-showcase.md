# Receipt: fix-1128c-ai-showcase (AI on the home page and in the build process)

Branch `fix/1128c-ai-showcase`, based on `origin/ui/combined-r7` (70917c058). Owner 11-28 ~12:25 UTC: "We need to
highlight AI in our build process and homepage. We have AI NPCs, AI guides, and various weather systems."
Sources: `design/handoff-r2:docs/planning/ai-requirements-1128.md`, brief `round3-1127.md` (OWNER RULE 1-3, levels,
planning-audit Release-composition rule), `audit/1128-plan:docs/audits/1128-plan.md` (H-08a/b/c), backend hengyin
`origin/us/r3-functional` `ApiAiController.java` (`/theme/draft/prepare|execute|quota|recovery` :173-287,
`/template/fill` :325, `/safety/precheck` :385, `/club/design` :461; `gateRole` :86 blocks players,
`gateThemeDraftRole` :108 lets players draft), MP `chengyinhub-xcx` (`pages/index/index.wxml`,
`pages/publish/fabu/index.js:6859-6990`, `pages/club/detail/index.js:1632-1661`). Merchant AI (`ai/merchant/*`, the
store-bound template fill) stays deferred.

## Step 1 · Home AI showcase (level B · Crafted, P34)

| MP page → native | MP sections kept (✓) / added | Optimizations |
|---|---|---|
| `pages/index/index.wxml` → `App/HomeFeedView.swift:113-118`, `App/SessionHomeFeedView.swift:157`, `App/HomeAIShowcaseCard.swift` | banner → greeting/city → location card → **AI showcase (added, owner 11-28)** → 编辑精选 ✓ → (我的地盘 rail, unchanged) → 附近活动 ✓ → 即将上线 ✓ → feed tabs ✓. The MP home has no AI block, so the card heads the 编辑精选 (featured) block as the brief asks; no MP section moved. Hidden when the whole feed is down (one error state) | One designed object (`.cyCard()`): sparkles art band on `CYColor.brandSoft`, eyebrow "AI guide · AI NPCs", title + subtitle; **live example**: today's suggestion chosen by the current weather (symbol + label + °C, `symbolEffect(.bounce)` on change, `.contentTransition(.numericText())`), a reviewed nearby NPC row with "Chat with …" when the guide branch offers one; one `.borderedProminent` "Start AI guide" (link → guide; default → 漫游 tab, where the reviewed roam prompt layer runs, audit R-18) and one `.bordered` "Create with AI" (→ hub); AIGC disclosure line; Dynamic Type text styles only, `ViewThatFits` for the action row, VoiceOver header + hints |

Copy is data: 27 suggestion lines (`aiShowcase.guide.<any|clear|cloudy|rain|snow|fog|wind|storm|sand>.<1-3>`, rotated
daily, `Core/AIExperienceLink.swift` `AIShowcaseCatalog`) and the chrome in `Resources/Localizable.xcstrings`, en +
zh-Hans, written by `tools/add_fix_1128c_ai_showcase_localizations.py`. The guide branch can serve its own reviewed line
through `AIExperienceLinking.todaySuggestion(for:)`, which wins over the catalog.

## Step 2 · AI as the first step of the build process

| Entry | File | What it does |
|---|---|---|
| 发布 tab "+" | `App/PublishTabRootView.swift:126-133,194-195` | **Create with AI** is the first menu item (then a divider and the MP 自由探索 / 城市定向 / 互动 in MP order) |
| Publish menu (home 更多玩法, 我的, deep links) | `App/PublishingModesViews.swift:42-48` | first section **Create with AI**, then the MP choices |
| Home showcase | `App/HomeAIShowcaseCard.swift` `HomeAIShowcaseActions` | "Create with AI" |
| Hub | `App/AICreationHubView.swift` `SessionAICreationHubView` (level C) | Draft a route with AI (player, club); Fill a template with AI and Design a club event with AI (club hosts, the backend `gateRole`); "Before you publish: AI safety precheck"; signed-out `ContentUnavailableView` with sign-in; AIGC filing line |
| Draft with AI (`api/ai/theme/draft/prepare|execute|quota`, read-back `request|recovery`) | `SessionAIThemeDraftStartView` → `QuickPublishingView(opensAIOnAppear: true)` (`App/PublishingModesViews.swift:88-92,182-191`) → existing `PublishingAIDraftSheet` | the AI sheet opens first: **quota** (`PublishingAIQuotaSection`), **progress** + stop (in place), **review-before-apply** (draft card, "Use this draft"), **recovery** of an earlier draft (`G6AIThemeDraftRecoverySection`), **errors** (server message / unavailable / quota exhausted); then places to confirm on the map and the professional editor. **Undo**: "Undo AI draft" restores the page's draft from before the adopted AI draft (`App/QuickPublishingJourneyOwner.swift:26-27,108-120`) |
| Fill template with AI (`api/ai/template/fill`, H-08a) | `SessionAITemplateFillView`, `Core/AITemplateFill.swift` | venue + idea (+ category / reward / play style), Fill with AI → progress + Cancel → **review** (every field labelled) → "Use in the template editor" fills the retained 互动 template draft (`TemplateAuthoringCoordinator.change`) → Open the template editor / **Undo AI fill**; server refusal shown verbatim, failure → Try again; a pending saved draft blocks the apply with a clear line |
| Design with AI (`api/ai/club/design`, H-08c) | `App/ClubDetailView.swift:150-151` (existing `SessionClubAIDesignView`) | now **on in Release** (`.publishingAIClub`), shown with the AI glyph in the club Manage tab (MP 运营管理 grid entry); review → adopt into the editor (existing flow) |
| AI safety precheck before publish (H-08b) | `App/ProjectEditView.swift:326-328,524,662-672,677-678,841-843`, `App/AISafetyPrecheckGate.swift`, `Core/AISafetyPrecheck.swift` | 下一步 / 提交草稿 first POST `api/ai/safety/precheck` JSON exactly `{title, subtitle, description, nodes:[{name, task, hint1, hint2}]}` built like MP `_buildPrecheckReq`; MP classification (`error` blocks except `parse_error` / `timeline_conflict`; `missing_cover` dropped); a block opens "Fix before publishing" (issues + Keep Editing, `.warning` haptic once); no block → the existing review step continues on its own; any failure / quota / role gate → **degrade to pass** with the MP skip line in the new "AI safety precheck" editor row |

### H-08b request fields corrected
- `UGCContentSafetyService.precheckContent` (`Core/UGCContentSafetyService.swift:310-322`) now sends the DTO
  (`description` = the text, empty `title`/`subtitle`, `nodes: []`) instead of `{content, scene}`.
- `PublishingAIRuntimeTransport` refuses any other shape for `.publishingAISafety`
  (`Core/PublishingAIRuntimeFactory.swift:30,46-47`).
- A failed precheck clears its journal marker (`Core/PublishingAuxiliaryService.swift:155-160,167-170`). Before, one
  outage left a persistent marker and every later publish skipped the precheck. Deliberate change; the pinned test
  became `testUnavailableSafetyStaysSoftGateAndClearsItsMarker` with a comment.

### Release composition: every service ON
`App/AICreationReleaseApprovals.swift`, merged in `ReviewedProductionGateLeases.sessionDependencies`
(`App/ReviewedPlayerWriteLeases.swift:1680-1681`) and admitted by the composition transport (`:72-73`):

| Feature | Route | Player | Club | Merchant |
|---|---|---|---|---|
| `.publishingAIQuota` | POST `api/ai/theme/draft/quota` (no body) | ON | ON | off |
| `.publishingAITheme` | POST `api/ai/theme/draft/prepare`, `…/execute` | ON | ON | off |
| `.publishingAIClub` | POST `api/ai/club/design` | — (backend blocks) | ON | off |
| `.publishingAITemplate` | POST `api/ai/template/fill` | — (backend blocks) | ON | off |
| `.publishingAISafety` (new feature, `Core/BusinessRuntimeConfiguration.swift:21-22,347`) | POST `api/ai/safety/precheck` | — (backend blocks; degrades to pass) | ON | off |

Proof: `Tests/AppUnitTests/AICreationReleaseCompositionTests.swift` builds
`RegionalLaunchConfiguration.reviewedDeployment` + `makeComposition` and asserts the routes per role (player, club,
merchant), that every granted route passes its feature catalog (`BusinessRuntimeConfiguration` would otherwise be nil),
that `ReviewedProductionFormMutationRoute.acceptsPlayerWrite` and `ChinaReviewedRouteCapability.admitsChinaProductionCall`
admit the six exact requests (and refuse GET, a body-less creator call and a quota call with a body), that the runtime
transport refuses the legacy `{content, scene}` body, the MP request order and issue classification, and the weather
facts parser.

## Step 3 · Coordination with the sibling AI branches

- `Core/AIExperienceLink.swift`: `AIExperienceLinking` (`canStartGuide`, `startGuide()`, `nearbyNPC`,
  `chatWithNPC(_:)`, `todaySuggestion(for:)`, `currentWeatherFacts()`), `AIShowcaseWeather(guideFacts:)`,
  `AIShowcaseNPC`, `AIShowcaseCatalog`. `App/AIExperienceEnvironment.swift`: environment values `aiExperienceLink`,
  `aiWeatherFacts`, `aiSafetyPrecheckSource`, installed by `AIExperienceRootEnvironment` (one line in
  `App/QuestifyApp.swift:516`).
- **fix/1128c-ai-weather** (fetched 11-28, 7 commits): exposes `Core/WeatherContext.swift` with
  `WeatherContextBoard.shared.current?.guideFacts` = `["weather", "intensity", "temperatureC", "daylight", "daypart",
  "source"]`. `AIShowcaseWeather(guideFacts:)` reads exactly `weather` / `temperatureC` / `daypart` and knows its
  `sand` kind. No type of that branch is named here, so both branches compile alone. **After both merge**, add in
  `AIExperienceRootEnvironment.body`:
  `.environment(\.aiWeatherFacts, { WeatherContextBoard.shared.current?.guideFacts })`.
- **fix/1128c-ai-npc-guide** (fetched 11-28: inventory only, no code yet; it plans `App/AIGuide/*`,
  `App/AINPCReleaseComposition.swift`, `Core/StoryContent.swift`). No name collides (`grep` for `AIShowcase*`,
  `AICreation*`, `AISafety*`, `AIExperience*`, `AITemplateFill*` was empty before this branch). **After both merge**, its
  guide object conforms to `AIExperienceLinking` and is installed with `.environment(\.aiExperienceLink, …)` in
  `AIExperienceRootEnvironment`. Until then "Start AI guide" opens 漫游 and the NPC row is hidden (no dead control).
- The new files live directly in `App/` and `Core/` (the generator globs only listed subfolders), so
  `tools/generate_project.py` needs no edit that could conflict with the guide branch's folder.

## Files
New: `Core/AIExperienceLink.swift`, `Core/AISafetyPrecheck.swift`, `Core/AITemplateFill.swift`,
`App/AICreationReleaseApprovals.swift`, `App/AIExperienceEnvironment.swift`, `App/AISafetyPrecheckGate.swift`,
`App/HomeAIShowcaseCard.swift`, `App/AICreationHubView.swift`, `Tests/AppUnitTests/AICreationReleaseCompositionTests.swift`,
`tools/add_fix_1128c_ai_showcase_localizations.py`.
Changed: `App/HomeFeedView.swift`, `App/SessionHomeFeedView.swift`, `App/PublishTabRootView.swift`,
`App/PublishingModesViews.swift`, `App/QuickPublishingJourneyOwner.swift`, `App/ProjectEditView.swift`,
`App/ClubDetailView.swift`, `App/QuestifyApp.swift`, `App/ReviewedPlayerWriteLeases.swift`,
`Core/BusinessRuntimeConfiguration.swift`, `Core/PublishingAIRuntimeFactory.swift`, `Core/PublishingAuxiliaryService.swift`,
`Core/UGCContentSafetyService.swift`, `Resources/Localizable.xcstrings`, `Questify.xcodeproj`, `docs/design/levels.md`,
`docs/release/owner-values.md`. `App/AppSession.swift` is unchanged (7977 lines, ratchet kept).

Pinned tests updated deliberately (each with a comment): `Tests/CoreTests/UGCContentSafetyServiceTests.swift` (DTO
body), `Tests/CoreTests/PublishingAuxiliaryTests.swift` (marker cleared), `Tests/ContractChecks/test_project_edit_review_availability.py`
and `Tests/ContractChecks/test_project_cloud_draft_intent.py` (下一步 / 提交草稿 go through `precheckThenReview`).

## Gates
GATES_PLACEHOLDER

## Not verified here
No Swift compiler or simulator in this environment: the Swift sources were checked by reading only (declared
`@State` / `@Environment`, typed view structs and static funcs instead of long closures, no `{` + `//` on one line).
The unit tests above run in Xcode (`QuestifyAppUnitTests`, `QuestifyCoreTests`). Owner values: see
`docs/release/owner-values.md` "fix/1128c-ai-showcase" (backend AI provider and quota, AIGC filing number, showcase copy).

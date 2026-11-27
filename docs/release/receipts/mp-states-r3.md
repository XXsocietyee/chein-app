# mp-states r3 — states sweep (empty / loading / error / offline / signed-out)

Branch `mp/r3-states`, base `origin/ui/combined-r7`. Brief: `origin/design/handoff-r2:docs/briefs/round3-1127.md`
(OWNER RULE + OWNER RULE 2). MP source: `origin/mp-source:chengyinhub-xcx`.

One native pattern everywhere:
- empty / error / signed-out / offline → `ContentUnavailableView` (via `CYEmptyState`, `CYErrorState`, `CYContentState`,
  `CYStateView` or a direct call) with the MP `cy-empty` / `cy-error` title and the MP CTA as the one button
  (`.borderedProminent` for 登录 / next step, `.bordered` for 重试);
- loading → system `ProgressView` with a **visible** label carrying the MP loading words (加载中… / 正在加载…).

No Swift compiler in this environment: edits are type-simple and mirror existing call sites.

## Method

`cy-empty` / `cy-error` titles, CTAs and retry labels were extracted from every player `.wxml` (merchant / shop / coop /
organizer / story excluded) and matched against the native string catalogs and Swift sources. A title with no native
match is a queue item (133 at the start). Tab roots first, then their pushed pages.

## Receipt

| Screen | MP state (path → title / CTA) | Native before | Native after |
|---|---|---|---|
| All screens using `CYLoadingStateView` (46 call sites) | `components/cy/empty` kind `loading` 加载中 · `cy-loading-mask` 加载中 | bare `ProgressView()`, words only for VoiceOver | `ProgressView { Text("cy.state.loading") }` — 加载中… / Loading… visible |
| All screens using `CYLoadingState` | same | skeleton block + footnote, no system spinner | `ProgressView` with the caller's MP loading words as the label |
| Official events (`OfficialReadScreen`: activity list / detail / mine / inbox) | `pages/activity/list` loading | overlay `ProgressView()`, label hidden | `ProgressView { Text("official.loading") }` — 正在加载官方活动 visible |
| Social reads (`SocialReadScreen`: guides, public profile, invites …) | loading | `ProgressView()`, label hidden | `ProgressView { Text("social.loading") }` — 正在加载… visible |
| 俱乐部 tab — club list (`ClubHomeView` → `ClubReadScreen usesClubTabStates`) | `pages/talent/list/index.wxml:65` cy-error: 登录后查看我的俱乐部 · 登录 / 当前身份不能查看俱乐部 · 重试 / 俱乐部列表加载失败 · 重试 | generic 请登录后继续 + hint / 暂无俱乐部访问权限 / 俱乐部加载失败 | MP titles (en: Sign in to see your clubs / This identity can’t view clubs / Couldn’t load the club list); same CTA; sign-in drops the extra hint like the MP (no sub) |

## Gates

See the last commit message on the branch for the gate run that accompanied each push.

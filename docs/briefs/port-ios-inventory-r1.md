# Port chengyin-ios into chengyin-app, step 1: inventory and port plan (owner, 2026-11-24)

**Owner decision:**
- chengyin-app is the official iOS app.
- Everything good in chengyin-ios is ported into chengyin-app. Then chengyin-ios is retired.
- "Leverage the strengths of each and compensate for their weaknesses."

You are a PLANNER. You are read-only on product code, and you write ONE plan file.

## Background
- Both apps are the same SwiftUI codebase until **2026-10-13**: the last shared commit is `a8d387e` "Limit CI review notes to public iOS test assertions". After that they diverged.
  - **chengyin-ios** (`/home/user/chengyin-ios`, origin/main a5c863e): about 58 merged PRs, about 219 files, +16.7k / −3.5k lines.
  - **chengyin-app** (`/home/user/chengyin-app`): the redesign, City Monopoly, the type and chrome sweep, and parity rounds 1 and 2.
- Our SwiftUI app is on `origin/ui/combined-r5`. Round-2 fixes are on `origin/fix/parity2-*`, and will be merged into `ui/combined-r6`. The Flutter app on chengyin-app `main` is out of scope.
- **The audits of chengyin-ios against the MP:** `origin/audit/ios-parity-<area>:docs/audit/ios-parity/<area>.md` for member, account-publish, merchant-coop, club, player-content and play-roam. Read their "verdict", "intended difference" and "chengyin-ios avoids" notes.
- **Strengths of chengyin-ios** found by the audits:
  - It uses the system back button, semantic Dynamic Type everywhere, and fewer custom headers and confirmation sheets.
  - State handling is honest: unknown is kept apart from zero, and it shows estimate notices.
  - Its contracts for search, city nodes and templates are cleaner.
  - It has story reading, cast (characters and dialogue), motion polish, the hint ladder, free-explore chapters, offline chapters and image fallback chains.
  - It has per-feature capability gates.
- **Weaknesses of chengyin-ios:**
  - It has no reviewed deployment, so it never reaches the backend.
  - Many pages are missing compared with the MP.
  - Its settings and compliance pages follow Flutter rather than the MP.
  - Its topic detail is read-only.
  - "local sample" and fixture-only flows.
- **Strengths of chengyin-app:** MP parity of 55–80%; live TEST and production contracts; the owner-approved redesign and type scale (`docs/design/type-and-chrome.md`; `.cyText(.token)`, `cyPageTitle`, `cyGuardedBack`); City Monopoly; and the motion kit (`CYMotion`, `CYInPlaceResult`).
- **Weaknesses of chengyin-app:**
  - Some custom chrome remains.
  - Known red tests: Core 27 and AppUnit 72.
  - Its state honesty is uneven.

## Steps
1. List every change in chengyin-ios since `a8d387e`:
   - Run `git log --first-parent a8d387e..origin/main`.
   - For merged PRs, read the PR titles and bodies with `git log` messages, or with `gh` if it is available.
   - Run `git diff --stat a8d387e origin/main`.

   Group the changes into **feature clusters**, for example story reading, cast, motion-1118/1119, free-explore and arrival, hint ladder, image fallback, ProfileSelf, compliance, test and CI infrastructure.
2. For each cluster, compare it with chengyin-app at `origin/ui/combined-r5` (plus the `fix/parity2-*` branches) and decide one of:
   - **PORT:** chengyin-app lacks it and it is good.
   - **MERGE-IDEA:** both apps have the feature. Keep ours, and take their better part (name exactly which part).
   - **SKIP:** it conflicts with MP parity, an owner ruling or our design system, or ours is already better. Give the reason.
   - **ALREADY:** chengyin-app already has it.

   Also list the cross-cutting qualities to adopt across our app: Dynamic Type, system back, honest states and capability-gate discipline. For each, give a rule and the files where our app falls short. Don't break the owner-approved type scale or the MP visual values.
3. For each PORT or MERGE-IDEA cluster, give:
   - the source commits and files in chengyin-ios;
   - the target files in chengyin-app;
   - the approach, either a 3-way `git cherry-pick` (the history is shared, so try it in a scratch clone and report how many files conflict) or a manual re-implementation;
   - the adaptation needed: our type tokens and chrome helpers, our deployment and contracts, our strings in `Localizable.xcstrings`, and the City Monopoly and redesign screens;
   - the tests to bring over;
   - the risk, and an estimate (S, M or L).
4. Split the work into **4–6 port packages** that cloud agents can run in parallel without touching the same files. For each package, list its owned files and its order dependencies. Cloud agents have no Swift compiler: a local integrator compiles. So keep each package's surface reviewable.
5. List anything in chengyin-ios that must be preserved before the repo is deleted. Include docs, tests, assets, fixtures and owner rulings recorded only there, and say where each should go in chengyin-app.

## Output
- Write `docs/port/ios-port-plan.md` on a new branch `port/plan-r1` from `origin/design/handoff-r2` in chengyin-app, and push it.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Push nothing to chengyin-ios. Don't edit product code. No secrets. MP screenshots are private.
- If the usage limit stops you, push what you have first.

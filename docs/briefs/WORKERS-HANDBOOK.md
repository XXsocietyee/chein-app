# Chengyin (城瘾) iOS: the complete picture for every worker (Cursor, Gemini, Claude)

Read this first, then your package brief. It is the shared context.
- Owner: liboyang42-cpu.
- Coordinator: Claude, the Claude Code session that writes these briefs.
- **All three repos are PUBLIC: never commit secrets, tokens, passwords or mini-program screenshots.**

## 1. What we are building
- **The product:** 城瘾 (Chengyin; code name Questify) is a city-exploration and story-game app.
  - Players walk real routes (topics and activities), solve station games, and collect stamps and points.
  - Clubs, merchants and creators publish and operate content.
  - 积分 (points) is the only currency. Real money stays TEST-only until the owner says "money on".
- **The base and source of truth:** the WeChat **mini-program (MP)**. It is at `liboyang42-cpu/hengyin`, folder `chengyinhub-xcx` (app.json has about 177 pages).
  - The iOS app must have **every MP function**, with the same backend contracts, states and copy.
  - Owner rulings and the owner's Figma win over the MP where they differ.
- **The iOS app:** `liboyang42-cpu/chengyin-app`, the SwiftUI `ui/*` branches (Xcode project `Questify.xcodeproj`, schemes `Questify` and `QuestifyAppUnitTests`, Swift package `QuestifyCore` for Core tests). The repo's `main` branch is an OLD Flutter app; ignore it.
- **The retired app:** `liboyang42-cpu/chengyin-ios` is another developer's copy of the same SwiftUI app. It split from ours on 2026-10-13. Its good parts are being ported in (port packages P1–P6), and then it will be deleted.
- **The backend:** Java/Spring in `hengyin`.
  - **TEST:** `https://8120-agqyfqxs5vwolymtoibzq3fhde.instabox.tech` (DB cy_e2e_r2).
  - **Production:** `https://www.chengyinhub.com/prod-api`. Prod runs hengyin `master`. No prod writes without the owner.

## 2. Where things stand (2026-11-24)
- **`ui/combined-r6`** (f1115875e) is the current verified base. It holds:
  - the redesign, City Monopoly, the type and chrome sweeps;
  - parity-fix rounds 1 and 2: Core has 27 known failures, AppUnit 70, the contract ratchet has 185 against a baseline of 184, with 0 new failures.
- **Mini-program parity on the 11-21 audit:** member 57%, merchant 53%, club 55%, player 80%, play/roam 66%. About 270 fixes followed in round 1, and more in round 2.
  - The audits are in `origin/audit/parity-<area>:docs/audit/parity/<area>.md`. The chengyin-ios audits are in `origin/audit/ios-parity-<area>`.
- **Owner decision, 11-24: NATIVE iOS STYLE.**
  - Use system List/Form/sheets/ContentUnavailableView, system navigation and back, and semantic Dynamic Type.
  - Keep the MP content, functions, colours and accent.
  - The details are in `design/handoff-r2:docs/briefs/port-packages-r1.md`. A full restyle spec (P6a) is coming for owner approval. Until it is approved, apply the rule to the code you write. Don't restyle screens outside your package.
- **Other open work:**
  - backend items in `docs/release/backend-needed-r6.md`;
  - owner gate decisions (platform-pass reads, refunds, merchant approvals);
  - TestFlight upload, done by the owner.

## 3. The current wave: port packages
- Plan: `port/plan-r1:docs/port/ios-port-plan.md`.
- Shared brief: `design/handoff-r2:docs/briefs/port-packages-r1.md`.

Packages:
- **P1** story/cast/roles: Cursor → `port/p1-story-cast`
- **P2** play runtime: Cursor → `port/p2-play-runtime`
- **P4** game kits: Cursor → `port/p4-game-kits`
- **P3** route detail: Claude cloud → `port/p3-route-detail`
- **P5** contract fixes + owner rulings: Gemini → `port/p5-contracts`
- **P6a** native-iOS design spec (no code): Claude → `design/native-ios-r1`
- **P6b** archive of chengyin-ios: Claude → `port/p6-archive`

Each package OWNS its files (plan §4); touch nothing else. Anything outside your files goes through mount hooks.

## 4. Acceptance: you verify your own work in the cloud
You don't need anyone's Mac. Every push to `port/**` runs the **Acceptance** workflow on GitHub's macOS runners (`.github/workflows/acceptance.yml`, once it lands). You can also start it by hand with `gh workflow run acceptance.yml --ref <branch>`.

**What it does:**
1. Builds the app (Debug, simulator).
2. Runs `tools/check_scaffold.py`, `tools/check_typography_lint.py` and `tools/contract_ratchet.py --check`.
3. Runs the Core `swift test` and the AppUnit shards.
4. Compares the failures with the baseline lists in `docs/release/baselines/`. **Any NEW failure fails the run.**
5. Launches the app on a simulator with DEBUG fixtures and takes screenshots of the screens your package lists in `docs/port/accept/<pkg>.txt` (one fixture route per line).
6. Uploads screenshots, logs and xcresult as artifacts.

**Your loop:** push → read the run (`gh run view --log-failed`, or download the artifacts) → fix → push again, until it is green with no new failures. Then:
- check your screenshots against the MP page (read the MP .wxml/.js) and the native-iOS rule;
- write the acceptance section of your receipt: run URL, gate counts, screenshot list, and MP functions checked present / missing.

A package is DONE only when its acceptance run is green and the receipt is complete.

## 4b. Priority order (owner, 2026-11-24): Claude → Cursor → Gemini
- Critical and large work goes to Claude first, then Cursor, then Gemini.
- If two workers touch the same file or disagree on an approach, the higher-priority worker's version wins. The lower-priority worker rebases onto it.
- The coordinator (Claude) owns integration (`ui/combined-r7`, rolling: each branch is merged as soon as its acceptance run is green) and the FINAL acceptance.

## 5. Rules (all workers)
- **Base** `origin/ui/combined-r6`.
- **Never push** main, master, ui/main or ui/combined-*. No force-push to another worker's branch.
- **No deploys.** No production writes. Money stays TEST-only.
- **No secrets** in files or logs. No mini-program screenshots in the repo. No ledger or gitleaks-allowlist changes.
- **Strings:** add them to `docs/port/strings/<pkg>.json`. Don't edit `Localizable.xcstrings`, `project.pbxproj` or `tools/current_ci_manifest.json` (the integrator regenerates them).
- **Push** at least every 2 hours. If you are stopped, push first.
- **Report** in Slack `#chengyin-rc`: one line when you start; one line with the branch, SHA and acceptance-run URL when you finish.
- **Commit trailer:** your own (Cursor, Gemini or Claude).

## 6. Integration (after acceptance)
The coordinator merges the packages into `ui/combined-r7` in this order: P1 → P4 → P2 → P3 → P5 → P6. After each merge it merges strings, regenerates the project, re-runs acceptance on the merge, and then runs a parity re-audit against the MP.

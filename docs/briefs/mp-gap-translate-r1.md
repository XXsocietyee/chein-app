# MP gap translate r1: find what the mini-program has that the app lacks, and translate it (owner, 2026-11-24)

Owner: "Compare what features the mini-program has that the app doesn't. Copy the mini-program's code and then translate it." Worker: Gemini, via Orca.

Read `git show origin/design/handoff-r2:docs/briefs/WORKERS-HANDBOOK.md` first, especially the native iOS rule and the rules section.

## Sources
- **MP:** `liboyang42-cpu/hengyin`, folder `chengyinhub-xcx` (pages `.wxml`/`.js`/`.wxss`/`.json`, components, and the `api/` request modules).
- **App:** `liboyang42-cpu/chengyin-app` at `origin/ui/combined-r6`.
- **What's already known to be missing:**
  - round-1 audits: `origin/audit/parity-<area>:docs/audit/parity/<area>.md`;
  - fix receipts: `docs/release/receipts/fix-parity-<area>.md` and `fix-parity2-<area>.md` on `ui/combined-r6`. Items still open are marked deferred, partial or blocked.

## Step 1: gap inventory (first 60–90 minutes; push it early)
For your half's areas, write `docs/mp-gap/<area>.md` with every MP function that `ui/combined-r6` still lacks. Each entry gives:
- the MP page and file:line;
- what the function does;
- the API calls (path and params);
- the app screen where it belongs (or "no screen");
- the type: NEW-SCREEN, NEW-SECTION or NEW-ACTION;
- a size: S, M or L.

Exclude anything a running package already covers:
- **port packages:** the P1–P5 clusters in `port/plan-r1:docs/port/ios-port-plan.md` §2.2;
- **restyle** (visual only);
- **Cursor C2** (the Core wiring for backend-needed §2).

## Step 2: translate, the largest gaps first
- **Read the MP code** (wxml structure, js logic and api calls) and **translate it to SwiftUI + Core**, following the native iOS rule: system List/Form/sheets/ContentUnavailableView, system back, Dynamic Type.
  - Reuse the existing Core clients and contracts where the endpoint is already wired; add new contract types in NEW Core files where it is not.
  - Keep the MP Chinese copy exactly. Put strings in `docs/port/strings/gap-<half>.json`.
- **File ownership: NEW FILES ONLY.**
  - `App/MPGap/<Area>/*.swift`, `Core/MPGap/<Area>/*.swift`, `Tests/CoreTests/MPGap/*`.
  - Never edit an existing file: restyle and port agents own them.
  - To show a new screen or action in an existing screen, write a **mount hook** (a public View or a `NavigationLink` value) in your new file. List it in `docs/mp-gap/mounts-<half>.md` (target file + where + code); the coordinator mounts them at integration.
- **Money flows:** TEST-only and behind the existing gates; do not open them.
- **Owner-gated items:** platform-pass, refunds and merchant approvals. Translate the UI, but leave the action gated and list it.

## Verify
- Do NOT build or run tests on the Mac: its disk is nearly full.
- Push and verify through the cloud acceptance workflow once `.github/workflows/acceptance.yml` exists (`gh workflow run acceptance.yml --ref <branch>`). Until then, keep the code simple and reuse existing types. Run `swiftc -parse` on new files if swiftc is available without a build.

## Halves and branches
| half | areas | branch |
|---|---|---|
| G1 player | player-content, play-roam, member | `gap/g1-player` |
| G2 ops | club, merchant-coop, account-publish | `gap/g2-ops` |

**Base** `origin/ui/combined-r6`. **Receipt** `docs/release/receipts/gap-<half>.md`:
- the gaps found, translated and left (with reasons);
- the mount list;
- the acceptance run URL.

Push at least every hour. Commit trailer `Co-Authored-By: Gemini <noreply@google.com>`. The repo is PUBLIC: no secrets and no MP screenshots.

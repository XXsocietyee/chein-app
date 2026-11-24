# Port packages r1: shared brief for P1–P6 (owner, 2026-11-24)

**Owner decisions:**
- chengyin-app is the official iOS app. The good parts of chengyin-ios are ported in, and then chengyin-ios is retired.
- **Native iOS style:** "I need the native iOS style." This replaces the old "MP rpx ÷ 2" visual rule.
- The repo is now PUBLIC. Never commit secrets, tokens or MP screenshots.

## Read first
- The plan: `git show origin/port/plan-r1:docs/port/ios-port-plan.md`. Read all of it, especially §2.2 (per-cluster sources, targets and approach), §3 (shared rules) and §4 (your package: owned files, clusters, mount hooks and order).
- Source: chengyin-ios `origin/main` (a5c863e) plus the branches the plan names. Clone https://github.com/liboyang42-cpu/chengyin-ios if it is not already checked out.
- **BASE:** `origin/ui/combined-r6` (f1115875e), which is combined-r5 plus all the parity-r2 fixes and is verified, with 0 new failures. Branch name: `port/<pkg>` (below).

## Native iOS style rule (applies to every line of UI you write or touch)
- **Use system components:**
  - `List` / `Form` (`.insetGrouped`) for settings-like and detail pages;
  - `ContentUnavailableView` for empty and error states;
  - `NavigationStack` titles and the **system back** (no custom chevrons; `cyGuardedBack` only for unsaved edits);
  - standard sheets with `.presentationDetents`;
  - system buttons (`.borderedProminent` / `.bordered`).
- **Use semantic Dynamic Type text styles:** `.font(.body/.headline/.subheadline/.footnote/.caption…)`, or `.cyText(.token)` where the token maps to a text style.
  - No `.font(.system(size:))` for text, and no static `.font(CYTypography.x)` in new code.
  - Nothing smaller than `.caption`.
  - Use `.monospacedDigit()` for numbers.
- **Keep the MP content, functions, copy, colours and accent, and the backend contracts.** Take layout calmness from chengyin-ios (`docs/native-design-and-motion.md` in chengyin-ios is the reference). Keep our `CYMotion` and `CYInPlaceResult`, and respect Reduce Motion.
- Use one radius set (12 for cards, 20 for heroes) and 16 pt margins.

## How to port (plan §0.4)
- Cherry-pick does not work as the main path. Copy the plan's NEW files verbatim, then adapt them: their types become our types, and their deployment and capability gate becomes our `ChinaReviewedRouteCapability` (P2 owns that file; send route rows to P2 in your PR body).
- Re-implement the hunks in shared files by hand on our code.
- Port their tests with the code.
- Strings go into `docs/port/strings/<pkg>.json` (key → zh-Hans / en). The integrator merges them into `Localizable.xcstrings`.
- Do NOT edit `project.pbxproj` or `tools/current_ci_manifest.json`. The integrator regenerates them.
- **Stay inside your package's owned files.** A file you need that another package owns gets a "mount hook": a small public view or function in YOUR file, which the owner mounts later.

## Packages
| pkg | branch | worker |
|---|---|---|
| P1 story reader + cast + roles | `port/p1-story-cast` | Cursor |
| P2 play runtime (arrival, free-explore, images, photo record) | `port/p2-play-runtime` | Cursor |
| P4 game-page kits (pool, ladder extras, stage header) | `port/p4-game-kits` | Cursor |
| P3 route detail (chapter cards, 出发前, totalTime seconds fix) | `port/p3-route-detail` | Claude cloud |
| P5 small contract fixes + owner rulings (one-decimal money pending the owner's confirmation: implement it behind one `MoneyDisplay` switch) | `port/p5-contracts` | Claude cloud (reassigned from Gemini) |
| P6a native-iOS restyle **design spec** (NO code; see below) | `design/native-ios-r1` | Claude cloud |
| P6b archive of chengyin-ios unique docs, branches and rulings (plan §5) | `port/p6-archive` | Claude cloud |

**P6a** is a design spec. Code waits for the owner's approval.
- Write `docs/design/native-ios-r1.md`. It covers the token mapping (text styles, colours, radii, spacing), the component rules (list/form/sheet/empty/error/button/nav) and before/after for the 12 most-used screens. Base the before/after on our current views and chengyin-ios's equivalents, with SwiftUI snippets.
- Include the migration plan for the screen sweep: batches of ≤ 40 files, using the `codemod_typography.py` and `report_chrome.py` tools, and the lint updates (`check_typography_lint.py` must flag `.system(size:)` text and `CYTypography` statics in views).

## Done means
- Your branch is pushed.
- You have a receipt at `docs/release/receipts/port-<pkg>.md`. It lists:
  - the clusters done;
  - the files copied and the files adapted;
  - the tests ported;
  - the mount hooks provided or needed;
  - the route rows for P2;
  - the strings file;
  - what you could not do and why.
- Cloud agents have no Swift compiler. Parse-check with `swiftc -parse` when it is available, reuse existing types, and avoid long expressions. A local integrator compiles.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Cursor and Gemini use their own trailer.

## Rules
- Never push main, master, ui/main or ui/combined-*. No deploys.
- No secrets, tokens or MP screenshots (the repo is public).
- No ledger or gitleaks changes. Money stays TEST-only.
- Push at least every 2 hours. If you are stopped, push first.

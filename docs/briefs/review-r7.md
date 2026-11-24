# Code review r7: review the merged work against the mini-program (owner, 2026-11-24)

The owner wants reviewers working alongside the builders. You are a REVIEWER: read and judge; don't edit product code. Read `git show origin/design/handoff-r2:docs/briefs/WORKERS-HANDBOOK.md` first.

## What to review (diff against `origin/ui/combined-r6`)
- **REV-A, play runtime (Cursor):**
  - `port/p1-story-cast`, `port/p2-play-runtime`, `port/p4-game-kits`;
  - `cursor/r7-wiring` if it exists.
- **REV-B, contracts, route detail and gates:**
  - `port/p3-route-detail`, `port/p5-contracts`;
  - `cursor/core-wiring-r6`, `cursor/r7-gates`;
  - the integration commits on `ui/combined-r7`.
- **REV-C, Gemini's MP translations:** `gap/g1-player`, `gap/g2-ops` (`Core/MPGap`, `App/MPGap`) and `docs/mp-gap/*`.

## Check each changed function against the MP source (`hengyin/chengyinhub-xcx`)
1. **Contract:** the same endpoint, method, params, response fields, error codes and state handling as the MP's api call (cite the MP file:line).
2. **Behaviour:** the same user flow, validation, empty, error and no-permission states, and navigation targets as the MP page.
3. **Correctness:** compile-risk patterns. Examples:
   - APIs that don't exist on `origin/ui/combined-r7` (grep for every type, case or initializer used);
   - optional misuse;
   - actor-isolation and Sendable mistakes;
   - force unwraps on server data;
   - duplicate keys.
4. **Safety:**
   - money stays TEST-only;
   - new gates default off;
   - no secrets;
   - no weakened auth or ownership checks;
   - no test assertion weakened just to pass.
5. **Native iOS rule:** system navigation and back, List/Form, ContentUnavailableView, semantic text styles, nothing below `.caption`.
6. **MP assets:** wherever the MP shows a brand, feature or category icon, a logo, a badge, an illustration or a default image, does the app show the same asset? Note SF Symbols or other images used instead.

## Output
- Write `docs/review/r7-<rev>.md` on branch `review/r7-<rev>` from `origin/ui/combined-r7`, and push.
- **Findings table:** id | severity (P0 = broken function, wrong contract, compile error or safety; P1 = missing state or behaviour gap; P2 = polish) | file:line | MP file:line | problem | exact fix | owner (Cursor / Gemini / Claude / owner).
- Sort P0 first. Push within 90 minutes; then continue and push every 30 minutes.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. The repo is PUBLIC: no MP screenshots and no secrets.

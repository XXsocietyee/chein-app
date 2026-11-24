# Acceptance kit r1: the MP checklist + Maestro flows for the final acceptance (owner, 2026-11-24)

The coordinator (Claude) runs the FINAL acceptance of `ui/combined-r7` today. Your job is to build the kit that acceptance runs on. Read `git show origin/design/handoff-r2:docs/briefs/WORKERS-HANDBOOK.md` first.

## Scope (disjoint from every other package)
You own ONLY these:
- `docs/accept/mp-checklist/<area>.md`
- `e2e/maestro/accept/<area>/*.yaml`
- `docs/release/receipts/accept-kit-<half>.md`

Don't touch App/, Core/, Tests/ or any other e2e folder.

| half | areas (the same six as the parity audits) | branch |
|---|---|---|
| A (player) | player-content, play-roam, member | `accept/kit-a-player` |
| B (ops) | club, merchant-coop, account-publish | `accept/kit-b-ops` |

## 1. The MP checklist, one file per area
- **Source:** the MP at `/home/user/hengyin/chengyinhub-xcx`. The page lists are in the parity audits: `origin/audit/parity-<area>:docs/audit/parity/<area>.md`.
- **For EVERY MP page, list:**
  - the app screen and its fixture route (find them with `grep` in `App/` on `origin/ui/combined-r6` and in `docs/port/accept/*.txt` on the port branches);
  - every user-visible function, as a checkable line: element / action → expected result, with the MP file:line;
  - the states to check: loading, empty, error, not signed in, no permission;
  - the key MP copy;
  - the native-iOS visual checks: system back and title, Dynamic Type, list/form structure, ContentUnavailableView for empty and error states.
- **Mark each line** `auto` (covered by a Maestro flow) or `manual` (needs a screenshot or a TEST account), and keep the P0 lines first.

## 2. Maestro flows
- For each area, write flows under `e2e/maestro/accept/<area>/` that launch the app (`appId: invalid.example.questify.ios`) and open screens through DEBUG fixture routes or deep links. Look at the existing flows in `.maestro/` and `e2e/` and at the fixture launch arguments in the app (`grep -rn "fixture" App/ | head`).
- Assert visible text and IDs and take screenshots (`takeScreenshot`). Cover every `auto` line.
- Keep each flow under 2 minutes, with one flow per MP page or a small group of pages.
- Validate the syntax with `maestro check-syntax` if it is available; otherwise keep to documented commands only (https://docs.maestro.dev).

## Done means
- Branch pushed. The receipt lists, per area: the pages, the `auto` and `manual` line counts, the flows, and the known gaps (pages with no fixture route).
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- The repo is PUBLIC: no secrets, no TEST passwords, no MP screenshots. Use placeholders like `${TEST_USER}` for accounts.

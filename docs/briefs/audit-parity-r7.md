# Parity audit on ui/combined-r7: where the merged app stands against the mini-program (owner, 2026-11-24)

The owner wants the app optimized and checked against the mini-program, in parallel with the remaining port work. You are a REVIEWER: read-only on product code.

## Sources
- **App:** `liboyang42-cpu/chengyin-app` at `origin/ui/combined-r7`. It holds combined-r6, the P1–P5 ports, the C1 gallery, the C2 Core wiring and Gemini's MPGap Core.
  - Gemini's screens in `App/MPGap` are parked: they are not compiled yet.
  - Restyle branches `restyle/r*` are in progress (round 2) and not merged yet.
- **Mini-program:** `hengyin/chengyinhub-xcx`.
- **Earlier audits:**
  - round 1: `origin/audit/parity-<area>:docs/audit/parity/<area>.md`;
  - the chengyin-ios audit: `origin/audit/ios-parity-<area>`;
  - Gemini's gap lists: `origin/gap/g1-player` and `origin/gap/g2-ops`, `docs/mp-gap/*.md`.
- **Context:** read `git show origin/design/handoff-r2:docs/briefs/WORKERS-HANDBOOK.md` first.

## For EVERY MP page in your area
- Re-check each function line from the round-1 audit against r7: present, different, missing, or present only in an unmerged branch (name the branch).
- Count parity as functions present / total, and compare it with round 1.
- List every remaining gap as a FIX-QUEUE line:
  - id | MP file:line | app file:line or none | what to do | size S/M/L;
  - an owner:
    - **Cursor** (Core logic or contracts),
    - **Claude** (App/ UI, structure or copy, native-iOS rule),
    - **Gemini** (whole missing feature translated from MP code),
    - **owner** (decision or backend).
- Do NOT list items an in-flight branch already covers. Check `port/*`, `restyle/*`, `gap/*`, `cursor/*` and `accept/*` first, and note the branch instead.

## Output
- `docs/audit/parity-r7/<area>.md` on a new branch `audit/parity-r7-<area>` from `origin/ui/combined-r7`. Push within 2 hours; push early and often.
- **Contents:**
  - a summary table: page, round-1 %, r7 %, P0, P1;
  - the area totals;
  - the FIX QUEUE, sorted P0 first and grouped by owner;
  - a five-line verdict.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- The repo is PUBLIC: no MP screenshots and no secrets.

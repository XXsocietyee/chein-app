# Coordinator handover: how to keep going without me

This is the live state of the chengyin-app go-live push and the exact steps to continue it. It is updated on every hourly and half-hourly check. If Claude (the coordinator) is out of credit, anyone (a person, Cursor, Gemini or another Claude) can pick up from here.

**Last updated:** 2026-11-25 06:24 UTC by Claude (coordinator).

---

## 1. Where things are right now

| Item | Value |
|---|---|
| Product | Native SwiftUI iOS app with full mini-program (MP) parity. Repo `liboyang42-cpu/chengyin-app` (PUBLIC), branches `ui/*`. |
| Integration branch | `ui/combined-r7`. Last pushed and built clean: **`7bd1c0ee1`** (adds Cursor k7e-fixes, ratchet-1 [AppSession 7994], cov4-tests-2). |
| MP source | `liboyang42-cpu/hengyin`, folder `chengyinhub-xcx` (the mini-program). |
| Parity (r8 audit, 01:55 UTC) | member 85% · account-publish 86% · merchant 77% · club 77% · player-content 91% · play-roam 98%. Reports: `origin/audit/parity-r8-<area>:docs/audit/parity-r8/<area>.md`. |
| Acceptance | Runner `fanning-air-5`, branch `ci/acceptance`. Baselines Core 27, AppUnit 71, contract 1. K7e on 6afe54b4a failed on **infrastructure** (GitHub SSL during git fetch, sim 405 already-booted, POSIX 3 terminate), not code; Cursor is hardening the workflow. CHECK on ebf6c160c queued (run 45557373770). |
| MP contract coverage | Checker (06:10): total 1038, matched 802, missing endpoint 115, missing test 232. Per area on ebf6c160c (matched/endpoint/test): member 103/21/52, account-publish 84/11/27, merchant-coop 134/20/38, club 109/6/14, player-content 183/21/40, play-roam 128/15/26. |
| Money | All money writes (pay, refund, payout, withdrawal, paid orders) stay **TEST-only** until the owner says "money on". |

## 2. Owner rules (binding)

- **MP-first** (`owner-decisions-1124.md` §MP-first): anything the MP does, the app does the same way. It is NOT an owner decision. Only money stays gated. Ask the owner only if the MP lacks the feature or it truly can't work (cite MP file:line).
- **Native iOS style:** system List/Form/sheets, ContentUnavailableView, Dynamic Type, nothing below `.caption`. MP icons, logos and images must be identical (`App/MPAssets/MPAsset.swift`, `docs/mp-assets/mapping.md`).
- **Workers:**
  - Claude: cloud routines, plus the coordinator.
  - Cursor: Slack `#chengyin-rc`, thread `1795516369.184329`, mention `@Cursor`.
  - Gemini: Orca `orca agent launch --agent antigravity`.
- **Parallel, never idle:** give Cursor a new batch the moment it posts "No new task".
- **Never:**
  - push `main`, `ui/main`, or other people's branches;
  - put secrets or MP screenshots in the repo (it's public);
  - deploy to production without the owner;
  - push to chengyin-ios (it is to be archived after the other developer freezes it).

## 3. Who is working on what (as of last update)

**Cursor round 7** (re-posted 04:10 UTC with SHA `f95850a46`):
- **Merged:** A1, A2-a, A2-c, q9c-composition, r8-merchant-coop, r8-play-roam, r8-club, r8-account-publish, r8-member.
- **Merged in `6afe54b4a`:** a2-contract-b/d, r8-player-content, r8-wire. a3 goes to `ci/acceptance`.
- **Merged in `08792c15b`:** cov3-c, cov3-d. **Running:** K7e CHECK (run 45550995140, queued behind 45545406477), r8-wire-2, cov3-a/b, cov3-tests-1..4; then cov3-e (checker: forwarded-url/ternary rows count as matched-indirect).
- **Merged by 06:24:** k7e-fixes, ratchet-1, cov4-tests-2. **Running:** cov3-e, cov4-tests-1/3/4, CHECK 45557373770, acceptance-hardening (on `ci/acceptance`).
- **Batch posted 05:50 (base `ebf6c160c`):** K7e, cov3-e (checker indirect-match rule), cov4-tests-1..4 (remaining ~250 missing tests by area), ratchet-1 (AppSession −300 lines), r9-prep (per-area checker table).
- **Posted 05:02:** K7e CHECK on `6afe54b4a`; r8-wire-2; Phase C `cursor/cov3-a..d` (missing endpoints) and `cursor/cov3-tests-1..4` (P0 missing tests).

**Claude cloud routines** (claude.ai/code/routines):
- **Phase B is done**: every round-4/r8/R5/R6 Claude branch is merged.
- **Phase D started 06:19:** 6 × `cloud AUDIT r9 · <area>` → `audit/parity-r9-<area>:docs/audit/parity-r9/<area>.md` (brief `audit-parity-r9.md`). When they push (~07:20): split each fix queue into Claude App routines (`fix/r9-<area>-<a|b>`) and post the Cursor Core rows in the Cursor thread.

**Gemini:** relaunched 06:20 via `orca agent launch --agent antigravity` in DES-ag3 on `gemini/mp-assets-r9` (MP images byte-identical: map every MP image to MPAsset, receipt `docs/release/receipts/gemini-mp-assets-r9.md`). No local builds.

## 4. How to integrate (the coordinator's loop)

Work in the worktree `/Users/fanning/orca/workspaces/native-ios/DES-ag6` on `ui/combined-r7`. Use **bash, not zsh**, for loops: zsh's `$b:r` modifier and unquoted arrays break refspecs.

1. **Fetch branches explicitly** (the remote fetch refspec is narrow): `git fetch origin "+refs/heads/<b>:refs/remotes/origin/<b>"`.
2. **Merge one branch at a time.** On a conflict, abort it and send it back to its owner ("rebase onto origin/ui/combined-r7 <sha>"); don't hand-mix both sides. Mixed sides caused most of the compile errors.
3. **Regenerate:**
   - `python3 tools/build_page_route_table.py`
   - `python3 tools/generate_project.py`
   - Merge string fragments from `docs/port/strings/*.json` into `Resources/Localizable.xcstrings` with `python3 -B tools/merge_localization_fragments.py <fragment>`. Fragments must be xcstrings-shaped (`{sourceLanguage, strings:{key:{localizations:{en,zh-Hans}}}, version}`). Plain `{en, zh-Hans}` maps need wrapping. Add only missing keys.
3b. **`Localizable.xcstrings` conflicts:** take the union of keys (ours wins on overlap), keep the existing key order and append new keys, write with `json.dumps(indent=2, ensure_ascii=False)`. Re-sorting or Xcode's ` : ` separator rewrites the whole file.
4. **Gate:** `python3 tools/check_scaffold.py` must print `PASS structural checks`. Frequent failures:
   - **`String(localized: "literal")`:** use `appLocalized("key", locale: locale)` (or `Locale.current` in static code).
   - **Interpolated `LocalizedStringKey("a.\(x)")`:** use concatenation.
   - **A missing catalog key:** add it via a fragment.
   - **A raw hex colour in App/:** use a design token; if it's payload data, build the string without a literal `#`.
   - **Glue-file ratchet** (`tools/check_appsession_ratchet.py`): AppSession 8171, AppCompositionRoot 4177 (q9c lowered it). Raise it temporarily only, and assign the extraction to Cursor.
5. **Build:** XcodeBuildMCP `build_sim`. Session defaults:
   - projectPath `DES-ag6/Questify.xcodeproj`, scheme `Questify`, simulator `2337B386-AC5F-4417-B8B8-012A8DB888BD`;
   - extraArgs `OTHER_SWIFT_FLAGS=$(inherited) -disable-sandbox`, `ARCHS=arm64`, `ONLY_ACTIVE_ARCH=YES`.

   "note: …locationManager…" lines are notes, not errors. Common cloud-agent compile errors:
   - generic static access (`Type<Placeholder>.method`);
   - duplicate type names across files;
   - a local var shadowing a method (`self.method`);
   - inout across `await`;
   - memberwise-init argument order;
   - Image-only modifiers after `.accessibilityHidden`;
   - new enum cases not handled in an existing `switch`;
   - tuple patterns that change length.
6. **Commit** with trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`, then `git push origin ui/combined-r7`. **Post the new SHA** in the Cursor Slack thread so every lane rebases onto it.

## 5. Recurring checks

- **:07 hourly and :37 half-hourly:**
  - read the Cursor thread;
  - accept or fix landed branches;
  - merge, build and push;
  - assign the next batch;
  - list the routines (`RemoteTrigger list` / `list_runs`) and start new rounds for finished ones;
  - report to the owner in ≤ 6 lines.
- **New cloud routine:**
  - `RemoteTrigger create` with `run_once_at`, env `env_01Hv5QHDiUzfDHqc59bWLxK4`, model `claude-opus-5-5`, sources chengyin-app + hengyin;
  - then `update {"clear_mcp_connections": true}`;
  - after a 429, wait about 1 s and retry.

## 6. Open owner items

1. The other developer must freeze chengyin-ios; then archive it (not delete).
2. Register the second test runner: `docs/release/runner-2-setup.md` on `cursor/runner-2`.
3. Keep the Mac awake (`caffeinate -dims`) so builds and acceptance keep running.
4. "Money on": not yet.
5. TestFlight: when acceptance is green.

## 8. Plan to complete the entire app

The finish line: every MP feature works in the app the way it does in the MP (non-money parity 100% in all 6 areas), acceptance is green, and an internal TestFlight build is out. Money stays TEST-only until the owner says "money on". The phases overlap; a later phase starts as soon as its input exists.

| Phase | Goal | Who | Exit criteria | Estimate |
|---|---|---|---|---|
| **A. Acceptance green** | Fix the 37 contract failures and 2 Core compile errors from the last CHECK. | Cursor (A2 b/d, A3, K7e); coordinator merges. | K7e CHECK on the tip shows Core ≤ 27, AppUnit ≤ 71, contract ≤ 1 failures (the baselines), screenshot step passes. | ~2–3 h |
| **B. Close the r8 queues** | Fix every open r8 P0/P1 row. | Claude routines: 12 × F round 4 (`fix/r3-*`), 6 × `fix/r8-<area>`, `fix/r8-mp-first`. Cursor: Core rows + `r8-wire`. | Each r8 report row is marked fixed with a SHA; the 5 conflicting Claude branches are re-merged onto the tip. | ~4–6 h |
| **C. Contract coverage** | Every MP request the app needs has an endpoint and a test. Now: 1038 total, 423 matched, 130 missing endpoint, 611 missing test. | Cursor (Core endpoints + tests); Claude routines (cov lanes per area); Gemini after its quota reset (~05:50 UTC) on test-only lanes. | Missing endpoint = 0 (or cited "MP-only, not used"); missing test < 200, then 0 for P0 flows. | ~6–8 h, parallel with B |
| **D. r9 re-audit + fix rounds** | Measure again and close what is left. | 6 Claude audit routines (`audit/parity-r9-<area>`), then one fix routine per area per round. | Every area at 100% non-money parity; no P0/P1 rows open. Repeat audit → fix until true (expect 1–2 rounds). | ~6–8 h |
| **E. Release** | Ship to testers. | Coordinator + owner. | Acceptance green on the release SHA → internal TestFlight (owner OK'd "TestFlight when green"). Then: archive chengyin-ios after the other developer freezes it; "money on" only when the owner says so. | ~1 h after D |

**Total:** about 90% in every area ~8 h from 04:00 UTC; ~100% non-money parity ~18 h from 04:00 UTC, if the Mac stays awake and Cursor stays loaded.

**How each round runs (repeat until done):**
1. Each worker branches from the posted tip SHA and pushes its own branch (never the integration branch).
2. The coordinator merges one branch at a time (§4), runs the gate and build, pushes `ui/combined-r7`, and posts the new SHA in the Cursor thread.
3. Cursor runs the K7e CHECK on the new SHA and lists new failures in §7; failures go back to the branch owner.
4. When a routine finishes, start the next round for it with "continue on your branch from <SHA>" (each routine is one session).

**Bottlenecks and what we do about them:**
- **Serial integration** (one coordinator, 5–14 min builds): merge in batches of 3–5 clean branches; send conflicts back instead of hand-merging.
- **The Mac sleeping** (builds and the only acceptance runner stop): owner runs `caffeinate -dims`; registering runner-2 (§6.2) removes the single point.
- **Cursor missing thread posts:** re-post the full task list in one message at every :07 / :37 check.
- **Coordinator out of credit:** anyone can continue from this doc. Cursor can take the merge loop (§4) on `ui/combined-r7` if the owner allows it; until then, workers keep pushing their branches and they are merged when the coordinator is back.

**If you pick this up cold:** read §1 (tip), §3 (who does what), §7 (Cursor's lanes and acceptance), then run the loop in §4 starting with the phase in this table whose exit criteria are not met yet.

---

## 7. Cursor live status (maintained by Cursor)

**Rule for both editors:** edit only your own section (Claude: §1–§6; Cursor: §7). Before every edit: `git pull --rebase origin design/handoff-r2`. Commit small and push right away. On a push conflict, rebase again; never force-push.

| Lane | Branch | Base | Status | SHA | Notes |
|---|---|---|---|---|---|
| (Cursor fills this in) | | | | | |

**Acceptance (Cursor owns):** latest CHECK run, its SHA, and the new Core/AppUnit/contract failures by name.

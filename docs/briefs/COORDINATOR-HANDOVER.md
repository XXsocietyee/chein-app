# Coordinator handover: how to keep going without me

This is the live state of the chengyin-app go-live push and the exact steps to continue it. It is updated on every hourly and half-hourly check. If Claude (the coordinator) is out of credit, anyone (a person, Cursor, Gemini or another Claude) can pick up from here.

**Last updated:** 2026-11-25 03:48 UTC by Claude (coordinator).

---

## 1. Where things are right now

| Item | Value |
|---|---|
| Product | Native SwiftUI iOS app with full mini-program (MP) parity. Repo `liboyang42-cpu/chengyin-app` (PUBLIC), branches `ui/*`. |
| Integration branch | `ui/combined-r7`. Last pushed and built clean: **`b7771abb4`** (+ cursor/r8-member, A1 Core test compile fix). |
| MP source | `liboyang42-cpu/hengyin`, folder `chengyinhub-xcx` (the mini-program). |
| Parity (r8 audit, 01:55 UTC) | member 85% · account-publish 86% · merchant 77% · club 77% · player-content 91% · play-roam 98%. Reports: `origin/audit/parity-r8-<area>:docs/audit/parity-r8/<area>.md`. |
| Acceptance | Runs on the self-hosted runner `fanning-air-5` (owner's Mac), branch `ci/acceptance`. Baselines: Core 27, AppUnit 71, contract 1. The last CHECK (on `0e1cf578a`) found **37 new contract failures + 2 Core test compile errors**; Cursor round 7 fixes them. |
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

**Cursor round 7** (posted 03:47 UTC):
- **A1:** Core test compile fixes.
- **A2:** the 37 contract failures.
- **A3:** screenshot step retry.
- **K7e:** CHECK on the next SHA.
- **r8-wire:** App call sites.
- **Pending:** rebase `cursor/r8-{merchant-coop,play-roam,club,player-content,account-publish}` and `cursor/q9c-composition` onto `b5b9d9003` (they conflict with `fix/r8-mp-first`).

**Claude cloud routines** (claude.ai/code/routines):
- 12 × `cloud FIX r3 R4 · <area> a|b`: branches `fix/r3-<area>-<a|b>`; flows, images, copy.
- 6 × `cloud FIX r8 · <area>`: branches `fix/r8-<area>`; r8 Claude-App rows.
- 1 × `cloud FIX r8 · MP-first gates`: branch `fix/r8-mp-first`.
- **Not yet merged (conflicts; the agents re-merge the base):** `fix/r8-club`, `fix/r3-member-a`, `fix/r3-play-roam-a`, `fix/r3-player-content-b`, `fix/r8-player-content`.

**Gemini:** down. Orca restarted and lost its terminals; the quota resets about 05:50 UTC. Its MP-alignment work moved to the Claude F-agents (`fix-r3-round4.md`).

## 4. How to integrate (the coordinator's loop)

Work in the worktree `/Users/fanning/orca/workspaces/native-ios/DES-ag6` on `ui/combined-r7`. Use **bash, not zsh**, for loops: zsh's `$b:r` modifier and unquoted arrays break refspecs.

1. **Fetch branches explicitly** (the remote fetch refspec is narrow): `git fetch origin "+refs/heads/<b>:refs/remotes/origin/<b>"`.
2. **Merge one branch at a time.** On a conflict, abort it and send it back to its owner ("rebase onto origin/ui/combined-r7 <sha>"); don't hand-mix both sides. Mixed sides caused most of the compile errors.
3. **Regenerate:**
   - `python3 tools/build_page_route_table.py`
   - `python3 tools/generate_project.py`
   - Merge string fragments from `docs/port/strings/*.json` into `Resources/Localizable.xcstrings` with `python3 -B tools/merge_localization_fragments.py <fragment>`. Fragments must be xcstrings-shaped (`{sourceLanguage, strings:{key:{localizations:{en,zh-Hans}}}, version}`). Plain `{en, zh-Hans}` maps need wrapping. Add only missing keys.
4. **Gate:** `python3 tools/check_scaffold.py` must print `PASS structural checks`. Frequent failures:
   - **`String(localized: "literal")`:** use `appLocalized("key", locale: locale)` (or `Locale.current` in static code).
   - **Interpolated `LocalizedStringKey("a.\(x)")`:** use concatenation.
   - **A missing catalog key:** add it via a fragment.
   - **A raw hex colour in App/:** use a design token; if it's payload data, build the string without a literal `#`.
   - **Glue-file ratchet** (`tools/check_appsession_ratchet.py`): AppSession 8171, AppCompositionRoot 4184. Raise it temporarily only, and assign the extraction to Cursor.
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

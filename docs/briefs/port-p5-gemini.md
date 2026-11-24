# Port package P5 (owner reassigned it from Gemini to a Claude cloud agent on 2026-11-24): small contract fixes + owner rulings

You run as a cloud agent. Work only from GitHub. All the repos are public.

1. Clone https://github.com/liboyang42-cpu/chengyin-app and https://github.com/liboyang42-cpu/chengyin-ios.
2. In chengyin-app, run `git fetch origin design/handoff-r2 port/plan-r1 ui/combined-r6`. Then read, in order:
   - `git show origin/design/handoff-r2:docs/briefs/WORKERS-HANDBOOK.md`: the complete picture. Follow it.
   - `git show origin/design/handoff-r2:docs/briefs/port-packages-r1.md`: the shared brief, including the NATIVE iOS STYLE rule.
   - `git show origin/port/plan-r1:docs/port/ios-port-plan.md`: §2.2 C7 rows OR-023, PG-006, MC-055, FE-G5, FE-G6; C15 ShopNPC; §3; §4 **P5**; §5 for the owner rulings on chengyin-ios branch `fix/owner-decisions-1122`.
3. Do package **P5**:
   - Base `origin/ui/combined-r6`, branch `port/p5-contracts`.
   - Own ONLY the files listed for P5 in plan §4.
   - **One-decimal money:** ONE shared `MoneyDisplay` formatter behind a single switch, defaulting to the current behaviour. The owner has not confirmed it yet.
   - **V-23:** the report entry is off.
4. Strings go into `docs/port/strings/p5.json`. Port the listed tests. Write `docs/port/accept/p5.txt` (fixture screens to screenshot).
5. **Acceptance in the cloud (handbook §4):** once `.github/workflows/acceptance.yml` exists, push and let it run, or run `gh workflow run acceptance.yml --ref port/p5-contracts`. Read the result and iterate until it is green with no new failures.
   - Until the workflow exists, make sure every changed Swift file passes `swiftc -parse` (if swiftc is available), and say so in the receipt.
6. **Receipt:** `docs/release/receipts/port-p5.md`. Push.

**Rules:** never push main, ui/main or ui/combined-*. No deploys. No secrets. Money stays TEST-only. Commit trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

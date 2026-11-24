# Backend r6: implement the server items the app needs (owner, 2026-11-24)

**Repo:** `liboyang42-cpu/hengyin` (Java/Spring, PUBLIC: no secrets). Read the app-side context first: `git -C /home/user/chengyin-app show origin/design/handoff-r2:docs/briefs/WORKERS-HANDBOOK.md`.

## Items
- **Source lists:**
  - `git -C /home/user/chengyin-app show origin/ui/combined-r6:docs/release/backend-needed-r6.md` §1;
  - the §1 leftovers of `origin/ui/combined-r5:docs/release/backend-needed-r5.md` that are NOT already done on hengyin `fix/be-parity-r1` (check that branch's commits and receipt first).
- **Known items:**
  - **CLB-customer-detail-06:** `summary.lastInteractionText` on `POST /api/club/crm/customers/detail`.
  - **JREPORT-5:** `reasonCode: "RUN_NOT_FOUND"` (or a consistent 404) on `GET /api/play/player-journey/report` for unknown or deleted runs.
  - plus any r5 leftovers.
- **Owner gate decisions are pending:** platform-pass reads, refunds, merchant approvals and money. Do NOT open those gates. Leave them as they are and list them.

## How
- **Branch:** `fix/be-needed-r6` from hengyin `fix/be-parity-r1` (so it stacks on it). If that branch doesn't build, start from `integration/backend-app-r3` and say so.
- **Code style:** follow the existing module patterns. Keep each change narrow, and keep the security scoping in place: no loosened auth or ownership checks.
- **Tests:** add a unit or integration test per item. Run the affected modules' tests with Maven (`LANG=C.UTF-8 LC_ALL=C.UTF-8`, `TZ=Asia/Shanghai`; use `mvn -o` if offline).
  - If Maven can't resolve dependencies in the cloud, say so in the receipt, list the tests you wrote, and keep the code compiling by inspection.
- **Receipt:** `qa/BE-NEEDED-R6.md`. Cover each item: endpoint, change, test, and the app file that consumes it (from backend-needed-r6), plus the items left for owner decisions.
- **NO deploy** to TEST or production; the coordinator deploys. No ledger, gitleaks or workflow changes.
- **Commit trailer:** `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Push.

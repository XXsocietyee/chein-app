# Fix parity r1: shared brief for the fix agents (Opus only)

The owner wants every page and function checked against the mini-program, with a consistent design style, using the skills. Six audits are done (one per area) on branches audit/parity-<area>, file docs/audit/parity/<area>.md: 143 P0, about 740 P1 and about 450 P2 in total. You FIX your area's findings.

## Base and branch
BASE = origin/ui/combined-r4. It holds everything (C1, C2, R4, continuity, consist-1) plus the typography sweep. A local integrator is making it compile in parallel and pushes compile fixes to it, so run `git fetch origin ui/combined-r4` and rebase your branch on it every hour or so. Create your branch fix/parity-<area> from it.

## Order of work
1. Every P0 in your area: a missing or broken function, a wrong backend contract, an unreachable page. Use the mini-program source (/home/user/hengyin/chengyinhub-xcx) as the functional reference and the backend (/home/user/hengyin) for contracts. If a fix needs a backend change, don't make it; list it under "Backend needed" in your receipt with the exact endpoint and fields.
2. The P1s in your area, in the audit's fix-plan order: missing states, structure and copy to match the mini-program (unless the audit marked it an intended difference), and consistency with the type-and-chrome rules.
3. Chrome in your files: run `python3 -B tools/report_chrome.py` and fix the custom back chevrons and hidden system backs IN YOUR FILES (cyGuardedBack, cyHeroChrome, cyPageTitle; see docs/design/type-and-chrome.md).
4. P2s only if time remains.

## Rules
- Swift is not installed in the cloud: match existing patterns exactly. Use CYTypography / .cyText, the CY components, CYMotion and the in-place kit (CYInPlaceResult). No raw fonts; the typography lint ratchet must not go up.
- Skills: `git clone --depth 1 https://github.com/s1gmamale1/apple-design-skills /tmp/s/apple && git clone --depth 1 https://github.com/emilkowalski/skills /tmp/s/emil && git clone --depth 1 https://github.com/jakubkrehel/make-interfaces-feel-better /tmp/s/mifb`; follow apple-design-os, apple-design-interaction, apple-design-tactics, emil break-ui and choreograph, and mifb.
- Owner rules: 积分 only; money stays TEST-only behind the existing switches (gated, not removed); unknown values show "—" or hide; never hide features; the mini-program is the base; channel and IM follow the Flutter app; production gating through the reviewed route gate stays as it is.
- Stay inside your area's files. Shared DesignSystem changes must be minimal and listed in the receipt. Don't edit tools/*_baseline.json except by running the ratchet's --update after you have LOWERED counts.
- Gates: python3 -B tools/check_scaffold.py, tools/check_design_lint.py and tools/contract_ratchet.py --check (no new failures).
- Commit small (each commit message names its finding ids), end messages with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`, and push every few findings. If the usage limit stops you, push first.
- Receipt docs/release/receipts/fix-parity-<area>.md: a table of finding id → status (fixed / partial / blocked-backend / deferred) → files → the local verification step (screen, fixture or TEST account, what to look at).
- Never push main, ui/main or ui/combined-r4. No deploys. No secrets.

# Screens r4: shared brief for the Claude cloud agents (2026-11-21)

Repo /home/user/chengyin-app, a native iOS SwiftUI app (城瘾), iPhone. Swift is NOT installed in the cloud, so write code that compiles by checking every type, initializer and modifier against existing code. A local integrator will build, verify and screenshot your branch.

## Base and branch
BASE = origin/ui/h-code-r3-ops. It already contains C1 (ui/h-code-r3-player: the ONE motion set in CYMotion, the in-place kit App/DesignSystem/CYInPlaceResult.swift, CYDesignedCover, City follow-ups) and C2. Create your branch from it. Fetch: `git fetch origin ui/h-code-r3-ops design/handoff-r2 ui/consist-1`.

## Design source (no Figma access)
`git show origin/design/handoff-r2:docs/design/handoff-r2/<path>`, or check it out read-only into /tmp. The key files:
- review/skill-r2.md §3 (code hand-off and the SwiftUI mapping per kit component), §4 (owner defaults, accepted), "What works";
- revise/skill-r2/js/_handoff.json (83 final frames: frame id → SwiftUI view, plus owner defaults) and revise/skill-r2/js/*.js (exact geometry, colours, spacing and copy as code);
- review/xrefs-1.md and revise/xrefs-1/LOG.md (motion and continuity: changes start where the cause is, one lead and its followers, everything else still, interruptible, results IN PLACE, a Reduce Motion fallback);
- review/verify-r1.md, review/full-*.md and CODE-QUEUE.md (open items).

## Type and chrome rules (consist-1)
Read `git show origin/ui/consist-1:docs/design/type-and-chrome.md`. Use CYTypography tokens (or .cyText once that lands), and no raw .system(size:) or raw text styles in new code. Back: the system back in the nav bar; a glass circle only on full-bleed heroes. Titles: tab roots use cyRootHeader (large); pushed pages use an inline 17 pt semibold title; sheets use CYSheetHeader styles. Don't add custom back chevrons or hide the system back button.

## Skills (clone, read and follow; cite the rules in the receipt)
`git clone --depth 1 https://github.com/s1gmamale1/apple-design-skills /tmp/s/apple && git clone --depth 1 https://github.com/emilkowalski/skills /tmp/s/emil && git clone --depth 1 https://github.com/jakubkrehel/make-interfaces-feel-better /tmp/s/mifb`, then apple-design-os, apple-design-interaction, apple-design-motion, apple-design-foundations, apple-design-tactics; emil choreograph, gestures, break-ui, write-swift; mifb make-interfaces-feel-better.

## Owner rules
积分 is the only currency. Money stays TEST-only behind the existing switches. Show unknown values as "—", or hide the row; never show 0 for unknown. Never hide features. The mini-program is the base, plus the owner's Figma. Channel and IM pages follow the owner's Flutter app. Dark player theme, light editor and merchant pages, neutral selected states, purple used rarely.

## Ownership
Five cloud agents run in parallel on DISJOINT areas. Touch only the files of your area. Shared DesignSystem changes must be minimal and noted in the receipt. Another integration branch is merging the continuity work (search, sheets, tabs, IM), so don't edit global search, CYTabs, the IM views or the TopicDetail bottom-bar presenters.

## Delivery
Branch name as given. Small commits ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Run python3 -B tools/check_scaffold.py, tools/check_design_lint.py and tools/contract_ratchet.py --check (no new failures). Push often; if the usage limit stops you, push first. Write docs/release/receipts/<branch-with-dashes>.md: for each frame, done, partial or left, the files touched, the skill rules applied, and a LOCAL VERIFICATION CHECKLIST (screens to shoot, fixture launch args, edge data, transitions to check). Never push main or ui/main; no deploys; no secrets.

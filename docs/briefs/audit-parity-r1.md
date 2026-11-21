# Audit parity r1: shared brief for the audit agents (owner, 2026-11-21)

Owner: "All pages and functions should be thoroughly checked. Pages need to be verified against the mini-program, utilizing our newly added skills. The overall design style should be consistent."

You are a REVIEWER: read-only on product code. You write ONE audit report. Fixes happen in a later round from your report.

## Sources
- Mini-program (the base): /home/user/hengyin/chengyinhub-xcx (app.json lists 177 pages; read each page's .wxml, .js, .wxss and .json, its components, and the api/request modules it calls).
- iOS app (SwiftUI): /home/user/chengyin-app. Audit the NEWEST combined code: `git fetch origin ui/h-code-r3-ops ui/consist-1 design/handoff-r2` and check out origin/ui/h-code-r3-ops. Also look at the in-flight branches when they exist (origin/ui/r4-*, origin/ui/c-cont-*) and note where they change a page.
- Design rules: `git show origin/ui/consist-1:docs/design/type-and-chrome.md` (the ONE type scale = MP rpx ÷ 2, line heights, the back and title rules); the final design hand-off is at origin/design/handoff-r2:docs/design/handoff-r2/ (revise/skill-r2/js/_handoff.json for the final frames; review/*.md).
- Skills (clone and FOLLOW, cite the rule for each finding): `git clone --depth 1 https://github.com/s1gmamale1/apple-design-skills /tmp/s/apple && git clone --depth 1 https://github.com/dickwu/apple-design-skill /tmp/s/review && git clone --depth 1 https://github.com/emilkowalski/skills /tmp/s/emil && git clone --depth 1 https://github.com/jakubkrehel/make-interfaces-feel-better /tmp/s/mifb`. Use /tmp/s/review (HIG review lens, 123 HIG pages), apple-design-os, apple-design-interaction, apple-design-tactics (a11y), apple-design-foundations, emil break-ui and review-animations, and mifb make-interfaces-feel-better.

## For EVERY mini-program page in your area
1. Map it to the app screen(s): the file and view type, and how it is reached. If there is no equivalent, that is a P0 gap.
2. FUNCTION PARITY: list every user action, entry point, button, form field, validation, API call (path plus params), state (loading, empty, error, not signed in, no permission, disabled) and navigation target in the MP page. For each, does the app have it, and is it wired to the same backend contract? Record missing, different or broken.
3. STRUCTURE AND COPY: section order, what is shown, and the Chinese copy (compare the MP strings with the app's .xcstrings). Note deliberate app improvements from the owner's Figma or rulings as "intended difference" (not a gap), citing the hand-off frame or ruling.
4. VISUAL vs MP and CONSISTENCY: font sizes and weights (MP rpx ÷ 2 vs the app token used), line height, spacing, radius, colours, button shape, back button, title style and sheet header against the type-and-chrome rules. Flag raw fonts, custom back chevrons, hidden system backs and off-scale sizes.
5. SKILL REVIEW: HIG and component correctness, interaction logic, a11y (VoiceOver labels, 44 pt targets, Dynamic Type, contrast), worst-case data (break-ui), and polish (make-interfaces-feel-better).

## Output
Write docs/audit/parity/<area>.md in the APP repo on branch audit/parity-<area> (from origin/design/handoff-r2), and push. Contents:
- A summary: pages audited, a per-page parity score (functions present / total), and counts of P0 (missing or broken function, wrong contract, unreachable page), P1 (missing state, wrong structure or copy, inconsistency with the rules) and P2 (visual polish).
- A table per page: MP path → app view/file → function checklist with status → findings, each with severity, the skill rule, evidence (MP file:line and app file:line) and a concrete fix (file, SwiftUI change, token).
- A cross-page consistency section for your area: patterns that differ between pages that should be the same.
- A batched fix plan for an executor (ordered, with files).
Commit message ending `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Don't edit product code. Never push main or ui/main. No secrets. If the usage limit stops you, push what you have first.

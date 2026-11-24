# Audit chengyin-ios against the mini-program: shared brief (owner, 2026-11-24)

Owner: "I've already had someone else do the UI, so let's compare it to the mini-program. I've made a lot of changes."

The other developer's iOS app lives in a SEPARATE repo, `liboyang42-cpu/chengyin-ios` (branch `main`, PRs up to #174). It is NOT the `chengyin-app` app. You audit `chengyin-ios` against the mini-program (MP).

You are a REVIEWER: read-only on product code in every repo. You write ONE audit report.

## Sources
- **Mini-program (the base):** `/home/user/hengyin/chengyinhub-xcx`. app.json lists the pages. For each page, read its .wxml, .js, .wxss and .json, its components, and the api/request modules it calls.
- **iOS app to audit:** clone it with `git clone https://github.com/liboyang42-cpu/chengyin-ios /home/user/chengyin-ios`. Audit `origin/main`. Also list any open branches that change a page in your area (`git branch -r --sort=-committerdate | head -20`; for example `biz/seats-parity-1124`). Note those changes without auditing them in full. Read its README.md, PROGRESS.md and docs/ first, to learn its structure, design system and any owner rulings it records.
- **Your page list:** it is the SAME as round 1. Take it from `git -C /home/user/chengyin-app show origin/audit/parity-<area>:docs/audit/parity/<area>.md`, from the summary table that lists every MP page. You may reuse the MP-side function checklists in that file, because the MP has not changed. Re-check every app-side item against chengyin-ios; never copy an app status from round 1.
- **Skills:** clone them and FOLLOW them, citing the rule for each finding.
  - `git clone --depth 1 https://github.com/s1gmamale1/apple-design-skills /tmp/s/apple`
  - `git clone --depth 1 https://github.com/dickwu/apple-design-skill /tmp/s/review`
  - `git clone --depth 1 https://github.com/emilkowalski/skills /tmp/s/emil`
  - `git clone --depth 1 https://github.com/jakubkrehel/make-interfaces-feel-better /tmp/s/mifb`

  Use:
  - /tmp/s/review: the HIG review lens;
  - apple-design-os, apple-design-interaction, apple-design-tactics (a11y) and apple-design-foundations;
  - emil break-ui and review-animations;
  - mifb.

## For EVERY MP page in your area
1. **MAP:** find the chengyin-ios screen(s) for it: the file, the view type, and how it is reached from the tab roots. A page with no equivalent, or one that can't be reached, is a P0.
2. **FUNCTION PARITY:** cover every user action, entry point, button, form field and validation. Check every API call (path plus params) and every state: loading, empty, error, not signed in, no permission, disabled. Check every navigation target. For each one, does chengyin-ios have it, wired to the same backend contract (path, method, params, response fields)? Record anything missing, different, broken, or only fixture or local-preview backed. Fixture-only or "local sample" flows that don't call the backend are P0 when the MP calls the backend.
3. **STRUCTURE AND COPY:** compare section order and what is shown. Compare the Chinese copy: MP strings vs the app's string catalogs and literals. A deliberate change that chengyin-ios docs or an owner ruling records is an "intended difference", not a gap; cite the doc.
4. **VISUAL vs MP:** compare font sizes and weights (MP rpx ÷ 2 vs the app value), line height, spacing, radius, colours, button shape, back button, title style and sheets. Then check CONSISTENCY across chengyin-ios's own pages: one type scale, one back and title pattern, one sheet header, one button style.
5. **SKILL REVIEW:** HIG and component correctness, interaction logic, a11y (VoiceOver labels, 44 pt targets, Dynamic Type, contrast), worst-case data (break-ui) and polish (mifb).
6. **OPTIONAL CROSS-CHECK:** where round 1 found a gap in chengyin-app, say in one word whether chengyin-ios has the same gap ("same"), avoids it ("ok") or has no such page ("n/a"). This tells the owner which app is closer to the MP per page.

## Output
- Write `docs/audit/ios-parity/<area>.md` in the `chengyin-app` repo (NOT in chengyin-ios), on a new branch `audit/ios-parity-<area>` from `origin/design/handoff-r2`, and push it. Do not push anything to chengyin-ios.
- **Contents:**
  - **Summary:** the chengyin-ios commit you audited; pages audited; a per-page parity score (functions present / total); counts of P0 (missing or broken function, wrong contract, unreachable, fixture-only), P1 (missing state, wrong structure or copy, inconsistency) and P2 (visual polish); and the overall parity % for the area.
  - **A table per page:** MP path → chengyin-ios view/file → function checklist with status → findings. Give each finding a severity, the skill rule, evidence (MP file:line and chengyin-ios file:line) and a concrete fix (file and SwiftUI change).
  - **Cross-page consistency** within the area.
  - **The round-1 cross-check column** (step 6), plus a one-paragraph verdict: for this area, which app is closer to the MP and why.
  - **A batched fix plan** for an executor working in chengyin-ios (ordered, with files).
- **Commits:** the commit message ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Push early and often. If the usage limit stops you, push what you have first.

## Rules
- Don't edit product code in any repo. Never push main, master or any ui/* branch. No secrets.
- MP screenshots are private: never copy or commit them.
- 积分 is the only currency. Money flows are TEST-only: note them, but don't call them.

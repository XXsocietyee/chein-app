# Type and chrome: the rule card (consist-1)

One type scale, one back button, one title rule. The code is the source of truth:
`CYTextStyle.spec` in `App/DesignSystem/CYDesignTokens.swift` (type) and the title/back modifiers in
`App/DesignSystem/CYScreenStyle.swift` (chrome). The gate is `tools/check_typography_lint.py`, which runs inside
`tools/check_design_lint.py`.

## 1. Type scale

Base: mini-program `style/tokens.wxss` (`docs/design/handoff-r1/mp-tokens.json` on `design/handoff-r1`).
**pt = rpx ÷ 2, rounded to a whole number** (owner rule). Weights and line heights also come from the mini-program.

| token | rpx → pt | weight | MP line-height | CJK line box at default size | tracking | Dynamic Type (relative to) | use |
|---|---|---|---|---|---|---|---|
| `display` | 56 → 28 | bold | 1.15 | 39.2 pt (natural) | 0 | `.largeTitle` | hero text: onboarding, result, empty-state hero |
| `pageTitle` | 58 → 29 | bold | 1.2 | 40.6 pt (natural) | 0 | `.largeTitle` | an object's name in the content (club, activity). Not a page-type title |
| `sheetTitle` | 44 → 22 | bold | 1.3 | 30.8 pt (natural) | 0 | `.title2` (native) | sheet / modal title (`CYSheetHeader`) |
| `sectionTitle` | 36 → 18 | bold | 1.25 | 25.2 pt (natural) | 0 | `.title3` | section header inside a page |
| `cardTitle` | 32 → 16 | semibold | 1.3 | 22.4 pt (natural) | 0 | `.callout` (native) | card / row headline |
| `button` | 32 → 16 | bold | 1.3 | 22.4 pt (natural) | 0 | `.callout` (native) | button label (`CYPillButton`) |
| `body` | 28 → 14 | regular | **1.6** | **22.4 pt (+2.8 lineSpacing)** | 0 | `.body` | reading text |
| `bodyMedium` | 28 → 14 | semibold | **1.6** | **22.4 pt (+2.8)** | 0 | `.body` | emphasised body (`.cy-text-body-strong`) |
| `bodyCompact` | 28 → 14 | regular | 1.3 | 19.6 pt (natural) | 0 | `.subheadline` | dense secondary copy: row subtitles, 1–2 line descriptions |
| `label` | 24 → 12 | medium | 1.35 | 16.8 pt (natural) | 0 | `.caption` (native) | control label: tab, field label, chip |
| `meta` | 24 → 12 | regular | 1.35 | 16.8 pt (natural) | 0 | `.caption` (native) | time, count, place, row hint |
| `caption` | 22 → 11 | regular | 1.45 | 16.0 pt (+0.55) | 0 | `.caption2` (native) | tag, badge, caption |
| `micro` | 20 → 10 | medium | 1.3 | 14.0 pt (natural) | 0 | `.caption2` | counter, legal footnote |
| `numericBody` | 28 → 14 | semibold, rounded, tabular | 1.3 | — | 0 | `.body` | price, points, counts in rows |
| `numericTitle` | 40 → 20 | semibold, tabular | 1.25 | — | 0 | `.title3` | card stat / price one step below the hero number |
| `dataXL` | 64 → 32 | bold, rounded, tabular | 1.05 | — | 0 | `.largeTitle` | stat hero number |
| `data2XL` | 84 → 42 | bold, rounded, tabular | 1.05 | — | 0 | `.largeTitle` | balance / settlement total |

Changes from the previous `CYTypography`: `pageTitle` heavy → **bold** (MP 700), `cardTitle` bold → **semibold**
(MP 600), `bodyMedium` medium → **semibold** (MP body-strong 600), `bodyCompact` gets the tight 1.3 leading,
`CYSheetHeader` titles 20 → **22** (MP 44rpx). Token names are unchanged.

**Line height.** Chinese renders in PingFang SC, whose line box is already 1.4 em (ascent 1.06 + descent 0.34).
`.cyText(_:)` adds `lineSpacing = max(0, (MP line-height − 1.4) × size)`, so body copy gets the mini-program's
1.6 and tighter MP values stay at the natural 1.4 (SwiftUI cannot pull lines closer). `lineSpacing` only adds space
*between* lines, so single-line labels are unaffected. The iOS 26 SDK line-height API is not used: the deployment
target is iOS 17.0 (`Config/Base.xcconfig`), so it would need an `#available` branch, and it cannot be compiled
here to check its signature.

**Tracking.** 0 for every style. Chinese takes no letter-spacing; SF already applies size-dependent tracking through
its optical sizes (*apple-design-foundations / typography.md*: "the system applies it automatically… only apply
manually in Figma/CSS").

**Dynamic Type.** `.cyText(.x)` scales the size with `@ScaledMetric(relativeTo:)` of the style in the table
(*apple-design-foundations*: "Dynamic Type must reflow"; *typography.md* principle 4 "Trust the system").
The static `CYTypography.x` values scale natively only for the rows marked *native* (their size equals the Apple
text style's default); the others are fixed, as before. Use `.cyText` in views.

### How to write it

```swift
// DO
Text(club.name).cyText(.pageTitle)
Text(summary).cyText(.body)                       // font + 1.6 line height + Dynamic Type
Text(price).cyText(.numericBody)
Label("场次", systemImage: "calendar").cyText(.meta)
Text(a).cyText(.meta) + Text(b).cyText(.meta)    // still Text: the compiler uses the Text overload

// DON'T
Text(summary).font(.subheadline)                  // raw text style (15 pt, not on the scale)
Text(title).font(.system(size: 17, weight: .heavy))
Text(title).font(Theme.Font.sectionTitle)        // legacy alias, use the token
Text(summary).font(CYTypography.body).lineSpacing(6)  // ad-hoc leading; .cyText(.body) carries it
```

`weight:` on `.cyText` is for one-off emphasis where the scale has no matching style; prefer the dedicated style
(`.bodyMedium`, `.label`). SF Symbol images may keep a text style (`Image(systemName:).font(.body)`): the codemod
leaves icons alone. Large decorative glyphs (≥ 48 pt) belong in DesignSystem components.

## 2. Title rule

| page | title | how |
|---|---|---|
| tab root (首页 · 漫游 · 发布 · 俱乐部 · 我的) | system **large title**, collapses on scroll | `cyRootHeader(_:)` (already on the five roots) |
| pushed page | system **inline** title, 17 pt semibold, drawn by the bar | `cyPageTitle("key")` / `cyPageTitle(verbatim: name)` |
| sheet | the three handbook styles (player / editor / merchant), 22 pt bold | `CYSheetHeader` |

Do not leave the title mode unset on a pushed page: it inherits from the stack and turns large after a large root.
Do not draw a second, page-type title ("活动详情") in the content under an inline title. An object's own name in the
content is fine (`.cyText(.pageTitle)`), and on hero pages it becomes the inline title once the hero scrolls away.
(*apple-design-os / app-component-anatomy.md*: "Large title… collapses to 17 pt semibold inline title on scroll";
ios-ipados.md "Navigation bar: 44 pt tall + top safe area".)

## 3. Back rule

**One back button: the system back in the navigation bar**, with its edge-swipe gesture. Don't hide it, don't draw
a chevron. (*apple-design-interaction / navigation-models.md*: "Edge-swipe… mirrors the back button exactly; don't
intercept it"; *app-component-anatomy.md*: "Swipe-from-left-edge always available".)

Two exceptions, both in `CYScreenStyle.swift`:

| case | use | behaviour |
|---|---|---|
| unsaved-edit exit guard | `.cyGuardedBack(when: hasEdits) { confirmDiscard() }` | system back while clean; while dirty a same-looking `CYBareBackButton` asks first and the swipe is blocked |
| full-bleed hero image | `.cyHeroChrome(heroScrolledAway: away)` + `CYHeroBackButton` in the hero's top-leading overlay + `cyTracksHeroScroll($away)` | glass circle sits on the image and **scrolls away with it**; then the bar returns with the system back and the object's inline title; swipe-back kept (`cyKeepsSwipeBack()`) |

Glass circles appear **only** on full-bleed hero images (*apple-design-os / app-component-anatomy.md*: "glass floats
above content… it is not applied to primary content rows"). A full-screen cover closes with ✕ or 完成, not a back
chevron. Calendar / step pagers (`chevron.left` to the previous month) are not back buttons and are allowed.

```swift
// DO
SomeDetail().cyPageTitle("club.members")
Editor().cyGuardedBack(when: model.isDirty) { showDiscard = true }

// DON'T
.navigationBarBackButtonHidden(true)
.toolbar { ToolbarItem(placement: .topBarLeading) { Button { dismiss() } label: { Image(systemName: "chevron.left") } } }
```

## 4. Polish rules applied (*make-interfaces-feel-better*)

- **Tabular numbers** (§9): every number token is `.monospacedDigit()`; counts that change use `numericBody` /
  `dataXL`, or `.cyText(.meta, monospacedDigit: true)`.
- **Text wrapping** (§10): titles grow downward (`cyWrapText`); never truncate body at large Dynamic Type sizes.
- **Minimum hit area** (§16): every back control is a 44 × 44 pt target.
- Font family scope: system font only (SF + PingFang SC); no new typeface.

## 5. Tooling

| tool | what |
|---|---|
| `tools/codemod_typography.py` | dry run by default; `--apply` rewrites `.font(raw)` → `.cyText(.token)`; `--upgrade-tokens` also turns `.font(CYTypography.x)` into `.cyText(.x)`; lists what a human must decide (icons, ternaries, monospaced, test-pinned) |
| `tools/report_chrome.py` | every custom back chevron, hidden back, non-root large title, unset title mode, hero chrome, with the fix |
| `tools/check_typography_lint.py` | ratchet over `tools/typography_lint_baseline.json`; new raw fonts, back chevrons, hidden backs, non-root large titles fail. `--update` lowers the baseline after a sweep |
| `tools/typography_scale.py` | the scale and the mapping table shared by the three tools |

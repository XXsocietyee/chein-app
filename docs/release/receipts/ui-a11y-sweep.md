# ui-a11y-sweep receipt (W3-8, DES-e5; NOT COMPILED locally; cloud Build is the gate)

Scope: views, design-system and DEBUG fixtures only. No Core/Tests/Config, behaviour, gating or data changes. Strings added to `Resources/Localizable.xcstrings` (EN + zh-Hans): `map.panel.size.compact|medium|large`, `roam.peek.countUnknown`.
Note: `design-bar-ada.md` does not exist in this tree; `motion-spec*.md` and `ux-strategy.md` W3-8 were used.

## Fixed (views only)
- **Map panel grabber** (`CYMapScaffold`): hit row 28 -> 44 pt; bar contrast 0.28 -> 0.5 white (non-text 3:1); VoiceOver now speaks the current size (Small/Medium/Large) as the adjustable value. Peek bar height maths uses the same 44 pt.
- **Peek bar** (`CYMapScaffold`): children combined into one button element for every caller.
- **Roam map chrome** (`RoamBrowserView`): title over map gets a soft top scrim (white text >= 4.5:1 on any tile), wraps/shrinks at AX5 instead of clipping; GO read first among rules / GO / open-map (sort priority); search clear button 44x44; removed the AX1 Dynamic Type cap on the search field (now follows AX5); peek count em dash reads "Count unknown", chevron hidden.
- **Passport stamp grid** (`RoamStampCard`): caption 2-line limit lifted at accessibility sizes.
- **Badge wall tile** (`ObjectBadgeWallBadgeLabel`): decorative medal glyph hidden from VoiceOver (name + locked/unlocked chip carry the meaning).
- **Locked silhouette** (`CYAlbum`): dim 0.62 -> 0.78; 0.62 left secondary text ~3.5:1 on light surfaces.

## Fixtures
`--design-fixture a11y-roam-ax5` (map chrome, peek bar with unknown count, AX5), `a11y-passport-ax5` (badge wall incl. locked tiles, AX5).

## Findings not fixable in views
- Floating chrome contrast over live MapKit tiles can only be guaranteed by the scrim; tile colour is outside our control.
- Account screen is a system `Form` (rows already CYListRow, system Dynamic Type); no grid there. The grids are the stamp album and badge wall (both covered).
- `accessibility-*-specialist` audits and a device AX5 / VoiceOver pass were not run (code-only task).
- ~46 pre-existing design-lint violations (allowlisted) untouched.

## Checks
swiftc -parse on all touched Swift files clean; check_scaffold PASS; check_design_lint PASS. Cloud: appended below.

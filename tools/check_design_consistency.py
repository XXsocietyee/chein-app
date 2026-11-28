#!/usr/bin/env python3
"""ds-consistency r3: ONE design system ratchet (owner rule 2, 2026-11-27). Text scan, not a Swift compiler.

Scans player-facing App/**/*.swift (skips paths with `Merchant`, `Fixture`, `DesignFixtures/`, `Diagnostics`,
and `#Preview { ... }` blocks; comments are ignored) and counts, per file:

  raw font        `.system(size:` (unless the size is an `@ScaledMetric`), `.font(.custom(`, `Font.custom(`,
                  `UIFont.systemFont(ofSize:`  -> use Dynamic Type text styles or `.cyText(_:)`
                  (App/Theme and CYDesignTokens.swift define the scale and are not counted)
  tracking        `.tracking(` / `.kerning(`  -> the system letter spacing only
  root title      a tab-root file (TAB_ROOTS) without `.cyRootHeader(` or `.navigationBarTitleDisplayMode(.large)`
                  (a transparent / hidden bar on a root is caught by `hidden nav`)
  pushed large    `.navigationBarTitleDisplayMode(.large)` outside the tab roots and the design system
                  (pushed pages use the inline title, `cyPageTitle(_:)`)
  title mode      a file that sets navigation titles but never a display mode (no `.navigationBarTitleDisplayMode`,
                  `cyPageTitle`, `cyRootHeader`): a pushed page then inherits the tab root's large title
  hidden nav      `.navigationBarHidden(true)`, `.toolbar(.hidden, for: .navigationBar)`,
                  `.toolbarBackground(.hidden, for: .navigationBar)`, `.navigationBarBackButtonHidden(true)`
                  (custom back buttons / MP custom nav chrome)
  fixed surface   a shared colour token `let x = Color.black` / `.white` (design system included): it ignores
                  light / dark -> CYColor / palette / system colours
  dark backing    `.background(Color.black.opacity(…))` stacked right under a material background (design system
                  included): semantic text on a darkened material is black-on-grey in light mode -> the material alone
  custom back     `CYNavBar(` / `CYBareBackButton(` / `CYHeroBackButton(` outside App/DesignSystem
                  (use the system bar; `cyGuardedBack(when:onBack:)` for an unsaved-changes exit)
  button style    a page-level `struct …: ButtonStyle` outside App/DesignSystem, or `.buttonStyle(.questifyPrimary)`
                  (one button system: `.borderedProminent` / `.bordered` / `.borderless` or the CY styles)
  popup scrim     `Color.black.opacity(0.2…0.8).ignoresSafeArea(` outside App/DesignSystem: an MP popup copied as a
                  dimmed overlay (use `.sheet` + `.presentationDetents`)
  raw colour      `Color(red:` / `UIColor(red:` / `Color(hex:` / `"#RRGGBB"` / `0xRRGGBB` outside App/DesignSystem
                  and App/Theme  -> semantic system colours or the CY palette
  list style      `.listStyle(...)` other than `.insetGrouped` (190 sibling pages use `.insetGrouped`; a `.plain` /
                  `.grouped` / `.inset` / `.sidebar` page next to them is a list-style mix)
  custom sheet    an MP popup / half-screen built by hand instead of `.sheet` + `.presentationDetents`, outside
                  App/DesignSystem: `.accessibilityAddTraits(.isModal)` (hand-made modal), a dimmed
                  `CYColor.bgOverlay` / `Color.black.opacity(…)` scrim with `.ignoresSafeArea()` + `.onTapGesture`,
                  or a drawn sheet grabber `Capsule()…frame(width: 3x–4x, height: 4–6)`
  custom tabs     a hand-made tab bar / segment row outside App/DesignSystem: `ForEach` over tabs / segments whose
                  rows are `Button`s compared against the selection (use `Picker` + `.cyAdaptiveSegmented()` or
                  `CYTabs`), or the design-kit bottom bars `CYNightTabBar(` / `CYDomainTabBar(` used in place of the
                  system `TabView` (App/QuestifyApp.swift)
  font design     `design: .rounded` / `.serif` or `.fontDesign(.rounded / .serif)` outside App/DesignSystem and
                  App/Theme: a per-page numeral / heading face (stat numbers use `.cyText(.dataXL)`, the one rounded
                  data style; `.monospaced` code editors are fine)
  custom search   a hand-drawn search field outside App/DesignSystem: an `Image(systemName: "magnifyingglass")`
                  followed within 3 lines by a `TextField(` (use `.searchable` on the page, or `CYFormSearchRow` for a
                  filter that is one row of a Form / List section)
  text on art     a generated cover `CYCoverArt(` used as the `.background` of a view outside App/DesignSystem
                  (a title / text laid on busy procedural art): put the cover above the text as the hero
                  illustration (`CYHeroHeader { Cloud07Cover(...) }`) and keep text on system backgrounds
  raw segmented   `.pickerStyle(.segmented)` outside App/DesignSystem: 85 sibling pickers use `.cyAdaptiveSegmented()`
                  (segmented while every title fits, the system menu for long English titles / accessibility sizes),
                  so a bare segmented picker truncates where its siblings do not
  leading action  a `ShareLink(` / replay action inside a `.topBarLeading` / `.navigationBarLeading` toolbar item
                  outside App/DesignSystem: the leading slot is Back / Cancel / Close only; share, save and replay
                  sit trailing (`.primaryAction`) next to the one Done (P16)
  done leading    a `Button("….done")` in a `.cancellationAction` / leading toolbar item with no
                  `.confirmationAction` within 8 lines (a sheet whose only dismiss is Done): 30 sibling sheets put
                  Done trailing (`.confirmationAction`); leading is Cancel / Close
  raw radius      a literal non-zero `cornerRadius: N` outside App/DesignSystem and App/Theme: 94 player call sites
                  used 13 different radii (2–48 pt) next to the one scale. Use `CYRadius.inner` / `.sm` (8: thumbnails
                  inside a card, chips, icon tiles), `.card` (12), `.bubble` (18: Messages-style bubbles / composer),
                  `.hero` (20), `.sheet` (24); procedural art drawn to its own frame goes in "allowed"
  line spacing    a literal `.lineSpacing(N)` outside App/DesignSystem and App/Theme: 7 reading paragraphs set
                  3/4/5/6/8 pt by hand, fixed points that do not scale with Dynamic Type and override the one
                  reading leading `.cyText(.body)` already applies (CYTypeSpec lineHeight 1.6, scaled)
  status capsule  a hand-drawn soft-tint status chip outside App/DesignSystem and App/Theme: a `Capsule` filled with a
                  colour at opacity 0.05–0.29 (`Capsule().fill(x.opacity(0.15))`, `.background(x.opacity(0.12), in:
                  Capsule())`). Native r2 status words have no capsule chrome: use `CYStatusChip(_:tone:)` (footnote
                  `Label`, system tone colour) like its 249 call sites
  silent spinner  a bare `ProgressView()` stretched as the page / section loader (`.frame(maxWidth: .infinity` on the
                  same or the next line) outside App/DesignSystem: P10 "say what's happening in words, never a spinner alone".
                  Use `CYLoadingState(_:messageIdentifier:)` (system `ProgressView` with the MP loading words)
  busy swap       a button label that swaps its title for a bare `ProgressView()` while the action runs
                  (`if busy { ProgressView() } else { Text(title) }`): the button shrinks, the words vanish (P10).
                  Use `CYBusyLabel(busy:) { title }` (small system spinner before the kept title). A toolbar
                  confirmation item that becomes a spinner (`ToolbarItem` within 4 lines) is the system idiom, allowed
  hand divider    a hand-drawn hairline outside App/DesignSystem and App/Theme: `Rectangle().fill(colour).frame(height:
                  0.5 / 1)` (or `Rectangle().frame(height: 1)`). 98 call sites use the system `Divider()` (right
                  thickness on every display scale, follows the separator colour in light and dark): use it.
                  Vertical timeline connectors (`frame(width:)`) and clear spacers are not dividers
  all caps        `.textCase(.uppercase)` anywhere in App/ (design system included): one text case on every player
                  surface, sentence case in English like the system's own headers and the run-16 eyebrows; the
                  en string carries its own capitals (zh is unaffected either way)
  grid link       a `NavigationLink` as a cell of a `LazyVGrid` / `LazyHGrid` / `Grid` whose nearest container is a
                  `List` (outside App/DesignSystem): List draws its disclosure chevron beside every link in the row,
                  so stray chevrons sit between the grid's tiles. Make the cell a `Button` that sets the selection of
                  one `.navigationDestination(item:)` (grids in a `ScrollView` are fine)
  refresh no pull a toolbar refresh button (`"arrow.clockwise"` inside a `.toolbar` / `ToolbarItem`) in a file with a
                  `List` / `Form` / `ScrollView` and no `.refreshable`: 24 sibling pages pair the button with
                  pull-to-refresh (the MP `onPullDownRefresh`); add `.refreshable { await load() }` on the scroll
  manual paging   a `Button` whose title is a "Load more" / "Load earlier" / "Show more" key (en value in
                  Resources/Localizable.xcstrings) with no `.onAppear` / `.task` beside it (ADA 11-28 §3 Refresh /
                  paging): the MP pages on `onReachBottom`; use `CYLoadMoreRow(key) { … }` (loads when it scrolls in,
                  the button stays for VoiceOver), or add the `.onAppear` auto-load like Square / Home feed
  section spacing a numeric `.listSectionSpacing(…)` outside App/DesignSystem and App/Theme: `CYScreenStyle` gives every
                  player list 24 pt between sections (`CYSpacing.xxl`); three pages re-set 16 / 20 / 20 by hand. Drop
                  it to inherit the one spacing; `.compact` (tab strips / dense detail lists) stays the system value

Build-break guards (module-wide: App/ and Core/ compile into ONE module, so every file is scanned, merchant and
fixtures included; there is no Swift compiler in the lanes' cloud sessions):
  duplicate type   the same top-level `struct` / `class` / `enum` / `protocol` / `actor` / `typealias` name declared
                   in two files of App/ + Core/ (two lanes each added a `PlayRouteNotice`). `private` / `fileprivate`
                   top-level types only clash inside their own file; declarations in different branches of the same
                   `#if … #else` are not a clash.
  undeclared state inside a SwiftUI `View` struct (its body plus every `extension Name` in the module): a `$name`
                   binding or an assignment `name = …` / `self.name = …` / `name += …` whose name is never declared
                   (`var` / `let` / `inout` / enum `case`) in that type, its extensions or the module's globals
                   (a lane used `governanceMemberCount = $0` without `@State private var governanceMemberCount`).
                   Heuristic text scan: string literals are blanked first.
  effect on clean page  a call to the restored effect kit (OWNER RULE 3, 11-28): `CYBurst(` / `CYConfettiBurst(` /
                  `CYStarBloom(` / `CYFogLayer(` / `CYEdgeGlow(` / `CYCelebrationMoment(` / `CYJoinReward(` /
                  `CYGlassCarousel(` / `CYGlassSliver(` / `CYCarouselBackdrop(` / `CYWeatherScene(`, `.cyFoil(` / `.cyFoilSheen(` /
                  `.cyEdgeGlow(` / `.cyUnlockCelebration(` outside the distinctive surfaces: games, story flow,
                  payment, maps and celebration moments (EFFECT_SURFACE_DIRS / EFFECT_SURFACE_NAME) and the kit files
                  that host them (EFFECT_KIT_FILES). Home, search, lists, settings, Me, wallet, club admin, inbox,
                  forms and details stay clean: remove the call there
  status hue      a `checkmark…` / `exclamationmark…` / `xmark…` glyph with a raw `.green` / `.orange` / `.red`
                  foreground on the same line, outside App/DesignSystem and the effect surfaces: use
                  `CYColor.successText` / `warningText` / `dangerText` (one done / warning / failed hue)
  header font     a List/Form `header: { … }` closure outside App/DesignSystem that sets a heading style
                  (`.cyText(.sectionTitle / .cardTitle / .headline / .title…)`, `.font(.headline / .title… /
                  .largeTitle)`, `.bold()`, `.fontWeight(.bold / .semibold …)`): one section shouts next to its
                  system-header siblings. Leave the header text plain (system footnote, secondary); trailing
                  footnote / meta accessories are fine

Baseline: tools/design_consistency_baseline.json
  "allowed":  {file: {kind: reason}}  intentional chrome (game HUDs, full-screen maps, procedural art), never fails;
                                      an allowed kind with no hit left in its file is reported as stale and fails;
                                      a reason starting "unmounted internal screen" fails as soon as the file's
                                      `struct …: View` is called anywhere in App/ outside DesignFixtures / *Fixture*
                                      (mounting it for players means converting its chrome first)
  "baseline": {file: {kind: count}}   debt on this tree; a count above it fails, so new violations fail

  python3 tools/check_design_consistency.py            # check (exit 1 on a new violation)
  python3 tools/check_design_consistency.py --list     # print every current hit
  python3 tools/check_design_consistency.py --update   # lower the baseline to the tree (never raises a count)
  python3 tools/check_design_consistency.py --update --allow-increase   # re-baseline (reviewed only)
"""
import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASELINE = ROOT / 'tools' / 'design_consistency_baseline.json'

RAW_FONT = 'raw font'
TRACKING = 'tracking'
ROOT_TITLE = 'root title'
PUSHED_LARGE = 'pushed large'
HIDDEN_NAV = 'hidden nav'
RAW_COLOUR = 'raw colour'
CUSTOM_BACK = 'custom back'
TITLE_MODE = 'title mode'
BUTTON_STYLE = 'button style'
POPUP_SCRIM = 'popup scrim'
LIST_STYLE = 'list style'
CUSTOM_SHEET = 'custom sheet'
CUSTOM_TABS = 'custom tabs'
FONT_DESIGN = 'font design'
CUSTOM_SEARCH = 'custom search'
TEXT_ON_ART = 'text on art'
RAW_SEGMENTED = 'raw segmented'
RAW_SEGMENTED_PATTERN = re.compile(r'\.pickerStyle\(\s*\.segmented\s*\)')
LEADING_ACTION = 'leading action'
LEADING_PLACEMENT = re.compile(r'placement:\s*\.(?:topBarLeading|navigationBarLeading)\b')
DONE_LEADING = 'done leading'
DONE_LEADING_PLACEMENT = re.compile(r'placement:\s*\.(?:cancellationAction|topBarLeading|navigationBarLeading)\b')
DONE_BUTTON = re.compile(r'Button\((?:String\(localized:\s*LocalizedStringResource\()?"[A-Za-z0-9_.]*\.done"'
                         # also a Done label through a helper / label closure: `Button(loc("x.done"))`,
                         # `Button { … } label: { Text("done", tableName: …) }`, `Button(W8Text.t("完成", "Done"))`
                         r'|Button\([A-Za-z0-9_.]+\("(?:[A-Za-z0-9_.]*\.)?done"'
                         r'|Button\s*\{.*label:\s*\{\s*Text\("(?:[A-Za-z0-9_.]*\.)?done"'
                         r'|Button\([A-Za-z0-9_.]+\("完成",\s*"Done"\)\)')
LEADING_ACTION_CONTENT = re.compile(r'\bShareLink\(|"arrow\.counterclockwise"|"square\.and\.arrow\.up"')
RAW_RADIUS = 'raw radius'
# One radius scale (CYRadius: inner/sm 8, card 12, bubble 18, hero 20, sheet 24): a literal non-zero corner radius.
RAW_RADIUS_PATTERN = re.compile(r'\bcornerRadius:\s*(?!0(?:\.0+)?\b)\d')
LINE_SPACING = 'line spacing'
# One reading leading: `.cyText(.body)` applies it (scaled); a literal `.lineSpacing(N)` is a per-page value.
LINE_SPACING_PATTERN = re.compile(r'\.lineSpacing\(\s*\d')
# Coordinator 11-28: an untyped `{ old, new in … }` condition on a haptic modifier inside a long view body made the
# compiler give up ("unable to type-check this expression in reasonable time") four times in one night. New haptic
# conditions go through a typed ViewModifier or a named static func (`where: Self.rose`, `condition: Self.signedIn`).
UNTYPED_HAPTIC = 'untyped haptic'
UNTYPED_HAPTIC_PATTERN = re.compile(r'\.(?:cyHaptic|sensoryFeedback)\([^)]*\)\s*\{\s*\w+\s*,\s*\w+\s+in\b|\.(?:cyHaptic|sensoryFeedback)\([^{]*(?:where|condition):\s*\{\s*\w+\s*,\s*\w+\s+in\b')
STATUS_CAPSULE = 'status capsule'
# One status word (CYStatusChip, no capsule): a capsule filled with a soft tint (opacity 0.05–0.29) is a per-page chip.
STATUS_CAPSULE_SHAPE = re.compile(r'\bCapsule\s*\(|in:\s*\.capsule\b')
STATUS_CAPSULE_TINT = re.compile(r'\.opacity\(\s*0?\.(?:0[5-9]|[12]\d?)\d*\s*\)')
SILENT_SPINNER = 'silent spinner'
# One loading pattern (P10): a page loader shows its words; `CYLoadingState` is the system ProgressView with a label.
SILENT_SPINNER_PATTERN = re.compile(r'^\s*ProgressView\(\)\s*$')
SILENT_SPINNER_FRAME = re.compile(r'^\s*\.frame\(maxWidth:\s*\.infinity')
SILENT_SPINNER_INLINE = re.compile(r'\bProgressView\(\)\s*\.frame\(maxWidth:\s*\.infinity')
BUSY_SWAP = 'busy swap'
# One busy-button pattern: `CYBusyLabel` keeps the title beside a small spinner; a label never becomes a bare spinner.
BUSY_SWAP_ONE_LINE = re.compile(r'\{\s*ProgressView\(\)(?:\s*\.controlSize\([^)]*\))?\s*\}\s*else\s*\{')
BUSY_SWAP_ELSE = re.compile(r'^\s*\}\s*else\s*\{')
BUSY_SWAP_BUTTON = re.compile(r'\blabel:|\bButton\b[^{]*\{\s*$|\bButton\s*\{')
BUSY_SWAP_EXEMPT = re.compile(r'\bToolbarItem\b|\bLabeledContent\b')
HAND_DIVIDER = 'hand divider'
# One separator: the system `Divider()`, never a drawn 0.5 / 1 pt rectangle.
HAND_DIVIDER_PATTERN = re.compile(r'\bRectangle\(\)(?:\s*\.fill\((?!\s*\.clear\b)[^)]*(?:\([^)]*\))?[^)]*\))?\s*\.frame\(height:\s*(?:0?\.5|1(?:\.0)?)\s*\)')
ALL_CAPS = 'all caps'
# One text case: sentence case from the strings; no view forces English to ALL CAPS.
ALL_CAPS_PATTERN = re.compile(r'\.textCase\(\s*\.uppercase\s*\)')
GRID_LINK = 'grid link'
GRID_OPEN = re.compile(r'\b(?:Lazy[VH]Grid\(|Grid\s*[({])')
GRID_CONTAINER = re.compile(r'\b(List|ScrollView)\s*[({]')
GRID_HELPER_CALL = re.compile(r'(?<![.\w])([a-z]\w*)\(')
GRID_HELPER_DECL = re.compile(r'\bfunc\s+([a-z]\w*)\s*[(<]')
FIXED_SURFACE = 'fixed surface'
# One appearance: a shared colour token pinned to black / white ignores light / dark (the map panel was a fixed black
# slab under a light map). Tokens resolve through CYColor / the palette / system colours.
FIXED_SURFACE_PATTERN = re.compile(r'^\s*(?:(?:public|internal|private|fileprivate|static)\s+)*let\s+\w+\s*(?::\s*Color\s*)?='
                                   r'\s*(?:Color\.|\.)(?:black|white)\s*$')
DARK_BACKING = 'dark backing'
# A material already adapts to light / dark; a fixed black layer under it turns a light chip grey, so the semantic
# (black in light mode) text on top loses contrast (roam fog chips over the light map).
DARK_BACKING_PATTERN = re.compile(r'\.background\(\s*Color\.black\.opacity\(')
MATERIAL_BACKGROUND = re.compile(r'\.background\(\s*\.(?:ultraThin|thin|regular|thick|ultraThick|bar)Material\b')
LOCALE_MONEY = 'locale money'
# One money label: `LocaleDisplay.money` reads `¥12.00` in Chinese and `CN¥12.00` elsewhere. The wallet's currency
# table without a locale, or a literal `¥` drawn as text, puts a bare `¥` in English next to `CN¥` on other screens.
# Run 22: a price / amount string shown as-is (`Text(verbatim: offer.priceText)`) keeps a server or hand-built `¥` in
# English; show it through `LocaleDisplay.yuanAmounts(in:locale:)` (idempotent) or a locale-aware money helper.
LOCALE_MONEY_PATTERN = re.compile(r'WalletCurrencySymbol\.symbol\((?![^()]*locale:)[^()]*\)|Text\((?:verbatim:\s*)?"[+\-\u2212]?¥'
                                  r'|Text\((?:verbatim:\s*)?[A-Za-z_.]*(?:priceText|amountText|PriceText|AmountText)\)')
REFRESH_NO_PULL = 'refresh no pull'
# One refresh pattern: 24 player pages pair the toolbar `arrow.clockwise` refresh with `.refreshable` on the scroll
# (the MP `onPullDownRefresh`); a page with only the toolbar button cannot be pulled down like its siblings.
REFRESH_GLYPH = re.compile(r'"arrow\.clockwise"')
REFRESH_TOOLBAR = re.compile(r'\bToolbarItem\b|\.toolbar\s*\{')
REFRESH_SCROLL = re.compile(r'\b(?:List|Form)\s*[({]|\bScrollView\b')
MANUAL_PAGING = 'manual paging'
# One paging pattern (ADA 11-28 §3 Refresh / paging): the MP loads the next page on `onReachBottom`. A "Load more"
# button with no `.onAppear` / `.task` beside it makes the player find and tap it; `CYLoadMoreRow` does both.
PAGING_EN = re.compile(r'^(?:Load more|Load earlier|Show more)\b')
PAGING_AUTO = re.compile(r'\.onAppear\b|\.task\s*[({]|CYLoadMoreRow\b')
_PAGING_KEYS = None


def paging_keys():
    """Catalog keys whose English value is a short "Load more" / "Load earlier" / "Show more" title."""
    global _PAGING_KEYS
    if _PAGING_KEYS is None:
        keys = set()
        catalog = ROOT / 'Resources' / 'Localizable.xcstrings'
        if catalog.exists():
            for key, entry in json.loads(catalog.read_text(encoding='utf-8')).get('strings', {}).items():
                value = entry.get('localizations', {}).get('en', {}).get('stringUnit', {}).get('value', '')
                if PAGING_EN.match(value) and len(value) < 40:
                    keys.add(key)
        _PAGING_KEYS = keys
    return _PAGING_KEYS


def manual_paging_hits(lines):
    keys = paging_keys()
    hits = []
    last = -10
    for index, (number, code) in enumerate(lines):
        named = [m.group(1) for m in re.finditer(r'"([A-Za-z0-9_.]+)"', code)]
        if not any(k in keys for k in named):
            continue
        if not any('Button' in c for _, c in lines[max(0, index - 3):index + 1]):
            continue
        if any(PAGING_AUTO.search(c) for _, c in lines[max(0, index - 6):index + 9]):
            continue
        if hits and index - last <= 3:
            continue  # the same button's label / accessibility lines
        hits.append((number, MANUAL_PAGING, code.strip()))
        last = index
    return hits


SECTION_SPACING = 'section spacing'
# One list rhythm: CYScreenStyle sets `.listSectionSpacing(CYSpacing.xxl)` once; a page re-setting a number drifts.
SECTION_SPACING_PATTERN = re.compile(r'\.listSectionSpacing\(\s*(?!\.compact\b|\.default\b)')
DUPLICATE_TYPE = 'duplicate type'
UNDECLARED_STATE = 'undeclared state'
HEADER_FONT = 'header font'
# One section-header look: a List/Form `header: { … }` closure inherits the system header style (footnote, secondary).
# A heading-size font, bold weight or primary colour inside it makes one section shout next to its siblings.
HEADER_OPEN = re.compile(r'\bheader:\s*\{')
HEADER_FONT_PATTERN = re.compile(
    r'\.cyText\(\s*\.(?:sectionTitle|cardTitle|headline|largeTitle|title\w*|display\w*)\b'
    r'|\.font\(\s*\.(?:headline|largeTitle|title\w*)\b'
    r'|\.(?:bold|fontWeight)\(\s*(?:\.(?:bold|semibold|heavy|black))?\s*\)'
    # `CYSectionHeader` is the `.headline` header for scroll pages; inside a List/Form `header:` it must be system text.
    r'|\bCYSectionHeader\(')
RAW_COUNT = 'raw count'
# One count style (ADA audit cross-screen): a big number is `.cyText(.dataXL)` (largeTitle, bold, rounded, monospaced
# digits), a card stat / price is `.cyText(.numericTitle)` (title3, semibold, monospaced digits). A raw
# `.font(.largeTitle…|.title…|.title2…|.title3…)` + `.monospacedDigit()` on the same chain draws it in a second face
# and weight.
RAW_COUNT_FONT = re.compile(r'\.font\(\s*\.(?:largeTitle|title|title2|title3)\b')
RAW_COUNT_DIGITS = re.compile(r'\.monospacedDigit\(\)')
RATING_HUE = 'rating hue'
# One rating / starred hue (ADA audit §3 accent colours): review stars, place rating and the starred-friend mark were
# orange on some pages and yellow on others. A `star.fill` drawn in a raw `.yellow` / `.orange` within 6 lines uses
# `CYColor.ratingStar` (a first-place / medal star uses `CYColor.medalGold`). Celebration art keeps its own colour
# through an allowed entry with a reason.
RATING_STAR = re.compile(r'systemName:\s*(?:[^)]*\?\s*)?"star\.fill"')
RATING_RAW_HUE = re.compile(r'\.(?:foregroundStyle|foregroundColor|tint)\(\s*(?:Color)?\.(?:yellow|orange)\b')
STATUS_HUE = 'status hue'
# One status hue (ADA audit §3 accent colours, ds-consistency run 47): a done / warning / failed glyph drew in the raw
# system `.green` / `.orange` / `.red` on some pages and in `CYColor.successText` / `warningText` / `dangerText` on
# others. A `checkmark…` / `exclamationmark…` / `xmark…` symbol with a raw green / orange / red foreground on the same
# line uses the semantic token. Games, story, maps and other effect surfaces keep their own HUD colours.
STATUS_GLYPH = re.compile(r'systemName:\s*"(?:checkmark|exclamationmark|xmark)[\w.]*"')
STATUS_RAW_HUE = re.compile(r'\.(?:foregroundStyle|foregroundColor)\(\s*(?:Color)?\.(?:green|orange|red)\b')
EFFECT_ON_CLEAN = 'effect on clean page'
# OWNER RULE 3 (11-28): the 11-26 no-op effects are restored, but only for games, story flow, payment, maps and
# celebration moments. Every other page stays clean (system components, no glow / foil / particles / glass).
EFFECT_PATTERN = re.compile(
    r'(?<![\w.])(?:CYBurst|CYConfettiBurst|CYStarBloom|CYFogLayer|CYEdgeGlow|CYCelebrationMoment|CYJoinReward|'
    r'CYGlassCarousel|CYGlassSliver|CYCarouselBackdrop|CYWeatherScene)\s*[(<]'
    r'|\.(?:cyFoil|cyFoilSheen|cyEdgeGlow|cyUnlockCelebration)\s*\(')
EFFECT_SURFACE_DIRS = ('App/NativeR2/Games/', 'App/NativeR2/Story/', 'App/NativeR2/FreeExplore/',
                       'App/NativeR2/CityOrientation/', 'App/NativeR2/MapHome/', 'App/NativeR2/Motion/')
# Page files of the distinctive surfaces, by name: play / game / chapter / story, payment, journey and roam maps,
# celebration and reward moments.
EFFECT_SURFACE_NAME = re.compile(
    r'^App/(?:[^/]+/)*(?:Play(?!er)\w*|\w*Game\w*|\w*Chapter\w*|\w*Story\w*|\w*Pay(?!out)\w*|\w*Checkout\w*|'
    r'JourneyReport\w*|FreeExplor\w*|RoamLive\w*|RoamFinish\w*|RoamFog\w*|CityRoam\w*|RoamCreatedStamp\w*|'
    r'RoamStampCamera\w*|\w*StampCapture\w*|\w*Celebration\w*|\w*Reward\w*)\.swift$')
# The kit itself: definitions and the celebration / album / medal hosts that compose them.
EFFECT_KIT_FILES = tuple('App/DesignSystem/' + n + '.swift' for n in (
    'CYBurst', 'CYEdgeGlow', 'CYFoil', 'CYRoamKit', 'CYSignature', 'CYStarBloom', 'CYGlassCarousel', 'CYAlbum',
    'CYCollectible', 'CYBadgeCraft', 'CYCelebrationViews', 'CYCelebrationEngine', 'CYJoinReward', 'CYNightGlass',
    'CYWeatherScene'))


def effect_surface(rel):
    return rel in EFFECT_KIT_FILES or rel.startswith(EFFECT_SURFACE_DIRS) or bool(EFFECT_SURFACE_NAME.match(rel))


KINDS = (RAW_FONT, TRACKING, ROOT_TITLE, PUSHED_LARGE, TITLE_MODE, HIDDEN_NAV, CUSTOM_BACK, BUTTON_STYLE, POPUP_SCRIM,
         RAW_COLOUR, LIST_STYLE, CUSTOM_SHEET, CUSTOM_TABS, FONT_DESIGN, CUSTOM_SEARCH, TEXT_ON_ART, RAW_SEGMENTED,
         LEADING_ACTION, DONE_LEADING, RAW_RADIUS, LINE_SPACING, STATUS_CAPSULE, SILENT_SPINNER, BUSY_SWAP, HAND_DIVIDER,
         ALL_CAPS, GRID_LINK, FIXED_SURFACE, DARK_BACKING, LOCALE_MONEY, REFRESH_NO_PULL, SECTION_SPACING, DUPLICATE_TYPE,
         UNDECLARED_STATE, UNTYPED_HAPTIC, HEADER_FONT, EFFECT_ON_CLEAN, RAW_COUNT,
         MANUAL_PAGING, RATING_HUE, STATUS_HUE)

# The five player tab roots (Core/RootTab.swift, QuestifyApp root TabView) and the files that own their title.
# 漫游 is the full-screen map home: its chrome is allowed in the baseline instead.
TAB_ROOTS = (
    'App/HomeFeedView.swift',                 # 首页 (SessionHomeFeedView -> HomeFeedView)
    'App/DiscoveryTemplateBrowserView.swift', # 发布 (PublishTabRootView -> isTabRoot: true)
    'App/ClubHomeView.swift',                 # 俱乐部
    'App/AccountView.swift',                  # 我的 (signed in, PassportView -> AccountView)
    'App/WelcomeView.swift',                  # 我的 (signed out)
)

SKIP_PARTS = ('Merchant', 'Fixture', 'DesignFixtures/', 'Diagnostics')
FONT_SCALE_FILES = ('App/DesignSystem/CYDesignTokens.swift',)
COLOUR_EXEMPT_PREFIXES = ('App/DesignSystem/', 'App/Theme/')

FONT_PATTERNS = (
    re.compile(r'\.system\s*\(\s*size\s*:'),
    re.compile(r'\.font\s*\(\s*\.custom\s*\('),
    re.compile(r'\bFont\.custom\s*\('),
    re.compile(r'\bUIFont\.systemFont\s*\(\s*ofSize\s*:'),
    re.compile(r'\bUIFont\s*\(\s*name\s*:'),
)
SCALED_METRIC = re.compile(r'@ScaledMetric\b[^\n]*?\bvar\s+(\w+)')
SYSTEM_SIZE_ARG = re.compile(r'\.system\s*\(\s*size\s*:\s*(\w+)\s*[,)]')
TRACKING_PATTERN = re.compile(r'\.(?:tracking|kerning)\s*\(')
LARGE_PATTERN = re.compile(r'\.navigationBarTitleDisplayMode\s*\(\s*\.large\s*\)')
TITLE_PATTERN = re.compile(r'\.(?:navigationTitle|appNavigationTitle)\s*\(')
ANY_MODE_PATTERN = re.compile(r'\.navigationBarTitleDisplayMode\s*\(|\.cyPageTitle\s*\(|\.cyRootHeader\s*\(')
TITLE_MODE_EXEMPT = ('App/AppLocalizedString.swift',)
ROOT_HEADER_PATTERN = re.compile(r'\.cyRootHeader\s*\(')
HIDDEN_PATTERNS = (
    re.compile(r'\.navigationBarHidden\s*\(\s*true\s*\)'),
    re.compile(r'\.toolbar\s*\(\s*\.hidden\s*,\s*for\s*:\s*\.navigationBar\s*\)'),
    re.compile(r'\.toolbarBackground\s*\(\s*\.hidden\s*,\s*for\s*:\s*\.navigationBar\s*\)'),
    re.compile(r'\.navigationBarBackButtonHidden\s*\(\s*true\s*\)'),
)
# MP-style custom navigation chrome built from the design kit instead of the system bar (`cyGuardedBack` is the
# approved guarded exit and lives inside the design system).
CUSTOM_BACK_PATTERN = re.compile(r'(?<![\w.])(?:CYNavBar|CYBareBackButton|CYHeroBackButton)\s*[(<]')
# One button system: `.borderedProminent` / `.bordered` / `.borderless` or the CY styles in App/DesignSystem.
BUTTON_STYLE_PATTERNS = (
    re.compile(r'\bstruct\s+\w+\s*:\s*(?:Primitive)?ButtonStyle\b'),
    re.compile(r'\.buttonStyle\s*\(\s*\.questifyPrimary\s*\)'),
)
# A hand-made dimmed full-screen scrim = an MP popup copied as an overlay. MP popups are `.sheet` with detents.
POPUP_SCRIM_PATTERN = re.compile(r'Color\.black\.opacity\(\s*0?\.[2-8]\d*\s*\)\s*\.ignoresSafeArea\(')
# One list pattern: the app's list pages are `.insetGrouped` (the iOS Settings look); anything else is a mix.
LIST_STYLE_PATTERN = re.compile(r'\.listStyle\s*\(\s*(?!\.insetGrouped\b|InsetGroupedListStyle\s*\()([^)]*\)?)')
# Hand-made MP popups / half-screens instead of `.sheet` + detents.
CUSTOM_SHEET_PATTERNS = (
    re.compile(r'\.accessibilityAddTraits\s*\(\s*(?:\[[^\]]*)?\.isModal\b'),
    re.compile(r'(?:CYColor\.bgOverlay|Color\.black\.opacity\([^)]*\))\s*\.ignoresSafeArea\([^)]*\)\s*\.onTapGesture\b'),
    re.compile(r'\bCapsule\(\)[^\n]*\.frame\(\s*width:\s*[34]\d(?:\.\d+)?\s*,\s*height:\s*[4-6](?:\.\d+)?\s*\)'),
)
# Hand-made tab bars: a ForEach over tabs / segments whose items are Buttons tested against the selection.
TABS_FOREACH = re.compile(r'\bForEach\s*\([^\n]*\b(?:tabs|segments|\w*(?:Tab|Segment)\w*\.allCases)\b')
TABS_BUTTON = re.compile(r'\bButton\b')
TABS_SELECTED = re.compile(r'==\s*(?:self\.)?(?:selection|selected\w*|active|current|state\.selected\w*)\b|'
                           r'\b(?:isSelected|on)\s*=\s*\w+(?:\.\w+)?\s*==')
DS_TAB_BAR = re.compile(r'(?<![\w.])(?:CYNightTabBar|CYDomainTabBar)\s*\(')
APP_ROOT = 'App/QuestifyApp.swift'
# Hand-drawn search fields: the search symbol drawn next to a TextField.
BACKGROUND_OPEN = re.compile(r'\.background\s*[({]')
SEARCH_GLYPH = re.compile(r'Image\(systemName:\s*"magnifyingglass"\)')
FONT_DESIGN_PATTERN = re.compile(r'\bdesign\s*:\s*\.(?:rounded|serif)\b|\.fontDesign\s*\(\s*\.(?:rounded|serif)\b')
COLOUR_PATTERNS = (
    re.compile(r'(?<![\w.])(?:UI)?Color\s*\(\s*red\s*:'),
    re.compile(r'(?<![\w.])(?:UI)?Color\s*\(\s*hex\s*:'),
    re.compile(r'"#[0-9A-Fa-f]{6}(?:[0-9A-Fa-f]{2})?"'),
    re.compile(r'\b0x[0-9A-Fa-f]{6}\b'),
)


def player_files():
    for path in sorted((ROOT / 'App').rglob('*.swift')):
        rel = path.relative_to(ROOT).as_posix()
        if any(part in rel for part in SKIP_PARTS):
            continue
        yield rel, path


def strip_comments(line, state):
    """Drops `//` and `/* */` comments outside string literals. `state` carries an open block comment."""
    if not state['block'] and '/' not in line:
        return line
    out = []
    i = 0
    in_string = False
    while i < len(line):
        if state['block']:
            end = line.find('*/', i)
            if end < 0:
                return ''.join(out)
            state['block'] = False
            i = end + 2
            continue
        ch = line[i]
        if in_string:
            out.append(ch)
            if ch == '\\' and i + 1 < len(line):
                out.append(line[i + 1])
                i += 2
                continue
            if ch == '"':
                in_string = False
            i += 1
            continue
        if ch == '"':
            in_string = True
            out.append(ch)
            i += 1
            continue
        if line.startswith('//', i):
            break
        if line.startswith('/*', i):
            state['block'] = True
            i += 2
            continue
        out.append(ch)
        i += 1
    return ''.join(out)


def code_lines(text):
    """(line number, code) pairs without comments and without `#Preview { ... }` blocks."""
    state = {'block': False}
    preview_depth = None
    for number, raw in enumerate(text.split('\n'), start=1):
        code = strip_comments(raw, state)
        if preview_depth is None and re.match(r'\s*#Preview\b', code):
            preview_depth = 0
            opened = False
            for ch in code:
                if ch == '{':
                    preview_depth += 1
                    opened = True
                elif ch == '}':
                    preview_depth -= 1
            if opened and preview_depth <= 0:
                preview_depth = None
            continue
        if preview_depth is not None:
            preview_depth += code.count('{') - code.count('}')
            if preview_depth <= 0 and '}' in code:
                preview_depth = None
            continue
        yield number, code


def header_font_hits(lines):
    """`header: { … }` closures (brace-balanced over comment-free code lines) that set a heading font or weight."""
    out = []
    for index, (number, code) in enumerate(lines):
        match = HEADER_OPEN.search(code)
        if not match:
            continue
        depth = 1
        body = [(number, code[match.end():])]
        for later_number, later in lines[index + 1:index + 40]:
            body.append((later_number, later))
        for part_number, part in body:
            cut = len(part)
            for pos, ch in enumerate(part):
                depth += {'{': 1, '}': -1}.get(ch, 0)
                if depth == 0:
                    cut = pos
                    break
            if HEADER_FONT_PATTERN.search(part[:cut]):
                out.append((part_number, HEADER_FONT, part.strip()))
            if depth == 0:
                break
    return out


HEADER_CALL = re.compile(r'\bheader:\s*\{\s*([A-Z]\w*)\s*\(')
STRUCT_VIEW = re.compile(r'\bstruct\s+([A-Z]\w*)\s*:\s*View\b')
_WRAPPER_INDEX = None


def _struct_bodies(lines):
    """`struct Name: View { … }` bodies (brace-balanced) in one file: name -> [(number, code)]."""
    out = {}
    for index, (number, code) in enumerate(lines):
        match = STRUCT_VIEW.search(code)
        if not match:
            continue
        depth, started, body = 0, False, []
        for later_number, later in lines[index:index + 80]:
            body.append((later_number, later))
            for ch in later:
                if ch == '{':
                    depth, started = depth + 1, True
                elif ch == '}':
                    depth -= 1
            if started and depth <= 0:
                break
        out.setdefault(match.group(1), body)
    return out


def _wrapper_index():
    """Every player-file View struct body, so a header closure that calls a wrapper is checked across files."""
    global _WRAPPER_INDEX
    if _WRAPPER_INDEX is None:
        _WRAPPER_INDEX = {}
        for rel, path in player_files():
            if rel.startswith('App/DesignSystem/'):
                continue
            text = path.read_text(encoding='utf-8', errors='replace')
            for name, body in _struct_bodies(list(code_lines(text))).items():
                _WRAPPER_INDEX.setdefault(name, (rel, body))
    return _WRAPPER_INDEX


def header_wrapper_font_hits(lines):
    """`header: { Wrapper(…) }`: the wrapper View's own body must not set a heading font either (reported at its call)."""
    out = []
    local = _struct_bodies(lines)
    for index, (number, code) in enumerate(lines):
        match = HEADER_CALL.search(code)
        if not match:
            continue
        name = match.group(1)
        body = local.get(name) or _wrapper_index().get(name, (None, None))[1]
        if not body:
            continue
        for body_number, body_code in body:
            if HEADER_FONT_PATTERN.search(body_code):
                out.append((number, HEADER_FONT, f'{name} (line {body_number}): {body_code.strip()}'))
                break
    return out


def scan_file(rel, text):
    hits = []
    lines = list(code_lines(text))
    font_scale = rel in FONT_SCALE_FILES or rel.startswith('App/Theme/')
    colour_exempt = rel.startswith(COLOUR_EXEMPT_PREFIXES)
    design_system = rel.startswith('App/DesignSystem/')
    is_root = rel in TAB_ROOTS
    clean_effects_ok = effect_surface(rel)
    # `.system(size: x)` where `x` is an `@ScaledMetric` scales with Dynamic Type: that is the approved pattern.
    scaled = set(SCALED_METRIC.findall(text))
    prev_code = ''
    for number, code in lines:
        if DARK_BACKING_PATTERN.search(code) and (MATERIAL_BACKGROUND.search(prev_code) or MATERIAL_BACKGROUND.search(code)):
            hits.append((number, DARK_BACKING, code.strip()))
        prev_code = code
        sized = SYSTEM_SIZE_ARG.findall(code)
        scaled_only = bool(sized) and all(name in scaled for name in sized) and not any(
            p.search(code) for p in FONT_PATTERNS[1:])
        if not font_scale and not scaled_only and any(p.search(code) for p in FONT_PATTERNS):
            hits.append((number, RAW_FONT, code.strip()))
        if not font_scale and TRACKING_PATTERN.search(code):
            hits.append((number, TRACKING, code.strip()))
        if LARGE_PATTERN.search(code) and not is_root and not design_system:
            hits.append((number, PUSHED_LARGE, code.strip()))
        if any(p.search(code) for p in HIDDEN_PATTERNS):
            hits.append((number, HIDDEN_NAV, code.strip()))
        if not design_system and CUSTOM_BACK_PATTERN.search(code):
            hits.append((number, CUSTOM_BACK, code.strip()))
        if not design_system and any(p.search(code) for p in BUTTON_STYLE_PATTERNS):
            hits.append((number, BUTTON_STYLE, code.strip()))
        if not design_system and POPUP_SCRIM_PATTERN.search(code):
            hits.append((number, POPUP_SCRIM, code.strip()))
        if not colour_exempt and any(p.search(code) for p in COLOUR_PATTERNS):
            hits.append((number, RAW_COLOUR, code.strip()))
        if not design_system and LIST_STYLE_PATTERN.search(code):
            hits.append((number, LIST_STYLE, code.strip()))
        if not design_system and any(p.search(code) for p in CUSTOM_SHEET_PATTERNS):
            hits.append((number, CUSTOM_SHEET, code.strip()))
        if not font_scale and not design_system and FONT_DESIGN_PATTERN.search(code):
            hits.append((number, FONT_DESIGN, code.strip()))
        if not design_system and RAW_SEGMENTED_PATTERN.search(code):
            hits.append((number, RAW_SEGMENTED, code.strip()))
        if not colour_exempt and RAW_RADIUS_PATTERN.search(code):
            hits.append((number, RAW_RADIUS, code.strip()))
        if not colour_exempt and LINE_SPACING_PATTERN.search(code):
            hits.append((number, LINE_SPACING, code.strip()))
        if not colour_exempt and SECTION_SPACING_PATTERN.search(code):
            hits.append((number, SECTION_SPACING, code.strip()))
        if not clean_effects_ok and EFFECT_PATTERN.search(code):
            hits.append((number, EFFECT_ON_CLEAN, code.strip()))
        if UNTYPED_HAPTIC_PATTERN.search(code):
            hits.append((number, UNTYPED_HAPTIC, code.strip()))
        if not colour_exempt and HAND_DIVIDER_PATTERN.search(code):
            hits.append((number, HAND_DIVIDER, code.strip()))
        if ALL_CAPS_PATTERN.search(code):
            hits.append((number, ALL_CAPS, code.strip()))
        if FIXED_SURFACE_PATTERN.search(code):
            hits.append((number, FIXED_SURFACE, code.strip()))
        if LOCALE_MONEY_PATTERN.search(code):
            hits.append((number, LOCALE_MONEY, code.strip()))
        if not colour_exempt and STATUS_CAPSULE_SHAPE.search(code) and STATUS_CAPSULE_TINT.search(code) and 'strokeBorder' not in code:
            hits.append((number, STATUS_CAPSULE, code.strip()))
        if not design_system and rel != APP_ROOT and DS_TAB_BAR.search(code):
            hits.append((number, CUSTOM_TABS, code.strip()))
    if not design_system:
        for index, (number, code) in enumerate(lines):
            if (SILENT_SPINNER_PATTERN.match(code) and index + 1 < len(lines) and SILENT_SPINNER_FRAME.match(lines[index + 1][1])) \
                    or SILENT_SPINNER_INLINE.search(code):
                hits.append((number, SILENT_SPINNER, code.strip()))
            swap = BUSY_SWAP_ONE_LINE.search(code) or (SILENT_SPINNER_PATTERN.match(code) and index + 1 < len(lines)
                                                       and BUSY_SWAP_ELSE.match(lines[index + 1][1]))
            if swap:
                window = [c for _, c in lines[max(0, index - 4):index + 1]]
                if any(BUSY_SWAP_BUTTON.search(c) for c in window) and not any(BUSY_SWAP_EXEMPT.search(c) for c in window):
                    hits.append((number, BUSY_SWAP, code.strip()))
        for index, (number, code) in enumerate(lines):
            if not LEADING_PLACEMENT.search(code):
                continue
            window = ' '.join(c for _, c in lines[index:index + 3])
            if LEADING_ACTION_CONTENT.search(window):
                hits.append((number, LEADING_ACTION, code.strip()))
        for index, (number, code) in enumerate(lines):
            if not DONE_LEADING_PLACEMENT.search(code):
                continue
            item = [code] + [c for _, c in lines[index + 1:index + 3]]
            cut = next((i for i, c in enumerate(item) if i and 'ToolbarItem' in c), len(item))
            window = ' '.join(item[:cut])
            around = ' '.join(c for _, c in lines[max(0, index - 8):index + 9])
            if DONE_BUTTON.search(window) and 'confirmationAction' not in around:
                hits.append((number, DONE_LEADING, code.strip()))
        for index, (number, code) in enumerate(lines):
            if not TABS_FOREACH.search(code):
                continue
            window = ' '.join(c for _, c in lines[index:index + 8])
            if TABS_BUTTON.search(window) and TABS_SELECTED.search(window):
                hits.append((number, CUSTOM_TABS, code.strip()))
        for index, (number, code) in enumerate(lines):
            match = BACKGROUND_OPEN.search(code)
            if match and any('CYCoverArt(' in c for c in [code[match.start():]] + [c for _, c in lines[index + 1:index + 2]]):
                hits.append((number, TEXT_ON_ART, code.strip()))
        for index, (number, code) in enumerate(lines):
            if not GRID_OPEN.search(code):
                continue
            container = next((m.group(1) for _, c in reversed(lines[max(0, index - 80):index])
                              for m in [GRID_CONTAINER.search(c)] if m), None)
            if container != 'List':
                continue
            cell = lines[index + 1:index + 10]
            link = next(((n, c) for n, c in cell if 'NavigationLink' in c), None)
            if not link:
                # The cell may be a same-file helper (`link(slot…)`) whose body is the NavigationLink.
                called = {m.group(1) for _, c in cell for m in GRID_HELPER_CALL.finditer(c)}
                for at, (_, c) in enumerate(lines):
                    m = GRID_HELPER_DECL.search(c)
                    if m and m.group(1) in called:
                        link = next(((n, d) for n, d in lines[at:at + 12] if 'NavigationLink' in d), None)
                        if link:
                            break
            if link:
                hits.append((link[0], GRID_LINK, link[1].strip()))
        if not any('.refreshable' in c for _, c in lines) and any(REFRESH_SCROLL.search(c) for _, c in lines):
            for index, (number, code) in enumerate(lines):
                if REFRESH_GLYPH.search(code) and any(REFRESH_TOOLBAR.search(c) for _, c in lines[max(0, index - 8):index + 1]):
                    hits.append((number, REFRESH_NO_PULL, code.strip()))
        for index, (number, code) in enumerate(lines):
            if SEARCH_GLYPH.search(code) and any('TextField(' in c for _, c in lines[index:index + 4]):
                hits.append((number, CUSTOM_SEARCH, code.strip()))
    if not design_system and rel not in TITLE_MODE_EXEMPT and not any(ANY_MODE_PATTERN.search(c) for _, c in lines):
        for number, code in lines:
            if TITLE_PATTERN.search(code):
                hits.append((number, TITLE_MODE, code.strip()))
    if not design_system:
        hits.extend(header_font_hits(lines))
        hits.extend(header_wrapper_font_hits(lines))
        hits.extend(manual_paging_hits(lines))
    if not design_system and not effect_surface(rel):
        # Games / story / play keep their own HUD numerals (OWNER RULE 3 level A).
        for index, (number, code) in enumerate(lines):
            if RAW_COUNT_FONT.search(code) and 'Image(' not in code and \
                    (RAW_COUNT_DIGITS.search(code) or (index + 1 < len(lines)
                                                       and lines[index + 1][1].lstrip().startswith('.monospacedDigit()'))):
                hits.append((number, RAW_COUNT, code.strip()))
    if not design_system:
        for index, (number, code) in enumerate(lines):
            if RATING_STAR.search(code):
                for near_number, near in lines[index:index + 7]:
                    if RATING_RAW_HUE.search(near):
                        hits.append((near_number, RATING_HUE, near.strip()))
                        break
    if not design_system and not effect_surface(rel):
        for number, code in lines:
            if STATUS_GLYPH.search(code) and STATUS_RAW_HUE.search(code[STATUS_GLYPH.search(code).start():]):
                hits.append((number, STATUS_HUE, code.strip()))
    if is_root:
        has_large = any(ROOT_HEADER_PATTERN.search(c) or LARGE_PATTERN.search(c) for _, c in lines)
        if not has_large:
            hits.append((1, ROOT_TITLE, 'tab root without .cyRootHeader(...) / .navigationBarTitleDisplayMode(.large)'))
    return hits


TYPE_DECL = re.compile(r'^\s*(?:@[\w.]+(?:\([^)]*\))?\s+)*((?:(?:public|internal|private|fileprivate|open|final|'
                       r'indirect|nonisolated|package)\s+)*)(struct|class|enum|protocol|actor|typealias|extension)\s+'
                       r'([A-Za-z_][\w.]*)([^{]*)')
DECL_NAMES = re.compile(r'\b(?:var|let)\s+([A-Za-z_]\w*)')
DECL_TUPLES = re.compile(r'\b(?:var|let)\s*\(([^)]*)\)')
DECL_LINE = re.compile(r'\b(?:let|var)\b')
DECL_LIST = re.compile(r',\s*([A-Za-z_]\w*)\s*[:=]')
CLOSURE_BINDINGS = re.compile(r'\$([A-Za-z_]\w*)\s*(?=,[^{}]*\bin\b|\bin\b)')
CAPTURE_LIST = re.compile(r'\[\s*((?:(?:weak|unowned)\s+)?[A-Za-z_]\w*\s*=[^\[\]]*)\]\s*(?:\([^)]*\)\s*)?(?:async\s+)?in\b')
CAPTURE_NAMES = re.compile(r'(?:^|,)\s*(?:(?:weak|unowned)\s+)?([A-Za-z_]\w*)\s*=')
INOUT_NAMES = re.compile(r'\b([A-Za-z_]\w*)\s*:\s*inout\b')
CASE_NAMES = re.compile(r'^\s*(?:indirect\s+)?case\s+([^:=(]+?)\s*(?:=|\(|$)')
BINDING_USE = re.compile(r'(?<![\w$.\\])\$([a-z_]\w*)')
ASSIGN_USE = re.compile(r'(?:(?<![\w$.\\])|\bself\.)([a-z_]\w*)\s*(?:[-+*/]?=)(?!=)')
NOT_ASSIGNABLE = {'_', 'self', 'super', 'try', 'await', 'return', 'in', 'let', 'var', 'case', 'where', 'if', 'guard',
                  'else', 'some', 'any', 'inout', 'static', 'lazy', 'weak', 'private', 'fileprivate', 'public'}


def blank_strings(code, state):
    """Replaces string-literal contents with spaces (keeps the quotes); `state['multi']` tracks a `\"\"\"` block."""
    if not state.get('multi') and '"' not in code:
        return code
    out = []
    i = 0
    in_string = False
    while i < len(code):
        if state.get('multi'):
            end = code.find('\"\"\"', i)
            if end < 0:
                out.append(' ' * (len(code) - i))
                return ''.join(out)
            state['multi'] = False
            out.append(' ' * (end - i) + '\"\"\"')
            i = end + 3
            continue
        if not in_string and code.startswith('\"\"\"', i):
            state['multi'] = True
            out.append('\"\"\"')
            i += 3
            continue
        ch = code[i]
        if in_string:
            if ch == '\\\\' and i + 1 < len(code):
                out.append('  ')
                i += 2
                continue
            if ch == '"':
                in_string = False
                out.append(ch)
            else:
                out.append(' ')
            i += 1
            continue
        if ch == '"':
            in_string = True
        out.append(ch)
        i += 1
    return ''.join(out)


def module_files():
    for top in ('App', 'Core'):
        for path in sorted((ROOT / top).rglob('*.swift')):
            yield path.relative_to(ROOT).as_posix(), path


def parse_module():
    """Top-level declarations and their bodies for every App/ + Core/ file (one Swift module)."""
    decls = []   # (name, kind, access, file, line, if-stack, inheritance)
    bodies = {}  # type name -> [(file, [(line, code)])]
    globals_declared = set()
    for rel, path in module_files():
        text = path.read_text(encoding='utf-8', errors='replace')
        sstate = {}
        depth = 0
        if_stack = []
        if_counter = 0
        current = None
        for number, code in code_lines(text):
            code = blank_strings(code, sstate)
            stripped = code.strip()
            if stripped.startswith('#if'):
                if_counter += 1
                if_stack.append([f'{rel}#{if_counter}', 0])
            elif stripped.startswith('#elseif') or stripped.startswith('#else'):
                if if_stack:
                    if_stack[-1][1] += 1
            elif stripped.startswith('#endif'):
                if if_stack:
                    if_stack.pop()
            if depth == 0 and current is None:
                m = TYPE_DECL.match(code)
                if m:
                    access, kind, name, rest = m.group(1), m.group(2), m.group(3), m.group(4)
                    if kind != 'extension':
                        decls.append((name, kind, access, rel, number, tuple(tuple(x) for x in if_stack), rest))
                    if '{' in code and kind in ('struct', 'class', 'enum', 'actor', 'extension'):
                        current = (name.split('.')[-1] if kind == 'extension' else name, [])
                elif not stripped.startswith('func') and depth == 0:
                    globals_declared.update(DECL_NAMES.findall(code))
            if current is not None:
                current[1].append((number, code))
            depth += code.count('{') - code.count('}')
            if current is not None and depth <= 0:
                bodies.setdefault(current[0], []).append((rel, current[1]))
                current = None
                depth = 0
    return decls, bodies, globals_declared


def exclusive(a, b):
    """True when two `#if` stacks put the declarations in different branches of the same `#if` group."""
    branches = dict(a)
    return any(key in branches and branches[key] != branch for key, branch in b)


def duplicate_type_hits(decls):
    by_name = {}
    for d in decls:
        if d[1] == 'typealias' and '.' in d[0]:
            continue
        by_name.setdefault(d[0], []).append(d)
    hits = {}
    for name, rows in by_name.items():
        if len(rows) < 2:
            continue
        for row in rows:
            clashes = []
            for other in rows:
                if other is row or exclusive(row[5], other[5]):
                    continue
                private_row = 'private' in row[2]
                private_other = 'private' in other[2]
                if (private_row or private_other) and row[3] != other[3]:
                    continue
                clashes.append(f'{other[3]}:{other[4]}')
            if clashes:
                hits.setdefault(row[3], []).append(
                    (row[4], DUPLICATE_TYPE, f'{row[1]} {name} also declared at ' + ', '.join(clashes[:3])))
    return hits


def undeclared_state_hits(decls, bodies, globals_declared):
    views = {d[0] for d in decls if d[1] == 'struct' and re.search(r'\bView\b', d[6] or '')}
    hits = {}
    for name in sorted(views):
        parts = bodies.get(name, [])
        declared = set(globals_declared)
        for _, lines in parts:
            for _, code in lines:
                declared.update(DECL_NAMES.findall(code))
                declared.update(INOUT_NAMES.findall(code))
                declared.update(CLOSURE_BINDINGS.findall(code))
                for group in CAPTURE_LIST.findall(code):
                    declared.update(CAPTURE_NAMES.findall(group))
                if DECL_LINE.search(code):
                    declared.update(DECL_LIST.findall(code))
                for group in DECL_TUPLES.findall(code):
                    declared.update(re.findall(r'[A-Za-z_]\w*', group))
                m = CASE_NAMES.match(code)
                if m:
                    declared.update(re.findall(r'(?<![.\w])([a-z_]\w*)', m.group(1)))
        for rel, lines in parts:
            for number, code in lines:
                used = set(BINDING_USE.findall(code))
                used.update(n for n in ASSIGN_USE.findall(code) if n not in NOT_ASSIGNABLE)
                for n in sorted(used):
                    if n in declared or (n.startswith('_') and n[1:] in declared):
                        continue
                    hits.setdefault(rel, []).append(
                        (number, UNDECLARED_STATE, f'{name}: `{n}` used but never declared: {code.strip()}'))
    return hits


def module_hits():
    decls, bodies, globals_declared = parse_module()
    out = {}
    for source in (duplicate_type_hits(decls), undeclared_state_hits(decls, bodies, globals_declared)):
        for rel, rows in source.items():
            out.setdefault(rel, []).extend(rows)
    return out


def scan():
    result = {}
    for rel, path in player_files():
        hits = scan_file(rel, path.read_text(encoding='utf-8', errors='replace'))
        if hits:
            result[rel] = hits
    for rel, hits in module_hits().items():
        result.setdefault(rel, []).extend(hits)
    missing = [r for r in TAB_ROOTS if not (ROOT / r).exists()]
    for rel in missing:
        result[rel] = [(0, ROOT_TITLE, 'tab root file is missing: update TAB_ROOTS')]
    return result


def counts(hits):
    out = {}
    for _, kind, _ in hits:
        out[kind] = out.get(kind, 0) + 1
    return out


UNMOUNTED_REASON = 'unmounted internal screen'
VIEW_DECL_PATTERN = re.compile(r'^(?:public\s+|internal\s+|private\s+|fileprivate\s+)?struct\s+([A-Za-z_][A-Za-z0-9_]*)\s*:\s*View\b', re.M)


def mounted_unmounted(allowed):
    """Allowed entries justified as unmounted whose view is now called from a non-fixture App file."""
    marked = sorted(rel for rel, kinds in allowed.items()
                    if any(str(r).startswith(UNMOUNTED_REASON) for r in kinds.values()))
    if not marked:
        return []
    names = {}
    for rel in marked:
        path = ROOT / rel
        if path.exists():
            for name in VIEW_DECL_PATTERN.findall(path.read_text(encoding='utf-8')):
                names[name] = rel
    if not names:
        return []
    call = re.compile(r'\b(' + '|'.join(sorted(names)) + r')\s*\(')
    out = []
    for path in sorted((ROOT / 'App').rglob('*.swift')):
        rel = path.relative_to(ROOT).as_posix()
        if 'Fixture' in rel:
            continue
        for match in call.finditer(path.read_text(encoding='utf-8')):
            if names[match.group(1)] != rel:
                out.append(f'{names[match.group(1)]}: {match.group(1)} is now called from {rel}')
    return sorted(set(out))


def load_baseline():
    if not BASELINE.exists():
        return {'allowed': {}, 'baseline': {}}
    data = json.loads(BASELINE.read_text(encoding='utf-8'))
    data.setdefault('allowed', {})
    data.setdefault('baseline', {})
    return data


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--list', action='store_true', help='print every current hit')
    parser.add_argument('--update', action='store_true', help='lower the baseline to the current tree')
    parser.add_argument('--allow-increase', action='store_true', help='with --update, also raise counts')
    args = parser.parse_args()

    data = load_baseline()
    allowed = data['allowed']
    baseline = data['baseline']
    found = scan()

    failures = []
    totals = {k: 0 for k in KINDS}
    allowed_totals = {k: 0 for k in KINDS}
    current = {}
    for rel, hits in sorted(found.items()):
        file_allowed = allowed.get(rel, {})
        kept = [h for h in hits if h[1] not in file_allowed]
        for h in hits:
            if h[1] in file_allowed:
                allowed_totals[h[1]] += 1
        if args.list:
            for number, kind, code in hits:
                tag = ' (allowed)' if kind in file_allowed else ''
                print(f'{rel}:{number}: {kind}{tag}: {code[:160]}')
        c = counts(kept)
        if c:
            current[rel] = c
        for kind, n in c.items():
            totals[kind] += n
            limit = baseline.get(rel, {}).get(kind, 0)
            if n > limit:
                lines = [f'{rel}:{num}: {code[:160]}' for num, k, code in kept if k == kind]
                failures.append((rel, kind, n, limit, lines))

    stale = []
    for rel, kinds in sorted(allowed.items()):
        present = {kind for _, kind, _ in found.get(rel, [])}
        for kind in kinds:
            if kind not in present:
                stale.append(f'{rel}: {kind}')

    mounted = mounted_unmounted(allowed)

    below = 0
    for rel, kinds in baseline.items():
        for kind, limit in kinds.items():
            if current.get(rel, {}).get(kind, 0) < limit:
                below += 1

    if args.update:
        new = {}
        for rel in sorted(set(baseline) | set(current)):
            row = {}
            for kind in KINDS:
                now = current.get(rel, {}).get(kind, 0)
                was = baseline.get(rel, {}).get(kind, 0)
                value = now if args.allow_increase else min(now, was)
                if value:
                    row[kind] = value
            if row:
                new[rel] = row
        for row in stale:
            rel, kind = row.split(': ', 1)
            allowed.get(rel, {}).pop(kind, None)
            if rel in allowed and not allowed[rel]:
                del allowed[rel]
        data['baseline'] = new
        BASELINE.write_text(json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + '\n', encoding='utf-8')
        print(f'updated {BASELINE.relative_to(ROOT)}: {sum(sum(r.values()) for r in new.values())} baselined hits')
        if not args.allow_increase and failures:
            print('note: new violations were not baselined (use --allow-increase only after review)')
        return 0 if args.allow_increase or not failures else 1

    summary = ', '.join(f'{k} {totals[k]}' for k in KINDS)
    allowed_summary = sum(allowed_totals.values())
    if mounted:
        print('FAIL design consistency: an "unmounted internal screen" is now mounted; convert its chrome to the')
        print('design system (status words -> CYStatusChip) and remove its "allowed" entry:')
        for row in mounted:
            print(f'  {row}')
        return 1
    if stale and not failures:
        print('FAIL design consistency: stale "allowed" entries (no hit left; remove them from the baseline):')
        for row in stale:
            print(f'  {row}')
        return 1
    if failures:
        print('FAIL design consistency: new violations of the one design system (owner rule 2):')
        for rel, kind, n, limit, lines in failures:
            print(f'  {rel}: {kind} {n} > baseline {limit}')
            for line in lines[:8]:
                print(f'    {line}')
        print('Use Dynamic Type text styles / .cyText(_:), the system letter spacing, cyRootHeader / cyPageTitle,')
        print('the system navigation bar and semantic colours. Intentional chrome goes in "allowed" with a reason.')
        return 1
    print(f'PASS design consistency: {summary}; {allowed_summary} allowed hit(s); '
          f'{below} count(s) below baseline (run --update to ratchet down)')
    return 0


if __name__ == '__main__':
    sys.exit(main())

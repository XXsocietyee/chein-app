# Native iOS r2: Apple-identical front end (owner, 2026-11-26)

**Owner's words:** "I need native UI components, identical to Apple's official ones, not our own designs. We don't want any complex elements, but the overall structure should still reference the mini-program. I didn't see the design of Apple's native Maps, nor the city orientation and free exploration features. I didn't see the story flow or the design of over 20 games. Logically, it should be smoother and more complete than the mini-program."

Owner approved **step 1** (switch to Apple's components) and **step 2** (designs for approval). Step 3 (building the flows) waits for the owner to approve the designs.

## Already done centrally by the coordinator (`ui/combined-r7`, see the commit "native r2 tokens")
- `ThemeDomain.forcedColorScheme`: player, merchant and editor follow the system Light/Dark setting. Only `.game` and `.dark` stay forced dark.
- `CYDomainPalette`: tokens resolve per trait. Brand, selection, primary CTA and tab tint use the system accent (`Color.accentColor`). Surfaces, labels and separators use UIKit semantic colours.
- Do NOT edit `App/DesignSystem/CYDomainPalette.swift`, `App/Theme/Theme.swift`, or `CYDesignTokens.swift`; those belong to the coordinator.

## Component rule (use Apple's; when in doubt, copy what Settings, Maps, Fitness, Books or Wallet do)

| Instead of | Use |
|---|---|
| `CYPillButton` (style primary / secondary / tertiary) | `Button` with `.buttonStyle(.borderedProminent / .bordered / .borderless)`, `.controlSize(.large)`. One prominent button per screen. |
| `CYEmptyState`, custom empty art | `ContentUnavailableView` (system image or the MP image via `MPAsset`) |
| `CYSkeleton`, `CYLoadingStateView` | `.redacted(reason: .placeholder)` on the real layout, or `ProgressView()` |
| `CYListRow`, `CYFactRow`, `CYRowIcon`, custom cards in a list | `List` + `Section` + `Label` / `LabeledContent` / `NavigationLink` (inset grouped) |
| `CYHeroHeader`, `CYHeroBanner`, in-content page titles | `.navigationTitle` (large on tab roots, inline when pushed); one optional `Image` header in the first section |
| `CYStatusChip`, `CYChipRow` | `Text` in `.secondary`, or a `Label` with a tinted SF Symbol; for filters use `Picker(.segmented)` or a toolbar `Menu` |
| `CYSectionHeader` | `Section { } header: { Text(...) }` |
| `CYNoteBanner` | a `Section` footer, or `Label` with `info.circle` |
| `CYConfirmSheet`, `CYConfirmConsequence`, custom modals | `.confirmationDialog`, `.alert`, or `.sheet` with `.presentationDetents([.medium, .large])` |
| custom tab bars (`CYDomainTabBar`, `CYNightTabBar`) | `TabView` with `Tab(...)` |
| custom search fields | `.searchable` |
| `CYField`, custom inputs | `TextField` / `SecureField` / `Toggle` / `Stepper` / `DatePicker` inside `Form` |
| maps | `MapKit` `Map` with `Marker` / `Annotation`, `MapUserLocationButton`, `MapCompass`, `.mapControls`, and a bottom sheet via `.sheet` + `presentationDetents([.height(120), .medium, .large])` + `presentationBackgroundInteraction(.enabled)` (the Apple Maps pattern) |

**Remove:**
- gradients, glows, orbs, foil, fog, glass, bursts and confetti;
- custom fonts and fixed sizes (use `.font(.body)` etc. or `.cyText`, which is already Dynamic Type);
- `CYRGB` / hex colours;
- `.preferredColorScheme(.dark)` on player pages;
- decorative motion (keep only system transitions, `.contentTransition`, `.sensoryFeedback`).

**Keep:**
- MP content, order of sections and copy, and MP images via `MPAsset`;
- `accessibilityIdentifier`s (tests use them);
- every behaviour and request.

**Smoother than the MP:**
- fewer page jumps (a sheet instead of a pushed page for quick actions; inline results instead of pop-ups);
- swipe actions and context menus where Apple uses them;
- pull-to-refresh with `.refreshable`.

## Gates (no compiler in the cloud)
- grep every type, func and modifier you use;
- `python3 tools/check_scaffold.py` must print `PASS structural checks`;
- keep strings in `Resources/Localizable.xcstrings` plus `docs/port/strings/native-r2-<lane>.json`;
- the compile traps in `COORDINATOR-HANDOVER.md` §4;
- don't shadow `@State` with `if let`;
- `try` leads `||`;
- label closure args when two inits differ only by label.

Merge `origin/ui/combined-r7` before every push. Push every 30–45 min to your own branch only. Commit trailer: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. The repo is PUBLIC: no secrets, no MP screenshots.

## Step 2 design specs (one agent per flow) → `docs/design/native-r2/<flow>.md` on branch `design/native-r2-<flow>`
For each screen of the flow:
1. **MP source:** page path, wxml/js file:line, and what it shows and does.
2. **Apple reference:** which Apple app screen it mirrors (e.g. Maps place card, Fitness workout, Books reader) and why.
3. **Native layout:**
   - navigation (stack, sheet + detents, full screen);
   - toolbar items;
   - every component by its SwiftUI name, top to bottom.
4. **States:** loading (redacted), empty (`ContentUnavailableView` + copy), error, signed-out, offline, permission denied (location, camera, motion, mic).
5. **Smoother than the MP:** what we merge, inline or skip, and why the logic stays identical.
6. **App files to change** (`App/...swift`) and the Core types they already use. Don't change Core behaviour.
7. **Figma frame list:** frame names and sizes (iPhone 16, 393×852) so the coordinator can draw them.

Write plain, short, concrete lines. No code beyond SwiftUI view-tree sketches.

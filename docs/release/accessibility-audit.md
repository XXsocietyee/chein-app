# Player app accessibility audit (E1 inclusivity pass)

Branch `ui/e1`, merged with `origin/ui/main`. Lens: design-bar-ada.md #3 INCLUSIVITY.
Evidence: two 16-screen runs of the same list at `accessibility-extra-extra-large` (AX4), dark, via `design-batch.sh e1`.
First sheet (kit fixes only, before the screen fixes): `/Users/fanning/chengyin-refs/design-reports/e1/contact-145700.png`.
Second sheet (after all fixes below): `contact-151511.png`. Screens: d2-home, d2-search, d2-roam, e1-activity-detail, e1-route-detail,
order-detail, d4-detail (club), e3-chat, d2-me, e4-wallet-balance, e4-settings-support, login-player, welcome, e2-badges, e2-stamp-album,
d2-inbox. The second run was a queued duplicate of the batch, not planned; the two sheets are what made the before/after comparison possible.

## Before / after

| # | Area | Before | After | Where |
|---|---|---|---|---|
| 1 | Contrast, dark text tokens | danger `#E5484D` 4.35:1 on card `#1C1C1E`, 3.66 on raised `#2A2A2C`, 3.76 on its own soft chip; info `#4C86FF` 4.20 on raised, 4.16 on soft chip; warning `#D58300` 4.39 on soft chip; placeholder `#868686` 3.93 on raised | danger `#FF6B70` (6.15 / 5.18 / 5.32), info `#7AA5FF` (7.01 / 5.90 / 5.84), warning `#EDA52B`, placeholder `#929292` (4.60 on raised). Secondary `#B7B7B7` (>=7.1) and tertiary `#919191` (>=4.54) on all surfaces already passed. Light/merchant unchanged. Fixed once in the palette (the generated sheet is "do not edit"), not per page | `CYDomainPalette.legible(...)` |
| 2 | Increase Contrast | glass controls and GO circle had a 14% hairline only | 50% / 1.5pt stroke under Increase Contrast; image-card scrim 0.78 -> 0.92 and meta text full opacity | `CYMapChrome`, `CYImageCard` |
| 3 | Reduce Transparency | `.ultraThinMaterial` on glass controls, glass capsule and the dark tab bar regardless of setting | solid near-black fills when Reduce Transparency is on | `CYGlassLabel`, `CYGlassCapsule`, `CYDomainTabBarStyle` |
| 4 | Reduce Motion | map panel detent animations (`.snappy`) ignored the setting. Skeleton pulse, ring pulse, confetti, stagger, celebration, hero pager, press springs were already gated (audited) | all panel detent animations gated | `CYMapScaffold` |
| 5 | Bold Text | audited: kit text uses text styles, so Bold Text applies; no fixed-weight overrides found that fight it | no change | n/a |
| 6 | VoiceOver, `CYListRow` | icon, title, meta, value and chevron were separate stops | one stop "title, meta, value"; chevron and icon tile hidden | `CYListRow` |
| 7 | VoiceOver, `CYStatusChip` | glyph and text could be separate stops | combined into one element | `CYStatusChip` |
| 8 | VoiceOver, `CYImageCard` | combined (already) | stays combined; stacked layout at AX | `CYImageCard` |
| 9 | VoiceOver, GO button | label "GO" only, no reading priority | explicit label, `accessibilitySortPriority(10)` so the single primary map action is reached before the list panel | `CYGoButton` |
| 10 | VoiceOver, collectible tiles | combined; locked and unlocked read the same priority | unlocked tiles read first (`accessibilitySortPriority`); medal art stays hidden; state is spoken from the status text, not colour | `CYBadgeTile` |
| 11 | VoiceOver, chat bubbles | sender, text and timestamp were separate stops | one stop per message, read sender, text, time | `ChatMessageBubble` |
| 12 | VoiceOver, tab bar | system `TabView` item with `Label` (title + symbol) and `.isSelected` supplied by UIKit | audited, no change | `CYDomainTabBar` |
| 13 | AX4 `CYImageCard` | text over the photo, 2 lines max, clipped on long titles; shelf text unreadable | photo keeps ratio, text moves below on a solid surface with no line limit | `CYImageCard` |
| 14 | AX4 `CYListRow` | trailing value squeezed the title | value moves under the meta line | `CYListRow` |
| 15 | AX4 `CYStatusChip` | `lineLimit(1)` truncated status words | up to 3 lines | `CYStatusChip` |
| 16 | AX4 `CYPillButton` | single-line assumption | centred multi-line, vertical padding, min height 56 scaled | `CYPillButton` |
| 17 | AX4 `CYBadgeTile` | name capped at 2 lines and scaled down | no cap, no scale-down | `CYBadgeTile` |
| 18 | AX4 wallet ledger rows | reason and amount side by side, text broken one letter per line ("Synth/etic/missin/g") | amount stacks under the reason | `WalletLedgerView.ledgerRow` |
| 19 | AX4 inbox rows | 56pt avatar left a ~240pt column, "conversati/on" broke mid-word | decorative avatar dropped at AX sizes | `IMInboxRow` |
| 20 | AX4 activity detail hero | two chips side by side clipped ("即将开始" wrapped inside the chip, overflowed the photo) and a 72pt top pad | chips stack, title `.title`, small top pad | `E1ActivityDetailParts` |
| 21 | AX4 route detail hero | title truncated with an ellipsis at 2 lines | `.title`, 4 lines in the detail hero; **still shows an ellipsis in the shot** ("Old Town Lantern Walk (o…"), so the visible title there is another view with a one-line limit; not fixed | `E1OfficialRouteParts` |
| 22 | AX4 Me header | avatar plus text squeezed "Lv.2 城市探…" to an ellipsis | avatar above text, level capsule wraps, city and streak stack | `MemberHomeHeader` |
| 23 | Tap targets | audited: `CYListRow` min 44, chips 44, pill 56, glass controls 48; 40pt row icon is decorative | no change | n/a |

## Seen at AX4 and not changed

- Pinned CTA bars (activity detail, order detail) cover content in the first-screen shot. They are `safeAreaInset(edge: .bottom)`, so the scroll view insets for them and the content scrolls clear; this is the scroll position, not a clipped CTA.
- The debug fixture banner overlaps some titles (fixture artifact only, never in release builds).
- Roam at AX4 opens the panel at the medium detent and shows the GO circle at its 112pt cap; the list is reachable.
- Shots mix zh and en because the simulator keeps the last `AppleLanguages` for the bundle; the `-AppleLanguages '(en)'` args in the batch file were not honoured on every launch. Layout findings do not depend on language.

## Not covered

- Nothing was run on a physical device or with VoiceOver on; the label/order work is from code reading plus the SwiftUI accessibility tree, not from a spoken pass.
- Wallet, Me, inbox and activity-detail fixes are confirmed in the second sheet. Route detail title is not (row 21).
- Only dark/player at AX4 was shot. AX3 and AX5 were not shot; AX5 is larger than AX4 and may expose more wraps.
- Pages outside the 16 were audited only through the shared kit changes above.

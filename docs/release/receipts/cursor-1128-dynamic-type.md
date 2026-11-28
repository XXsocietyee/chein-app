# K26 · dynamic-type (`cursor/1128-dynamic-type`)

Base: `origin/ui/combined-r7` at `c4e43841afaddd576a72104f8bf8641af2060732` (contains the K13 `RuntimeDependencyConfiguration` argument order). The branch was created from that tip. No `String(localized:)` literals were added. `App/AppSession.swift` was not edited.

AX-XXXL is `UICTContentSizeCategoryAccessibilityXXXL` (SwiftUI `.accessibility5`).

## What ran

This VM has no iOS simulator and no Swift compiler. The XCUITest and the hosting unit test were added and not executed. There is no visual pass. Nothing below is a screenshot result.

- `Tests/AppUITests/DynamicTypeAX5ScreenPassUITests.swift` launches the 40 fixtures below with `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXXXL` and `--uitesting-max-text`, checks the process is in the foreground, and keeps a screenshot attachment. It does not judge clipping.
- `Tests/AppUnitTests/DynamicTypeAX5SharedComponentsTests.swift` hosts the shared components that changed, at `.large` and `.accessibility5`, and checks the AX-XXXL layout stays inside the offered width and is taller than the default size. It compiles only where UIKit exists.

`DesignFixtureRegistry.make` does not pin a Dynamic Type size on these 40 ids. A child inside a fixture can still pin one. That was not measured on a device.

## Shared components changed

Truncation and clipping only, under `App/DesignSystem/`. Default size still uses the previous one-line or two-line layout. AX-XXXL uses `ViewThatFits` or a higher line limit. No screen file was restyled.

| View | What clipped at AX-XXXL | Change |
|---|---|---|
| `CYPayButton` | Title and amount forced to one line and scaled to 0.8 | `ViewThatFits`: one row when it fits; title wraps to 2 lines and the amount sits under it when it does not. Amount stays one line. |
| `CYHeroBanner` | Caption lived inside a 4:3 frame, title and subtitle capped at 2 lines | At an accessibility size the cover stays 16:9 and the caption sits under it (title 4 lines, subtitle 3). Default size is unchanged. |
| `CYCarouselCaption` | Title 2 lines, place 1 line | Accessibility size: title 4, place 2. |
| `CYMapCallout` | Place name 2 lines | Accessibility size: 4 lines. |
| `CYRootSubtitle` | Tab-root subtitle 2 lines | Accessibility size: 3 lines. |
| `CYResultToast` | Message 2 lines beside the action | `ViewThatFits`: action drops under a 4-line message when the row does not fit. |
| `CYChapterEndCard` | Three stat labels in one row, 2 lines each | At an accessibility size the three stats stack and each label may use 3 lines. The default row is unchanged. Figures stay one line. |
| `CYRoamNearbyCard` | 64 pt art beside a 2-line title | At an accessibility size the art sits above a 4-line title and a 3-line meta line. The default row is unchanged. |
| `CYMedalDeck` | Medal name and subtitle 2 lines | Accessibility size: name 4, subtitle 3. |
| `CYSquareActivityPicker` | Activity name 2 lines beside a 56 pt cover | Accessibility size: 4 lines. |
| `StampSeal` | "Stamped. You were here." scaled to 0.7 on one line | Accessibility size: 2 lines, no shrink. |
| `CYPassVerifiedFace` | Title inside the fixed tear band, 2 lines, scaled to 0.85 | `ViewThatFits` in that band: the roomy seal when it fits; a smaller seal, a wrapping heading, and a 4-line title when it does not. |
| `CYSquareShareSheet` | Excerpt 2 lines beside a 72 pt image | Accessibility size: 3 lines. The 28-character excerpt cap in the payload is unchanged. |
| `CYSquarePostDraftsSheet` | Nickname and date on one row; summary 2 lines | At an accessibility size the date drops under a 2-line name. Summary 4 lines. The default row is unchanged. |

Left as they were: prices, counters, die faces, the GO wordmark, share-card export (rendered at `.large`), and the ticket ribbon (it already becomes a chip at an accessibility size).

## 40 screens

| Fixture | Lane | Screen | Level |
|---|---|---|---|
| `d2-home` | mp-home | Home feed | B |
| `d2-search` | mp-home | Home search | B |
| `e1-topic-detail` | mp-home | Topic detail | B |
| `e1-official` | mp-home | Official events | B |
| `d6-search` | mp-home | Map search | A |
| `d2-roam` | mp-roam | Roam map home | A |
| `d6-real-live` | mp-roam | Live roam | A |
| `d2-city` | mp-roam | City roam | A |
| `r3-roam-history` | mp-roam | Roam history | B |
| `e5b-stamp` | mp-roam | Stamp collected | A |
| `d4-stamps` | mp-roam | Stamp album | B |
| `r3-roam-nearby` | mp-roam | Nearby teams | B |
| `r3-roam-poi` | mp-roam | Place detail | B |
| `r3-roam-tasks` | mp-roam | Official tasks | B |
| `template-topics` | mp-publish | Publish shelf | B |
| `template-detail` | mp-publish | Template detail | B |
| `t11-fabu` | mp-publish | Project editor | C |
| `d2-square` | mp-publish | Square | B |
| `d4-directory` | mp-club | Club home | B |
| `d4-detail` | mp-club | Club detail | B |
| `d4-tab-posts` | mp-club | Club posts | B |
| `d4-channel-chat` | mp-club | Club channel chat | B |
| `d4-members` | mp-club | Club members | C |
| `welcome` | mp-mine | Welcome | A |
| `onboarding-1` | mp-mine | Onboarding | A |
| `d2-me` | mp-mine | Me | B |
| `ia-passport` | mp-mine | Passport | B |
| `d4-badges` | mp-mine | Badge wall | B |
| `d4-settings` | mp-mine | Settings | C |
| `d4-growth` | mp-mine | Growth | B |
| `d4-leaderboard` | mp-mine | Leaderboard | B |
| `wallet` | mp-mine | Wallet | C |
| `login-player` | mp-nav | Login | C |
| `e4-auth-phone` | mp-nav | Phone sign-in | C |
| `d2-inbox` | mp-nav | IM inbox | B |
| `e1-activity-detail` | mp-activity | Activity detail | B |
| `e1-ticket-holder` | mp-activity | Ticket wallet | B |
| `t5-pass-market` | mp-activity | Pass market | B |
| `d2-play` | mp-journey | Play | A |
| `d2-npc` | mp-journey | NPC | C |

Levels are from `docs/design/levels.md`. The XCUITest was not run, so this table is the pass list, not a result.

## Screen-specific issues for the lanes

Static read of `.lineLimit(1)` and a fixed `.lineLimit(2)` on these screens. Not fixed here. Words, not prices or counts, are the ones that still truncate at AX-XXXL.

| Lane | Screen | File | Issue |
|---|---|---|---|
| mp-home | Home search | `App/GlobalSearchView.swift` category capsules | Name is `.lineLimit(1)` plus `.fixedSize()`. A category longer than the row at AX-XXXL can overflow; the flow wraps capsules, not the name. |
| mp-home | Topic detail | `App/TopicXcxSections.swift` fact tiles | Value and unit share `.lineLimit(1)` and scale to 0.8. A long unit is cut. |
| mp-publish | Publish shelf | `App/DiscoveryTemplateBrowserView.swift` `DiscoveryShelfFeatureTile` | Title and meta are `.lineLimit(2)` at every size. A long English title is cut at AX-XXXL. |
| mp-publish | Template detail | `App/DiscoveryTemplateDetailView.swift` guide line | `.lineLimit(2)` at every size. |
| mp-publish | Square | `App/SquareXcxPostCard.swift` upcoming card | Subtitle is `.lineLimit(1)` at every size. The relative time on the post head is a clock and can stay one line. |
| mp-club | Club detail | `App/ClubDetailView.swift` `ClubOverviewFacts` | The three-cell probe is `.lineLimit(1)` plus `.fixedSize()` so `ViewThatFits` can fall through to labelled rows. Confirm on device that the fall-through still wins at AX-XXXL in English. |
| mp-roam | Live roam | `App/RoamLiveSessionView.swift` `RoamLiveStatColumn` | The label is `.lineLimit(1)` even after the pair stacks. "Time on foot" style labels get cut. The figure is a number and can stay one line. |
| mp-roam | Finish report | `App/RoamFinishReportView.swift` share and done | The buttons stack at an accessibility size and then keep `.lineLimit(1)`. A long localized label is still one line. The stat figure scales to 0.6; that one is a number. |
| mp-mine | Me | `App/MemberHomeHeader.swift` points and balance | The figures scale to 0.6 / 0.7 instead of wrapping. Labels already wrap. |
| mp-mine | Passport | `App/PassportView.swift` action | Already `ViewThatFits` (full title, then a short title that wraps). Worth a look if the short title is still one glyph wide. |
| mp-mine | Orders | `App/ProfileOrdersView.swift` order title | `.lineLimit(2)` beside a 72 pt cover. |
| mp-activity | Registration | `App/RegistrationSheetView.swift` activity name | `.lineLimit(2)` beside a 72 pt cover. |
| mp-activity | Pass market | `App/PassMarketViews.swift` `PassTicketHero` | Face name `.lineLimit(2)`. |
| mp-nav | IM inbox | `App/IMInboxViews.swift` | Name and preview already wrap from `.xxLarge` up. No change asked. |

`.clipped()` hits on covers (`HomeFeedView`, `DiscoveryTemplateBrowserView`, `ClubDetailView`, `RoamMapHomePlaceCard`, `SearchMapComponents`, `SocialPublicProfileView`, `MemberHomeHeader` avatar) are image crops, not text.

## Gates

Run on this machine against the working tree, before the commit. No Swift compiler and no iOS simulator, so nothing below is an XCTest or a visual pass.

- `python3 tools/check_scaffold.py` — PASS (structural checks, design lint, design consistency, accessibility lint scope, catalog coverage, AppSession ratchet).
- `python3 -B tools/check_a11y_lint.py` — PASS. 0 new, 0 current, 0 baselined, 0 removed.
- `python3 tools/contract_ratchet.py --check` — `46 failing, baseline 46, new 0, fixed 0`.
- Visual / XCUITest pass at AX-XXXL — **NOT_RUN**. `swift` and `swiftc` are not on this machine, and there is no simulator. The unit and UI tests are in the tree; they were not executed.

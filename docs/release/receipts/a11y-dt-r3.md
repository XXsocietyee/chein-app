# a11y-dt r3 receipt (branch `design/r3-a11y`)

Lane area: Dynamic Type up to AX5, VoiceOver labels/order/traits, Reduce Motion, contrast, 44 pt targets on every player screen.
Code-only, cloud-verified (no Swift compiler / simulator in the cloud). Gates per run: generate_project, check_scaffold,
check_a11y_lint (0 current), contract_ratchet --check (new 0), check_design_consistency (PASS).
No MP section added, removed or reordered by this lane (OWNER RULE): fixes are sizing, traits and labels only.

## Run 1 (2026-11-27)

Whole-tree scans done first (player files; Merchant / Fixture / Diagnostics / *SectionView skipped):
- `repeatForever` animations without a Reduce Motion check: **0**.
- `onTapGesture` without a button trait / action nearby: 17 hits reviewed; all either have an adjustable/custom
  accessibility action (journey settle step dots, medal stack), are map coordinate pickers with a text alternative,
  are tap-to-skip on a moment that also has a Done button, or are fixtures. No change needed.
- Button labels with a fixed frame < 44 pt and no min-hit wrapper: 0 real (all hits already wrap to 44).
- **Text inside a fixed-size circle/tile** (clips at AX sizes): 13 hits → fixed below.

| MP page | Native view file | MP sections present | Optimization applied (a11y-dt) | Status |
|---|---|---|---|---|
| `pages/index/index` (Home tab root) | `HomeFeedView.swift`, `HomeSearchTabParityViews.swift` (hero) | ✓ (mp-home owns order) | Verified: rails switch to full-width rows at AX sizes, banner autoplay stops for Reduce Motion + VoiceOver, page dots hidden, avatar/city 44 pt, greeting header trait. No change needed. | Done |
| `pages/roam/index` (Roam map home) | `NativeR2/MapHome/RoamMapHomePanel.swift` | ✓ (mp-roam owns order) | Verified: panel handle is adjustable for VoiceOver (peek/medium/large value), peek height scaled for Dynamic Type and capped at 40 %. No change needed. | Done |
| `pages/member/index` (Me tab root, passport block) | `PassportView.swift` (`actions`) | ✓ (mp-mine owns order) | 票夹 / 钱包 / 消息 capsule row → `AnyLayout` VStack at AX sizes (same buttons, same order), so labels no longer break one glyph per line; stamp grid / badge rail already adapt (verified) | Done |
| City ordered run (`subpackageJourney` city route list) | `CityOrderedMapView.swift` | ✓ | Stop number circle 28 pt → `@ScaledMetric(relativeTo: .footnote)` | Done |
| `pages/activity` official route detail | `E1OfficialRouteParts.swift` | ✓ | Route node number circle 28 pt → `@ScaledMetric(relativeTo: .body)` | Done |
| Growth leaderboard (`subpackageMember` rank) | `GrowthLeaderboardView.swift` (podium) | ✓ | Podium place badge 28 pt → `@ScaledMetric(relativeTo: .caption)` | Done |
| `pages/club/*` rows | `ClubKit/ClubR1Kit.swift` (`ClubR1Row`) | ✓ | Initial tile 32 pt (`.headline`) → `@ScaledMetric(relativeTo: .headline)` | Done |
| Questo accusation (`pages/playkit`) | `PlayKitQuestoViews.swift` (`PlayKitAccusationView`) | ✓ | Suspect initial circle 52 pt → `@ScaledMetric(relativeTo: .title3)` | Done |
| `subpackageMember` participants (常用出行人) | `ProfileParticipantsView.swift` | ✓ | Name initial circle 40 pt → `@ScaledMetric(relativeTo: .headline)` | Done |
| City deed card (roam city board) | `CityKit/CityDeedCard.swift` | ✓ | Owner avatar letter 22 pt → `@ScaledMetric(relativeTo: .caption)` | Done |
| Settings › marketing consents | `AccountComplianceViews.swift` | ✓ | Merchant initial / logo tile 36 pt → `@ScaledMetric(relativeTo: .body)` (logo and initial stay the same size) | Done |
| Blind taste (`pages/playkit` legacy kit) | `PlayKitLegacyViews.swift` (`PlayKitBlindSteps`, new private view) | ✓ | Step number circle 36 pt → `@ScaledMetric(relativeTo: .body)`; three steps `ViewThatFits` HStack → VStack at AX sizes / long English; combined VoiceOver sentence kept | Done |
| Journey record (`subpackageJourney` narrative) | `JourneyNarrativeView.swift` | ✓ | Found-count ring 88 pt → `@ScaledMetric(relativeTo: .title)` capped at 132; number scales down (0.5) instead of clipping | Done |
| Club month calendar (design component) | `ClubComponents.swift` (`E3MonthGrid`) | ✓ | Seven 38 pt day circles capped at `.xxxLarge` (as Calendar's month grid); each day keeps its VoiceOver label | Done (only fixture-hosted today) |

## Run 2 (2026-11-27, hourly)

Merged `origin/ui/combined-r7` (clean). Gates as above.

| MP page | Native view file | MP sections present | Optimization applied (a11y-dt) | Status |
|---|---|---|---|---|
| City orientation run map (`subpackageJourney`) | `NativeR2/CityOrientation/CityOrientationRunView.swift` (teammate annotation) | ✓ (mp-journey owns order) | Teammate initial 28 pt → `@ScaledMetric(relativeTo: .caption)` capped at 44 (Maps-pin size, never covers the route); `.regularMaterial` disc instead of translucent fill so the letter reads on any map tile; VoiceOver hears the team name, not the initial | Done |
| `pages/template/index` (Publish tab root, template shelf) | `DiscoveryTemplateBrowserView.swift`, `+Port.swift`, `TemplateShelfArt.swift` | ✓ (mp-publish owns order) | Row artwork (60/72 pt scaled) capped at 96 pt so the title keeps the row at AX5 (Music list artwork rule; also fixes search result rows that share `DiscoveryTopicCoverThumb`); shelf header picture capped at 240 pt (was 180 × AX5 ≈ 560 pt); featured page view 16:13 → 2:3 at accessibility sizes so title + meta are not cut off. Toolbar items, menu and sections unchanged | Done |
| `pages/member/index` passport actions (16:37 sweep `ia-passport`) | `PassportView.swift` (`action`) | ✓ | Labels `.caption` → `.footnote` medium (was "tiny"); contrast checked: brand #33363C on the bordered fill ≈ 9:1 light, #F8F8F8 ≈ 10:1 dark (≥ 4.5:1). AX stacking from run 1 kept | Done |
| `subpackageMember` ticket wallet (票夹) | `TicketWalletView.swift` (row), `TicketWalletDetailView.swift`, `TicketPassSheet.swift` | ✓ (mp-mine owns order) | Row cover 60 pt scaled → capped at 96 pt so title/date/place keep the width at AX5. Detail + pass sheet audited: QR band already shrinks at AX sizes, labels present. | Done |
| `pages/club/*` (Club tab root) | `ClubHomeView.swift` | ✓ (mp-club owns order) | Audit: system `List`/`Label` rows, no fixed sizes, no `font(.system)`, event rows wrap. No change needed | Done |

## Run 3 (2026-11-27, hourly)

Merged `origin/ui/combined-r7` (clean). Sweep 17:24 (build 070117595) a11y sheets read: `en-a11y-roam-ax5.jpg`
(peek title wraps cleanly, map controls fine), `en-a11y-badges-ax5.jpg` (single-column badges at AX5, OK),
`en-a11y-passport-ax5.jpg` renders the badge wall under a dimmed launch overlay (see For other lanes).

| MP page | Native view file | MP sections present | Optimization applied (a11y-dt) | Status |
|---|---|---|---|---|
| City orientation run (`subpackageJourney`) team stack | `NativeR2/CityOrientation/CityOrientationRunView.swift` (`CityOrientationTeamStack`) | ✓ | "N teams on the route" `lineLimit(1)` → 2 lines + 0.85 scale, never truncated in long English at AX5; face pile 24 pt → `@ScaledMetric(.caption)` capped 36, hidden at AX sizes (already VoiceOver-hidden; the count sentence carries the meaning) | Done |
| `pages/roam/index` (Roam map, floating controls) | `RoamBrowserView.swift` (`RoamMapGlassControl`) | ✓ (mp-roam owns order) | Rules / open-map circles scaled from 50 pt without a cap → capped at 72 pt so rules · GO · map fit 375 pt at AX5. Result rows (`RoamItemRow`, 60 pt art, combined element), search field 44 pt, peek line 44 pt + combined: audited, no change | Done (`en-a11y-roam-ax5.jpg`) |
| `subpackageMember` im list (inbox, `im/list/index`) | `IMInboxViews.swift` (`IMInboxRow`) | ✓ (mp-mine/mp-nav own order) | Audit: avatar 44 pt at AX sizes, name/time stack ≥ xxLarge, combined row, muted glyph labelled. No change | Done |
| `subpackageMember` im chat (system notice card) | `MessagingHistoryView.swift` (`MessagingBubble.noticeCard`) | ✓ | Bell tile 36 pt fixed with a `.body` glyph (clipped at AX sizes) → `@ScaledMetric(.body)` capped 60 | Done |
| Chat message cards | `MessagingMessageDetailView.swift` | ✓ | Audit: icon tile scaled + hidden at AX sizes. No change | Done |
| Club channel chat (`pages/club/*` channel, `d4-channel-chat`) | `ClubChannelMessagingView.swift` (`ChannelBurstGroupCard`, `ClubChannelMemberRosterSheet`) | ✓ (mp-club owns order) | Sender initial circle 28 pt and roster initial 32 pt (text in a fixed circle, clipped at AX sizes) → `@ScaledMetric(.subheadline)` capped 48 / 52, letter scales down instead of clipping. Send button 44 pt labelled, Reduce Motion respected on scroll: audited. `NativeChannelMessage*` (context avatar 40 pt art, no text) audited, no change | Done |

## Not done (next run starts here)
- Next pages without a row: club channel pins / search (`NativeChannelMessagePinsView`, `…SearchView`) VoiceOver
  order pass; `.lineLimit(1)` audit on remaining tab-root rows (P12 + AX5); square / team pages (`pages/square/*`).

## For other lanes
- **mp-home / mp-mine** (sweep 17:24, `a11y-passport-ax5`): the screen is still dimmed under the grey launch
  overlay with the logo watermark at capture time (same symptom as the 16:53 `d2-home` note) — it must never dim a
  tab root. Also the `a11y-passport-ax5` fixture opens the badge wall, not the passport.

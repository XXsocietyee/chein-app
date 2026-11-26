# Receipt: fix r10, lane roam-b

- **Brief:** `origin/design/handoff-r2:docs/briefs/fix-r10.md`; source `docs/audit/parity-r10/play-roam.md` §5.
- **Branch:** `fix/r10-roam-b`, based on `origin/ui/combined-r7` (`d9832ac50`), merged with `origin/ui/combined-r7` before each push.
- **Slice:** §5 has 23 P1 rows. roam-a takes rows 1–12 in table order (PLAY-6a … N-KIT-FORMS). roam-b takes rows 13–23 (N-PLAY-MAP … N-ALBUM), then every P2 row. §5 has no P0 row.
- **Not compiled:** there is no Swift toolchain in the cloud. Every type and member was grepped before use. Brace and paren balance was checked on the rewritten files.
- **Gates (last run, before the final push):**
  - `check_scaffold.py`: PASS structural checks.
  - `check_a11y_lint.py`: PASS, 0 new.
  - `check_typography_lint.py`: PASS.
  - `contract_ratchet.py --check`: new 1, fixed 0. The one new failure, `test_social_article_content…test_renderer_is_wired_only_to_existing_scoped_article_contents`, already fails on the base `d9832ac50` and is outside this slice.
- **Pinned contracts changed (each with an MP citation in a comment):**
  - `test_city_game_base` (N-ORIENT).
  - `test_design_system_component_contracts`: the RoamHomeTabsView raw-colour allowance goes from 4 to 0 (N-ROAM-HOME).
  - `test_object_badge_wall_layout` byte pin and `test_accessibility_hardening_wave` turntable check (N-B3D).

**Finding that changes several rows:** since native r2, `CYPillButton` (→ `.borderedProminent` / `.bordered` / `.borderless`), `CYStatusChip` (→ `Label` / secondary text), `CYEmptyState` (→ `ContentUnavailableView` with MP empty art), `CYChoiceRow` (→ checkmark `Button` row), `.cyField()` (→ `.roundedBorder`), `CYHeroHeader` (→ `.title` Text) and `CYColor.bgElevated` (→ `secondarySystemGroupedBackground`) already render system components. The audit counted these by grep. Where a row only lists them, the receipt says so instead of churning call sites. The work went into the chrome that is still drawn by hand: cards, shapes, shadows, gradients, 3D, custom sheets and modals.

## P1 (rows 13–23)

| id | status | SHA | app file:line | note |
|---|---|---|---|---|
| N-PLAY-MAP | partly | `3d8015537` | App/PlayExperienceView.swift:884, :1368 | Glass clock, route and end controls → material `Label` and `.bordered` circle Buttons. Answer cards → List checkmark rows. This screen is the flag-off fallback: the default city-orientation run is `CityOrientationRunView`, which is already `Map` + detented system sheet + `MapUserLocationButton`. The in-view panel stays, because a system panel sheet would detach the panel's NavigationLinks and the parent's sheets. |
| N-ROAM-MAP | partly | `d0bbdd3ca`, `22b296055` | App/RoamBrowserView.swift:365, :498, :726 | The nav bar now stays visible on the map, with an inline title and the overflow `Menu` as a toolbar item. Rules / start / map → system bordered buttons. The search field sits on the system fill. **Not done:** `MapUserLocationButton` on `QuestifyDensityMap`, which was added and then reverted because the pinned privacy contract `test_map_camera_controls` forbids location acquisition there (owner decision needed). `.searchable` stays off-map as before. The in-view panel stays, as for N-PLAY-MAP. |
| N-ROAM-LIVE | fixed (on base) | `d9832ac50` | App/RoamLiveSessionView.swift:148, :244 | Already `Map` + system sheet detents + `MapUserLocationButton` + `.borderedProminent` + `confirmationDialog`. No CY map chrome is left. |
| N-ORIENT | partly | `617ec496a` | App/CityGamePanel.swift:44-194 | `CYPillButton` ×7 and `cySecondary` → system Buttons. `CYSkeleton` → `ProgressView`. Tile and chip backgrounds removed. **Not done:** OrientScore keeps `.game`, pinned by `test_global_chrome_domain_contract`. Its `CYEmptyState` calls are already `ContentUnavailableView`, and TeamOrientBoard has no drawn chrome. |
| N-RHIST | fixed | `66a5a4794` | App/RoamHistoryViews.swift:27 | ScrollView of cards → `.insetGrouped` List of NavigationLink rows. Night glass, hexagons and card button style removed. `CYSkeleton` → `ProgressView`. |
| N-RNEAR | partly | `b19eaae37` → reverted in `22b296055` | App/NearbyTeamMapViews.swift | No net change. The map is already MapKit `Marker`s, the cards use `CYColor.bgElevated` (= the system grouped fill), and the location button is blocked by the privacy contract above. |
| N-RTEAMS | partly | `02ed74614` | App/NearbyTeamViews.swift:650 | `CYSheetContainer` review → `NavigationStack` + `Form` + cancellation item + detents. CY button styles → Form buttons. **Not done:** the team cards stay `cyDomainCard` inside the parent ScrollView. |
| N-JOURNEY-1 | fixed | `9a56ff29f` | App/JourneyLandingViews.swift:98, :337; promo `ready` | Promo → `.insetGrouped` List with Sections and `LabeledContent` (the payout note is the section footer). Landing facts and rules → `GroupBox` + `LabeledContent`. Lantern glow and title pill removed. |
| N-JOURNEY-2 | fixed | `7e195e7cc` | App/JourneyLandingViews.swift:566, :708 | `CYHoldToStartButton` → `.borderedProminent` 去起点 + `confirmationDialog`. `MPCard` / `MPRow` / `MPRows` → `GroupBox` rows. The eyebrow and title are left to JSEAT-8 (roam-a). |
| N-JOURNEY-3 | fixed | `4b806af1c` | App/JourneyReportViews.swift:536, :958, :1009, :1136 | Report → List sections with `LabeledContent` and disclosure rows. Settle: SF Symbol seal, `GroupBox` rank card, no star spring, bordered tag buttons, `.roundedBorder` review field. |
| N-ALBUM | fixed | `ad2afa80e` | App/RoamStampViews.swift:217, :253, :529 | Detail → List (image row + `LabeledContent`). The legacy grid loses foil and tilt, and its shadowed FAB becomes a toolbar item. The default album (`NativeR2Flags.freeExplore`) is `NativeStampAlbumView`. |

## P2

| id | status | SHA | app file:line | note |
|---|---|---|---|---|
| N-KIT-CHOICE | fixed | `e611c53c2` | App/PlayKitLegacyViews.swift:86 | `CYChoiceRow` and `.cyField` are already system. The drawn diy-name box → `.roundedBorder` TextField. |
| N-KIT-BUTTONS | fixed (via wrapper) | — | App/PlayKitTimedChallengeView.swift:34 | `CYPillButton`, `CYHeroHeader` and `CYStatusChip` already render system components. The stage drawings stay (the stage stays dark). |
| N-KIT-QUESTO | fixed | `5237cfd2b` | App/PlayKitQuestoViews.swift:319, deck | `rotation3DEffect` → cross-fade. Letter keys → `.bordered` `.small` Buttons. |
| N-ROAM-HOME | fixed | `88410130d` | App/RoamHomeTabsView.swift:48 | Ticket cards (with `Color(red:)`, white card and shadow) → NavigationLink `Label` rows with `MPAsset` art. The capsule badge becomes a tinted caption. |
| N-RCODE | partly | `cc9769c52` | App/VerificationCodeView.swift:35 | `CYHeroHeader` → inline nav title. `CYScanSweep` removed. `CYSkeleton` → `ProgressView`. The page stays a ScrollView (QR display), not a Form. |
| N-RPOI | fixed | `36212f053` | App/RoamPOIActions.swift:324 | `CYOptionSheet` → `confirmationDialog`. `CYEmptyState` and `cyPageTitle` are already system. |
| N-RSESS | blocked | — | App/RoamHistoryShareView.swift:49 | The screen is the shared `CYShareComposer` export pipeline (privacy toggles, state machine, photo save). Converting it belongs to the coordinator's design-system follow-up, not a per-page swap. |
| N-ROUTES | fixed (on base) | `d9832ac50` | App/OfficialRouteViews.swift:18-50 | States are already `ProgressView` / `ContentUnavailableView`, and no stagger animation is left. The route cover cards stay (MP official-routes cards). |
| N-RSTAMP | fixed | `093085f95` | App/RoamStampCameraView.swift:357; App/RoamSubpageParityViews.swift:605 | `CYScanMark` + `CYOrbitDots` → SF Symbol with `.symbolEffect(.bounce)`. Printer shadow removed. |
| N-MERCHANT | partly | `2a4c08ef8` | App/PlayStoreDayMerchantView.swift:58, arrive purpose | `cyModalConfirm` ×4 → `.alert` (the MP uses `wx.showModal`). Player-side page, not merchant-center. **Not done:** the hero image scrim gradient stays. |
| N-POICH | fixed | `277a0e081` | App/ChallengePOIView.swift:278 | Tinted note box → `Label`. Choice rows and fields are already system. |
| N-OCARDS | fixed | `53c20f5b4` | App/ObjectCardViews.swift:144; App/ObjectCardPileView.swift:69; App/SessionObjectCardsView.swift:34 | Flip and foil removed: image row plus style and source rows. Pile is untilted with no shadow. `CYListRow` → `Label`. |
| N-GROWTH | fixed | `efc9a3667` | App/GrowthCenterView.swift:102; App/GrowthLeaderboardView.swift:268, :299 | Level-up cover removed (the haptic stays). `listRowBackground` dropped. `CYTabs` → segmented `Picker`. Podium colours → `.yellow` / `.gray` / `.brown`. |
| N-TOOLS | partly | `5c697bf2e` | App/RoamExplorationExportView.swift:323; App/RoamPassportPrivateToolsViews.swift:671; App/RoamPassportToolsViews.swift:239 | Skeletons → `ProgressView` / `.redacted`. Export pill → Form button. **Not done:** recap bars → Swift Charts `BarMark` (tap-to-pick selection needs a compiler pass). |
| N-B3D | fixed | `6d6cb47d3` | App/ObjectBadgeViews.swift:421 | 2D List under the inline title, no `rotation3DEffect` turntable. Two pinned tests updated. |
| seats-save | fixed | `375835507`, `e0f6324ca` | App/JourneyLandingViews.swift:856 | Invite card → `ImageRenderer` → `ShareLink` (Save Image is in the share sheet). Existing key `gap.team.saveInviteImage`. |

No row in this slice is merchant-only or money.

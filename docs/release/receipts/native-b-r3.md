# Receipt — native-b, round 3 (2026-11-27)

Branch `native/r3-b` from `origin/ui/combined-r7`. Scope: player surfaces in `App/` files M–Z plus `App/NativeR2/**`. Skipped `Merchant*`, `*Fixture*`, `*Diagnostics*` and `*SectionView`, the story-flow theme, and creator/authoring tools. Nothing deployed.

## Baseline scan (scoped files: 985)
- `.font(.system(size:))` / `UIFont.systemFont(ofSize:)` / `Font.custom`: **0** in scope. Every `.font(.system(...))` left in scope takes a text style (`.largeTitle`, `.title3`, …) with a design, so Dynamic Type already works. Nothing to do.
- Hard-coded `Color(red:)`: 9 hits. Only one was a UI surface (fixed below). The rest are data or rendering code: MP colour tokens decoded from the server (`MapCoreEntryHubView:167`, `SearchMapCanvas:85`, `NativeAttributeAuthorViews:514`, `ProjectChapterAtmosphereFields:149`), the map overlay renderer (`SearchMapCanvas:112`), the device-provider drawing (`PlayNativeDeviceProvider`) and the `QuestifyPalette` UIKit bridge. I kept all of those.
- Custom search fields: the only ones left are documented exceptions. `RoamBrowserView:352` is the map sheet's pinned field (it uses `.searchable` outside the map layout). `NativeFriendPickerView:27` is a row inside the host's Form.
- Already native before this round: `CYEmptyState` wraps `ContentUnavailableView`, and so do all `CYEmptyIllustration` empty states.

## Replaced patterns (file:line on this branch)

### Fixed/decorative colours and gradients → semantic system colours / backgrounds
The fixed-dark `CYNight.ink*` page and card fills were dark surfaces under semantic text, so text was unreadable in light mode.
- `QuestifyImageEntityCard.swift:70`: `Color(red:0.16,…)` placeholder → `Color(uiColor: .systemGray4)`
- `RoamExperienceComponents.swift:241-249`: `RoamNightCard` indigo `LinearGradient` + gradient stroke → `.background(.background.secondary, in: .rect)`
- `RoamExperienceHubView.swift:51-53`: hero indigo `LinearGradient` + gradient edge → `.background.secondary`
- `RoamFinishReportView.swift:87`: forced `Color.black` page → `.background(.background)`. Its text uses `CYColor.textPrimary`, which was unreadable in light mode.
- `RoamFinishReportView.swift:66`: drawn `glassEdgeTop` hairline → `Divider()`
- `RoamFinishReportView.swift:227`: medal row background `CYNight.ink1` → `.background.secondary`
- `RoamFinishReportView.swift:250`: map panel background → `.background.secondary`
- `RoamFinishReportView.swift:257`: no-track capsule edge → `.separator`
- `RoamFinishReportView.swift:270`: map overlay link capsule `ink0` + edge → `.regularMaterial`
- `RoamNearbyParityExtras.swift:266, 309`: quote and review cards `CYNight.ink2` → `.background.secondary`
- `RoamStampPhotoStrip.swift:56`: photo placeholder → `.fill.secondary`
- `RoamStampPhotoStrip.swift:103`: photo edge → `.separator`
- `MPParityKit.swift:337`, `MPReviewedPageScreen.swift:1034`: `CYNight.ink0` page → `.background(.background)`
- `MPParityKit.swift:558`: avatar disc → `.fill.secondary`
- `MPParityKit.swift:428`: `MPDivider` drawn rectangle → `Divider()`
- `MPPassEntries.swift:67, 83`: pass store chips → `.fill.tertiary`; card `ink1` → `.background.secondary`
- `PlayKitDecisionProgressViews.swift:151, 250`: walk tiles and daily-sign ticket `ink2` → `.background.secondary`
- `PlayKitDecisionProgressViews.swift:200`: dashed divider → `.separator`
- `PlayKitNewGameForms.swift:192`: puzzle tile index capsule → `.regularMaterial`
- `NearbyTeamMapViews.swift:306`: recruit card `bgElevated` → `.background.secondary`

### Custom `.shadow` on cards and bars → system
- `PlayKitAlbumView.swift:97-102`: album card drop shadow removed; fill → `.background.secondary`. The 3-D scroll transition already separates the cards.
- `ShopNPCView.swift:204`: composer bar page colour + drop shadow → `.background(.bar)`
- `MiniCropView.swift:97`: control bar page colour + drawn line → `.bar` + `Divider()`

### Custom buttons and selection rows → system
- `PlayHelpLadderPanel.swift:224-226`: skip row on a hand-drawn rectangle → `.buttonStyle(.bordered)` with `.controlSize(.large)`
- `UGCSafetyComponents.swift:343`: contact-support row → `.background.secondary`
- `UGCSafetyComponents.swift:505-514`: report reason rows. Brand-soft fill + custom stroke → accent wash or `.background.secondary`, plus `.isSelected` trait.

### Custom segmented controls → `Picker(.segmented)`
- `RoamHomeTabsView.swift:130`: MP `entryStripTab` near/city (two plain text buttons) → segmented picker. The unused `stripTab` helper is removed (`:177`).
- `RoamTerritoryView.swift:165-174`: three `CYPillButton` tabs (附近格子 / 我的领地 / 赛季排行) → segmented picker. `onChange` reloads, as the old buttons did.

### Empty states → `ContentUnavailableView`
- Roam: `RoamPassportHistoryView.swift:87`, `RoamPassportToolsViews.swift:287` (anniversary), `RoamPassportToolsViews.swift:720` (recap), `RoamPassportPrivateToolsViews.swift:546` (capsules)
- Team, topic, square: `TeamHomeView.swift:213`, `TopicReviewsContent.swift:50`, `SquareDetailView.swift:577`, `SquareGovernanceViews.swift:105, 124`
- Wallet and coupons: `WalletCommerceViews.swift:268, 931, 1152`, `WP07CommerceViews.swift:149, 160`
- Profile, support, location sharing:
  - `ProfileSelfMedalsSection.swift:39`, `ParticipantFormView.swift:498`, `MemberReportProgressDetailView.swift:105`
  - `PersonalLocationShareView.swift:79, 119, 143`
  - `SupportTicketReadView.swift:41, 74`, `UsageConsentReadView.swift:44`
- Channels: `NativeChannelChainView.swift:104`, `NativeChannelCheckinView.swift:136, 218`, `NativeChannelModerationEntry.swift:110`, `NativeFriendChannelInviteEntry.swift:97`
- Play: `OrientScoreView.swift:341`, `PlayRouteMapView.swift:81`, `PlaySessionView.swift:112`, `PlaySharedPlanLifecycleView.swift:69`, `PlayExperienceView.swift:676`, `PlayPreferenceViews.swift:256`
- `WorkshopPurchasedLibraryView.swift:44`
- `NativeR2/CityOrientation/CityOrientationFinishSummaryView.swift:269`

All MP copy keys and accessibility identifiers are unchanged. No new strings.

## Contract pins updated (stale pins of the old layout)
- `test_profile_self_medals.py`: pin now `ContentUnavailableView("profile.selfMedals.empty"`
- `test_wallet_product_search_GrokR1.py`: pin now `ContentUnavailableView("wallet.empty"`

## Not done / kept on purpose
- Kept on purpose:
  - Game and reward styling that P7 asks for: `MotionR2Rewards` shadow and holo gradient, `MotionR2Core` sheen, `MotionR2Metrics` mesh background, `NativeR2SheetBackdrop` wash, the `PlayKitQuestoViews` tilted clue pins, and the `PlayKitNewGameForms` lantern selection.
  - Photo scrims over images: `RoamStampViews:416`, `RoamPassportToolsViews:915`, `QuestifyImageEntityCard:47`, `PlayThemePresentation:77`.
  - Map pin and control shadows: `RoamFogMapView:171`, `RoamBrowserView:779`. The Dynamic Island black. The `RoamRouteSketchView` night-map drawing.
- `MPPillTabs` (`MPParityKit.swift` ~475): this is the MP horizontally scrolling capsule tab row and can hold many tabs, so it is left as capsules rather than a segmented control.
- Small empty lines inside a card stay as text: roam summary rewards and places (`RoamHistoryViews:325, 356`), the team ranking card (`TeamOrientBoardView:178`), the peek strip (`RoamHomeTabsView:210`), the map list overlay (`QuestifyDensityMap:327`) and the WP07 group / activate notes.
- Creator and authoring-tool empty lines (`Template*`, `Project*`, `Workshop*` creator, `PlayCreatorTailViews`, `ModSettlement*`, `OwnerDraftBrowserView`): out of the player-surface scope.
- The UGC report sheet is still a ScrollView form. Moving it to `Form` would be a larger restructure.
- Not built or run: there is no Swift compiler here. All edits use existing SwiftUI APIs and repo patterns (`ContentUnavailableView(_:systemImage:)`, `.background(.background.secondary, in:)`, `Picker` + `.pickerStyle(.segmented)`).

## Gates
- `generate_project`: run, no errors
- `check_scaffold`: PASS
- `check_a11y_lint`: PASS (0 new)
- `contract_ratchet --check`: 104 failing, baseline 104, **new 0**, fixed 0

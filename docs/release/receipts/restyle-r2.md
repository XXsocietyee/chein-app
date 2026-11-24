# Restyle R2 (club & social): receipt, run 1 (2026-11-24)

- **Branch:** `restyle/r2-club-social`, based on `origin/ui/combined-r6` (f1115875e).
- **Brief:** `design/handoff-r2:docs/briefs/restyle-native-r1.md`. **Spec:** `design/native-ios-r1:docs/design/native-ios-r1.md` (DRAFT, read before the last commit).
- **Scope held:** R2 prefixes only (`Club*`, `ClubKit/`, `Social*`, `Session*`, `Messaging*`, `IM*`, `Channel*`, `Friend*`). No `App/DesignSystem/*`. No port-owned files: `ClubGovernanceViews`, `ClubEventCalendarView`, `IMDriftEntries` and `MessagingHomeView` are untouched. No strings, `pbxproj` or lint-baseline edits.

## Files changed (21)
- **Type (codemod, `tools/codemod_typography.py --upgrade-tokens`, 24 sites):** `ClubActivityListContent`, `ClubAndTeamCoopGovernanceSectionView`, `ClubMerchantDiscoveryView`, `ClubParticipationTrendSection`, `ClubPostDiscussion`, `ClubProfileChoiceEditor`, `ClubSettlementDetail`, `ClubStoryViews`, `ClubTopicMerchantContent`, `IMAndSocialSafetyParitySectionView`, `IMInboxViews`, `SessionLocationHoldsSection`, `SocialGraphAndProfilePrivacySectionView`; plus `ClubDetailTabBar` by hand.
- **Titles:** `ClubChannelMessagingView` (2), `SessionCityMerchantValueView`, `SessionCityPlayerValueView`, `SessionHomeFeedView` (mini-games sheet).
- **Back:** `ClubChannelMessagingView` channel top bar.
- **Cards:** `ClubComponents`.
- **Tab root:** `ClubHomeView`.
- **Test:** `Tests/ContractChecks/test_club_story_runtime_boundary.py` now accepts `.cyText(.cardTitle)` as well as the old `.font(CYTypography.cardTitle)`. The pin's intent (the title identifier stays a leaf) is unchanged.

## Before → after patterns
| before | after |
|---|---|
| `.font(.subheadline)` (16 sites), `.font(CYTypography.meta / cardTitle / sectionTitle)` (8 sites) | `.cyText(.body)`, `.cyText(.meta / .cardTitle / .sectionTitle)` (semantic, Dynamic Type) |
| `.font(sel ? CYTypography.bodyMedium.weight(.semibold) : CYTypography.bodyMedium)` | `.cyText(.bodyMedium, weight: sel ? .semibold : nil)` |
| `.navigationTitle(…)` with an unset mode on pushed pages | `+ .navigationBarTitleDisplayMode(.inline)` |
| channel top bar `chevron.backward` that opens the channel list (a custom back) | `list.bullet` icon, label 频道列表. Same action, same `club.channel.backToList` id. The system back stays the only back. |
| club card: radius 24, `.shadow(black 35%, r10)`; E3 social cards / `e3Card`: radius 22 | radius 12, no shadow (one card style, spec §3.3) |
| club tab root: in-content `CYHeroHeader("club.title")` under an empty `cyHeroScreen()` bar; `CYTabs(.segmented)` | system large title `cyRootHeader(.club)` (俱乐部); `Picker(.segmented)` for 帖文/俱乐部, keeping the `clubTab.topTabs` id, label and selection haptic (spec §4.4) |

## Local gates (no Swift compiler in the cloud)
- `tools/check_typography_lint.py`: PASS. Raw text style 1127, back chevron 9 (one below baseline), 13 counts below baseline. The baseline is P6-owned, so it is not ratcheted here.
- `tools/check_scaffold.py`: PASS (264 pages, structure and keys).
- `Tests/ContractChecks` (python unittest): base 186 FAIL/ERROR, branch 186. 0 new; the one new pin failure was fixed above.
- **Not run:** the Swift build, AppUnit/Core tests and screenshots. `.github/workflows/acceptance.yml` is not on `ui/combined-r6` yet. When it lands, rebase and run `gh workflow run acceptance.yml --ref restyle/r2-club-social`.

## Screens for acceptance
`docs/port/accept/r2.txt` has 19 fixture launch lines: club root and top tabs, member/visitor/empty/retry/tabFacts/merchant-locality, join/leave actions, management owner/failure, the community feed, messaging success/empty/error, and the social profile/guide/invites pages.

## Component requests (R6 / `App/DesignSystem`)
1. **`ClubDetailTabBar` → segmented `Picker` (spec §4.9).** Not done. UI tests tap per-tab ids `club.detail.tab.<key>` (ClubDetailTabsFlowTests, ClubManagementFlowTests, ModuleFlowTests, ClubActionFlowTests, CoopRelationDiscoveryFlowTests), and a segmented `Picker` cannot carry an id per segment. This needs a shared `CYSegmentedPicker` that exposes segment ids, or the tests moved to segment labels.
2. **Sheet detents:** about 60 `.sheet(` sites in R2 files present review/confirm/editor flows without `.presentationDetents`. This is left for the `cySheet` re-point (spec §3.4). Adding detents per site without a compiler risks conflicting with inner detents.
3. **State kit:** R2 screens use `CYEmptyState`/`CYStateView`/`ClubReadScreen` at about 110 sites. They will move with R6's `ContentUnavailableView` re-point. No local custom empties remain except one inline section line (`IMAndSocialSafetyParitySectionView`).

## Left (next run)
- About 30 static `.font(CYTypography.x)` remain. They are mostly SF Symbol sizes (allowed) or pinned by contract tests (`ClubEnrollmentView`, `ClubAIDesignView`, `ClubComponents`); they move with their tests.
- `ClubDetailView` hero header (spec §4.9: hero card row, join as the one `.borderedProminent`, leave in a toolbar `Menu` + `confirmationDialog`).
- List/Form conversion of the club management/ops pages.
- Acceptance run and screenshot check, once the workflow exists.

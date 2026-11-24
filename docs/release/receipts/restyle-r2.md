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

## Left after run 1 (now handled in round 2, below)
- Static `.font(CYTypography.x)`: done (round 2, batch A/B).
- `ClubDetailView` hero header: name now `.title` bold; join/leave placement kept (see round 2 notes).
- List/Form conversion of club management/ops pages: they were already `List`/`Form` (checked, see round 2).
- Acceptance run: still not possible (see round 2).

---

# Round 2 (2026-11-24)

## Coordinator decisions applied
1. **Contract pins:** one text pin updated in the same commit as its file (listed below). No behavioural assertion was weakened.
2. **R6 shared components merged first:** `origin/restyle/r6-system-rest` (aa235bbab) merged as 26fe5cb28 before any round 2 edit. Round 2 uses `cySheet`, `CYRadius.card/hero/inner` and the R6 `ContentUnavailableView` state kit.
3. **`origin/ci/acceptance`: NOT merged.** It has no green run. All three Acceptance runs on it (45382432691, 45382725772, 45382894882) concluded `failure`. On the latest one, `debug-build` and the four AppUnit shards report `build-failed` on the base itself, and the `gates` job fails the contract ratchet on the known Workshop test (185 vs 184). The decision says merge only on a green run, so this branch has no acceptance run yet.

## Commits (all ≤ 40 files)
| commit | files | what |
|---|---:|---|
| `82364cb71` batch A | 32 + 1 test | radius set, semantic type tokens, sheet detents, inline titles, ClubDetailView name, ClubReadScreen refresh |
| `27b122bef` batch B | 31 | same sweep for the remaining files, LabeledContent, title wrap, no glass on content |
| `cc4b5a888` batch C | 21 | 4/8 spacing grid, segmented club detail tabs, segmented profile tabs |

**69 R2 files were changed in round 2** (90 across both rounds). The other R2-owned files had none of the patterns below.

## Before → after (round 2)
| before | after | sites |
|---|---|---:|
| `CYRadius.lg / md` · `xl / xxl` · `sm / xs` | `CYRadius.card` · `hero` · `inner` (spec §2.3) | 77 |
| literal `cornerRadius: N` | snapped: ≤ 10 `inner`, 11–16 `card`, ≥ 18 `hero` | 25 |
| `.font(CYTypography.x)` / `.font(Theme.Font.x)` (incl. `.weight(.w)`) | `.cyText(.x)` / `.cyText(.x, weight: .w)` | 35 |
| `.caption2` | `.caption` (the floor) | 6 |
| `.sheet { … }` with no detents anywhere in its content | `Group { … }.cySheet()` (system detents, visible drag indicator). `[.medium, .large]` for the city picker and the member welcome sheet; `[.large]` for editors, review, settlement, ops, poll composer and image preview | 17 |
| `presentationCornerRadius(CYRadius.sheet)` (home project editor, merchant application) | removed; the merchant application gets `cySheet(detents: [.large])` | 2 |
| `navigationTitle` with no mode (payout receiver ×2, three fixture hosts) | `+ .navigationBarTitleDisplayMode(.inline)` | 5 |
| `ClubReadScreen` bar 刷新 button on by default | off by default (spec §3.1: pull to refresh only). Club home, members, directory and owned now refresh by pull, like club detail already did. Management pages keep their own refresh buttons because UI tests tap them. | 1 |
| `ClubDetailView` name `.sheetTitle` | `.pageTitle` (`.title` bold, spec §4.9) | 1 |
| `ClubDetailTabBar` underline tabs | segmented-style control: subtle fill track, selected segment lifted on `bgSurface`, `.label` text, 44 pt segments, `matchedGeometryEffect`, selection haptic. Kept as buttons so the `club.detail.tab.<key>` ids stay. | 1 |
| `SocialPublicProfileView` `CYTabs(.underline)` 我的/帖文/成就/关于 | system `Picker(.segmented)` (spec §3.7). The `social.profile.tabs` id is kept; UI tests pick segments by label. | 1 |
| `ChannelRedeemSheet` `HStack { Text; Spacer; Text }` | `LabeledContent` (value `.monospacedDigit()`) | 1 |
| `SocialGuideTemplateSection` title `.lineLimit(1)` | `.lineLimit(2)` (no one-line title truncation) | 1 |
| `SessionOfflineRetrySupport` offline-queue strip on `.ultraThinMaterial` | `CYColor.bgSurface` (no glass on content) | 1 |
| `CYSpacing.xxs` (2) / `s2_5` (10) | `xs` (4) / `md` (12) (4/8 grid, spec §2.4) | 32 |

## Contract pins updated (decision 1)
- `Tests/ContractChecks/test_ui_workbench_navigation.py::test_enrollment_ticket_identifier_does_not_replace_descendant_routes` now expects `.cyText(.cardTitle)` (was `.font(CYTypography.cardTitle)`) on the enroll ticket title. The behavioural part is unchanged: the identifier stays a leaf on the title, and the profile/check-in ids and identity guards are still asserted. No SHA pins were affected.

## Checked and left as they are (not violations)
- **Chevrons:** `ClubCalendarSessionRows` ‹ › is a month stepper; `ClubGovernanceCommandForm` "上一步" is a wizard step in a guarded editor. Neither is a custom back.
- **Glass:** the club hero share circle and the gallery 重置 pill sit on imagery (chrome, spec §3.10). The `ClubReadScreen` refresh capsule floats over content while it reloads. `ClubStoryFixtureHost` is a fixture.
- **Shadow:** the channel 跳到最新 pill floats over the message list (a floating control).
- **Sheets still "without" detents in the scan:** the content types (`CYConfirmSheet`, `CYSheetContainer`, `ClubGovernanceConsequence.sheet`, …) set their own detents. The camera sheets (`MerchantEvidenceCameraCapture`, `PlayNativeCameraSheet`) are camera surfaces. The generic `content()` / `support()` hosts (`ClubManagementReviewOwner`, `ClubOwnerFundsView`) present views that choose their own detents.
- **List/Form:** the R2 management, ops, settlement, members and detail pages were already `List`/`Form` with sections. A scan for hand-built `ScrollView { VStack … Divider }` pages found only the channel chat, the community feed and the welcome sheet, which are content, not settings.
- **Toolbars:** no R2 screen has more than 2 trailing items. **Buttons:** no R2 file has more than one `.borderedProminent`.
- **Join/leave (spec §4.9 asks for leave in a toolbar Menu):** kept as the MP's page-end quiet red row (HANDOFF-R1 MC-20). It already uses `role: .destructive` and a confirmation sheet, and its presenter placement is a behaviour fix (F-08) pinned by tests. Moving it is a behaviour change, so it needs an owner call.

## Local gates (no Swift compiler here)
- `tools/check_typography_lint.py`: PASS (raw text style 32, Theme.Font 35, raw size 53, back chevron 9, hidden back 3, large title 7).
- `tools/check_design_lint.py`: PASS. One raw `Color(.systemFill)` I added in `ClubDetailTabBar` was caught by `test_design_system_component_contracts` and replaced with `CYColor` tokens before commit.
- `tools/check_scaffold.py`: PASS.
- `tools/contract_ratchet.py --check` (clean worktree at the branch head): **185 failing, baseline 184, new 1.** The one new failure is the known pre-existing `test_workshop_paid_professional…bounded_paging`. The merged base (26fe5cb28) gives the same result.
- **Not run:** the Swift build, AppUnit/UI tests and screenshots. The cloud acceptance workflow has never passed (see decision 3) and only triggers on `port/**`. **Nothing here has been compiled.** I kept edits mechanical and reused existing APIs (`cySheet`, `cyText`, `CYRadius`, `CYColor`, `LabeledContent`, `Picker`). The first build to look at: the 17 `Group { … }.cySheet(…)` wraps (sheet content closures are `@ViewBuilder`, so the wrap is legal) and the `SocialPublicProfileView` `Picker`.

## Component requests (still open, for R6 / R0)
1. A shared segmented control that exposes per-segment accessibility ids (`CYSegmentedPicker`). With it, `ClubDetailTabBar` can be a true system `Picker`; R2's local look-alike is the stopgap.
2. The colour re-point (R6 receipt §4.1) and the `CYPillButton` system-style re-point (§4.2) are not done. The club join button, `CYClubJoinStage`, keeps its custom stage until then.

## Screens for acceptance
`docs/port/accept/r2.txt` (19 routes) is unchanged. In round 2, look at: club detail tabs (segmented look, 44 pt), the club home/members/directory pull to refresh with no bar 刷新, the social profile segmented tabs, and the club create city picker sheet (medium detent).

## Left
- The acceptance run, as soon as `ci/acceptance` is green and merged: rebase and iterate.
- The leave-club placement (owner call above), and `CYSegmentedPicker` (component request 1).

DONE-ROUND-2

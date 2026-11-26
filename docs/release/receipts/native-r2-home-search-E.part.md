## Group E: Square (feed, detail, composer, report, workspace)

| File | What changed |
|---|---|
| App/SquareBrowserView.swift | `CYLoadingStateView` → `ProgressView`; `CYEmptyState`/`CYStateLayout` (closed, error, empty) → `ContentUnavailableView` (ids moved to the title `Text`, retry keeps `square.retry`); load-more `CYPillButton` → borderless `Button`; removed `scrollContentBackground(.hidden)` + `bgPage`, the clear picker row background and `CYColor`; `.listStyle(.insetGrouped)`. |
| App/SquareCloudComposerView.swift | Composer rebuilt as a `Form`: `TextField(axis: .vertical)` with a system prompt (no hand-drawn placeholder), author in the section header, counter in the footer, notice as an `info.circle` `Label`, attachments and tools as `Label` rows, announcement as a `Toggle`; Publish / Check result / Close moved to the navigation bar's `.confirmationAction` (as in Mail); drafts page → inset-grouped `List` with `ContentUnavailableView` for no drafts, plus swipe and context-menu delete; review page → `Form` with a `ProgressView`; status screens → `ContentUnavailableView`; removed `CYSkeleton`, `CYColor` backgrounds and the capsule chips. |
| App/SquareCloudFeedViews.swift | Route preview: `Canvas` on `CYNight` → MapKit `Map` + `MapPolyline` (orange, no interaction, double-tap kudos kept); Strava block: removed card background, banner tint and avatar chrome, system fonts; post actions: `CYOptionSheet`/`CYSheetContainer`/`CYConfirmSheet` → `NavigationStack` + `List` of role buttons + `.confirmationDialog` for delete, `.presentationDetents([.medium, .large])`; author `cy/popover` → system `Menu` (the custom `SquareCloudPopover` was removed and had no other users); activity and completed pickers → inset-grouped `List`, `ContentUnavailableView` states with Retry, `.refreshable`. |
| App/SquareComponents.swift | Avatar `cyAnchoredMenu` → system `Menu`; `cyText` → text styles; dropped the `cyPressable` style and the min-frame. |
| App/SquareDeletionViews.swift | `CYConfirmSheet` → `NavigationStack` + `Form` (consequences as `Label`s, title in the header, message in the footer, destructive button row, Cancel in the toolbar), medium/large detents; `CYStatusChip` → `Label` with a tinted symbol; `CYPillButton` → bordered `Button`. |
| App/SquareDetailView.swift | `CYSkeleton` → `ProgressView`; removed `cyMiniListScreen`/`cyMiniCardRow` (now `.insetGrouped`); more-comments `CYPillButton` → `Button`; comment bar → bordered large `Button` inside the existing `CYFooterBar` (no capsule chrome); block `CYModal` → `.alert(presenting:)`; deletion sheet detents are system; `CYColor` → semantic colours; author-delete section uses a `ProgressView` and bordered/destructive `Button`s; play card and issue view → system fonts; `SquareDetailIssueView` → `ContentUnavailableView` (MP empty art kept as the icon). |
| App/SquareGovernanceViews.swift | Sign-in `CYPillButton` → `Button` row in a `Section`; `CYSkeleton` → `ProgressView`; `.insetGrouped`; appeal counter styled as footnote. |
| App/SquarePostLocalMediaPresentation.swift | Removed the rounded clip on the thumbnail and the `SquareFlowNoticeStyle` custom tone; system fonts and semantic red/orange. |
| App/SquarePostVideoViews.swift | `CYSkeleton` → `ProgressView`; `CYStatusChip` → `Label` with a tinted symbol; `CYPillButton` → `Button`; removed `.cornerRadius(8)`; system fonts. |
| App/SquareRelatedTopicView.swift | `CYPillButton` → bordered `Button` with `Label("…", systemImage: "map")`. |
| App/SquareReportFixtureHost.swift | `cyText` → `.font(.caption)` (DEBUG fixture). |
| App/SquareReportProgressView.swift | Row: removed the capsule stage chip and `CYColor`, now secondary text with a tertiary chevron; `CYEmptyState` (empty, error, signed out) → `ContentUnavailableView` (ids kept on title/action); `CYSkeleton` → `ProgressView`; `cyGroupedSurface` → `.insetGrouped`. |
| App/SquareReportView.swift | Discard `CYConfirmSheet` → `.confirmationDialog` (ids `squareReport.discard` / `keepEditing` kept); reason picker `CYSheetContainer` with rounded cards → `NavigationStack` + `List` with checkmark rows and a Cancel toolbar button (`squareReport.reasonCancel`); `CYStatusChip` → `Label`; `CYPillButton` → `Button` rows; `CYSkeleton` → `ProgressView`; removed `cyGroupedSurface`; no-attachments line moved into the section footer. |
| App/SquareWorkspaceView.swift | `CYPillButton` → `Button`; `CYSkeleton` → `ProgressView`; issue `CYModal` → `.alert`; withdraw-location `CYConfirmSheet` → `.confirmationDialog(presenting:)`. |
| App/SquareXcxPostCard.swift | Removed rounded fills on the play card and upcoming cards and the capsule badges; `cyText` → text styles; lifecycle tint is `.orange`. |

Unchanged (non-UI or already native): SquareFixtureSupport, SquareGovernanceFixtureHost, SquareGovernanceSessionAccess, SquarePostLocalMediaInspector, SquarePostLocalMediaPicker, SquareReportSessionAccess, SquareRouteMapProvider, SquareWorkspaceFixtureHost, SquareWorkspaceSecureStorage.

### Not converted / notes
- `CYFooterBar` stays in SquareDetailView, because `test_global_chrome_domain_contract.test_pinned_footer_bars_use_cy_footer_bar` pins it there. Only its content is native now.
- These shared DesignSystem components are still used, because they belong to App/DesignSystem and are out of this lane:
  - `CYSquareRouteMapCard`;
  - `CYSquareShareSheet`;
  - `CYSquareActivityPicker`;
  - `CYSquarePostDraftsSheet` (it has a 4-second undo flow);
  - `cyToast`;
  - `cySheet`;
  - `cyPushedChrome`;
  - `cyDomainScreen`.
- The source "即将开始" horizontal banner strip (`SquareXcxUpcomingStrip`) has no Apple list equivalent. It stays a horizontal `ScrollView` of plain text columns (no card chrome). Its single-row structure is kept so its `.task` loading is unchanged.
- The composer's activity "chips" are now plain `Label` rows with a clear button. The MP `cy/popover` author menu is now a system `Menu`.
- No new localization keys. Every new copy is an existing key or an existing `locale.pick` / `copy(zh, en)` pair.

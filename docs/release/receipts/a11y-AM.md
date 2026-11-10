# VoiceOver audit A (list tail-AM, 180 restyled views)

Code-only, cloud-verified. Scope rule: files changed on any `origin/ui/cloud-*` branch (150 of 180) were skipped; 30 files audited.
Most audited files were already compliant (icon-only buttons labelled, decorative images hidden, cards in NavigationLink/Button already combine): verified, no change needed.

## Fixes
| File | Fixes |
|---|---|
| ActivityBrowserView | Load-more `ProgressView` labelled (`activity.loading`) |
| ClubOpsCustomerViews | Failure title + customer-detail name `.isHeader`; customer row `accessibilityElement(.combine)` (avatar already hidden) |
| JourneyRoleViewSection | Assignment / role / view title `.isHeader` |
| MapPublicStoryNodeDetailView | Node title `.isHeader` |
| ModCreatorIncomeViews | 4 unlabelled `ProgressView`s labelled (inline zh/en like file helper) |
| ModVenueOperationsView | Busy `ProgressView` labelled (inline zh/en) |
| ModInstallationTemplateEditorView | Field titles `.isHeader` |
| NativeNotificationPermissionNudgeView | Status headline `.isHeader` |
| NativeProgressPrivacyView | Loading/saving `ProgressView` labelled (reuses `objects.loading`, no new key) |
| NativeRpgResourceAuthorView | Resource name + group headings `.isHeader` |
| NativeSharedRecoveryAuthorView | "恢复方式 N" heading `.isHeader` |

## Verified, no change needed
Icon-only controls already labelled: ModCreatorIncomeViews refresh, NativeStoryWalkingAuthorView back, NativeAttributeAuthorViews bar preview (label+value), MapCoreEntryHubView legend (swatch hidden, combined), NativeChannelNotificationGlobalView chevron (hidden), MapCoreEntryHubView disclosure `Toggle`s (native value), CooperationBrowserView / ActivityBrowserView cards (NavigationLink label combines).
Remaining 18 audited files (Native*Author*, NearbyMapDiscovery, Cooperation, etc.): native Form/List controls with text labels; no gaps found.

## Skipped (on ui/cloud-* branches)
150 files, list = `tail-AM.txt` minus the 30 above.

## Strings
No new strings: the loading label reuses existing `objects.loading` (Localizable; EN "Loading" / zh "加载中").

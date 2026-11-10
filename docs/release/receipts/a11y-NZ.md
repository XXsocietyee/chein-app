# a11y-NZ (VoiceOver audit B)

List `/Users/fanning/chengyin-refs/tail-NZ.txt` (180 files). Presentation only: accessibilityLabel/Hint/Value/Traits, no behaviour or layout change. Strings go to `docs/release/ui-strings-a11y-NZ.json`.
Merged `origin/ui/main` first (already up to date). 88 files are changed on `origin/ui/cloud-*` branches and were skipped as cloud-owned; 92 were audited.
Most files were already annotated (combined cards, hidden decoration, selection traits, 44pt rows); changes below are the remaining gaps.

## Batch 1
- Headings (`.isHeader`): OfficialActionViews (3), OrderPassPreviewView, OwnedTemplateConfigurationView, ProjectDraftStoryPreviewView (title), ProjectStoryTemplateView, PublisherLifecycleViews (invalid-link title), ReformWorldHostWorkbenchView (2), RoamExperienceHubView, RoamSubpageParityViews (session, shared route, note header), RoamPosterScanView, SearchMapExplorerView (area, layers, layer failure), SearchRoutePreviewView, SocialPublicProfileView (name), SquareDeletionViews (3), TeamPageParityViews, UltimateReleaseReadinessExecutiveSummaryView, UnifiedReleaseAuditHubView.
- Progress bars with a name: roam goal detail (metric), exploration export (`roam.export.title`).
- RoamHistoryToolsRow: tool symbol hidden so "calendar"/"list bullet" is not spoken beside the title.
- SquareDetailView: like button carries `.isSelected` when liked.

## Batch 2
- Image previews with no description now carry one (existing keys `image.retained.preview`, `ownedCover.authorImage`): OwnedTopicCoverAuthorView (local, server), ProjectNodeImageAuthorView, ProjectStoryImageAuthorView.
- SearchRoutePreviewView: each turn step is one stop (number, instruction, distance).
- RoamPassportPrivateToolsViews: capsule unlock presets expose `.isSelected` (was colour only).
- PublisherLifecycleViews: price slider has a label and a "¥N" value.
- RoamSubpageParityViews: shared-walk date line is one stop.
- SettingsPrivacyLocationView: "older" button keeps its label while its spinner shows.
- Audited, no change needed: kit skeleton/loading states (label already in kit), Map views (annotations are labelled buttons; a container label could hide them, left alone), stamp slip (VoiceOver path with plain buttons already present).

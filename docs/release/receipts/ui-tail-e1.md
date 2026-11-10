# UI tail (e1 family) receipt

Presentation only, no behaviour or Core edits. NOT COMPILED locally; cloud Build+Test per push.
Shared helpers: `e1HeroRow()` / `e1ActionRow()` in App/E1CommerceComponents.swift (Form/List hero + pill rows).

## Batch 1
- ActivityBrowserView: CUV states -> CYEmptyState (unavailable/failed/empty, ids kept)
- ActivityDetailView: sign-in / load-failed / stale states -> CYEmptyState (club gate kept: custom action)
- ActivityEditingView: hero title, grouped surface, pills (review primary), one title
- ActivityHostCancelView: hero, skeleton loading, pills (confirm primary), grouped surface
- ApprovedTopicReviewRequestView: hero (x2), skeleton loading, pills, grouped surface

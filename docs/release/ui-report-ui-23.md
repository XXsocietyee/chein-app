# UI-23 report — Roam*, City*, Map* (player, DARK) — NOT COMPILED

Scope: 88 owned files in `App/` matching Roam*/City*/Map*. Reviewed by scanning for raw colours/fonts/scheme overrides; most files already clean or use tokens.

| File | Change | Pattern | Theme | New keys |
|---|---|---|---|---|
| App/CityPlayerView.swift | lifecycle chip background -> `CYColor.successSoft` / `borderSubtle` | token swap | dark | none |
| App/MapVisualLayerControlSectionView.swift | palette badge, contrast status text, datum badge -> `warningSoft/successSoft/textSecondary/dangerText/infoSoft` | token swap | dark | none |
| App/RoamLiveSessionView.swift | active dot -> `successText` / `textTertiary` | token swap | dark | none |
| App/RoamPassportPrivateToolsViews.swift | achieved chip -> `successSoft` / `borderSubtle` | token swap | dark | none |

Skipped (owned by wave 1, changed in cloud/ui-01..11): App/RoamHistoryViews.swift, App/RoamPassportHistoryView.swift.

Not changed deliberately:
- MapCoreEntryHubView / MapVisualLayerControlSectionView `Color(red:...)` — map style tokens from data (not UI chrome).
- RoamMedalShareView (black/gradient share-card artwork), RoamStampCameraView / RoamStampFramingCamera (UIColor.white image canvas fill), RoamSubpageParityViews:492 (scratch-card gray, game art): intentional artwork.
- Remaining ~80 files: no raw colours found; deeper layout/Dynamic Type polish not attempted (cannot compile or view).

Files touched: 4 source + report + strings json. New component files: 0. New string keys: 0.

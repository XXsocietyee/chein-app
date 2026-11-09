# Design spec D6: player play / roam / map (dark, immersive)

Pairings (docs/parity/page-map.csv): `pages/roam/index` -> RoamBrowserView/RoamLiveSessionView (ref `chengyinhub-xcx/docs/screenshots/roam-intro-nrc.png`);
`pages/play/index` -> PlayExperienceView/PlaySessionView (ref: mini-program play top bar + bottom run stack); search map -> `docs/evidence/player-e2e-20260927/015-searchmap.png`.
Roam start/passport home tabs (RoamHomeTabsView) belong to D2 and are untouched.

Principles: full-bleed map, <=3 floating glass controls, ONE primary action, node/task info in a persistent bottom sheet with detents (peek 236pt / medium / large), game logic untouched.

## Screens (ASCII)
```
PLAY (d6-play)                ROAM (d6-roam)                 SEARCH MAP (d6-search)        LIVE ROAM (d6-live)
(<)            (loc)(...)     Roam            (book)(...)    (<) [ search routes ] (loc)   [ time | fog | km ]
   map + callouts                map + fog                    map + white callouts
 ------ sheet ------           walk anywhere - fog lifts                                   map + fog
 [task 2/5][120 m]           (i)   ( GO )   (map)                [ View all 8 results ]    (i)  (Pause)  (flag)
 Find the Lantern Gate                                                                       
 [   I've arrived   ]  <- primary
 Next stops (rows)
```
## Stays / demoted
- Play: back, locate, more = the 3 controls. Refresh, route map, end run, hints/skip stay in the sheet's large detent or the More menu (never removed).
- Roam: passport + more in one glass capsule; rules (i) and nearby list (map) flank GO.
- Search map: filter demoted from the top bar into the results sheet; locate kept. Primary = View all results.
- Live roam: Pause is the one primary (white circle); rules and finish are glass circles; finish keeps its confirmation dialog.
## States
loading = CYSkeleton in the sheet (fixture d6-play-loading); empty/error = CYEmptyState/CYErrorState in the sheet; unknown values = em dash; offline = CYMapPlaceholder.
## Type/spacing
CYHeroHeader-weight titles (heavy), kit radii (sheet 28, pills capsule), 16pt gutters, tabular numerals for stats.

# Design report D6: player play / roam / map (branch `ui/d6`)

Build: `design-run.sh d6 … --design-fixture d6-{play,play-loading,roam,search,live}`, BUILD_EXIT=0, no logic changes.
New: `App/DesignSystem/CYMapChrome.swift` (CYGlassButton, CYGlassCapsule, CYGoButton white circle, CYMapPlaceholder, CYMapCallout, `cyMapSheet` persistent detent sheet, opens at .medium at accessibility text sizes). Fixtures: `App/DesignFixtures/D6Fixtures.swift` (DEBUG, synthetic, map is a static placeholder).
Shots in `design-report-d6-shots/`: `en-*.png` (EN default), `zh-play/zh-roam.png` (zh default), `zh-play-XL/zh-search-XL.png` (zh, accessibility XL), `compare-roam.png` (ref roam-intro-nrc), `compare-search.png` (ref 015-searchmap), `compare-live.png`. Play has no mini-program screenshot: closest ref is the roam map chrome; stated honestly.

## Checklist (design fixtures)
1 info order matches refs (roam: title, passport/menu, info·GO·map; search: back·search·locate, callouts, results pill) yes. 2 one primary per screen (sheet pill / GO / results pill / Pause) yes. 3 <=3 other controls yes. 4 dark yes. 5 no violet yes. 6 kit radii/pill/chip/list rows yes. 7 loading = skeleton in sheet (`d6-play-loading`, not screenshotted); empty/error use kit states (not shown). 8 XL: play and search checked, no clipping of controls (placeholder callouts clip, fixture only). 9 EN + zh checked. 10 builds, no logic changes.

## Demoted controls
Search map: filter moved from the top bar into the results sheet. Play: refresh/route map/end run/hints stay in More or the large detent. Live roam: finish is a glass circle (keeps confirmation dialog).

## Open issues (honest)
- The REAL views (PlayExperienceView, PlaySessionView, SessionPlayRuntimeView, RoamBrowserView, RoamLiveSessionView, SearchMapCanvas) are NOT yet re-skinned: they are logic-heavy lists needing model/reader fixtures. Only the kit chrome + design fixtures are delivered; applying `CYMapChrome` to them is a follow-up (needs a synthetic PlaySnapshot / roam reader fixture).
- Roam start/passport home (RoamHomeTabsView) is D2's. Fog vignette on the placeholder is faint; real MapKit fog untouched.
- Loading/empty/error fixtures not screenshotted; light-mode N/A.

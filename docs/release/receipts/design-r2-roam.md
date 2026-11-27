# Receipt · design-r2-roam (round 2)

Lane `design/r2-roam` from `origin/ui/combined-r7`. Brief: `origin/design/handoff-r2:docs/briefs/round2-1127.md`
(row `design-r2-roam` + English sweep finding d2-roam), principles `design-principles.md` (P1–P16), round-1 receipt
`docs/release/receipts/design-pass-roam.md` ("Not done" items). MP source: `origin/mp-source:chengyinhub-xcx/`
(`pages/roam/index.wxml` settle :890-958, `subpackageMember/components/cy/scene-roam-poi-detail/index.wxml`).
**Not compiled (no Swift toolchain in the cloud) — needs a coordinator `build_sim`.** Nothing deployed. Merchant
features and the story-flow theme untouched.

## Done

| Screen | Failed before | Fix (native) | file |
|---|---|---|---|
| Roam finish report (`RoamFinishReportView`) | P16: route sat below everything, close was an ✕, share was a bottom pill, no date · place line, no stamps | Top bar: share icon + one **Done** (`action.done`; identifiers `roam.finishReport.share` / `.close` kept). Then the route panel (`RoamRouteSketchView`, 260 pt, 查看漫游数据 link kept), MP title `{zone} · 自由漫游`, **date · place** line (place = the settle chip address, moved out of the map overlay), hero 处到达 (P1, rolls once), MP six cells in a 3-column grid (2 columns at accessibility sizes), MP stamp strip, medal tiles, route story, exits | `App/RoamFinishReportView.swift` |
| Finish stamp strip (new) | Round 1: left out because `RoamHistoryRecord.photos` are MP-style local paths and no native loader existed | `RoamStampPhotoSource` classifies a path: `https://` → `AsyncImage`; `file://`, absolute, or Documents-relative → read off the main thread, downsampled (`preparingThumbnail`), **only inside the app sandbox** (`..` cannot escape); `wxfile://`, `http://tmp/`, `http://usr/` (WeChat sandbox) → a quiet `seal` placeholder, never a broken image. Strip = MP `finish-stamps` (horizontal, caption MP fallback 漫游打卡 / "Roam stamp"); hidden when empty. VoiceOver: "Roam stamp, Stamp 2 of 5" | `App/RoamStampPhotoStrip.swift` |
| Badge wall from the finish report | Round 1: `RoamBadgeWallDestination` accepted only the session's own roam reader | `SessionRoamBadgeWallDestination` also accepts a `RoamFinishedHistoryReader` whose identity has the same scope `storageKey` and epoch as `session.roamExperienceReader`; `RoamBadgeWallReader` still re-checks the account against the profile reader on every read. Finish report shows 查看全部勋章 (`roam.finishReport.collection`) when medals > 0; this also fixes the same link in `RoamHistoryDetailView` opened from the finish report | `App/RoamBadgeWallDestination.swift`, `App/RoamFinishReportView.swift` |
| Place / checkpoint detail (`RoamItemDetailView`) | P15: kind label alone at the top; status, challenge, stamp, poster, share scattered (status section, toolbar) | `RoamPlaceHeaderView`: name → (icon) category · area → live status in colour (not open = orange `roam.notPublished`, completed = green, open = accent "Challenge open / 可挑战"), then a horizontally scrolling capsule row: **Challenge** (`.borderedProminent`, P3, only while open), Stamp camera, Scan poster, Share (`.bordered` capsules). Same destinations and identifiers (`roam.poiChallenge.open`, `media.poster.open`, `roam.detail.share`; new `media.stamp.open`). Removed the duplicates (status-section rows, toolbar share, the separate 未开放 section). Favourite (RoamPOIActionRows) and directions (reviewed `PlatformExternalMapHost`) stay in their sections | `App/RoamPlaceHeaderView.swift`, `App/RoamItemDetailView.swift` |
| Roam map home, en sweep d2-roam | Nav title black on the navy map; info / map buttons and the collapsed "2 ⌃" near-invisible | Inline bar on `.regularMaterial` (`toolbarBackground(.regularMaterial)` + `.visible`, map mode only) so the system title/overflow keep `.primary`. Rules + open-map floating controls are 50 pt (scaled) `.regularMaterial` circles with `.primary` glyph, hairline and soft shadow (`RoamMapGlassControl`); GO stays `.borderedProminent`. Peek line uses `.primary`/`.secondary` on a `.regularMaterial` rounded rect (the panel is always black; `CYColor.text*` is black in light mode) | `App/RoamBrowserView.swift` |

P12: titles/captions wrap (`fixedSize(vertical)`), action pills scroll horizontally, grid drops to 2 columns at
accessibility sizes, no fixed text widths. Reduce Motion: no new motion added.

## Not done

- **P7 first-walk headline:** the MP settle has no "first roam" state (`pages/roam/index.wxml` :890-958), so none invented.
- **P16 "save" in the top bar:** the MP has no save for a finished walk (it is archived automatically); only share + Done.
- **Per-stamp captions:** native `RoamHistoryRecord.photos` is `[String]` (the decoder drops MP `item.name`), so every
  caption is the MP fallback 漫游打卡. Keeping names would need a Core model change (out of scope for this lane).
- **Native photo capture into history:** `RoamLiveSessionController.archive` writes `photos: []`; the strip only shows
  stamps from migrated MP/Flutter records until native capture writes paths (any Documents-relative path will load).
- **P15 photo strip / social proof under the header:** no MP field for "saved by friends"; the merchant gallery stays in
  its merchant section (merchant out of scope).
- **Directions as a capsule:** directions go through the reviewed `PlatformExternalMapHost` (confirmation dialog,
  gated state), which renders a pill + state text; left in 关于 rather than bypassing the review.

## Risks for first compile

- `RoamPlaceHeaderView<Actions>` generic with a `@ViewBuilder` init; the actions closure has an `if` + 3 views.
- `.buttonStyle(.bordered).buttonBorderShape(.capsule)` applied to `poiShareButton` (an `@ViewBuilder` property
  that may be empty) — fine in SwiftUI, but check the share sheet still opens from a `ShareLink` inside a `List` row.
- Several `NavigationLink`s with explicit button styles in one `List` row: each should be independently tappable;
  verify the row does not forward taps to the first link.
- `RoamStampPhotoView`: `switch` on an enum with associated values inside a `ZStack` builder; `nonisolated private
  static func read` using `Task.detached` returning `Data?`.
- `toolbarBackground(.regularMaterial, for: .navigationBar)` on the root map tab — check the large-title list mode is
  unaffected (modifier only applies when `inline` / map mode).
- `RoamFinishReportView` `head`: `cyText` applied to an `HStack` (View overload) containing `Text` + `@ViewBuilder dateLine`.

## Strings

Fragment `docs/port/strings/design-r2-roam.json` (6 keys, en + zh-Hans) merged into `Resources/Localizable.xcstrings`.

## Gates

- `generate_project.py` ✓ · `check_scaffold.py` PASS · `check_a11y_lint.py` PASS (0 new)
- `contract_ratchet.py --check`: **104 failing, baseline 104, new 0, fixed 0**
- New file read in `RoamStampPhotoStrip.swift` (`.documentDirectory`) catalogued in
  `docs/ops-safety/client-data-catalog.json` (read-only, no own data); `audit_client_ops_surfaces.py` exit 0.
- `check_l10n.py`: 6 problems, all pre-existing on `origin/ui/combined-r7` (`E1CommerceComponents.swift`,
  `RegistrationStripePaySection.swift`, …); this lane adds no CJK literals.

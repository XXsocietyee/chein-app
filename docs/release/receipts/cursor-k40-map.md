# K40 · Map, search, and nearby (`cursor/1128-k40-map`)

Scope is map, search, and nearby wiring. Roam-tab official work (fog, stamps, check-in, presence, official routes, US roam, city board, team writes) stays with the roam agent. No visual restyle.

Base `origin/ui/combined-r7` at pin `a7c956335`. Counts below: **n** = closed in this change, **m** = already fixed at a cited SHA, **k** = still open inside this scope (off by design, no copy, restyle refused, or left for the roam agent). Home map/search rows the function audit already marked Works were rechecked and are not counted.

**n = 2, m = 6, k = 4.**

## Closed here (n)

| Audit | What changed |
|---|---|
| Plan H-04b | Guest GET `/api/city/nodes` and `/api/city/nodes/{id}`. The two `SearchMapService` token gates are gone. The composition admits that pair only for a pure China guest when the deployment grants `.manualMap` and a manual area is already selected. Places, nearby, favorites, and complete stay signed in. The publish place picker still requires `manualMapApprovalRevision`. |
| Plan R-07 | `RoamRouteNode` decodes `namePinyin` and `nameInitials` from `/api/map/nearby`. The live address sheet matches MP `matchPlaces` (name/address contains, pinyin prefix, initials prefix) across nearby places and registered shops, then the existing remote place-search / city-node keyword leg, capped at five. A shop pick moves the camera and selects `RoamLiveMapPick.shop`. The client does not invent pinyin. |

Backend: no branch. `NearbyNodeVO` on `us/r3-functional` already sends `namePinyin` / `nameInitials`. `ApiCityNodeController` already returns `CityNodeGuestProjection` for `uid() <= 0`, and SecurityConfig already permits those GETs. No 404.

## Already fixed (m)

| Audit | SHA | Recheck |
|---|---|---|
| H-05e guest club search | `7d8d5e6db` | `clubRows` no longer refuses a nil token. |
| H-07 / plan #26 place pickers | `309b28d7d` | Player `PublishingMapKitAdapter.playerPublishing` is on, with tap-to-drop. Merchant adapters stay off. |
| P1-21 Apple Maps driver | `401fd7d63` | `PlatformConsumerSessionOwner.appleMaps` is the session maps consumer. |
| P2-3a map search opens on a known area | `a4a44254f` | Home map uses `session.roamArea`, otherwise `HomeCityCentre`. |
| H-04a / P2-3b home city | `c2e84e360`, menu `85aaf303f` | One foreground fix, nearest supported 首页 city, coordinate never sent. This is the on-device match, not a reverse-geocode POST. |
| Plan #25 / R-04c nearby events | `3dc4a042a` | China player lease for GET `/api/roam/hangout/nearby`. |

Function-audit home rows that were already Works (map button, viewport search, filters, global search lanes, history, scopes, result navigation, template results, 在地图上找, 附近活动 rail, stream address → Apple Maps) still match the current tree. Guest city nodes were the remaining hole in that surface and are the H-04b row above.

## Left (k)

| Audit | Why it stays |
|---|---|
| J-13 / plan #23 walking navigation | Off by design. K13 does not invent MapKit regions. `walkingNavigation` stays nil. |
| P1-17 漫游 home device location | Roam-tab. The area still comes from `RoamAreaPicker` / `roamArea`. |
| H-05c map layer explanation | The MP has no such copy. None was added. |
| ADA d2-search, d2-search-results, map-control contrast, roam map hero | Visual restyle. Wiring only on this pass. |

Out of scope, not in n/m/k: fog (`3a60af988`, already live), presence, stamps, check-in, official routes, US roam, city board, team writes, P2-3d template tap, H-01c city rail, H-02a continuation card.

## Gates

- `python3 tools/generate_project.py` PASS
- `python3 tools/check_scaffold.py` PASS
- `python3 tools/check_a11y_lint.py` PASS
- `python3 tools/check_design_consistency.py` PASS
- `python3 tools/check_search_map.py` PASS
- `python3 tools/check_appsession_ratchet.py` PASS. AppSession stays 7977. AppCompositionRoot shrank 4175 → 4173 and the ceiling moved with it.
- `python3 tools/contract_ratchet.py --check` new 0 (46 failing, baseline 46, fixed 0)
- No `String(localized:)`. Init order `devices`, `sensors`, `artworkHosts` untouched. `PlayerLaunch.merchantCenterEnabled` stays false in Release. Money switches untouched. Public store pages untouched.
- Swift toolchain is not on this machine, so the new XCTest cases were not executed here.

## Proof

- `Tests/CoreTests/SearchMapCityNodeReadTests.swift` guest city-node GET sends no Authorization.
- `Tests/CoreTests/SearchMapTests.swift` guest city search reads nodes and activities; guest city-node detail sends.
- `Tests/AppUnitTests/ManualMapCompositionTests.swift` guest city search decodes poi 42 with no Authorization; guest `api/roam/pois` does not dispatch; a bearer token, a partial identity, and an area change stay closed.
- `Tests/AppUnitTests/GuestMapCityNodeAdmissionTests.swift` China pure guest, city nodes and city-node detail only.
- `Tests/CoreTests/MapAddressMatchTests.swift` MP three-way match and lenient pinyin decode.

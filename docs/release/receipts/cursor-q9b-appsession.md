# Q9b AppSession search and official-event glue

Base `0e1cf578a0e710803d49e6bc1151a53b4a8dfe24` on `origin/ui/combined-r7` (message starts "Integrate Cursor round 4"). The tip had not moved. No rebase.

Branch `cursor/q9b-appsession`. No pull request.

## Line counts

`tools/check_appsession_ratchet.py` measures `splitlines()` against `CEILINGS`.

| File | Before lines | Before ceiling | After lines | After ceiling |
|---|---:|---:|---:|---:|
| `App/AppSession.swift` | 8193 | 8193 | 8171 | 8171 |
| `App/AppCompositionRoot.swift` | 4184 | 4184 | 4184 | 4184 |

The AppSession ceiling is set back to 8171. It was not raised. `AppCompositionRoot.swift` stays at 4184. After the move, measured size equals each ceiling, so the ratchet prints `PASS appsession ratchet` with no `NOTE`.

## Move

The W2-player-content wiring (22 lines) left `AppSession.swift`. The same readers are built from `App/PlayerContentSessionGlue.swift`.

- `searchMapReader` is still `PlayerContentSearchMapReader` around a `SearchMapSessionReader`. `categories` still calls `categoryList`. `search` still calls `searchTopicList`, `searchActivityList`, `searchClubList`, and `searchMerchantList`. City, merchant, and nearby reads still go to the inner `SearchMapSessionReader`.
- `officialEventReader` is still `PlayerContentOfficialReader` around an `OfficialSessionReader`. `events(city: nil)`, `myEvents`, and `canPublish` still call `officialEvents`, `officialMyEvents`, and `officialCanPublish`. A non-nil city filter still uses the inner reader (`events(city:)` returns `inner.events(city:)`).
- `topicSelfPlayFlow` still wraps `TopicSelfPlayHTTPClient` in `PlayerContentSelfPlayClient`.

`python3 -B tools/generate_project.py` registered `App/PlayerContentSessionGlue.swift`. `project.pbxproj` was not hand-edited. `tools/current_ci_manifest.json` was not edited.

View signatures of `SettingsView`, `MerchantVerifyRecordsSections`, `PlatformConsumerSessionOwner`, `RoamPOIActions`, `JourneyReportViews`, `TeamHomeView`, `TicketWalletView`, `TopicXcxSections`, `ClubDetailView`, and `ClubWorkbenchKit` were not edited.

## Checks

`python3 -B tools/check_appsession_ratchet.py`

- `PASS appsession ratchet`

`python3 -B tools/check_scaffold.py`

- `PASS appsession ratchet`
- `PASS structural checks: 5066 Swift source files, 18122 bilingual keys, references, scheme, read-only expected project equivalence`
- design lint scanned 1796 App Swift files

No `swiftc`. This receipt does not claim a parse.

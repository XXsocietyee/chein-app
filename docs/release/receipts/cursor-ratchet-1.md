# cursor-ratchet-1

Base `ebf6c160ce73880807c07cf3cc10aa829e83d75e` on `ui/combined-r7`. That commit stayed the parent. No rebase.

Branch `cursor/ratchet-1`.

## Line counts

`tools/check_appsession_ratchet.py` measures `splitlines()` against `CEILINGS`.

| File | Before lines | Before ceiling | After lines | After ceiling |
|---|---:|---:|---:|---:|
| `App/AppSession.swift` | 8171 | 8171 | 7994 | 7994 |
| `App/AppCompositionRoot.swift` | 4177 | 4177 | 4177 | 4177 |

177 lines left `App/AppSession.swift`. 176 of those are the discovery, merchant, and club catalog reads. The extra line was the blank line between that block and the next extension. The AppSession ceiling is 7994, the same as the file. It was not raised, and it is not below the file. `App/AppCompositionRoot.swift` was not edited. Its ceiling stays 4177.

## Move

Existing methods only. Call sites are unchanged. Pay, refund, payout, withdrawal, quote, registration create, and pricing confirm were not edited.

Moved into `App/AppSession+DiscoveryReading.swift`:

- `extension AppSession: DiscoveryReading, MerchantReading` (`readDiscovery`, template metadata requests, public topic template reads, `readMerchant`, `merchantAccess`, dashboard, todo, events, orders, projects)
- `extension AppSession: ClubReading` (`isClubConfigured`, `clubIdentity`, `clubDiscoveryScope`, `clubMerchantLocality`, `clubHome`, `clubOwned`, `clubDirectory`, `clubDetail`, `clubMembers`)

Stored properties stayed on `AppSession`. These are no longer `private`, so the extension file can read or write the same storage. The assignments and increments are the same statements as before:

- `compositionViewerRevision`
- `publicTemplateDetails`
- `discoveryService`
- `merchantService`
- `merchantOnboardingService`
- `merchantAccessRecord`
- `merchantClubAccessRevision`

`python3 tools/generate_project.py` registered `App/AppSession+DiscoveryReading.swift`. `Questify.xcodeproj/project.pbxproj` was not hand-edited. `tools/current_ci_manifest.json` was not edited.

## Ratchet

`python3 -B tools/check_appsession_ratchet.py`

```
PASS appsession ratchet
```

No `NOTE` line. No `swiftc`. This receipt does not claim a parse.

`python3 -B tools/check_scaffold.py` also passed, including `PASS appsession ratchet` and read-only expected project equivalence (`5111` Swift source files).

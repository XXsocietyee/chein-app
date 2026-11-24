# Q9 AppSession / AppCompositionRoot ceiling

Base `b0ac0108d0a5a9739ababecbbc61284cae5a8043` on `origin/ui/combined-r7` (message starts "Integrate F-agent round 2"). The tip had not moved. No rebase.

Branch `cursor/appsession-ceiling`.

## Ceilings

`tools/check_appsession_ratchet.py` measures `splitlines()` against `CEILINGS`.

| File | Before lines | Before ceiling | After lines | After ceiling |
|---|---:|---:|---:|---:|
| `App/AppSession.swift` | 8180 | 8180 | 8171 | 8171 |
| `App/AppCompositionRoot.swift` | 4187 | 4187 | 4184 | 4184 |

The ceilings are set back to 8171 and 4184. Neither ceiling was raised. After the move, measured size equals each restored ceiling, so `check_appsession_ratchet.py` prints `PASS appsession ratchet` with no `NOTE`.

## Move

Existing code only. Call sites are unchanged.

- `UnconfiguredRegistrationBackend` and `extension AppSession: MerchantOnboardingObserving` moved to `App/UnconfiguredRegistrationBackend.swift`. The struct is no longer `private`, so `AppSession.swift` can still construct it. The three methods still throw `APIError.notConfigured`.
- `ReviewedOrientOfficialRoute.sameOrigin(_:_:)` moved to `App/ReviewedOrientOfficialRoute+Origin.swift`. `acceptsRead` and `acceptsWrite` still call `sameOrigin(url, baseURL)`. The helper is no longer `private`, so those call sites, which stay in `AppCompositionRoot.swift`, can still reach it.

`python3 tools/generate_project.py` registered the two new `App/*.swift` files. `project.pbxproj` was not hand-edited. `tools/current_ci_manifest.json` was not edited.

## Scaffold

`python3 -B tools/check_scaffold.py`

Before:

- `PASS appsession ratchet`
- `PASS structural checks: 5063 Swift source files, 18122 bilingual keys, references, scheme, read-only expected project equivalence`
- design lint scanned 1793 App Swift files

After:

- `PASS appsession ratchet`
- `PASS structural checks: 5065 Swift source files, 18122 bilingual keys, references, scheme, read-only expected project equivalence`
- design lint scanned 1795 App Swift files

`python3 -B tools/check_appsession_ratchet.py` before and after: `PASS appsession ratchet`.

No `swiftc`. This receipt does not claim a parse.

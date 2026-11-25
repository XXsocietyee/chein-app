# Q9c AppCompositionRoot deregister contract glue

Rebased onto `b5b9d900373c2062c4daf916f64a0184e20c63af` (`origin/ui/combined-r7`, message starts "Integrate Claude round 4"). That tip had not moved past the named SHA.

Branch `cursor/q9c-composition`. No pull request.

## Line counts

`tools/check_appsession_ratchet.py` measures `splitlines()` against `CEILINGS`.

| File | Before lines | Before ceiling | After lines | After ceiling |
|---|---:|---:|---:|---:|
| `App/AppSession.swift` | 8171 | 8171 | 8171 | 8171 |
| `App/AppCompositionRoot.swift` | 4224 | 4224 | 4177 | 4177 |

`b5b9d900` had raised the composition ceiling to 4224. This branch keeps one ceiling for that file and sets it to the line count after the extraction, 4177. It was not raised. `AppSession.swift` stays at 8171 and was not edited. Measured size equals each ceiling, so the ratchet prints `PASS appsession ratchet` with no `NOTE`.

## Move

The deregister checks left `AppCompositionRoot.swift`. They run from `App/AccountComplianceContractGlue.swift`. `AccountComplianceCompositionRoute.accepts` still chooses the route. Later App merges on `b5b9d900` stayed in `AppCompositionRoot.swift`. The extra lines removed here are the deregister apply check this branch owns.

- Status still returns true for an empty GET, then calls `AccountPublishMPContract.deregisterStatusRequest` through `matchesContract` (method, Content-Type, and body).
- Precheck and cancel still return true for an empty POST. Precheck still calls `deregisterPrecheckRequest`. Cancel still calls `deregisterCancelRequest`.
- Apply form still calls `deregisterApplyRequest` with `requestId` and `smscode`, and still requires `AuthChannelInput.code`. That check runs when the multipart guard does not match. A form body cannot pass the multipart content-type prefix, so the contract call still happens only for the form shape.
- Multipart apply still calls `AuthRequestBuilder.makeFormRequest`. The `api/user/deregister/apply` path string stays in `AppCompositionRoot.swift`. Consent routes are unchanged.
- `merchantMarketingGates.settlement` stays `true`. That is the MP-first prediction-settle gate on the new base, not a second copy of the deregister gate.

`python3 -B tools/generate_project.py` registered `App/AccountComplianceContractGlue.swift`. `project.pbxproj` was not hand-edited. `tools/current_ci_manifest.json` was not edited.

## Checks

`python3 -B tools/check_appsession_ratchet.py`

- `PASS appsession ratchet`

`python3 -B tools/check_scaffold.py`

- `PASS appsession ratchet`
- `PASS structural checks: 5074 Swift source files, 18149 bilingual keys, references, scheme, read-only expected project equivalence`
- design lint scanned 1801 App Swift files

No `swiftc`. This receipt does not claim a parse.

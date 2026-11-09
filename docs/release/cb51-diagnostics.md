# CB51 local diagnostics plan

Base: `origin/rc/20261108`. This is a local measurement plan. It adds no third-party SDK, no package dependency, no network client, and no background location mode. Version stays `0.1.0` (`1`) in `Config/Base.xcconfig`. Password login, bank-card withdrawal, and virtual goods stay off. `47.103.124.64` stays disallowed. Nothing here was deployed, and this workspace did not run `xcodebuild`.

`tools/current_ci_manifest.json` was not refreshed.

## Decision

Diagnostics stay on the device and use Apple frameworks only:

- `os_signpost` through `OSSignposter` (`import os`). Subsystem `Questify.CB51`, category `.pointsOfInterest`.
- `MetricKit` as a plan for the four diagnostic categories already named in `Core/CrashResilienceAndMetricKitDiagnosticsAudit.swift`. This change does not `import MetricKit` and does not call `MXMetricManager.shared.add`.

No Firebase, Sentry, Bugsnag, Crashlytics, Datadog, Amplitude, or other vendor SDK. `Package.swift` gains no dependency. `tools/generate_project.py` still vendors only GLTFKit2.

## Already in the tree

| Piece | File | What it already does |
|---|---|---|
| Hot-path signposts | `Core/NativePerformanceSignposts.swift` | Six static Points of Interest on subsystem `Questify.Performance`. Names are `StaticString`s. No account, route, coordinate, URL, or content value is attached. |
| Trace tools | `tools/signpost_measure.py` | `record`, `export`, `summarize`, `compare`. `record` and `export` refuse to run off macOS. Traces stay local. |
| MetricKit audit | `Core/CrashResilienceAndMetricKitDiagnosticsAudit.swift` | Names crash, hang, CPU-exception, and disk-write diagnostics. It does not subscribe and does not upload. |
| Redaction audit | `Core/ProductionTelemetryAndPrivacyRedactionPipelineAudit.swift` | Requires the signpost pipeline to mask tokens, phone numbers, precise coordinates, and chat or draft text. |

CB51 does not widen `NativePerformanceSignposts`. Those six intervals stay static and are not copied into a second poster.

## os_signpost

`Core/CB51LocalDiagnostics.swift` is the gated recorder.

- The flag is the environment variable `QUESTIFY_CB51_DIAGNOSTICS`. The recorder is on only when that value is exactly `1`.
- Empty, `0`, `true`, `yes`, and any other value leave it off.
- The flag is not set in `Config/Base.xcconfig`, `Config/Info.plist`, `Config/Questify.entitlements`, or the shared schemes.
- No app call site constructs the recorder. A later local debug run may construct it. Shipping screens do not.

Catalog (static names only):

| Point | Name |
|---|---|
| Map frame | `cb51.mapFrame` |
| List scroll | `cb51.listScroll` |
| Image decode | `cb51.imageDecode` |
| Metric summary | `cb51.metricSummary` |

Each `measure` emits one closed interval: `beginInterval` then `endInterval` on the `StaticString` for that case. There is no `OSLogMessage`, no string interpolation, and no metadata argument. The interval is not opened when the flag is off, and `OSSignposter` is not created on that path.

`tools/signpost_measure.py` remains the way to export a trace. Do not commit traces.

## MetricKit

The subscriber is not installed.

A later debug-only subscriber, behind the same flag, may conform to `MXMetricManagerSubscriber` and implement `didReceive` for `MXMetricPayload` and `MXDiagnosticPayload`. It must reduce each payload to a count before calling `recordMetric`:

| Audit category | What the count is |
|---|---|
| `crashDiagnostic` | `crashDiagnostics?.count` |
| `hangDiagnostic` | `hangDiagnostics?.count` |
| `cpuExceptionDiagnostic` | `cpuExceptionDiagnostics?.count` |
| `diskWriteExceptionDiagnostic` | `diskWriteExceptionDiagnostics?.count` |

The count is a magnitude. It is not an account id, a user id, or a coordinate. The subscriber must not read `callStackTree`, hang diagnostic text, or metadata dictionaries into a signpost, a log line, or `CB51DiagnosticRecord`. It must not upload the payload and must not add a backend route. `MXMetricManager.shared.add` stays unwired until that subscriber exists and the flag is set.

This change does not add that subscriber, so the process does not retain MetricKit payloads.

## Privacy review

`CB51DiagnosticRecord` stores two fields: `name` and `count`. `name` is an enum raw value from the signpost catalog or from `MetricKitDiagnosticCategory`. `count` is a non-negative integer. There is no location field, no token field, and no account-id field.

`measure` and `recordMetric` take an extra unlabeled `String` so a caller can hand in a secret. The parameter has no internal name, so the body cannot read it. It is not passed to `OSSignposter`, not appended to `records`, and not included in `rendered()`.

| Data | Signpost | Metric record |
|---|---|---|
| Location trail (coordinates, route polyline, place sequence) | Not a parameter and not a field. No `CLLocation` use. | Not a field. A payload's call stack is dropped, not counted as a trail. |
| Token (session, bearer, refresh, authorization header) | Not a field. The unlabeled string is discarded. | Not a field. Metadata dictionaries are not copied. |
| Account id (user id, account id, phone) | Not a field. | Not a field. The count is an array length, not an identifier. |

Also excluded from both channels: chat or draft body, media URLs, and raw request or response bodies. The existing redaction audit's signpost rule stays in force.

Location collection is unchanged. This plan does not add `NSLocationAlwaysUsageDescription`, `NSLocationAlwaysAndWhenInUseUsageDescription`, `UIBackgroundModes`, `allowsBackgroundLocationUpdates`, `startUpdatingLocation`, or `requestAlwaysAuthorization`.

## Gates left off

- Password login. `AppSession.canUsePassword` is `false` outside `DEBUG` (`App/AppSession.swift`). This plan does not edit that switch.
- Bank-card withdrawal. `BankWithdrawalAdapter` still defaults `enableReviewedWrites` to false (`Core/BankWithdrawalAdapter.swift`). No withdrawal route is added.
- Virtual goods. `purchaseViaIAP()` stays the closed workshop path (`Core/WorkshopInstallUpgradeRollback.swift`). `productionGatesEnabled` stays false (`App/RegionalLaunchConfiguration.swift`).
- Version. `MARKETING_VERSION = 0.1.0` and `CURRENT_PROJECT_VERSION = 1`.

## Tests

`Tests/CoreTests/CB51LocalDiagnosticsTests.swift` builds the recorder with the flag unset, set to other strings, and set to `1`. It passes a location trail, a token sample, and an account-id sample on every call. With the flag off, `records` is empty. With the flag on, `rendered()` contains the static name and the count, and does not contain those samples.

`Tests/ContractChecks/test_cb51_diagnostics.py` runs without Swift. It executes the same flag and discard rules, checks the Swift bodies match those rules, and checks the implementation file does not contain the samples. It also checks the version line, the absent background-location keys, and that `Package.swift` has no third-party URL.

Swift and `xcodebuild` were not run here. The XCTest is authored and not executed on this machine.

## Local run (not executed)

On a Mac, for one debug install, set `QUESTIFY_CB51_DIAGNOSTICS` to `1` in that process only. Do not put the variable in the shared scheme. Capture with the Logging template, then `python3 tools/signpost_measure.py export` and `summarize`. Keep the trace on the machine. Do not commit it. Repeat with the variable unset and confirm the `Questify.CB51` subsystem is absent.

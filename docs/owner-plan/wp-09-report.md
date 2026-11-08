# WP-09 report (cloud builder, Linux, no Swift toolchain)

## Files written
- Core/MapCoordinateObservation.swift: added `receivedAt`, `isBackfilled` (defaulted init params, so existing callers compile unchanged; preserved through `projected(to:)`), `isOnlineNow(now:maxAge:)`, `MapCoordinateJumpVerdict`, `MapCoordinateJumpGuard`.
- Core/ChallengePOI.swift: added `ChallengePOIRules.assessArrival` / `ArrivalAssessment` / `navigationToleranceMeters`. `checkArrival` (+30 m) is unchanged.
- Core/RoamExperienceCoordinators.swift: added `RoamMileageAccumulator` (measured points only; interpolated points and jump-flagged fixes add no mileage).
- docs/owner-plan/wp-09-new-strings.md (none needed).

## Tests written
- WP09ObservationReceiveTimeTests: testReceiveTimeRecordedSeparatelyFromSampleTime, testBackfilledPointNotOnlineNow
- WP09TeleportBackfillTests: testImpossibleJumpFlaggedNotAccepted
- WP09ArrivalToleranceSeparationTests: testNavigationToleranceDoesNotCountAsAuthoritativeArrival, testInterpolatedPointsAddNoMileage

## NOT verified
- Nothing compiled or run (no Swift toolchain here). Tests were not run red-then-green.
- The `ChallengePOINode(id:name:…)` test fixture and `Double.infinity` use in the verdict are by inspection only.
- Existing `MapCoordinateObservation` Equatable now also compares the two new fields; callers comparing instances built with defaults are unaffected, but not compiled.
- The default 55 m/s ceiling is my choice and needs owner sign-off.
- Wiring `assessArrival` / the accumulator into live callers was out of scope (live callers are on the Must-NOT-touch list).

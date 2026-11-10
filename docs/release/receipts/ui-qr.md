# ui-qr receipt (DES-e5)

Delivered: `App/DesignSystem/CYScan.swift`; wiring in `VerificationCodeView`, `RoamStampCameraView`, `ClubMemberWelcomeSheet`; DEBUG fixtures `qr-scanning|detected|success|used|expired|offline`; `docs/release/ui-strings-qr.json`; `docs/release/motion-spec-qr.md`.
Scope: UI-owned files only (plus pbxproj file refs). No Core/Tests/Config edits; network and verification calls unchanged; money switches untouched.
Not delivered (see motion-spec-qr.md): live camera scanner, CoreHaptics/sound, offline queue, `TicketPassPresentView` wiring (file absent on this base).
Verification: cloud only. Check-run results appended below.
Cloud: 946ab88 Build red (CYScanStage body type-check timeout), fixed in 1cf6e84; its runs were cancelled, re-pushed below.

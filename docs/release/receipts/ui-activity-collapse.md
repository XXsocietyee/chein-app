# ui-activity-collapse (W3-3)

Code-only; no local compile. Verified with `swiftc -parse`, `tools/check_scaffold.py`, `tools/check_design_lint.py`.

## What changed (`App/ActivityDetailView.swift`)
Activity detail went from 18 Sections to 5 always-visible blocks, behaviour, gates and data unchanged:
1. Hero + three action tiles (Sign up / Review / Share, each >= 44 pt, stack at AX sizes) + info card
2. Map card (only with valid coordinates)
3. People (host, participants)
4. Tickets
5. "More info" disclosure row (chevron, `activity.more.toggle`, Reduce Motion aware via `CYMotion.resolve`)

Cancelled notice and host-cancel stay conditional sections (not counted). Behind the disclosure, in original order and with original gates: topic link, about, associated plays, reviews, review row + points note, play session, character card, play experience/director.

Pinned pill: unchanged `CYPillButton`, `activity.openRegistration` / `activity.primaryAction` ids and titles, now with a summary line above it: "From ¥58 · 24 going"; free -> "Free"; unknown price -> "¥—", unknown count -> "—" (never 0). Tile 1 reuses the pill's exact action (sheet / wallet / disabled when cancelled) and is absent when `registrationEnabled == false`.

## Not done
The brief names a "Contact" tile. No contact action exists in the reader or model, so it is omitted rather than inventing behaviour; Review replaces it.

## Strings
7 keys in `Resources/Localizable.xcstrings` (EN + zh-Hans) and `docs/release/ui-strings-activity-collapse.json`: `activity.tile.share`, `activity.more.show|hide|expanded|collapsed`, `activity.pinned.price %@`, `activity.pinned.going %lld`. Existing keys reused for the register and review tiles.

## DEBUG fixtures (`--design-fixture <name>`)
`activity-collapsed` (known price 58, 24 going), `activity-expanded` (disclosure open via DEBUG-only `startsWithMoreInfoOpen`), `activity-unknown` (no price/count: dashes).

## Impact for the integrator
Existing UI tests that look for rows now behind the disclosure need a tap on `activity.more.toggle` first: `activity.openReview`, `activity.detail.readOnly` (ActivityFlowTests), `activity.openTopic` (SignedInContentDetailFlowTests), `activity.openPlay` (IntegratedActivityPlayJourneyFlowTests). Ticket ids (`activity.ticket.*`) stay visible. Tests were not edited (UI-owned files only).

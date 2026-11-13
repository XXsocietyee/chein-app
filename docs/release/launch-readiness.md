# Launch readiness: first TestFlight internal build (player app)

Base: `origin/rc/20261108`. Facts come from files in this repo; verification numbers are as reported by the coordinator brief and are not re-run here (marked "reported"). Anything not proven is marked **UNVERIFIED**.

## 1. What ships (player surfaces)

| Surface | Receipt / spec |
| --- | --- |
| Onboarding pager (Create account / Guest) | `receipts/ui-onboarding.md`, `motion-spec-onboarding.md` |
| Roam hero, GO, nearby sheet; fog engine (UI built, **switched off**) | `receipts/ui-roam.md`, `motion-spec-roam.md` |
| Today hero card (Explore); shows "Start a roam" until host supplies ticket/club event | `receipts/ui-today-hero.md` |
| Pass card (Passport tile to QR in 2 taps) | `receipts/ui-pass-card.md` |
| Ticket wallet / holder, glass carousel | `motion-spec-tickets.md`, `receipts/ui-carousel.md` |
| Club photo cards and Clubs tab | `receipts/ui-club-cards.md` |
| Activity detail (18 sections collapsed to 5 blocks) | `receipts/ui-activity-collapse.md` |
| Celebration, badge unlock, roam summary, state kit | `receipts/ui-celebration.md`, `motion-spec-celebration.md` |
| QR kit (scan states; **no live camera scanner**) | `receipts/ui-qr.md`, `motion-spec-qr.md` |
| Share card composer (walk, medal, route, activity) | `motion-spec-share.md`, `receipts/ui-tail-e3.md` |
| Four-tab IA Explore / Roam / Clubs / Passport; Passport; deep-link parser | `receipts/ui-ia.md` |
| Design Wave 3: night-light tokens, press wave (non-shader fallback), Go hold pill, onboarding light, stamp/seal continuity, club join morph, motion tour (`receipts/wave3-b*.md`, spec `specs/design-wave3.md`). Metal shaders are **opt-in** (`CY_ENABLE_METAL=1 tools/generate_project.py`, needs the Metal Toolchain); default builds compile them out | `receipts/wave3-b*.md` |
| Accessibility sweep | `receipts/ui-a11y-sweep.md` |
| Loading / phase kit, purchase motion | `receipts/ui-loading.md`, `receipts/ui-phase-adoption.md`, `receipts/ui-purchase-motion-e4.md` |

## 2. Verification status

| Check | Result |
| --- | --- |
| Debug + Release arm64 builds | Debug arm64 builds OK on the final tip; Release arm64 simulator build OK on `930acb848` (binary has no design-fixture symbols), not rebuilt after later merges (measured) |
| App unit tests | Full serial run on `198b2d873`: 7469 pass / 130 fail of 7599. Since then hosted-window fixes (e3s, e3t2): the 13 hosted classes now 106 pass / 25 fail of 131 (was 88/43; Place 9->0, Share 7->1, Enrolled 5->4, Tile 4->3); remaining hosted: Native*Hosting 9, Workshop 5, Official 3, Enrolled 4, Tile 3, Share 1. Full suite not re-run after those fixes, expected about 112 failing (measured/derived) |
| Contract suite | 194 failing of 5912 (was 246, was 721). Ratchet: `tools/contract_ratchet.py --check` = 194, baseline 194, new 0, fixed 0, see `receipts/cloud-x2.md` (measured) |
| UITests | Pass (measured on `8509e7f04`/`92e078747`): Entry 7/7, Regional 4/4, TicketWallet 6/6, PageFlowGoldenPathTests 1/1, MotionTourTests 3/4 (tour 2,3,4; tour 1 failed at `MotionTourTests.swift:43`, fixed in `ui/w3u`, not re-run). Skipped: 6 merchant Coupon UITests (v1). Red: IntegratedDenied 1/2, IntegratedActivityPlay 0/2, IntegratedNativeAcceptance 0/6, NonCashReward 0/6, **Roam hub UITests 0/17 (parked, see section 6)** |
| Core scratch package | 1254/1254 (measured earlier on `5e2aeabb1`+e1s; not re-run on the final tip) |
| Release binary fixture symbols | 0 (reported) |
| Xcode Cloud | **NOT cloud verified** (silent; see `receipts/xcode-cloud.md`) |
| Real device | **No real-device pass** |

## 3. Safety gates

| Gate | State |
| --- | --- |
| Reviewed logic (Core / composition) | untouched by the UI work (receipts state "no Core/Tests/Config edits") |
| `WalletPayoutCapability` | off (reported) |
| Password login | not compiled into Release (`app-store-pack.md`) |
| Payment / payout / withdrawal | off |
| Non-money player writes | on for the shipped China composition only, owner approval 2026-11-12. Each writer is constructed by `ReviewedProductionGateLeases` and admitted by `ReviewedProductionFormMutationRoute`. Password login, merchant/coop writes, roam presence, and the four money switches stay off. See `launch-scope-matrix.md` and `receipts/cloud-w1.md`. |
| Player journey reads | on for the shipped China composition only, owner approval 2026-11-12 (`Yes, allow them`). `ReviewedProductionGateLeases` mints `JourneyLoopSource` and `PWaveReader` for the China host: invite landing, seats, run report, settle/rating, and anonymous `POST /api/public-catalog/{city/list,list,filters,info}`. Seat invite/claim/cancel keep the saved request id. Pass purchase, gift purchase, gift claim, referral-token issue, and affiliate payout stay off. The affiliate summary GET is filled on `journeyPromo` for this composition. See `receipts/cloud-pwave.md` and `receipts/cloud-stubs-affiliate.md`. |
| Fog live reveal (`PersonalFogFeature.liveRevealEnabled`, location capability) | off (`roam-fog/location-permission-copy.md`) |
| Closed-by-default tests | green (reported) |

## 4. Release config

Owner-approved (`testflight-internal.md`): API `https://www.chengyinhub.com/prod-api/`, realm `cn-prod`, market `CN`, bundle `com.chengyinhub.chengyinApp`, team `9VHY8N755R`. Lives in `Config/Release.xcconfig`. The "Release Identity Gate" build phase fails the Release build on empty, non-https or placeholder values; `tools/check_release_config.py` proves it. Exact archive and upload steps: `docs/release/testflight-internal.md`. Nothing is deployed or uploaded until the owner says "deploy now".

## 5. Owner to-do

| # | Item | Where |
| --- | --- | --- |
| 1 | Check the Xcode Cloud workflow in App Store Connect | `xcode-cloud-setup.md` |
| 2 | Archive and upload when saying "deploy now" | `testflight-internal.md` |
| 3 | Add internal testers | App Store Connect |
| 4 | Version bump to 1.0 (`MARKETING_VERSION` is `0.1.0` in `Config/Base.xcconfig`); raise build number per upload | `version-scheme.md` |
| 5 | Trim privacy manifest over-declaration (User ID, Purchase History, Email Address, Physical Address) | `Resources/PrivacyInfo.xcprivacy`, `app-store-metadata-checklist.md` |
| 6 | Provide privacy / support / terms URLs, support contact, ICP number, copyright, demo account | `OWNER-TO-PROVIDE` in `app-store-pack.md` |
| 7 | Confirm zh label 提现申请扣款 (**UNVERIFIED: string not found in this tree**; related: `wallet.analysis.withdrawal` now reads "Withdrawals", see section 6) | `receipts/contract-backlog-5.md` |
| 8 | Choose location-permission wording (draft, not approved) | `docs/roam-fog/location-permission-copy.md` |
| 9 | Decide on registering `chein://` in `Config/Info.plist` (not registered) | `receipts/ui-ia.md` |
| 10 | Club-event Today card needs a backend start-date field | `receipts/ui-today-hero.md` |
| 11 | Sign off fog haze 0.62 vs 0.35 `fogOverlay` token | `motion-spec-roam.md` |
| 12 | Camera QR scanner is not built (decide scope) | `receipts/ui-qr.md` |

## 6. Known gaps and real defects still open

| Gap | Source |
| --- | --- |
| Roam hub UITests (17: RoamExperienceFlowTests 14, RoamFinishedHistoryFlowTests 2, RoamLiveActionAccessibilityFlowTests 1) red: pre-existing (also red at `2dd07066a`). Progress: hub row open fixed; remaining: child-screen identifiers (history.record row, recovery TextField, tiles.load) and the album row is absent from the hub AX dump; needs a real-device/hands-on look at Roam hub rows (album/badges/goals reachability from Roam: Passport has stamps/badges now). Not skipped or deleted | this file, `receipts/uitest-14.md` |
| Blacklist: original identities and historical copy not rendered | `contract-backlog-3.md` |
| Channel appeal: "receipt does not mean reversed" safety copy not rendered | `contract-backlog-3.md` |
| Merchant template metadata hints removed from editor | `contract-backlog-3.md` |
| Merchant coupon runtime UITests skipped for v1 (CouponRuntimeFlowTests x5, CouponRuntimeChineseFlowTests x1; merchant surface hidden in the player shell, bodies kept for re-enable) | `uitest-14.md` |
| Shop NPC retry copy over-promises ("won't send it twice"); needs copy decision | `contract-backlog-3.md` |
| `ticketWallet.readOnly` ("Payment, refunds and completion rewards aren't in the app yet") no longer rendered | `contract-backlog-5.md` |
| Wallet withdrawal label says "Withdrawals", not "Withdrawal request debits"; payout-wording call (a later commit message mentions a request-debit label fix; not re-verified here) | `contract-backlog-5.md` |
| Per-row ticket notices (cancelled / expired / unknown) not rendered; anonymous growth leaderboard route marked `.missing`; shortened disclosure copy (shopNPC voice, roam history, playkit pair) | `contract-backlog-1.md` |
| Unavailable club community shown as empty was fixed; `walking.saved.notice` lost a sentence; official event dates use viewer time zone | `contract-backlog-2.md` |
| `cityGame.points.existing`, `cityGame.notEnabled`, several template/city-node notes not rendered | `contract-backlog-5.md` |
| Remaining contract failures (246) are classed obsolete/env or hash pins needing reviewed regeneration, not hidden | `contract-backlog-1..5.md` |
| Today card shows only "Start a roam" until ticket/club-event sources are wired | `receipts/ui-today-hero.md` |
| Light/glass visuals, 120 Hz, VoiceOver paging, Reduce Motion: no device pass | `receipts/ui-carousel.md` |
| Map chrome contrast over live tiles guaranteed only by scrim | `receipts/ui-a11y-sweep.md` |
| `ios-current-ci` ledger not refreshed (as of `LAUNCH-STATUS.md` tip `67053ccb3`) | `LAUNCH-STATUS.md` |

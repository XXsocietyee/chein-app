# RM-02 Device, Multi-Identity E2E & TestFlight Verification Steps (`OWN-OPT-090`..`OWN-OPT-092`)

All code, Maestro flows, accessibility IDs, Release preflight assertions, and signing/upload scripts are integrated on `ui/h-rm-02`. The three items below require Xcode + iOS Simulator or physical iPhone hardware (not available in the headless CI sandbox).

---

## `OWN-OPT-090` — Multi-Identity E2E Rerun (iOS Simulator + TEST `cy_e2e_r2`)

1. **Prerequisites**
   - Signing/build Mac with Xcode 16+, iOS 17+ Simulator booted, and Maestro CLI installed (`maestro --version`).
   - Backend TEST stack reachable at `https://8120-agqyfqxs5vwolymtoibzq3fhde.instabox.tech` with seeded accounts:
     - Player `9004`: `13900000004`
     - Merchant `9002`: `13900000002`
     - SMS OTP bridge: `e2e/maestro/scripts/sms_code_server.py` / `read_test_sms_code.sh`.
2. **Build DEBUG Test-Host App**
   - Build scheme `Questify` (`DEBUG` config, `TEST` flag active) for iOS Simulator and install bundle `invalid.example.questify.ios`.
3. **Run All 18 Maestro Multi-Identity Journeys**
   ```bash
   ./e2e/maestro/run_all.sh
   ```
   - Verify individual flows:
     - `permissions.yaml`, `login.yaml`, `discover-activity-signup.yaml`, `play-session.yaml`
     - `roam.yaml`, `city-game.yaml`, `club.yaml`, `im-dm-preview.yaml`, `community-post.yaml`
     - `creator-publish-review-appeal.yaml`, `external-game.yaml`, `rewards-store.yaml`
     - `workshop-purchased-install.yaml`, `wallet.yaml`, `search-filters.yaml`, `offline-banner.yaml`
     - `account-export-deletion.yaml`, `merchant-ops-payout.yaml` (identity switch `9004` -> `9002`).
4. **Verify RM-02 Runtime Flows on TEST (`--e2e-test-host`)**
   - **`API-/api/registration/pay`**: Open an unpaid registration (via Registration sheet or Order Detail) on TEST host where `ReviewedAreaSwitch.moneyPayments == true`. Confirm `payment-readiness` is checked (`paymentReadiness.ready`), quote & signup consent are present, tap `registration.pay.submit` (`立即支付`), confirm `POST /api/registration/pay` executes **once**, and verify expired `410` displays `registration.pay.expired` with manual rebuild CTA and zero automatic retries.
   - **`OWN-OPT-072`**: Trigger a non-play error/unknown state (e.g., offline or 5xx on quote/order/club/participant) and confirm `requestReference.row` displays the server `x-request-id` copy button.
   - **`OWN-25.1` & `OWN-READ-全队共享提示-跳过-计时-团队总分`**: Start a team topic run (`teamId > 0`), confirm `teamPool.run.section` displays `teamPool.run.score`, hints/skips remaining, and shared timer countdown (`teamPool.timerStart` -> `teamPool.run.timer`). Open a node hint sheet (`teamPool.section`), test shared hint (`teamPool.useHint`), shared skip (`teamPool.useSkip` -> `teamPool.skip.confirm`), and verify team score & solved nodes sync across second team member device/simulator.
5. **Sign-Off**
   - Record results in `e2e/maestro/RESULTS_TEMPLATE.md` (18/18 `PASS`) and confirm `python3 tools/check_scaffold.py`.

---

## `OWN-OPT-091` — Physical iPhone Hardware Matrix

Run on a physical iPhone (arm64, iOS 17+) using an Internal TestFlight or Xcode development build:

1. **Camera & QR Code Scan (`PlayNativeDeviceProvider`)**
   - Grant camera permission on first prompt; scan a seeded check-in QR at a Play station (`validationMethod == 4` or photo task `validationMethod == 2`); verify capture upload and server verdict, and verify graceful denial UI if camera permission is revoked in Settings.
2. **CoreLocation GPS & Background Roam (`SessionBackgroundLocationTracker`)**
   - Enable "While Using" -> upgrade to "Always" when starting a Free Roam session; background the app for 5 minutes while walking, resume to foreground, and confirm roam tracks & `PlayExperienceView` arrival proximity checks recover cleanly.
3. **Offline Pack & Weak/No Network (`PlayOfflinePackHost`, `offline.capsule`)**
   - Download offline pack on Wi-Fi, enable Airplane Mode, open downloaded run chapters, verify offline availability badge & `offline.capsule` banner, trigger a write (comment/registration) to verify `.outcomeUnknown` preserves intent + `requestReference.row` (`x-request-id`) with no auto-retry.
4. **Sign in with Apple & StoreKit Sandbox (`Config/QuestifyWorkshopSandbox.storekit`)**
   - Test Sign in with Apple authentication flow and Workshop sandbox IAP purchase/restore flow; confirm production non-IAP registration pay remains gated (`paymentReadiness.closed` lock shown in Release).
5. **Network Switch & Session Isolation**
   - Switch between Wi-Fi and cellular during active play & IM channel messaging; sign out and sign in as a second account and verify zero cross-account cached state.

---

## `OWN-OPT-092` — Layered Release Archive, TestFlight Upload & Production Readback

Follow `docs/release/TESTFLIGHT.md` and `scripts/release/`:

1. **Automated Pre-Archive Verification (Runnable Anywhere)**
   ```bash
   python3 tools/check_release_preflight.py
   python3 -m unittest tools/tests/test_release_prep.py
   python3 tools/contract_ratchet.py --check
   ```
   Confirm `Release` pins:
   - `PRODUCT_BUNDLE_IDENTIFIER = com.chengyinhub.chengyinApp`
   - `QUESTIFY_API_BASE_URL = https://www.chengyinhub.com/prod-api/`
   - `ReleaseMoneyWriteSwitch.*Enabled == false` & `ReviewedAreaSwitch.moneyPayments == false` in `Release`.
2. **Bump Version & Run Signed Archive + Upload (Signing Mac)**
   ```bash
   ./scripts/release/bump-version.sh --marketing 1.0.0 --build <incremented_build>
   ./scripts/release/preflight.sh
   ./scripts/release/archive.sh
   ./scripts/release/upload.sh --api-key-id "$APP_STORE_CONNECT_KEY_ID" --issuer-id "$APP_STORE_CONNECT_ISSUER_ID"
   ```
3. **TestFlight Internal Install & Readback**
   - Wait for App Store Connect build processing (`Valid`), assign to Internal Testing group, install via TestFlight on physical iPhone.
   - Verify **Production Safety Readback**: open a paid ticket registration sheet and confirm `registration.pay.closed` / `paymentReadiness.closed` lock banner renders and **zero** payment or password requests can leave the device.
   - Confirm App Privacy answers (`docs/release/app-privacy-answers.md`) and Review Notes (`docs/release/app-store-review-notes.md`) match the uploaded build.

# Receipt: Final E2E Maestro Preparation (`ui/h-e2e-flows`)

- **Branch:** `ui/h-e2e-flows` (based on `origin/ui/main` @ `3ac970ec2`)
- **Target Build / Host:** `DEBUG` (`invalid.example.questify.ios`) launched with `--e2e-test-host https://8120-agqyfqxs5vwolymtoibzq3fhde.instabox.tech`
- **Sources Reviewed:**
  - `docs/release/workflows.md` (read from `origin/docs/completeness-2` @ `e1969026e`)
  - `docs/release/e2e/E2E-20261113b.md`, `E2E-20261113.md`, `E2E-20261112.md`
  - `docs/release/cb64-maestro.md`
  - UI sources under `App/` and `Core/` for `.accessibilityIdentifier` verification

## Deliverables Added

1. **18 Journey Maestro Flows (`e2e/maestro/<journey>.yaml`):**
   - `login.yaml` (player `13900000004` via TEST Redis OTP bridge)
   - `discover-activity-signup.yaml` (Global Search -> activity `992031` detail -> registration form)
   - `play-session.yaml` (Team Backpack, station node, hint ladder trigger, station answer review/confirm)
   - `roam.yaml` (simulated GPX coordinates / `chein://roam/go` -> live session + background/foreground transition)
   - `city-game.yaml` (Roam menu check + city search / map layers fallback)
   - `club.yaml` (deep link `chein://club/7001/join` -> join/apply confirmation, chat message send, channels)
   - `im-dm-preview.yaml` (Passport -> Messages -> conversation preview & send)
   - `community-post.yaml` (Home -> Square -> composer -> guideline -> publish)
   - `creator-publish-review-appeal.yaml` (Home -> Project Editor -> Publishing Clarity -> audit appeal flow)
   - `external-game.yaml` (Home Mini Games banner -> catalog, import, submissions, report sheet)
   - `rewards-store.yaml` (Passport -> Rewards Store -> browse / present)
   - `workshop-purchased-install.yaml` (Passport landing + documented Settings gear gap)
   - `merchant-ops-payout.yaml` (merchant `13900000002`, TEST switch ON via `--e2e-test-host`, merchant operations + payout account)
   - `wallet.yaml` (Passport -> Wallet -> earnings overview, balance/points ledgers, bank withdrawal entry)
   - `search-filters.yaml` (tag, today preset, min/max price, keyword search, result kind filter, reset)
   - `permissions.yaml` (launched with `--uitesting-usage-consent-pending` + signed-out Settings notification/privacy/consent)
   - `offline-banner.yaml` (`offline.capsule` `NWPathMonitor` state verification)
   - `account-export-deletion.yaml` (signed-out Settings -> compliance cancellation precheck + NPC chat data screen)

2. **Helpers & Fixtures:**
   - `e2e/maestro/scripts/read_test_sms_code.sh`: SSH + `docker exec be-int-redis redis-cli -n 9 GET sms_<phone>_code` helper (with `--clear-limit`).
   - `e2e/maestro/scripts/sms_code_server.py`: localhost HTTP bridge for Maestro `runScript`.
   - `e2e/maestro/scripts/get_sms_code.js`: Maestro JS script calling the bridge (or consuming `E2E_SMS_CODE`).
   - `e2e/maestro/fixtures/roam_shanghai_walk.gpx`: Shanghai simulated GPX track for `xcrun simctl location`.

3. **Missing Identifiers, Sequential Runner & Results Template:**
   - `e2e/maestro/MISSING_IDS.md`: documents missing `.accessibilityIdentifier` sites in `App/` (root player/merchant `TabView` items, Passport Settings gear `AccountView.swift:177-180`, `roam.more` city/nearby menu links `RoamBrowserView.swift:283,286`, `RegistrationSheetView.swift:134-135` alert button, `TopicXcxSections.swift:160-167`, `PlayExperienceView.swift:786-791` hint confirm dialog button, sheet close buttons, and `RoamSubpageParityViews.swift:128`).
   - `e2e/maestro/run_all.sh`: acquires `/private/tmp/design-build.lock` (`lockf`), waits while 1-min system load > 25, boots/reuses a single simulator (`Questify-iPhone17-Lane2`), starts `sms_code_server.py` and `[E2E]` simulator log capture, runs all 18 flows sequentially, streams GPX during `roam.yaml`, and writes a populated summary report from `e2e/maestro/RESULTS_TEMPLATE.md`.
   - `e2e/maestro/RESULTS_TEMPLATE.md`: structured 18-flow run matrix, triage table, and `[E2E]` log template.

## Verification Run (Static Only — No Builds, No Flow Execution)

- `maestro check-syntax` on all 18 `e2e/maestro/*.yaml` flows: passed (`18/18`).
- Identifier audit script across all 18 flows against `App/**/*.swift`: `294` YAML `id:` references checked, `0` unmatched.
- `bash -n e2e/maestro/run_all.sh e2e/maestro/scripts/read_test_sms_code.sh`: passed.
- `python3 -m py_compile e2e/maestro/scripts/sms_code_server.py`: passed.
- `python3 tools/check_release_config.py`: passed (`Release config check passed`).
- XML parse check (`xml.etree.ElementTree.parse`) on `e2e/maestro/fixtures/roam_shanghai_walk.gpx`: passed.

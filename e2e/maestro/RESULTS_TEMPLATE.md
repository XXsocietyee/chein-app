# Questify iOS Final E2E Run Results Template

- **Date:** `<YYYY-MM-DD HH:MM TZ>`
- **Tester / Operator:** `<name or ci>`
- **App Branch / Commit SHA:** `<branch> @ <sha>`
- **Build Target:** `DEBUG` (`invalid.example.questify.ios`)
- **Launch Argument:** `--e2e-test-host https://8120-agqyfqxs5vwolymtoibzq3fhde.instabox.tech`
- **Backend Host / DB:** `https://8120-agqyfqxs5vwolymtoibzq3fhde.instabox.tech` (`cy_e2e_r2`)
- **Simulator:** `<name> (<udid>)` / iOS `<version>`
- **Accounts Used:**
  - Player `9004`: phone `13900000004`
  - Merchant `9002`: phone `13900000002`
- **Artifacts Directory:** `<path/to/results/run_timestamp>`

## Summary Matrix (18 Journeys)

Status key: `PASS` | `FAIL` | `BLOCKED_MISSING_ID` | `BLOCKED_BACKEND` | `SKIP`

| # | Journey Flow (`e2e/maestro/<journey>.yaml`) | Status | Duration (s) | Notes / Findings (`[E2E]` logs, MISSING_IDS, backend status) |
|---|---|---|---|---|
| 1 | `permissions` | | | Launch `--uitesting-usage-consent-pending` + privacy/notification |
| 2 | `account-export-deletion` | | | Compliance cancellation + NPC data screen |
| 3 | `login` | | | Phone `13900000004` + TEST Redis DB 9 OTP bridge |
| 4 | `discover-activity-signup` | | | Activity `992031` detail + reg sheet |
| 5 | `play-session` | | | Station answer + hint ladder + team backpack |
| 6 | `roam` | | | Free roam + simulated GPX (`roam_shanghai_walk.gpx`) + background |
| 7 | `city-game` | | | City search & layer view (`roam.more` city ID gap noted) |
| 8 | `club` | | | Seeded club `7001` join/apply + chat + channels |
| 9 | `im-dm-preview` | | | Passport -> Messages -> conversation preview + send |
| 10 | `community-post` | | | Home -> Square compose -> review -> publish |
| 11 | `creator-publish-review-appeal` | | | Project editor -> publishing clarity -> audit/appeal |
| 12 | `external-game` | | | Home -> Mini Games banner -> catalog / submit / report |
| 13 | `rewards-store` | | | Passport -> Rewards Store -> browse / present |
| 14 | `workshop-purchased-install` | | | Blocked by `MISSING_IDS.md` `AccountView.swift:177` gear ID |
| 15 | `wallet` | | | Passport -> Wallet -> earnings + ledgers + withdrawal entry |
| 16 | `search-filters` | | | Filter sheet (tag, date preset, min/max price, result kind) |
| 17 | `offline-banner` | | | `offline.capsule` (`E2E_EXPECT_OFFLINE=0` / `1`) |
| 18 | `merchant-ops-payout` | | | Merchant `9002` (`13900000002`), `--e2e-test-host` TEST switch ON |

## Failures & Root Cause Triage

| # | Flow | Step / Selector | Failure Output / Screenshot | Backend vs App vs Harness | Ticket / Action |
|---|---|---|---|---|---|
| 1 | | | | | |

## Log Excerpts (`eventMessage CONTAINS "[E2E]"`)

```text
<paste relevant [E2E] log lines here>
```

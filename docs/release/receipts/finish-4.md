# Finish 4: contract backlog 4/5 decisions and re-run (DES-e4, branch ui/e4p)

Base: `origin/rc/20261108` = `1b9db04ca`. Code only; no xcodebuild/simulator (integrator compiles).
Run: `cd Tests/ContractChecks && PYTHONPATH=<repo root> python3 -m unittest <module>`; baseline via `tools/contract_ratchet.py`.

## Product decisions (safest default)
| question | decision | change |
|---|---|---|
| Wallet withdrawal label ("Withdrawals" vs "request debits") | Use the wording the contract pins: a withdrawal row is a request debit, not a completed payout. Payout capability untouched (`WalletPayoutCapability` stays off, nothing in App/Core changed). | `Resources/WalletIncomeAnalysis.xcstrings` `wallet.analysis.withdrawal`: en "Withdrawal request debits", zh-Hans "提现申请扣款" (zh had no pinned wording; chosen to mirror en) |
| Dropped `ticketWallet.readOnly` disclosure | Restored; contract requires `Text("ticketWallet.readOnly")` in `TicketWalletView`. | Footer `Section` in `App/TicketWalletView.swift`, meta typography + secondary colour, wraps, id `ticketWallet.readOnly`. Shown in every state (also signed-out and error), key already in catalog |
| Dead Home live countdown | Not removed: `upcomingCountdownText` / `countdownScheduleDates` / `maxAllowedScheduleHorizon` are NOT unreferenced; `Tests/CoreTests/HomeSearchTabParityTests.swift` and `Tests/AppUnitTests/ProfileParticipantValidationAppTests.swift` call them, and deleting them blind (no compiler here) risks a red Core test target. Home itself renders none of it (no behaviour change). | Contract test `test_home_live_updates_only_at_a_verified_boundary` re-pinned to what Home guarantees now: no `.periodic`, no `TimelineView`, no countdown helper use, no `TimeZone.current`. Follow-up for the integrator: delete the helpers together with their Core/AppUnit tests |

## Re-run of chunk 4 and 5 modules (288 listed ids, 94 modules)
Baseline 259 -> 253 failing ids in this run (`contract_ratchet --check`: new 0).

| module | verdict | action |
|---|---|---|
| test_wallet_income_analysis_closure (2) | real decision + stale | withdrawal label restored (above); income row pin follows the plain `walletRow("wallet.analysis.title", ...)` (key exists in Localizable too) |
| test_native_design_motion (2) | real + obsolete | readOnly restored; stale `ticketWallet.noCode` pin (em-dash placeholder was removed; pass is offered only for ready tickets) re-pinned to `if ticket.status == .ready` + `ticketWallet.present.open`; Home-live test re-pinned (above) |
| test_merchant_club_discovery (1) | stale | `clubRows(..., page: page)` and `merchantNearbySection(nearby, page: page)` gained the page argument; merchant viewers still get nearby only |
| test_restored_management_core_sources (1) | stale | `NativeFriendFlow` retry has a synchronous re-validation guard between `requireCurrentVisit` and `service.write`; test now requires the fence after the last `await` before each service call (guards may sit between) |

### Classified obsolete (left failing, evidence)
- sha256/byte-hunk/inverse pins over frozen baselines (fail on a hash of files that legitimately changed; a re-pin would only be a rubber stamp): `test_category_roam_registration` (13), `test_approved_release_recovery_migration` (2), `test_run138_ui52_driver` (5), `test_run129_host_diagnostics` (2), `test_run130_route_fixture_inset` (2), `test_run129_map_button_role` (4), `test_ci138_map_readonly_enabled` (4), `test_workshop_paid_lifecycle_closure` (5, five sha256 mismatches), `test_workshop_paid_reentry_closure` (1), `test_social_guide_templates` (2, byte hunk of AccountView + sha256 of TicketWalletDetailView), `test_merchant_operator_invitation_receipt` (3, coordinator/services/view hashes), `test_project_editor_readiness` (13, `Unknown current editor-readiness source`), `test_global_search_category_recovery` (10), `test_club_customer_directory_remote_admission` (7), `test_template_shelf_state_projection` (2), `test_merchant_redemption_filter` (1), `test_merchant_station_submission_import` (1), `test_merchant_discovery_redemption_contracts` (1).
- Frozen branch baseline / absent ref: `test_branch_history_fixture_handshake` (2), `test_c11_ops_support_projections` (7, `origin/migration/native-ios` absent), `test_chapter_replacement_invitation` (git-diff whitelist; the cwd errors pass from the repo root).
- Missing input files (`docs/release/ui-strings-*.json`, absent on this tree): `test_club_create_page_ready`, `test_club_host_apply_page_model`, `test_information_detail_page_ready`, `test_pages_activity_baoming_baoming`, `test_play_guide_information_list_page` (3), `test_object_badge_wall_page_state` (3), `test_official_event_contracts` (1).

## Not verified
Nothing compiled: the `TicketWalletView` footer and the catalog edit are unbuilt. No simulator/UI check of the footer. zh-Hans wording of the withdrawal label has no product sign-off.

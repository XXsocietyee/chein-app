# ui-cur-fixtures-8

Branch `ui/cur-fixtures-8` was cut from `origin/ui/cur-rm-01` `f21270bb8419e6a82467058c08a494a5afbbb15d`. `ui/cur-rm-01` was not moved. Merge commit parents are that pin and `origin/ui/h-rm-02` `eda3e9773f93767a8ca5ba52dfe66bc4c642347e`. `ui/h-rm-02` was not moved.

`docs/release/completeness-matrix.csv` and `docs/release/completeness-matrix.md` conflicted. Every requirement id on both sides already exists on `origin/ui/main`. Those rows stay the `ui/main` text. No new id was appended.

`ReviewedAreaSwitch` was not redeclared. `moneyPayments`, `payout`, `merchantWrites`, and `passwordLogin` stay closed on `www.chengyinhub.com`. `AppSession.swift` and `AppCompositionRoot.swift` were not edited, and this change adds no method on either type. The merge already contains `AppSession.teamPoolHint` from `ui/h-rm-02` in `TeamPoolHintSection.swift`. `RegionalLaunchConfiguration.swift` was not edited. `OwnerDecisionFixtureHost` was not re-added. `docs/release/contract-failing-baseline.txt` was not raised.

`swiftc` is not on this machine. Nothing here is a compile or a typecheck.

`python3 tools/generate_project.py` registered `App/DesignFixtures/CurFixtures8.swift`. `python3 tools/check_design_fixture_release_exclusion.py --write`, then the check without `--write`, passed. `python3 tools/check_scaffold.py` passed. `python3 tools/check_design_lint.py` passed. Fixtures stay on the Release exclusion list.

Launch with `--design-fixture <id>`. An unknown amount is an em dash (`—`). A decoded `0` is not turned into that dash. No fixture opens a socket. The pay executor, when present, returns `moneyPaymentsClosed` and does not send.

## Fixtures

| Fixture id | Screen | What it shows |
|---|---|---|
| `cur8-decor` | `MerchantOpsWp03Panel` `.decor` | Host `fixture.example`. Reply name `Sample shop`. No price. |
| `cur8-decor-closed` | same | Host `www.chengyinhub.com`. Transport throws. Money and merchant writes stay withheld. Reads fail as an em dash. |
| `cur8-npc` | `MerchantStoreCharacterView` | Existing offline host, scenario `normal`. |
| `cur8-npc-failed` | same | Scenario `error`. Profile read fails inside the offline transport. |
| `cur8-relation` | `CoopRelationDiscoveryView` | Existing relation reader, scenario `mixed`. |
| `cur8-relation-empty` | same | Scenario `empty`. |
| `cur8-merchant-info` | `MerchantContentHomeView` | Existing merchant-content fixture service, topic `70`. |
| `cur8-merchant-info-failed` | same | `failReads` on that in-process transport. |
| `cur8-pay` | `RegistrationPaySection` | Executor nil. The lock sentence is the closed switch. No amount is drawn. |
| `cur8-pay-unknown` | same | Payable amount nil. The amount line is an em dash. The executor refuses and does not send. |
| `cur8-team` | `TeamPoolHintSection` and `TeamPoolRunStatusSection` | Shared hints, skip, a running timer, and team score `4`. |
| `cur8-team-unknown` | same | Timer expired. Team score is an em dash. |
| `cur8-request-ref` | `RequestReferenceRow` | Path `/api/registration/pay`. Id `d81d7c38d3bc4ede9ca68a6191299c6e` on a private ledger. |
| `cur8-request-ref-unknown` | same row, absent | Ledger empty. The fixture draws an em dash. |
| `cur8-opt090` | `UnifiedReleaseAuditHubView` | Default verified snapshot. |
| `cur8-opt090-attention` | same | First card metric is an em dash and is not verified. |
| `cur8-opt091` | `TestFlightInternalAndExternalSmokeSectionView` | Default ready snapshot. |
| `cur8-opt091-hold` | same | Existing journey copy, smoke not passed, tracks held. |
| `cur8-opt092` | `FinalThreeDocumentAndSevenDayGoalCompletionView` | Default ready snapshot. |
| `cur8-opt092-incomplete` | same | Seven-day path and native-superset flag are false. Row percentages stay the snapshot's own values. |
| `cur8-opt-signoff` | `UnifiedOPT090To092AndEXT01To11SectionView` | The static OPT-090 / OPT-091 / OPT-092 packages. |
| `cur8-opt-signoff-static` | same | The type has no empty or failed input, so this id mounts the same section. |

## Missing surfaces

These names are not on the merged tree. They were not added.

- `TestFlightInternalAndExternalSmokeMatrixSectionView`. The view on the tree is `TestFlightInternalAndExternalSmokeSectionView`, fixtured above.
- `FinalThreeDocumentAndSevenDayGoalCompletionSectionView`. The view on the tree is `FinalThreeDocumentAndSevenDayGoalCompletionView`, fixtured above.

RM-01 did not add a new screen type. Its four pages are the decoration panel, the store-character view, the relation discovery view, and the merchant-info home, all fixtured above. `OWN-OPT-014`, `OWN-OPT-022`, `OWN-OPT-032`, `OWN-OPT-043`, `OWN-OPT-060`, `OWN-OPT-062`, and `OWN-OPT-082` are citation tests on screens that already existed. They are not separate views, and no screen was invented for them.

## Accessibility

Labels, values, and hints use copy that was already on the screen: `MerchantOpsWp03` keys, `teamPool.*`, `requestReference.*`, `paymentReadiness.closed`, the pay-once sentence, the team-skip sentence, and the verbatim titles already drawn by the OPT-090 / OPT-091 / OPT-092 views. No new catalog string was added.

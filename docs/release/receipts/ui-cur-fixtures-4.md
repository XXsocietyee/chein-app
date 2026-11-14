# ui-cur-fixtures-4 — handover 47 DEBUG fixtures

This branch contains the merge of `ui/wp-02` (`c943799a66e32b9a910e66892d30ea080c31bc4e`) and `ui/wp-11` (`1e48434aaa7ec692265f73e343394ff799440be8`), plus the DEBUG fixtures below. The diff against `ui/main` (`a2a9d82e78459df7c22c5545e2c5bf19f2f0ff46`) is that merge plus these fixtures. It is not fixtures-only.

Merge commit `62c6cbcf83881beee48a81a2b389546b94dbb2b9`. Parents: `c943799a66e32b9a910e66892d30ea080c31bc4e`, `1e48434aaa7ec692265f73e343394ff799440be8`.

## Merge

`ui/wp-11` was merged into the `ui/wp-02` tip with `--no-ff`. Swift and project files merged without conflicts. The only conflicted path was `docs/release/completeness-matrix.csv` (add/add, 14 hunks). Each side's row evidence was kept: a row that only `ui/wp-02` updated stayed, a row that only `ui/wp-11` updated stayed. No feature logic was rewritten to force the merge.

## Fixtures

`App/DesignFixtures/Cur4Fixtures.swift` is wrapped in `#if DEBUG`. Each fixture mounts the real view. Launch with `--design-fixture <id>`. `DesignFixtureRegistry.make` hands `cur4-*` to `Cur4Fixtures.make`. Account `990001` and token `synthetic-fixture-token` match the G-parity player-gap fixtures, except the unlock session, which is account `9001` so it matches the synthetic leader. Unknown values are an em dash (`—`). en and zh-Hans strings for these screens were already in `Resources/PlayCreatorTail.xcstrings` and `Resources/Localizable.xcstrings`. No new copy was added.

Money stays closed on `www.chengyinhub.com`. `ReviewedAreaSwitch` is not redeclared. The editions non-happy fixture uses that host, so `moneyPayments(apiHost:)` is false and the view shows the generic empty line.

| View | Fixture ids | Normal | Non-happy |
|---|---|---|---|
| `CreatorAuditSheet` timeline | `cur4-audit-timeline`, `cur4-audit-timeline-failed` | REJECT row plus a NODE problem, appeal `SUBMITTED` | no timeline reply → load failed |
| `CreatorAuditSheet` appeal | `cur4-audit-appeal`, `cur4-audit-appeal-unknown` | `canAppeal` true, empty rounds, appeal button | appeal state `QUEUED` → em dash |
| `CreatorAuditSheet` receipt | `cur4-audit-receipt`, `cur4-audit-receipt-unreadable` | pending draft `appeal-fixture0001`; Recover matches the FOUND receipt for appeal 77 | local receipt is `not-json` → storage failed |
| `PlayGuardAppealSection` | `cur4-guard`, `cur4-guard-unconfirmed` | activity 41, eligibility `canSubmit` | activity 42, seeded command, no receipt → unconfirmed |
| `PlayLeadChapterTools` | `cur4-unlock-chapter`, `cur4-unlock-chapter-pending` | all arrived, unlock button, skip row 阿青 / node 34 闸口 | unlock-chapter HTTP 500 → receipt-only check and pending notice; if boot cannot reach that state the body is an em dash |
| `ClubEditionEmptyReasonView` | `cur4-edition-empty`, `cur4-edition-empty-closed` | host `fixture.example`, reason `NO_PERMISSION` | host `www.chengyinhub.com`, money closed, generic empty |
| `SessionLocationHoldsSection` | `cur4-location-holds`, `cur4-location-holds-none` | dedicated tracker: roam (background) and `play:41:990001:1` (foreground) | no holds → none |
| `RequestReferenceRow` via `PlayExperienceIssueView` | `cur4-request-reference`, `cur4-request-reference-unknown` | shared ledger id `d81d7c38d3bc4ede9ca68a6191299c6e` on `/api/play/nodes` | shared ledger cleared; the row is absent and the fixture draws an em dash |

The receipt fixture shows Recover on the first frame. `CreatorAuditSheet` confirms only after that tap; the FOUND body matches the frozen command. The location fixture calls the real ledger `acquire`, which starts `CLLocationManager`. A denied authorization clears holds asynchronously, so that normal fixture can collapse to empty on a device that has refused location. The none fixture never acquires. The request-reference fixture clears `RequestReferenceLedger.shared` because `PlayExperienceIssueView` reads `.shared`.

## Screens skipped

These landed on the two branches and are not separate fixture screens:

- `MyProjectAuditEntry` is the row that presents `CreatorAuditSheet`. The sheet is the fixtured view.
- Points spend rules (`WalletPointsRules` section), registration points refusal, audio interruption resume, and content compatibility are behavior on existing screens. They are not new views in the handover list.
- Roam "recording also when locked" is a row on the existing roam session, not the location-holds section.

## Gates

- `python3 tools/generate_project.py` adds `Cur4Fixtures.swift` and keeps design-fixture sources in the Release exclusion list.
- `python3 tools/check_design_fixture_release_exclusion.py --write`, then the check without `--write`.
- `python3 tools/check_scaffold.py` and `python3 tools/check_design_lint.py` before push.
- `swiftc` is absent. This receipt does not claim a typecheck.
- `RegionalLaunchConfiguration.swift`, `AppSession.swift`, and `AppCompositionRoot.swift` were not edited. The contract baseline was not raised. The completeness matrix was not imported into Swift.

# cloud-g7

Branch `ui/cloud-g7-guards`. Base `origin/ui/main` `72d2eb9ec498de21ded7cf9215f2638d7195786f`.

Client rules that have no backend yet. Source list: `docs/owner-plan/gap-pl-3.md` (plan text in `docs/owner-plan/questify-plan-v12.txt` §7, CT04, CT05, CT07, CT09, CT14). Implementation is pure Core in `Core/G7ClientRules.swift`. Tests are `Tests/CoreTests/G7ClientRulesTests.swift`. No network call. `ReleaseMoneyWriteSwitch` is unchanged and stays all false. Not wired into `AppSession` or `AppCompositionRoot`.

`python3 tools/check_scaffold.py` exited 0 before this commit. Swift is not installed in this workspace, so these tests were not compiled or executed here.

| Rule | Statement | Test |
| --- | --- | --- |
| CT04.d | Declining to share must not strip normal participation. Play and roam stay allowed for unset, declined, and granted personal-share consent. | `G7ClientRulesTests.testCT04dDecliningShareKeepsPlayAndRoam` |
| CT04.e | Old permanent location restores, derived stats, imported tracks, and migrated copies do not extend retention or gain a new use. A later end is refused. A use outside the source set is refused. The kept window is the source window. | `G7ClientRulesTests.testCT04eCopiesDoNotExtendRetentionOrGainUses` |
| CT05.c | POI, game node, store, and map-provider IDs are distinct types. The same raw text in two kinds is not the same place. An empty raw value is not a place. | `G7ClientRulesTests.testCT05cPlaceIDsStayDistinctKinds` |
| CT07.e | A PHOTO substitute under review awards no score and does not advance required completion. A method switch or a replay returns the original completion. A local proposed score is not applied. | `G7ClientRulesTests.testCT07ePendingPhotoAwardsNothingAndReplayReturnsOriginal` |
| CT09.b | Quantities are whole units and half-steps, plus an unlimited balance. A request must fit the balance and the capacity. A money spend is refused and charges nothing. | `G7ClientRulesTests.testCT09bHalfUnitBalanceAndCapacityNeverSpendMoney` |
| CT09.c | One missed appointment marks only that unit. Sibling units stay as they were. The multi-use ticket is not voided. No charge and no refund. | `G7ClientRulesTests.testCT09cNoShowTouchesOnlyThatUnit` |
| CT14.b | An expired public reference is withheld. It is not rewritten into a visible public post with no location. An explicit downgrade is refused the same way. | `G7ClientRulesTests.testCT14bExpiredReferenceDoesNotBecomeLocationlessPublicPost` |

`G7ClientRulesTests.testBoundaryDoesNotCallNetworkOrEnableMoney` locks `G7ClientRuleBoundary.performsNetwork` and `enablesMoney` to false, and locks every `ReleaseMoneyWriteSwitch` kind off.

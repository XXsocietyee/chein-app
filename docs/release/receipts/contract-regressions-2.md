# Contract regressions 2

Seven contract tests failed on the rc tree but passed on base 201bf147f. All seven are fixed; no protection was weakened. Code and contract-source changes only. No Xcode, UIKit or simulator run.

## Our code broke a protected property (fixed in code)
- `test_ci138_hosted_navigation_scene.test_scene_owner_requires_the_real_foreground_scene...`: the test-triage wave added `hostedWait` (uses `Task.sleep`) and `WorkshopSyntheticStorage` above `WorkshopPurchasedAppFixture` in `WorkshopPurchasedNormalAccountTests.swift`. That region is the scene-owner helper, which must contain no sleep. Both helpers moved below the fixture enum, so the scene helper region is byte-identical to base again.

## Stale pins (re-pinned, protection kept)
- `test_run130_creator_scene.test_three_host_changes...`, and `test_run129_host_diagnostics` `creator_actions_assertions_wait_helpers...` and `creator_probe_records_only...`: the Creator Consent and Pending harnesses legitimately gained refreshed copy expectations and the `WorkshopSyntheticStorage.factory` storage seam. The published-source snapshots (`tools/tests/fixtures/run129_published_sources`) took the same hunks, and the `run130_creator_scene.json` file hashes and `CONTRACT_SHA` were recomputed. The scene-window hunks still reverse to the original assertions, actions, waits and probe, and the `waitUntil` tail is still compared byte for byte.
- `test_club_home_topic_navigation`: `eventRow(event)` became `eventRow(event, page: page)`. The topic-id NavigationLink and the Button fallback are unchanged.
- `test_w2_04_p2_member_tools.test_invite_summary_keeps_existing_total_row`: `SocialOptionalCount` was inlined as `LabeledContent(... ProfileInviteHistoryPageReady.countText(total))`. `countText(nil)` returns the em dash, the same as before.
- `test_activity_registration_parity_w2_06.test_meta_rows_follow_cancellation_and_precede_about`: unknown category, meeting point and count now render a verbatim em dash instead of separate "unconfirmed" keys. The pin now requires the em-dash forms. The meta slice is cut at the struct end, because other structs now follow it in the file.

Other failures in the same files (run129 owned-journey x2, ci138 owned postimage, w2_04 x2, w2_06 x2) also fail on base 201bf147f and are out of scope.

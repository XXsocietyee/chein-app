# pages/team/join/index — PAGE-READY (CB205)

Map row is `exists`: `App/TeamHomeView.swift` (`TeamDetailView` with `.invitation`). No view file was edited. No route was added or marked live.

Already on `rc/20261108`: `TeamReadOnlyService.detail` posts `api/team/info` with `inviteCode`; `TeamWriteContract.join` posts `/api/team/join` with `inviteCode` only; `TeamCoordinator.loadDetail` accepts `.invitation`. Writes stay behind the existing approval. `loadingKey`, `blockingState`, and `showsJoinRetry` already name loading and error. `TeamSyntheticFixtures` (`#if DEBUG`) already covers invitation, full, ended, rejected, network, and forbidden.

Added because it was missing: `invitationReadout` (loading / empty / error / ready), `rosterIsEmpty`, and `memberCountText`. A missing joined count or capacity is `—` (U+2014). A literal `0` stays `0 / maximum`. `TeamJoinIndexFixtureData` is the DEBUG-only page payload, including an omitted-count body. EN and zh-Hans keys plus accessibility identifiers are in `docs/release/ui-strings-pages-team-join-index.json`.

Left: `App/TeamPageParityViews.swift` still draws its own em dash and does not call `memberCountText`. `team.page.eyebrow` is in the catalog and unused. Club invite and share were not added. `tools/current_ci_manifest.json` was not refreshed. Swift was not executed on this machine. No Xcode Cloud result.

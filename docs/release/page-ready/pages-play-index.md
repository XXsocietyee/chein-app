# pages/play/index

Screen `App/PlayExperienceView.swift`. Page-map status stays `partial`.

Already on `rc/20261108`: `PlayExperienceCoordinator.Phase` (`loading`, `unknown`, `failed`), `PlaySessionAvailability.empty`, `PlayExperienceService` reads `api/play/nodes` and `api/play/route-state` with `enabled` defaulting to empty, DEBUG `PlayExperienceSyntheticFixtures`, and `PlayTaskSummaryPresentationTests`.

This lane adds `PlayIndexPageReadiness` in `Core/PlayTaskSummaryPresentation.swift`. Loading, empty, error, and UNKNOWN share that projection. UNKNOWN progress is the em dash `—`. A known zero of a positive total stays `0/N`. Reads that are off stay the disabled empty shell.

Copy and identifiers: `docs/release/ui-strings-pages-play-index.json`. Tests: `Tests/CoreTests/PlayIndexPageReadinessTests.swift`.

Left: views still show `referenceTask.phaseOnly` and `play.progress.unknown` instead of the em dash. `tools/current_ci_manifest.json` was not refreshed. No Xcode Cloud run. Story join, backpack writes, and external-game download stay hidden.

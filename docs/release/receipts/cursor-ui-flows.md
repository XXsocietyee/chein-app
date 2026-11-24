# Receipt: cursor/ui-flows

Six Maestro flows, one per mini-program area, on DEBUG fixtures that `DesignFixtureRegistry.make` already returns. Each flow launches with `--design-fixture <name>` and asserts accessibility identifiers that already exist. No screen layout, Swift, Xcode project, or `ci/acceptance` file was edited. No `swiftc`. No mini-program screenshots.

`.github/workflows/acceptance.yml` is not on this branch (`ui/combined-r7` at `82388e4a5e7391e0c5a286735d6b30613a860ae8`; the workflow lives on `ci/acceptance`). This change does not add a workflow. The ui-smoke step the acceptance job can call later is:

```yaml
- name: UI smoke
  run: bash tools/run_ui_smoke.sh
```

`tools/run_ui_smoke.sh` runs only the six flows below. If the `maestro` CLI is not on `PATH`, it prints `ui-smoke: Maestro CLI is not installed...` and exits 0. On any OS other than macOS it prints `ui-smoke: Maestro iOS flows need a Mac simulator...` and exits 0. It does not build, sign, or boot a simulator. A Mac with Maestro installed runs `maestro test` on each flow against a DEBUG install of `invalid.example.questify.ios` (`Config/Base.xcconfig`).

These flows were not executed here. This workspace has no Maestro CLI.

## Flows

| Area | Flow | Fixture `DesignFixtureRegistry.make` returns | Identifiers asserted |
|---|---|---|---|
| member | `.maestro/ui-flows/member.yaml` | `e4-member` | `member.card.name`, `member.card.level`, `member.card.city`, `member.card.tickets`, `member.card.friends`, `member.card.following`, `member.card.fans` |
| account-publish | `.maestro/ui-flows/account-publish.yaml` | `publish-menu-pro` | `publishModes.home`, `publishModes.pro.city`, `publishModes.pro.freeExplore`, `publishModes.interaction` |
| merchant-coop | `.maestro/ui-flows/merchant-coop.yaml` | `merchant-home` | `merchant.store.name`, `merchant.dashboard.revenue`, `merchant.workbench.scan`, `merchant.workbench.more.action`, `merchant.orders.entry`, `merchant.projects.entry` |
| club | `.maestro/ui-flows/club.yaml` | `d4-directory` | `club.directory.81`, `club.directory.82`, `club.directory.search`, `club.directory.refresh` |
| player-content | `.maestro/ui-flows/player-content.yaml` | `e1-discovery` | `discovery.openRoutes`, `discovery.openTemplates`, `discovery.play.701`, `discovery.play.702` |
| play-roam | `.maestro/ui-flows/play-roam.yaml` | `d2-roam` | `roam.go`, `roam.rules`, `roam.openMap` |

Maestro keeps a launch-argument key that already starts with `-`, then appends the value. The map key is the literal `--design-fixture`, which is the flag `fixtureArgument` in `App/QuestifyApp.swift` looks up.

## Why these fixtures

`docs/port/accept/` lists DEBUG routes the app already launches. The ones that are `--design-fixture` names, and that `DesignFixtureRegistry.make` returns, include `t5-free-explore`, `hfeat-playkit-truefalse`, `hfeat-playkit-jigsaw`, `hfeat-playkit-scratchcard`, `e1-ticket-holder-valid`, `e1-ticket-holder-pending`, `e3-inbox`, `d2-inbox`, `e3-chat`, `e3-club-calendar`, `d4-tab-manage`, and `e3-club-detail`, plus the `native-gallery*` lines. Routes that use `--uitesting-module` are not `--design-fixture` names, so these flows do not launch them.

Each flow uses one registered name for that area's main screen:

- **member.** `e4-member` mounts `MemberHomeFixtureHost(scenario: "ready")`, the member identity card (`App/MemberHomeHeader.swift`). The card title, level, city, ticket pill, and the three counters are in the first section before the role-info read finishes.
- **account-publish.** `publish-menu-pro` mounts `PublishingModesView` with `makeProfessional` and `makeTemplateAuthoring` set (`App/DesignFixtures/PublishDesignFixtures.swift`). Those closures are what show `publishModes.pro.city`, `publishModes.pro.freeExplore`, and `publishModes.interaction` (`App/PublishingModesViews.swift`). `publish-menu` does not pass them, so those identifiers are absent there.
- **merchant-coop.** `merchant-home` mounts `MerchantHomeView` on `DesignMerchantReader` rich access (`App/DesignFixtures/MerchantConsoleFixtures.swift`): active owner, finance, orders, projects, and verify. The fixture also sets `nativeVerificationDestination`, which is what shows `merchant.workbench.scan`.
- **club.** `d4-directory` mounts `ClubDirectoryView` on the visitor reader (`App/DesignFixtures/D4Fixtures.swift`). `clubDirectory` returns fixture clubs 81 and 82 (`App/ClubFixtureSupport.swift`). The search field and the toolbar refresh are `club.directory.search` and `club.directory.refresh`.
- **player-content.** `e1-discovery` mounts `DiscoveryHomeView` with topic browsing on and `DiscoveryFixtureReader()` content (`App/DesignFixtures/E1Fixtures.swift`). The route and template entries are in the first section. The content home decodes play templates 701 and 702 (`App/DiscoveryFixtureReader.swift`), which are `discovery.play.701` and `discovery.play.702`.
- **play-roam.** `d2-roam` mounts `RoamHomeFixtureHostView` (`App/DesignFixtures/D2Fixtures.swift`). `RoamFixtureReader()` content is configured, signed in (account 900), and has a search area, so `RoamMapCameraScope` is present and the map chrome shows `roam.go`, `roam.rules`, and `roam.openMap` (`App/RoamBrowserView.swift`).

## Omitted steps

The flows do not type, do not tap a row, link, GO, scan, refresh, or search, and do not pass a URL. They do not assert identifiers that appear only after a tap or only in an error state.

`docs/port/accept/p4.txt` play-kit names (`hfeat-playkit-truefalse`, `hfeat-playkit-jigsaw`, `hfeat-playkit-scratchcard`) are registered and are not this play-roam flow. That flow is the roam home, which is the area's map entry. `docs/port/accept/p5.txt` club names (`d4-tab-manage`, `e3-club-detail`, `e3-club-calendar`) are registered and are not this club flow. That flow is the directory, which is the area's list entry.

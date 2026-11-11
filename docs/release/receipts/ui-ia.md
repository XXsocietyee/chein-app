# ui-ia receipt (W1-1 four-tab root, W1-4 Passport skeleton, W3-6 deep links; DES-e5, branch ui/e5; NOT COMPILED locally, cloud Build is the gate)

Branch `ui/e5` only. Not merged to ui/main. Source: ux-strategy.md W1-1, W1-4, W3-6.

## W1-1 Four tabs: Explore / Roam / Clubs / Passport
- `Core/RootTab.swift`: the five cases, `titleKey`, `systemImage` are unchanged (mini-program parity, `RootTabBarParity`, the merchant bar's slot map all rely on them). Added `playerTabs` (`.home .roam .club .mine`), `isPlayerTab`, `playerTitleKey` (`tabBar.explore`, `tabBar.roam`, `tabBar.club`, `tabBar.passport`) and `playerSystemImage` (`sparkles`, ..., `book.closed`).
- `App/QuestifyApp.swift`: `publishTab` removed from the player `TabView`; labels use the player title/icon; a guard `onChange` snaps any non-player selection (for example a merchant return to `.publish`) to Explore. `.mine` is now `PassportView`.
- `App/DesignSystem/CYDomainTabBar.swift`: player icons/titles follow; merchant bar unchanged (`.mine` keeps `tabBar.mine`).
- Publish moved to an Explore toolbar "+" (`homeFeed.openCreate`, `SessionHomeFeedView`): opens the former Publish tab content in a sheet. Shown only when `session.publishingSession != nil` (signed in with token, same capability the Publish flow already required); hidden otherwise. A guest still reaches Templates via the More menu (`homeFeed.openTemplates`). Merchant mode is untouched (separate root container).
- Old identifiers kept: every `accessibilityIdentifier`, `RootTab.mine` tag, `tabBar.mine`/`tabBar.publish`/`tabBar.home` catalog keys.

## W1-4 PassportView skeleton
- `App/PassportView.swift`: wraps `AccountView(showsPassportOverview: true)`. Adds, below the existing identity card, `PassportOverviewSection`: 3 circular actions (Ticket wallet -> existing ticket pass sheet, Account earnings -> `SessionWalletCommerceView`, Messages -> `SessionMessagingHome`, all existing destinations and gating) and a 12-slot stamp grid (earned slots filled, the rest dashed locked silhouettes). Nav title is Passport.
- No new data: stamp count = `RoamPassportHome(records: reader.history()).stamps` from the local saved records; read failure or no reader shows an em dash and all slots locked, never 0. Only the first `min(count, 12)` slots are filled; the grid carries no per-stamp titles.
- Capability gating unchanged: merchant rows were already hidden for the player domain; wallet payout capability and `reviewed` logic are untouched.
- Not done (deliberate): moving merchant/creator rows into a Settings section, badges rail and re-grouping of the existing list. The list is unchanged so every existing row and identifier still works.

## W3-6 Deep links
- `Core/CheinDeepLink.swift` (pure parser, `chein://roam/go`, `chein://ticket/<id>`, `chein://club/<id>/join`; positive canonical ids, no query/fragment/userinfo/port, case-insensitive scheme/host). `rootTab`: Roam, Passport, Clubs.
- `AppSession.receiveNativeURL` handles the `chein` scheme first: valid link -> `pendingDeepLink`, invalid -> existing `.routeError(.unsupported)` via `NativeEntryIntent`; `SessionRootView` consumes it and selects the owning tab (one presentation). A link grants nothing: it does not start a roam, open a ticket by id or join a club; each destination keeps its own sign-in, capability and confirmation gate. Id-specific presentation (ticket sheet, join confirm) waits for those screens.
- URL scheme is NOT registered in `Config/Info.plist`: `test_universal_link_associated_domains` asserts no `CFBundleURLTypes`, so registering is an owner decision. Until then `onOpenURL` receives nothing from the OS; the parser and routing are in place and unit-tested.

## Strings and tests
- `docs/release/ui-strings-ia.json` (+ catalog): `tabBar.explore` Explore/发现, `tabBar.passport` Passport/护照, `homeFeed.create`, `passport.stamps.*`, `passport.stamp.earned|locked`. check_catalog_coverage gaps 0.
- Tests: `RootTabTests` (player bar), new `CheinDeepLinkTests`. UITests read and updated: `EntryFlowTests`, `EntryUsageConsentFlowTests` (labels Explore/Roam/Clubs/Passport, no Publish tab, Templates via More menu, no "+" for a guest), `NonCashRewardFlowTests`, `CouponRuntimeJourney`, `Integrated{Activity,Native,Denied}*` (tab("Me") -> "Passport", tab("Home") -> "Explore"), `test_roam_account_entry.py` (PassportView). Not run.
- Fixtures (`--design-fixture`): `ia-tabs`, `ia-explore-create`, `ia-explore-no-create`, `ia-passport` (3 of 12), `ia-passport-unknown` (em dash), `ia-passport-ax5`, `ia-deeplinks`.

## Checks (code only)
swiftc -parse clean on touched files; check_scaffold, check_design_lint, check_catalog_coverage run before push (see commit). ContractChecks discover run on this branch vs origin/ui/main: same pre-existing failure set (687 on base) apart from `test_root_tab_switch_default_is_inert`, fixed. Not verified: compile, any UI test, VoiceOver/AX XL rendering, the "Messages" label now appearing twice on Passport (circle + row) for `tap("Messages")`.

## How to revert
- Whole feature: `git revert <merge commit>` on ui/main, or do not merge `ui/e5`.
- Just restore the Publish tab: in `QuestifyApp.swift` re-add `publishTab` (the NavigationStack with `DiscoveryTemplateBrowserView`, tag `.publish`) to `playerTabs`, delete the guard `onChange`, point `rootTabLabel` at `titleKey`/`systemImage`; remove the "+" and `showsCreate` sheet in `SessionHomeFeedView`; `PassportView` -> `AccountView`.
- Just the Passport additions: delete `PassportView.swift` use (`PassportView(` -> `AccountView(`); `showsPassportOverview` defaults to false so AccountView is otherwise unchanged.
- Deep links: delete `CheinDeepLink.swift`, the `chein` branch in `receiveNativeURL`, `pendingDeepLink`/`consumeDeepLink`, and the `onChange` in `chain0`.
- After any revert run `python3 tools/generate_project.py` (new/removed files are in the generated pbxproj).

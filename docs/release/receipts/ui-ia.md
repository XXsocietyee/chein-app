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
- Follow-up (gap fixes, same branch): see "Gap fixes" below. Still not done: re-grouping the rest of the existing list.

## W3-6 Deep links
- `Core/CheinDeepLink.swift` (pure parser, `chein://roam/go`, `chein://ticket/<id>`, `chein://club/<id>/join`; positive canonical ids, no query/fragment/userinfo/port, case-insensitive scheme/host). `rootTab`: Roam, Passport, Clubs.
- `AppSession.receiveNativeURL` handles the `chein` scheme first: valid link -> `pendingDeepLink`, invalid -> existing `.routeError(.unsupported)` via `NativeEntryIntent`; `SessionRootView` consumes it and selects the owning tab (one presentation). A link grants nothing: it does not start a roam, open a ticket by id or join a club; each destination keeps its own sign-in, capability and confirmation gate. Id-specific presentation (ticket sheet, join confirm) waits for those screens.
- URL scheme is NOT registered in `Config/Info.plist` (see OWNER DECISION below). Until then `onOpenURL` receives nothing from the OS; the parser and routing are in place and unit-tested.
- Presentation (gap fix d): `chein://ticket/<id>` selects Passport and presents the existing ticket pass sheet (`TicketPassSheet`, signed-in only; the id is not used to open a specific ticket, the view has no by-id entry). `chein://club/<id>/join` selects Clubs and pushes the existing `ClubDetailView(id:)` via `ClubHomeView.requestedClubID`; the detail keeps its own join confirmation and gating, nothing joins from the link. `chein://roam/go` stays tab selection only. Both requests are one-shot `Binding`s in `SessionRootView` (`deepLinkTicketPass`, `deepLinkClubID`) cleared by the consumer.

## OWNER DECISION: register `chein://`
Not done on purpose; `Config/Info.plist` is untouched. To make the OS deliver `chein://` links the owner must approve all of:
1. Add `CFBundleURLTypes` to `Config/Info.plist` with one entry: `CFBundleURLName` (e.g. the bundle id), `CFBundleURLSchemes` = [`chein`], `CFBundleTypeRole` = Viewer.
2. Relax the contract tests that forbid it: `Tests/ContractChecks/test_universal_link_associated_domains.py` line 18 (`assertNotIn("CFBundleURLTypes", Info.plist)`) and `Tests/ContractChecks/test_account_marketing_entry_integration.py` line 19 (forbids `CFBundleURLTypes` in the root view/plist text). Keep the `applinks:` / associated-domains assertions; this change is custom scheme only, not Universal Links.
3. Accept that any app or web page can open `chein://` links (custom schemes are not ownership-verified); acceptable only because `CheinDeepLink` grants nothing and each destination keeps its gating.
4. Optional: add a ContractChecks test pinning the scheme list to exactly [`chein`] so no other scheme is registered silently.
No safety switch is involved.

## Gap fixes (follow-up on this branch)
- (a) Messages duplicate: on Passport the `account.messages` list row is hidden (`showsPassportOverview`); the circle action (`passport.action.messages`) stays. `tap("Messages")` is unique on Passport. The row (with its unread badge) still shows in the legacy `AccountView` host.
- (b) Creator/merchant rows: extracted unchanged into `AccountRoleSections` (in `App/AccountView.swift`, so existing contract-test string anchors remain) and hosted in Settings (`SettingsView`, after the identity application entries). Gating kept: merchant rows only when `themeDomain != .player`, mode switch only when `merchantRootModeSwitch.isAvailable`; creator rows hidden in Settings when `session.publishingSession == nil` (the capability the Create flow already requires). Merchant application is now a navigation destination of that section. Passport no longer lists them; legacy `AccountView` (non-Passport) renders the same section ungated for creator as before. Moved identifiers (`account.creatorProjects`, `account.templateAuthoring`, `account.merchant*` ...) now live in Settings: UI tests that tap `account.templateAuthoring` after `tab("Passport")` (`IntegratedNativeAcceptanceFlowTests`, `IntegratedActivityPlayJourneyFlowTests`) and `CouponRuntimeJourney` (`account.merchant`) need an extra open-Settings step; NOT updated here, not run.
- (c) Badges rail: `PassportOverviewContent.badges` below the stamp grid, from the existing growth center read (`session.growthCenterReader.overview().center.badges`, same source as Growth Center). Unknown (unconfigured, signed out, read failed) = header with an em dash and no rail; known empty = section hidden; otherwise horizontal rail of medal chips with the badge name (generic "Badge" when unnamed) and the count. Reloads on pull-to-refresh. New string `passport.badges.title`. Fixtures: `ia-passport` (3 badges), `ia-passport-no-badges`, `ia-passport-unknown` (em dash), `ia-passport-ax5`.


## Strings and tests
- `docs/release/ui-strings-ia.json` (+ catalog): `tabBar.explore` Explore/发现, `tabBar.passport` Passport/护照, `homeFeed.create`, `passport.stamps.*`, `passport.stamp.earned|locked`. check_catalog_coverage gaps 0.
- Tests: `RootTabTests` (player bar), new `CheinDeepLinkTests`. UITests read and updated: `EntryFlowTests`, `EntryUsageConsentFlowTests` (labels Explore/Roam/Clubs/Passport, no Publish tab, Templates via More menu, no "+" for a guest), `NonCashRewardFlowTests`, `CouponRuntimeJourney`, `Integrated{Activity,Native,Denied}*` (tab("Me") -> "Passport", tab("Home") -> "Explore"), `test_roam_account_entry.py` (PassportView). Not run.
- Fixtures (`--design-fixture`): `ia-tabs`, `ia-explore-create`, `ia-explore-no-create`, `ia-passport` (3 of 12), `ia-passport-unknown` (em dash), `ia-passport-ax5`, `ia-deeplinks`.

## Checks (code only)
swiftc -parse clean on touched files; check_scaffold, check_design_lint, check_catalog_coverage run before push (see commit). ContractChecks discover run on this branch vs origin/ui/main: same pre-existing failure set (687 on base) apart from `test_root_tab_switch_default_is_inert`, fixed. Not verified: compile, any UI test, VoiceOver/AX XL rendering, Settings row styling (`SettingsTileLabelStyle` over `CYListRow`), the Settings-hosted `navigationDestination` for merchant application, badge rail layout.

## How to revert
- Whole feature: `git revert <merge commit>` on ui/main, or do not merge `ui/e5`.
- Just restore the Publish tab: in `QuestifyApp.swift` re-add `publishTab` (the NavigationStack with `DiscoveryTemplateBrowserView`, tag `.publish`) to `playerTabs`, delete the guard `onChange`, point `rootTabLabel` at `titleKey`/`systemImage`; remove the "+" and `showsCreate` sheet in `SessionHomeFeedView`; `PassportView` -> `AccountView`.
- Just the Passport additions: delete `PassportView.swift` use (`PassportView(` -> `AccountView(`); `showsPassportOverview` defaults to false so AccountView is otherwise unchanged.
- Deep links: delete `CheinDeepLink.swift`, the `chein` branch in `receiveNativeURL`, `pendingDeepLink`/`consumeDeepLink`, and the `onChange` in `chain0`.
- After any revert run `python3 tools/generate_project.py` (new/removed files are in the generated pbxproj).

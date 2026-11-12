# U10 cloud fixes (ui/cloud-fixes)

Base: `ui/main` `72d2eb9ec498de21ded7cf9215f2638d7195786f`.
Three integrator video-review defects. No other screens were restyled.
No simulator or UI test was run on this Linux agent. Checks are source contracts, `tools/check_scaffold.py`, and `tools/check_design_lint.py`.

## 1. Explore greeting under the status bar

`HomeFeedView` hides the navigation bar when the hero greeting is showing (`homeIndex.hero.greeting`, "Hi, …" / "Player · Shanghai"). The feed `.searchable` drawer then draws in that band and blurs the greeting. `displayMode: .always` did not move it (reverted on `72d2eb9ec`).

When the hero is showing, the navigation-bar search is not attached. The same keyword field (`homeFeed.search`, submit and clear unchanged) sits under the greeting. `HomeHeroStatusBarClearance` measures the content top once against the key window's top safe area and pads only the overlap, capped at 80 pt, so a header that is already clear is not padded twice. Reduce Motion is not involved; the inset does not animate.

## 2. Roam tools rows

`RoamPassportToolsSection` and `RoamPassportPrivateLinks` applied `.navigationDestination(item:)` on the section and on a row. Inside a `List` that modifier collapses the section into one cramped line.

The destinations now live on the `List` via `roamPassportToolsDestinations` and `roamPassportPrivateDestinations` (`.navigationDestination(item: openedTool)` / `.navigationDestination(item: openedLink)`). Call sites: `RoamExperienceHubView`, `RoamHomeTabsView`, and the two grant-scope hosts. Anchors `roam.tools.anniversary.open`, `roam.tools.recap.open`, `roam.export.open`, `roam.goals.open`, and `roam.capsule.open` are unchanged. `NavigationLink` labels stay so a real tap still pushes. Contract pins: `Tests/ContractChecks/test_roam_anniversary_navigation.py` and `tools/check_roam_private_tools.py` (PASS count 31).

## 3. Ticket "Checked in" face

`CYPassVerifiedFace` (`ticketPass.verified`) was a `#0B4F5C` → `#1FA866` gradient. The dark stop is 2.20:1 on `CYNight.ink0` (`#06060A`). White "Checked in" on `#1FA866` is 3.07:1. White also fails the new stops (4.18 / 3.98 / 3.07).

The ground is now `#168E50` → `#189252` → `#1FA866`. Ink text, including "You're in" / "已入场", "Have fun." / "玩得开心", and "Checked in" / "已核验入场", is full-opacity `CYNight.ink0`. Ink on the darkest stop is 4.83:1, which is the same pair as the card against the night page. Lighter stops are 5.08:1 and 6.60:1. The lantern stamp shadow and Reduce Motion scale fallback stay. Copy and the identifier are unchanged.

`E1TicketCard` "Checked in" already uses `CYColor.textPrimary`. `TicketPassPresentView` "You're in. Have fun." already uses `CYNight.verify` (`#3DDC84`, 11.34:1 on ink). Those were left alone.

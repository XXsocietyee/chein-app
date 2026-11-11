# club-home-light-contrast

Branch `ui/e1s` from `52dcf72dd`. Code-only; no build or screenshot re-run.

Finding: no hard-coded white. `CYHeroHeader`, `CYListRow`, `CYClubCards` and `CYStatusChip` read the domain palette (`cyPalette`, player = light text), but `ClubHomeView` painted its ground with `cyGroupedSurface()` = `CYColor.bgPage`, which follows the system scheme. The club fixture host never applied the role-root styling (`themeDomain` + `cyScreenStyle`), so under a light system scheme the player-palette text (#F8F8F8) sat on light grey #F3F4F4 (about 1.1:1). The real app was unaffected because its roots force scheme and domain together.

Fix:
- `ClubHomeView`: ground is now `cyDomainPageBackground()` (same palette as the text) with the list background hidden, so text and ground cannot disagree in any host.
- `ClubFixtureRootView`: applies `themeDomain` (merchant when the fixture scope is a merchant viewer, else player) and `cyScreenStyle()`, as the app roots do.

Contrast with matching ground (token values): player textSecondary #B7B7B7 and textTertiary #919191 on #000000 are about 10.5:1 and 6.7:1; merchant textTertiary #6B6B6B on #F3F4F4 is 4.9:1 (5.3:1 on white). The faint "Topics: 2" chip (neutral chip, textSecondary) and the unknown "—" member text (textSecondary) were the same mismatch, not low tokens, so no token changed. Other ClubHome fixtures (owner, member, empty, tabUnknown, merchantLocality*) share this host and view, so they get the same ground/text pairing; merchant fixtures now render light ground with dark text via the merchant domain.

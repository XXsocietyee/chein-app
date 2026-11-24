# Q4 shared mini-program assets

Base `origin/ui/combined-r7` is `82388e4a5e7391e0c5a286735d6b30613a860ae8`. C7 already imported the catalog under `App/Assets.xcassets/MP` with accessors in `App/MPAssets/MPAsset.swift` and the map in `docs/mp-assets/mapping.md`. This pass wires that map into shared components only.

Area screens stay with the F-agents. Member, account-publish, merchant-coop, club, player-content, and play-roam page files were not edited. System-control glyphs stay SF Symbols: back chevron, close, share, more, and the search magnifier.

No new image file was added. The only bitmap rewrite is `App/Assets.xcassets/LaunchMark.imageset/LaunchMark.png`, a white alpha treatment of `cy_logo_mark` so the mark reads on the black launch ground. `file` reports `PNG image data, 384 x 384, 8-bit/color RGBA, non-interlaced`. No WebP was added. `project.pbxproj` was not edited. This VM did not run `swiftc`; this receipt does not claim a parse.

## Slots left because the asset is missing

None. Every shared slot below already had a PNG or PDF in the catalog.

## Tab bar

Player bar (`app.json` / CONSUMER_LIST) draws the colored selected pair as original images. Merchant bar draws the template pair. Live bars: `CYDomainTabLabel` in `QuestifyApp` and `SessionMerchantRootContainerView`. The design-kit strip uses the same icons.

| Slot | MPAsset |
| --- | --- |
| Player home, idle / selected | `MPAsset.TabIcon.iconF1` / `iconF01d` |
| Player roam, idle / selected | `MPAsset.TabIcon.iconRoam` / `iconRoamD` |
| Player publish, idle / selected | `MPAsset.TabIcon.iconF3` / `iconF03d` |
| Player club, idle / selected | `MPAsset.TabIcon.iconF4` / `iconF04d` |
| Player mine, idle / selected | `MPAsset.TabIcon.iconF5` / `iconF05d` |
| Merchant workbench, idle / selected | `MPAsset.TabIcon.iconTabWorkbench` / `iconTabWorkbenchOn` |
| Merchant marketing, idle / selected | `MPAsset.TabIcon.iconTabMarketing` / `iconTabMarketingOn` |
| Merchant template, idle / selected | `MPAsset.TabIcon.iconTabTemplate` / `iconTabTemplateOn` |
| Merchant relation, idle / selected | `MPAsset.TabIcon.iconTabRelation` / `iconTabRelationOn` |
| Merchant mine, idle / selected | `MPAsset.TabIcon.iconTabMine` / `iconTabMineOn` |

Present, not drawn a second time (same player home / roam / club slots as `iconF1` / `iconRoam` / `iconF4`): `iconTabHome`, `iconTabHomeOn`, `iconTabRoam`, `iconTabRoamOn`, `iconTabClub`, `iconTabClubOn`.

Present, left for the template-detail shelf (not the root bar): `tplTabGame`, `tplTabTopic`.

## Empty states (`CYSharedStates`)

`CYEmptyIllustration` is drawn by `CYStateArt` and by `CYEmptyState` → `CYStateLayout`. Search keeps the SF magnifier.

| Slot | MPAsset |
| --- | --- |
| Generic / tray background | `MPAsset.EmptyState.emptyStateBg` |
| Generic / tray figure | `MPAsset.EmptyState.emptyStateFigure` |
| Orders / ticket | `MPAsset.EmptyState.iconTicketEmpty` |
| Sparkles empty (no-data) | `MPAsset.EmptyState.noData` |

## Avatar default

| Slot | MPAsset |
| --- | --- |
| `CYAvatarView` fallback | `MPAsset.AvatarDefault.dProfile` |

Present, left for the leaderboard (not the shared default): `memoji1`, `memoji2`, `memoji3`.

## Map markers

`CYMapMarker` in `CYMapChrome` is the shared pin. `CYRoamPin`, `QuestifyMapPinSymbol`, and the square route-node annotation draw it. Unselected category art is the dot; selected art is the pin.

| Slot | MPAsset |
| --- | --- |
| Landmark, idle / selected | `dotLandmark` / `pinLandmark` |
| Merchant, idle / selected | `dotMerchant` / `pinMerchant` |
| Park, idle / selected | `dotPark` / `pinPark` |
| Shop, idle / selected | `dotShop` / `pinShop` |
| Street, idle / selected | `dotStreet` / `pinStreet` |
| Unknown, idle / selected | `dotUnknown` / `pinUnknown` |
| Cluster | `dotCluster` |
| Search pin, idle / selected | `iconMap6` / `dSmapicon` |
| Location pin | `dLocation2` |
| Route node | `iconMap4` |
| Publish pin (`mappin.circle`) | `mapPin` |
| Roam pushpin, selected | `roamPushpin` (idle falls back to `dotUnknown`) |

Present, not drawn a second time: `pagesSearchmapImagesDSmapicon` is the same selected search pin as `dSmapicon`.

## Badges and medals

`CYMedalGlyph` feeds `CYMedalFace`, medal-screen stat cells, and `CYBadgeCraft`. The new-record row uses `glTrophy`. `CYShareMedalArt` picks the metal from the card title or symbol (gold unless the text names silver / 银 or bronze / 铜). Laurel on the badge craft uses `laurel`.

| Symbol or slot | MPAsset |
| --- | --- |
| `rosette`, `medal.fill` | `medal3d` |
| `medal` | `medal` |
| `seal`, `seal.fill` | `glassBadge` |
| `trophy` | `trophy` |
| `trophy.fill`, new-record row | `glTrophy` |
| `book`, `book.closed`, `book.pages` | `glBook` |
| `clock`, `clock.fill` | `glClock` |
| `storefront`, `storefront.fill`, `bag`, `bag.fill` | `glShop` |
| `sparkles` | `glSpark` |
| `stamp` | `glStamp` |
| `figure.walk` | `glWalk` |
| `shippingbox`, `shippingbox.fill` | `micChest` |
| `mountain.2`, `mountain.2.fill`, `globe` | `micEnv` |
| `key`, `key.fill` | `micKey` |
| `leaf`, `leaf.fill` | `micLeaf` |
| `moon`, `moon.fill`, `moon.stars`, `moon.stars.fill` | `micMoon` |
| `checkmark.seal`, `checkmark.seal.fill` | `micStamp` |
| `laurel.leading`, `laurel.trailing`, badge-craft laurel | `laurel` |
| Share card, default | `medalGold` |
| Share card, silver / 银 | `medalSilver` |
| Share card, bronze / 铜 | `medalBronze` |
| Share card, `mappin.and.ellipse` | `stamp3d` |

Present, left for area screens (profile ribbons, 3D showroom, template shelf, album intro): `group2`, `group3`, `group4`, `group5`, `badgeDemo`, `goldMatcap`, `tagTrophy`, `stamp`.

## Brand logo

| Slot | MPAsset |
| --- | --- |
| Launch mark (`LaunchMark`, white on the existing black `LaunchBackground`) | `MPAsset.BrandLogo.cyLogoMark` |
| Login mark | `MPAsset.BrandLogo.cyLogoMark` |
| Login wordmark | `MPAsset.BrandLogo.dLogo` |

The source logos are near-black. Login tints both as template images in `CYColor.textPrimary`. Launch uses the white treatment above so the mark is visible on black.

Present, left for the member journey (not launch or login): `dCyIcon`, `dCyIcon2`.

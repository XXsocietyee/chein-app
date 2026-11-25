# MP Image Alignment Receipt (r9)

- **Lane**: Gemini MP image-alignment (`gemini/mp-assets-r9`)
- **MP Source**: `/Users/fanning/chengyin-handoff/LOCAL-HENGYIN-WIP/chengyinhub-xcx`
- **Catalog**: `App/Assets.xcassets/MP/<category>/<asset>.imageset`
- **Accessors**: `App/MPAssets/MPAsset.swift`
- **Mapping**: `docs/mp-assets/mapping.md`

## Summary Counts

- **Total local MP images referenced** (`.wxml`/`.wxss`/`.js`/`.json`): **198**
- **Already mapped** (prior to r9): **131**
- **Added now** (byte-identical PNG/JPG/SVG + `MPAsset.swift` + `mapping.md`): **67**
- **Total `MPAsset` / `mapping.md` entries** (including legacy MP paths): **580**
- **Still unused in `App/**/*.swift`** (`use this MP asset`): **111**
- **Intentionally kept as SF Symbols** (system-control glyphs, unused as `MPAsset`): **8**

## Added Now (67 Assets)

| `MPAsset` | MP Path | Category | MP Source (`file:line`) | App Screen |
| --- | --- | --- | --- | --- |
| `MPAsset.BannerCover.imagesDFrametu` | `images/d_frametu.jpg` | banner/cover default | `utils/mockData.js:274` | `App/ClubDetailView.swift` (shared) |
| `MPAsset.MapMarker.imagesDLocation2` | `images/d_location2.png` | map marker | `pages/searchmap/index.js:661` | `App/SearchMapExplorerView.swift` |
| `MPAsset.FeatureIcon.imagesDOrderIcon` | `images/d_orderIcon.png` | feature/category icon | `subpackageMember/components/cy/scene-member-order-history/index.wxml:46` | `App/InvoiceLaunchHistoryView.swift` |
| `MPAsset.FeatureIcon.imagesDOrderIcon2` | `images/d_orderIcon2.png` | feature/category icon | `subpackageMember/components/cy/scene-member-order-history/index.wxml:47` | `App/InvoiceLaunchHistoryView.swift` |
| `MPAsset.EmptyState.dYhqon` | `images/d_yhqon.png` | empty-state illustration | `subpackageMember/mycanyu/mycanyu.wxml:15` | `App/PlayerJourneyViews.swift` |
| `MPAsset.Other.imagesDel` | `images/del.png` | other | `pages/gerenziliao/gerenziliao.wxml:82` | `App/ProfileEditView.swift` |
| `MPAsset.Other.imagesFigmaInviteQr` | `images/figma-invite-qr.png` | other | `components/cy/scene-share-invite/index.js:35` | `App/AccountView.swift` (shared) |
| `MPAsset.BadgeMedal.imagesGroup2` | `images/group2.png` | badge/medal | `subpackageMember/components/cy/profile/index.wxml:59` | `App/AccountView.swift` (shared) |
| `MPAsset.BadgeMedal.imagesGroup3` | `images/group3.png` | badge/medal | `subpackageMember/components/cy/profile/index.wxml:60` | `App/AccountView.swift` (shared) |
| `MPAsset.BadgeMedal.imagesGroup4` | `images/group4.png` | badge/medal | `subpackageMember/components/cy/profile/index.wxml:61` | `App/AccountView.swift` (shared) |
| `MPAsset.BadgeMedal.imagesGroup5` | `images/group5.png` | badge/medal | `subpackageMember/components/cy/profile/index.wxml:62` | `App/AccountView.swift` (shared) |
| `MPAsset.BannerCover.homeBanner2` | `images/home-banner-2.jpg` | banner/cover default | `pages/index/index.js:192` | `App/HomeFeedView.swift` |
| `MPAsset.BannerCover.homeRouteFreePlaceholder` | `images/home-route-free-placeholder.jpg` | banner/cover default | `pages/index/index.js:192` | `App/HomeFeedView.swift` |
| `MPAsset.FeatureIcon.imagesIconJia` | `images/icon_jia.png` | feature/category icon | `components/cy/post-card/index.wxml:11` | `App/SquareBrowserView.swift` (shared) |
| `MPAsset.FeatureIcon.imagesIconPen` | `images/icon_pen.svg` | feature/category icon | `subpackageMember/components/cy/profile/index.wxml:47` | `App/AccountView.swift` (shared) |
| `MPAsset.FeatureIcon.imagesIconQaPerson` | `images/icon_qa_person.svg` | feature/category icon | `subpackageMember/components/cy/profile/index.wxml:220` | `App/AccountView.swift` (shared) |
| `MPAsset.FeatureIcon.imagesIconSearch` | `images/icon_search.svg` | feature/category icon | `pages/template/index.wxml:29` | `App/DiscoveryTemplateBrowserView.swift` |
| `MPAsset.FeatureIcon.imagesIconSet` | `images/icon_set.png` | feature/category icon | `subpackageMember/components/cy/profile/index.wxml:15` | `App/AccountView.swift` (shared) |
| `MPAsset.FeatureIcon.iconSjt` | `images/icon_sjt.png` | feature/category icon | `subpackageMember/components/cy/profile/index.wxml:249` | `App/AccountView.swift` (shared) |
| `MPAsset.FeatureIcon.iconSjtH` | `images/icon_sjt_h.png` | feature/category icon | `subpackageMember/components/cy/profile/index.wxml:249` | `App/AccountView.swift` (shared) |
| `MPAsset.FeatureIcon.imagesIconStar` | `images/icon_star.png` | feature/category icon | `subpackageMember/mytemplate/mytemplate.wxml:26` | `App/AccountCollectionFavoritesView.swift` |
| `MPAsset.EmptyState.imagesIconTicketEmpty` | `images/icon_ticket_empty.svg` | empty-state illustration | `subpackageMember/components/cy/scene-member-order-detail/index.js:55` | `App/OrderLifecycleView.swift` (shared) |
| `MPAsset.FeatureIcon.iconXjt` | `images/icon_xjt.png` | feature/category icon | `subpackageMember/components/cy/profile/index.wxml:252` | `App/AccountView.swift` (shared) |
| `MPAsset.FeatureIcon.iconXjtH` | `images/icon_xjt_h.png` | feature/category icon | `subpackageMember/components/cy/profile/index.wxml:252` | `App/AccountView.swift` (shared) |
| `MPAsset.BannerCover.imagesMer1` | `images/mer1.jpg` | banner/cover default | `utils/mockData.js:311` | `App/ClubDetailView.swift` (shared) |
| `MPAsset.FeatureIcon.imagesMerchantReviewsIconStarFilled` | `images/merchant/reviews/icon-star-filled.svg` | feature/category icon | `pages/merchant/reviews/index.wxml:33` | `App/MerchantBusinessViews.swift` |
| `MPAsset.FeatureIcon.imagesMerchantReviewsIconStarMuted` | `images/merchant/reviews/icon-star-muted.svg` | feature/category icon | `pages/merchant/reviews/index.wxml:33` | `App/MerchantBusinessViews.swift` |
| `MPAsset.FeatureIcon.imagesMerchantReviewsIconStarSmall` | `images/merchant/reviews/icon-star-small.svg` | feature/category icon | `pages/merchant/reviews/index.wxml:152` | `App/MerchantBusinessViews.swift` |
| `MPAsset.Other.imagesNavMsg` | `images/nav_msg.svg` | other | `pages/talent/list/index.wxml:15` | `App/ClubHomeView.swift` (shared) |
| `MPAsset.FeatureIcon.introMap` | `images/roam/intro-map.svg` | feature/category icon | `pages/roam/index.wxml:112` | `App/RoamBrowserView.swift` |
| `MPAsset.FeatureIcon.introRoam` | `images/roam/intro-roam.svg` | feature/category icon | `pages/roam/index.wxml:106` | `App/RoamBrowserView.swift` |
| `MPAsset.FeatureIcon.introTeam` | `images/roam/intro-team.svg` | feature/category icon | `pages/roam/index.wxml:118` | `App/RoamBrowserView.swift` |
| `MPAsset.BannerCover.imagesRouteFreeCover` | `images/route_free_cover.png` | banner/cover default | `subpackageA/pages/myproject/index.wxml:48` | `App/CreatorContentViews.swift` |
| `MPAsset.FeatureIcon.dBianji2` | `pages/gerenziliao/images/d_bianji2.png` | feature/category icon | `pages/gerenziliao/gerenziliao.wxml:20` | `App/ProfileEditView.swift` |
| `MPAsset.FeatureIcon.iconBellAlert` | `pages/merchant/images/icon_bell_alert.svg` | feature/category icon | `pages/merchant/index/index.wxml:175` | `App/MerchantHomeView.swift` |
| `MPAsset.FeatureIcon.iconBellMuted` | `pages/merchant/images/icon_bell_muted.svg` | feature/category icon | `pages/merchant/index/index.wxml:183` | `App/MerchantHomeView.swift` |
| `MPAsset.FeatureIcon.iconWallet` | `pages/merchant/images/icon_wallet.svg` | feature/category icon | `pages/merchant/index/index.wxml:259` | `App/MerchantHomeView.swift` |
| `MPAsset.Other.pagesPlayComponentsPlaykitScanArReticle` | `pages/play/components/playkit-scan/ar/reticle.png` | other | `pages/play/components/playkit-scan/ar/index.wxml:15` | `App/PlayKitScreen.swift` (shared) |
| `MPAsset.Other.mascotCatBlind` | `pages/play/images/mascot-cat-blind.svg` | other | `pages/play/components/mascot/index.js:6` | `App/PlayExperienceView.swift` (shared) |
| `MPAsset.Other.mascotCat` | `pages/play/images/mascot-cat.svg` | other | `pages/play/components/mascot/index.js:5` | `App/PlayExperienceView.swift` (shared) |
| `MPAsset.MapMarker.dLocation` | `pages/searchmap/images/d_location.png` | map marker | `pages/searchmap/index.js:514` | `App/SearchMapExplorerView.swift` |
| `MPAsset.FeatureIcon.iconDeregister` | `pages/shezhi/images/icon_deregister.svg` | feature/category icon | `pages/shezhi/shezhi.wxml:26` | `App/SettingsView.swift` |
| `MPAsset.FeatureIcon.iconGlobe` | `pages/shezhi/images/icon_globe.svg` | feature/category icon | `pages/shezhi/shezhi.wxml:20` | `App/SettingsView.swift` |
| `MPAsset.FeatureIcon.iconInfoCircle` | `pages/shezhi/images/icon_info_circle.svg` | feature/category icon | `pages/shezhi/shezhi.wxml:27` | `App/SettingsView.swift` |
| `MPAsset.FeatureIcon.close2` | `pages/square/images/close2.png` | feature/category icon | `pages/square/list/index.wxml:78` | `App/SquareBrowserView.swift` |
| `MPAsset.FeatureIcon.close3` | `pages/square/images/close3.png` | feature/category icon | `pages/square/list/index.wxml:66` | `App/SquareBrowserView.swift` |
| `MPAsset.FeatureIcon.iconDot` | `pages/square/images/icon_dot.png` | feature/category icon | `pages/square/detail/index.wxml:149` | `App/SquareDetailView.swift` |
| `MPAsset.MapMarker.iconMap5` | `pages/square/images/icon_map5.png` | map marker | `pages/square/list/index.wxml:74` | `App/SquareBrowserView.swift` |
| `MPAsset.Other.dBaifx` | `pages/topic/images/d_baifx.png` | other | `pages/topic/index/index.wxml:367` | `App/TopicDetailView.swift` |
| `MPAsset.Other.dBmtk1` | `pages/topic/images/d_bmtk1.png` | other | `pages/topic/merchantinfo/merchantinfo.wxml:410` | `App/MerchantContentViews.swift` |
| `MPAsset.Other.dBmtk2` | `pages/topic/images/d_bmtk2.png` | other | `pages/topic/merchantinfo/merchantinfo.wxml:428` | `App/MerchantContentViews.swift` |
| `MPAsset.Other.dBmtk3` | `pages/topic/images/d_bmtk3.png` | other | `pages/topic/merchantinfo/merchantinfo.wxml:413` | `App/MerchantContentViews.swift` |
| `MPAsset.Other.dBmtk4` | `pages/topic/images/d_bmtk4.png` | other | `pages/topic/merchantinfo/merchantinfo.wxml:422` | `App/MerchantContentViews.swift` |
| `MPAsset.Other.dBmtk5` | `pages/topic/images/d_bmtk5.png` | other | `pages/topic/merchantinfo/merchantinfo.wxml:431` | `App/MerchantContentViews.swift` |
| `MPAsset.Other.dBmtk6` | `pages/topic/images/d_bmtk6.png` | other | `pages/topic/merchantinfo/merchantinfo.wxml:440` | `App/MerchantContentViews.swift` |
| `MPAsset.FeatureIcon.dStarH` | `pages/topic/images/d_star_h.png` | feature/category icon | `pages/topic/index/index.wxml:303` | `App/TopicDetailView.swift` |
| `MPAsset.Other.iconLine` | `pages/topic/images/icon_line.jpg` | other | `pages/topic/index/index.wxml:52` | `App/TopicDetailView.swift` |
| `MPAsset.FeatureIcon.iconLp` | `pages/topic/images/icon_lp.png` | feature/category icon | `pages/topic/index/index.wxml:353` | `App/TopicDetailView.swift` |
| `MPAsset.MapMarker.iconMap2` | `pages/topic/images/icon_map2.png` | map marker | `pages/topic/index/index.wxml:555` | `App/TopicDetailView.swift` |
| `MPAsset.FeatureIcon.iconWl` | `pages/topic/images/icon_wl.png` | feature/category icon | `pages/topic/index/index.wxml:246` | `App/TopicDetailView.swift` |
| `MPAsset.Other.yjt2` | `pages/topic/images/yjt2.png` | other | `pages/topic/index/index.wxml:251` | `App/TopicDetailView.swift` |
| `MPAsset.Other.dSubtraction` | `subpackageMember/images/d_subtraction.png` | other | `subpackageMember/coupon/coupon.wxml:35` | `App/AccountCollectionCouponsView.swift` |
| `MPAsset.Other.dYhqadd1` | `subpackageMember/images/d_yhqadd1.png` | other | `subpackageMember/couponInfo/couponInfo.wxml:35` | `App/AccountCollectionCouponDetailView.swift` |
| `MPAsset.Other.dYhqadd2` | `subpackageMember/images/d_yhqadd2.png` | other | `subpackageMember/couponInfo/couponInfo.wxml:46` | `App/AccountCollectionCouponDetailView.swift` |
| `MPAsset.FeatureIcon.iconDel` | `subpackageMember/images/icon_del.png` | feature/category icon | `subpackageMember/mytemplate/mytemplate.wxml:101` | `App/AccountCollectionFavoritesView.swift` |
| `MPAsset.FeatureIcon.subpackagememberImagesIconSend` | `subpackageMember/images/icon_send.png` | feature/category icon | `subpackageMember/mytemplate/mytemplate.wxml:94` | `App/AccountCollectionFavoritesView.swift` |
| `MPAsset.FeatureIcon.iconBack` | `subpackageP3/images/icon_back.png` | feature/category icon | `subpackageP3/pages/badge-wall/index/index.wxml:55` | `App/ObjectBadgeViews.swift` |

## Still Unused in the App — Actionable (`use this MP asset`)

Claude can wire these `MPAsset` accessors into the corresponding App screens:

| `MPAsset` | MP Path | App Screen | MP Source (`file:line`) |
| --- | --- | --- | --- |
| `MPAsset.FeatureIcon.clock` | `images/cards/clock.svg` | `App/HomeFeedView.swift` (shared) | `components/cy/merchant-card/index.wxml:13` |
| `MPAsset.FeatureIcon.members` | `images/cards/members.svg` | `App/ClubHomeView.swift` (shared) | `components/cy/club-card/index.wxml:15` |
| `MPAsset.BannerCover.imagesDFrametu` | `images/d_frametu.jpg` | `App/ClubDetailView.swift` (shared) | `utils/mockData.js:274` |
| `MPAsset.MapMarker.imagesDLocation2` | `images/d_location2.png` | `App/SearchMapExplorerView.swift` | `pages/searchmap/index.js:661` |
| `MPAsset.FeatureIcon.imagesDOrderIcon` | `images/d_orderIcon.png` | `App/InvoiceLaunchHistoryView.swift` | `subpackageMember/components/cy/scene-member-order-history/index.wxml:46` |
| `MPAsset.FeatureIcon.imagesDOrderIcon2` | `images/d_orderIcon2.png` | `App/InvoiceLaunchHistoryView.swift` | `subpackageMember/components/cy/scene-member-order-history/index.wxml:47` |
| `MPAsset.MapMarker.dSmapicon` | `images/d_smapicon.png` | `App/SearchMapExplorerView.swift` | `utils/roam-hangout.js:6` |
| `MPAsset.EmptyState.dYhqon` | `images/d_yhqon.png` | `App/PlayerJourneyViews.swift` | `subpackageMember/mycanyu/mycanyu.wxml:15` |
| `MPAsset.Other.imagesDel` | `images/del.png` | `App/ProfileEditView.swift` | `pages/gerenziliao/gerenziliao.wxml:82` |
| `MPAsset.Other.imagesFigmaInviteQr` | `images/figma-invite-qr.png` | `App/AccountView.swift` (shared) | `components/cy/scene-share-invite/index.js:35` |
| `MPAsset.BadgeMedal.imagesGroup2` | `images/group2.png` | `App/AccountView.swift` (shared) | `subpackageMember/components/cy/profile/index.wxml:59` |
| `MPAsset.BadgeMedal.imagesGroup3` | `images/group3.png` | `App/AccountView.swift` (shared) | `subpackageMember/components/cy/profile/index.wxml:60` |
| `MPAsset.BadgeMedal.imagesGroup4` | `images/group4.png` | `App/AccountView.swift` (shared) | `subpackageMember/components/cy/profile/index.wxml:61` |
| `MPAsset.BadgeMedal.imagesGroup5` | `images/group5.png` | `App/AccountView.swift` (shared) | `subpackageMember/components/cy/profile/index.wxml:62` |
| `MPAsset.BannerCover.homeBanner2` | `images/home-banner-2.jpg` | `App/HomeFeedView.swift` | `pages/index/index.js:192` |
| `MPAsset.BannerCover.homeRouteFreePlaceholder` | `images/home-route-free-placeholder.jpg` | `App/HomeFeedView.swift` | `pages/index/index.js:192` |
| `MPAsset.FeatureIcon.iconCat` | `images/icon_cat.png` | `App/GlobalSearchView.swift` | `utils/mockData.js:2` |
| `MPAsset.FeatureIcon.iconCat2` | `images/icon_cat2.png` | `App/HomeFeedView.swift` (shared) | `components/cy/category-sheet/index.js:124` |
| `MPAsset.FeatureIcon.imagesIconJia` | `images/icon_jia.png` | `App/SquareBrowserView.swift` (shared) | `components/cy/post-card/index.wxml:11` |
| `MPAsset.FeatureIcon.imagesIconPen` | `images/icon_pen.svg` | `App/AccountView.swift` (shared) | `subpackageMember/components/cy/profile/index.wxml:47` |
| `MPAsset.FeatureIcon.imagesIconQaPerson` | `images/icon_qa_person.svg` | `App/AccountView.swift` (shared) | `subpackageMember/components/cy/profile/index.wxml:220` |
| `MPAsset.FeatureIcon.iconRz` | `images/icon_rz.png` | `App/SquareBrowserView.swift` (shared) | `components/cy/post-card/index.wxml:19` |
| `MPAsset.FeatureIcon.imagesIconSet` | `images/icon_set.png` | `App/AccountView.swift` (shared) | `subpackageMember/components/cy/profile/index.wxml:15` |
| `MPAsset.FeatureIcon.iconSjt` | `images/icon_sjt.png` | `App/AccountView.swift` (shared) | `subpackageMember/components/cy/profile/index.wxml:249` |
| `MPAsset.FeatureIcon.iconSjtH` | `images/icon_sjt_h.png` | `App/AccountView.swift` (shared) | `subpackageMember/components/cy/profile/index.wxml:249` |
| `MPAsset.FeatureIcon.imagesIconStar` | `images/icon_star.png` | `App/AccountCollectionFavoritesView.swift` | `subpackageMember/mytemplate/mytemplate.wxml:26` |
| `MPAsset.EmptyState.imagesIconTicketEmpty` | `images/icon_ticket_empty.svg` | `App/OrderLifecycleView.swift` (shared) | `subpackageMember/components/cy/scene-member-order-detail/index.js:55` |
| `MPAsset.FeatureIcon.iconXjt` | `images/icon_xjt.png` | `App/AccountView.swift` (shared) | `subpackageMember/components/cy/profile/index.wxml:252` |
| `MPAsset.FeatureIcon.iconXjtH` | `images/icon_xjt_h.png` | `App/AccountView.swift` (shared) | `subpackageMember/components/cy/profile/index.wxml:252` |
| `MPAsset.FeatureIcon.iconViewers` | `images/index-figma/icon-viewers.png` | `App/HomeFeedView.swift` | `pages/index/index.wxml:156` |
| `MPAsset.BannerCover.nearbyCard` | `images/index-figma/nearby-card.jpg` | `App/RoamBrowserView.swift` | `pages/roam/index.js:43` |
| `MPAsset.BannerCover.clubCityCamera` | `images/interaction-templates/club-city-camera.svg` | `App/DiscoveryTemplateDetailView.swift` (shared) | `pages/template/index.js:33` |
| `MPAsset.BannerCover.clubGather` | `images/interaction-templates/club-gather.svg` | `App/DiscoveryTemplateDetailView.swift` (shared) | `pages/template/index.js:30` |
| `MPAsset.BannerCover.clubRelay` | `images/interaction-templates/club-relay.svg` | `App/DiscoveryTemplateDetailView.swift` (shared) | `pages/template/index.js:34` |
| `MPAsset.BannerCover.clubRoleMission` | `images/interaction-templates/club-role-mission.svg` | `App/DiscoveryTemplateDetailView.swift` (shared) | `pages/template/index.js:35` |
| `MPAsset.BannerCover.clubStreetPuzzle` | `images/interaction-templates/club-street-puzzle.svg` | `App/DiscoveryTemplateDetailView.swift` (shared) | `pages/template/index.js:32` |
| `MPAsset.BannerCover.clubTeamRace` | `images/interaction-templates/club-team-race.svg` | `App/DiscoveryTemplateDetailView.swift` (shared) | `pages/template/index.js:31` |
| `MPAsset.BannerCover.lifeBottomLine` | `images/interaction-templates/life-bottom-line.svg` | `App/DiscoveryTemplateDetailView.swift` (shared) | `pages/template/index.js:39` |
| `MPAsset.BannerCover.lifeFirstChoiceOffline` | `images/interaction-templates/life-first-choice-offline.svg` | `App/DiscoveryTemplateDetailView.swift` (shared) | `pages/template/index.js:43` |
| `MPAsset.BannerCover.lifeHoursPuzzle` | `images/interaction-templates/life-hours-puzzle.svg` | `App/DiscoveryTemplateDetailView.swift` (shared) | `pages/template/index.js:40` |
| `MPAsset.BannerCover.lifeOutageTest` | `images/interaction-templates/life-outage-test.svg` | `App/DiscoveryTemplateDetailView.swift` (shared) | `pages/template/index.js:37` |
| `MPAsset.BannerCover.lifePrepChecklist` | `images/interaction-templates/life-prep-checklist.svg` | `App/DiscoveryTemplateDetailView.swift` (shared) | `pages/template/index.js:41` |
| `MPAsset.BannerCover.lifeWhatFirst` | `images/interaction-templates/life-what-first.svg` | `App/DiscoveryTemplateDetailView.swift` (shared) | `pages/template/index.js:38` |
| `MPAsset.BannerCover.lifeWorthNow` | `images/interaction-templates/life-worth-now.svg` | `App/DiscoveryTemplateDetailView.swift` (shared) | `pages/template/index.js:42` |
| `MPAsset.BannerCover.merchantBlindTest` | `images/interaction-templates/merchant-blind-test.svg` | `App/DiscoveryTemplateDetailView.swift` (shared) | `pages/template/index.js:28` |
| `MPAsset.BannerCover.merchantFlavorStamp` | `images/interaction-templates/merchant-flavor-stamp.svg` | `App/DiscoveryTemplateDetailView.swift` (shared) | `pages/template/index.js:27` |
| `MPAsset.BannerCover.merchantPhotoMoment` | `images/interaction-templates/merchant-photo-moment.svg` | `App/DiscoveryTemplateDetailView.swift` (shared) | `pages/template/index.js:26` |
| `MPAsset.BannerCover.merchantSecretCode` | `images/interaction-templates/merchant-secret-code.svg` | `App/DiscoveryTemplateDetailView.swift` (shared) | `pages/template/index.js:24` |
| `MPAsset.BannerCover.merchantSecretQuestion` | `images/interaction-templates/merchant-secret-question.svg` | `App/DiscoveryTemplateDetailView.swift` (shared) | `pages/template/index.js:25` |
| `MPAsset.BannerCover.merchantStyleMission` | `images/interaction-templates/merchant-style-mission.svg` | `App/DiscoveryTemplateDetailView.swift` (shared) | `pages/template/index.js:29` |
| `MPAsset.BannerCover.imagesMer1` | `images/mer1.jpg` | `App/ClubDetailView.swift` (shared) | `utils/mockData.js:311` |
| `MPAsset.FeatureIcon.imagesMerchantReviewsIconStarFilled` | `images/merchant/reviews/icon-star-filled.svg` | `App/MerchantBusinessViews.swift` | `pages/merchant/reviews/index.wxml:33` |
| `MPAsset.FeatureIcon.imagesMerchantReviewsIconStarMuted` | `images/merchant/reviews/icon-star-muted.svg` | `App/MerchantBusinessViews.swift` | `pages/merchant/reviews/index.wxml:33` |
| `MPAsset.FeatureIcon.imagesMerchantReviewsIconStarSmall` | `images/merchant/reviews/icon-star-small.svg` | `App/MerchantBusinessViews.swift` | `pages/merchant/reviews/index.wxml:152` |
| `MPAsset.Other.imagesNavMsg` | `images/nav_msg.svg` | `App/ClubHomeView.swift` (shared) | `pages/talent/list/index.wxml:15` |
| `MPAsset.FeatureIcon.assetReturn` | `images/publish-quick/return.png` | `App/PublishingModesViews.swift` (shared) | `components/cy/publish-sheet/index.wxml:14` |
| `MPAsset.FeatureIcon.introMap` | `images/roam/intro-map.svg` | `App/RoamBrowserView.swift` | `pages/roam/index.wxml:112` |
| `MPAsset.FeatureIcon.introRoam` | `images/roam/intro-roam.svg` | `App/RoamBrowserView.swift` | `pages/roam/index.wxml:106` |
| `MPAsset.FeatureIcon.introTeam` | `images/roam/intro-team.svg` | `App/RoamBrowserView.swift` | `pages/roam/index.wxml:118` |
| `MPAsset.BannerCover.imagesRouteFreeCover` | `images/route_free_cover.png` | `App/CreatorContentViews.swift` | `subpackageA/pages/myproject/index.wxml:48` |
| `MPAsset.FeatureIcon.dBianji2` | `pages/gerenziliao/images/d_bianji2.png` | `App/ProfileEditView.swift` | `pages/gerenziliao/gerenziliao.wxml:20` |
| `MPAsset.FeatureIcon.iconBellAlert` | `pages/merchant/images/icon_bell_alert.svg` | `App/MerchantHomeView.swift` | `pages/merchant/index/index.wxml:175` |
| `MPAsset.FeatureIcon.iconBellMuted` | `pages/merchant/images/icon_bell_muted.svg` | `App/MerchantHomeView.swift` | `pages/merchant/index/index.wxml:183` |
| `MPAsset.FeatureIcon.iconWallet` | `pages/merchant/images/icon_wallet.svg` | `App/MerchantHomeView.swift` | `pages/merchant/index/index.wxml:259` |
| `MPAsset.FeatureIcon.iconUp` | `pages/mylike/images/icon_up.png` | `App/AccountCollectionFavoritesView.swift` | `pages/mylike/mylike.wxml:48` |
| `MPAsset.Other.pagesPlayComponentsPlaykitScanArReticle` | `pages/play/components/playkit-scan/ar/reticle.png` | `App/PlayKitScreen.swift` (shared) | `pages/play/components/playkit-scan/ar/index.wxml:15` |
| `MPAsset.BannerCover.dTopic1` | `pages/play/images/d_topic1.png` | `App/PlayExperienceView.swift` (shared) | `pages/play/index.js:275` |
| `MPAsset.BannerCover.dTopic2` | `pages/play/images/d_topic2.png` | `App/PlayExperienceView.swift` (shared) | `pages/play/index.js:283` |
| `MPAsset.BannerCover.dTopic4` | `pages/play/images/d_topic4.png` | `App/PlayExperienceView.swift` (shared) | `pages/play/index.js:291` |
| `MPAsset.BannerCover.dTopic5` | `pages/play/images/d_topic5.png` | `App/PlayExperienceView.swift` (shared) | `pages/play/index.js:315` |
| `MPAsset.Other.mascotCatBlind` | `pages/play/images/mascot-cat-blind.svg` | `App/PlayExperienceView.swift` (shared) | `pages/play/components/mascot/index.js:6` |
| `MPAsset.Other.mascotCat` | `pages/play/images/mascot-cat.svg` | `App/PlayExperienceView.swift` (shared) | `pages/play/components/mascot/index.js:5` |
| `MPAsset.FeatureIcon.iconDate3` | `pages/publish/images/icon_date3.png` | `App/PublishingModesViews.swift` | `pages/publish/activity/index.wxml:62` |
| `MPAsset.FeatureIcon.iconDeregister` | `pages/shezhi/images/icon_deregister.svg` | `App/SettingsView.swift` | `pages/shezhi/shezhi.wxml:26` |
| `MPAsset.FeatureIcon.iconGlobe` | `pages/shezhi/images/icon_globe.svg` | `App/SettingsView.swift` | `pages/shezhi/shezhi.wxml:20` |
| `MPAsset.FeatureIcon.iconInfoCircle` | `pages/shezhi/images/icon_info_circle.svg` | `App/SettingsView.swift` | `pages/shezhi/shezhi.wxml:27` |
| `MPAsset.FeatureIcon.iconDot` | `pages/square/images/icon_dot.png` | `App/SquareDetailView.swift` | `pages/square/detail/index.wxml:149` |
| `MPAsset.MapMarker.iconMap5` | `pages/square/images/icon_map5.png` | `App/SquareBrowserView.swift` | `pages/square/list/index.wxml:74` |
| `MPAsset.Other.dBaifx` | `pages/topic/images/d_baifx.png` | `App/TopicDetailView.swift` | `pages/topic/index/index.wxml:367` |
| `MPAsset.Other.dBmtk1` | `pages/topic/images/d_bmtk1.png` | `App/MerchantContentViews.swift` | `pages/topic/merchantinfo/merchantinfo.wxml:410` |
| `MPAsset.Other.dBmtk2` | `pages/topic/images/d_bmtk2.png` | `App/MerchantContentViews.swift` | `pages/topic/merchantinfo/merchantinfo.wxml:428` |
| `MPAsset.Other.dBmtk3` | `pages/topic/images/d_bmtk3.png` | `App/MerchantContentViews.swift` | `pages/topic/merchantinfo/merchantinfo.wxml:413` |
| `MPAsset.Other.dBmtk4` | `pages/topic/images/d_bmtk4.png` | `App/MerchantContentViews.swift` | `pages/topic/merchantinfo/merchantinfo.wxml:422` |
| `MPAsset.Other.dBmtk5` | `pages/topic/images/d_bmtk5.png` | `App/MerchantContentViews.swift` | `pages/topic/merchantinfo/merchantinfo.wxml:431` |
| `MPAsset.Other.dBmtk6` | `pages/topic/images/d_bmtk6.png` | `App/MerchantContentViews.swift` | `pages/topic/merchantinfo/merchantinfo.wxml:440` |
| `MPAsset.FeatureIcon.dStarH` | `pages/topic/images/d_star_h.png` | `App/TopicDetailView.swift` | `pages/topic/index/index.wxml:303` |
| `MPAsset.FeatureIcon.dWeihao` | `pages/topic/images/d_weihao.png` | `App/MerchantContentViews.swift` | `pages/topic/merchantinfo/merchantinfo.wxml:377` |
| `MPAsset.FeatureIcon.pagesTopicImagesIconCopy` | `pages/topic/images/icon_copy.svg` | `App/TopicDetailView.swift` (shared) | `pages/topic/components/project-join/index.wxml:229` |
| `MPAsset.FeatureIcon.iconCreatorSpark` | `pages/topic/images/icon_creator_spark.svg` | `App/TopicDetailView.swift` (shared) | `pages/topic/components/project-join/index.wxml:251` |
| `MPAsset.Other.iconLine` | `pages/topic/images/icon_line.jpg` | `App/TopicDetailView.swift` | `pages/topic/index/index.wxml:52` |
| `MPAsset.FeatureIcon.iconLp` | `pages/topic/images/icon_lp.png` | `App/TopicDetailView.swift` | `pages/topic/index/index.wxml:353` |
| `MPAsset.MapMarker.iconMap2` | `pages/topic/images/icon_map2.png` | `App/TopicDetailView.swift` | `pages/topic/index/index.wxml:555` |
| `MPAsset.FeatureIcon.iconPhoto2` | `pages/topic/images/icon_photo2.png` | `App/TopicDetailView.swift` | `pages/topic/index/index.wxml:597` |
| `MPAsset.FeatureIcon.iconQaClub` | `pages/topic/images/icon_qa_club.svg` | `App/MerchantContentViews.swift` | `pages/topic/merchantinfo/merchantinfo.js:160` |
| `MPAsset.FeatureIcon.iconQaEdit` | `pages/topic/images/icon_qa_edit.svg` | `App/MerchantContentViews.swift` | `pages/topic/merchantinfo/merchantinfo.js:162` |
| `MPAsset.FeatureIcon.pagesTopicImagesIconQaPerson` | `pages/topic/images/icon_qa_person.svg` | `App/MerchantContentViews.swift` | `pages/shezhi/shezhi.wxml:14` |
| `MPAsset.FeatureIcon.iconQaScan` | `pages/topic/images/icon_qa_scan.svg` | `App/MerchantContentViews.swift` | `pages/topic/merchantinfo/merchantinfo.js:159` |
| `MPAsset.FeatureIcon.iconQaStore` | `pages/topic/images/icon_qa_store.svg` | `App/MerchantContentViews.swift` | `pages/topic/merchantinfo/merchantinfo.js:1958` |
| `MPAsset.FeatureIcon.iconTodoCheck` | `pages/topic/images/icon_todo_check.svg` | `App/TopicDetailView.swift` (shared) | `pages/topic/components/project-join/index.wxml:306` |
| `MPAsset.FeatureIcon.iconWl` | `pages/topic/images/icon_wl.png` | `App/TopicDetailView.swift` | `pages/topic/index/index.wxml:246` |
| `MPAsset.Other.clock` | `pages/topic/images/merchant-guide/clock.svg` | `App/MerchantContentViews.swift` | `pages/topic/merchantinfo/merchantinfo.wxml:256` |
| `MPAsset.Other.location` | `pages/topic/images/merchant-guide/location.svg` | `App/MerchantContentViews.swift` | `pages/topic/merchantinfo/merchantinfo.wxml:257` |
| `MPAsset.Other.people` | `pages/topic/images/merchant-guide/people.svg` | `App/MerchantContentViews.swift` | `pages/topic/merchantinfo/merchantinfo.wxml:258` |
| `MPAsset.Other.xjt` | `pages/topic/images/xjt.png` | `App/MerchantContentViews.swift` | `pages/topic/merchantinfo/merchantinfo.wxml:135` |
| `MPAsset.Other.yjt2` | `pages/topic/images/yjt2.png` | `App/TopicDetailView.swift` | `pages/topic/index/index.wxml:251` |
| `MPAsset.Other.dSubtraction` | `subpackageMember/images/d_subtraction.png` | `App/AccountCollectionCouponsView.swift` | `subpackageMember/coupon/coupon.wxml:35` |
| `MPAsset.Other.dYhqadd1` | `subpackageMember/images/d_yhqadd1.png` | `App/AccountCollectionCouponDetailView.swift` | `subpackageMember/couponInfo/couponInfo.wxml:35` |
| `MPAsset.Other.dYhqadd2` | `subpackageMember/images/d_yhqadd2.png` | `App/AccountCollectionCouponDetailView.swift` | `subpackageMember/couponInfo/couponInfo.wxml:46` |
| `MPAsset.FeatureIcon.iconDel` | `subpackageMember/images/icon_del.png` | `App/AccountCollectionFavoritesView.swift` | `subpackageMember/mytemplate/mytemplate.wxml:101` |
| `MPAsset.FeatureIcon.subpackagememberImagesIconSend` | `subpackageMember/images/icon_send.png` | `App/AccountCollectionFavoritesView.swift` | `subpackageMember/mytemplate/mytemplate.wxml:94` |
| `MPAsset.BadgeMedal.goldMatcap` | `subpackageP3/assets/gold-matcap.png` | `App/ObjectBadgeViews.swift` | `subpackageP3/components/xr-badge/index.js:187` |

## Intentionally Kept as SF Symbols (System-Control Glyphs)

| `MPAsset` | MP Path | App Screen | MP Source (`file:line`) | Rule |
| --- | --- | --- | --- | --- |
| `MPAsset.FeatureIcon.iconRight` | `images/icon_right.png` | `App/PublishingModesViews.swift` (shared) | `subpackageMember/couponInfo/couponInfo.wxml:57` | Keep SF Symbol `chevron.right`. System-control glyphs stay SF Symbols: disclosure chevron (same family as the back chevron). |
| `MPAsset.FeatureIcon.imagesIconSearch` | `images/icon_search.svg` | `App/DiscoveryTemplateBrowserView.swift` | `pages/template/index.wxml:29` | Keep SF Symbol `magnifyingglass`. System-control glyphs stay SF Symbols: search magnifier. |
| `MPAsset.FeatureIcon.iconShare` | `images/icon_share.png` | `App/SquareDetailView.swift` | `components/cy/post-card/index.wxml:127` | Keep SF Symbol `square.and.arrow.up`. System-control glyphs stay SF Symbols: share. |
| `MPAsset.FeatureIcon.dClose` | `pages/address/images/d_close.png` | `App/ProfileParticipantsView.swift` | `pages/address/address.wxml:27` | Keep SF Symbol `xmark`. System-control glyphs stay SF Symbols: close ✕. |
| `MPAsset.FeatureIcon.close2` | `pages/square/images/close2.png` | `App/SquareBrowserView.swift` | `pages/square/list/index.wxml:78` | Keep SF Symbol `xmark`. System-control glyphs stay SF Symbols: close ✕. |
| `MPAsset.FeatureIcon.close3` | `pages/square/images/close3.png` | `App/SquareBrowserView.swift` | `pages/square/list/index.wxml:66` | Keep SF Symbol `xmark`. System-control glyphs stay SF Symbols: close ✕. |
| `MPAsset.FeatureIcon.iconBack` | `subpackageP3/images/icon_back.png` | `App/ObjectBadgeViews.swift` | `subpackageP3/pages/badge-wall/index/index.wxml:55` | Keep SF Symbol `chevron.backward`. System-control glyphs stay SF Symbols: back chevron. |
| `MPAsset.FeatureIcon.iconCloseSm` | `subpackageP3/images/icon_close_sm.png` | `App/ObjectBadgeViews.swift` | `subpackageP3/pages/badge-wall/index/index.wxml:89` | Keep SF Symbol `xmark`. System-control glyphs stay SF Symbols: close ✕. |

# UI gap list, family e5 (utility and long-tail player pages)

Base: rc/20261108 (d1-d7 merged). Source: `docs/parity/page-map.csv` (163 rows), merchant rows out of scope.
Claimed elsewhere (not e5): home/search/roam/map (d2,d6,e1,e2), welcome/login (d1), orders/wallet/coupons/tickets (d3,e1,e4), clubs/me/settings (d4,e3,e4), publish menu/templates (d7), IM/social (e3), account/settings/wallet remainder/growth (e4), play/city/stamps/badges (e2).

## e5 pages
| Page | Native view | Status |
|---|---|---|
| subpackageA/pages/infomation/infomation | SocialGuideViews (SocialPlayGuideView) | restyled, fixture `e5-guide`, `e5-guide-empty` |
| subpackageA/pages/infomationdetail | SocialInformationView | restyled, fixture `e5-info-detail`, `e5-info-link` |
| subpackageA/pages/myproject/index (+ creator center) | CreatorContentViews, MyProjectTabViews | restyled, fixtures `e5-creator-*` (overlaps e4 "creator pages") |
| subpackageMember/free-explore/index | FreeExploreBundleLaunchView | restyled, fixture `e5-free-explore` |
| subpackageMember/invoice, invoice-detail, invoice-apply, invoice-titles | InvoiceLaunch* | restyled, fixtures `e5-invoice-*` |
| subpackageMember/invoice-title-edit | InvoiceLaunchTitleEditor | LEFT |
| pages/play/circle/index (retired link) | PlayCircleRetiredLinkView | already kit, fixture `e5-circle-link` |
| pages/crop/index | MiniCropView / TemplateImageCropView | already kit, fixture `e5-crop` |
| Route error / deep-link landing | NativeRouteErrorView, NativeEntryLandingView | restyled; route error fixture `e5-route-error`, `e5-route-legacy`; landing needs AppSession, no fixture |
| H5 shells | H5PlatformShellView, H5ShellParentFlowView, H5LaunchProducerView, H5DeclaredSessionView | restyled, fixtures `e5-h5-*` |
| AI design (club) | ClubAIDesignView | restyled, fixture `e5-club-ai` (disabled state only) |
| External game import | ExternalGameLibrarySection | already kit, fixture `e5-external-game` (empty library) |
| pages/publish/simple, activity | PublishingModesViews | done by d7 |
| pages/publish/temp, template-intro, mytemplate, fabu, topicadd | TemplateAuthoring*, ProjectEditView | LEFT (gated; need fixture hosts with harness args) |
| pages/topic/pricing, pricing/partner | PublisherLifecycleViews | LEFT |
| subpackageTools/* (capsule, recap, anniversary, goals, export) | RoamPassport*Tools* | LEFT, likely e2 (roam) |
| subpackageMember/myinvite | SocialInviteHistoryView | LEFT, likely e3 |
| report-mine / report-detail / appeal-mine | Member*Report/Appeal | LEFT, likely e3 (safety) |
| Maintenance / version-update pages | none exist natively | nothing invented |
| QR scanner / app clip handshake | NativeQRScanner (camera); *SectionView audit files are developer diagnostics, not player UI | not restyled |

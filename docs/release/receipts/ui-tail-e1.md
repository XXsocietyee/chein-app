# ui-tail-e1 (worker from the START of the list)

Source list: `/Users/fanning/chengyin-refs/tail-e1.txt` (88 files). Batches of 5, in file order. Not compiled locally; cloud Build+Test per push. e1 works from the end.

## Batch 1
| File | Result |
| --- | --- |
| App/ActivityBrowserView.swift | done: CYEmptyState (unavailable/error+retry/empty), CYPillButton load-more/retry; root keeps nav title (searchable) |
| App/ActivityDetailView.swift | done: CYEmptyState states, CYPillButton primary bottom action + club gate, label helper removed |
| App/ActivityEditingView.swift | done: CYHeroHeader (one title), cyGroupedSurface, CYPillButton actions (one primary per section) |
| App/ActivityHostCancelView.swift | done: CYLoadingStateView, CYStatusChip blocked/cancelled, CYPillButton recheck/done; destructive confirm stays role button + confirmationDialog |
| App/ApprovedTopicReviewRequestView.swift | done: CYLoadingStateView, CYPillButton review/submit primary, others secondary |

## Batch 2
| File | Result |
| --- | --- |
| App/BundleAppealView.swift | done: CYPillButton submit (primary) / check / resend, CYLoadingStateView; embedded form, no own title so no hero |
| App/BundleCancelView.swift | done: CYHeroHeader, cyGroupedSurface, CYPillButton, CYLoadingStateView; destructive confirm stays role button |
| App/BundleOrderStatusView.swift | done: CYPillButton recheck, cyGroupedSurface; no own title (embedded) |
| App/BundleRedeemResultView.swift | done: CYHeroHeader, CYLoadingStateView, CYPillButton retry |
| App/BundleRefundQuoteView.swift | done: CYHeroHeader, monospaced amounts, cyGroupedSurface (read-only, no action by design) |

## Batch 3
| File | Result |
| --- | --- |
| App/BundleRenewalIntentView.swift | done: CYHeroHeader, CYLoadingStateView, CYPillButton submit (primary) / recover / retry |
| App/BundleReservationsView.swift | done: CYEmptyState empty, monospaced start time, cyGroupedSurface (display only) |
| App/BundleReserveWindowView.swift | done: CYPillButton choose (embedded Section, no own title) |
| App/BundleReviewComposeView.swift | done: CYLoadingStateView, CYPillButton submit/check/resend, monospaced counter |
| App/BundleTransferClaimView.swift | done: CYPillButton claim, CYLoadingStateView, cyGroupedSurface |
| App/BundleTransferSendView.swift | done (list item 16): CYLoadingStateView, CYPillButton confirm (primary) / recover; revoke stays destructive role button; cyGroupedSurface |
| App/BundleWalletView.swift | done (list item 17): CYEmptyState noDetail, monospaced totals, cyGroupedSurface |

(Batches are 5 files in list order; items 16-17 were done together with batch 3 and count toward batch 4.)

## Batch 4 (remaining items 18-20)
| File | Result |
| --- | --- |
| App/DiscoveryHomeView.swift | done: CYEmptyState (unavailable/empty), CYLoadingStateView; root keeps nav title |
| App/DiscoveryPlayTemplatePresentationView.swift | done: monospaced use count (Section fragment, no own chrome) |
| App/DiscoveryTemplateBrowserView+Port.swift | done: CYLoadingStateView, CYPillButton empty refresh; cover thumb left (private fallback tile, no behaviour change) |

## Batch 5
| File | Result |
| --- | --- |
| App/MemberTemplateDetailView.swift | done: CYLoadingStateView, CYStatusChip draft/published, CYPillButton retry; keeps nav title (content title is the template's own) |
| App/ModInstallationTemplateEditorView.swift | done: CYHeroHeader, cyGroupedSurface, CYPillButton (save primary, others secondary/tertiary), confirm primary in review sheet |
| App/NearbyMapDiscoveryView.swift | done: CYLoadingStateView status, CYPillButton clear-tag; map/model code untouched |
| App/OfficialActionViews.swift | done: hero in publish/broadcast/invite editors, CYPillButton review/confirm (one primary each), CYLoadingStateView |
| App/OfficialEventsBrowserView.swift | done: CYEmptyState empty list; search/filter untouched |

## Batch 6
| File | Result |
| --- | --- |
| App/OrderPassPreviewView.swift | done: CYPillButton disabled verification action; kept ContentUnavailableView (two accessibility identifiers on its label/description would be lost with CYEmptyState) |
| App/OwnedTemplateConfigurationView.swift | done: CYHeroHeader on both forms (one title each), CYLoadingStateView, CYPillButton story/retry, cyGroupedSurface |
| App/OwnedTemplateSensorConfigurationView.swift | skipped: a value-only Section fragment inside the owner host, no title/buttons/states of its own, already tokens |
| App/OwnedTopicCoverAuthorView.swift | done: CYHeroHeader in main + confirm sheets, 13 buttons to CYPillButton (choose/review/confirm primary, rest secondary), CYLoadingStateView |
| App/OwnedTopicCoverImageView.swift | done: CYLoadingStateView, CYPillButton retry; inline nav title kept (image sheet) |

## Batch 7
| File | Result |
| --- | --- |
| App/ParticipantManagementDetailView.swift | done: CYEmptyState (sign-in/unavailable), CYLoadingStateView, CYPillButton edit primary; delete stays destructive role + confirmation |
| App/PlayFinishRouteCardView.swift | done: CYStatusChip for free price; card layout untouched (already Theme tokens) |
| App/PlayRouteMapView.swift | done: CYPillButton (open-current primary, toggles tertiary, refresh secondary), CYLoadingStateView; map/camera code untouched |
| App/PrivateHomeView.swift | done: CYHeroHeader, CYEmptyState gate, CYPillButton (set/confirm primary), delete stays destructive role, cyGroupedSurface |
| App/ProfileOrderMeetingPointView.swift | done: CYPillButton open/confirm, CYLoadingStateView, hero in review sheet |

## Batch 8
| File | Result |
| --- | --- |
| App/ProjectStoryTemplateView.swift | done: CYHeroHeader (locale-safe table keys), CYPillButton apply primary / back / refresh / more, CYLoadingStateView, cyGroupedSurface |
| App/PublisherIdentityRegistrationView.swift | done: CYPillButton submit/open primary, refresh/return, CYLoadingStateView (Section fragment, no hero) |
| App/RegistrationSheetView.swift | done (partial by design): CYPillButton for 11 secondary actions, 8 CYLoadingStateView; checkout bar (cyPrimary) and alerts/destructive left as-is |
| App/SearchMapDetailViews.swift | done: CYLoadingStateView |
| App/SearchMapExplorerView.swift | done: CYPillButton (search area primary), CYEmptyState, CYLoadingStateView; map/selection logic untouched |

## Batch 9
| File | Result |
| --- | --- |
| App/SearchRoutePreviewView.swift | done: CYLoadingStateView, CYPillButton remove/retry |
| App/SecondRegistrationStatsView.swift | done: CYEmptyState unavailable, cyGroupedSurface (read-only report, rate rows already mono) |
| App/SessionGlobalSearchView.swift | skipped: pure host wrapper around GlobalSearchView, no UI of its own |
| App/SessionHomeFeedView.swift | skipped: host with native toolbar/menu/sheets (close buttons are toolbar items), no restylable content of its own |
| App/SessionTopicBrowserView.swift | skipped: pure host wrapper around TopicBrowserView |

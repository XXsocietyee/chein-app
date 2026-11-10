# ui-tail-e4

Source list: `/Users/fanning/chengyin-refs/tail-e4.txt` (38 files). Batches of 5, in file order. Not compiled locally; cloud Build+Test per push.

## Batch 1
| File | Result |
| --- | --- |
| App/AccountView.swift | done: CYHeroHeader + cyHeroScreen (one title), cyGroupedSurface |
| App/BankWithdrawalView.swift | done: hero, CYStatusChip states, CYPillButton primary/confirm/prepare, danger tokens |
| App/CollectSetAuthorView.swift | done: hero, CYPillButton save, cyGroupedSurface |
| App/CreatorCropExportView.swift | done: spacing/colour tokens, 44pt picker, dark page ground |
| App/DeregistrationParityViews.swift | done: spacing tokens, CYPillButton recheck |

Order change (coordinator): remaining files processed in reverse list order; no `origin/ui/cloud-*` branches existed at batch 2 time, so nothing was cloud-owned.

## Batch 2 (reverse order)
| File | Result |
| --- | --- |
| App/WithdrawalSupportLandingView.swift | done: hero, CYPillButton retry/contact, cyGroupedSurface |
| App/WithdrawalSupportContactView.swift | done: hero, CYPillButton copy/retry, CYStatusChip unconfigured |
| App/WithdrawalHistoryView.swift | done: hero, CYLoadingStateView, CYEmptyState (empty + error states, retry), CYStatusChip status |
| App/UsageConsentReadView.swift | done: hero, CYPillButton |
| App/SettingsPrivacyLocationView.swift | done: hero, CYEmptyState media states, CYPillButton |

## Batch 3 (reverse order)
| File | Result |
| --- | --- |
| App/SessionWalletCommerceView.swift | done: CYEmptyState for the stale-session fallback (host wrappers otherwise have no UI) |
| App/SessionBankWithdrawalView.swift | skipped: pure wrapper around BankWithdrawalView (restyled in batch 1), no UI of its own |
| App/QmodAuthorImportView.swift | done: hero, CYPillButton actions (one primary), token colours |
| App/ProjectNodeImageAuthorView.swift | done: hero, CYPillButton actions (one primary), cyGroupedSurface |
| App/ProfileReadScreen.swift | done: CYEmptyState sign-in/unavailable states, CYPillButton retry |

## Batch 4 (reverse order)
| File | Result |
| --- | --- |
| App/ProfileInviteHistoryIssueView.swift | done: CYStatusChip issue, CYPillButton retry, CYEmptyState empty |
| App/ProfileFavoriteRemovalView.swift | done: hero in sheet, CYPillButton retry/check/done (destructive confirm stays a role button), grouped surface |
| App/ProfileCurrentAvatarView.swift | done: CYSkeletonBlock loading, CYPillButton retry |
| App/PrivacyProtectionView.swift | done: hero with subtitle, icon+colour consent status, grouped surface |
| App/NativeZeroHPAuthorView.swift | done: hero, CYPillButton reload actions, grouped surface |

## Batch 5 (reverse order)
Embedded editor sections (no own screen/title): kit buttons only. Confirm-save is the single primary; open/preview secondary; close/restore tertiary; destructive remove rows keep their role button.
| File | Result |
| --- | --- |
| App/NativeSharedRecoveryAuthorView.swift | done |
| App/NativeRpgResourceAuthorView.swift | done |
| App/NativeRpgPassiveRulesAuthorView.swift | done |
| App/NativeRpgEnvironmentAuthorView.swift | done |
| App/NativeRpgConditionAuthorView.swift | done |

## Batch 6 (reverse order)
| File | Result |
| --- | --- |
| App/NativeProgressPrivacyView.swift | done: hero, CYPillButton recover/confirm/cancel/refresh |
| App/NativeNotificationPermissionNudgeView.swift | done: hero, CYPillButton request/settings (one primary) |
| App/NativeConditionAuthorView.swift | done: hero (root list), CYPillButton save |
| App/NativeChannelProgressPrivacyView.swift | done: hero, CYEmptyState closed, CYLoadingStateView, CYPillButton save/recover |
| App/NativeChannelNotificationGlobalView.swift | done: hero, one visible title |

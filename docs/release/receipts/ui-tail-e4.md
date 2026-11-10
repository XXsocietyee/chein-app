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

## Batch 7 (reverse order)
| File | Result |
| --- | --- |
| App/ModCreatorIncomeViews.swift | done: hero on list + detail, CYPillButton reads, CYStatusChip dispute flag |
| App/MemberScoreAppealListView.swift | done: hero with boundary subtitle, CYEmptyState, CYPillButton |
| App/MemberScoreAppealDetailView.swift | done: hero, CYPillButton refresh |
| App/MemberReportProgressDetailView.swift | done: hero, CYPillButton refresh |
| App/MemberIdentityAvatarView.swift | done: raised-token placeholder ground behind the avatar surface (lifecycle code untouched) |

## Batch 8 (reverse order, remainder)
| File | Result |
| --- | --- |
| App/NativeAttributeAuthorViews.swift | done: hero on root list, CYPillButton (check-save / confirm / keep primary), grouped surface |
| App/NativeChannelNotificationConversationView.swift | done: hero, CYPillButton save/recovery, one visible title |
| App/SettingsLegalDocumentView.swift | done: CYLoadingStateView, CYEmptyState missing document, CYPillButton retry (document keeps its own title) |

## Summary
38 files in list: 37 restyled, 1 skipped (SessionBankWithdrawalView: pure wrapper, no UI). No merchant-only files in the list. No cloud-owned files (no origin/ui/cloud-* branches existed). No new string keys (all existing keys reused); `docs/release/ui-strings-e4-tail.json` is `[]`. No local builds; cloud results below.

Cloud result for 13ad8ea2f (all 8 batches): Build - iOS success. Test - iOS reports `action_required` (not run; no red). Earlier per-batch runs were superseded/cancelled by the next push.

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

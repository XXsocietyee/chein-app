# wired-e3 (SL3 social wiring) — NOT WIRED, blocked

Merged origin/ui/main and origin/rc/20261108 (rc already up to date). The model types for the family rows are not defined on rc or ui/main; rc only names them in docs/receipts. No view was swapped, so there are no wiring commits to list.

| row (page) | view | model.property | status |
| --- | --- | --- | --- |
| club/apply | ClubGovernanceViews | ClubHostApplyPageModel.snapshot | type only on cursor/cb237, cursor/wire7 |
| club/detail | ClubDetailView | ClubDetailPageModel.resolve | type only on cursor/cb242, cursor/wire11 |
| im/list | MessagingHomeView | IMListPageReady.project | type only on cursor/cb229 |
| club/checkin-detail, create, customer-detail, edit, group-code, governance, join-requests, notify; coop/invite-detail, coop/list, coop/nearby; talent/list; im/chat | see view-requests-91.md | see file | type not found; wire13-19 PRs cover several |

Commit: none.

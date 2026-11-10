# wire29

[x] 26e87fbbacedcbc0f6077b4395ca202b5085afd6

PR 1030. Branch `cursor/wire29`. Parent `a9b89c901`. Base `rc/20261108`. +61/−4.

The CRM campaigns screen in `App/MerchantEngagementViews.swift` reads `MerchantCrmCampaignsPage.phase`. A missing count is an em dash. A present integer 0 stays 0. Dispatch, retry, and the campaign section stay hidden when those capabilities are absent. The view change is +18/−4. Not merged to rc.

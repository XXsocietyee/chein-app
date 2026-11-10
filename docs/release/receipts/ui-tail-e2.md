# UI tail (E2) receipt
Source list: chengyin-refs/tail-e2.txt (62 files). NOT COMPILED locally; cloud Build+Test per batch.
No new string keys so far (kit components reuse existing keys; docs/release/ui-strings-e2-tail.json lists any added).

## Batch 1
- done: ChallengePOIView (CYSkeleton, CYStatusChip distance, CYSectionHeader, CYPillButton, CYHeroHeader + cyHeroScreen on host)
- done: CityAcquisitionView (CYHeroHeader+cyHeroScreen, CYPillButton, CYSkeleton, CYEmptyState)
- done: CityActionBudgetView (CYStatusChip, CYEmptyState)
- done: CityArrivalEvidenceRuntimeHostView (CYEmptyState)
- skipped (merchant-only): ChapterReplacementInvitationView (MerchantChapterReplacementHostContext)

## Batch 2
- done: CityFairnessView (CYHeroHeader+cyHeroScreen x2, CYListRow, CYPillButton, CYSkeleton, CYEmptyState)
- done: CityNeutralTaskResultRecoveryView (CYPillButton, CYSkeleton)
- done: CityNeutralTaskRuntimeHostView, CityOnsiteTaskRuntimeHostView (CYEmptyState)
- skipped (merchant-only): CityNodeRedeemView (merchant.cityRedeem, MerchantBusinessReading)

# IWP-8a new strings (not added to any xcstrings; orchestrator/IWP-L to localize)

All are inline `W8Text.t(zh, en)` pairs today (same pattern as `Core/FreeExploreCancelFlow.swift`), so nothing is missing at runtime.

| zh-Hans | en | Where |
|---|---|---|
| 审核中 | Under review | `BundleReviewStatusKind.underReview` |
| 已发布 | Published | `.published` |
| 未通过审核 | Not approved | `.rejected` |
| 已隐藏 | Hidden | `.hidden` |
| 状态未知 | Status unknown | `.unknown` |
| 评价功能暂未开放 | Reviews are not available yet | compose + list views (unavailable) |
| 暂时无法评价，未发送任何内容 | Can't review right now. Nothing was sent. | compose view (failed) |
| 当前订单暂不可评价 | This order can't be reviewed right now | compose view (blocked) |
| 评分 | Rating | compose view |
| 评价未被接受 | Your review wasn't accepted | compose view (rejected) |
| 评价是否提交成功尚未确认 | We couldn't confirm whether your review was submitted | compose view (unknown outcome) |
| 查询提交结果 | Check status | compose view |
| 重新提交 | Submit again | compose view |
| 提交评价 | Submit review | compose view |
| 评价加载失败 | Couldn't load reviews | list view |
| 暂无评价 | No reviews yet | list view |
| 加载更多 | Load more | list view |

Server business codes (duplicate, not eligible, …) are shown verbatim; `bundle.error.<code>` keys are requested under IWP-L once the backend defines the codes.

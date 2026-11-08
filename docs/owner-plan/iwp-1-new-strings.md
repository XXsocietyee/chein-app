# IWP-1 strings (not added to any catalog)

No `Resources/*.xcstrings` key was added. All user-facing text in `App/BundleCancelCanceler.swift` and `App/BundleCancelView.swift` uses inline `W8Text.t(zh, en)` with `Text(verbatim:)`, the same mechanism `Core/FreeExploreCancelFlow.swift` already uses. If the owner wants catalog keys instead, these are the strings (zh / en):

| Where | zh | en |
|---|---|---|
| quote, CANCELLED | 可免费取消（服务器规则：开始前 N 小时） / 可免费取消 | Free cancellation (server rule: N hours before start). / Free cancellation. |
| quote, LATE_CANCELLED | 已过免费取消时间，本次将按迟到取消处理，不免费 | Past the free-cancel window. This counts as a late cancellation, not a free one. |
| quote, WAIVED | 将使用本月的豁免次数取消 | This will use this month's waiver. |
| quote, unknown outcome | 服务器结果：X | Server result: X |
| BUNDLE_CANCEL_QUOTE_CHANGED | 取消条件已变化，请重新确认 | The cancellation terms changed. Please review them again. |
| BUNDLE_WAIVER_USED | 本月豁免次数已用完 | This month's waiver has already been used. |
| LOGIN_REQUIRED | 请先登录后再取消 | Please sign in before cancelling. |
| 401 | 登录已过期，请重新登录 | Your session expired. Please sign in again. |
| view | 使用本月豁免次数 / 查看取消结果 / 确认取消 / 返回 / 预约已取消（S） / 正在等待服务器确认，请勿重复提交 / 刷新状态 / 暂未开放 / 取消预约 | Use this month's waiver / Check cancellation / Confirm cancellation / Back / Reservation cancelled (S). / Waiting for the server to confirm. Please don't submit again. / Refresh status / Not available yet / Cancel reservation |

N = server `BundlePolicy.freeCancelHours`; X = server `outcome`; S = server reservation status.

# IWP-7 new strings

No `.xcstrings` edits were made. `App/BundleAppealView.swift` and `Core/BundleAppealModel.swift` use inline `W8Text.t(zh, en)` copy
(existing pattern, no catalog keys). If the orchestrator wants catalog keys (IWP-L), these are the strings:

| zh | en |
|---|---|
| 申诉原因 / 商家忘记核销 / 其他 | Reason / Merchant forgot to scan / Other |
| 补充说明（最多500字） | Note (up to 500 characters) |
| 已附证据 n/6 | Evidence attached n/6 |
| 提交后将进入审核，审核结果以服务器为准；提交不代表已退款或已核销。 | Your appeal will be submitted for review. The outcome is decided by the server; submitting does not refund or redeem anything. |
| 提交申诉 | Submit appeal |
| 已提交，等待审核 | Submitted for review |
| 审核已通过，处理结果以服务器状态为准 | Review approved. The result will appear once the server applies it. |
| 审核未通过 / 已撤回 / 已提交，状态更新中 | Not approved / Withdrawn / Submitted. Status is being updated. |
| 未能确认是否已提交，请先查询结果。 / 查询提交结果 | We couldn't confirm whether it was submitted. Check the result first. / Check result |
| 暂未查到该申诉。可以再次查询，或使用同一申请重新提交。 / 再次查询 / 重新提交同一申诉 | No record yet. Check again, or send the same appeal again. / Check again / Send the same appeal again |
| 服务器未接受这次申诉。 | The server did not accept this appeal. |
| 请先登录后再试，已保存的申诉不会丢失。 | Sign in and try again. Your saved appeal is kept. |
| 无法在本机保存申诉，未发送。 | Couldn't save the appeal on this device. Nothing was sent. |
| 申诉功能暂不可用。 | Appeals aren't available yet. |
| 内容不符合要求，请检查后重试。 | Please check the details and try again. |

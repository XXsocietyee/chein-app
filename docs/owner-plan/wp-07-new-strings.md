# WP-07 new strings (to be added by orchestrator to Resources/OpsSafety.xcstrings)

| Key | Table | en | zh-Hans |
|---|---|---|---|
| `opsSafety.pay.noAutoFunds` | OpsSafety | No payment or deduction happens automatically. Funds move only after you confirm a payment yourself. | 不会自动付款或扣款；只有你亲自确认支付后才会扣款。 |

Notes: no existing key covers the "no auto funds" clause (searched all Resources). The shop NPC screen has no pay action, so `SafetyDisclosureBanner` never renders this key there; it is only rendered if a caller sets `hasPayAction: true`. Wording is a proposal for owner/legal review.

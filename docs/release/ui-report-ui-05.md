# UI-05 report — Wallet / points / ledger (NOT COMPILED)

Theme: dark (player surface). Presentation only; no logic, contract or routing changes.

| Screen file | What changed | Follows | Theme | New string keys |
|---|---|---|---|---|
| App/WalletCommerceViews.swift `WalletCommerceHomeView` | Balance shown as a Revolut-style hero: caption label + large tabular `CYTypography.data2XL` figure (scales down, single line, privacy-sensitive). Identifier `wallet.earnings.balance` kept. | Mini-program 账户收益 balance hero + Revolut balance pattern | dark | none (reuses `withdrawal.support.balance`) |
| App/WalletCommerceViews.swift `WalletLedgerView.ledgerRow` | Amounts use `CYTypography.numericBody`; inflow uses `CYColor.successText`, balance-after uses `CYColor.textTertiary`; source badge uses `CYColor.accentSoft` (token instead of system accent/green). | Revolut transaction list | dark | none |

## Not done
- No new `#Preview` added: the views need `WalletCommerceReader` / service fixtures that cannot be built safely without compiling.
- Orders, refunds and withdrawal-history screens were not restyled (time-boxed; only wallet home and ledger rows touched).
- Role theme forcing is UI-01's job; not touched here.

Files touched: 1 (+ this report). New component files: 0. New string keys: 0.

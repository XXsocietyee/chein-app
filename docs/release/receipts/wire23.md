# wire23

[x] 3236cb774fcf88b8ff1602317be007bb6eaff999

PR 1017. Branch `cursor/wire23`. Base `rc/20261108`. +51/−0.

`MerchantAftercareProgressView` reads `MerchantAftercareDetailPage.load(amount:)`. The amount is `progress.amount.raw`. A missing amount is an em dash. A literal `0` stays `0`. The policy version is not announced. The copy button is unchanged. Not merged to rc.

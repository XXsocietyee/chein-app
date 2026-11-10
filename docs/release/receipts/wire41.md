# wire41

[x] 945dda747ab30713367cd7114f0cd023b2d963f7

PR 1029. Branch `cursor/wire41`. Base `rc/20261108`. +107/−8.

Insight counts use `MerchantMarketingValue.integer`. A JSON number 0 and a numeric string `"0"` stay `0`. Missing, null, bool, and non-numeric values stay an em dash. The marketing board is not in the diff. Not merged to rc.

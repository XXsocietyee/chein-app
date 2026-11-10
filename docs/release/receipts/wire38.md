# wire38

[x] 539af654b6ae814394510dfd71c02b7651bde1fa

PR 1025. Branch `cursor/wire38`. Parent `a9b89c901`. Base `rc/20261108`. +55/−2.

`MerchantHomeView` reads `MerchantHomePage.project`. A missing pending count is an em dash. A literal 0 stays 0 and the existing row still appears only when the count is greater than 0. Scan and the verify row stay hidden when that capability is absent. The view change is +20/−2. Not merged to rc.

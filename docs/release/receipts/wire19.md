# wire19

[x] f1868e9dcaf02436c0bba13344a76fd67d7aff0b

PR 1015. Branch `cursor/wire19`. Base `rc/20261108`. +307/−0.

`NearbyMerchantView` reads `NearbyMerchantPage.resolve`. The page total is an em dash when the read is missing and `0` when the loaded list is empty. A literal distance of 0 stays 0. The distance line keeps the meter suffix and stays hidden when distance is missing. The count is not prefixed onto that line. Not merged to rc.

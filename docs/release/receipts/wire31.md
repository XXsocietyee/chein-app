# wire31

[x] d136c4bad5696c56782be880a85824ee10d29664

PR 1022. Branch `cursor/wire31`. Parent `a9b89c901`. Base `rc/20261108`. +549/−5.

The customer roster in `App/MerchantBusinessViews.swift` reads `MerchantCustomerRosterPage.project`. A missing count is an em dash. A present empty list stays 0. A literal integer 0 stays 0. The roster stays hidden when the read was not granted. Other queries in the file are left visible. Not merged to rc.

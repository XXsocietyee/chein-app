# Compile errors in App/MPGap on ui/combined-r7 (Xcode 27.1, 14:49 UTC)

App/MPGap is excluded from the app target until these are fixed (tools/generate_project.py). Core/MPGap compiles and is included.
Fix on your gap/* branch after merging origin/ui/combined-r7; check every API you call against origin/ui/combined-r7 (CYSheetHeader takes Text; CYCachedAsyncImage(_ source: String?, role:); CYColor has no accent/warning: see App/DesignSystem; CYAvatar takes name: and size: CYAvatarSize).

```
App/MPGap/AccountPublish/AccountPublishGapRemainingViews.swift:159:33: error: extraneous argument label 'verbatimTitle:' in call
App/MPGap/AccountPublish/AccountPublishGapRemainingViews.swift:161:68: error: cannot convert value of type 'String' to expected argument type 'LocalizedStringKey'
App/MPGap/AccountPublish/AccountPublishGapViews.swift:19:50: error: type 'CYColor' has no member 'accent'
App/MPGap/AccountPublish/AccountPublishGapViews.swift:251:13: error: static method 'buildExpression' requires that 'some View' conform to 'TableRowContent'
App/MPGap/Club/ClubGapManageExtensions.swift:172:47: error: missing argument for parameter 'name' in call
App/MPGap/Club/ClubGapManageExtensions.swift:172:68: error: extra argument 'fallbackText' in call
App/MPGap/Club/ClubGapManageExtensions.swift:172:80: error: cannot convert value of type 'Double' to expected argument type 'CYAvatarSize'
App/MPGap/Club/ClubGapRemainingViews.swift:181:50: error: type 'CYColor' has no member 'warning'
App/MPGap/Club/ClubGapRemainingViews.swift:31:32: error: failed to produce diagnostic for expression; please submit a bug report (https://swift.org/contributing/#reporting-bugs)
App/MPGap/Member/MemberRound2Views.swift:112:39: error: extraneous argument label 'url:' in call
App/MPGap/Member/MemberRound2Views.swift:112:45: error: cannot convert value of type 'URL' to expected argument type 'String'
App/MPGap/Member/OrientScoreGapViews.swift:22:34: error: cannot convert value of type 'String' to expected argument type 'Text'
App/MPGap/Member/OrientScoreGapViews.swift:88:34: error: cannot convert value of type 'LocalizedStringKey' to expected argument type 'Text'
App/MPGap/Member/ReportAppealAndCouponSummaryViews.swift:184:34: error: cannot convert value of type 'LocalizedStringKey' to expected argument type 'Text'
App/MPGap/Member/ReportAppealAndCouponSummaryViews.swift:32:34: error: cannot convert value of type 'LocalizedStringKey' to expected argument type 'Text'
App/MPGap/MerchantCoop/MerchantGapOperationsViews.swift:172:62: error: type 'CYColor' has no member 'accent'
App/MPGap/MerchantCoop/MerchantGapRemainingViews.swift:103:46: error: type 'CYColor' has no member 'accent'
App/MPGap/MerchantCoop/MerchantGapRemainingViews.swift:17:17: error: generic parameter 'C' could not be inferred
App/MPGap/MerchantCoop/MerchantGapRemainingViews.swift:17:25: error: cannot convert value of type '[MerchantWorkbenchProjectCard]' to expected argument type 'Binding<C>'
App/MPGap/MerchantCoop/MerchantGapRemainingViews.swift:19:46: error: cannot convert value of type 'Binding<Subject>' to expected argument type 'Int'
App/MPGap/MerchantCoop/MerchantGapRemainingViews.swift:23:53: error: cannot convert value of type 'Binding<Subject>' to expected argument type 'String'
App/MPGap/PlayRoam/CityStampTearScratchCardView.swift:113:35: error: extraneous argument label 'url:' in call
App/MPGap/PlayRoam/CityStampTearScratchCardView.swift:113:41: error: cannot convert value of type 'URL' to expected argument type 'String'
App/MPGap/PlayRoam/ObjectCardCategoryAndRenameSheets.swift:27:34: error: cannot convert value of type 'String' to expected argument type 'Text'
App/MPGap/PlayRoam/ObjectCardCategoryAndRenameSheets.swift:82:34: error: cannot convert value of type 'String' to expected argument type 'Text'
App/MPGap/PlayRoam/PlayRoamRound2Views.swift:125:51: error: extraneous argument label 'url:' in call
App/MPGap/PlayRoam/PlayRoamRound2Views.swift:125:57: error: cannot convert value of type 'URL' to expected argument type 'String'
App/MPGap/PlayRoam/PlayRoamRound2Views.swift:184:34: error: cannot convert value of type 'String' to expected argument type 'Text'
App/MPGap/PlayRoam/PlayRoamRound2Views.swift:49:55: error: extraneous argument label 'url:' in call
App/MPGap/PlayRoam/PlayRoamRound2Views.swift:49:61: error: cannot convert value of type 'URL' to expected argument type 'String'
App/MPGap/PlayRoam/PlayRoamRound2Views.swift:49:73: error: type 'CYCachedAsyncImageRole' has no member 'thumbnail'
```

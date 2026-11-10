# pages/topic/index/index PAGE-READY

CB256. 主题详情页. Native `App/TopicDetailView.swift`. Map status stays exists. No route was added or marked live.
Model: `POST api/topic/info-to-user` is decoded by `TopicDetail` and read by `TopicService.detail`. Vote, route map, share card, points banner, marketing consent, and theme replay stay hidden.
States already on rc: loading (`topic.loading`, records loading), empty (tickets, chapters, activities, reviews, route, records, sessions), error (`TopicReadFailure.unavailable`, notConfigured, unauthorized, unavailable, failed, records failed).
UNKNOWN: missing locationCount, price, commentCount, seat remaining, and theme-card quantity stay nil, never 0. A literal 0 stays 0. This lane changes only node-template minutes: a missing duration is an em dash (—). A duration of 0 stays "0".
Missing EN+zh-Hans keys: none. Every catalog lookup on this page has a non-empty en value and a non-empty zh-Hans value in `Resources/Localizable.xcstrings`.
Tests: `TopicXcxNodeFactsTests.testNodeTemplatesKeepRouteOrderAndFirstOccurrence` still asserts "0" and now asserts "—". Not executed (no Swift toolchain). xcodebuild was not run. No Xcode Cloud result.
Left: `TopicXcxFacts.duration(nil)` remains `.zero` because `topicXcx.duration.zero` is "0 h" / "0时" and a new case needs a view edit; the detail row is omitted when `totalTimeSeconds` is nil. `TopicDetailView` treats a nil `commentCount` plus an empty preview as the empty-review prompt. `TopicThemeCardView` leaves a nil quantity blank. `topicXcx.route.emptyDetail` and `topicXcx.nodes.emptyDetail` exist and are unused. Unknown `productType` is stored as 0 and the hero labels it orienteering.
Not edited: `App/**/*View*.swift`, ui-strings JSON, `Localizable.xcstrings`, the xcodeproj, `tools/current_ci_manifest.json`. `showsMerchantChoice` and the money switches stay false. No US URL or secret. The current CI ledger stays stale until a refresh outside this lane.

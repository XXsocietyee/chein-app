# CB246 pages/club/event-ops/index
Status: already complete on rc/20261108. Map status exists. Native screen App/ClubOpsEventView.swift. No Core or test change.
Contract already wired: access/me, event topics, series list/detail, occurrences, occurrence status, roster, series create/update. Missing original-result, door check-in, and proxy-enroll stay hidden and are not marked live. No new route. Kept off the player-first entry.
Permission: manage shows occurrence, series, recurrence, and capacity; check-in needs an activity and shows roster only. A manager without check-in keeps the roster hidden. Hub capacity has no control.
Writes: cancel-occurrence and attendance correction stay ClubOpsEventWriteGate.notAvailableYet in production and send nothing. showsMerchantChoice and the money switches stay false.
States: hub loading, denied, and error with retry. Empty series, empty occurrence list, and empty roster bucket. Signup or refund UNKNOWN is pending or omitted, never stored or shown as 0. A literal JSON 0 stays 0.
Tests already present: ClubOpsEventPresentationTests and ClubOpsEventWriteGateTests, plus roster, occurrence, and schedule draft tests. None deleted or weakened. xcodebuild was not run. No Xcode Cloud result is claimed.
Missing EN+zh-Hans keys: club.schedule.error.futureOnly (both languages absent). ClubSeriesScheduleDraft.Issue.futureOnly builds that key. The screen shows club.schedule.futureOnly, which has EN and zh-Hans in Resources/ClubSeriesSchedule.xcstrings.
Other event-ops keys in ClubOpsEvent.xcstrings, Localizable.xcstrings, and ClubSeriesSchedule.xcstrings already have both EN and zh-Hans, including loading, empty, error, and pending-count copy.
Left: leave the missing key untranslated in this lane, leave production cancel and attendance gated, and do not invent a route.

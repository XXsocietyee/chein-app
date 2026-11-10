# pages/club/enroll/index

CB244 page-ready on `rc/20261108`. `App/ClubEnrollmentView.swift` is unchanged. The roster still reads the existing `api/club/topics` and `api/club/topic-registrations` contracts through `ClubEnrollmentReader`. No route was added, and none was marked live. A missing `club:member:list:read` grant still clears the roster and stays hidden. `showsMerchantChoice`, payment, payout, withdrawal, and virtual-goods switches were not set true.

`ClubEnrollmentDecode.count` no longer reads counts through `ClubGovernanceValue.int`. Null, a missing number, the token `UNKNOWN`, and a numeric string (including `"0"`) stay nil and display as U+2014 (`—`). A literal JSON `0` stays `0`. An accepted empty topic list is empty, with loading off and no error. Loading and error were already separate on the reader.

## Missing EN+zh-Hans keys

None. Every `club.enroll.*` key the screen uses, including `club.enroll.checkin.unknown`, `club.enroll.checkin.pending`, `club.enroll.checkin.done`, and `club.enroll.teamStatus.0`, `.1`, and `.2`, already has both `en` and `zh-Hans` in `Resources/Localizable.xcstrings`. `club.enroll.unknown` is already `—` in both languages. `club.enroll.emptyTeamsHint`, `club.enroll.readOnly`, and `club.enroll.refundUnavailable` are also present in both languages. The error rows use existing `club.gov.*` keys, which have both languages.

## Left

The view still hides a literal capacity of `0` behind `club.enroll.registrants`, and it does not show `club.enroll.emptyTeamsHint`. `ClubEnrollmentReader.formatPaymentRefundSummary` still says `待确认` for a nil refundable count; that sentence stays, because `ClubDetailTabTests` locks it. The count row uses the em dash. Map status stays `exists`. No Xcode build was run, and no Xcode Cloud result is claimed.

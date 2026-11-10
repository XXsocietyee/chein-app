# pages/activity/official-inbox/index

CB213 page-ready evidence. Map status stays `exists` (`App/OfficialPrivateViews.swift`). No view file was edited.

- The read `api/official/v2/party-inbox` is already live in `ChinaReviewedRouteCapability` and already called by `OfficialEventService.partyInbox`. This lane does not add a route or change that mark.
- `OfficialInboxPageModel` projects that read into loading, empty, error, unknown, and ready. A path this repo marks missing stays hidden. Unknown counts use an em dash and are not stored as 0.
- `OfficialPartyInvite.capacityFact` keeps a literal JSON 0 as 0. Null, a missing value, a numeric string, and `UNKNOWN` display as an em dash. The existing positive `capacity` field is unchanged.
- EN and zh-Hans keys, plus accessibility identifiers, are in `docs/release/ui-strings-pages-activity-official-inbox-index.json`.
- DEBUG fixture bytes are `OfficialInboxFixtureData` in `Core/OfficialEventSyntheticFixtures.swift`, next to the existing `inboxJSON`.
- Tests: `Tests/CoreTests/OfficialInboxPageReadyTests.swift` and `Tests/ContractChecks/test_official_inbox_page_ready.py`.
- Left: binding the new phase and capacity fact in the inbox view, organizer-invite writes (`/api/official/v2/organizer-invites/{}/{}` is still missing and stays hidden), and any Xcode run.

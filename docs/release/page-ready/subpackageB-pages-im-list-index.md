# CB229 page-ready · subpackageB/pages/im/list/index

`rc/20261108` already loaded `api/im/conversations` and mapped kinds 1 direct, 2 system, 3 merchant, 4 group, else unknown. It had no page model that keeps a missing unread count unknown.

Evidence added on this branch:

- `IMListPageReady` and `IMListPageCoordinator` in `Core/IMInbox.swift`. The coordinator calls the existing `MessagingReading.messagingConversations` read. Loading, empty, error, and unknown are separate. Unknown counts are an em dash. A literal 0 stays 0. An empty list is the known count 0.
- `IMListPageReadyTests` and `IMListPageReadyLoadTests` in `Tests/CoreTests/IMInboxTests.swift`.
- `docs/release/ui-strings-subpackageB-pages-im-list-index.json` (en, zh-Hans, accessibility identifiers).
- DEBUG `IMListFixtureData` in `Core/IMInbox.swift`.

Left: `App/MessagingHomeView.swift` is unchanged and still owns the screen. Read-all, Square, and the coop-invite strip stay hidden unless a grant that already exists is passed in. No route was marked live. The page stays partial.

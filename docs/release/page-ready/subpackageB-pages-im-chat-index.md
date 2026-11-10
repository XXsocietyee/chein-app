# PAGE-READY `subpackageB/pages/im/chat/index`

CB230 on `rc/20261108`. Screen stays `App/MessagingHistoryView.swift` (map status partial). No view file was edited.

- Model and coordinator: `Core/MessagingHistory.swift` (`IMChatSessionPage`, `IMChatSessionCoordinator`). The read is the existing `MessagingReading.messagingMessages` contract (`POST api/im/messages`). Send, automatic `/api/im/read`, and polling stay hidden. No route was added or marked live.
- Phases are hidden, loading, empty, error, unknown, and ready. Unknown counts display as an em dash (`—`). A literal JSON 0 stays 0. Kinds stay 1 direct, 2 system, 3 merchant, 4 group, otherwise unknown.
- Tests: `Tests/CoreTests/IMChatSessionPageTests.swift`. Existing messaging tests were not changed.
- Strings: `docs/release/ui-strings-subpackageB-pages-im-chat-index.json` (EN, zh-Hans, accessibility identifiers).
- DEBUG fixture: `IMChatSessionFixtureData` in `Core/MessagingHistory.swift`.

Left: the history view still keeps its own loading flags and does not call this coordinator. `Questify.xcodeproj` was not edited. `swift test` was not run here because no Swift toolchain is installed. Send, read-receipt, and poll writes remain dormant.

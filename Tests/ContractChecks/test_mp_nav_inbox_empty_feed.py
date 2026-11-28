"""mp-nav r3: MP im/list onEmptyCta (index.js:345-349) switches to 俱乐部 on the 帖文 feed; the session inbox follows it."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class InboxEmptyFeedChecks(unittest.TestCase):
    def test_session_inbox_switches_to_club_feed(self):
        entry = (ROOT / "App/SessionMessagingEntry.swift").read_text()
        home = entry.split("struct SessionMessagingHome", 1)[1].split("struct SessionMessagingToolbarEntry", 1)[0]
        self.assertIn("emptyFeedAction: openDiscoverFeed", home)
        self.assertNotIn("SessionSquareBrowserView", home)
        action = home.split("func openDiscoverFeed()", 1)[1]
        self.assertIn('MiniProgramPageLink(path: "pages/talent/list/index", query: ["tab": "feed"])', action)
        self.assertLess(action.index("dismiss()"), action.index("session.receiveNativeIntent(.miniProgramPage(link))"))

    def test_empty_cta_prefers_feed_action_over_push(self):
        view = (ROOT / "App/MessagingHomeView.swift").read_text()
        self.assertIn("squareDestination != nil || emptyFeedAction != nil", view)
        self.assertIn("if let emptyFeedAction { emptyFeedAction(); return }", view)


if __name__ == "__main__":
    unittest.main()

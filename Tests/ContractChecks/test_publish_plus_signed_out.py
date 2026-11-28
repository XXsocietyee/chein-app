"""Function audit 11-28 P2-6 (mp-publish): signed out, the 发布 tab “+” asks for sign-in instead of a dead toast.

MP `components/tabBar/index.js:88-93` `openPublishSheet` → `app.ensureLoginFor('publish', …)` before the sheet opens.
"""
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


class PublishPlusSignedOutTests(unittest.TestCase):
    def test_signed_out_plus_opens_login(self):
        text = (ROOT / "App/PublishTabRootView.swift").read_text(encoding="utf-8")
        self.assertIn("if session.isSignedIn {\n                        publishMenu", text)
        self.assertIn("signInPublishButton", text)
        self.assertIn("LoginView(intent: .player)", text)
        self.assertIn('"publishTab.publish.signIn"', text)


if __name__ == "__main__":
    unittest.main()

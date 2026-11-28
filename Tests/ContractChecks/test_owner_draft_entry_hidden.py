"""Function audit 11-28 P2-6c (mp-publish): the 内容草稿 row shows only when a draft reader exists.

The MP has no content-draft page; Release has no `ownerDraftReadApproval`, so the row used to open
a dead "not configured" page (P27: render nothing for a gated feature).
"""
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


class OwnerDraftEntryHiddenTests(unittest.TestCase):
    def test_entry_requires_browser(self):
        text = (ROOT / "App/OwnerDraftBrowserView.swift").read_text(encoding="utf-8")
        head = text.split("struct OwnerDraftDestination", 1)[0]
        self.assertIn("if let browser {", head)
        self.assertIn('"account.ownerDrafts"', head)


if __name__ == "__main__":
    unittest.main()

"""Static guards for the accessibility and hardening wave (FP-A1..A6, FP-M5..M7, FP-M12, FP-X1)."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def src(path):
    return (ROOT / path).read_text()


class FPA1IconOnlyButtons(unittest.TestCase):
    def test_h5_close_is_labelled_and_44pt(self):
        s = src('App/H5PlatformShellView.swift')
        self.assertIn('Label("action.close", systemImage: "xmark").labelStyle(.iconOnly)', s)
        self.assertIn('minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget', s)
        self.assertNotIn('Button(action: onClose) { Image(systemName: "xmark") }', s)

    def test_story_rule_move_up_is_labelled_and_44pt(self):
        s = src('App/StoryRuleEditorView.swift')
        self.assertIn('Label(ChannelCopy.text("上移", "Move up", locale: locale), systemImage: "arrow.up")', s)
        self.assertIn('.labelStyle(.iconOnly)', s)
        self.assertIn('minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget', s)
        self.assertNotIn('Image(systemName: "arrow.up")', s)


class FPA2HomeSearchAndPublish(unittest.TestCase):
    def test_publish_button_uses_tokens_and_44pt(self):
        s = src('App/HomeSearchTabParityViews.swift')
        body = s[s.index('struct PublishTabFloatingButton'):s.index('struct PublishTabFloatingSheetView')]
        self.assertIn('.foregroundStyle(CYColor.textOnAccent)', body)
        self.assertNotIn('.foregroundStyle(.white)', body)
        self.assertIn('.frame(minHeight: CYSpacing.minTouchTarget)', body)
        self.assertNotIn('.padding(.vertical, 10)', body)

    def test_search_entry_has_search_trait_and_wraps(self):
        s = src('App/HomeSearchTabParityViews.swift')
        entry = s[s.index('GlobalSearchParityPresentation.placeholderCopy'):s.index('"homeIndex.hero.searchEntry"')]
        self.assertIn('.lineLimit(2)', entry)
        self.assertNotIn('.lineLimit(1)', entry)
        self.assertIn('.accessibilityAddTraits(.isSearchField)', entry)


if __name__ == '__main__':
    unittest.main()

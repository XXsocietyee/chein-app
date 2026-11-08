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


if __name__ == '__main__':
    unittest.main()

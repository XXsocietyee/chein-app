"""mp-nav r3 (B lane): topic bar 编辑 is a push (MP navigateTo pages/publish/fabu/index), not a full-detent sheet."""
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


class TopicEditorPushChecks(unittest.TestCase):
    def test_editor_is_pushed_with_system_back(self):
        source = (ROOT / 'App/TopicDetailView.swift').read_text()
        self.assertIn('.navigationDestination(isPresented: $showsEditor) {', source)
        self.assertNotIn('.cySheet(isPresented: $showsEditor)', source)
        self.assertNotIn('NavigationStack { editorDestination(value.id, scope) }', source)
        self.assertIn('showingPlay = false; showsEditor = false }', source)


if __name__ == '__main__':
    unittest.main()

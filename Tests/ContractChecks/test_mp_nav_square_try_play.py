"""mp-nav r3 (B lane): MP square/detail 试玩 (`goPlay`, index.js:186-193) opens pages/play/index?topicId= directly."""
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


class SquareTryPlayChecks(unittest.TestCase):
    def text(self, path):
        return (ROOT / path).read_text()

    def test_play_card_pushes_play_when_the_session_supplies_it(self):
        detail = self.text('App/SquareDetailView.swift')
        self.assertIn('reader: reader) { openPlay($0) }', detail)
        self.assertIn('if playDestination != nil { playTopic = selected } else { relatedTopic = selected }', detail)
        self.assertIn('.modifier(SquarePlayPushModifier(selection: $playTopic, squareReader: reader))', detail)
        self.assertIn('.onChange(of: key) { _, _ in playTopic = nil }', detail)

    def test_play_push_is_fenced_by_both_read_scopes(self):
        view = self.text('App/SquareRelatedTopicView.swift')
        self.assertIn('static let defaultValue: ((Int) -> AnyView)? = nil', view)
        self.assertIn('selected.isCurrent(squareScope: squareReader.scope, topicScope: context.reader.scope)', view)
        self.assertIn('playDestination(selected.route.topicID)', view)

    def test_session_root_supplies_the_topic_play_page(self):
        root = self.text('App/QuestifyApp.swift')
        self.assertEqual(root.count('.environment(\\.squarePlayDestination,'), 1)
        self.assertIn('SessionPlayRuntimeView(session: session, destination: .journey(.topic(topicID)))', root)


if __name__ == '__main__':
    unittest.main()

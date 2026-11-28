"""K40 publish/create: 用这个模板 opens the professional editor from every session shelf and from search.

The 发布 tab already injected `topicEditorDestination` (P1-26). Home search, a sheet-hosted shelf and square
看看模板 still pushed a blank page because that destination was missing. The create menu's AI row stays first.
"""
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


def text(path):
    return (ROOT / path).read_text(encoding="utf-8")


class K40PublishCreateTests(unittest.TestCase):
    def test_session_root_opens_the_fabu_editor(self):
        root = text("App/QuestifyApp.swift")
        self.assertIn(
            ".environment(\\.topicEditorDestination, PublishTabRootView.topicEditorDestination(session: session))",
            root,
        )

    def test_session_shelf_and_search_inject_the_same_editor(self):
        shelf = text("App/DiscoveryTemplateBrowserView.swift")
        self.assertIn("SessionShelfTopicEditor(reader: reader)", shelf)
        self.assertIn("reader as? AppSession", shelf)
        self.assertIn("PublishTabRootView.topicEditorDestination(session: session)", shelf)
        search = text("App/GlobalSearchLinksAndTemplates.swift")
        self.assertIn(
            ".environment(\\.topicEditorDestination, PublishTabRootView.topicEditorDestination(session: session))",
            search,
        )

    def test_square_use_template_falls_back_to_the_editor(self):
        card = text("App/SquareDetailView.swift")
        self.assertIn("copiedDraft = CopiedTopicDraft(id: topicID)", card)
        self.assertIn("editorDestination(draft.id, nil)", card)

    def test_create_menu_keeps_the_ai_row_first(self):
        menu = text("App/PublishingModesViews.swift")
        ai = menu.find('.accessibilityIdentifier("publishModes.ai")')
        free = menu.find('.accessibilityIdentifier("publishModes.pro.freeExplore")')
        self.assertGreater(ai, 0)
        self.assertGreater(free, ai)
        self.assertIn("SessionAICreationHubView()", menu[:ai])

    def test_merchant_scope_stays_gated_on_the_editor_query(self):
        query = text("App/PublishTabRootView.swift")
        self.assertIn('scope != "MERCHANT" || PlayerLaunch.merchantCenterEnabled', query)


if __name__ == "__main__":
    unittest.main()

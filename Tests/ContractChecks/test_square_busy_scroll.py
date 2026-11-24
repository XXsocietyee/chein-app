from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[2]
class SquareBusyScrollTests(unittest.TestCase):
    def test_busy_state_disables_all_form_content_but_not_scroll_container(self):
        view=(ROOT/'App/SquareWorkspaceView.swift').read_text()
        form=view.split('var body: some View {',1)[1].split('.task(id: initialPostID)',1)[0]
        # Native restyle R1 (owner-approved): the in-content hero title became the system inline navigation title.
        # The busy-state rule is unchanged: the disabled group sits inside the Form, never on the scroll container.
        self.assertIn('Form {\n            Group {', form)
        self.assertIn('}.disabled(coordinator.busy || (initialPostID != nil && !editReady))\n        }\n        .cyPageTitle("squareWorkspace.title")', form)
        self.assertNotIn('.cyPageTitle("squareWorkspace.title")\n        .disabled', form)
        tests=(ROOT/'Tests/AppUITests/SquareWorkspaceFlowTests.swift').read_text()
        self.assertIn('requiresHittable: false', tests)
        self.assertIn('attachFailureScreenshot(self, app: activeApp)', tests)
        self.assertIn('XCTAttachment(string: app.debugDescription)', tests)
        self.assertIn('XCTAssertFalse(editor.isEnabled, app.debugDescription)', tests)
        self.assertIn('"Saved first recovery draft"', tests)
if __name__=='__main__': unittest.main()

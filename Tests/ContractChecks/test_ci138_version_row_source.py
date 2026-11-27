"""Project editor version row: MP-first decision (debt-r3). Source checks are not Apple runtime acceptance.

The mini-program keeps `baseRevision` only as hidden save state (origin/mp-source
chengyinhub-xcx/pages/publish/fabu/index.js: data.baseRevision, sent with the save request) and renders it in no
.wxml. So the native editor shows no remote version row either; the revision still travels with the save.
The old byte inverse of the run138 mount (ProjectRemoteVersionRow inside ProjectEditView) was retired.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def violations(editor, ui_test):
    errors = []
    if 'ProjectRemoteVersionRow(' in editor or '"projectRemote.version"' in editor:
        errors.append('editor_shows_version_row')
    if 'draft.baseRevision' not in editor:
        errors.append('revision_not_carried')
    if 'XCTAssertFalse(app.staticTexts["projectRemote.version.value"].exists)' not in ui_test:
        errors.append('ui_test_expects_version_row')
    return errors


class VersionRowSourceChecks(unittest.TestCase):
    def sources(self):
        return ((ROOT / 'App/ProjectEditView.swift').read_text(),
                (ROOT / 'Tests/AppUITests/ProjectOwnedEditorFlowTests.swift').read_text())

    def test_editor_follows_mp_and_shows_no_version_row(self):
        self.assertEqual(violations(*self.sources()), [])

    def test_mount_or_lost_revision_is_rejected(self):
        editor, ui = self.sources()
        self.assertIn('editor_shows_version_row',
                      violations(editor + '\nProjectRemoteVersionRow(revision: model.draft.baseRevision)\n', ui))
        self.assertIn('revision_not_carried', violations(editor.replace('draft.baseRevision', 'draft.other'), ui))
        self.assertIn('ui_test_expects_version_row', violations(editor, ui.replace('XCTAssertFalse(app.staticTexts["projectRemote.version.value"]', 'XCTAssertTrue(app.staticTexts["projectRemote.version.value"]')))


if __name__ == '__main__':
    unittest.main()

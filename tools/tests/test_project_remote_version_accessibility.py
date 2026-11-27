"""CI138 source regression only; Apple accessibility execution is still required."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
IDENTIFIER = 'projectRemote.version.value'


def separate_version_elements(source):
    """Reject the known merging shape, not simulate SwiftUI's runtime AX tree."""
    code = re.sub(r'//[^\n]*', '', source)
    return (
        'HStack(alignment: .firstTextBaseline)' in code
        and code.count('Text("projectRemote.version")') == 1
        and code.count('Text(verbatim: revision)') == 1
        and code.count(f'.accessibilityIdentifier("{IDENTIFIER}")') == 1
        and '.accessibilityElement(children: .contain)' in code
        and not any(value in code for value in (
            'LabeledContent', '.accessibilityLabel(', '.accessibilityValue(',
            '.accessibilityHidden(', '.hidden(', '.opacity(',
            'children: .combine', 'children: .ignore',
        ))
    )


class ProjectRemoteVersionAccessibilityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.row = (ROOT / 'App/ProjectRemoteVersionRow.swift').read_text()

    def test_field_name_and_unmodified_revision_are_separate_accessible_texts(self):
        self.assertTrue(separate_version_elements(self.row))
        self.assertIn('let revision: String', self.row)
        self.assertNotIn('fixture-r2', self.row)

    def test_identifier_belongs_only_to_the_verbatim_value(self):
        self.assertRegex(self.row, r'Text\(verbatim: revision\)\s+'
                         r'\.foregroundStyle\(\.secondary\)\s+'
                         r'\.multilineTextAlignment\(\.trailing\)\s+'
                         r'\.accessibilityIdentifier\("projectRemote\.version\.value"\)')
        self.assertEqual(self.row.count('.accessibilityIdentifier('), 1)
        self.assertLess(self.row.index('Text("projectRemote.version")'),
                        self.row.index('Text(verbatim: revision)'))

    def test_original_labeled_content_shape_is_rejected(self):
        original = '''LabeledContent("projectRemote.version") {
            Text(verbatim: revision).accessibilityIdentifier("projectRemote.version.value")
                .accessibilityLabel(Text(verbatim: revision))
        }.accessibilityElement(children: .contain)'''
        self.assertFalse(separate_version_elements(original))

    def test_combining_or_repeating_accessible_value_is_rejected(self):
        self.assertFalse(separate_version_elements(
            self.row.replace('children: .contain', 'children: .combine')))
        self.assertFalse(separate_version_elements(
            self.row.replace('.foregroundStyle(.secondary)',
                             '.accessibilityLabel(Text(verbatim: revision))')))

    def test_hiding_the_field_name_is_rejected(self):
        self.assertFalse(separate_version_elements(self.row.replace(
            'Text("projectRemote.version")',
            'Text("projectRemote.version").accessibilityHidden(true)')))

    def test_ui_journey_follows_mp_and_expects_no_version_row(self):
        # debt-r3: MP fabu/index.js keeps baseRevision hidden (no .wxml renders it); the row is not mounted.
        ui = (ROOT / 'Tests/AppUITests/ProjectOwnedEditorFlowTests.swift').read_text()
        self.assertIn('XCTAssertFalse(app.staticTexts["projectRemote.version.value"].exists)', ui)
        self.assertNotIn('ProjectRemoteVersionRow(', (ROOT / 'App/ProjectEditView.swift').read_text())


if __name__ == '__main__':
    unittest.main()

import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


class SettingsSupportSafetyEntry(unittest.TestCase):
    def test_settings_lists_the_entry_and_it_is_in_the_app_target(self):
        self.assertIn('SettingsSupportSafetyEntry()', (ROOT / 'App/SettingsView.swift').read_text())
        project = (ROOT / 'Questify.xcodeproj/project.pbxproj').read_text()
        self.assertEqual(len(re.findall(r'SettingsSupportSafetyEntry\.swift', project)), 1)
        ids = re.findall(r'"([0-9A-F]{24})" = \{\n\t\t\t"isa" = "PBXFileReference";\n\t\t\t"lastKnownFileType" = "sourcecode.swift";\n\t\t\t"path" = "App/SettingsSupportSafetyEntry.swift"', project)
        self.assertEqual(len(ids), 1)
        self.assertGreaterEqual(project.count(ids[0]), 3, 'file reference, build file and group membership')

    def test_clause_is_bilingual_states_no_sla_and_invents_no_contact(self):
        source = (ROOT / 'App/SettingsSupportSafetyEntry.swift').read_text()
        self.assertIn('objectionable content', source)
        self.assertIn('令人反感的内容', source)
        self.assertNotRegex(source, r'24\s*(h|小时|hours)')
        self.assertNotRegex(source, r'[\w.]+@[\w.]+')
        self.assertNotIn('https://', source)

    def test_contact_comes_from_the_reviewed_support_reader(self):
        self.assertIn('WithdrawalSupportContactView()', (ROOT / 'App/SettingsSupportSafetyEntry.swift').read_text())


if __name__ == '__main__':
    unittest.main()

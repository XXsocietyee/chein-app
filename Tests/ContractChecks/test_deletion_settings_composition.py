import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


class DeletionSettingsComposition(unittest.TestCase):
    def test_settings_only_falls_back_when_no_coordinator(self):
        support = (ROOT / 'App/SettingsSupportSections.swift').read_text()
        self.assertRegex(support, r'if let complianceCoordinator \{\s*AccountComplianceSettingsSection\(')
        self.assertRegex(support, r'\} else \{\s*Section\("settingsNative\.privacy\.title"\) \{\s*ForEach\(SettingsUnavailableFeature\.allCases\)')

    def test_settings_view_passes_the_session_coordinator(self):
        view = (ROOT / 'App/SettingsView.swift').read_text()
        self.assertIn('complianceCoordinator: session.accountComplianceCoordinator', view)

    def test_coordinator_is_enabled_by_reviewed_china_gates_only(self):
        root = (ROOT / 'App/AppCompositionRoot.swift').read_text()
        self.assertRegex(root, r'var isAccountComplianceEnabled: Bool \{\s*reviewed\?\.productionGatesEnabled == true && reviewed\?\.regional\.market == \.china\s*\}')
        session = (ROOT / 'App/AppSession.swift').read_text()
        self.assertIn('readsEnabled: true, writesEnabled: true', session)
        self.assertIn('readsEnabled: false, writesEnabled: false', session)

    def test_reviewed_deployment_helper_turns_gates_on(self):
        launch = (ROOT / 'App/RegionalLaunchConfiguration.swift').read_text()
        self.assertIn('productionGatesEnabled: true', launch)


if __name__ == '__main__':
    unittest.main()

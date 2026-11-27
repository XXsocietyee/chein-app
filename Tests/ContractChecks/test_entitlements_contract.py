import pathlib
import plistlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


class EntitlementsContract(unittest.TestCase):
    GROUP = {'com.apple.security.application-groups': ['group.com.chengyinhub.chengyinApp']}

    def test_sign_in_with_apple_and_widget_app_group_only(self):
        plist = plistlib.loads((ROOT / 'Config/Questify.entitlements').read_bytes())
        self.assertEqual(plist, {'com.apple.developer.applesignin': ['Default'], **self.GROUP})

    def test_widget_extension_has_only_the_app_group(self):
        plist = plistlib.loads((ROOT / 'Config/QuestifyLiveActivity.entitlements').read_bytes())
        self.assertEqual(plist, self.GROUP)

    def test_app_target_sets_code_sign_entitlements(self):
        project = (ROOT / 'Questify.xcodeproj/project.pbxproj').read_text()
        hits = re.findall(r'"CODE_SIGN_ENTITLEMENTS" = "Config/Questify\.entitlements";', project)
        self.assertEqual(len(hits), 2, 'Debug and Release of the app target')
        widget = re.findall(r'"CODE_SIGN_ENTITLEMENTS" = "Config/QuestifyLiveActivity\.entitlements";', project)
        self.assertEqual(len(widget), 2, 'Debug and Release of the widget extension')
        self.assertEqual(len(re.findall(r'CODE_SIGN_ENTITLEMENTS', project)), 4, 'test targets must not set it')

    def test_no_associated_domains_or_url_types_invented(self):
        plist = (ROOT / 'Config/Questify.entitlements').read_text()
        self.assertNotIn('associated-domains', plist)


if __name__ == '__main__':
    unittest.main()

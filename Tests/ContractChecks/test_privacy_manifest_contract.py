"""FP-B4: the privacy manifest declares what the code provably collects.

Each row maps a data type to source evidence in the repo. The final list and the App Store Connect label are the
owner's decision (FP-O4); this check only stops the manifest from falling behind the code. Tracking stays off."""
import pathlib
import plistlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
PREFIX = 'NSPrivacyCollectedDataType'

# data type -> (file, snippet that proves the collection path exists)
EVIDENCE = {
    'PhoneNumber': ('Core/AuthChannelService.swift', 'phone'),
    'PreciseLocation': ('Config/Base.xcconfig', 'NSLocationWhenInUseUsageDescription'),
    'AudioData': ('Config/Base.xcconfig', 'NSMicrophoneUsageDescription'),
    'Name': ('Core/RegistrationContracts.swift', 'realName'),
    'EmailAddress': ('Core/RegistrationContracts.swift', 'email: String? = nil'),
    'PhysicalAddress': ('Core/ParticipantForm.swift', 'detailAddress'),
    'PurchaseHistory': ('Core/OrderLifecycleDormantAdapter.swift', 'api/registration/pay/app'),
    'Fitness': ('App/IPhonePedometerProvider.swift', 'CMPedometer'),
    'DeviceID': ('App/AppAttestStepAssertionProvider.swift', 'generateAssertion'),
    'SearchHistory': ('Core/MPGap/PlayerContent/PlayerContentRound2Service.swift', 'api/search/unified'),
    'GameplayContent': ('Core/PlayRuntimeGap.swift', 'api/play/run-session/save'),
    'CustomerSupport': ('Core/JourneyLoopSource.swift', '/api/play/feedback/submit'),
    'OtherDataTypes': ('Core/PublisherIdentityRegistration.swift', 'idCard'),
    'ProductInteraction': ('Core/AnalyticsEventClient.swift', 'actorScope: "member:\\(accountID)"'),
}


class PrivacyManifestContract(unittest.TestCase):
    def setUp(self):
        self.manifest = plistlib.loads((ROOT / 'Resources/PrivacyInfo.xcprivacy').read_bytes())
        self.declared = {item[PREFIX]: item for item in self.manifest['NSPrivacyCollectedDataTypes']}

    def test_tracking_stays_off(self):
        self.assertIs(self.manifest['NSPrivacyTracking'], False)
        self.assertEqual(self.manifest['NSPrivacyTrackingDomains'], [])

    def test_every_evidenced_collection_is_declared(self):
        for name, (path, snippet) in EVIDENCE.items():
            self.assertIn(snippet, (ROOT / path).read_text(), f'{name}: evidence moved, update the table')
            self.assertIn(PREFIX + name, self.declared, f'{name} is collected by {path} but not declared')

    def test_declared_entries_are_linked_untracked_app_functionality(self):
        for key, item in self.declared.items():
            self.assertIs(item['NSPrivacyCollectedDataTypeTracking'], False, key)
            self.assertIs(item['NSPrivacyCollectedDataTypeLinked'], True, key)
            self.assertEqual(item['NSPrivacyCollectedDataTypePurposes'], ['NSPrivacyCollectedDataTypePurposeAppFunctionality'], key)

    def test_no_duplicate_types(self):
        types = [item[PREFIX] for item in self.manifest['NSPrivacyCollectedDataTypes']]
        self.assertEqual(len(types), len(set(types)))


if __name__ == '__main__':
    unittest.main()

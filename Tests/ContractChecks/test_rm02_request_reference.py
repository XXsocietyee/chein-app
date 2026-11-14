"""RM-02 OWN-OPT-072 contract tests: non-play unknown/error surfaces mount RequestReferenceRow."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class Rm02RequestReferenceContractTests(unittest.TestCase):
    def read(self, rel):
        return (ROOT / rel).read_text()

    def test_non_play_error_and_unknown_surfaces_mount_request_reference_row(self):
        expected = [
            ("App/OrderLifecycleView.swift", 'RequestReferenceRow(pathFragment: "/api/registration/")'),
            ("App/RegistrationSheetView.swift", 'RequestReferenceRow(pathFragment: "/api/registration/quote")'),
            ("App/RegistrationSheetView.swift", 'RequestReferenceRow(pathFragment: "/api/registration/create")'),
            ("App/RegistrationSheetView.swift", 'RequestReferenceRow(pathFragment: "/api/registration/info")'),
            ("App/RegistrationPaymentReadinessSection.swift", 'RequestReferenceRow(pathFragment: "/api/registration/payment-readiness")'),
            ("App/RegistrationPaySection.swift", 'RequestReferenceRow(pathFragment: "/api/registration/pay")'),
            ("App/PayoutReceiverBridge.swift", 'RequestReferenceRow(pathFragment: "/api/")'),
            ("App/ClubManagementView.swift", 'RequestReferenceRow(pathFragment: "/api/club/")'),
            ("App/ParticipantFormView.swift", 'RequestReferenceRow(pathFragment: "/api/user/")'),
            ("App/MessageActionComposer.swift", 'RequestReferenceRow(pathFragment: "/api/im/")'),
            ("App/SocialActionViews.swift", 'RequestReferenceRow(pathFragment: "/api/")'),
        ]
        for rel, marker in expected:
            self.assertIn(marker, self.read(rel), f"{rel} missing {marker}")


if __name__ == "__main__":
    unittest.main()

"""RM-02 API-/api/registration/pay contract tests."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class Rm02RegistrationPayContractTests(unittest.TestCase):
    def read(self, rel):
        return (ROOT / rel).read_text()

    def test_registration_pay_is_gated_and_single_shot(self):
        flow = self.read("Core/RegistrationPayFlow.swift")
        self.assertIn('case standard = "api/registration/pay"', flow)
        self.assertIn('case app = "api/registration/pay/app"', flow)
        self.assertIn("ReleaseMoneyWriteSwitch.blocks(channel.routePath)", flow)
        self.assertIn("ReleaseMoneyWriteSwitch.isEnabled(.payment)", flow)
        self.assertIn("attemptedRegistrationIDs.insert(registrationID)", flow)
        self.assertIn("CheckoutOrderRebuildRule.classifyPayFailure", flow)

    def test_app_lease_and_surfaces_wire_registration_pay_behind_money_payments(self):
        section = self.read("App/RegistrationPaySection.swift")
        self.assertIn("ReviewedAreaSwitch.moneyPayments", section)
        self.assertIn("RegistrationPayLease", section)
        self.assertIn('RequestReferenceRow(pathFragment: "/api/registration/pay")', section)
        app = self.read("App/QuestifyApp.swift")
        self.assertIn(".environment(\\.registrationPayExecutor, payExecutor)", app)
        sheet = self.read("App/RegistrationSheetView.swift")
        self.assertIn("RegistrationPaySection(", sheet)
        order = self.read("App/OrderLifecycleView.swift")
        self.assertIn("RegistrationPaySection(", order)

    def test_release_money_switch_stays_off_in_release(self):
        cap = self.read("Core/ChinaReviewedRouteCapability.swift")
        self.assertIn('"/api/registration/pay": .payment', cap)
        self.assertIn("public static var paymentEnabled: Bool { testDerivation?(.payment) ?? false }", cap)


if __name__ == "__main__":
    unittest.main()

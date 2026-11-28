"""K50-R1: device-token upload shape exists, settings asks the client, composition still refuses the call."""
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


def read(relative):
    return (ROOT / relative).read_text(encoding="utf-8")


class K50RemotePushTests(unittest.TestCase):
    def test_settings_asks_the_client_and_the_entry_does_not_register(self):
        nudge = read("App/NativeNotificationPermissionNudgeView.swift")
        entry = read("App/NativeNotificationPermissionEntry.swift")
        self.assertIn("RemotePushRegistrationClient.consider(authorization: authorization)", nudge)
        self.assertNotIn("registerForRemoteNotifications", entry)
        self.assertNotIn("registerForRemoteNotifications", nudge)

    def test_register_call_is_behind_the_upload_admission_guard(self):
        client = read("App/RemotePushRegistrationClient.swift")
        guard_at = client.index("guard uploadAdmitted else { return }")
        call_at = client.index("target.registerForRemoteNotifications()")
        self.assertLess(guard_at, call_at)
        self.assertIn("DevicePushTokenUpload.compositionAdmitsUpload()", client)
        self.assertIn("application ?? UIApplication.shared", client)

    def test_upload_path_is_refused_by_the_reviewed_catalog(self):
        source = read("Core/DevicePushTokenUpload.swift")
        self.assertIn('public static let path = "api/device/push-token"', source)
        self.assertIn("ChinaReviewedRouteCapability.admitsChinaProductionCall", source)
        self.assertIn("guard compositionAdmitsUpload() else { return nil }", source)
        catalog = read("Core/ChinaReviewedRouteCapability.swift")
        self.assertNotIn('"/api/device/push-token"', catalog)

    def test_owner_placeholder_is_a_name_and_not_a_key(self):
        owner = read("docs/release/owner-values.md")
        self.assertIn("QUESTIFY_APNS_AUTH_KEY", owner)
        self.assertIn("chein-apns-unset", owner)
        self.assertNotIn("BEGIN PRIVATE KEY", owner)
        self.assertNotIn(".p8", owner)

    def test_money_merchant_and_init_order_stay(self):
        money = read("Core/ChinaReviewedRouteCapability.swift")
        self.assertIn("public static var paymentEnabled: Bool { testDerivation?(.payment) ?? false }", money)
        self.assertIn("public static var refundEnabled: Bool { testDerivation?(.refund) ?? false }", money)
        self.assertIn("public static var withdrawalEnabled: Bool { testDerivation?(.withdrawal) ?? false }", money)
        self.assertIn("public static var payoutEnabled: Bool { testDerivation?(.payout) ?? false }", money)
        launch = read("Core/PlayerLaunch.swift")
        self.assertIn("#else\n    public static let merchantCenterEnabled = false\n    #endif", launch)
        lease = read("App/ReviewedPlayerWriteLeases.swift")
        devices = lease.index("devices: Self.playDevices, sensors: Self.playSensors,")
        artwork = lease.index("artworkHosts: Self.playArtworkHosts(apiBase: context.baseURL)")
        self.assertLess(devices, artwork)
        self.assertNotIn("api/device/push-token", lease)

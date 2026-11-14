"""RM-02 OWN-OPT-090..092 release readiness, E2E flows, and TestFlight prep verification tests."""
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]


class Rm02ReleaseReadinessTests(unittest.TestCase):
    def test_opt090_maestro_flows_and_scripts_present(self):
        maestro_dir = ROOT / "e2e/maestro"
        self.assertTrue((maestro_dir / "run_all.sh").exists())
        self.assertTrue((maestro_dir / "RESULTS_TEMPLATE.md").exists())
        yaml_files = sorted(maestro_dir.glob("*.yaml"))
        self.assertGreaterEqual(len(yaml_files), 18)
        for flow_name in (
            "permissions.yaml",
            "login.yaml",
            "discover-activity-signup.yaml",
            "play-session.yaml",
            "roam.yaml",
            "city-game.yaml",
            "club.yaml",
            "im-dm-preview.yaml",
            "community-post.yaml",
            "creator-publish-review-appeal.yaml",
            "external-game.yaml",
            "rewards-store.yaml",
            "workshop-purchased-install.yaml",
            "wallet.yaml",
            "search-filters.yaml",
            "offline-banner.yaml",
            "account-export-deletion.yaml",
            "merchant-ops-payout.yaml",
        ):
            path = maestro_dir / flow_name
            self.assertTrue(path.exists(), f"Missing Maestro flow: {flow_name}")
            content = path.read_text()
            self.assertIn("appId:", content)

    def test_opt090_accessibility_ids_wired_in_swift(self):
        expected_ids = [
            ("App/AccountView.swift", "account.settings"),
            ("App/DesignSystem/CYDomainTabBar.swift", "cyTabBarAccessibilityIdentifiers"),
            ("App/RoamBrowserView.swift", "roam.more.city"),
            ("App/RoamBrowserView.swift", "roam.more.nearbyTeams"),
            ("App/RegistrationSheetView.swift", "registration.form.confirm"),
            ("App/TopicXcxSections.swift", "topic.cta.sessions"),
            ("App/PlayExperienceView.swift", "playx.hints.confirm"),
            ("App/LoginView.swift", "auth.close"),
        ]
        for rel, marker in expected_ids:
            self.assertIn(marker, (ROOT / rel).read_text(), f"{rel} missing {marker}")

    def test_opt091_device_test_steps_documented(self):
        doc = ROOT / "docs/release/e2e/RM-02-device-test-steps.md"
        self.assertTrue(doc.exists())
        text = doc.read_text()
        for section in ("OWN-OPT-090", "OWN-OPT-091", "OWN-OPT-092", "PlayNativeDeviceProvider", "CoreLocation", "TestFlight"):
            self.assertIn(section, text)

    def test_opt092_testflight_scripts_and_appstore_docs_valid(self):
        for rel in (
            "docs/release/TESTFLIGHT.md",
            "docs/release/app-privacy-answers.md",
            "docs/release/app-store-review-notes.md",
            "docs/release/release-notes.en.md",
            "docs/release/release-notes.zh-Hans.md",
            "docs/release/storekit-sandbox.md",
            "tools/check_release_preflight.py",
            "tools/archive_unsigned.py",
        ):
            self.assertTrue((ROOT / rel).exists(), f"Missing release artifact: {rel}")

        scripts_dir = ROOT / "scripts/release"
        for name in ("archive.sh", "bump-version.sh", "preflight.sh", "upload.sh"):
            script = scripts_dir / name
            self.assertTrue(script.exists(), f"Missing release script: {name}")
            res = subprocess.run(["bash", "-n", str(script)], capture_output=True, text=True)
            self.assertEqual(res.returncode, 0, f"bash -n failed for {name}: {res.stderr}")


if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3
"""Unit tests for TestFlight release preparation scripts and preflight assertions.

Never invokes real xcodebuild or xcrun altool. Uses temporary directories and
PATH-injected stubs to test guards, plist generation, version bumping, and
negative preflight cases.
"""
import os
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

import check_release_preflight as preflight  # noqa: E402


class ReleasePrepTests(unittest.TestCase):
    def test_scripts_exist_are_executable_and_pass_bash_syntax(self):
        for name in ("archive.sh", "bump-version.sh", "preflight.sh", "upload.sh"):
            path = ROOT / "scripts/release" / name
            self.assertTrue(path.is_file(), f"Missing {path}")
            self.assertTrue(os.access(path, os.X_OK), f"Not executable: {path}")
            res = subprocess.run(["bash", "-n", str(path)], capture_output=True, text=True)
            self.assertEqual(res.returncode, 0, f"bash -n failed for {name}: {res.stderr}")

    def test_archive_refuses_without_release_confirm(self):
        env = dict(os.environ)
        env.pop("RELEASE_CONFIRM", None)
        res = subprocess.run(
            [str(ROOT / "scripts/release/archive.sh")],
            cwd=ROOT,
            env=env,
            capture_output=True,
            text=True,
        )
        self.assertNotEqual(res.returncode, 0)
        self.assertIn("RELEASE_CONFIRM=deploy-now", res.stderr)

        env["RELEASE_CONFIRM"] = "wrong"
        res2 = subprocess.run(
            [str(ROOT / "scripts/release/archive.sh")],
            cwd=ROOT,
            env=env,
            capture_output=True,
            text=True,
        )
        self.assertNotEqual(res2.returncode, 0)

    def test_upload_refuses_without_release_confirm_and_requires_api_env(self):
        env = dict(os.environ)
        env.pop("RELEASE_CONFIRM", None)
        res = subprocess.run(
            [str(ROOT / "scripts/release/upload.sh")],
            cwd=ROOT,
            env=env,
            capture_output=True,
            text=True,
        )
        self.assertNotEqual(res.returncode, 0)
        self.assertIn("RELEASE_CONFIRM=deploy-now", res.stderr)

        with tempfile.TemporaryDirectory() as tmp:
            ipa = Path(tmp) / "Questify.ipa"
            ipa.write_bytes(b"fake-ipa")
            env["RELEASE_CONFIRM"] = "deploy-now"
            env.pop("APP_STORE_CONNECT_KEY_ID", None)
            env.pop("APP_STORE_CONNECT_ISSUER_ID", None)
            env.pop("APP_STORE_CONNECT_KEY_PATH", None)
            res2 = subprocess.run(
                [str(ROOT / "scripts/release/upload.sh"), str(ipa)],
                cwd=ROOT,
                env=env,
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(res2.returncode, 0)
            self.assertIn("APP_STORE_CONNECT_KEY_ID", res2.stderr)

    def test_upload_uses_stub_xcrun_altool_with_api_key_env(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            ipa = tmp_path / "Questify.ipa"
            ipa.write_bytes(b"fake-ipa")
            key_file = tmp_path / "my-key.p8"
            key_file.write_text("-----BEGIN PRIVATE KEY-----\nFAKE\n-----END PRIVATE KEY-----\n")
            log_file = tmp_path / "xcrun.log"
            bin_dir = tmp_path / "bin"
            bin_dir.mkdir()
            stub_xcrun = bin_dir / "xcrun"
            stub_xcrun.write_text(
                f"""#!/usr/bin/env bash
set -euo pipefail
echo "ARGS:$*" >> "{log_file}"
echo "KEYS_DIR:${{API_PRIVATE_KEYS_DIR:-}}" >> "{log_file}"
ls -1 "${{API_PRIVATE_KEYS_DIR:-}}" >> "{log_file}"
"""
            )
            stub_xcrun.chmod(0o755)

            env = dict(os.environ)
            env["PATH"] = f"{bin_dir}:{env.get('PATH', '')}"
            env["RELEASE_CONFIRM"] = "deploy-now"
            env["APP_STORE_CONNECT_KEY_ID"] = "ABCD123456"
            env["APP_STORE_CONNECT_ISSUER_ID"] = "00000000-0000-0000-0000-000000000000"
            env["APP_STORE_CONNECT_KEY_PATH"] = str(key_file)

            res = subprocess.run(
                [str(ROOT / "scripts/release/upload.sh"), "--validate-only", str(ipa)],
                cwd=ROOT,
                env=env,
                capture_output=True,
                text=True,
            )
            self.assertEqual(res.returncode, 0, res.stderr)
            logged = log_file.read_text()
            self.assertIn("altool --validate-app -f", logged)
            self.assertIn("--api-key ABCD123456", logged)
            self.assertIn("--api-issuer 00000000-0000-0000-0000-000000000000", logged)
            self.assertIn("AuthKey_ABCD123456.p8", logged)

    def test_bump_version_print_only_and_isolated_apply(self):
        res = subprocess.run(
            [str(ROOT / "scripts/release/bump-version.sh"), "--print"],
            cwd=ROOT,
            capture_output=True,
            text=True,
        )
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertIn("MARKETING_VERSION=", res.stdout)
        self.assertIn("CURRENT_PROJECT_VERSION=", res.stdout)
        self.assertIn("changed: no", res.stdout)

        with tempfile.TemporaryDirectory() as tmp:
            tmp_root = Path(tmp)
            (tmp_root / "Config").mkdir()
            (tmp_root / "tools").mkdir()
            (tmp_root / "scripts/release").mkdir(parents=True)
            shutil.copyfile(ROOT / "Config/Base.xcconfig", tmp_root / "Config/Base.xcconfig")
            shutil.copyfile(ROOT / "Config/Info.plist", tmp_root / "Config/Info.plist")
            shutil.copyfile(ROOT / "tools/bump_version.py", tmp_root / "tools/bump_version.py")
            bump_sh = tmp_root / "scripts/release/bump-version.sh"
            shutil.copyfile(ROOT / "scripts/release/bump-version.sh", bump_sh)
            bump_sh.chmod(0o755)

            res2 = subprocess.run(
                [str(bump_sh), "1.2.3", "42"],
                cwd=tmp_root,
                capture_output=True,
                text=True,
            )
            self.assertEqual(res2.returncode, 0, res2.stderr)
            self.assertIn("CFBundleShortVersionString=1.2.3", res2.stdout)
            self.assertIn("CFBundleVersion=42", res2.stdout)
            updated = (tmp_root / "Config/Base.xcconfig").read_text()
            self.assertIn("MARKETING_VERSION = 1.2.3", updated)
            self.assertIn("CURRENT_PROJECT_VERSION = 42", updated)

            res3 = subprocess.run(
                [str(bump_sh), "--build", "43"],
                cwd=tmp_root,
                capture_output=True,
                text=True,
            )
            self.assertEqual(res3.returncode, 0, res3.stderr)
            self.assertIn("CFBundleShortVersionString=1.2.3", res3.stdout)
            self.assertIn("CFBundleVersion=43", res3.stdout)

    def test_archive_flow_with_stub_xcodebuild_and_preflight(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_root = Path(tmp)
            (tmp_root / "scripts/release").mkdir(parents=True)
            (tmp_root / "Questify.xcodeproj").mkdir()
            out_dir = tmp_root / "out"
            bin_dir = tmp_root / "bin"
            bin_dir.mkdir()

            archive_sh = tmp_root / "scripts/release/archive.sh"
            shutil.copyfile(ROOT / "scripts/release/archive.sh", archive_sh)
            archive_sh.chmod(0o755)

            preflight_sh = tmp_root / "scripts/release/preflight.sh"
            preflight_sh.write_text("#!/usr/bin/env bash\nexit 0\n")
            preflight_sh.chmod(0o755)

            calls_log = tmp_root / "xcodebuild.calls"
            stub_xcodebuild = bin_dir / "xcodebuild"
            stub_xcodebuild.write_text(
                f"""#!/usr/bin/env python3
import pathlib, plistlib, sys
args = sys.argv[1:]
with open({str(calls_log)!r}, "a") as f:
    f.write(" ".join(args) + "\\n")
if "-showBuildSettings" in args:
    print("    DEVELOPMENT_TEAM = 9VHY8N755R")
    print("    MARKETING_VERSION = 0.1.0")
    print("    CURRENT_PROJECT_VERSION = 2")
elif "archive" in args:
    archive_path = pathlib.Path(args[args.index("-archivePath") + 1])
    (archive_path / "dSYMs" / "Questify.app.dSYM").mkdir(parents=True, exist_ok=True)
    (archive_path / "dSYMs" / "GLTFKit2.framework.dSYM").mkdir(parents=True, exist_ok=True)
elif "-exportArchive" in args:
    export_path = pathlib.Path(args[args.index("-exportPath") + 1])
    plist_path = pathlib.Path(args[args.index("-exportOptionsPlist") + 1])
    data = plistlib.loads(plist_path.read_bytes())
    assert data["method"] == "app-store-connect", data
    assert data["signingStyle"] == "automatic", data
    assert data["teamID"] == "9VHY8N755R", data
    assert data["destination"] == "export", data
    export_path.mkdir(parents=True, exist_ok=True)
    (export_path / "Questify.ipa").write_bytes(b"stub-ipa")
"""
            )
            stub_xcodebuild.chmod(0o755)

            env = dict(os.environ)
            env["PATH"] = f"{bin_dir}:{env.get('PATH', '')}"
            env["RELEASE_CONFIRM"] = "deploy-now"
            env["RELEASE_OUT_DIR"] = str(out_dir)

            res = subprocess.run([str(archive_sh)], cwd=tmp_root, env=env, capture_output=True, text=True)
            self.assertEqual(res.returncode, 0, res.stderr + res.stdout)
            self.assertIn("IPA_PATH=" + str(out_dir / "export/Questify.ipa"), res.stdout)
            self.assertIn("Questify.app.dSYM", res.stdout)
            self.assertIn("GLTFKit2.framework.dSYM", res.stdout)
            plist_data = plistlib.loads((out_dir / "ExportOptions.plist").read_bytes())
            self.assertEqual(plist_data["method"], "app-store-connect")
            self.assertEqual(plist_data["signingStyle"], "automatic")
            self.assertEqual(plist_data["teamID"], "9VHY8N755R")
            calls = calls_log.read_text()
            self.assertIn("-destination generic/platform=iOS ARCHS=arm64", calls)
            self.assertIn("-configuration Release", calls)

    def test_release_preflight_passes_on_repo_and_detects_open_switch(self):
        self.assertEqual(preflight.run_checks(ROOT), [])
        active, errs = preflight.release_projection_no_debug_no_test(
            "#if DEBUG || TEST\nlet x = true\n#else\nlet x = false\n#endif\n"
        )
        self.assertEqual(errs, [])
        self.assertEqual([code for _, code, _ in active], ["let x = false"])

        # Negative tests on an isolated repo copy
        with tempfile.TemporaryDirectory() as tmp:
            tmp_root = Path(tmp)
            for rel in (
                "Questify.xcodeproj/project.pbxproj",
                "Config/Base.xcconfig",
                "Config/China.xcconfig",
                "Config/China.Development.xcconfig",
                "Config/China.Staging.xcconfig",
                "Config/China.Production.xcconfig",
                "Config/UnitedStates.xcconfig",
                "Config/UnitedStates.Development.xcconfig",
                "Config/UnitedStates.Staging.xcconfig",
                "Config/UnitedStates.Production.xcconfig",
                "Config/Release.xcconfig",
                "Core/ChinaReviewedRouteCapability.swift",
                "Core/SettingsIdentityApplications.swift",
                "Core/ActivityPublishingWizard.swift",
                "Core/RoamStampCaptureCoordinator.swift",
                "App/ReviewedAreaSwitch.swift",
                "App/AppSession.swift",
                "App/WalletCommerceViews.swift",
                "App/QuestifyApp.swift",
                # One app for CN + US (owner 2026-11-27): runtime market inputs.
                "App/RegionalLaunchConfiguration.swift",
                "App/StripePayBridge.swift",
                "Core/UserMarket.swift",
            ):
                dst = tmp_root / rel
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT / rel, dst)

            # Create empty stubs for all other compiled sources in project.pbxproj
            proj = preflight.exclusion.parse_project((tmp_root / "Questify.xcodeproj/project.pbxproj").read_text())
            objs, target = preflight.exclusion.app_target(proj)
            for rel in preflight.exclusion.app_swift_sources(objs, target):
                p = tmp_root / rel
                if not p.exists():
                    p.parent.mkdir(parents=True, exist_ok=True)
                    p.write_text("")

            self.assertEqual(preflight.run_checks(tmp_root), [])

            # One app (owner 2026-11-27): a second App Store bundle ID or a build-keyed US pay gate must fail.
            us_prod = tmp_root / "Config/UnitedStates.Production.xcconfig"
            original_us = us_prod.read_text()
            us_prod.write_text(original_us + "\nPRODUCT_BUNDLE_IDENTIFIER = com.chengyinhub.chengyinApp.us\n")
            self.assertTrue(any("second App Store bundle ID" in f for f in preflight.run_checks(tmp_root)))
            us_prod.write_text(original_us)
            stripe = tmp_root / "App/StripePayBridge.swift"
            original_stripe = stripe.read_text()
            stripe.write_text(original_stripe.replace("RegionalLaunchConfiguration.storefrontMarket == .unitedStates",
                                                      "session.regionalConfiguration?.market == .unitedStates"))
            self.assertTrue(any("StripePayBridge" in f for f in preflight.run_checks(tmp_root)))
            stripe.write_text(original_stripe)
            self.assertEqual(preflight.run_checks(tmp_root), [])

            # Forcing the payment derivation default to true must fail
            cap = tmp_root / "Core/ChinaReviewedRouteCapability.swift"
            cap.write_text(cap.read_text().replace(
                "public static var paymentEnabled: Bool { testDerivation?(.payment) ?? false }",
                "public static var paymentEnabled: Bool { true }",
                1,
            ))
            failures = preflight.run_checks(tmp_root)
            self.assertTrue(any("paymentEnabled" in f for f in failures), failures)

            # Flipping passwordLoginCompiledIn in Release must fail
            sess = tmp_root / "App/AppSession.swift"
            sess.write_text(sess.read_text().replace("#else\n        false\n#endif", "#else\n        true\n#endif", 1))
            failures2 = preflight.run_checks(tmp_root)
            self.assertTrue(any("passwordLoginCompiledIn" in f for f in failures2), failures2)

            # Leaking E2ETestHostOverride outside #if DEBUG must fail
            app_swift = tmp_root / "App/QuestifyApp.swift"
            app_swift.write_text(app_swift.read_text() + "\nlet leak = E2ETestHostOverride.testHost\n")
            failures3 = preflight.run_checks(tmp_root)
            self.assertTrue(any("E2ETestHostOverride" in f for f in failures3), failures3)

    def test_preflight_exits_nonzero_on_gate_failure(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_root = Path(tmp)
            (tmp_root / "scripts/release").mkdir(parents=True)
            (tmp_root / "tools").mkdir()
            preflight_sh = tmp_root / "scripts/release/preflight.sh"
            shutil.copyfile(ROOT / "scripts/release/preflight.sh", preflight_sh)
            preflight_sh.chmod(0o755)
            # Populate all tools called by preflight.sh: all pass except contract_ratchet fails.
            for tool_name in (
                "check_scaffold.py",
                "check_design_lint.py",
                "check_appsession_ratchet.py",
                "check_release_config.py",
                "check_design_fixture_release_exclusion.py",
                "audit_client_ops_surfaces.py",
                "lint_no_release_print.py",
                "check_l2_environment_configs.py",
                "check_release_preflight.py",
            ):
                (tmp_root / "tools" / tool_name).write_text("import sys; sys.exit(0)\n")
            (tmp_root / "tools/contract_ratchet.py").write_text("import sys; print('boom'); sys.exit(1)\n")
            res = subprocess.run([str(preflight_sh)], cwd=tmp_root, capture_output=True, text=True)
            self.assertNotEqual(res.returncode, 0)
            self.assertIn("FAIL [contract_ratchet]", res.stderr)

    def test_docs_testflight_has_required_sections(self):
        doc = (ROOT / "docs/release/TESTFLIGHT.md").read_text(encoding="utf-8")
        for marker in (
            "scripts/release/bump-version.sh",
            "scripts/release/preflight.sh",
            "scripts/release/archive.sh",
            "scripts/release/upload.sh",
            "RELEASE_CONFIRM=deploy-now",
            "APP_STORE_CONNECT_KEY_ID",
            "APP_STORE_CONNECT_ISSUER_ID",
            "APP_STORE_CONNECT_KEY_PATH",
            "Internal Tester Group",
            "What to Check After Upload",
            "Rollback",
        ):
            self.assertIn(marker, doc)


if __name__ == "__main__":
    unittest.main()

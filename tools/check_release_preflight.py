#!/usr/bin/env python3
"""Release preflight assertions (source + config projection only, never runs xcodebuild).

Verifies:
1. Questify app target Release configuration has no DEBUG/TEST compilation conditions,
   points to Config/Release.xcconfig, generates dSYMs (dwarf-with-dsym), and optimizes (-O).
2. Resolved Release build settings pin the production API base URL
   (https://www.chengyinhub.com/prod-api/), realm (cn-prod), market (CN),
   bundle ID (com.chengyinhub.chengyinApp), and 10-char team ID.
3. Release-compiled Swift projection (DEBUG and TEST unset, Release exclusions applied)
   contains no DEBUG fixture hosts, test-host overrides, or E2E test-host endpoints.
4. Money writes follow the host derivation in Release and default off when no host is installed.
   Virtual goods stay off. Password login stays closed in Release.
   - Core/ChinaReviewedRouteCapability.swift: ReleaseMoneyWriteSwitch reads testDerivation, default false
   - App/ReviewedAreaSwitch.swift: installReleaseMoneyDerivation compiles; password/merchant Release branches stay false
   - App/AppSession.swift: passwordLoginCompiledIn & canUsePassword false in Release
   - App/WalletCommerceViews.swift: WalletPayoutCapability.isOn follows the withdrawal switch
"""
from pathlib import Path
import re
import sys

TOOLS_DIR = Path(__file__).resolve().parent
ROOT = TOOLS_DIR.parent
sys.path.insert(0, str(TOOLS_DIR))

import check_design_fixture_release_exclusion as exclusion  # noqa: E402
import check_l2_environment_configs as l2  # noqa: E402

PROD_BASE_URL = "https://www.chengyinhub.com/prod-api/"
PROD_HOST = "www.chengyinhub.com"
PROD_REALM = "cn-prod"
PROD_MARKET = "CN"
PROD_BUNDLE_ID = "com.chengyinhub.chengyinApp"
LEGACY_FORBIDDEN_HOST = "47.103.124.64"

FORBIDDEN_RELEASE_TOKENS = (
    "E2ETestHostOverride",
    "E2ETestHostTransport",
    "--e2e-test-host",
    "instabox.tech",
    "DesignFixtureRegistry",
    "--design-fixture",
    "FixtureThemeDomainModifier",
    "IntegratedNativeAcceptanceFixture",
    "CouponRuntimeFixture",
)


def _eval_condition_for_release(condition: str) -> bool:
    """Return True when the #if condition is EXCLUDED from Release (DEBUG/TEST unset)."""
    expr = condition.strip()
    if "&&" in expr and "||" not in expr:
        parts = [p.strip() for p in expr.split("&&")]
        return any(p in ("DEBUG", "TEST") for p in parts)
    if "||" in expr and "&&" not in expr:
        parts = [p.strip() for p in expr.split("||")]
        return all(p in ("DEBUG", "TEST") for p in parts)
    return expr in ("DEBUG", "TEST")


def release_projection_no_debug_no_test(text: str):
    """Return (active_lines, errors) with #if DEBUG / #if TEST / #if DEBUG || TEST excluded."""
    stack = []
    in_block = False
    active = []
    errors = []
    for number, raw in enumerate(text.splitlines(), 1):
        code, in_block = exclusion.strip_comments(raw, in_block)
        stripped = code.strip()
        if stripped.startswith("#if"):
            outer = bool(stack and stack[-1])
            stack.append(_eval_condition_for_release(stripped[3:].strip()) or outer)
            continue
        if stripped.startswith("#elseif"):
            if not stack:
                errors.append(f"{number}: #elseif without #if")
                continue
            outer = bool(len(stack) > 1 and stack[-2])
            stack[-1] = _eval_condition_for_release(stripped[len("#elseif"):].strip()) or outer
            continue
        if stripped.startswith("#else"):
            if not stack:
                errors.append(f"{number}: #else without #if")
                continue
            outer = bool(len(stack) > 1 and stack[-2])
            # `#else` of an excluded `#if DEBUG` / `#if DEBUG || TEST` IS active in Release
            # unless an enclosing outer block is excluded.
            stack[-1] = outer
            continue
        if stripped.startswith("#endif"):
            if not stack:
                errors.append(f"{number}: #endif without #if")
                continue
            stack.pop()
            continue
        if stack and stack[-1]:
            continue
        if stripped:
            active.append((number, stripped, raw.rstrip()))
    if stack:
        errors.append("unterminated #if")
    if in_block:
        errors.append("unterminated block comment")
    return active, errors


def check_project_release_settings(root: Path, failures: list[str]) -> set[str]:
    project = exclusion.parse_project((root / "Questify.xcodeproj/project.pbxproj").read_text(encoding="utf-8"))
    objects, target = exclusion.app_target(project)
    release_cfg = exclusion.configuration(objects, target, "Release")
    settings = release_cfg.get("buildSettings", {})

    base_ref_id = release_cfg.get("baseConfigurationReference")
    base_ref_path = objects.get(base_ref_id, {}).get("path") if base_ref_id else None
    if base_ref_path != "Config/Release.xcconfig":
        failures.append(f"Questify Release baseConfigurationReference must be Config/Release.xcconfig, found {base_ref_path!r}")

    active_conds = settings.get("SWIFT_ACTIVE_COMPILATION_CONDITIONS", "")
    cond_tokens = {tok for tok in active_conds.split() if tok != "$(inherited)"}
    for forbidden_cond in ("DEBUG", "TEST"):
        if forbidden_cond in cond_tokens:
            failures.append(f"Questify Release SWIFT_ACTIVE_COMPILATION_CONDITIONS must not define {forbidden_cond}")

    project_obj = objects[project["rootObject"]]
    proj_configs = objects[project_obj["buildConfigurationList"]]["buildConfigurations"]
    for cfg_id in proj_configs:
        cfg = objects[cfg_id]
        if cfg.get("name") == "Release":
            proj_conds = cfg.get("buildSettings", {}).get("SWIFT_ACTIVE_COMPILATION_CONDITIONS", "")
            for forbidden_cond in ("DEBUG", "TEST"):
                if forbidden_cond in proj_conds.split():
                    failures.append(f"Project Release configuration must not define {forbidden_cond}")

    if settings.get("DEBUG_INFORMATION_FORMAT") != "dwarf-with-dsym":
        failures.append(f"Questify Release DEBUG_INFORMATION_FORMAT must be dwarf-with-dsym, found {settings.get('DEBUG_INFORMATION_FORMAT')!r}")
    if settings.get("SWIFT_OPTIMIZATION_LEVEL") != "-O":
        failures.append(f"Questify Release SWIFT_OPTIMIZATION_LEVEL must be -O, found {settings.get('SWIFT_OPTIMIZATION_LEVEL')!r}")

    return set(exclusion.exclusion_tokens(settings.get("EXCLUDED_SOURCE_FILE_NAMES", "")))


def check_production_base_url_and_identity(root: Path, failures: list[str]) -> None:
    files = l2.tracked_inputs(root)
    files["Release.xcconfig"] = (root / "Config/Release.xcconfig").read_text(encoding="utf-8")
    resolved = l2.settings("Release.xcconfig", files)

    checks = {
        "QUESTIFY_API_BASE_URL": PROD_BASE_URL,
        "QUESTIFY_SESSION_REALM": PROD_REALM,
        "QUESTIFY_MARKET": PROD_MARKET,
        "QUESTIFY_DEPLOYMENT_ENVIRONMENT": "production",
        "PRODUCT_BUNDLE_IDENTIFIER": PROD_BUNDLE_ID,
        "CODE_SIGN_STYLE": "Automatic",
    }
    for key, expected in checks.items():
        actual = resolved.get(key, "")
        if actual != expected:
            failures.append(f"Resolved Release {key} must be {expected!r}, found {actual!r}")

    team = resolved.get("DEVELOPMENT_TEAM", "")
    if not re.fullmatch(r"[A-Z0-9]{10}", team):
        failures.append(f"Resolved Release DEVELOPMENT_TEAM is missing or malformed: {team!r}")

    if LEGACY_FORBIDDEN_HOST in resolved.get("QUESTIFY_API_BASE_URL", ""):
        failures.append("Resolved Release QUESTIFY_API_BASE_URL references forbidden legacy host")

    release_text = files["Release.xcconfig"]
    if '#include "China.Production.xcconfig"' not in release_text:
        failures.append('Config/Release.xcconfig must include "China.Production.xcconfig"')
    else:
        after_include = release_text.split('#include "China.Production.xcconfig"', 1)[1]
        for pinned_key in ("PRODUCT_BUNDLE_IDENTIFIER", "DEVELOPMENT_TEAM", "QUESTIFY_API_BASE_URL", "QUESTIFY_SESSION_REALM", "QUESTIFY_MARKET"):
            if pinned_key not in after_include:
                failures.append(f"Config/Release.xcconfig must pin {pinned_key} after China.Production.xcconfig include")

    for local_override in sorted((root / "Config").glob("Local*.xcconfig")):
        local_text = local_override.read_text(encoding="utf-8", errors="replace")
        for forbidden_key in (
            "MARKETING_VERSION",
            "CURRENT_PROJECT_VERSION",
            "QUESTIFY_API_BASE_URL",
            "QUESTIFY_SESSION_REALM",
            "DEVELOPMENT_TEAM",
            "PRODUCT_BUNDLE_IDENTIFIER",
            "CODE_SIGNING_ALLOWED",
        ):
            if re.search(rf"^\s*{forbidden_key}\s*=", local_text, re.M):
                failures.append(
                    f"Local xcconfig override {local_override.relative_to(root)} must not set {forbidden_key} for Release"
                )


def check_no_debug_fixtures_or_test_host_in_release(root: Path, excluded_names: set[str], failures: list[str]) -> None:
    project = exclusion.parse_project((root / "Questify.xcodeproj/project.pbxproj").read_text(encoding="utf-8"))
    objects, target = exclusion.app_target(project)
    compiled = exclusion.app_swift_sources(objects, target)

    for rel in compiled:
        if Path(rel).name in excluded_names:
            continue
        path = root / rel
        if not path.is_file():
            failures.append(f"Missing Questify compile source: {rel}")
            continue
        active, errors = release_projection_no_debug_no_test(path.read_text(encoding="utf-8"))
        for err in errors:
            failures.append(f"{rel}: preprocessor error: {err}")
        for num, code, _raw in active:
            for token in FORBIDDEN_RELEASE_TOKENS:
                if token in code:
                    failures.append(f"{rel}:{num}: forbidden DEBUG/test-host token {token!r} compiled in Release")

    app_active, _ = release_projection_no_debug_no_test((root / "App/QuestifyApp.swift").read_text(encoding="utf-8"))
    app_code = "\n".join(code for _, code, _ in app_active)
    if "Fixture" in app_code:
        failures.append("App/QuestifyApp.swift contains Fixture symbol in Release projection")
    if "SessionRootView(session:session)" not in app_code and "SessionRootView(session: session)" not in app_code:
        failures.append("App/QuestifyApp.swift Release projection missing SessionRootView(session:)")


def check_switches_closed_for_production(root: Path, failures: list[str]) -> None:
    # 1. ReleaseMoneyWriteSwitch follows the host derivation in Release and defaults off.
    cap_path = root / "Core/ChinaReviewedRouteCapability.swift"
    cap_active, cap_errors = release_projection_no_debug_no_test(cap_path.read_text(encoding="utf-8"))
    for err in cap_errors:
        failures.append(f"Core/ChinaReviewedRouteCapability.swift: {err}")
    cap_code = "\n".join(code for _, code, _ in cap_active)
    if "enum ReleaseMoneyWriteSwitch" not in cap_code:
        failures.append("Core/ChinaReviewedRouteCapability.swift missing ReleaseMoneyWriteSwitch in Release")
    else:
        switch_block = re.sub(
            r"\s+",
            " ",
            cap_code.split("enum ReleaseMoneyWriteSwitch", 1)[1].split("public struct ChinaReviewedProductionTransport", 1)[0],
        )
        if "testDerivation" not in switch_block:
            failures.append("ReleaseMoneyWriteSwitch.testDerivation must compile in Release")
        for flag, kind in (
            ("paymentEnabled", "payment"),
            ("payoutEnabled", "payout"),
            ("withdrawalEnabled", "withdrawal"),
            ("virtualGoodsEnabled", "virtualGoods"),
            ("refundEnabled", "refund"),
            ("hostCancelRefundEnabled", "hostCancelRefund"),
        ):
            snippet = f"public static var {flag}: Bool {{ testDerivation?(.{kind}) ?? false }}"
            if snippet not in switch_block:
                failures.append(f"ReleaseMoneyWriteSwitch.{flag} must follow testDerivation and default false")
            if f"{flag} = true" in switch_block:
                failures.append(f"ReleaseMoneyWriteSwitch.{flag} must not be constant true")

    # 2. App/ReviewedAreaSwitch.swift: production host & Release branches closed
    area_path = root / "App/ReviewedAreaSwitch.swift"
    area_active, area_errors = release_projection_no_debug_no_test(area_path.read_text(encoding="utf-8"))
    for err in area_errors:
        failures.append(f"App/ReviewedAreaSwitch.swift: {err}")
    area_code = "\n".join(code for _, code, _ in area_active)
    if f'static let productionAPIHost = "{PROD_HOST}"' not in area_code:
        failures.append(f"ReviewedAreaSwitch.productionAPIHost must be {PROD_HOST!r}")
    for forbidden in ("E2ETestHostOverride",):
        if forbidden in area_code:
            failures.append(f"App/ReviewedAreaSwitch.swift: {forbidden} must not compile in Release")
    for expected_snippet in (
        "static var compiledTestOrDebug: Bool { return false }",
        "private static var configuredEnabled: Bool { return false }",
        "static func installReleaseMoneyDerivation(host: String?)",
        "case .virtualGoods: return false",
        "private static func testAreaOnly(_ rawHost: String?) -> Bool { _ = rawHost return false }",
        "return admits(debug: false, apiBaseURL: bundleBaseURL())",
        'return ProcessInfo.processInfo.environment["QUESTIFY_TEST_AREA_SWITCHES"] == "1"',
    ):
        collapsed_code = re.sub(r"\s+", " ", area_code)
        if expected_snippet not in collapsed_code:
            failures.append(f"App/ReviewedAreaSwitch.swift Release projection missing closed guard: {expected_snippet}")

    # 3. App/AppSession.swift: password login compiled out in Release
    session_path = root / "App/AppSession.swift"
    session_active, session_errors = release_projection_no_debug_no_test(session_path.read_text(encoding="utf-8"))
    for err in session_errors:
        failures.append(f"App/AppSession.swift: {err}")
    session_code = re.sub(r"\s+", " ", "\n".join(code for _, code, _ in session_active))
    for expected_snippet in (
        "static var passwordLoginCompiledIn:Bool { false }",
        "var canUsePassword:Bool { false }",
        'guard Self.passwordLoginCompiledIn else { errorKey="auth.notConfigured";return }',
    ):
        if expected_snippet not in session_code:
            failures.append(f"App/AppSession.swift Release projection missing password-login closure: {expected_snippet}")

    # 4. Withdrawal entry follows the same host switch in Release. A missing derivation stays off.
    wallet_text = (root / "App/WalletCommerceViews.swift").read_text(encoding="utf-8")
    wallet_active, wallet_errors = release_projection_no_debug_no_test(wallet_text)
    for err in wallet_errors:
        failures.append(f"App/WalletCommerceViews.swift: {err}")
    wallet_code = re.sub(r"\s+", " ", "\n".join(code for _, code, _ in wallet_active))
    if "enum WalletPayoutCapability {" not in wallet_code \
            or "static var isOn: Bool { ReleaseMoneyWriteSwitch.withdrawalEnabled }" not in wallet_code \
            or "static let isOn = false" in wallet_code:
        failures.append("App/WalletCommerceViews.swift: WalletPayoutCapability.isOn must follow the withdrawal switch")

    # 5. Core/SettingsIdentityApplications.swift, ActivityPublishingWizard.swift, RoamStampCaptureCoordinator.swift
    for rel in (
        "Core/SettingsIdentityApplications.swift",
        "Core/ActivityPublishingWizard.swift",
        "Core/RoamStampCaptureCoordinator.swift",
    ):
        text = (root / rel).read_text(encoding="utf-8")
        for flag in ("paymentEnabled", "payoutEnabled", "withdrawalEnabled", "virtualGoodsEnabled"):
            if not re.search(rf"\b{flag}\b[^=\n{{]*(?:=\s*false|\{{\s*false\s*\}})", text):
                failures.append(f"{rel}: {flag} must remain false")


def run_checks(root: Path = ROOT) -> list[str]:
    failures: list[str] = []
    excluded = check_project_release_settings(root, failures)
    check_production_base_url_and_identity(root, failures)
    check_no_debug_fixtures_or_test_host_in_release(root, excluded, failures)
    check_switches_closed_for_production(root, failures)
    return failures


def main() -> int:
    failures = run_checks(ROOT)
    if failures:
        print("FAIL release preflight assertions:")
        for item in failures:
            print("  -", item)
        return 1
    print(
        f"PASS release preflight assertions: Release config verified ({PROD_BUNDLE_ID}, "
        f"{PROD_BASE_URL}, realm={PROD_REALM}), no DEBUG/test-host code in Release, "
        "money/merchant/password switches closed for production."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())

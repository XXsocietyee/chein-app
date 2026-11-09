#!/usr/bin/env python3
"""Unsigned archive preflight. Does not sign and does not upload.

With no arguments this checks the tree and does not run xcodebuild.
`--archive` runs one `xcodebuild archive` with code signing forced off.
It does not export an IPA and does not call altool, notarytool, or Transporter.
The owner signs and submits.
"""
import json
import pathlib
import plistlib
import re
import shutil
import subprocess
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(line_buffering=True)
    sys.stderr.reconfigure(line_buffering=True)

ROOT = pathlib.Path(__file__).resolve().parents[1]
ARCHIVE = ROOT / ".build" / "unsigned-archive" / "Questify.xcarchive"

USAGE_KEYS = (
    "NSCameraUsageDescription",
    "NSMotionUsageDescription",
    "NSLocationWhenInUseUsageDescription",
    "NSMicrophoneUsageDescription",
    "NSPhotoLibraryAddUsageDescription",
)
XCCONFIG_USAGE_KEYS = USAGE_KEYS[:-1]
ATS_FORBIDDEN = (
    "NSAllowsArbitraryLoads",
    "NSAllowsArbitraryLoadsForMedia",
    "NSAllowsArbitraryLoadsInWebContent",
    "NSAllowsLocalNetworking",
    "NSExceptionDomains",
    "NSAppTransportSecurity",
)
LOCATION_FORBIDDEN = (
    "NSLocationAlwaysUsageDescription",
    "NSLocationAlwaysAndWhenInUseUsageDescription",
    "UIBackgroundModes",
    "INFOPLIST_KEY_UIBackgroundModes",
)
REQUIRED_REASON_APIS = {
    "NSPrivacyAccessedAPICategoryUserDefaults": ["CA92.1"],
    "NSPrivacyAccessedAPICategoryFileTimestamp": ["C617.1", "3B52.1"],
    "NSPrivacyAccessedAPICategorySystemBootTime": ["35F9.1"],
}
UPLOAD_MARKERS = (
    "altool",
    "notarytool",
    "transporter",
    "upload",
    "-exportarchive",
    "-allowprovisioningupdates",
    "-allowprovisioningdeviceregistration",
    "development_team",
    "provisioning_profile",
    "code_sign_identity",
    "code_signing_allowed=yes",
    "authenticationkey",
    "apikey",
    ".p12",
    ".p8",
    ".mobileprovision",
    "appstoreconnect",
    "itunesconnect",
)


def fail(messages):
    for item in messages:
        print("FAIL:", item)
    return 1


def xcconfig_keys(text):
    return dict(re.findall(r"^(INFOPLIST_KEY_\w+)\s*=\s*(.+)$", text, re.M))


def check_privacy(failures):
    manifest = plistlib.loads((ROOT / "Resources/PrivacyInfo.xcprivacy").read_bytes())
    if manifest.get("NSPrivacyTracking") is not False:
        failures.append("NSPrivacyTracking is not false")
    if manifest.get("NSPrivacyTrackingDomains") != []:
        failures.append("NSPrivacyTrackingDomains is not empty")
    apis = {
        item["NSPrivacyAccessedAPIType"]: item["NSPrivacyAccessedAPITypeReasons"]
        for item in manifest["NSPrivacyAccessedAPITypes"]
    }
    if apis != REQUIRED_REASON_APIS:
        failures.append("required-reason API list differs from the committed manifest")
    for item in manifest["NSPrivacyCollectedDataTypes"]:
        name = item["NSPrivacyCollectedDataType"]
        if item["NSPrivacyCollectedDataTypeTracking"] is not False:
            failures.append("collected type is marked for tracking: " + name)
        if item["NSPrivacyCollectedDataTypeLinked"] is not True:
            failures.append("collected type is not linked: " + name)
        if item["NSPrivacyCollectedDataTypePurposes"] != ["NSPrivacyCollectedDataTypePurposeAppFunctionality"]:
            failures.append("collected type purpose is not App Functionality: " + name)
    vendor = plistlib.loads((ROOT / "Vendor/GLTFKit2/GLTFKit2/PrivacyInfo.xcprivacy").read_bytes())
    if vendor.get("NSPrivacyTracking") is not False or vendor.get("NSPrivacyCollectedDataTypes") != []:
        failures.append("GLTFKit2 privacy manifest is not tracking-off and empty")
    project = (ROOT / "Questify.xcodeproj/project.pbxproj").read_text()
    if "Resources/PrivacyInfo.xcprivacy" not in project:
        failures.append("privacy manifest is not a project resource")
    if "PrivacyInfo.xcprivacy" not in (ROOT / "tools/generate_project.py").read_text():
        failures.append("generator does not include the privacy manifest")


def check_usage_strings(failures):
    catalog = json.loads((ROOT / "Resources/InfoPlist.xcstrings").read_text())["strings"]
    keys = xcconfig_keys((ROOT / "Config/Base.xcconfig").read_text())
    info = plistlib.loads((ROOT / "Config/Info.plist").read_bytes())
    for name in USAGE_KEYS:
        localizations = catalog[name]["localizations"]
        english = localizations["en"]["stringUnit"]["value"].strip()
        chinese = localizations["zh-Hans"]["stringUnit"]["value"].strip()
        if not english or not chinese:
            failures.append("usage string missing English or zh-Hans: " + name)
        if not re.search(r"[\u4e00-\u9fff]", chinese):
            failures.append("zh-Hans usage string has no Chinese text: " + name)
    for name in XCCONFIG_USAGE_KEYS:
        english = catalog[name]["localizations"]["en"]["stringUnit"]["value"]
        if keys.get("INFOPLIST_KEY_" + name) != english:
            failures.append("xcconfig English usage string differs from the catalog: " + name)
    photo = "NSPhotoLibraryAddUsageDescription"
    if info.get(photo) != catalog[photo]["localizations"]["en"]["stringUnit"]["value"]:
        failures.append("Info.plist photo-add English string differs from the catalog")
    if "NSPhotoLibraryUsageDescription" in (ROOT / "Config/Info.plist").read_text():
        failures.append("NSPhotoLibraryUsageDescription must stay out of Config/Info.plist")


def check_ats(failures):
    files = sorted((ROOT / "Config").glob("*"))
    files.extend([
        ROOT / "Resources/InfoPlist.xcstrings",
        ROOT / "Resources/PrivacyInfo.xcprivacy",
    ])
    for path in files:
        if not path.is_file():
            continue
        text = path.read_text(errors="replace")
        for token in ATS_FORBIDDEN:
            if token in text:
                failures.append(token + " is present in " + str(path.relative_to(ROOT)))
    blob = "\n".join(
        (ROOT / relative).read_text()
        for relative in (
            "Config/Base.xcconfig",
            "Config/Info.plist",
            "Resources/InfoPlist.xcstrings",
            "Resources/PrivacyInfo.xcprivacy",
        )
    )
    for token in LOCATION_FORBIDDEN:
        if token in blob:
            failures.append(token + " is present")


def check_apple_entitlement(failures):
    """Keep Sign in with Apple only when the app target already has the slot.

    This function does not write Config/Questify.entitlements.
    """
    project = (ROOT / "Questify.xcodeproj/project.pbxproj").read_text()
    slot = re.findall(
        r'"CODE_SIGN_ENTITLEMENTS" = "Config/Questify\.entitlements";',
        project,
    )
    path = ROOT / "Config/Questify.entitlements"
    if not slot:
        print("Sign in with Apple capability slot is absent. Entitlement file was not added.")
        return
    if len(slot) != 2 or len(re.findall(r"CODE_SIGN_ENTITLEMENTS", project)) != 2:
        failures.append("Sign in with Apple capability slot is not exactly the app Debug and Release settings")
        return
    plist = plistlib.loads(path.read_bytes())
    if plist != {"com.apple.developer.applesignin": ["Default"]}:
        failures.append("entitlement file is not Sign in with Apple Default only")
        return
    print("Sign in with Apple entitlement: kept. Capability slot already exists. No other entitlement added.")


def check_composition(failures):
    script = ROOT / "tools/check_account_deletion_path.py"
    result = subprocess.run([sys.executable, "-B", str(script)], cwd=ROOT)
    if result.returncode != 0:
        failures.append("account-deletion path check failed")


def preflight():
    failures = []
    check_privacy(failures)
    check_usage_strings(failures)
    check_ats(failures)
    check_apple_entitlement(failures)
    check_composition(failures)
    if failures:
        return fail(failures)
    print("preflight: ok")
    print("signing: no")
    print("upload: no")
    return 0


def archive_command():
    return [
        "xcodebuild",
        "-project", "Questify.xcodeproj",
        "-scheme", "Questify",
        "-configuration", "Release",
        "-destination", "generic/platform=iOS",
        "-archivePath", str(ARCHIVE),
        "CODE_SIGNING_ALLOWED=NO",
        "CODE_SIGNING_REQUIRED=NO",
        "CODE_SIGN_IDENTITY=",
        "AD_HOC_CODE_SIGNING_ALLOWED=NO",
        "archive",
    ]


def command_is_unsigned(command):
    joined = " ".join(command).lower()
    markers = tuple(marker for marker in UPLOAD_MARKERS if marker != "code_sign_identity")
    if any(marker in joined for marker in markers):
        return False
    if "code_signing_allowed=no" not in joined or "code_signing_required=no" not in joined:
        return False
    identity = [part for part in command if part.lower().startswith("code_sign_identity=")]
    if identity != ["CODE_SIGN_IDENTITY="]:
        return False
    if command[-1] != "archive" or "-exportArchive" in command or "-exportarchive" in joined:
        return False
    return True


def main(argv):
    extra = argv[1:]
    lowered = [arg.lower() for arg in extra]
    if any(any(marker in arg for marker in UPLOAD_MARKERS) for arg in lowered):
        print("refusing signing or upload arguments", file=sys.stderr)
        return 2
    if extra not in ([], ["--archive"]):
        print("usage: archive_unsigned.py [--archive]", file=sys.stderr)
        return 2
    status = preflight()
    if status != 0:
        return status
    if not extra:
        print("xcodebuild: not run")
        return 0
    command = archive_command()
    if not command_is_unsigned(command):
        print("refusing archive command that is not unsigned", file=sys.stderr)
        return 2
    if shutil.which("xcodebuild") is None:
        print("xcodebuild is not installed; unsigned archive was not created", file=sys.stderr)
        return 2
    ARCHIVE.parent.mkdir(parents=True, exist_ok=True)
    print("xcodebuild archive: signing disabled, upload disabled")
    result = subprocess.run(command, cwd=ROOT)
    return result.returncode


if __name__ == "__main__":
    sys.exit(main(sys.argv))

#!/usr/bin/env python3
"""Unsigned archive preflight. Does not sign and does not upload.

With no arguments this checks the tree and does not run xcodebuild.
`--archive` runs one `xcodebuild archive` with code signing forced off.
It does not export an IPA and does not call altool, notarytool, or Transporter.
The owner signs and submits.

The preflight reads MARKETING_VERSION and CURRENT_PROJECT_VERSION from
Config/Base.xcconfig only. It does not change those numbers. A second
assignment, including one in gitignored Local.xcconfig, is a failure.
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
    "NSPrivacyAccessedAPICategoryUserDefaults": ["CA92.1", "1C8F.1"],
    "NSPrivacyAccessedAPICategoryFileTimestamp": ["C617.1", "3B52.1"],
    "NSPrivacyAccessedAPICategorySystemBootTime": ["35F9.1"],
}
VERSION_KEYS = ("MARKETING_VERSION", "CURRENT_PROJECT_VERSION")
MARKETING_VALUE = re.compile(r"^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$")
BUILD_VALUE = re.compile(r"^[1-9][0-9]*$")
LOCAL_INCLUDE = '#include? "Local.xcconfig"'
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
    widget_slot = re.findall(
        r'"CODE_SIGN_ENTITLEMENTS" = "Config/QuestifyLiveActivity\.entitlements";',
        project,
    )
    if len(slot) != 2 or len(widget_slot) != 2 or len(re.findall(r"CODE_SIGN_ENTITLEMENTS", project)) != 4:
        failures.append("entitlement slots are not exactly the app and widget Debug and Release settings")
        return
    # Components r1 (C2): the app and the widget extension share one App Group for the widget store.
    group = {"com.apple.security.application-groups": ["group.com.chengyinhub.chengyinApp"]}
    plist = plistlib.loads(path.read_bytes())
    if plist != {"com.apple.developer.applesignin": ["Default"], **group}:
        failures.append("entitlement file is not Sign in with Apple Default plus the widget App Group")
        return
    widget = plistlib.loads((ROOT / "Config/QuestifyLiveActivity.entitlements").read_bytes())
    if widget != group:
        failures.append("widget entitlement file is not the App Group only")
        return
    print("Sign in with Apple and widget App Group entitlements: kept. No other entitlement added.")


def xcconfig_version_assignments(text):
    """Return (key, value, offset) for version assignments. Offset is the line start.

    A // comment ends the line. A # line is an include or a directive, not an assignment.
    """
    found = []
    offset = 0
    for line in text.splitlines(keepends=True):
        body = line.split("//", 1)[0].strip()
        if body and not body.startswith("#"):
            match = re.match(
                r"^(MARKETING_VERSION|CURRENT_PROJECT_VERSION)\s*=\s*(.*)$",
                body,
            )
            if match:
                found.append((match.group(1), match.group(2).strip(), offset))
        offset += len(line)
    return found


def local_include_offset(text):
    offset = 0
    for line in text.splitlines(keepends=True):
        if line.split("//", 1)[0].strip() == LOCAL_INCLUDE:
            return offset
        offset += len(line)
    return None


def version_report(base_text, other_texts, info_text, project_text, generator_text):
    """Return (failures, marketing, build). Does not print and does not write.

    other_texts is a list of (label, text) for every xcconfig except Base.
    Values from those files are not copied into failure text.
    """
    failures = []
    include = local_include_offset(base_text)
    assignments = xcconfig_version_assignments(base_text)
    if include is not None:
        late = []
        for key, _value, offset in assignments:
            if offset > include and key not in late:
                late.append(key)
        if late:
            failures.append(
                "version is assigned after the Local.xcconfig include in Config/Base.xcconfig: "
                + ", ".join(late)
            )
    values = {key: [] for key in VERSION_KEYS}
    for key, value, _offset in assignments:
        values[key].append(value)
    for key in VERSION_KEYS:
        if len(values[key]) != 1:
            failures.append(key + " must be assigned once in Config/Base.xcconfig")
    marketing = values["MARKETING_VERSION"][0] if len(values["MARKETING_VERSION"]) == 1 else None
    build = values["CURRENT_PROJECT_VERSION"][0] if len(values["CURRENT_PROJECT_VERSION"]) == 1 else None
    if marketing is not None and MARKETING_VALUE.fullmatch(marketing) is None:
        failures.append("MARKETING_VERSION is not major.minor.patch")
        marketing = None
    if build is not None and BUILD_VALUE.fullmatch(build) is None:
        failures.append("CURRENT_PROJECT_VERSION is not a positive integer")
        build = None
    for label, text in other_texts:
        extra = sorted({key for key, _value, _offset in xcconfig_version_assignments(text)})
        if extra:
            failures.append(label + " assigns " + ", ".join(extra))
    for key in ("CFBundleShortVersionString", "CFBundleVersion"):
        if key in info_text:
            failures.append(key + " is present in Config/Info.plist")
    present = [key for key in VERSION_KEYS if key in project_text]
    if present:
        failures.append(
            "version build setting is present in Questify.xcodeproj/project.pbxproj: "
            + ", ".join(present)
        )
    present = [key for key in VERSION_KEYS if key in generator_text]
    if present:
        failures.append(
            "version build setting is named in tools/generate_project.py: " + ", ".join(present)
        )
    if failures:
        return failures, None, None
    return [], marketing, build


def read_regular_text(path, failures):
    relative = str(path.relative_to(ROOT))
    if path.is_symlink():
        failures.append(relative + " is a symlink")
        return None
    if not path.is_file():
        failures.append(relative + " is not a regular file")
        return None
    try:
        return path.read_text()
    except OSError:
        failures.append(relative + " is unreadable")
        return None


def check_version(failures):
    """Report the committed pair. Refuse a second source. Do not bump the numbers."""
    before = len(failures)
    config_dir = ROOT / "Config"
    if config_dir.is_symlink() or not config_dir.is_dir():
        failures.append("Config is not a regular directory")
        return
    base_text = read_regular_text(config_dir / "Base.xcconfig", failures)
    other_texts = []
    for path in sorted(config_dir.iterdir()):
        if path.name == "Base.xcconfig" or not path.name.endswith(".xcconfig"):
            continue
        if path.is_symlink():
            failures.append(str(path.relative_to(ROOT)) + " is a symlink")
            continue
        if not path.is_file():
            continue
        text = read_regular_text(path, failures)
        if text is None:
            continue
        other_texts.append((str(path.relative_to(ROOT)), text))
    info_text = read_regular_text(ROOT / "Config" / "Info.plist", failures)
    project_text = read_regular_text(ROOT / "Questify.xcodeproj" / "project.pbxproj", failures)
    generator_text = read_regular_text(ROOT / "tools" / "generate_project.py", failures)
    if None in (base_text, info_text, project_text, generator_text) or len(failures) != before:
        return
    report, marketing, build = version_report(
        base_text, other_texts, info_text, project_text, generator_text
    )
    failures.extend(report)
    if marketing is None or build is None:
        return
    print("marketing version: " + marketing)
    print("build: " + build)
    print("version source: Config/Base.xcconfig")


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
    check_version(failures)
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

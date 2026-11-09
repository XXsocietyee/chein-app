#!/usr/bin/env python3
"""Read the account-deletion path. Do not delete an account.

This process does not open a socket and does not call the deregister apply
route. Exit 0 means the settings row is present and the shipped composition
leaves that route gated off.
"""
import json
import pathlib
import re
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(line_buffering=True)
    sys.stderr.reconfigure(line_buffering=True)

ROOT = pathlib.Path(__file__).resolve().parents[1]

# Search needle only. This script never requests the path.
APPLY_PATH = "api/user/deregister/apply"


def read(relative):
    return (ROOT / relative).read_text()


def composition_body(source):
    match = re.search(
        r"@MainActor static var composition: AppCompositionRoot \{\n(?P<body>.*?)\n    \}",
        source,
        re.S,
    )
    if match is None:
        return None
    return match.group("body")


def check():
    failures = []
    launch = read("App/RegionalLaunchConfiguration.swift")
    body = composition_body(launch)
    if body is None:
        failures.append("composition property not found")
        body = ""
    elif body.count("makeComposition(reviewed: nil, build: .current)") != 1:
        failures.append("shipped composition is not makeComposition(reviewed: nil, build: .current)")
    if "reviewedComposition" in body or "reviewedMarketComposition" in body or "productionGatesEnabled" in body:
        failures.append("composition property selects a reviewed deployment")

    root = read("App/AppCompositionRoot.swift")
    gate = re.search(
        r"var isAccountComplianceEnabled: Bool \{\s*"
        r"reviewed\?\.productionGatesEnabled == true && reviewed\?\.regional\.market == \.china\s*\}",
        root,
    )
    if gate is None:
        failures.append("account compliance is not limited to China production gates")
    apply_guard = (
        "AccountComplianceCompositionRoute.accepts(request, baseURL: api.baseURL, token: captured.token) {\n"
        "            guard deployment.productionGatesEnabled, deployment.regional.market == .china,"
    )
    if apply_guard not in root:
        failures.append("deregister route is not behind the China production-gate guard")
    if APPLY_PATH not in root:
        failures.append("deregister apply path is missing from the composition route")

    session = read("App/AppSession.swift")
    if "guard let configuration = regionalConfiguration?.apiConfiguration, let authChannelService," not in session:
        failures.append("coordinator no longer requires an API configuration")
    if "readsEnabled: false, writesEnabled: false" not in session:
        failures.append("unreviewed compliance service no longer keeps writes off")

    regional = read("Core/RegionalConfiguration.swift")
    if "if value.isEmpty {\n            apiConfiguration = nil" not in regional:
        failures.append("empty base URL no longer leaves apiConfiguration nil")

    support = read("App/SettingsSupportSections.swift")
    if not re.search(
        r"if let complianceCoordinator \{\s*AccountComplianceSettingsSection\(",
        support,
    ):
        failures.append("settings no longer uses the coordinator when one exists")
    if not re.search(
        r"\} else \{\s*Section\(\"settingsNative\.privacy\.title\"\) \{\s*"
        r"ForEach\(SettingsUnavailableFeature\.allCases\)",
        support,
    ):
        failures.append("missing coordinator no longer shows the blocked settings rows")
    if "feature == .accountDeletion ? .cancellationNotice : .privacyPolicy" not in support:
        failures.append("blocked account-deletion row no longer opens the cancellation notice")

    features = read("Core/SettingsAboutContracts.swift")
    if "case locationConsent, marketingConsent, accountDeletion" not in features:
        failures.append("accountDeletion is not a blocked settings feature")

    catalog = json.loads(read("Resources/Localizable.xcstrings"))
    title = catalog["strings"]["settingsNative.blocked.accountDeletion.title"]["localizations"]
    message = catalog["strings"]["settingsNative.blocked.accountDeletion.message"]["localizations"]
    if title["en"]["stringUnit"]["value"] != "Account cancellation":
        failures.append("blocked account-deletion title changed")
    if title["zh-Hans"]["stringUnit"]["value"] != "账号注销":
        failures.append("blocked account-deletion Chinese title changed")
    english_message = message["en"]["stringUnit"]["value"]
    chinese_message = message["zh-Hans"]["stringUnit"]["value"]
    if "can't be requested" not in english_message:
        failures.append("blocked account-deletion message no longer refuses a request")
    if "暂不能" not in chinese_message or "注销" not in chinese_message:
        failures.append("blocked account-deletion Chinese message no longer refuses a request")

    navigation = read("Core/NativeNavigationCompletion.swift") + read("Core/NativeEntryRouting.swift")
    if APPLY_PATH in navigation or "deregister" in navigation:
        failures.append("an inbound navigation path names account deletion")

    return failures


def main(argv):
    refused = [arg for arg in argv[1:] if arg.startswith("-")]
    if refused:
        print("refusing arguments; this check does not delete an account", file=sys.stderr)
        return 2
    failures = check()
    if failures:
        for item in failures:
            print("FAIL:", item)
        print("deleted an account: no")
        return 1
    print("account-deletion path: present")
    print("shipped composition: makeComposition(reviewed: nil, build: .current)")
    print("apply route: gated (China production gates only)")
    print("settings row: blocked when the coordinator is nil")
    print("deleted an account: no")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

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
CHINA_HOST = "https://www.chengyinhub.com/prod-api/"
XCCONFIG_HOST = "https:/$()/www.chengyinhub.com/prod-api/"
CHINA_REALM = "cn-prod"
NIL_COMPOSITION = "makeComposition(reviewed: nil, build: .current)"


def read(relative):
    return (ROOT / relative).read_text()


def brace_body(source, signature, opener="{"):
    start = source.find(signature)
    if start < 0:
        return None
    brace = source.find(opener, start)
    if brace < 0:
        return None
    brace = brace + opener.rfind("{")
    depth = 0
    for index in range(brace, len(source)):
        char = source[index]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return source[brace + 1:index]
    return None


def last_assignment(text, key):
    found = None
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#") or stripped.startswith("//"):
            continue
        name, sep, value = stripped.partition("=")
        if sep and name.strip() == key:
            found = value.strip()
    return found


def check_shipped_composition(failures):
    """Accept shippedComposition only while an empty URL or realm stays unconfigured.

    The composition property itself must not select a reviewed deployment. China is
    admitted only by admitsShippedChina: market China, the reviewed host, and a
    bundle plus realm that can form a storage scope.
    """
    launch = read("App/RegionalLaunchConfiguration.swift")
    body = brace_body(launch, "@MainActor static var composition: AppCompositionRoot")
    if body is None:
        failures.append("composition property not found")
        body = ""
    elif body.count("shippedComposition(build: .current)") != 1:
        failures.append("composition property does not call shippedComposition(build: .current) once")
    if "makeComposition(" in body or "reviewedComposition" in body or "reviewedMarketComposition" in body or "productionGatesEnabled" in body:
        failures.append("composition property selects a reviewed deployment")
    if "https://" in body or CHINA_HOST in launch:
        failures.append("launch configuration names a host literal")

    shipped = brace_body(launch, "@MainActor static func shippedComposition(", ") -> AppCompositionRoot {")
    if shipped is None:
        failures.append("shippedComposition not found")
        shipped = ""
    else:
        guard = (
            "        let base = build.baseURL ?? \"\"\n"
            "        let bundle = build.bundleIdentifier ?? \"\"\n"
            "        let realm = build.realm ?? \"\"\n"
            "        guard let market, ReviewedMarketLaunch.admitsShippedChina(\n"
            "            market: market, baseURL: base, bundleIdentifier: bundle, realm: realm\n"
            "        ) else {\n"
            "            return makeComposition(reviewed: nil, build: .current)\n"
            "        }"
        )
        if guard not in shipped:
            failures.append("empty URL or realm no longer uses makeComposition(reviewed: nil, build: .current)")
        if shipped.count(NIL_COMPOSITION) != 1:
            failures.append("shippedComposition does not keep exactly one unconfigured composition")
        reviewed_at = shipped.find("reviewedComposition(")
        nil_at = shipped.find(NIL_COMPOSITION)
        if reviewed_at < 0 or nil_at < 0 or nil_at > reviewed_at:
            failures.append("unconfigured composition is not the failure path before a reviewed composition")
        if "reviewedMarketComposition" in shipped or "productionGatesEnabled" in shipped or "https://" in shipped:
            failures.append("shippedComposition selects a market composition or names a host")

    admits = brace_body(read("Core/RegionalConfiguration.swift"), "public static func admitsShippedChina(")
    if admits is None:
        failures.append("admitsShippedChina not found")
    elif (
        "guard market == .china, base == chinaProductionBaseURL else { return false }" not in admits
        or "return (try? storageScope(market: market, baseURL: base, bundleIdentifier: bundle, realm: realm)) != nil" not in admits
    ):
        failures.append("China host is not limited to market China with a bundle and realm")
    regional = read("Core/RegionalConfiguration.swift")
    if f'public static let chinaProductionBaseURL = "{CHINA_HOST}"' not in regional:
        failures.append("China host string changed")

    china = read("Config/China.Production.xcconfig")
    if last_assignment(china, "QUESTIFY_API_BASE_URL") != XCCONFIG_HOST:
        failures.append("China production xcconfig host is not the reviewed host")
    if last_assignment(china, "QUESTIFY_SESSION_REALM") != CHINA_REALM:
        failures.append("China production realm is not cn-prod")
    base = read("Config/Base.xcconfig")
    united = read("Config/UnitedStates.Production.xcconfig")
    if last_assignment(base, "QUESTIFY_API_BASE_URL") != "" or last_assignment(base, "QUESTIFY_SESSION_REALM") != "":
        failures.append("default build URL or realm is no longer empty")
    if "chengyinhub.com" in base or CHINA_HOST in base:
        failures.append("default build names the China host")
    if last_assignment(united, "QUESTIFY_API_BASE_URL") != "" or last_assignment(united, "QUESTIFY_SESSION_REALM") != "":
        failures.append("United States production URL or realm is no longer empty")
    if "chengyinhub.com" in united:
        failures.append("United States production names a reviewed host")
    project = read("Questify.xcodeproj/project.pbxproj")
    if "Config/Base.xcconfig" not in project or "China.Production.xcconfig" in project:
        failures.append("default project does not stay on the empty Base.xcconfig")


def check():
    failures = []
    check_shipped_composition(failures)

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
    print("shipped composition: shippedComposition(build: .current)")
    print("empty URL or realm: makeComposition(reviewed: nil, build: .current)")
    print("china host: admitted only for market China with a bundle and realm")
    print("apply route: gated (China production gates only)")
    print("settings row: blocked when the coordinator is nil")
    print("deleted an account: no")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

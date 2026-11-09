#!/usr/bin/env python3
"""Keep one Xcode Cloud checkout unsigned. Does not run xcodebuild.

Edits that checkout only when CI_XCODE_CLOUD=TRUE and --checkout is set.
Does not change MARKETING_VERSION or CURRENT_PROJECT_VERSION.
Does not set a team, a bundle id, or an API URL.
Does not sign, upload, or submit.
"""
import os
import pathlib
import re
import sys

LOCKED = (
    "MARKETING_VERSION",
    "CURRENT_PROJECT_VERSION",
    "DEVELOPMENT_TEAM",
    "IPHONEOS_DEPLOYMENT_TARGET",
    "PRODUCT_BUNDLE_IDENTIFIER",
    "QUESTIFY_API_BASE_URL",
)
LOCAL_XCCONFIG = """// CB45 unsigned archive override. Xcode Cloud checkout only.
// Does not set a version, a team, a bundle id, or an API URL.
CODE_SIGNING_ALLOWED = NO
CODE_SIGNING_REQUIRED = NO
CODE_SIGN_IDENTITY =
AD_HOC_CODE_SIGNING_ALLOWED = NO
"""
APP_UNIT_SUFFIX = (
    "CODE_SIGNING_ALLOWED = NO\n"
    "CODE_SIGNING_REQUIRED = NO\n"
    "CODE_SIGN_IDENTITY =\n"
    "AD_HOC_CODE_SIGNING_ALLOWED = NO\n"
)
BLOCK = re.compile(
    r'^(?P<indent>[ \t]*)(?P<key>"buildSettings"|buildSettings) = \{\n',
    re.M,
)


def fail(message):
    print(message, file=sys.stderr)
    return 2


def locked_lines(text):
    found = []
    for line in text.splitlines():
        if any(key in line for key in LOCKED):
            found.append(line)
    return tuple(found)


def ensure_unsigned(body, quoted):
    if "CODE_SIGNING_ALLOWED" in body:
        if "CODE_SIGNING_ALLOWED = YES" in body or '"CODE_SIGNING_ALLOWED" = "YES"' in body:
            raise ValueError("refusing a build settings block that allows signing")
        if "CODE_SIGNING_REQUIRED = YES" in body or '"CODE_SIGNING_REQUIRED" = "YES"' in body:
            raise ValueError("refusing a build settings block that requires signing")
        return body
    setting_indent = None
    for line in body.splitlines():
        stripped = line.lstrip(" \t")
        if stripped and stripped != "};" and "=" in stripped:
            setting_indent = line[: len(line) - len(stripped)]
            break
    if setting_indent is None:
        raise ValueError("build settings block has no setting line")
    if quoted:
        inserted = (
            f'{setting_indent}"CODE_SIGNING_ALLOWED" = "NO";\n'
            f'{setting_indent}"CODE_SIGNING_REQUIRED" = "NO";\n'
            f'{setting_indent}"CODE_SIGN_IDENTITY" = "";\n'
            f'{setting_indent}"AD_HOC_CODE_SIGNING_ALLOWED" = "NO";\n'
        )
    else:
        inserted = (
            f"{setting_indent}CODE_SIGNING_ALLOWED = NO;\n"
            f"{setting_indent}CODE_SIGNING_REQUIRED = NO;\n"
            f'{setting_indent}CODE_SIGN_IDENTITY = "";\n'
            f"{setting_indent}AD_HOC_CODE_SIGNING_ALLOWED = NO;\n"
        )
    # Keep the closing line, including its indent. Do not split on the characters "};".
    if body.endswith("\n"):
        head, newline, last = body[:-1].rpartition("\n")
        last = last + "\n"
        head = head + newline
    else:
        head, newline, last = body.rpartition("\n")
        if newline:
            head = head + newline
    if last.strip() != "};":
        raise ValueError("build settings block does not end at };")
    return head + inserted + last


def inject(text):
    pieces = []
    cursor = 0
    count = 0
    for match in BLOCK.finditer(text):
        pieces.append(text[cursor:match.end()])
        rest = text[match.end():]
        lines = rest.splitlines(keepends=True)
        taken = []
        for line in lines:
            taken.append(line)
            if line.strip() == "};":
                break
        else:
            raise ValueError("unclosed build settings block")
        body = "".join(taken)
        pieces.append(ensure_unsigned(body, match.group("key").startswith('"')))
        cursor = match.end() + len(body)
        count += 1
    if count == 0:
        raise ValueError("no build settings block")
    pieces.append(text[cursor:])
    updated = "".join(pieces)
    allowed = 0
    for line in updated.splitlines():
        stripped = line.strip()
        if stripped.startswith('"CODE_SIGNING_ALLOWED"') or stripped.startswith("CODE_SIGNING_ALLOWED "):
            allowed += 1
    if allowed != count:
        raise ValueError("signing was not disabled in every build settings block")
    if locked_lines(updated) != locked_lines(text):
        raise ValueError("version, team, bundle, deployment target, or API URL changed")
    return updated, count


def write_local(path):
    if path.exists():
        if path.read_text() != LOCAL_XCCONFIG:
            raise ValueError("refusing to overwrite Config/Local.xcconfig")
        return
    path.write_text(LOCAL_XCCONFIG)


def append_app_unit(path):
    text = path.read_text()
    if "MARKETING_VERSION" in text or "CURRENT_PROJECT_VERSION" in text:
        raise ValueError("refusing to edit a test xcconfig that sets the version pair")
    if "CODE_SIGNING_ALLOWED" in text:
        if not text.endswith(APP_UNIT_SUFFIX) and "CODE_SIGNING_ALLOWED = NO" not in text:
            raise ValueError("test xcconfig already sets signing and is not the unsigned override")
        return
    suffix = "" if text.endswith("\n") else "\n"
    path.write_text(text + suffix + APP_UNIT_SUFFIX)


def prepare(checkout):
    checkout = pathlib.Path(checkout)
    base = checkout / "Config/Base.xcconfig"
    app_unit = checkout / "Config/AppUnitTests.xcconfig"
    projects = (
        checkout / "Questify.xcodeproj/project.pbxproj",
        checkout / "Vendor/GLTFKit2/GLTFKit2.xcodeproj/project.pbxproj",
    )
    for path in (base, app_unit, *projects):
        if not path.is_file():
            raise ValueError("missing " + str(path.relative_to(checkout)))
    before_base = base.read_bytes()
    version = re.findall(
        r"^(MARKETING_VERSION = .+|CURRENT_PROJECT_VERSION = .+)$",
        before_base.decode(),
        re.M,
    )
    if len(version) != 2:
        raise ValueError("Config/Base.xcconfig does not have one version pair")
    for project in projects:
        original = project.read_text()
        updated, _count = inject(original)
        project.write_text(updated)
    write_local(checkout / "Config/Local.xcconfig")
    append_app_unit(app_unit)
    if base.read_bytes() != before_base:
        raise ValueError("Config/Base.xcconfig was modified")
    local = (checkout / "Config/Local.xcconfig").read_text()
    for token in LOCKED:
        if token in local:
            raise ValueError("unsigned override sets " + token)
    print("signing: disabled on temporary checkout")
    print("version: unchanged")
    print("upload: no")
    print("submit: no")


def main(argv):
    joined = " ".join(argv[1:]).lower()
    if any(marker in joined for marker in ("altool", "notarytool", "transporter", "upload", "submit", "-exportarchive")):
        return fail("refusing signing or upload arguments")
    if len(argv) != 3 or argv[1] != "--checkout":
        return fail("usage: xcode_cloud_unsigned_archive.py --checkout <temporary-ci-checkout>")
    if os.environ.get("CI_XCODE_CLOUD") != "TRUE":
        return fail("refusing to edit a checkout outside Xcode Cloud")
    checkout = pathlib.Path(argv[2]).expanduser().resolve()
    if checkout == pathlib.Path(checkout.anchor):
        return fail("refusing the filesystem root")
    try:
        prepare(checkout)
    except ValueError as error:
        return fail(str(error))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

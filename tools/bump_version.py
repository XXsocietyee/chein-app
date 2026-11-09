#!/usr/bin/env python3
"""Read the marketing version and build. Write them only with --apply.

Without --apply this script does not modify Config/Base.xcconfig.
--apply also requires both --marketing and --build. It does not pick a
new pair by itself. This script does not sign, upload, or submit.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
TARGET = ROOT / "Config/Base.xcconfig"
MARKETING = re.compile(r"^MARKETING_VERSION = (\S+)$", re.M)
BUILD = re.compile(r"^CURRENT_PROJECT_VERSION = (\S+)$", re.M)
MARKETING_VALUE = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+$")
BUILD_VALUE = re.compile(r"^[1-9][0-9]{0,8}$")
REFUSED = (
    "upload",
    "submit",
    "altool",
    "notarytool",
    "transporter",
    "development_team",
    "code_sign",
    "provisioning",
    "api_base",
    "http://",
    "https://",
    ".p12",
    ".p8",
    ".mobileprovision",
)


def fail(message):
    print(message, file=sys.stderr)
    return 2


def read_pair(text):
    marketing = MARKETING.findall(text)
    build = BUILD.findall(text)
    if len(marketing) != 1 or len(build) != 1:
        raise ValueError("Config/Base.xcconfig must contain one marketing version and one build")
    return marketing[0], build[0]


def render(text, marketing, build):
    if MARKETING_VALUE.fullmatch(marketing) is None:
        raise ValueError("marketing version must be digits separated by two dots")
    if BUILD_VALUE.fullmatch(build) is None:
        raise ValueError("build must be a positive integer")
    current_marketing, current_build = read_pair(text)
    if text.count("MARKETING_VERSION = " + current_marketing) != 1:
        raise ValueError("marketing version line is not unique")
    if text.count("CURRENT_PROJECT_VERSION = " + current_build) != 1:
        raise ValueError("build line is not unique")
    text = text.replace(
        "MARKETING_VERSION = " + current_marketing,
        "MARKETING_VERSION = " + marketing,
        1,
    )
    text = text.replace(
        "CURRENT_PROJECT_VERSION = " + current_build,
        "CURRENT_PROJECT_VERSION = " + build,
        1,
    )
    if read_pair(text) != (marketing, build):
        raise ValueError("version pair was not written as one line each")
    return text


def parse_args(argv):
    apply = False
    self_check = False
    marketing = None
    build = None
    index = 0
    while index < len(argv):
        arg = argv[index]
        lowered = arg.lower()
        if any(marker in lowered for marker in REFUSED):
            raise ValueError("refusing signing, upload, or URL arguments")
        if arg == "--apply":
            apply = True
        elif arg == "--self-check":
            self_check = True
        elif arg == "--marketing":
            index += 1
            if index >= len(argv):
                raise ValueError("usage: bump_version.py [--apply --marketing X.Y.Z --build N]")
            marketing = argv[index]
        elif arg == "--build":
            index += 1
            if index >= len(argv):
                raise ValueError("usage: bump_version.py [--apply --marketing X.Y.Z --build N]")
            build = argv[index]
        else:
            raise ValueError("usage: bump_version.py [--apply --marketing X.Y.Z --build N]")
        index += 1
    if self_check and (apply or marketing is not None or build is not None):
        raise ValueError("--self-check does not write and takes no version arguments")
    if apply and (marketing is None or build is None):
        raise ValueError("refusing to change Config/Base.xcconfig: --apply needs --marketing and --build")
    if not apply and (marketing is not None or build is not None):
        raise ValueError("refusing to change Config/Base.xcconfig without --apply")
    return apply, self_check, marketing, build


def self_check(text):
    """Exercise the writer in memory. Does not write the file."""
    marketing, build = read_pair(text)
    same = render(text, marketing, build)
    if same != text:
        raise ValueError("rendering the current pair changed the file text")
    bumped = render(text, "0.1.1", "2")
    if read_pair(bumped) != ("0.1.1", "2"):
        raise ValueError("in-memory render did not apply the sample pair")
    if "MARKETING_VERSION = " + marketing not in text:
        raise ValueError("self-check lost the on-disk marketing version")
    print("self-check: in memory only")
    print("changed: no")


def main(argv):
    try:
        apply, check, marketing, build = parse_args(argv[1:])
    except ValueError as error:
        return fail(str(error))
    before = TARGET.read_bytes()
    text = before.decode()
    try:
        current = read_pair(text)
    except ValueError as error:
        return fail(str(error))
    print("MARKETING_VERSION=" + current[0])
    print("CURRENT_PROJECT_VERSION=" + current[1])
    if check:
        try:
            self_check(text)
        except ValueError as error:
            return fail(str(error))
    elif apply:
        try:
            updated = render(text, marketing, build)
        except ValueError as error:
            return fail(str(error))
        if updated != text:
            TARGET.write_text(updated)
            print("changed: yes")
        else:
            print("changed: no")
    else:
        print("changed: no")
    if not apply and TARGET.read_bytes() != before:
        return fail("Config/Base.xcconfig changed without --apply")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

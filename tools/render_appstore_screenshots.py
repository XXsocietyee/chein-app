#!/usr/bin/env python3
"""Render the App Store screenshot pack from existing DEBUG fixtures.

The pack is eight player screens, English and zh-Hans, on the 6.9-inch and
6.5-inch iPhone sizes named in docs/release/appstore-screens.md. Launch
arguments open fixtures that already exist. This script does not add a
network client and does not upload anything.

PNGs go to build/appstore-screenshots/, which is gitignored. They are not
committed. When xcodebuild or a required simulator is missing, the script
exits 2 and says the screenshots were not rendered.
"""
import argparse
import json
import plistlib
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HARNESS = ROOT / "App/DesignFixtures/AppStoreScreenshotHarness.swift"
REGISTRY = ROOT / "App/DesignFixtures/DesignFixtureRegistry.swift"
DOC = ROOT / "docs/release/appstore-screens.md"
DEFAULT_OUTPUT = ROOT / "build/appstore-screenshots"
DERIVED = ROOT / "build/appstore-screenshots-derived"
SCHEME_TARGET = "Questify"
PROJECT = ROOT / "Questify.xcodeproj"
BUNDLE_FALLBACK = "invalid.example.questify.ios"
SETTLE_SECONDS = 4

# Apple App Store Connect slots. Do not substitute a different pixel size.
DEVICES = (
    {
        "slot": "6.9-inch",
        "pixels": "1320 × 2868",
        "names": ("iPhone 16 Pro Max",),
    },
    {
        "slot": "6.5-inch",
        "pixels": "1242 × 2688",
        "names": ("iPhone 11 Pro Max", "iPhone XS Max"),
    },
)
LANGUAGES = (
    {
        "id": "en",
        "apple_languages": "(en)",
        "apple_locale": "en_US",
    },
    {
        "id": "zh-Hans",
        "apple_languages": "(zh-Hans)",
        "apple_locale": "zh_Hans",
    },
)
SCREEN_LINE = re.compile(
    r'\.init\(id: "([^"]+)", title: "([^"]+)", fixtureID: "([^"]+)"\)'
)
NOT_RENDERED = "App Store screenshots were not rendered."


class RenderStop(Exception):
    def __init__(self, message, code):
        super().__init__(message)
        self.code = code


def screens_from_harness():
    text = HARNESS.read_text()
    found = SCREEN_LINE.findall(text)
    if len(found) != 8:
        raise RenderStop(
            f"{HARNESS.relative_to(ROOT)} must list exactly 8 screens; found {len(found)}. {NOT_RENDERED}",
            1,
        )
    screens = [{"id": item[0], "title": item[1], "fixture_id": item[2]} for item in found]
    ids = [item["id"] for item in screens]
    if len(ids) != len(set(ids)):
        raise RenderStop(f"Duplicate screenshot id. {NOT_RENDERED}", 1)
    return screens


def check_catalog(screens):
    registry = REGISTRY.read_text()
    doc = DOC.read_text()
    missing = []
    for device in DEVICES:
        if device["slot"] not in doc or device["pixels"] not in doc:
            missing.append(f'{device["slot"]} {device["pixels"]}')
        if device["names"][0] not in doc:
            missing.append(device["names"][0])
    for screen in screens:
        needle = f'case "{screen["fixture_id"]}"'
        if needle not in registry:
            missing.append(f'registry {needle}')
        for token in (screen["id"], screen["title"], screen["fixture_id"]):
            if token not in doc:
                missing.append(f'doc {token}')
    for language in LANGUAGES:
        if language["id"] not in doc:
            missing.append(f'doc language {language["id"]}')
    if missing:
        detail = ", ".join(missing)
        raise RenderStop(f"Screenshot catalog does not match the repo: {detail}. {NOT_RENDERED}", 1)


def tool_path(name):
    return shutil.which(name)


def stop_unavailable(message):
    raise RenderStop(f"{message} {NOT_RENDERED}", 2)


def run(argv, cwd=None, check=True):
    completed = subprocess.run(argv, cwd=cwd, text=True, capture_output=True)
    if check and completed.returncode != 0:
        detail = (completed.stderr or completed.stdout or "").strip()
        tail = detail[-2000:] if detail else f"exit {completed.returncode}"
        raise RenderStop(f"{argv[0]} failed: {tail}\n{NOT_RENDERED}", 1)
    return completed


def simctl_json(*args):
    completed = run(["xcrun", "simctl", *args, "-j"])
    try:
        return json.loads(completed.stdout)
    except json.JSONDecodeError as error:
        raise RenderStop(f"simctl {' '.join(args)} did not return JSON ({error}). {NOT_RENDERED}", 2) from error


def require_toolchain():
    if tool_path("xcodebuild") is None:
        stop_unavailable("xcodebuild is not on PATH.")
    if tool_path("xcrun") is None:
        stop_unavailable("xcrun is not on PATH.")
    version = subprocess.run(["xcodebuild", "-version"], text=True, capture_output=True)
    if version.returncode != 0:
        detail = (version.stderr or version.stdout or "xcodebuild -version failed").strip()
        stop_unavailable(f"xcodebuild is unavailable ({detail}).")
    probe = subprocess.run(["xcrun", "simctl", "help"], text=True, capture_output=True)
    if probe.returncode != 0:
        detail = (probe.stderr or probe.stdout or "simctl help failed").strip()
        stop_unavailable(f"The iOS Simulator (xcrun simctl) is unavailable ({detail}).")


def newest_runtime(payload):
    runtimes = [item for item in payload.get("runtimes", []) if item.get("isAvailable")]
    ios = [item for item in runtimes if str(item.get("platform", "")).startswith("iOS") or str(item.get("name", "")).startswith("iOS")]
    if not ios:
        stop_unavailable("No available iOS Simulator runtime is installed.")
    def sort_key(item):
        version = str(item.get("version", "0"))
        parts = []
        for piece in version.split("."):
            try:
                parts.append(int(piece))
            except ValueError:
                parts.append(0)
        return parts
    ios.sort(key=sort_key)
    return ios[-1]


def device_type_id(payload, names):
    by_name = {item.get("name"): item.get("identifier") for item in payload.get("devicetypes", [])}
    for name in names:
        identifier = by_name.get(name)
        if identifier:
            return name, identifier
    joined = ", ".join(names)
    stop_unavailable(f"None of these simulator device types are installed: {joined}.")


def build_app():
    if DERIVED.exists():
        shutil.rmtree(DERIVED)
    print("Building Questify Debug for the iOS Simulator. This does not upload or sign for the store.", flush=True)
    completed = subprocess.run(
        [
            "xcodebuild",
            "-project", str(PROJECT),
            "-target", SCHEME_TARGET,
            "-configuration", "Debug",
            "-sdk", "iphonesimulator",
            "-derivedDataPath", str(DERIVED),
            "CODE_SIGNING_ALLOWED=NO",
            "build",
        ],
        cwd=ROOT,
        text=True,
        capture_output=True,
    )
    if completed.returncode != 0:
        tail = (completed.stdout or "")[-2500:]
        raise RenderStop(f"The Debug simulator build failed.\n{tail}\n{NOT_RENDERED}", 1)
    products = DERIVED / "Build/Products/Debug-iphonesimulator/Questify.app"
    if not products.is_dir():
        raise RenderStop(f"Debug build did not produce {products}. {NOT_RENDERED}", 1)
    return products


def bundle_identifier(app):
    info = app / "Info.plist"
    if not info.is_file():
        return BUNDLE_FALLBACK
    with info.open("rb") as handle:
        payload = plistlib.load(handle)
    return payload.get("CFBundleIdentifier") or BUNDLE_FALLBACK


def png_ok(path):
    if not path.is_file() or path.stat().st_size < 1024:
        return False
    header = path.read_bytes()[:8]
    return header == b"\x89PNG\r\n\x1a\n"


def launch_arguments(screen, language):
    return [
        "--appstore-screenshot", screen["id"],
        "--appstore-screenshot-language", language["id"],
        "-preferences.language", language["id"],
        "-AppleLanguages", language["apple_languages"],
        "-AppleLocale", language["apple_locale"],
    ]


def capture(app, screens, output):
    if output.exists():
        shutil.rmtree(output)
    output.mkdir(parents=True)
    types = simctl_json("list", "devicetypes")
    runtimes = simctl_json("list", "runtimes")
    runtime = newest_runtime(runtimes)
    runtime_id = runtime.get("identifier")
    if not runtime_id:
        stop_unavailable("The selected iOS Simulator runtime has no identifier.")
    identifier = bundle_identifier(app)
    created = []
    try:
        for device in DEVICES:
            name, type_id = device_type_id(types, device["names"])
            sim_name = f"Questify App Store {device['slot']}"
            created_run = run(["xcrun", "simctl", "create", sim_name, type_id, runtime_id])
            udid = created_run.stdout.strip()
            if not udid:
                stop_unavailable(f"simctl create did not return a UDID for {name}.")
            created.append(udid)
            run(["xcrun", "simctl", "boot", udid])
            subprocess.run(["xcrun", "simctl", "bootstatus", udid, "-b"], check=False, text=True, capture_output=True)
            subprocess.run(
                ["xcrun", "simctl", "status_bar", udid, "override",
                 "--time", "9:41", "--batteryState", "charged", "--batteryLevel", "100",
                 "--wifiBars", "3", "--cellularMode", "active", "--cellularBars", "4"],
                check=False, text=True, capture_output=True,
            )
            run(["xcrun", "simctl", "install", udid, str(app)])
            for language in LANGUAGES:
                for screen in screens:
                    destination = output / device["slot"] / language["id"] / f'{screen["id"]}.png'
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    subprocess.run(["xcrun", "simctl", "terminate", udid, identifier], check=False, text=True, capture_output=True)
                    run(["xcrun", "simctl", "launch", "--terminate-running-process", udid, identifier, *launch_arguments(screen, language)])
                    time.sleep(SETTLE_SECONDS)
                    run(["xcrun", "simctl", "io", udid, "screenshot", str(destination)])
                    if not png_ok(destination):
                        raise RenderStop(f"Screenshot file is missing or not a PNG: {destination}. {NOT_RENDERED}", 1)
                    print(f"wrote {destination.relative_to(ROOT)} on {name}", flush=True)
    finally:
        for udid in created:
            subprocess.run(["xcrun", "simctl", "shutdown", udid], check=False, text=True, capture_output=True)
            subprocess.run(["xcrun", "simctl", "delete", udid], check=False, text=True, capture_output=True)


def expected_count(screens):
    return len(screens) * len(DEVICES) * len(LANGUAGES)


def main(argv):
    parser = argparse.ArgumentParser(description="Render DEBUG App Store screenshots. Does not commit PNGs.")
    parser.add_argument("--check", action="store_true", help="Check the fixture catalog and exit. Does not render.")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT, help="PNG directory. Default is gitignored.")
    args = parser.parse_args(argv)
    try:
        screens = screens_from_harness()
        check_catalog(screens)
        if args.check:
            print(f"Catalog check passed for {len(screens)} screens, {len(DEVICES)} sizes, {len(LANGUAGES)} languages. {NOT_RENDERED}")
            return 0
        require_toolchain()
        app = build_app()
        capture(app, screens, args.output)
        written = list(args.output.rglob("*.png"))
        if len(written) != expected_count(screens) or not all(png_ok(path) for path in written):
            raise RenderStop(f"Expected {expected_count(screens)} PNG files. {NOT_RENDERED}", 1)
        print(f"Rendered {len(written)} App Store screenshots under {args.output}.")
        print("These PNGs are not committed. Do not add them to git.")
        return 0
    except RenderStop as error:
        print(error, file=sys.stderr)
        return error.code


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

#!/usr/bin/env python3
"""Helpers for .github/workflows/acceptance.yml.

The AppUnit class split matches .github/workflows/ios-ci.yml. Failing test
names come from XCTest lines ``Test Case '-[Target.Class testMethod]' failed``.
Screenshot routes come only from docs/port/accept/*.txt and launch through the
app's existing DEBUG fixture arguments (``--design-fixture <name>``, or a line
that already starts with ``--``).

Record mode is the branch ``ci/baseline-record``. It appends one known contract
ratchet id and does not rewrite that baseline. Every other branch is check mode.
"""
import argparse
import json
import plistlib
import re
import shlex
import subprocess
import sys
import time
from pathlib import Path

ANSI = re.compile(r"\x1b\[[0-9;]*m")
XCTEST_FAILED = re.compile(r"Test Case '-\[([^\]]+)\]' failed")
BUNDLE_FALLBACK = "invalid.example.questify.ios"
PREFERRED_SIMULATORS = ("iPhone 18 Pro", "iPhone 17 Pro")
ACCEPT_UI_ROOT = Path("Tests/AppUITests/Accept")
# The one contract-ratchet failure RECORD may add. Do not replace the file.
KNOWN_CONTRACT_FAILURE = "test_workshop_paid_professional.PaidProfessionalContracts.test_current_generic_draft_cas_reuses_real_reader_with_bounded_paging"


def xctest_classes(root):
    """XCTestCase subclass names under ``root``, sorted and unique.

    The name is the identifier after ``class``, so ``@MainActor final class`` counts.
    Comment lines are ignored. A missing directory yields an empty list.
    """
    classes = []
    if not root.is_dir():
        return classes
    for path in root.rglob("*.swift"):
        for line in path.read_text(errors="replace").splitlines():
            text = line.strip()
            if "XCTestCase" not in text or text.startswith(("//", "*", "/*")):
                continue
            parts = text.split()
            if "class" not in parts:
                continue
            name = parts[parts.index("class") + 1].split("(")[0].split(":")[0].split("{")[0]
            if name:
                classes.append(name)
    return sorted(set(classes))


def only_testing_args(shard):
    """Four-way split used by ios-ci.yml: sorted class names, index % 4.

    ios-ci.yml takes token 2 of lines that start with ``class`` or ``final class``.
    On this tree that misses ``@MainActor final class`` and names every ``final class``
    ``class``, so shards 2 and 3 are empty. The name is the identifier after ``class``.
    The scheme, ``-only-testing:QuestifyAppUnitTests/<Class>``, and the 4-way split stay.
    """
    if shard not in (0, 1, 2, 3):
        raise SystemExit(f"shard {shard} is outside 0..3")
    classes = xctest_classes(Path("Tests/AppUnitTests"))
    if not classes:
        raise SystemExit("no AppUnit classes found")
    mine = [name for index, name in enumerate(classes) if index % 4 == shard]
    if not mine:
        raise SystemExit(f"shard {shard} is empty")
    return " ".join(f"-only-testing:QuestifyAppUnitTests/{name}" for name in mine)


def ui_smoke_needed(root=None):
    """True when Accept/ exists and declares at least one XCTestCase."""
    return bool(xctest_classes(ACCEPT_UI_ROOT if root is None else root))


def write_ui_smoke_args(root, out_path):
    classes = xctest_classes(root)
    if not classes:
        raise SystemExit(f"no XCUITest classes under {root}")
    text = " ".join(f"-only-testing:QuestifyUITests/{name}" for name in classes)
    out_path.write_text(text + "\n")
    print(text)
    return text


def record_known_contract_failure(path):
    """Append the one known contract failure. Never blank or rewrite the file."""
    if not path.is_file():
        raise SystemExit(f"contract ratchet baseline missing: {path}")
    original = path.read_text()
    if not original.strip():
        raise SystemExit(f"refusing to write a blank contract ratchet baseline: {path}")
    names = [line.strip() for line in original.splitlines() if line.strip()]
    if KNOWN_CONTRACT_FAILURE in names:
        print(f"acceptance: known contract failure already in {path} ({len(names)} names)")
        return 0
    text = original
    if not text.endswith("\n"):
        text += "\n"
    text += KNOWN_CONTRACT_FAILURE + "\n"
    path.write_text(text)
    print(f"acceptance: added known contract failure to {path} ({len(names) + 1} names)")
    return 0


def normalize_xctest(identifier):
    module_class, method = identifier.rsplit(" ", 1)
    return f"{module_class}/{method}"


def failures_from_log(path):
    names = []
    if not path.is_file():
        return names
    with path.open(errors="replace") as handle:
        for line in handle:
            line = ANSI.sub("", line)
            match = XCTEST_FAILED.search(line)
            if match:
                names.append(normalize_xctest(match.group(1)))
    return names


def tests_ran(log_path):
    if not log_path.is_file():
        return False
    with log_path.open(errors="replace") as handle:
        for line in handle:
            line = ANSI.sub("", line)
            if "Test Case '-[" in line or "Executed " in line or "** TEST SUCCEEDED **" in line or "** TEST FAILED **" in line:
                return True
    return False


def read_exit_code(path):
    if not path.is_file():
        return None
    text = path.read_text(errors="replace").strip()
    try:
        return int(text)
    except ValueError:
        return None


def write_names(path, names):
    unique = sorted(set(names))
    text = "".join(f"{name}\n" for name in unique)
    # A zero-byte file is dropped by upload-artifact. One blank line still means no names.
    path.write_text(text or "\n")
    return unique


def read_names(path):
    if not path.is_file():
        return []
    return [line.strip() for line in path.read_text(errors="replace").splitlines() if line.strip()]


def collect(log_path, exit_path, failures_out, status_out):
    exit_code = read_exit_code(exit_path)
    ran = exit_code == 0 or tests_ran(log_path)
    names = failures_from_log(log_path) if ran else []
    write_names(failures_out, names)
    if ran:
        status_out.write_text("ran\n")
        print(f"acceptance: tests ran, exit {exit_code}, {len(set(names))} failing names")
        return 0
    status_out.write_text(f"build-failed\nexit {exit_code}\n")
    print(f"acceptance: build or test runner failed before tests executed (exit {exit_code})")
    return 1


def gate(mode, baseline_path, failure_paths, status_paths, record_path, expected_statuses):
    if mode not in ("check", "record"):
        raise SystemExit(f"unknown acceptance mode {mode!r}")
    if expected_statuses:
        found = list(status_paths)
        if len(found) != expected_statuses:
            raise SystemExit(f"expected {expected_statuses} shard status files, found {len(found)}")
    for status_path in status_paths:
        if not status_path.is_file():
            raise SystemExit(f"missing status file {status_path}")
        state = status_path.read_text(errors="replace").splitlines()[0].strip()
        if state != "ran":
            raise SystemExit(f"tests did not run ({status_path}: {state})")
    observed = []
    for path in failure_paths:
        observed.extend(read_names(path))
    observed = sorted(set(observed))
    if record_path is not None:
        write_names(record_path, observed)
    print(f"acceptance: observed {len(observed)} failing names")
    if mode == "record":
        print("acceptance: record mode does not fail on these test names")
        return 0
    if not baseline_path.is_file():
        raise SystemExit(f"baseline missing: {baseline_path}")
    baseline = set(read_names(baseline_path))
    new = [name for name in observed if name not in baseline]
    passing = sorted(baseline - set(observed))
    for name in new:
        print(f"NEW FAILURE (not in baseline): {name}")
    for name in passing:
        print(f"NOW PASSING (kept in baseline): {name}")
    print(f"acceptance: observed {len(observed)}, baseline {len(baseline)}, new {len(new)}, now-passing {len(passing)}")
    if new:
        return 1
    return 0


def select_xcode():
    """Print the active Xcode. Do not switch the self-hosted Mac's selection."""
    subprocess.check_call(["xcodebuild", "-version"])


def runtime_key(runtime):
    return tuple(int(part) for part in re.findall(r"\d+", runtime))


def choose_simulator():
    raw = subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"], text=True)
    payload = json.loads(raw)
    rows = []
    for runtime, devices in payload.get("devices", {}).items():
        for device in devices:
            if device.get("isAvailable") is False:
                continue
            name = device.get("name") or ""
            udid = device.get("udid")
            if name.startswith("iPhone") and udid:
                rows.append((runtime, name, udid))
    if not rows:
        raise SystemExit("no available iPhone simulator")
    for wanted in PREFERRED_SIMULATORS:
        matches = [row for row in rows if row[1] == wanted]
        if matches:
            matches.sort(key=lambda row: runtime_key(row[0]))
            return matches[-1]
    rows.sort(key=lambda row: (runtime_key(row[0]), row[1]))
    return rows[-1]


def write_destination(path):
    runtime, name, udid = choose_simulator()
    destination = f"platform=iOS Simulator,id={udid}"
    path.write_text(destination + "\n")
    print(f"Simulator destination: {name} runtime={runtime} id={udid}")
    print(destination)


def udid_from_destination(text):
    for part in text.strip().split(","):
        if part.startswith("id="):
            return part.split("=", 1)[1]
    raise SystemExit(f"destination has no simulator id: {text}")


def routes_from_accept(root):
    """Return fixture route lines. Blank lines and # comments are ignored."""
    routes = []
    for path in sorted(root.glob("*.txt")):
        for line in path.read_text(errors="replace").splitlines():
            stripped = line.strip()
            if not stripped or stripped[0] == "#":
                continue
            routes.append(stripped)
    return routes


def fixture_launch_args(route):
    """Launch args for one DEBUG fixture route. Does not invent routes."""
    if route.startswith("--"):
        return shlex.split(route)
    return ["--design-fixture", route]


def safe_png_name(route, index):
    cleaned = re.sub(r"[^A-Za-z0-9._-]+", "-", route).strip("-") or "route"
    return f"{index:02d}-{cleaned[:80]}.png"


def png_ok(path):
    if not path.is_file() or path.stat().st_size < 1024:
        return False
    return path.read_bytes()[:8] == b"\x89PNG\r\n\x1a\n"


def stream_command(argv, log_path):
    log_path.parent.mkdir(parents=True, exist_ok=True)
    with log_path.open("w") as log:
        proc = subprocess.Popen(argv, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, errors="replace")
        assert proc.stdout is not None
        for line in proc.stdout:
            sys.stdout.write(line)
            log.write(line)
        return proc.wait()


def bundle_identifier(app):
    info = app / "Info.plist"
    if not info.is_file():
        return BUNDLE_FALLBACK
    with info.open("rb") as handle:
        payload = plistlib.load(handle)
    return payload.get("CFBundleIdentifier") or BUNDLE_FALLBACK


def screenshot_needed():
    accept = Path("docs/port/accept")
    if not accept.is_dir() or not any(accept.glob("*.txt")):
        return False
    return bool(routes_from_accept(accept))


def capture_screenshots(destination_file, shots):
    accept = Path("docs/port/accept")
    if not accept.is_dir():
        print("docs/port/accept is missing; skipping screenshots")
        return 0
    files = sorted(accept.glob("*.txt"))
    if not files:
        print("docs/port/accept has no package file; skipping screenshots")
        return 0
    routes = routes_from_accept(accept)
    if not routes:
        print("docs/port/accept package files have no fixture routes; skipping screenshots")
        return 0
    destination = destination_file.read_text(errors="replace").strip()
    udid = udid_from_destination(destination)
    shots.mkdir(parents=True, exist_ok=True)
    derived = Path("DerivedData-screenshots")
    build_log = shots / "debug-build.log"
    xcresult = shots / "build.xcresult"
    command = [
        "xcodebuild", "-project", "Questify.xcodeproj", "-scheme", "Questify",
        "-configuration", "Debug", "-sdk", "iphonesimulator", "-destination", destination,
        "-derivedDataPath", str(derived), "-resultBundlePath", str(xcresult),
        "CODE_SIGNING_ALLOWED=NO", "ARCHS=arm64", "ONLY_ACTIVE_ARCH=YES", "build",
    ]
    print("Building Questify Debug for screenshots")
    if stream_command(command, build_log) != 0:
        print("screenshot build failed")
        return 1
    app = derived / "Build/Products/Debug-iphonesimulator/Questify.app"
    if not app.is_dir():
        print(f"Debug build did not produce {app}")
        return 1
    bundle = bundle_identifier(app)
    subprocess.run(["xcrun", "simctl", "boot", udid], check=False, text=True)
    boot = subprocess.run(["xcrun", "simctl", "bootstatus", udid, "-b"], text=True, timeout=240)
    if boot.returncode != 0:
        print("simulator did not boot")
        return 1
    install = subprocess.run(["xcrun", "simctl", "install", udid, str(app)], text=True)
    if install.returncode != 0:
        print("simctl install failed")
        return 1
    launch_log = shots / "launch.log"
    picture_dir = shots / "screenshots"
    picture_dir.mkdir(parents=True, exist_ok=True)
    failures = []
    with launch_log.open("w") as handle:
        for index, route in enumerate(routes, start=1):
            args = fixture_launch_args(route)
            png = picture_dir / safe_png_name(route, index)
            subprocess.run(["xcrun", "simctl", "terminate", udid, bundle], check=False, text=True)
            launch = subprocess.run(
                ["xcrun", "simctl", "launch", "--terminate-running-process", udid, bundle, *args],
                text=True, capture_output=True,
            )
            handle.write(f"route {route}\nargv {args}\nexit {launch.returncode}\n{launch.stdout}\n{launch.stderr}\n")
            handle.flush()
            if launch.returncode != 0:
                failures.append(route)
                continue
            time.sleep(5)
            shot = subprocess.run(["xcrun", "simctl", "io", udid, "screenshot", str(png)], text=True)
            if shot.returncode != 0 or not png_ok(png):
                time.sleep(3)
                shot = subprocess.run(["xcrun", "simctl", "io", udid, "screenshot", str(png)], text=True)
            if shot.returncode != 0 or not png_ok(png):
                failures.append(route)
                continue
            print(f"wrote {png}")
    if failures:
        print("screenshot failed for routes:")
        for route in failures:
            print(route)
        return 1
    return 0


def self_check():
    import tempfile

    assert normalize_xctest("QuestifyCoreTests.FooTests testBar") == "QuestifyCoreTests.FooTests/testBar"
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        log = root / "test.log"
        log.write_text(
            "Test Case '-[QuestifyCoreTests.FooTests testBar]' failed (0.001 seconds).\n"
            "Test Case '-[QuestifyAppUnitTests.Other testOk]' passed (0.001 seconds).\n"
            "\x1b[31mTest Case '-[QuestifyCoreTests.FooTests testBaz]' failed (0.002 seconds).\x1b[0m\n"
            "Executed 3 tests, with 2 failures (0 unexpected) in 0.1 seconds\n"
        )
        found = failures_from_log(log)
        assert found == [
            "QuestifyCoreTests.FooTests/testBar",
            "QuestifyCoreTests.FooTests/testBaz",
        ], found
        assert tests_ran(log)
        exit_path = root / "exit.txt"
        exit_path.write_text("65\n")
        failures = root / "failures.txt"
        status = root / "status.txt"
        assert collect(log, exit_path, failures, status) == 0
        assert status.read_text().splitlines()[0] == "ran"
        try:
            gate("check", root / "missing.txt", [failures], [status], None, 0)
            raise AssertionError("missing baseline must fail check")
        except SystemExit as error:
            assert "baseline missing" in str(error)
        baseline = root / "baseline.txt"
        baseline.write_text("QuestifyCoreTests.FooTests/testBar\nQuestifyCoreTests.FooTests/testOld\n")
        assert gate("check", baseline, [failures], [status], None, 0) == 1
        baseline.write_text(
            "QuestifyCoreTests.FooTests/testBar\nQuestifyCoreTests.FooTests/testBaz\nQuestifyCoreTests.FooTests/testOld\n"
        )
        assert gate("check", baseline, [failures], [status], None, 0) == 0
        record = root / "record.txt"
        assert gate("record", root / "missing.txt", [failures], [status], record, 0) == 0
        assert read_names(record) == [
            "QuestifyCoreTests.FooTests/testBar",
            "QuestifyCoreTests.FooTests/testBaz",
        ]
        status.write_text("build-failed\n")
        try:
            gate("record", baseline, [failures], [status], record, 0)
            raise AssertionError("record must still fail when tests did not run")
        except SystemExit as error:
            assert "did not run" in str(error)
        assert fixture_launch_args("d2-home") == ["--design-fixture", "d2-home"]
        assert fixture_launch_args("--merchant-npc-fixture") == ["--merchant-npc-fixture"]
        assert fixture_launch_args('--design-fixture "city kit"') == ["--design-fixture", "city kit"]
        sample = root / "accept"
        sample.mkdir()
        (sample / "p1.txt").write_text("# comment\n\n  d2-home\n\t# also\n--shop-npc-fixture enabled\n")
        assert routes_from_accept(sample) == ["d2-home", "--shop-npc-fixture enabled"]
        assert routes_from_accept(root / "absent") == []
        missing_contract = root / "no-contract.txt"
        try:
            record_known_contract_failure(missing_contract)
            raise AssertionError("missing contract baseline must fail")
        except SystemExit as error:
            assert "baseline missing" in str(error)
        blank_contract = root / "blank-contract.txt"
        blank_contract.write_text("\n\n")
        try:
            record_known_contract_failure(blank_contract)
            raise AssertionError("blank contract baseline must fail")
        except SystemExit as error:
            assert "blank" in str(error)
        assert blank_contract.read_text() == "\n\n"
        contract = root / "contract-failing-baseline.txt"
        contract.write_text("zeta.Z.test_last\nalpha.A.test_first")
        assert record_known_contract_failure(contract) == 0
        recorded = contract.read_text()
        assert recorded == "zeta.Z.test_last\nalpha.A.test_first\n" + KNOWN_CONTRACT_FAILURE + "\n"
        assert record_known_contract_failure(contract) == 0
        assert contract.read_text() == recorded
        accept = root / "Accept"
        assert ui_smoke_needed(accept) is False
        accept.mkdir()
        assert ui_smoke_needed(accept) is False
        (accept / "Helper.swift").write_text("// class NotATest: XCTestCase\nstruct Foo {}\n")
        assert ui_smoke_needed(accept) is False
        (accept / "Flow.swift").write_text("@MainActor final class AcceptFlowTests: XCTestCase {\n}\n")
        assert ui_smoke_needed(accept) is True
        args_path = root / "ui.args"
        assert write_ui_smoke_args(accept, args_path) == "-only-testing:QuestifyUITests/AcceptFlowTests"
    groups = []
    for shard in (0, 1, 2, 3):
        args = only_testing_args(shard).split()
        assert args
        assert all(arg.startswith("-only-testing:QuestifyAppUnitTests/") for arg in args)
        group = [arg.split("/", 1)[1] for arg in args]
        assert "class" not in group
        groups.append(group)
    ordered = sorted(name for group in groups for name in group)
    assert len(ordered) == len(set(ordered))
    for index, name in enumerate(ordered):
        assert name in groups[index % 4]
    workflow_contract()
    print(f"acceptance support self-check passed ({len(ordered)} AppUnit classes)")
    return 0


def workflow_contract():
    """Lock the Acceptance workflow to the self-hosted runner and branch record mode."""
    text = Path(".github/workflows/acceptance.yml").read_text()
    head, jobs = text.split("\njobs:\n", 1)
    for forbidden in ("workflow_dispatch:", "pull_request:", "pull_request_target:", "macos-26", "macos-latest", "github.event.inputs"):
        if forbidden in text:
            raise SystemExit(f"acceptance workflow contains {forbidden}")
    if "acceptance-mac" in head:
        raise SystemExit("concurrency group must stay on the self-hosted jobs")
    if "contents: write" in head:
        raise SystemExit("contents: write must stay on the commit job")
    if jobs.count("group: acceptance-mac") != 5:
        raise SystemExit("acceptance-mac concurrency must be on the five self-hosted jobs")
    if jobs.count("cancel-in-progress: false") != 5:
        raise SystemExit("self-hosted concurrency must not cancel")
    runner = "runs-on: [self-hosted, macOS, ARM64, chengyin-app]"
    if jobs.count(runner) != 5:
        raise SystemExit("build, test, and screenshot jobs must use the self-hosted Mac")
    if jobs.count("runs-on: ubuntu-latest") != 5:
        raise SystemExit("python and baseline jobs must use ubuntu-latest")
    if "HEAD:refs/heads/ci/acceptance" not in jobs:
        raise SystemExit("record must push baselines to ci/acceptance")
    if "refs/heads/ci/baseline-record" not in head:
        raise SystemExit("record mode must key off refs/heads/ci/baseline-record")
    if jobs.count("contents: write") != 1:
        raise SystemExit("only the commit job may write contents")
    if KNOWN_CONTRACT_FAILURE not in Path(".github/acceptance_support.py").read_text():
        raise SystemExit("known contract failure id drifted")
    if not ui_smoke_needed() and not ACCEPT_UI_ROOT.is_dir():
        print("acceptance: Tests/AppUITests/Accept is absent; ui-smoke will skip")


def main(argv):
    parser = argparse.ArgumentParser(description="Acceptance workflow helpers")
    sub = parser.add_subparsers(dest="cmd", required=True)

    only = sub.add_parser("only-testing")
    only.add_argument("--shard", type=int, required=True)

    collect_p = sub.add_parser("collect")
    collect_p.add_argument("--log", type=Path, required=True)
    collect_p.add_argument("--exit", dest="exit_path", type=Path, required=True)
    collect_p.add_argument("--failures-out", type=Path, required=True)
    collect_p.add_argument("--status-out", type=Path, required=True)

    gate_p = sub.add_parser("gate")
    gate_p.add_argument("--mode", required=True)
    gate_p.add_argument("--baseline", type=Path, required=True)
    gate_p.add_argument("--failures", type=Path, action="append", default=[])
    gate_p.add_argument("--status", type=Path, action="append", default=[])
    gate_p.add_argument("--record", type=Path)
    gate_p.add_argument("--expected-statuses", type=int, default=0)

    sub.add_parser("xcode")

    dest = sub.add_parser("destination")
    dest.add_argument("--out", type=Path, required=True)

    shots = sub.add_parser("screenshots")
    shots.add_argument("--destination-file", type=Path, required=True)
    shots.add_argument("--out", type=Path, default=Path("acceptance-shots"))

    sub.add_parser("screenshot-needed")
    sub.add_parser("ui-smoke-needed")

    ui = sub.add_parser("ui-smoke-args")
    ui.add_argument("--out", type=Path, required=True)
    ui.add_argument("--root", type=Path, default=ACCEPT_UI_ROOT)

    contract = sub.add_parser("record-contract")
    contract.add_argument("--baseline", type=Path, required=True)

    sub.add_parser("self-check")

    args = parser.parse_args(argv)
    if args.cmd == "only-testing":
        print(only_testing_args(args.shard))
        return 0
    if args.cmd == "collect":
        return collect(args.log, args.exit_path, args.failures_out, args.status_out)
    if args.cmd == "gate":
        return gate(args.mode, args.baseline, args.failures, args.status, args.record, args.expected_statuses)
    if args.cmd == "xcode":
        select_xcode()
        return 0
    if args.cmd == "destination":
        write_destination(args.out)
        return 0
    if args.cmd == "screenshots":
        return capture_screenshots(args.destination_file, args.out)
    if args.cmd == "screenshot-needed":
        print("true" if screenshot_needed() else "false")
        return 0
    if args.cmd == "ui-smoke-needed":
        print("true" if ui_smoke_needed() else "false")
        return 0
    if args.cmd == "ui-smoke-args":
        write_ui_smoke_args(args.root, args.out)
        return 0
    if args.cmd == "record-contract":
        return record_known_contract_failure(args.baseline)
    if args.cmd == "self-check":
        return self_check()
    raise SystemExit(f"unknown command {args.cmd}")


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

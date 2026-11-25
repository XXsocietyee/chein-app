#!/usr/bin/env python3
"""Helpers for .github/workflows/acceptance.yml.

The AppUnit class split matches .github/workflows/ios-ci.yml. Failing test
names come from XCTest lines ``Test Case '-[Target.Class testMethod]' failed``.
Screenshot routes come only from docs/port/accept/*.txt and launch through the
app's existing DEBUG fixture arguments (``--design-fixture <name>``, or a line
that already starts with ``--``).

Record mode is the branch ``ci/baseline-record``. It appends one known contract
ratchet id and does not rewrite that baseline. Every other branch is check mode.

One ``build-for-testing`` is published under a commit-and-run key. Lane2 runs
AppUnit shards 0 then 1. W2 runs shards 2 then 3. Each lane clones that build
into its own DerivedData directory. Simulators are chosen by name, then by
device type. UDIDs are not hardcoded.

The screenshot step retries a failed simulator boot once. Lane2, W2,
screenshots, and ui-smoke take one shared lock so two lanes do not boot or
launch at the same time.

Before each AppUnit shard, and before screenshots, that lane's phone is shut
down, booted, and waited on with ``bootstatus -b``. Shutting down a phone that
is already shut down is success. ``found nothing to terminate`` is success.
Checkout retries ``git fetch`` and ``git checkout`` three times with backoff.
"""
import argparse
import fcntl
import json
import os
import plistlib
import re
import shlex
import shutil
import subprocess
import sys
import time
from contextlib import contextmanager
from pathlib import Path

ANSI = re.compile(r"\x1b\[[0-9;]*m")
XCTEST_FAILED = re.compile(r"Test Case '-\[([^\]]+)\]' failed")
BUNDLE_FALLBACK = "invalid.example.questify.ios"
# Lane2 is shards 0 and 1. W2 is shards 2 and 3. Name wins; device type is the
# fallback so a renamed phone of the same model still lands on its lane.
LANES = {
    "lane2": {"names": ("Questify-iPhone17-Lane2",), "device_type": "iPhone-17"},
    "w2": {"names": ("Questify-iPhone17-W2",), "device_type": "iPhone-17-Pro"},
}
LANE_SHARDS = {"lane2": (0, 1), "w2": (2, 3)}
ACCEPT_UI_ROOT = Path("Tests/AppUITests/Accept")
DERIVED_ROOT = Path("/private/tmp/chengyin-acceptance-derived")
# One file on the shared Mac. Lane2, W2, screenshots, and ui-smoke flock it
# for the whole boot and launch, not a per-ref concurrency group.
SIMULATOR_LOCK = Path("/private/tmp/chengyin-acceptance-simulator.lock")
BOOT_STATUS_TIMEOUT = 240
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
        if len(failure_paths) != expected_statuses:
            raise SystemExit(f"expected {expected_statuses} failure name files, found {len(failure_paths)}")
    for status_path in status_paths:
        if not status_path.is_file():
            raise SystemExit(f"missing status file {status_path}")
        state = status_path.read_text(errors="replace").splitlines()[0].strip()
        if state != "ran":
            raise SystemExit(f"tests did not run ({status_path}: {state})")
    for path in failure_paths:
        if not path.is_file():
            raise SystemExit(f"missing failure names file {path}")
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


def device_type_name(identifier):
    return (identifier or "").rsplit(".", 1)[-1]


def iphone_devices(payload):
    rows = []
    for runtime, devices in payload.get("devices", {}).items():
        for device in devices:
            if device.get("isAvailable") is False:
                continue
            name = device.get("name") or ""
            udid = device.get("udid") or ""
            device_type = device.get("deviceTypeIdentifier") or ""
            if udid and (name.startswith("iPhone") or "iPhone" in device_type):
                rows.append({
                    "runtime": runtime,
                    "name": name,
                    "udid": udid,
                    "device_type": device_type,
                })
    return rows


def choose_simulator(payload, lane):
    """Pick one phone for a lane. Exact name wins, then the lane's device type.

    ``iPhone-17`` does not match ``iPhone-17-Pro``. A device is never returned
    for both lanes. UDIDs come from simctl output, not from this file.
    """
    if lane not in LANES:
        raise SystemExit(f"unknown lane {lane}")
    spec = LANES[lane]
    rows = iphone_devices(payload)
    if not rows:
        raise SystemExit("no available iPhone simulator")
    named = [row for row in rows if row["name"] in spec["names"]]
    if named:
        pool = named
    else:
        other_names = {name for key, other in LANES.items() if key != lane for name in other["names"]}
        pool = [
            row for row in rows
            if device_type_name(row["device_type"]) == spec["device_type"] and row["name"] not in other_names
        ]
    if not pool:
        raise SystemExit(f"no simulator for lane {lane} ({spec['device_type']})")
    pool.sort(key=lambda row: (runtime_key(row["runtime"]), row["name"]))
    return pool[-1]


def write_destination(path, lane):
    raw = subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"], text=True)
    chosen = choose_simulator(json.loads(raw), lane)
    destination = f"platform=iOS Simulator,id={chosen['udid']}"
    path.write_text(destination + "\n")
    print(
        f"Simulator destination lane={lane}: {chosen['name']} "
        f"type={device_type_name(chosen['device_type'])} runtime={chosen['runtime']} id={chosen['udid']}"
    )
    print(destination)


def derived_root():
    override = os.environ.get("ACCEPTANCE_DERIVED_ROOT")
    return Path(override) if override else DERIVED_ROOT


def derived_key(sha, run_id):
    if not re.fullmatch(r"[0-9a-f]{40}", sha or ""):
        raise SystemExit("derived data must be keyed by the full commit sha")
    if not re.fullmatch(r"[1-9][0-9]*", run_id or ""):
        raise SystemExit("derived data run id must be numeric")
    return f"{sha}-{run_id}"


def _walk(value):
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from _walk(child)
    elif isinstance(value, list):
        for child in value:
            yield from _walk(child)


def _rewrite_root(value, aliases):
    if isinstance(value, dict):
        return {key: _rewrite_root(child, aliases) for key, child in value.items()}
    if isinstance(value, list):
        return [_rewrite_root(child, aliases) for child in value]
    if isinstance(value, str):
        for prefix in sorted(aliases, key=len, reverse=True):
            if value == prefix:
                return "__TESTROOT__"
            needle = prefix + "/"
            if needle in value:
                value = value.replace(needle, "__TESTROOT__/")
        return value
    return value


def xctestrun_file(derived):
    products = Path(derived) / "Build" / "Products"
    runs = sorted(path for path in products.glob("*.xctestrun") if path.is_file())
    if len(runs) != 1:
        raise SystemExit(f"expected one xctestrun in {products}, found {len(runs)}")
    return runs[0]


def normalize_products(products):
    """Rewrite xctestrun paths so a cloned Products directory still runs.

    ``__TESTROOT__`` is the directory that contains the xctestrun file.
    """
    original = Path(products)
    products = original.resolve()
    aliases = {str(original), str(original.absolute()), str(products)}
    runs = sorted(products.glob("*.xctestrun"))
    if not runs:
        raise SystemExit(f"no xctestrun under {products}")
    for path in runs:
        with path.open("rb") as handle:
            data = plistlib.load(handle)
        rewritten = _rewrite_root(data, aliases)
        for node in _walk(rewritten):
            for key in ("TestBundlePath", "TestHostPath", "UITargetAppPath"):
                value = node.get(key)
                if isinstance(value, str) and value.startswith("/"):
                    raise SystemExit(f"nonportable {key} in {path.name}")
        with path.open("wb") as handle:
            plistlib.dump(rewritten, handle)
    return len(runs)


def clone_tree(src, dest):
    src, dest = Path(src), Path(dest)
    if dest.exists():
        raise SystemExit(f"refusing to clone onto existing {dest}")
    dest.parent.mkdir(parents=True, exist_ok=True)
    if sys.platform == "darwin":
        cloned = subprocess.run(["cp", "-cR", str(src), str(dest)], text=True, capture_output=True)
        if cloned.returncode == 0:
            return
        if dest.exists():
            shutil.rmtree(dest)
        copied = subprocess.run(["cp", "-R", str(src), str(dest)], text=True, capture_output=True)
        if copied.returncode != 0:
            raise SystemExit(copied.stderr.strip() or cloned.stderr.strip() or "cp failed")
        return
    shutil.copytree(src, dest, symlinks=True)


def _same_or_nested(left, right):
    left, right = left.resolve(), right.resolve()
    return left == right or left in right.parents or right in left.parents


def prune_derived(keep, max_age_seconds=6 * 3600):
    root = derived_root()
    if not root.is_dir():
        return
    now = time.time()
    for child in root.iterdir():
        if not child.is_dir() or child.name.startswith("."):
            continue
        try:
            if keep is not None and child.resolve() == keep.resolve():
                continue
            if now - child.stat().st_mtime <= max_age_seconds:
                continue
        except OSError:
            continue
        shutil.rmtree(child, ignore_errors=True)


def publish_derived(src, sha, run_id):
    """Copy Products to the commit-and-run store. Callers test from a clone."""
    src = Path(src).resolve()
    products = src / "Build" / "Products"
    app = products / "Debug-iphonesimulator" / "Questify.app"
    if not app.is_dir():
        raise SystemExit(f"debug build did not produce {app}")
    normalize_products(products)
    root = derived_root()
    root.mkdir(parents=True, exist_ok=True)
    final = root / derived_key(sha, run_id)
    staging = root / f".staging-{final.name}-{os.getpid()}"
    if staging.exists():
        shutil.rmtree(staging)
    clone_tree(products, staging / "Build" / "Products")
    (staging / "acceptance-derived-key.txt").write_text(f"{sha} {run_id}\n")
    if final.exists():
        shutil.rmtree(final)
    staging.rename(final)
    prune_derived(final)
    print(f"published derived data {final}")
    return final


def restore_derived(sha, run_id, dest):
    """Clone the published build into ``dest``. ``dest`` must not be the store."""
    src = derived_root() / derived_key(sha, run_id)
    if not src.is_dir():
        raise SystemExit(f"no derived data for {sha} run {run_id}")
    marker = src / "acceptance-derived-key.txt"
    expected = f"{sha} {run_id}"
    if not marker.is_file() or marker.read_text(errors="replace").strip() != expected:
        raise SystemExit(f"derived data key mismatch at {src}")
    dest = Path(dest)
    if _same_or_nested(src, dest):
        raise SystemExit("refusing to point a job at the shared derived data directory")
    if dest.exists() and any(dest.iterdir()):
        raise SystemExit(f"refusing to restore into non-empty {dest}")
    if dest.exists():
        dest.rmdir()
    clone_tree(src, dest)
    app = dest / "Build" / "Products" / "Debug-iphonesimulator" / "Questify.app"
    if not app.is_dir():
        raise SystemExit(f"restored derived data has no {app}")
    print(f"restored derived data to {dest}")
    return dest


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


def simulator_lock_path():
    override = os.environ.get("ACCEPTANCE_SIMULATOR_LOCK")
    return Path(override) if override else SIMULATOR_LOCK


@contextmanager
def simulator_use_lock(path=None):
    """Exclusive lock for one boot and launch session on the shared Mac."""
    target = Path(path) if path is not None else simulator_lock_path()
    target.parent.mkdir(parents=True, exist_ok=True)
    try:
        fd = os.open(target, os.O_CREAT | os.O_RDWR, 0o666)
    except PermissionError:
        fd = os.open(target, os.O_RDONLY)
    try:
        try:
            os.chmod(target, 0o666)
        except OSError:
            pass
        print(f"waiting for simulator lock {target}", flush=True)
        fcntl.flock(fd, fcntl.LOCK_EX)
        print(f"acquired simulator lock {target}", flush=True)
        try:
            yield
        finally:
            fcntl.flock(fd, fcntl.LOCK_UN)
    finally:
        os.close(fd)


def split_lock_command(argv):
    """Optional ``--prepare-from <destination>`` then the locked command."""
    destination = None
    if argv[:1] == ["--prepare-from"]:
        if len(argv) < 2 or argv[1] in ("", "--"):
            raise SystemExit("simulator-lock --prepare-from needs a destination file")
        destination = Path(argv[1])
        argv = argv[2:]
    if argv[:1] == ["--"]:
        argv = argv[1:]
    if not argv:
        raise SystemExit("simulator-lock needs a command")
    return destination, argv


def run_with_simulator_lock(argv):
    """Run a lane or ui-smoke command while holding the simulator lock.

    ``--prepare-from`` shuts that destination down, boots it, and waits for
    ``bootstatus -b`` before the command. The lock covers both.
    """
    destination, command = split_lock_command(argv)
    with simulator_use_lock():
        if destination is not None:
            udid = udid_from_destination(destination.read_text(errors="replace"))
            if not prepare_simulator(udid):
                return 1
        return subprocess.call(command)


GIT_RETRY_DELAYS = (10, 20)


def retry_git_fetch_checkout(fetch_argv, checkout_argv, run=None, sleep=None):
    """Run fetch then checkout. Retry the pair 3 times with backoff."""
    run = run or (lambda argv: subprocess.run(argv, text=True, check=False).returncode)
    sleep = sleep or time.sleep
    for attempt in range(1, 4):
        fetch_code = run(list(fetch_argv))
        checkout_code = run(list(checkout_argv)) if fetch_code == 0 else None
        if fetch_code == 0 and checkout_code == 0:
            print(f"git fetch and checkout succeeded on attempt {attempt}", flush=True)
            return 0
        failed = fetch_code if fetch_code != 0 else checkout_code
        print(f"git fetch or checkout failed on attempt {attempt} (exit {failed})", flush=True)
        if attempt == 3:
            return failed or 1
        delay = GIT_RETRY_DELAYS[attempt - 1]
        print(f"waiting {delay}s before retrying git fetch and checkout", flush=True)
        sleep(delay)
    return 1


def git_fetch_and_checkout(ref, remote="origin", run=None, sleep=None):
    if remote != "origin" or not re.fullmatch(r"refs/heads/[A-Za-z0-9._/-]+", ref or "") or ".." in ref:
        raise SystemExit(f"refusing git retry for {remote} {ref}")
    return retry_git_fetch_checkout(
        ["git", "fetch", remote, ref],
        ["git", "checkout", "--detach", "FETCH_HEAD"],
        run=run,
        sleep=sleep,
    )


def materialize_shard_status(shards, root=None):
    """Write shard status and failure files when a lane stops before collect.

    A finished collect is left as-is. A missing pair means the job timed out
    or the shard never started, so the upload still has both files.
    """
    root = Path(root) if root is not None else Path(".")
    for shard in shards:
        if shard not in (0, 1, 2, 3):
            raise SystemExit(f"shard {shard} is outside 0..3")
        failures = root / f"appunit-{shard}-failures.txt"
        status = root / f"appunit-{shard}-status.txt"
        if (
            failures.is_file()
            and status.is_file()
            and failures.stat().st_size > 0
            and status.stat().st_size > 0
        ):
            print(f"acceptance: shard {shard} status already recorded")
            continue
        log = root / f"appunit-{shard}.log"
        exit_path = root / f"appunit-{shard}-exit.txt"
        if log.is_file() and exit_path.is_file():
            collect(log, exit_path, failures, status)
            continue
        names = failures_from_log(log) if log.is_file() else []
        write_names(failures, names)
        status.write_text("timed-out\n")
        print(
            f"acceptance: shard {shard} timed out before a finished status "
            f"({len(set(names))} names in the partial log)"
        )
    return 0


def process_text(completed):
    parts = []
    for value in (getattr(completed, "stdout", None), getattr(completed, "stderr", None)):
        if value is None or value == "":
            continue
        if isinstance(value, bytes):
            value = value.decode("utf-8", "replace")
        parts.append(value)
    return "\n".join(parts)


def retryable_simulator_failure(text):
    """CoreSimulator 405 and NSPOSIX 3 or 60 are boot or launch timeouts.

    405 while the phone is already Booted is not a timeout. POSIX 3 from
    terminate when nothing is running is success, not a timeout.
    """
    if not text:
        return False
    if re.search(r"domain=NSPOSIXErrorDomain,\s*code=60\b", text):
        return True
    if re.search(r"domain=com\.apple\.CoreSimulator\.SimError,\s*code=405\b", text):
        if "current state: Shutdown" in text or "Unable to lookup" in text:
            return True
        if "current state: Booted" in text:
            return False
        return True
    if re.search(r"domain=NSPOSIXErrorDomain,\s*code=3\b", text):
        return "found nothing to terminate" not in text
    return False


def should_reboot(detail):
    return detail == "timeout" or retryable_simulator_failure(detail)


def run_process(argv, timeout=None):
    return subprocess.run(argv, text=True, capture_output=True, timeout=timeout, check=False)


def run_simctl(argv, timeout=None, echo=True):
    try:
        result = run_process(argv, timeout=timeout)
    except subprocess.TimeoutExpired as error:
        text = process_text(error)
        if echo and text.strip():
            print(text, flush=True)
        print("simulator command timed out", flush=True)
        return None, text
    text = process_text(result)
    if echo and text.strip():
        print(text, flush=True)
    return result, text


def note_boot_retry():
    print("retrying simulator boot once", flush=True)


def terminate_is_success(result, text):
    """``simctl terminate`` exits 3 with this message when the app is not running."""
    if "found nothing to terminate" in (text or ""):
        return True
    return result is not None and result.returncode == 0


def shutdown_is_success(result, text):
    """A phone that is already shut down is a successful shutdown."""
    if result is not None and result.returncode == 0:
        return True
    return "current state: Shutdown" in (text or "")


def shutdown_simulator(udid):
    result, text = run_simctl(["xcrun", "simctl", "shutdown", udid], echo=False)
    if shutdown_is_success(result, text):
        if "current state: Shutdown" in (text or ""):
            print("simulator already shut down", flush=True)
        elif text.strip():
            print(text, flush=True)
        return True
    if text.strip():
        print(text, flush=True)
    print("simulator shutdown failed", flush=True)
    return False


def prepare_simulator(udid):
    """Shut one lane phone down, boot it, and wait for ``bootstatus -b``.

    This is a single attempt. Screenshot capture still has its own one boot retry.
    """
    if not shutdown_simulator(udid):
        return False
    boot, text = run_simctl(["xcrun", "simctl", "boot", udid])
    if boot is None:
        print("simulator boot timed out", flush=True)
        return False
    if boot.returncode != 0 and "current state: Booted" not in (text or ""):
        print("simulator boot failed", flush=True)
        return False
    status, _text = run_simctl(
        ["xcrun", "simctl", "bootstatus", udid, "-b"],
        timeout=BOOT_STATUS_TIMEOUT,
    )
    if status is None or status.returncode != 0:
        print("simulator bootstatus failed", flush=True)
        return False
    print(f"simulator {udid} is booted", flush=True)
    return True


def boot_simulator_once(udid):
    """Boot one phone. Already booted plus a successful bootstatus counts as up."""
    boot, _text = run_simctl(["xcrun", "simctl", "boot", udid])
    if boot is None:
        print("simulator boot timed out", flush=True)
        return False
    status, _text = run_simctl(["xcrun", "simctl", "bootstatus", udid, "-b"], timeout=BOOT_STATUS_TIMEOUT)
    if status is None:
        print("simulator boot timed out", flush=True)
        return False
    return status.returncode == 0


def boot_simulator(udid, state):
    """Boot, and retry that boot once if it does not come up."""
    if boot_simulator_once(udid):
        return True
    if state["retried"]:
        print("simulator did not boot", flush=True)
        return False
    state["retried"] = True
    note_boot_retry()
    shutdown_simulator(udid)
    if boot_simulator_once(udid):
        return True
    print("simulator did not boot", flush=True)
    return False


def install_app(udid, app):
    result, text = run_simctl(["xcrun", "simctl", "install", udid, str(app)])
    if result is None or result.returncode != 0:
        print("simctl install failed", flush=True)
        return False, result, text
    return True, result, text


def relaunch_after_boot(udid, app, state):
    """Use the step's one boot retry after the phone shuts down mid-launch."""
    if state["retried"]:
        return False
    state["retried"] = True
    note_boot_retry()
    shutdown_simulator(udid)
    if not boot_simulator_once(udid):
        print("simulator did not boot", flush=True)
        return False
    installed, _result, _text = install_app(udid, app)
    return installed


def take_screenshot(udid, png):
    result, text = run_simctl(["xcrun", "simctl", "io", udid, "screenshot", str(png)])
    ok = result is not None and result.returncode == 0 and png_ok(png)
    return ok, result, text


def capture_route(udid, bundle, route, png, handle, can_reboot):
    args = fixture_launch_args(route)
    terminated, term_text = run_simctl(["xcrun", "simctl", "terminate", udid, bundle], echo=False)
    if terminate_is_success(terminated, term_text):
        if "found nothing to terminate" in (term_text or ""):
            print("simulator terminate found nothing to terminate", flush=True)
    else:
        if term_text.strip():
            print(term_text, flush=True)
        print("simulator terminate failed", flush=True)
    launch, launch_text = run_simctl(
        ["xcrun", "simctl", "launch", "--terminate-running-process", udid, bundle, *args],
        echo=False,
    )
    if launch is not None and launch.returncode != 0 and terminate_is_success(launch, launch_text):
        print("simulator launch found nothing to terminate; launching again", flush=True)
        launch, launch_text = run_simctl(
            ["xcrun", "simctl", "launch", udid, bundle, *args],
            echo=False,
        )
    code = "timeout" if launch is None else launch.returncode
    stdout = "" if launch is None else (launch.stdout or "")
    stderr = "" if launch is None else (launch.stderr or "")
    handle.write(f"route {route}\nargv {args}\nexit {code}\n{stdout}\n{stderr}\n")
    handle.flush()
    if launch is None:
        return False, launch_text or "timeout"
    if launch.returncode != 0:
        return False, launch_text if retryable_simulator_failure(launch_text) else ""
    time.sleep(5)
    ok, shot, shot_text = take_screenshot(udid, png)
    if ok:
        print(f"wrote {png}", flush=True)
        return True, ""
    # A boot or launch timeout burns the one boot retry. Any other miss still
    # gets the existing second screenshot attempt.
    if can_reboot and (shot is None or retryable_simulator_failure(shot_text)):
        return False, shot_text or "timeout"
    time.sleep(3)
    ok, second, shot_text = take_screenshot(udid, png)
    if ok:
        print(f"wrote {png}", flush=True)
        return True, ""
    if second is None or retryable_simulator_failure(shot_text):
        return False, shot_text or "timeout"
    return False, ""


def capture_screenshots(destination_file, shots, derived):
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
    with simulator_use_lock():
        return _capture_screenshots_locked(destination_file, shots, derived, routes)


def _capture_screenshots_locked(destination_file, shots, derived, routes):
    destination = destination_file.read_text(errors="replace").strip()
    udid = udid_from_destination(destination)
    shots.mkdir(parents=True, exist_ok=True)
    app = Path(derived) / "Build/Products/Debug-iphonesimulator/Questify.app"
    if not app.is_dir():
        print(f"reused debug build did not produce {app}")
        return 1
    bundle = bundle_identifier(app)
    state = {"retried": False}
    prepare_simulator(udid)
    if not boot_simulator(udid, state):
        return 1
    installed, result, text = install_app(udid, app)
    if not installed and not (should_reboot(text if result is not None else "timeout") and relaunch_after_boot(udid, app, state)):
        return 1
    launch_log = shots / "launch.log"
    picture_dir = shots / "screenshots"
    picture_dir.mkdir(parents=True, exist_ok=True)
    failures = []
    with launch_log.open("w") as handle:
        for index, route in enumerate(routes, start=1):
            png = picture_dir / safe_png_name(route, index)
            ok, detail = capture_route(udid, bundle, route, png, handle, can_reboot=not state["retried"])
            if not ok and should_reboot(detail) and relaunch_after_boot(udid, app, state):
                ok, detail = capture_route(udid, bundle, route, png, handle, can_reboot=False)
            if not ok:
                failures.append(route)
    if failures:
        print("screenshot failed for routes:")
        for route in failures:
            print(route)
        return 1
    return 0


def check_simulator_retry(root):
    """One boot retry, and the shared lock keeps two sessions from overlapping."""
    shutdown = (
        "An error was encountered processing the command (domain=com.apple.CoreSimulator.SimError, code=405):\n"
        "Unable to lookup in current state: Shutdown\n"
    )
    already = (
        "An error was encountered processing the command (domain=com.apple.CoreSimulator.SimError, code=405):\n"
        "Unable to boot device in current state: Booted\n"
    )
    timed_out = (
        "An error was encountered processing the command (domain=NSPOSIXErrorDomain, code=60):\n"
        "Timeout waiting for screen surfaces\n"
    )
    missing = (
        "An error was encountered processing the command (domain=NSPOSIXErrorDomain, code=3):\n"
        "Simulator device failed to launch the application.\n"
    )
    nothing = (
        "An error was encountered processing the command (domain=NSPOSIXErrorDomain, code=3):\n"
        "found nothing to terminate\n"
    )
    assert retryable_simulator_failure(shutdown)
    assert retryable_simulator_failure(timed_out)
    assert retryable_simulator_failure(missing)
    assert not retryable_simulator_failure(already)
    assert not retryable_simulator_failure(nothing)
    assert terminate_is_success(subprocess.CompletedProcess(["simctl", "terminate"], 3, "", nothing), nothing)
    assert not terminate_is_success(
        subprocess.CompletedProcess(["simctl", "terminate"], 3, "", missing),
        missing,
    )
    assert shutdown_is_success(
        subprocess.CompletedProcess(["simctl", "shutdown"], 1, "", "current state: Shutdown\n"),
        "current state: Shutdown\n",
    )
    assert not shutdown_is_success(
        subprocess.CompletedProcess(["simctl", "shutdown"], 1, "", "current state: Creating\n"),
        "current state: Creating\n",
    )
    assert should_reboot("timeout")
    assert not should_reboot("The application failed to launch.")

    global run_process
    real = run_process
    calls = []

    def fake_timeout(argv, timeout=None):
        calls.append(list(argv))
        if argv[1:3] == ["simctl", "bootstatus"] and sum(item[1:3] == ["simctl", "bootstatus"] for item in calls) == 1:
            raise subprocess.TimeoutExpired(argv, timeout or BOOT_STATUS_TIMEOUT)
        return subprocess.CompletedProcess(argv, 0, "", "")

    def fake_ok(argv, timeout=None):
        calls.append(list(argv))
        stderr = already if argv[1:3] == ["simctl", "boot"] else ""
        return subprocess.CompletedProcess(argv, 0, "", stderr)

    def fake_down(argv, timeout=None):
        calls.append(list(argv))
        if argv[1:3] == ["simctl", "bootstatus"]:
            return subprocess.CompletedProcess(argv, 1, "", shutdown)
        return subprocess.CompletedProcess(argv, 0, "", "")

    try:
        run_process = fake_timeout
        state = {"retried": False}
        assert boot_simulator("PHONE", state) is True
        assert state["retried"] is True
        assert sum(item[1:3] == ["simctl", "bootstatus"] for item in calls) == 2
        assert ["xcrun", "simctl", "shutdown", "PHONE"] in calls
        calls.clear()
        run_process = fake_ok
        state = {"retried": False}
        assert boot_simulator("PHONE", state) is True
        assert state["retried"] is False
        assert sum(item[1:3] == ["simctl", "bootstatus"] for item in calls) == 1
        assert ["xcrun", "simctl", "shutdown", "PHONE"] not in calls
        calls.clear()
        run_process = fake_down
        state = {"retried": False}
        assert boot_simulator("PHONE", state) is False
        assert state["retried"] is True
        assert sum(item[1:3] == ["simctl", "bootstatus"] for item in calls) == 2
    finally:
        run_process = real

    log = root / "lock-order.txt"
    script = root / "hold_lock.py"
    script.write_text(
        "import importlib.util, sys, time\n"
        "spec = importlib.util.spec_from_file_location('acceptance_support_lock', sys.argv[1])\n"
        "module = importlib.util.module_from_spec(spec)\n"
        "spec.loader.exec_module(module)\n"
        "with module.simulator_use_lock(sys.argv[2]):\n"
        "    with open(sys.argv[3], 'a', encoding='utf-8') as handle:\n"
        "        handle.write('enter ' + sys.argv[4] + '\\n')\n"
        "    time.sleep(float(sys.argv[5]))\n"
        "    with open(sys.argv[3], 'a', encoding='utf-8') as handle:\n"
        "        handle.write('leave ' + sys.argv[4] + '\\n')\n"
    )
    lock_path = root / "simulator.lock"
    first = subprocess.Popen(
        [sys.executable, str(script), str(Path(__file__).resolve()), str(lock_path), str(log), "a", "0.4"],
        text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
    )
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        if log.exists() and "enter a" in log.read_text():
            break
        if first.poll() is not None:
            raise AssertionError(first.stdout.read())
        time.sleep(0.05)
    else:
        raise AssertionError("simulator lock was not acquired")
    second = subprocess.Popen(
        [sys.executable, str(script), str(Path(__file__).resolve()), str(lock_path), str(log), "b", "0"],
        text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
    )
    first_out, _ = first.communicate(timeout=10)
    second_out, _ = second.communicate(timeout=10)
    assert first.returncode == 0, first_out
    assert second.returncode == 0, second_out
    assert log.read_text().splitlines() == ["enter a", "leave a", "enter b", "leave b"]
    check_prepare_git_and_timeout(root)


def check_prepare_git_and_timeout(root):
    """One shutdown-boot-bootstatus, git retry, and timeout status files."""
    global run_process
    real = run_process
    calls = []

    def fake_already_down(argv, timeout=None):
        calls.append(list(argv))
        if argv[1:3] == ["simctl", "shutdown"]:
            return subprocess.CompletedProcess(argv, 1, "", "Unable to shutdown device in current state: Shutdown\n")
        return subprocess.CompletedProcess(argv, 0, "", "")

    def fake_shutdown_busy(argv, timeout=None):
        calls.append(list(argv))
        return subprocess.CompletedProcess(argv, 1, "", "Unable to shutdown device in current state: Creating\n")

    try:
        run_process = fake_already_down
        assert prepare_simulator("PHONE") is True
        assert [item[1:3] for item in calls] == [
            ["simctl", "shutdown"],
            ["simctl", "boot"],
            ["simctl", "bootstatus"],
        ]
        assert calls[2][3:] == ["PHONE", "-b"]
        calls.clear()
        run_process = fake_shutdown_busy
        assert prepare_simulator("PHONE") is False
        assert [item[1:3] for item in calls] == [["simctl", "shutdown"]]
    finally:
        run_process = real

    destination, command = split_lock_command(
        ["--prepare-from", "simulator-destination.txt", "--", "xcodebuild", "test"]
    )
    assert destination == Path("simulator-destination.txt")
    assert command == ["xcodebuild", "test"]
    bare_destination, bare_command = split_lock_command(["--", "xcodebuild"])
    assert bare_destination is None and bare_command == ["xcodebuild"]
    try:
        split_lock_command(["--prepare-from", "--", "xcodebuild"])
        raise AssertionError("prepare-from needs a destination file")
    except SystemExit as error:
        assert "destination" in str(error)

    calls = []
    sleeps = []

    def fail_fetch_twice(argv):
        calls.append(list(argv))
        if argv[1] == "fetch" and sum(item[1] == "fetch" for item in calls) < 3:
            return 128
        return 0

    assert git_fetch_and_checkout("refs/heads/ci/acceptance", run=fail_fetch_twice, sleep=sleeps.append) == 0
    assert sleeps == [10, 20]
    assert sum(item[1] == "fetch" for item in calls) == 3
    assert sum(item[1] == "checkout" for item in calls) == 1
    assert calls[0] == ["git", "fetch", "origin", "refs/heads/ci/acceptance"]
    calls.clear()
    sleeps.clear()

    def fail_checkout_once(argv):
        calls.append(list(argv))
        if argv[1] == "checkout" and sum(item[1] == "checkout" for item in calls) == 1:
            return 1
        return 0

    assert git_fetch_and_checkout("refs/heads/ci/acceptance", run=fail_checkout_once, sleep=sleeps.append) == 0
    assert sleeps == [10]
    assert sum(item[1] == "fetch" for item in calls) == 2
    assert sum(item[1] == "checkout" for item in calls) == 2
    try:
        git_fetch_and_checkout("refs/heads/../main", run=lambda argv: 0, sleep=lambda _seconds: None)
        raise AssertionError("a ref that escapes heads must not be fetched")
    except SystemExit as error:
        assert "refusing" in str(error)

    log = root / "appunit-0.log"
    log.write_text("Test Case '-[QuestifyAppUnitTests.Foo testBar]' failed (0.1 seconds).\n")
    assert materialize_shard_status([0], root) == 0
    assert (root / "appunit-0-status.txt").read_text() == "timed-out\n"
    assert (root / "appunit-0-failures.txt").read_text() == "QuestifyAppUnitTests.Foo/testBar\n"
    (root / "appunit-0-status.txt").write_text("ran\n")
    (root / "appunit-0-failures.txt").write_text("kept\n")
    assert materialize_shard_status([0], root) == 0
    assert (root / "appunit-0-status.txt").read_text() == "ran\n"
    assert (root / "appunit-0-failures.txt").read_text() == "kept\n"
    assert materialize_shard_status([1], root) == 0
    assert (root / "appunit-1-status.txt").read_text() == "timed-out\n"
    assert (root / "appunit-1-failures.txt").read_text() == "\n"


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
        untouched = root / "should-not-write.txt"
        try:
            gate("record", baseline, [root / "no-names.txt"], [status], untouched, 0)
            raise AssertionError("missing failure names must not record")
        except SystemExit as error:
            assert "missing failure names" in str(error)
        assert not untouched.exists()
        try:
            gate("record", baseline, [failures], [status, status], record, 2)
            raise AssertionError("a short name-file list must not record")
        except SystemExit as error:
            assert "failure name" in str(error)
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
        check_lanes_and_derived(root)
        check_simulator_retry(root)
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


def check_lanes_and_derived(root):
    """Lane2 and W2 stay distinct, and two jobs never share DerivedData."""
    assert LANE_SHARDS == {"lane2": (0, 1), "w2": (2, 3)}
    payload = {
        "devices": {
            "com.apple.CoreSimulator.SimRuntime.iOS-27-0": [
                {
                    "name": "Questify-iPhone17-Lane2",
                    "udid": "LANE-UDID",
                    "isAvailable": True,
                    "deviceTypeIdentifier": "com.apple.CoreSimulator.SimDeviceType.iPhone-17",
                },
                {
                    "name": "Questify-iPhone17-W2",
                    "udid": "W2-UDID",
                    "isAvailable": True,
                    "deviceTypeIdentifier": "com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro",
                },
                {
                    "name": "iPad",
                    "udid": "PAD",
                    "isAvailable": True,
                    "deviceTypeIdentifier": "com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch",
                },
                {
                    "name": "Offline",
                    "udid": "OLD",
                    "isAvailable": False,
                    "deviceTypeIdentifier": "com.apple.CoreSimulator.SimDeviceType.iPhone-17",
                },
            ]
        }
    }
    lane = choose_simulator(payload, "lane2")
    other = choose_simulator(payload, "w2")
    assert lane["name"] == "Questify-iPhone17-Lane2"
    assert other["name"] == "Questify-iPhone17-W2"
    assert lane["udid"] != other["udid"]
    renamed = {
        "devices": {
            "com.apple.CoreSimulator.SimRuntime.iOS-27-2": [
                {
                    "name": "Phone A",
                    "udid": "A",
                    "isAvailable": True,
                    "deviceTypeIdentifier": "com.apple.CoreSimulator.SimDeviceType.iPhone-17",
                },
                {
                    "name": "Phone B",
                    "udid": "B",
                    "isAvailable": True,
                    "deviceTypeIdentifier": "com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro",
                },
                {
                    "name": "Phone C",
                    "udid": "C",
                    "isAvailable": True,
                    "deviceTypeIdentifier": "com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max",
                },
            ]
        }
    }
    assert choose_simulator(renamed, "lane2")["udid"] == "A"
    assert choose_simulator(renamed, "w2")["udid"] == "B"
    only_pro = {
        "devices": {
            "rt": [
                {
                    "name": "Phone B",
                    "udid": "B",
                    "isAvailable": True,
                    "deviceTypeIdentifier": "com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro",
                }
            ]
        }
    }
    try:
        choose_simulator(only_pro, "lane2")
        raise AssertionError("iPhone 17 Pro must not satisfy Lane2")
    except SystemExit as error:
        assert "lane2" in str(error)
    named_like_shorter_type = {
        "devices": {
            "rt": [
                {
                    "name": "iPhone-17",
                    "udid": "PRO-NAME",
                    "isAvailable": True,
                    "deviceTypeIdentifier": "com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro",
                }
            ]
        }
    }
    try:
        choose_simulator(named_like_shorter_type, "lane2")
        raise AssertionError("iPhone-17 must not select iPhone-17-Pro")
    except SystemExit as error:
        assert "lane2" in str(error)
    try:
        choose_simulator(payload, "shared")
        raise AssertionError("unknown lane must fail")
    except SystemExit as error:
        assert "unknown lane" in str(error)
    previous = os.environ.get("ACCEPTANCE_DERIVED_ROOT")
    os.environ["ACCEPTANCE_DERIVED_ROOT"] = str(root / "derived-store")
    try:
        sha = "516f1deae9961636c64d1af643423b7d69f0a266"
        run_id = "45420309627"
        src = root / "build"
        products = src / "Build" / "Products"
        app = products / "Debug-iphonesimulator" / "Questify.app"
        app.mkdir(parents=True)
        host = str(app.resolve())
        run = products / "Questify.xctestrun"
        run.write_bytes(plistlib.dumps({
            "TestTargets": [{
                "TestBundlePath": host + "/PlugIns/QuestifyAppUnitTests.xctest",
                "TestHostPath": host,
            }]
        }))
        published = publish_derived(src, sha, run_id)
        lane_dest = root / "job-lane2"
        w2_dest = root / "job-w2"
        restore_derived(sha, run_id, lane_dest)
        restore_derived(sha, run_id, w2_dest)
        assert lane_dest.resolve() != w2_dest.resolve()
        assert published.resolve() != lane_dest.resolve()
        try:
            restore_derived(sha, run_id, published)
            raise AssertionError("a lane must not reuse the shared store")
        except SystemExit as error:
            assert "shared" in str(error)
        restored = xctestrun_file(lane_dest)
        assert restored == lane_dest / "Build" / "Products" / "Questify.xctestrun"
        assert xctestrun_file(w2_dest) != restored
        with restored.open("rb") as handle:
            data = plistlib.load(handle)
        assert data["TestTargets"][0]["TestHostPath"] == "__TESTROOT__/Debug-iphonesimulator/Questify.app"
        assert data["TestTargets"][0]["TestBundlePath"].startswith("__TESTROOT__/")
    finally:
        if previous is None:
            os.environ.pop("ACCEPTANCE_DERIVED_ROOT", None)
        else:
            os.environ["ACCEPTANCE_DERIVED_ROOT"] = previous


def job_block(text, job_id):
    marker = f"\n  {job_id}:\n"
    start = text.find(marker)
    if start < 0:
        raise SystemExit(f"missing job {job_id}")
    rest = text[start + len(marker):]
    match = re.search(r"\n  [A-Za-z0-9-]+:\n", rest)
    return rest[:match.start()] if match else rest


def workflow_contract():
    """Lock lanes, one shared build, and record mode to the workflow file."""
    text = Path(".github/workflows/acceptance.yml").read_text()
    support = Path(".github/acceptance_support.py").read_text()
    head, jobs = text.split("\njobs:\n", 1)
    for forbidden in ("workflow_dispatch:", "pull_request:", "pull_request_target:", "macos-26", "macos-latest", "github.event.inputs", "queue:"):
        if forbidden in text:
            raise SystemExit(f"acceptance workflow contains {forbidden}")
    selection = support.split("def workflow_contract", 1)[0]
    for udid in ("2337B386-AC5F-4417-B8B8-012A8DB888BD", "B9EDBC65-4D27-40CB-9521-A41ED05EAE35"):
        if udid in text or udid in selection:
            raise SystemExit("simulator UDIDs must not be hardcoded")
    if "acceptance-mac" in text:
        raise SystemExit("acceptance-mac serializes every Mac job")
    if "contents: write" in head:
        raise SystemExit("contents: write must stay on the commit job")
    if "actions/cache" in text:
        raise SystemExit("actions/cache DerivedData save holds the runner")
    runner = "runs-on: [self-hosted, macOS, ARM64, chengyin-app]"
    if jobs.count(runner) != 6:
        raise SystemExit("debug, core, two lanes, ui-smoke, and screenshots must use the self-hosted Mac")
    if jobs.count("runs-on: ubuntu-latest") != 6:
        raise SystemExit("python and baseline jobs must use ubuntu-latest")
    gates = job_block(text, "gates")
    if "ubuntu-latest" not in gates or "tools/contract_ratchet.py" not in gates:
        raise SystemExit("python gates must stay on ubuntu-latest")
    if "refs/heads/ci/baseline-record" not in head:
        raise SystemExit("record mode must key off refs/heads/ci/baseline-record")
    if jobs.count("contents: write") != 1:
        raise SystemExit("only the commit job may write contents")
    if "HEAD:refs/heads/ci/acceptance" not in jobs:
        raise SystemExit("record must push baselines to ci/acceptance")
    record = job_block(text, "record-baselines")
    if "git-retry --ref refs/heads/ci/acceptance" not in record:
        raise SystemExit("record must retry git fetch and checkout")
    if "\n          git fetch origin refs/heads/ci/acceptance\n" in record:
        raise SystemExit("record must not fetch ci/acceptance only once")
    checkout_action = Path(".github/actions/acceptance-checkout/action.yml")
    action = checkout_action.read_text()
    pin = "actions/checkout@11d5960a326750d5838078e36cf38b85af677262"
    if action.count(pin) != 3 or "sleep 10" not in action or "sleep 20" not in action:
        raise SystemExit("checkout must retry git fetch and checkout 3 times with backoff")
    checkout_ref = "liboyang42-cpu/chengyin-app/.github/actions/acceptance-checkout@9bdac9b5b5f49d242d35f3c3ae7f835846ab1b43"
    if text.count(checkout_ref) != 12:
        raise SystemExit("every acceptance job must retry checkout")
    if "./.github/actions/acceptance-checkout" in text:
        raise SystemExit("a local checkout action is not on disk before checkout")
    if "actions/checkout@" in text:
        raise SystemExit("checkout retries belong in the acceptance checkout action")
    if text.count("persist-credentials: 'false'") != 11 or text.count("persist-credentials: 'true'") != 1:
        raise SystemExit("checkout credentials must stay read-only except for record")
    if KNOWN_CONTRACT_FAILURE not in support:
        raise SystemExit("known contract failure id drifted")
    groups = (
        "acceptance-debug-${{ github.ref }}",
        "acceptance-core-${{ github.ref }}",
        "acceptance-lane2-${{ github.ref }}",
        "acceptance-w2-${{ github.ref }}",
        "acceptance-ui-${{ github.ref }}",
        "acceptance-shots-${{ github.ref }}",
    )
    for group in groups:
        if jobs.count(f"group: {group}") != 1:
            raise SystemExit(f"concurrency group {group} must appear once")
    if jobs.count("cancel-in-progress: true") != len(groups):
        raise SystemExit("each Mac job cancels only its own previous run")
    lane2 = job_block(text, "appunit-lane-lane2")
    w2 = job_block(text, "appunit-lane-w2")
    for body, lane, other in ((lane2, "lane2", "w2"), (w2, "w2", "lane2")):
        shards = " ".join(str(shard) for shard in LANE_SHARDS[lane])
        if f"for shard in {shards}" not in body:
            raise SystemExit(f"{lane} must run shards {shards} in order")
        if f"derived-{lane}" not in body or f"derived-{other}" in body:
            raise SystemExit(f"{lane} must use its own DerivedData directory")
        if f"--lane {lane}" not in body:
            raise SystemExit(f"{lane} must choose its own simulator")
        if body.count("test-without-building") != 1 or "-xctestrun" not in body:
            raise SystemExit(f"{lane} must reuse the debug build")
        if "xcodebuild -project" in body:
            raise SystemExit(f"{lane} must not compile")
        if body.count("continue-on-error: true") != len(LANE_SHARDS[lane]):
            raise SystemExit(f"{lane} xcresult upload must not fail the job")
        if body.count("if-no-files-found: error") != len(LANE_SHARDS[lane]):
            raise SystemExit(f"{lane} name artifacts stay required")
        if "build-for-testing" in body or "actions/cache" in body:
            raise SystemExit(f"{lane} must not compile or share a cache path")
        if body.count("simulator-lock --") != 1:
            raise SystemExit(f"{lane} must take the simulator lock around boot and launch")
        if "simulator-lock --prepare-from simulator-destination.txt --" not in body:
            raise SystemExit(f"{lane} must shut down and boot its simulator before each shard")
        shard_args = " ".join(f"--shard {shard}" for shard in LANE_SHARDS[lane])
        marker = f"materialize-shard-status {shard_args}"
        if marker not in body:
            raise SystemExit(f"{lane} must record shard status for a timed-out job")
        window = body[max(0, body.find(marker) - 240):body.find(marker)]
        if "if: always()" not in window:
            raise SystemExit(f"{lane} must write shard status even when the job times out")
    if "group: acceptance-lane2-" in w2 or "group: acceptance-w2-" in lane2:
        raise SystemExit("the two lanes must not share a concurrency group")
    debug = job_block(text, "debug-build")
    if debug.count("build-for-testing") != 1 or "publish-derived" not in debug:
        raise SystemExit("one debug build must publish DerivedData")
    if "test-without-building" in debug:
        raise SystemExit("the debug job only builds")
    if jobs.count("build-for-testing") != 1 or jobs.count("xcodebuild -project") != 1:
        raise SystemExit("only the debug job may compile")
    shots = job_block(text, "screenshots")
    if "xcodebuild -project" in shots or "--derived" not in shots or "restore-derived" not in shots:
        raise SystemExit("screenshots must reuse the published build")
    if "acceptance_support.py screenshots" not in shots:
        raise SystemExit("screenshots must launch DEBUG fixtures through acceptance_support.py")
    if "with simulator_use_lock()" not in selection:
        raise SystemExit("screenshots must hold the simulator lock while booting and launching")
    if "retrying simulator boot once" not in selection:
        raise SystemExit("screenshots must retry the simulator boot once")
    locked_fn = selection.split("def _capture_screenshots_locked", 1)[1].split("\ndef ", 1)[0]
    if "prepare_simulator(udid)" not in locked_fn or "boot_simulator(udid, state)" not in locked_fn:
        raise SystemExit("screenshots must shut down and boot, and keep the one boot retry")
    if selection.count("/private/tmp/chengyin-acceptance-simulator.lock") != 1:
        raise SystemExit("simulator boot and launch must share one lock")
    ui = job_block(text, "ui-smoke")
    if "test-without-building" not in ui or "-xctestrun" not in ui or "restore-derived" not in ui:
        raise SystemExit("ui-smoke must reuse the published build")
    if ui.count("simulator-lock --") != 1:
        raise SystemExit("ui-smoke must take the simulator lock around boot and launch")
    if "xcodebuild -project" in ui:
        raise SystemExit("ui-smoke must not compile")
    if "ubuntu-latest" not in job_block(text, "ui-smoke-plan"):
        raise SystemExit("the ui-smoke plan stays on ubuntu")
    record = job_block(text, "record-baselines")
    if "!cancelled()" not in record.split("steps:", 1)[0]:
        raise SystemExit("record-baselines must include !cancelled()")
    for check in (
        "needs.gates.result == 'success'",
        "needs.core-tests.result == 'success'",
        "needs.appunit-baseline.result == 'success'",
        "refs/heads/ci/baseline-record",
    ):
        if check not in record:
            raise SystemExit(f"record-baselines must keep {check}")
    if "> docs/release/baselines" in record or "truncate" in record:
        raise SystemExit("record-baselines must not blank baseline files")
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
    dest.add_argument("--lane", required=True, choices=sorted(LANES))
    dest.add_argument("--out", type=Path, required=True)

    publish = sub.add_parser("publish-derived")
    publish.add_argument("--src", type=Path, required=True)
    publish.add_argument("--sha", required=True)
    publish.add_argument("--run-id", required=True)

    restore = sub.add_parser("restore-derived")
    restore.add_argument("--sha", required=True)
    restore.add_argument("--run-id", required=True)
    restore.add_argument("--dest", type=Path, required=True)

    xctestrun = sub.add_parser("xctestrun")
    xctestrun.add_argument("--derived", type=Path, required=True)

    shots = sub.add_parser("screenshots")
    shots.add_argument("--destination-file", type=Path, required=True)
    shots.add_argument("--derived", type=Path, required=True)
    shots.add_argument("--out", type=Path, default=Path("acceptance-shots"))

    locked = sub.add_parser("simulator-lock")
    locked.add_argument("command", nargs=argparse.REMAINDER)

    sub.add_parser("screenshot-needed")
    sub.add_parser("ui-smoke-needed")

    ui = sub.add_parser("ui-smoke-args")
    ui.add_argument("--out", type=Path, required=True)
    ui.add_argument("--root", type=Path, default=ACCEPT_UI_ROOT)

    contract = sub.add_parser("record-contract")
    contract.add_argument("--baseline", type=Path, required=True)

    retry = sub.add_parser("git-retry")
    retry.add_argument("--ref", required=True)
    retry.add_argument("--remote", default="origin")

    shards = sub.add_parser("materialize-shard-status")
    shards.add_argument("--shard", type=int, action="append", required=True)

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
        write_destination(args.out, args.lane)
        return 0
    if args.cmd == "publish-derived":
        publish_derived(args.src, args.sha, args.run_id)
        return 0
    if args.cmd == "restore-derived":
        restore_derived(args.sha, args.run_id, args.dest)
        return 0
    if args.cmd == "xctestrun":
        print(xctestrun_file(args.derived))
        return 0
    if args.cmd == "screenshots":
        return capture_screenshots(args.destination_file, args.out, args.derived)
    if args.cmd == "simulator-lock":
        return run_with_simulator_lock(args.command)
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
    if args.cmd == "git-retry":
        return git_fetch_and_checkout(args.ref, args.remote)
    if args.cmd == "materialize-shard-status":
        return materialize_shard_status(args.shard)
    if args.cmd == "self-check":
        return self_check()
    raise SystemExit(f"unknown command {args.cmd}")


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

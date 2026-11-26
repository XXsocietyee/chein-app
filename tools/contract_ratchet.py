#!/usr/bin/env python3
"""Ratchet for the Python contract suite in Tests/ContractChecks.

Runs every test_*.py module (one subprocess per module, in parallel), collects
failing test ids and compares them with docs/release/contract-failing-baseline.txt.

  --check   exit 1 on a new failure or a baseline entry that now passes
  --update  rewrite the baseline from this run (sorted; keeps `  # note` suffixes)
  (none)    just print the failing ids
"""
import argparse
import json
import os
import subprocess
import sys
import unittest
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SUITE = ROOT / 'Tests' / 'ContractChecks'
BASELINE = ROOT / 'docs' / 'release' / 'contract-failing-baseline.txt'
MODULE_TIMEOUT = 600


def worker(module):
    sys.path.insert(0, str(SUITE))
    sys.path.insert(0, str(ROOT))
    suite = unittest.defaultTestLoader.loadTestsFromName(module)
    result = unittest.TestResult()
    suite.run(result)
    failing = {t.id() for t, _ in result.failures + result.errors}
    json.dump(sorted(failing), sys.__stdout__)


def run_module(module):
    env = dict(os.environ, PYTHONPATH=str(ROOT))
    try:
        proc = subprocess.run([sys.executable, __file__, '--worker', module], cwd=ROOT, env=env,
                              capture_output=True, text=True, timeout=MODULE_TIMEOUT)
        return module, json.loads(proc.stdout.strip().splitlines()[-1])
    except Exception as exc:  # crash/timeout/unparsable output counts as the module failing
        return module, [f'{module}.<module-crashed:{type(exc).__name__}>']


def run_suite(jobs):
    modules = sorted(p.stem for p in SUITE.glob('test_*.py'))
    with ThreadPoolExecutor(max_workers=jobs) as pool:
        results = pool.map(run_module, modules)
    return sorted({t for _, ids in results for t in ids})


def read_notes():
    """Map baseline id -> note. A line is `<id>` or `<id>  # <note>` (e.g. `# merchant release`)."""
    notes = {}
    if not BASELINE.exists():
        return notes
    for line in BASELINE.read_text().splitlines():
        name, _, note = line.partition('#')
        name = name.strip()
        if name:
            notes[name] = note.strip()
    return notes


def read_baseline():
    return sorted(read_notes())


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--check', action='store_true')
    ap.add_argument('--update', action='store_true')
    ap.add_argument('--worker')
    ap.add_argument('--jobs', type=int, default=os.cpu_count() or 4)
    args = ap.parse_args()
    if args.worker:
        worker(args.worker)
        return 0
    failing = run_suite(args.jobs)
    if args.update:
        notes = read_notes()
        BASELINE.write_text(''.join(f'{t}  # {notes[t]}\n' if notes.get(t) else f'{t}\n' for t in failing))
        print(f'contract ratchet: baseline rewritten with {len(failing)} failing tests')
        return 0
    if not args.check:
        print('\n'.join(failing))
        print(f'contract ratchet: {len(failing)} failing')
        return 0
    base = set(read_baseline())
    new = sorted(set(failing) - base)
    fixed = sorted(base - set(failing))
    for t in new:
        print(f'NEW FAILURE (not in baseline): {t}')
    for t in fixed:
        print(f'NOW PASSING (remove from baseline; run --update): {t}')
    print(f'contract ratchet: {len(failing)} failing, baseline {len(base)}, new {len(new)}, fixed {len(fixed)}')
    return 1 if new or fixed else 0


if __name__ == '__main__':
    sys.exit(main())

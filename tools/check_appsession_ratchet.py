#!/usr/bin/env python3
"""Line-count ratchet for the single-writer glue files. They may shrink, never grow.

When a file shrinks, lower its ceiling here in the same change so the gain is locked in.
"""
import pathlib, sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
CEILINGS = {
    'App/AppSession.swift':     7977,
    'App/AppCompositionRoot.swift':     4175,
}

failed = False
for rel, ceiling in CEILINGS.items():
    count = len((ROOT / rel).read_text(encoding='utf-8').splitlines())
    if count > ceiling:
        print(f'FAIL {rel}: {count} lines > ratchet {ceiling}. Extract into a new file instead of growing the glue file.')
        failed = True
    elif count < ceiling:
        print(f'NOTE {rel}: {count} < ratchet {ceiling}; lower CEILINGS in tools/check_appsession_ratchet.py')
if failed:
    raise SystemExit(1)
print('PASS appsession ratchet')

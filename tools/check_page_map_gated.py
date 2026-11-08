#!/usr/bin/env python3
"""FP-C10: page-map.csv must not call a screen `exists` when its notes say the primary write is gated.

Statuses: exists | partial | gated | merged-into:<path> | dropped:<reason>. A `gated` row has a native screen whose live action is
off in the shipped composition (read parity may be wired). Exit 1 and print the offending rows otherwise."""
import csv
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
GATED_PHRASE = re.compile(r'\b(?:live|write|writes|upload|submission|publish|save|payout)\b[^.;]*\bgated\b', re.I)
VALID = re.compile(r'^(exists|partial|gated|merged-into:.+|dropped:.+)$')


def check(path=ROOT / 'docs/parity/page-map.csv'):
    problems = []
    with open(path, newline='') as handle:
        for row in csv.DictReader(handle):
            status, notes = row['status'], row['notes']
            if not VALID.match(status):
                problems.append((row['mini_path'], f'unknown status {status!r}'))
            if status == 'exists' and GATED_PHRASE.search(notes):
                problems.append((row['mini_path'], 'status exists but notes say the live action is gated'))
            if status == 'gated' and not GATED_PHRASE.search(notes):
                problems.append((row['mini_path'], 'status gated but notes do not say what is gated'))
    return problems


if __name__ == '__main__':
    found = check()
    for mini, why in found:
        print(f'{mini}: {why}')
    sys.exit(1 if found else 0)

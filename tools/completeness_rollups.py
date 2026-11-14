#!/usr/bin/env python3
"""Re-compute the roll-up rows of docs/release/completeness-matrix.csv (rule CL-02.R).

A roll-up row's evidence names its open children ("rollup: k/n child rows not DONE: a, b. ...").
A child is satisfied when its status is DONE or `IN-PROGRESS (production off ...)`: the call site
and the route exist and only `forcedOff` / `ReleaseMoneyWriteSwitch` keeps it off on purpose.
`IN-PROGRESS (screen/code on ..., not finished)` and MISSING do not count. Nested roll-ups
(22.2 -> 22.1, 十一/十四 -> 十三 -> 十三-NN) are evaluated to a fixed point.

Usage:
  tools/completeness_rollups.py            # report every roll-up and what keeps it open
  tools/completeness_rollups.py --apply    # also close satisfied roll-ups in the CSV and the .md table
  tools/completeness_rollups.py --rows OWN-22.1,OWN-十三   # report only these rows
A roll-up is never downgraded here; an open roll-up keeps its status and evidence.
"""
import argparse
import csv
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CSV_PATH = ROOT / "docs/release/completeness-matrix.csv"
MD_PATH = ROOT / "docs/release/completeness-matrix.md"
OPEN_CHILDREN = re.compile(r"rollup: (\d+)/(\d+) child rows not DONE: (.*?)\.(?: |$)")


def satisfied(status: str) -> bool:
    return status == "DONE" or status.startswith("IN-PROGRESS (production off")


def open_children(evidence: str):
    match = OPEN_CHILDREN.search(evidence)
    if not match:
        return None
    listed = match.group(3).split(";")[0]
    return int(match.group(2)), [child.strip() for child in listed.split(",") if child.strip()]


def evaluate(rows):
    status = {row["requirement id"]: row["status"] for row in rows}
    rollups = {}
    for row in rows:
        parsed = open_children(row["evidence"])
        if parsed:
            rollups[row["requirement id"]] = parsed
    changed = True
    while changed:
        changed = False
        for rid, (_, children) in rollups.items():
            if status[rid] != "DONE" and all(satisfied(status.get("OWN-" + c, "MISSING")) for c in children):
                status[rid] = "DONE"
                changed = True
    report = {}
    for rid, (total, children) in rollups.items():
        blocking = [(c, status.get("OWN-" + c, "not in matrix")) for c in children
                    if not satisfied(status.get("OWN-" + c, "MISSING"))]
        production_off = [c for c in children if status.get("OWN-" + c, "").startswith("IN-PROGRESS (production off")]
        report[rid] = (total, children, blocking, production_off, status[rid])
    return report


def md_row(row) -> str:
    return "| " + " | ".join(value.replace("|", "\\|") for value in row.values()) + " |"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--rows", default="")
    args = parser.parse_args()
    # Keep the file's own line endings (the matrix is CRLF); a rewrite must change only the rows it closes.
    terminator = "\r\n" if b"\r\n" in CSV_PATH.read_bytes()[:4096] else "\n"
    with CSV_PATH.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        fields = reader.fieldnames
        rows = list(reader)
    report = evaluate(rows)
    wanted = [r for r in args.rows.split(",") if r] or sorted(report)
    closed = {}
    for rid in wanted:
        if rid not in report:
            print(f"{rid}: not a roll-up row")
            continue
        total, children, blocking, production_off, new_status = report[rid]
        if blocking:
            print(f"{rid}: open; {len(blocking)}/{total} children not satisfied under CL-02.R: "
                  + ", ".join(f"{c} ({s})" for c, s in blocking))
        else:
            note = f"; production off: {', '.join(production_off)}" if production_off else ""
            print(f"{rid}: satisfied under CL-02.R ({total} children{note})")
            closed[rid] = (total, children, production_off)
    if not args.apply:
        return 0
    by_id = {row["requirement id"]: row for row in rows}
    md_lines = MD_PATH.read_text(encoding="utf-8").split("\n")
    md_index = {line.split(" | ")[0][2:]: i for i, line in enumerate(md_lines) if line.startswith("| ") and " | " in line}
    for rid, (total, children, production_off) in closed.items():
        row = by_id[rid]
        if row["status"] == "DONE":
            continue
        was = row["evidence"].split("Was: ", 1)[1] if "Was: " in row["evidence"] else row["status"] + "."
        note = f"; counted as satisfied while production off: {', '.join(production_off)}" if production_off else ""
        row["status"] = "DONE"
        row["evidence"] = (f"rollup: all {total} native child rows satisfied under CL-02.R "
                           f"(listed open on e3264af9f: {', '.join(children)}){note}. Was: {was}")
        if rid in md_index:
            md_lines[md_index[rid]] = md_row(row)
    with CSV_PATH.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, lineterminator=terminator)
        writer.writeheader()
        writer.writerows(rows)
    MD_PATH.write_text("\n".join(md_lines), encoding="utf-8")
    print(f"applied: {len(closed)} roll-up rows satisfied")
    return 0


if __name__ == "__main__":
    sys.exit(main())

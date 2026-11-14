"""CL-02.R: a roll-up child that is IN-PROGRESS (production off) counts as satisfied (OWN-22.1, OWN-22.2, OWN-十三, OWN-十一, OWN-十四)."""
import importlib.util
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("completeness_rollups", ROOT / "tools/completeness_rollups.py")
rollups = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(rollups)


def row(rid, status, evidence=""):
    return {"requirement id": rid, "status": status, "evidence": evidence + " Was: MISSING."}


class CompletenessRollupRuleTests(unittest.TestCase):
    def test_production_off_child_counts_and_nested_rollups_close(self):
        rows = [
            row("OWN-十六", "MISSING", "e3264af9f: rollup: 2/14 child rows not DONE: 十六-12, 十六-13."),
            row("OWN-十六-12", "IN-PROGRESS (production off: ReleaseMoneyWriteSwitch)"),
            row("OWN-十六-13", "IN-PROGRESS (production off: forcedOff)"),
            row("OWN-20.1", "DONE"),
            row("OWN-22.1", "MISSING", "e3264af9f: rollup: 2/9 child rows not DONE: 十六, 20.1."),
            row("OWN-22.2", "MISSING", "e3264af9f: rollup: 1/1 child rows not DONE: 22.1."),
        ]
        report = rollups.evaluate(rows)
        self.assertEqual(report["OWN-十六"][4], "DONE")
        self.assertEqual(report["OWN-十六"][3], ["十六-12", "十六-13"])
        self.assertEqual(report["OWN-22.1"][4], "DONE")
        self.assertEqual(report["OWN-22.2"][4], "DONE")

    def test_unfinished_code_child_does_not_count(self):
        rows = [
            row("OWN-21.1", "IN-PROGRESS (code on e3264af9f, not finished)"),
            row("OWN-21.2", "IN-PROGRESS (production off: ReleaseMoneyWriteSwitch)"),
            row("OWN-十三-02", "MISSING", "e3264af9f: rollup: 2/8 child rows not DONE: 21.1, 21.2."),
            row("OWN-十三", "MISSING", "e3264af9f: rollup: 1/11 child rows not DONE: 十三-02."),
            row("OWN-十四", "MISSING", "e3264af9f: rollup: 1/1 child rows not DONE: 十三."),
        ]
        report = rollups.evaluate(rows)
        self.assertEqual(report["OWN-十三-02"][2], [("21.1", "IN-PROGRESS (code on e3264af9f, not finished)")])
        for rid in ("OWN-十三-02", "OWN-十三", "OWN-十四"):
            self.assertEqual(report[rid][4], "MISSING", rid)

    def test_matrix_rollups_parse_and_wp_r_rows_are_rollups(self):
        import csv
        with (ROOT / "docs/release/completeness-matrix.csv").open(newline="", encoding="utf-8") as handle:
            report = rollups.evaluate(list(csv.DictReader(handle)))
        for rid in ("OWN-22.1", "OWN-22.2", "OWN-十三", "OWN-十一", "OWN-十四"):
            self.assertIn(rid, report)

    def test_status_rules_carry_cl02r(self):
        rules = (ROOT / "docs/release/completeness-matrix.md").read_text(encoding="utf-8")
        self.assertIn("CL-02.R", rules)
        self.assertIn("tools/completeness_rollups.py", rules)


if __name__ == "__main__":
    unittest.main()

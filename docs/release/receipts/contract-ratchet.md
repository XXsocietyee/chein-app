# Contract suite ratchet

The Python contract suite (`Tests/ContractChecks`) has had no CI job since `run_static_checks.py`
left `native-ios.yml` (f329ff518). `tools/contract_ratchet.py` keeps it from drifting further.

- Baseline: `docs/release/contract-failing-baseline.txt` (sorted failing test ids, 259 at creation).
- Check (~2 min, parallel by module): `python3 tools/contract_ratchet.py --check`
  fails on a failure not in the baseline (regression) or a baseline entry that now passes.
- After fixing tests: `python3 tools/contract_ratchet.py --update`, commit the shrunk baseline.
  Never add entries by hand to hide a regression; the baseline only shrinks.
- Plain `python3 tools/contract_ratchet.py` prints the current failing ids.
- CI: `ci_scripts/ci_pre_xcodebuild.sh` runs `--check` as a non-blocking warning on the Build action.
  It is not part of `check_scaffold.py` (too slow) and not wired into `run_targeted_native.py`
  (that runner is hash-bound to a fixed path contract).

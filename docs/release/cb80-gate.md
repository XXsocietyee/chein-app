# CB80 release gate

Base: `origin/rc/20261108` `89dcba807e7e5439182ff8852d6600d1fa9fdd49`.
Branch: `cursor/cb80`.
Version left at `0.1.0` (`1`) in `Config/Base.xcconfig`.
`tools/current_ci_manifest.json` was not refreshed. This note does not claim all PASS.

These are the two commands in the `release-gate` job on this RC (`.github/workflows/ios-ci.yml`). No Swift compiler was used. No view was edited. No check was deleted or weakened.

## `python3 tools/check_scaffold.py`

Exit 0.

```text
PASS structural checks: 4340 Swift source files, 14323 bilingual keys, references, scheme, read-only expected project equivalence
SCOPE: this script does not run Swift/Xcode, previews, simulator/device, accessibility or live backend checks; see separate evidence
```

## `python3 tools/current_ci.py check`

Exit 1. This is the known ledger failure. It stays red.

First error:

```text
ValueError: Current source or test inventory changed without manifest audit
```

Command:

```text
python3 tools/current_ci.py check
```

The process prints a `SyntaxWarning` first, then raises that `ValueError`. The warning is not a separate failing check: `ast.parse` warns on the non-raw `\.` in `Tests/ContractChecks/test_personal_theme_backpack_contract.py` line 133, and the string value still contains the backslash. That contract check was not edited.

```text
<unknown>:133: SyntaxWarning: invalid escape sequence '\.'
Traceback (most recent call last):
  File "/agent/repos/chengyin-app/tools/current_ci.py", line 609, in <module>
    if __name__ == '__main__': main()
                               ^^^^^^
  File "/agent/repos/chengyin-app/tools/current_ci.py", line 602, in main
    manifest = verified_manifest(args.root)
               ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/agent/repos/chengyin-app/tools/current_ci.py", line 539, in verified_manifest
    require(data['snapshot'] == actual, 'Current source or test inventory changed without manifest audit')
  File "/agent/repos/chengyin-app/tools/current_ci.py", line 69, in require
    raise ValueError(message)
ValueError: Current source or test inventory changed without manifest audit
```

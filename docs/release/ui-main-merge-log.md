# ui/main merge log

Base: cfbc9aa75 (already contained ui/d6 b85ae2741, an older ui/d2/ui/d4/d7 via ddd3589da).

| Merged | SHA | Result |
|---|---|---|
| ui/d2 round 4 | 0f44c1f59 | conflicts in 7 files; design side for views, registry union, pbxproj regenerated (2f22c9920) |
| ui/d4 round 5 | 12bf99e8e | clean |
| DES-D7 round 4 | 3654c85d0 | clean |

Strings: all ui-strings-*.json keys are in Resources/Localizable.xcstrings (check_catalog_coverage.py passes); ui-strings-d1.json targets the separate AuthEntry table.

Build 1 (design-batch int) failed on kit compile errors, fixed by reading only (not yet rebuilt; builds paused by owner for machine load):
CYCachedAsyncImage:101, CYConfirmSheet (cancelIdentifier/titleIdentifier missing), CYHeroHeader:48, CYScreenStyle:28 and :150.

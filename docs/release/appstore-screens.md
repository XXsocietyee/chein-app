# App Store screenshots

DEBUG-only pack for eight player screens. `--appstore-screenshot <id>` opens a fixture that already exists in `DesignFixtureRegistry` on this branch. The harness does not add a fixture, a session, or a network path. PNGs are not in git. The integrator renders them with `python3 tools/render_appstore_screenshots.py` on a Mac that has Xcode. This note does not claim that any screenshot was rendered.

If `xcodebuild` or a required simulator is missing, the script exits 2 and prints `App Store screenshots were not rendered.`

## Sizes

Both sizes are portrait iPhone slots from App Store Connect. The script does not substitute a different pixel size.

| Slot | Simulator device | Pixels | Languages |
|---|---|---|---|
| 6.9-inch | iPhone 16 Pro Max | 1320 × 2868 | `en`, `zh-Hans` |
| 6.5-inch | iPhone 11 Pro Max | 1242 × 2688 | `en`, `zh-Hans` |

`iPhone XS Max` is the same 6.5-inch pixel size (1242 × 2688). The script uses it only when iPhone 11 Pro Max is not installed. The 6.9-inch device is iPhone 16 Pro Max only.

Output, gitignored: `build/appstore-screenshots/{6.9-inch|6.5-inch}/{en|zh-Hans}/{id}.png`. Thirty-two files when a render finishes. Derived data is `build/appstore-screenshots-derived/` and is also gitignored.

## Launch arguments

DEBUG builds only. The flag is read in `App/DesignFixtures/AppStoreScreenshotHarness.swift`.

| Argument | Value |
|---|---|
| `--appstore-screenshot` | one id from the table below |
| `--appstore-screenshot-language` | `en` or `zh-Hans` |
| `-preferences.language` | the same `en` or `zh-Hans` (set before `QuestifyApp` reads language storage) |
| `-AppleLanguages` | `(en)` or `(zh-Hans)` |
| `-AppleLocale` | `en_US` or `zh_Hans` |

An unknown id does not create a session. The existing design-fixture registry shows its unknown-fixture notice. No request is sent. Money stays behind the existing `ReviewedAreaSwitch`. This pack does not show a payment or a payout as succeeded. Unknown values on the underlying fixtures stay an em dash (—).

## Screens

Each row is one existing fixture. Both device sizes apply to every row: 6.9-inch iPhone 16 Pro Max at 1320 × 2868, and 6.5-inch iPhone 11 Pro Max at 1242 × 2688.

| id | Screen | Fixture id | 6.9-inch | 6.5-inch | English caption | zh-Hans caption |
|---|---|---|---|---|---|---|
| home | Home | d2-home | iPhone 16 Pro Max, 1320 × 2868 | iPhone 11 Pro Max, 1242 × 2688 | See what is happening nearby | 看看附近正在发生的事 |
| search | Search | d2-search | iPhone 16 Pro Max, 1320 × 2868 | iPhone 11 Pro Max, 1242 × 2688 | Search the map and themes | 搜索地图和主题 |
| square | Square | d2-square | iPhone 16 Pro Max, 1320 × 2868 | iPhone 11 Pro Max, 1242 × 2688 | Read the square | 看看广场 |
| play | Play | d2-play | iPhone 16 Pro Max, 1320 × 2868 | iPhone 11 Pro Max, 1242 × 2688 | Follow the route and check in | 沿着路线打卡 |
| roam | Roam | d2-roam | iPhone 16 Pro Max, 1320 × 2868 | iPhone 11 Pro Max, 1242 × 2688 | Walk the city | 在城里漫步 |
| inbox | Messages | d2-inbox | iPhone 16 Pro Max, 1320 × 2868 | iPhone 11 Pro Max, 1242 × 2688 | Open your messages | 打开消息 |
| me | Account | d2-me | iPhone 16 Pro Max, 1320 × 2868 | iPhone 11 Pro Max, 1242 × 2688 | Your profile and growth | 你的资料和成长 |
| clubs | Clubs | d4-directory | iPhone 16 Pro Max, 1320 × 2868 | iPhone 11 Pro Max, 1242 × 2688 | Find a club | 找一个俱乐部 |

Fixture ids are the existing `--design-fixture` names: `d2-home`, `d2-search`, `d2-square`, `d2-play`, `d2-roam`, `d2-inbox`, `d2-me`, and `d4-directory`. None of them was copied from another branch.

## Render

```
python3 tools/render_appstore_screenshots.py --check
python3 tools/render_appstore_screenshots.py
```

`--check` only compares the harness, the registry, and this document. It does not render. The render command builds the Debug simulator app with `CODE_SIGNING_ALLOWED=NO`, boots a temporary simulator for each size, launches each screen in `en` and `zh-Hans`, and writes PNGs. It deletes those simulators when it finishes. It does not archive, upload, or contact a host.

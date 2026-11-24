# cursor/native-gallery

DEBUG-only native iOS design gallery for owner screenshot approval. Base is `origin/ui/combined-r6` `f1115875e53a3fbc03969720d44e91f01eeb5ada`. No product screen was edited.

## Registry

The only edit in `App/DesignFixtures/DesignFixtureRegistry.swift`:

```swift
case let name where name == "native-gallery" || name.hasPrefix("native-gallery-"):
    return AnyView(NativeGalleryFixture(route: name))
```

Launch with `--design-fixture <route>`. Routes are listed in `docs/port/accept/cursor-gallery.txt` (61 lines: the index plus 8 component sections and 12 screens, each in light, dark, and `.accessibility5`).

`native-gallery` is the index and does not force appearance. Every other route sets `preferredColorScheme` and `dynamicTypeSize` on the fixture:

| suffix | color scheme | Dynamic Type |
|---|---|---|
| `-light` | light | `.large` |
| `-dark` | dark | `.large` |
| `-ax5` | light | `.accessibility5` |

`-ax5` uses light so one launch shows the largest type size against a fixed scheme. Page margins on custom layouts are 16 pt. Grouped lists use the system inset. Cards use radius 12. Heroes use radius 20. Back is the system navigation back. No custom chevrons. No `.font(.system(size:))`. Type stops at `.caption`.

Selected player tab tint is mini-program `#7A5CFF`. Status tags use the mini-program status colours (dark `#22C55E` / `#D58300` / `#E5484D` / `#4C86FF`, light `#0B7A57` / `#96610A` / `#D0323B` / `#2563EB`) plus the violet accent. Primary buttons are `.borderedProminent` tinted with the mini-program action colour (black in light, `#F8F8F8` in dark). Secondary buttons are `.bordered`.

## Component sections

| slug | what it shows |
|---|---|
| `list-form` | inset-grouped Form: fields, picker, switch, value rows |
| `cards` | hero radius 20 and cards radius 12 |
| `sheets` | sheet with `.presentationDetents([.medium, .large])` |
| `empty-error` | `ContentUnavailableView` empty and error, error has 重试 |
| `buttons` | `.borderedProminent` and `.bordered` |
| `confirm` | confirmation dialog, destructive 确认放弃, cancel 继续编辑 |
| `status-tags` | 进行中 / 即将开始 / 已取消 / 营业中 / 试玩 |
| `type-ramp` | `.largeTitle` `.title` `.title2` `.title3` `.headline` `.body` `.callout` `.subheadline` `.footnote` `.caption` |

## Twelve screens

| # | slug | title | mini-program copy |
|---|---|---|---|
| 1 | `home` | 首页 | `chengyinhub-xcx/pages/index/index.wxml` |
| 2 | `square` | 动态 | `chengyinhub-xcx/pages/square/detail/index.wxml`, `chengyinhub-xcx/pages/talent/list/index.wxml` |
| 3 | `play-tab` | 玩法 | `chengyinhub-xcx/pages/index/index.wxml`, `chengyinhub-xcx/pages/topic/index/index.wxml` |
| 4 | `club-tab` | 发现 | `chengyinhub-xcx/pages/talent/list/index.wxml` |
| 5 | `topic-detail` | 主题详情 | `chengyinhub-xcx/pages/topic/index/index.wxml` |
| 6 | `activity-detail` | 活动详情 | `chengyinhub-xcx/pages/activity/detail/index.wxml`, `chengyinhub-xcx/subpackageMember/components/cy/scene-play-activity-detail/index.wxml` |
| 7 | `play` | 游玩 | `chengyinhub-xcx/pages/play/index.wxml`, `chengyinhub-xcx/pages/play/play-stage.wxml`, `chengyinhub-xcx/pages/play/play-topbar.wxml` |
| 8 | `club-home` | 俱乐部主页 | `chengyinhub-xcx/pages/club/detail/index.wxml` |
| 9 | `merchant` | 工作台 | `chengyinhub-xcx/pages/merchant/index/index.wxml`, `chengyinhub-xcx/components/tabBar/index.js` |
| 10 | `me` | 我的 | `chengyinhub-xcx/pages/member/index/index.wxml`, `chengyinhub-xcx/subpackageMember/components/cy/profile/index.wxml` |
| 11 | `settings` | 设置 | `chengyinhub-xcx/pages/shezhi/shezhi.wxml` |
| 12 | `lobby` | 开局大厅 | `chengyinhub-xcx/subpackageJourney/pages/seats/index.wxml` |

Accent and status colours are from `chengyinhub-xcx/style/tokens.wxss` (`--cy-ref-violet-500`, `--cy-color-status-*` on `page` and the light theme). Tab words 首页 / 动态 / 俱乐部 / 我的 and merchant 工作台 / 营销 / 模板 / 发现 / 我的 are from `chengyinhub-xcx/components/tabBar/index.js` and the square title 动态. Fixture names (陈小北, 西湖夜游漫步, 良渚秋日探索, 钱塘夜色, 清河坊茶馆, 杭州) are realistic stand-ins, not live accounts.

The square list path `pages/square/list` is not on current `hengyin` master. The filled 动态 mock uses the detail and 帖文 labels (城瘾玩家, 点赞, 评论, 收藏, 转发, 即将开始). The empty lines 广场还很安静 / 成为第一个发布创意路线的人吧 are the recorded square empty copy and are not drawn on the filled mock.

The live player tab bar is 首页, 漫游, 发布, 俱乐部, 我的. There is no separate 玩法 tab. `play-tab` is a mock list of playable topics (开始游玩, 试玩, 城市定向, 自由探索). `play` is the in-session screen.

Merchant production stays light. This gallery still has dark and ax5 for 工作台, because every screen has three modes.

## Not done

- Did not edit `project.pbxproj`, `Localizable.xcstrings`, or `tools/current_ci_manifest.json`.
- The Questify target lists each source file. `App/NativeGallery/*.swift` is not a member. `tools/generate_project.py` only globs `App/`, `App/Theme`, `App/DesignSystem`, `App/DesignFixtures`, `App/ClubKit`, `App/MerchantKit`, `App/CityKit`, and `Core`. Regenerating the project will also omit this folder until that glob includes `App/NativeGallery/*.swift`. Debug will not compile the new registry case until those two Swift files are in the app target. They are wrapped in `#if DEBUG`. Release exclusion for `App/DesignFixtures` does not name them; once they are added, keep them out of Release the same way, or rely on `#if DEBUG` stripping the body.
- `swiftc` is not on this machine. The new Swift files were not parsed.
- Did not open a pull request. Did not push `main`, `master`, `ui/main`, or any `ui/combined-*` branch.
- Did not edit TopicDetailView, ActivityDetailView, PlayExperienceView, or any other product screen. The gallery only mocks them.
- Did not copy mini-program screenshots or any secret into the repo.
- `python3 tools/check_typography_lint.py` fails on the new files: `NativeGalleryFixture.swift` raw text style 0 → 34, `NativeGalleryScreens.swift` raw text style 0 → 100. The gallery is required to use `.font(.largeTitle)` through `.font(.caption)`. The baseline was not raised.
- 取消 and 重试 are existing localization keys (Cancel / Retry in English). Those two button titles are `Text(verbatim:)` so an English launch still shows the mini-program words. Other gallery strings are not keys.

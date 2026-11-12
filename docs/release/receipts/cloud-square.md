# cloud-square

Branch `ui/cloud-square`. Base `ui/main` at `72d2eb9ec498de21ded7cf9215f2638d7195786f`.

Source: private `liboyang42-cpu/hengyin` folder `chengyinhub-xcx` at `1c80c5aea8f721ca8575e6108048495b100f5576`, including `docs/广场Strava化改版-交接文档.md`, `pages/square/components/cy/post-compose`, `cy/post-drafts`, `activity-picker`, `route-map`, `cy/post-actions`, `cy/popover`, `pages/square/utils/*`, and `utils/community-*.js`. This is the existing square feed and composer, not a new page.

## What landed

- Activity posts (`dataType` 1, reference type `ACTIVITY`, or a positive `activityId`; club `refType` 1) use the activity card: distance, node pace, duration, orange route line on the map ground, cleared banner, kudos stack, one inline comment, read-only repost state when the payload includes it, and an avatar follow control when the payload says the viewer is not following.
- Missing metrics stay an em dash. A fractional duration is not truncated to a whole number. Route points outside the geographic range are dropped. Fewer than two distinct points hides the line; a supplied snapshot is shown only when one exists.
- Posts without an activity keep the existing text and image card, including topic posts (`dataType` 2).
- The square pencil opens one composer sheet. Drafts, the activity list, and review are pages in that sheet. Like and follow reuse the existing social editor in that same sheet. The workspace stays on the overflow menu.
- Club activity posts use the same card. A double tap likes only through the existing club review, and only when injected writes are already permitted.
- Publish sends `activity_id` only when a positive activity is chosen. Omitting it keeps the previous body (`contents`, empty `pics`, `request_id`). Images and location are not sent.
- An unknown publish stores the request id on this device and stays locked. 确认结果 re-reads that saved id. A different id, a still-unknown read, or the default reader does not confirm it. A fresh feed read does not turn unknown into success.

## Hidden on purpose

- The activity flag stays hidden until a host injects a completed-activity reader. This change does not add a network client and does not edit `App/RegionalLaunchConfiguration.swift`.
- Image and location tools stay hidden. The reviewed create path does not accept those fields.
- In-site repost has no writer here. The control is read-only when `reposted` is present, and absent when the key is absent. Community rows stay out of the club repost toggle.
- Club follow stays hidden. Square follow is hidden unless the payload explicitly says not following, the viewer and author are different positive ids, and follow is not disabled.
- Payment, payout, withdrawal, virtual goods, merchant and coop writes, and password login are unchanged.

## Checks

`python3 tools/generate_project.py`, `python3 tools/check_design_lint.py`, and `python3 tools/check_scaffold.py` passed. Scaffold also runs catalog coverage, the privacy manifest, the release config, the AppSession ratchet, and the page-route table.

This environment has no Swift toolchain, so `swift test` was not run. No simulator screenshots were taken. Copy is English and zh-Hans in `Resources/SquareStrava.xcstrings`.

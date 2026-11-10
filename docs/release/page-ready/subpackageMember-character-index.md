# CB284 subpackageMember/character/index

PAGE-READY model for 我的角色卡. Native screen `App/CharacterCardReadbackView.swift`. Map status stays **partial**. No route was added and none was marked live. Views, string catalogs, the Xcode project, and the ledger were not edited.

Already on `rc/20261108`: `CharacterCardReadback.load` reads `GET api/play/character` and, when an activity is already in scope, `GET api/play/rpg/status`. Attribute level labels are stored on the card. Malformed payloads stay `UNKNOWN` and are not an empty success. Save stays `PlayWriteAvailability.characterSheetSave` with `isAvailable == false`. No save URL exists.

Added in Core: `CharacterCardPageModel` names loading, empty, error, unknown, and ready. A missing card cannot be ready, and its count is an em dash. A loaded empty attribute list has count `0`. Unknown stats (`null`, missing, `UNKNOWN`, a numeric string, a point-range percent) are `—`. A literal integer `0` stays `0`. The existing `CharacterRpgSheet.read` result and a non-blank `definitionSource` are now kept on the card. `UNKNOWN` and blank sources stay nil. Status overlays a sheet only when that read returns one. It does not open a new path.

Missing EN+zh-Hans keys (present copy is `W8Text`, not a catalog key). These eight keys already have en and zh-Hans: `characterCard.empty`, `characterCard.loading`, `characterCard.momentum`, `characterCard.refresh`, `characterCard.rpgStatus`, `characterCard.title`, `characterCard.traits`, `characterCard.unavailable`.

- `characterCard.heading.mine` — 本人角色卡 / My character card
- `characterCard.heading.template` — 角色模板 / Character template
- `characterCard.status.running` — 本局进行中 / Run in progress
- `characterCard.status.created` — 已建立 / Created
- `characterCard.status.notCreated` — 尚未建卡 / Card not created yet
- `characterCard.definition.partial` — 部分跨局属性展示当前主题定义，不代表建卡时原始区间。 / Some cross-run attributes show the current theme definition, not the original range at card creation.
- `characterCard.definition.snapshot` — 展示本局开始时的角色属性定义。 / Shows the character attribute definitions from the start of this run.
- `characterCard.definition.legacy` — 历史角色未保存建卡快照，当前按主题最新规则展示。 / This older character has no creation snapshot; shown with the theme’s latest rules.
- `characterCard.definition.recorded` — 仅展示服务端已记录的本人角色数值。 / Showing only your character values recorded on the server.
- `characterCard.definition.template` — 当前尚未建立本人角色，以下为主题属性模板与初始值。 / You have no character yet; below are the theme’s attribute template and starting values.
- `characterCard.scope.topic` — 同主题跨局保留 / Kept across runs of this theme
- `characterCard.scope.run` — 每局重置 / Reset every run
- `characterCard.scope.unknown` — 保留范围未记录 / Retention not recorded
- `characterCard.range` — 范围 %lld–%lld / Range %lld–%lld
- `characterCard.facet` — 侧面 / Aspect
- `characterCard.aspect` — 本局特质 / Run trait
- `characterCard.failure.unauthorized` — 请先登录后查看角色卡 / Sign in to view the character card
- `characterCard.failure.forbidden` — 无权查看该角色卡 / You do not have access to this character card
- `characterCard.failure.error` — 角色卡加载失败，请稍后重试 / Could not load the character card. Try again later.
- `characterCard.dice` — 掷骰练习 / Dice roller
- `characterCard.dice.practice` — 练习 / Practice
- `characterCard.adjust` — 调整 / Adjust
- `characterCard.done` — 完成 / Done
- `characterCard.preview` — 本机预览的调整 / Adjustments previewed on this device
- `characterCard.reset` — 还原 / Reset
- `characterCard.save` — 保存 / Save
- `characterCard.save.title` — 暂未开放 / Not available yet (`roam.w208.passport.closed` is a different key)
- `characterCard.save.message` — 角色卡修改暂时无法保存到服务器。以下调整只是本机预览。 / Character sheet changes can't be saved to the server yet. Adjustments below are a local preview only.

Left: `CharacterCardReadbackView` still branches on `isCurrent`, `availability`, and an empty attribute list. It does not read `pageModel`, and it does not pass `rpgSheet` or `definitionSource` into `CharacterSheetDetailView`. `CharacterCardAttribute.percent` still returns `0` when `max <= min`. Practice-roll history still stores a missing kept, total, or DC as `0`. A dismissed lease still looks like loading. Save still has no server contract. Screenshot and a DEBUG host for this screen were not added. Xcode was not run.

# port-1 new strings (not added to catalogs; add to the matching table)

| key | table | en | zh-Hans |
|---|---|---|---|
| `club.host.skills.selectedCount %lld` | Localizable | `%lld selected` | `已选 %lld 项` |
| `club.ops.create.needType` | Localizable | `Choose a club type to continue.` | `请先选择俱乐部类型` |
| `club.ops.create.needName` | Localizable | `Enter a club name to continue.` | `请先填写俱乐部名称` |
| `club.ops.create.needCity` | Localizable | `Enter the club's city to continue.` | `请先填写所在城市` |
| `club.ops.counter %lld %lld` | Localizable | `%1$lld / %2$lld` | `%1$lld / %2$lld` |
| `club.gov.expiredCode.hint` | Localizable | `This code has expired. Issue a new one to check in guests.` | `团码已过期，请重新出码后再核销。` |
| `club.topic.verify.title` | Localizable | `Check-in` | `核销` |
| `club.topic.verify.pending` | Localizable | `Pending` | `待核销` |
| `club.topic.verify.verifiedByMe` | Localizable | `Checked in by me` | `我已核销` |
| `club.topic.verify.headcount` | Localizable | `Session headcount` | `本场总人数` |
| `club.topic.primary.reviewing` | Localizable | `Awaiting review` | `等待审核中` |
| `club.topic.primary.rejected` | Localizable | `Edit and resubmit` | `修改并重新提交` |
| `club.topic.primary.confirmed` | Localizable | `Start preparing` | `开始准备` |
| `club.topic.primary.preparing` | Localizable | `Start session` | `开始活动` |
| `club.topic.primary.running` / `.selfrun` | Localizable | `End session` | `结束活动` |
| `club.topic.primary.ended` | Localizable | `View settlement report` | `查看结算报告` |
| `clubOpsGov.report.targetType.CLUB` | ClubOpsGovernance | `Club` | `俱乐部` |
| `clubOpsGov.report.targetType.ACTIVITY` | ClubOpsGovernance | `Activity` | `活动` |
| `clubOpsGov.report.targetType.MEMBER` | ClubOpsGovernance | `Member` | `成员` |
| `clubOpsGov.reasonRequired.ban/.transfer/.report/.appeal` (declared in Core only, not rendered yet) | ClubOpsGovernance | `Enter a ban reason.` / `Enter a handover reason.` / `Describe the facts.` / `Describe the facts.` | `请填写封禁原因` / `请填写交接原因` / `请填写事实说明` / `请填写事实说明` |

Note: the report target card reads the optional seed key `targetName`; no current entry supplies it, so only the type shows until a host passes the display name (the seed is display-only and is not part of the command anchors).

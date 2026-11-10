# pages/address/address

Native screen `App/ProfileParticipantsView.swift` (常用参与人信息列表, map status partial). This lane did not edit the view. No route was added, and none was marked live.

Already on `rc/20261108`: bodyless `POST api/user/address/list` and `api/user/address/info` through `ProfileService` / `ProfileSessionReader`; row fields `id`, `fullName`, `mobilePhone`, `province`, `detailAddress`, `isDefault` on `ProfileParticipant`; loading, empty, and error chrome on `ProfileReadScreen`; an unknown mutation outcome on `ParticipantMutationCoordinator`. `participants()` still returns rows only.

Added `ProfileParticipantListFacts`, `ProfileParticipantListPage`, and `ProfileParticipantListCoordinator` in `Core/ProfileContracts.swift`, plus `ProfileService.participantListFacts` on the same list route. Phases are loading, empty, error, unknown, and ready. The table `total` is the only count. A missing, null, or unsettled total is an em dash (`—`, U+2014). A literal `0` stays `0`. The row count is never substituted. A numeric string, including `"0"`, is malformed and stays unknown. A refresh keeps the retained list; a first-load failure does not become an empty list. The list card copies only `fullName` and `mobilePhone`.

`ProfileParticipantsView` still loads `[ProfileParticipant]` through `profileParticipants()` and does not read this page. Map status stays partial.

## Missing keys

These source strings have no EN + zh-Hans entry in `Resources/Localizable.xcstrings`. This lane did not add them.

| Key | Source zh-Hans |
|---|---|
| `profile.participants.refreshing` | 正在更新参与人信息… |
| `profile.participants.loadFailed` | 参与人信息加载失败 |
| `profile.participants.serviceUnavailable` | 服务暂不可用，请稍后重试 |
| `participant.list.deleteTitle` | 删除这条参与人信息? |
| `participant.list.deleteBody` | 姓名和手机号只用于报名联系与到场核验,删除只影响之后报名时选用。 |
| `participant.list.deleteIrreversible` | 此操作不可撤销,删除后需要重新填写参与人资料 |
| `participant.list.deleteKeepsRegistration` | 已经产生的报名不会因此取消,历史报名记录仍然有效 |
| `participant.list.deleteConfirm` | 删除参与人信息 |
| `participant.list.deletedTitle` | 参与人信息已删除 |
| `participant.list.deletedDetail` | 历史报名记录不受影响。 |

`网络异常，请重试` already exists as `playerJourney.parity.network`. This list does not use that key, and no participant key carries the same words.

Already catalogued, so not listed above: `profile.participants.title`, `profile.participants.empty`, `profile.participants.emptyHint`, `profile.participants.unnamed`, `profile.participants.rowPurpose`, `profile.participants.name`, `profile.participants.phone`, `participant.form.add`, `participant.form.edit`, `participant.form.delete`, `action.retry`, `profile.loading`.

## Left

The view still clears the list while reloading, and a missing `total` never reaches the screen. Delete confirmation still uses `participant.form.confirmDelete` / `participant.form.confirmDeleteHint`, not the source danger-confirm copy above. Xcode was not run.

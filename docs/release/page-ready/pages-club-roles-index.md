# CB251 pages/club/roles/index
PAGE-READY on rc/20261108. Native screen `App/ClubOpsGovernanceSections.swift`. Map status stays gated. No route was invented and none was marked live.
The list contract is already wired: `ClubGovernanceRead.roles` is `api/club/roles/list`, joined in `ClubOpsRoleRoster` with `api/club/members`. Assign and revoke stay the existing writes. `api/club/roles/assign-receipt` and `api/club/roles/revoke-receipt` stay missing.
Loading is `ClubRoleListRead.loading` and `ClubRoleAssignmentReadModel.loading`. Empty is `delegableMemberCount == 0` and an empty assignable roster. Error is `ClubOpsPageFailureCopy` for `.roles`; denial keeps its own note.
UNKNOWN stays nil (name, role name, expiry, unread member count) or the unknown-outcome key. It is never shown as 0. A literal 0 stays 0, including an empty delegable count and assignment version 0.
This page is not on the player-first entry. `ClubGovernanceHomeEntries` is host status and the feed only. `showsRoleManagement` is false when signed out and for a member without `club:role:manage`. A missing grant stays hidden.
`showsMerchantChoice` stays false. Money switches were not set true. No US URL and no secrets were added.
Missing EN+zh-Hans keys: none. Roles keys in Localizable, ClubOpsGovernance, ClubRoleAssignment, and ClubRoleRevocation already have translated en and zh-Hans.
Left: recovery sections still draw when the receipt route is missing; `clubOpsGov.roles.emptyBody` and `clubOpsGov.roles.assign.caption` are catalogued and not rendered; the literal `Audit #` has no key; memberId preselect is not routed. Footer zh-Hans is `撤销后立即生效` and does not match the older pin. Strings and tests were not changed.
Existing coverage stays in ClubOpsGovernancePresentationTests, ClubDetailEntryGateTests, ClubRoleAssignmentOptionsTests, and ClubRoleOriginalDispatchRestoreTests. No Swift run and no Xcode Cloud result.

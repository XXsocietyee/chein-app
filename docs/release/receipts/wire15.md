# wire15

[x] 4c4fabd742d9f8326e972eeb9261dbdb7dba9f9c

PR 1007. Branch `cursor/wire15`. Parent `ba70d72c4`. Base `rc/20261108`. +101/−1.

The join-requests section in `App/ClubManagementView.swift` reads `ClubJoinRequestsPageReady.pendingCountText`. The count passed today is the loaded array length, so a literal 0 stays 0 and the empty state remains. The section stays hidden when the route is not already live or the viewer cannot govern. Not merged to rc.

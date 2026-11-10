# wire22

[x] b974ca421e05857747a33e286be0397b7745c3ec

PR 1013. Branch `cursor/wire22`. Base `rc/20261108`. +95/−6.

Member home reads `MemberHomePageModel.state` with the optional friend, follow, and fans counts from before `?? 0`. A missing count is an em dash. A literal 0 stays 0. The stored Ints used by existing readers are unchanged. Not merged to rc.

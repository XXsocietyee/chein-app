# CB12 staging verify

Backend branch `claude/be-v2-fixes` on private repo `liboyang42-cpu/chengyin`. This note is on `cursor/cb12`, based on `origin/rc/20261108` `67053ccb33c0e1ad35a7508f8546ae9076fd82e5`.

Routes executed: **0** of 370. Every route in the matrix is **UNVERIFIED**. No migration file was applied. No MySQL integration test was started.

## Backend SHA

The full object id of `claude/be-v2-fixes` was not resolved. This credential received HTTP 404 (`Repository not found`) from `https://github.com/liboyang42-cpu/chengyin.git` and from `gh api repos/liboyang42-cpu/chengyin`. The remaining digits are left blank.

Public static tables on `liboyang42-cpu/chengyin-ios` branch `claude/backend-route-tables-20261108` (`24ab11622236fb9fca483ed4e1ddef05b50e9279`, directory `docs/backend-routes/`) record the prefix `537e43c74` in `route-table-rt-01.md` and `route-table-rt-02.md`. `route-table-rt-04.md` and `ug-capability-registry.md` record `537e43c7`. Those prefixes are not a 40-digit object id.

`gh api repos/liboyang42-cpu/{hengyin,chengyin-ios,chengyin-app,chengyin-miniprogram}/commits/537e43c7` returned no commit. Public `hengyin` has no branch `claude/be-v2-fixes`. Its `master` is `147754ba8740abf208bda75cf86ed5901cac4c02`, and that tree has no `migration_g*_20261108.sql`.

The 370 paths below are copied from those static tables. This run did not read the Java controllers.

## Throwaway database

A local server was reached and then stopped. It is not the public gate's scratch image.

`sudo DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server` installed `mysql-server` `8.0.46-0ubuntu0.24.04.4`. `/usr/sbin/policy-rc.d` exits 101, so the package did not leave `mysqld` running. It was started by hand, bound to localhost:

```bash
sudo mkdir -p /var/run/mysqld && sudo chown mysql:mysql /var/run/mysqld
sudo mysqld --user=mysql --bind-address=127.0.0.1 --mysqlx=0 --port=3306 \
  --datadir=/var/lib/mysql --socket=/var/run/mysqld/mysqld.sock \
  --pid-file=/var/run/mysqld/mysqld.pid
```

The error log recorded ready for connections at 2026-11-09 06:34:22 UTC (10:34 PM PT, Sunday, Nov 8, 2026): `Version: '8.0.46-0ubuntu0.24.04.4'`, socket `/var/run/mysqld/mysqld.sock`, port 3306. `SELECT CONCAT(VERSION(), '|', @@version_comment)` returned `8.0.46-0ubuntu0.24.04.4|(Ubuntu)`. `@@bind_address` was `127.0.0.1`. `@@port` was `3306`.

```bash
sudo mysql --protocol=socket -e "CREATE DATABASE cb12_scratch CHARACTER SET utf8mb4;"
sudo mysql --protocol=socket -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='cb12_scratch';"
```

That count was **0**. `sudo mysqladmin --protocol=socket shutdown` then ran. Shutdown complete is in the error log at 2026-11-09 06:35:31 UTC (10:35 PM PT). A later `mysqladmin ping` could not open the socket.

The public funds workflow on `hengyin` (`.github/workflows/funds-mysql-it.yml`) starts container image `mysql:8.0.45` and continues only when `SELECT CONCAT(VERSION(), '|', @@version_comment)` equals `8.0.45|MySQL Community Server - GPL`. Docker was not installed here, that image was not pulled, and the local server's identity is the Ubuntu 8.0.46 string above. No statement from a migration file was sent to this server.

## Migrations, one file at a time

These commands were not run. The private checkout was not on disk, so the five names below are the files the static tables cite, and the `find` is how to discover any others on a real checkout. Apply one file per `mysql` process. Stop at the first non-zero status. The database argument stays a localhost scratch. This run's scratch ended with 0 tables.

```bash
git -C "$BACKEND" rev-parse HEAD
git -C "$BACKEND" rev-parse --abbrev-ref HEAD
find "$BACKEND/chengyinhub-admin/sql" -type f -name 'migration_g*_20261108.sql' | sort
```

Names cited by `docs/backend-routes/route-table-rt-01.md` on the iOS branch above:

- `chengyinhub-admin/sql/migration_g01_20261108.sql`
- `chengyinhub-admin/sql/migration_g02_20261108.sql`
- `chengyinhub-admin/sql/migration_g03_20261108.sql`
- `chengyinhub-admin/sql/migration_g04_20261108.sql`
- `chengyinhub-admin/sql/migration_g08_20261108.sql`

The first three are the expansion of the table's `migration_g0{1,2,3}_20261108.sql`. `migration_g08_20261108.sql` is named for the G08 tables. Other groups' filenames were not in those tables. Files applied in this run: **0**.

```bash
mysql --protocol=TCP -h 127.0.0.1 -P 3306 --user="$CB12_DB_USER" cb12_scratch \
  -e "SELECT DATABASE(), COUNT(*) FROM information_schema.tables WHERE table_schema=DATABASE();"
mysql --protocol=TCP -h 127.0.0.1 -P 3306 --user="$CB12_DB_USER" cb12_scratch < "$file"
```

Repeat the second command once per file, in the sorted `find` order. Keep the host on `127.0.0.1` or `localhost`.

## MySQL integration tests

`mvn` is not on `PATH` in this environment. The private tree was not checked out, so no `*MySqlIT.java` list was produced. Tests executed: **0**.

When a checkout of `claude/be-v2-fixes` exists, discover the classes on that checkout and pass those names. The `-Dtest` list inside public `hengyin` `ci/funds-mysql-it-gate.sh` is the funds suite on that public snapshot. It is a different set.

```bash
cd "$BACKEND"
mapfile -t classes < <(find chengyinhub-admin chengyinhub-system -name '*MySqlIT.java' -printf '%f\n' | sed 's/\.java$//' | sort -u)
printf '%s\n' "${classes[@]}"
export CHENGYIN_TEST_MYSQL_HOST=127.0.0.1
export CHENGYIN_TEST_MYSQL_PORT=3306
export CHENGYIN_TEST_MYSQL_USER="$CB12_DB_USER"
export CHENGYIN_TEST_MYSQL_PASSWORD="$CB12_DB_PASSWORD"
export CHENGYIN_TEST_MYSQL_DATABASE_SUFFIX="_cb12${RANDOM}"
mvn -B -pl chengyinhub-admin -am clean test \
  -DfailIfNoTests=false -Dsurefire.failIfNoSpecifiedTests=false \
  -Dtest="$(IFS=,; echo "${classes[*]}")"
```

`ci/funds-mysql-it-gate.sh` on public `hengyin` refuses a `CHENGYIN_TEST_MYSQL_HOST` other than `127.0.0.1`, `localhost`, or `::1`, and it probes that port with a TCP open before `mvn`. This run did not execute that script.

## Curl matrix

The loop below was not started. No HTTP status was recorded. `CB12_BASE` is the throwaway origin, for example `http://127.0.0.1:8080`, after a boot of this branch. Brace placeholders such as `{draftId}` stay literal; this run did not substitute ids. No backend process was started, so there was no origin to call.

```bash
case "$CB12_BASE" in
  *47.103.124.64*|*chengyinhub.com*|*chengyinhub.cn*)
    echo 'refusing production host'
    exit 2
    ;;
esac
test -n "$CB12_TOKEN"
while IFS=$'\t' read -r method path _static _src; do
  curl -sS -o /tmp/cb12-body -D /tmp/cb12-headers -w '%{http_code}\n' \
    -X "$method" \
    -H "Authorization: Bearer ${CB12_TOKEN}" \
    -- "${CB12_BASE}${path}"
  echo "$method $path UNVERIFIED"
done <<'ROUTES'
GET	/api/merchant/authoring/drafts	registered	rt-01 summary 1 row 1
POST	/api/merchant/authoring/drafts	registered	rt-01 summary 1 row 2
GET	/api/merchant/authoring/drafts/{draftId}	registered	rt-01 summary 1 row 3
POST	/api/merchant/authoring/drafts/{draftId}	registered	rt-01 summary 1 row 4
POST	/api/merchant/authoring/jobs	registered	rt-01 summary 1 row 5
GET	/api/merchant/authoring/jobs	registered	rt-01 summary 1 row 6
POST	/api/merchant/authoring/jobs/cancel	registered	rt-01 summary 1 row 7
GET	/api/merchant/authoring/main-line	registered	rt-01 summary 1 row 8
GET	/api/merchant/authoring/environment	registered	rt-01 summary 1 row 9
POST	/api/merchant/authoring/draft-selection/list	registered	rt-01 summary 1 row 10
POST	/api/merchant/authoring/draft-selection/resolve	registered	rt-01 summary 1 row 11
POST	/api/merchant/authoring/releases	registered, functionally dead	rt-01 summary 1 row 12
GET	/api/merchant/authoring/releases	registered	rt-01 summary 1 row 13
POST	/api/merchant/authoring/releases/{id}/withdraw	registered	rt-01 summary 1 row 14
GET	/api/merchant/authoring/public	registered	rt-01 summary 1 row 15
GET	/api/merchant/authoring/player/{merchantId}/game	registered	rt-01 summary 1 row 16
GET	/api/merchant/authoring/player/{merchantId}/requests/{requestId}	registered	rt-01 summary 1 row 17
GET	/api/merchant/city-value/report	UNREGISTERED	rt-01 summary 1 row 18
GET	/api/merchant/city-value/events	UNREGISTERED	rt-01 summary 1 row 19
GET	/api/merchant/city-value/event/{id}/benefit	UNREGISTERED	rt-01 summary 1 row 20
GET	/api/merchant/city-value/result/{id}	registered, functionally 503	rt-01 summary 1 row 21
POST	/api/merchant/crm/customers/{customerMemberId}/detail	registered	rt-01 summary 1 row 22
POST	/api/merchant/crm/customers/{customerMemberId}/contact	registered	rt-01 summary 1 row 23
POST	/api/merchant/crm/exports/{taskId}/status	registered	rt-01 summary 1 row 24
GET	/api/merchant/crm/exports/{taskId}/download	registered	rt-01 summary 1 row 25
POST	/api/ai/merchant/insight	registered	rt-01 summary 1 row 26
POST	/api/merchant/npc/avatar/generate	registered	rt-01 summary 1 row 27
POST	/api/merchant/npc/avatar/status	registered	rt-01 summary 1 row 28
POST	/api/merchant/npc/knowledge-review	registered	rt-01 summary 1 row 29
GET	/api/merchant/npc/knowledge-review/request	registered	rt-01 summary 1 row 30
POST	/api/club/channels	registered	rt-01 summary 2 row 1
POST	/api/club/admission/receipt	registered	rt-01 summary 2 row 2
POST	/api/club/badge/original-receipt	registered	rt-01 summary 2 row 3
POST	/api/club/event-ops/series/original-result	registered	rt-01 summary 2 row 4
POST	/api/club/post/operation/create	registered	rt-01 summary 2 row 5
POST	/api/club/post/operation/update	registered	rt-01 summary 2 row 6
POST	/api/club/post/operation/receipt	registered	rt-01 summary 2 row 7
POST	/api/club/post/operation/comment/create	registered	rt-01 summary 2 row 8
POST	/api/club/post/operation/comment/receipt	registered	rt-01 summary 2 row 9
POST	/api/club/open-settings/welcome-note-receipt	registered only if flag true	rt-01 summary 2 row 10
GET	/api/city-game/acquisition/state	UNREGISTERED	rt-01 summary 2 row 11
GET	/api/city-game/acquisition/titles	UNREGISTERED	rt-01 summary 2 row 12
GET	/api/city-game/acquisition/quote/{id}	UNREGISTERED	rt-01 summary 2 row 13
POST	/api/city-game/acquisition/command	UNREGISTERED	rt-01 summary 2 row 14
GET	/api/city-game/acquisition/request/{requestId}	UNREGISTERED	rt-01 summary 2 row 15
GET	/api/city-game/action-budget/state	UNREGISTERED	rt-01 summary 2 row 16
POST	/api/city-game/action-budget/command	UNREGISTERED	rt-01 summary 2 row 17
GET	/api/city-game/action-budget/result/{resultId}	UNREGISTERED	rt-01 summary 2 row 18
GET	/api/city-game/action-budget/request/{requestId}	UNREGISTERED	rt-01 summary 2 row 19
GET	/api/city-game/arrival-evidence/state	UNREGISTERED	rt-01 summary 2 row 20
GET	/api/city-game/arrival-evidence/merchant	UNREGISTERED	rt-01 summary 2 row 21
GET	/api/city-game/arrival-evidence/evidence/{id}	UNREGISTERED	rt-01 summary 2 row 22
POST	/api/city-game/arrival-evidence/command	UNREGISTERED	rt-01 summary 2 row 23
GET	/api/city-game/arrival-evidence/request/{id}	UNREGISTERED	rt-01 summary 2 row 24
GET	/api/city-game/neutral-tasks/state	UNREGISTERED	rt-01 summary 2 row 25
POST	/api/city-game/neutral-tasks/command	UNREGISTERED	rt-01 summary 2 row 26
GET	/api/city-game/neutral-tasks/request/{requestId}	UNREGISTERED	rt-01 summary 2 row 27
GET	/api/city-game/onsite-tasks/state	UNREGISTERED	rt-01 summary 2 row 28
GET	/api/city-game/onsite-tasks/result/{id}	UNREGISTERED	rt-01 summary 2 row 29
POST	/api/city-game/onsite-tasks/command	UNREGISTERED	rt-01 summary 2 row 30
GET	/api/city-game/onsite-tasks/request/{requestId}	UNREGISTERED	rt-01 summary 2 row 31
GET	/api/city-game/merchant/operations/availability	UNREGISTERED, no registration helper	rt-01 summary 2 row 32
POST	/api/city-game/merchant/operations/intent	UNREGISTERED, no registration helper	rt-01 summary 2 row 33
GET	/api/city-game/merchant/operations/request/{requestId}	UNREGISTERED, no registration helper	rt-01 summary 2 row 34
GET	/api/city-game/player-rules	UNREGISTERED, no registration helper	rt-01 summary 2 row 35
GET	/api/city-game/state/deltas	UNREGISTERED, no registration helper	rt-01 summary 2 row 36
GET	/api/friend/list	listed	rt-01 summary 3 row 1
POST	/api/friend/accept	listed	rt-01 summary 3 row 2
POST	/api/friend/cancel	listed	rt-01 summary 3 row 3
GET	/api/friend/directory	listed	rt-01 summary 3 row 4
GET	/api/friend/directory/detail	listed	rt-01 summary 3 row 5
GET	/api/friend/group/list	listed	rt-01 summary 3 row 6
POST	/api/friend/group/save	listed	rt-01 summary 3 row 7
POST	/api/friend/group/delete	listed	rt-01 summary 3 row 8
GET	/api/friend/relationship	listed	rt-01 summary 3 row 9
GET	/api/friend/receipt	listed	rt-01 summary 3 row 10
POST	/api/friend/reject	listed	rt-01 summary 3 row 11
GET	/api/friend/metadata	listed	rt-01 summary 3 row 12
POST	/api/friend/remark	listed	rt-01 summary 3 row 13
GET	/api/friend/metadata/receipt	listed	rt-01 summary 3 row 14
POST	/api/friend/metadata/settle	listed	rt-01 summary 3 row 15
GET	/api/friend/removal/receipt	listed	rt-01 summary 3 row 16
POST	/api/friend/removal/settle	listed	rt-01 summary 3 row 17
GET	/api/friend/progress	listed	rt-01 summary 3 row 18
POST	/api/reward-pledge/drafts	listed	rt-01 summary 3 row 19
POST	/api/reward-pledge/{pledgeId}/submit	listed	rt-01 summary 3 row 20
POST	/api/reward-pledge/{pledgeId}/confirm	listed	rt-01 summary 3 row 21
POST	/api/reward-pledge/{pledgeId}/freeze	listed	rt-01 summary 3 row 22
GET	/api/reward-pledge/{pledgeId}	listed	rt-01 summary 3 row 23
GET	/api/reward-pledge/{pledgeId}/stats	listed	rt-01 summary 3 row 24
POST	/api/reward-pledge/awards/{awardId}/return-to-pool	listed	rt-01 summary 3 row 25
GET	/api/reward-pledge/fulfilment/awards	listed	rt-01 summary 3 row 26
POST	/api/reward-pledge/fulfilment/resolve	listed	rt-01 summary 3 row 27
POST	/api/reward-pledge/fulfilment/preview	listed	rt-01 summary 3 row 28
POST	/api/reward-pledge/fulfilment/redeem	listed	rt-01 summary 3 row 29
POST	/api/reward-pledge/fulfilment/expire	listed	rt-01 summary 3 row 30
GET	/api/reward-pledge/pledges	listed	rt-01 summary 3 row 31 ; rt-02 G19
GET	/api/reward-pledge/review	listed	rt-01 summary 3 row 32 ; rt-02 G19
GET	/api/reward-pledge/review/{versionId}	listed	rt-01 summary 3 row 33 ; rt-02 G19
GET	/api/reward-pledge/ops/{op}/{key}	listed	rt-01 summary 3 row 34 ; rt-02 G19
POST	/api/reward-pledge/versions/{versionId}/hold	listed	rt-01 summary 3 row 35 ; rt-02 G19
POST	/api/reward-pledge/versions/{versionId}/withdraw	listed	rt-01 summary 3 row 36 ; rt-02 G19
POST	/api/workshop/owned/list	listed	rt-01 summary 4 row 1
POST	/api/workshop/owned/detail	listed	rt-01 summary 4 row 2
POST	/api/workshop/owned/package	listed	rt-01 summary 4 row 3
POST	/api/workshop/creator/pending-packages/author	listed	rt-01 summary 4 row 4
POST	/api/workshop/creator/pending-packages/list	listed	rt-01 summary 4 row 5
POST	/api/workshop/creator/pending-packages/detail	listed	rt-01 summary 4 row 6
POST	/api/workshop/creator/public-theme-use/preview	listed	rt-01 summary 4 row 7
POST	/api/workshop/creator/public-theme-use/status	listed	rt-01 summary 4 row 8
POST	/api/workshop/creator/public-theme-use/declare	listed	rt-01 summary 4 row 9
GET	/api/topic/cover/selection/current	listed	rt-01 summary 4 row 10
POST	/api/topic/cover/upload	listed	rt-01 summary 4 row 11
POST	/api/topic/cover/selection	listed	rt-01 summary 4 row 12
POST	/api/topic/cover/selection/status	listed	rt-01 summary 4 row 13
GET	/api/topic/cover/{assetId}/content	listed	rt-01 summary 4 row 14
POST	/api/topic/attribute-author	listed	rt-01 summary 4 row 15
GET	/api/topic/attribute-author/request	listed	rt-01 summary 4 row 16
GET	/api/native/blacklist/list	listed	rt-02 G13
GET	/api/native/blacklist/current	listed	rt-02 G13
GET	/api/native/blacklist/receipt	listed	rt-02 G13
POST	/api/native/blacklist/unblock	listed	rt-02 G13
POST	/api/native/blacklist/settle	listed	rt-02 G13
POST	/api/native/channels/read-through	listed	rt-02 G13
GET	/api/channels/{id}	listed	rt-02 G14
PATCH	/api/channels/{id}	listed	rt-02 G14
DELETE	/api/channels/{id}	listed	rt-02 G14
POST	/api/channels/{id}/archive	listed	rt-02 G14
POST	/api/channels/{id}/restore	listed	rt-02 G14
GET	/api/channels/{id}/permissions	listed	rt-02 G14
PUT	/api/channels/{id}/permissions/{type}/{target}	listed	rt-02 G14
DELETE	/api/channels/{id}/permissions/{type}/{target}	listed	rt-02 G14
GET	/api/channels/{id}/effective/{memberId}	listed	rt-02 G14
GET	/api/channels/{id}/members	listed	rt-02 G14
GET	/api/channels/{id}/op-log	listed	rt-02 G14
POST	/api/channels/{id}/member-state	listed	rt-02 G14
GET	/api/channels/member-state-requests/{requestId}	listed	rt-02 G14
POST	/api/im/message/edit	listed	rt-02 G15
POST	/api/im/message/recall	listed	rt-02 G15
GET	/api/im/message/request	listed	rt-02 G15
GET	/api/im/message/mutations	listed	rt-02 G15
GET	/api/im/message/context	listed	rt-02 G15
GET	/api/im/message/{messageId}/revisions	listed	rt-02 G15
GET	/api/im/message/{messageId}/attachment	listed	rt-02 G15
POST	/api/rewards/noncash/claims	listed	rt-02 G16
POST	/api/rewards/noncash/claims/recover	listed	rt-02 G16
GET	/api/rewards/noncash	listed	rt-02 G16
GET	/api/rewards/noncash/subjects/{subjectId}	listed	rt-02 G16
GET	/api/rewards/noncash/versions/{versionId}	listed	rt-02 G16
POST	/api/rewards/noncash/cases	listed	rt-02 G16
GET	/api/rewards/noncash/cases/{caseId}	listed	rt-02 G16
GET	/api/rewards/noncash/{awardId}	listed	rt-02 G16
POST	/api/approved-topic-release/v1/prepare	listed	rt-02 G17
POST	/api/approved-topic-release/v1/publish	listed	rt-02 G17
POST	/api/approved-topic-release/v1/status	listed	rt-02 G17
POST	/api/approved-topic-release/v1/review/sources	listed	rt-02 G17
POST	/api/approved-topic-release/v1/review/prepare	listed	rt-02 G17
POST	/api/approved-topic-release/v1/review/submit	listed	rt-02 G17
POST	/api/approved-topic-release/v1/review/status	listed	rt-02 G17
POST	/api/approved-topic-release/v1/review/current	listed	rt-02 G17
POST	/api/activity/create-requests/submit	listed	rt-02 G18
POST	/api/activity/create-requests/read	listed	rt-02 G18
POST	/api/activity/create-requests/resume-post-processing	listed	rt-02 G18
POST	/api/club/update	listed	rt-02 G18
GET	/api/club/workbench	listed	rt-02 G18
POST	/api/club/workbench	listed	rt-02 G18
GET	/api/club/settlements	listed	rt-02 G18
POST	/api/club/settlements	listed	rt-02 G18
GET	/api/club/settlements/export	listed	rt-02 G18
POST	/api/club/settlements/export	listed	rt-02 G18
GET	/api/club/settings/notify-level	listed	rt-02 G18
POST	/api/club/settings/notify-level	listed	rt-02 G18
GET	/api/city/walking/target	listed	rt-02 G19
GET	/api/im/roles	listed	rt-02 G20
POST	/api/im/roles	listed	rt-02 G20
PATCH	/api/im/roles/{id}	listed	rt-02 G20
DELETE	/api/im/roles/{id}	listed	rt-02 G20
PUT	/api/im/roles/{id}/members	listed	rt-02 G20
POST	/api/im/moderation/timeout	listed	rt-02 G21
POST	/api/im/moderation/kick	listed	rt-02 G21
POST	/api/im/moderation/ban	listed	rt-02 G21
POST	/api/im/moderation/{actionId}/revoke	listed	rt-02 G21
GET	/api/im/moderation/actions	listed	rt-02 G21
GET	/api/im/moderation/me	listed	rt-02 G21
GET	/api/im/webhook/context	listed	rt-02 G21
GET	/api/im/webhook/subscriptions	listed	rt-02 G21
POST	/api/im/webhook/subscriptions	listed	rt-02 G21
GET	/api/im/webhook/subscriptions/{id}	listed	rt-02 G21
PUT	/api/im/webhook/subscriptions/{id}	listed	rt-02 G21
DELETE	/api/im/webhook/subscriptions/{id}	listed	rt-02 G21
POST	/api/im/webhook/subscriptions/{id}/rotate-secret	listed	rt-02 G21
GET	/api/im/webhook/subscriptions/{id}/deliveries	listed	rt-02 G21
POST	/api/im/webhook/subscriptions/{id}/test	listed	rt-02 G21
POST	/api/im/webhook/subscriptions/{id}/deliveries/{deliveryId}/retry	listed	rt-02 G21
GET	/api/im/webhook/endpoints	listed	rt-02 G21
POST	/api/im/webhook/endpoints	listed	rt-02 G21
GET	/api/im/webhook/endpoints/{id}	listed	rt-02 G21
PUT	/api/im/webhook/endpoints/{id}	listed	rt-02 G21
DELETE	/api/im/webhook/endpoints/{id}	listed	rt-02 G21
POST	/api/im/webhook/endpoints/{id}/rotate-token	listed	rt-02 G21
GET	/api/im/webhook/endpoints/{id}/logs	listed	rt-02 G21
POST	/api/friend/request	listed	rt-02 G22
POST	/api/friend/remove	listed	rt-02 G22
GET	/api/friend/requests	listed	rt-02 G22
GET	/api/friend/team-invite/picker	listed	rt-02 G22
GET	/api/friend/team-invite/landing	listed	rt-02 G22
GET	/api/friend/team-invite/mine	listed	rt-02 G22
POST	/api/im/chain/create	listed	rt-02 G23
POST	/api/im/chain/join	listed	rt-02 G23
POST	/api/im/chain/withdraw	listed	rt-02 G23
POST	/api/im/chain/close	listed	rt-02 G23
GET	/api/im/chain/info	listed	rt-02 G23
POST	/api/im/appeals	listed	rt-02 G24
GET	/api/im/appeals/{appealId}	listed	rt-02 G24
POST	/api/im/appeals/{appealId}/evidence	listed	rt-02 G24
POST	/api/im/appeals/{appealId}/withdraw	listed	rt-02 G24
POST	/api/im/file/upload	listed	rt-02 G24
GET	/api/im/file/receipt	listed	rt-02 G24
POST	/api/im/file/scan	listed	rt-02 G24
GET	/api/im/file/message/{messageId}/authorization	listed	rt-02 G24
GET	/api/im/file/message/{messageId}/preview	listed	rt-02 G24
GET	/api/im/video/policy	listed	rt-02 G25
POST	/api/im/video/upload	listed	rt-02 G25
GET	/api/im/video/receipt	listed	rt-02 G25
GET	/api/im/video/message/{id}/authorization	listed	rt-02 G25
GET	/api/im/video/message/{id}/preview	listed	rt-02 G25
POST	/api/join-request/submit	listed	rt-02 G25
POST	/api/join-request/cancel	listed	rt-02 G25
POST	/api/join-request/approve	listed	rt-02 G25
POST	/api/join-request/reject	listed	rt-02 G25
GET	/api/play/advanced/time-window	listed	rt-03
GET	/api/play/route-action	listed	rt-03
POST	/api/play/city-orientation/answer	listed	rt-03
GET	/api/play/city-orientation/receipt	listed	rt-03
GET	/api/progress/meter	listed	rt-03
GET	/api/progress/requests/{requestId}	listed	rt-03
POST	/api/merchant/poi/detail	listed	rt-03
POST	/api/merchant/shop/apply	listed	rt-03
POST	/api/topic/detail	listed	rt-03
GET	/api/merchant/offer-withdrawal/request/current	listed	rt-03
GET	/api/merchant/offer-withdrawal/request/result	listed	rt-03
POST	/api/merchant/offer-withdrawal/request/withdraw	listed	rt-03
POST	/api/topic/edit-requests/submit	listed	rt-03
POST	/api/topic/edit-requests/read	listed	rt-03
POST	/api/topic/edit-requests/resume-post-processing	listed	rt-03
GET	/api/topic/module-preflight	listed	rt-03
GET	/api/channel/{channelId}/board	listed	rt-03
GET	/api/channel/{channelId}/board/{key}/top	listed	rt-03
GET	/api/channel/{channelId}/board/{key}/detail	listed	rt-03
GET	/api/channel/{channelId}/board/{key}/version	listed	rt-03
GET	/api/channel/{channelId}/board/{key}/me/best	listed	rt-03
GET	/api/channel/{channelId}/board/{key}/me/recent	listed	rt-03
GET	/api/channel/{channelId}/progress/overview	listed	rt-03
GET	/api/channel/{channelId}/progress/privacy	listed	rt-03
POST	/api/channel/{channelId}/progress/privacy	listed	rt-03
GET	/api/channel-platform/{family}/requests/{requestId}	listed	rt-03
GET	/api/im/channel/checkin-status	listed	rt-03
GET	/api/im/channel/checkin-rank	listed	rt-03
GET	/api/im/channel/checkin-request	listed	rt-03
POST	/api/im/channel/checkin	listed	rt-03
POST	/api/im/voice/upload	listed	rt-03
GET	/api/im/voice/receipt	listed	rt-03
GET	/api/im/voice/message/{messageId}	listed	rt-03
GET	/api/im/voice/message/{messageId}/authorization	listed	rt-03
POST	/api/project/state-requests/context	listed	rt-03
POST	/api/project/state-requests/submit	listed	rt-03
POST	/api/project/state-requests/read	listed	rt-03
POST	/api/template/author-requests/submit	listed	rt-03
POST	/api/template/author-requests/read	listed	rt-03
GET	/api/template/report-receipt	listed	rt-03
POST	/api/template/report-receipt	listed	rt-03
POST	/api/us/auth/apple/challenges	listed	rt-03
POST	/api/us/auth/apple/exchange	listed	rt-03
GET	/api/us/auth/session	listed	rt-03
GET	/api/common/uploadOSS/receipt	listed	rt-03
GET	/api/free-explore/bundle/transfer/preview	listed	rt-03
POST	/api/free-explore/bundle/transfer	listed	rt-03
GET	/api/free-explore/bundle/transfer	listed	rt-03
GET	/api/free-explore/bundle/transfer/receipt	listed	rt-03
POST	/api/free-explore/bundle/transfer/{id}/revoke	listed	rt-03
POST	/api/free-explore/bundle/voucher/appeal	listed	rt-03
GET	/api/free-explore/bundle/voucher/appeal/receipt	listed	rt-03
GET	/api/free-explore/bundle/voucher/appeal	listed	rt-03
GET	/api/guilds/{kind}/{guildId}/channels	listed	rt-03
GET	/api/guilds/{kind}/{guildId}/channels/manage	listed	rt-03
GET	/api/im/pins	listed	rt-03
POST	/api/im/pins/sort	listed	rt-03
GET	/api/mod-settlement/mine	listed	rt-03
GET	/api/mod-settlement/mine/income	listed	rt-03
POST	/api/onboarding/get	listed	rt-03
POST	/api/onboarding/submit	listed	rt-03
GET	/api/compliance/usage-records	listed	rt-03
GET	/api/compliance/usage-records/request	listed	rt-03
POST	/api/growth/leaderboard/anonymous	listed	rt-03
POST	/api/space/leave	listed	rt-03
POST	/api/space/join-pause	listed	rt-03
POST	/api/ugc/block	listed	rt-03
POST	/api/ugc/report	listed	rt-03
GET	/api/user/follow-list	listed	rt-03
POST	/api/user/sms/send	listed	rt-03
GET	/api/im/device/attempts	listed	rt-03
GET	/api/im/notify-log	listed	rt-03
GET	/api/im/notify-pref	listed	rt-03
POST	/api/im/notify-pref	listed	rt-03
GET	/api/im/notification-requests/{requestId}	listed	rt-03
GET	/api/im/mute-state	listed	rt-03
GET	/api/im/mute-receipt	listed	rt-03
GET	/api/im/interaction/request	listed	rt-03
POST	/api/im/pin	listed	rt-03
GET	/api/im/poll/create-receipt	listed	rt-03
GET	/api/im/read-state	listed	rt-03
GET	/api/im/read-receipt	listed	rt-03
POST	/api/im/route-share-source	listed	rt-03
GET	/api/im/unread-summary	listed	rt-03
GET	/api/im/search	listed	rt-03
POST	/api/map/public-layers	listed	rt-03
GET	/api/privacy/progress	listed	rt-03
POST	/api/privacy/progress	listed	rt-03
POST	/api/support/tickets/list	listed	rt-03
POST	/api/support/tickets/detail	listed	rt-03
POST	/api/registration/original-event	listed	rt-03
GET	/api/official/v2/events/{id}/publish-check	listed	rt-03
POST	/api/welcome-screen/get	listed	rt-03
GET	/api/play/compatibility	listed	rt-04 G37-1
POST	/api/play/compatibility	listed	rt-04 G37-2
GET	/api/play/help	listed	rt-04 G38-1
GET	/api/play/help/quota	listed	rt-04 G39-1
POST	/api/play/help/use	listed	rt-04 G39-2
GET	/api/play/run-score-detail	listed	rt-04 G40-1
POST	/api/play/help/skip	listed	rt-04 G41-1
GET	/api/play/help/skip/receipt	listed	rt-04 G41-2
POST	/api/play/hangman/state	listed	rt-04 G42-1
POST	/api/play/hangman/submit	listed	rt-04 G42-2
GET	/api/play/accusation	listed	rt-04 G44-1
POST	/api/play/accusation/confirm	listed	rt-04 G44-2
GET	/api/play/accusation/receipt	listed	rt-04 G44-3
GET	/api/play/action-receipt/state	listed	rt-04 G45-1
GET	/api/topic/publish-check/fields-g47	listed	rt-04 G47-1
GET	/api/topic/author-config/hints-g47	listed	rt-04 G47-2
POST	/api/topic/author-config/hints/validate-g47	listed	rt-04 G47-3
GET	/api/topic/publish-status-g47	listed	rt-04 G47-4
GET	/api/topic/publish-result-g52	listed	rt-04 G52-1 ; rt-05 9 G52
GET	/api/topic/my-projects-status-g52	listed	rt-04 G52-2 ; rt-05 10 G52
GET	/business/ug-audit/topic/{topicId}/config	listed	rt-04 G48-1
GET	/business/ug-audit/run/{runId}/quota	listed	rt-04 G48-2
GET	/business/ug-audit/run/{runId}/detail	listed	rt-04 G48-3
POST	/api/template/topic-template/adoption-info	listed	rt-05 1 G49
GET	/api/template/topic-template/location-todos-g50	listed	rt-05 2 G50
POST	/api/template/topic-template/location-reconfirm-g50	listed	rt-05 3 G50
POST	/api/template/topic-template/source-g51/adoption/record	listed	rt-05 4 G51
GET	/api/template/topic-template/source-g51/adoption	listed	rt-05 5 G51
POST	/api/template/topic-template/source-g51/credits/save	listed	rt-05 6 G51
GET	/api/template/topic-template/source-g51/credits	listed	rt-05 7 G51
GET	/api/template/topic-template/source-g51/preview	listed	rt-05 8 G51
GET	/api/play/node-closure	listed	rt-05 11 G53
GET	/api/play/reading-g54/manifest	listed	rt-05 12 G54
GET	/api/play/reading-g54/position	listed	rt-05 13 G54
POST	/api/play/reading-g54/position	listed	rt-05 14 G54
POST	/api/team/seats	listed	rt-05 15 G55
GET	/api/team/state-g56	listed	rt-05 16 G56
GET	/api/team/leave-impact-g56	listed	rt-05 17 G56
POST	/api/team/quit-g56	listed	rt-05 18 G56
GET	/api/team/shared-outcome-g56	listed	rt-05 19 G56
POST	/api/team/handle-g56	listed	rt-05 20 G56
POST	/api/registration/delivery-g57	listed	rt-05 21 G57
POST	/api/registration/order-check-g57	listed	rt-05 22 G57
GET	/api/refund/impact-g58	listed	rt-05 23 G58
GET	/api/creator/revenue-g58	listed	rt-05 24 G58
GET	/api/topic/post-game-outcome-g58	listed	rt-05 25 G58
GET	/api/leaderboard/rank-basis-g58	listed	rt-05 26 G58
ROUTES
```

Each line of that heredoc is one route. The loop was not run, so each line stays **UNVERIFIED**. A printed HTTP code from a future run is still UNVERIFIED until the body is read against the static contract. This file does not record any HTTP code.

## Route ledger

370 routes. Runtime is UNVERIFIED on every row. The Static column is the word copied from the public table when that table had a status cell. `listed` means the table names the route and the copied cell was not a registered/UNREGISTERED word. Those static words were not re-checked against a running server.

| # | Method | Path | Static | Runtime |
|---|---|---|---|---|
| 1 | GET | `/api/merchant/authoring/drafts` | registered | UNVERIFIED |
| 2 | POST | `/api/merchant/authoring/drafts` | registered | UNVERIFIED |
| 3 | GET | `/api/merchant/authoring/drafts/{draftId}` | registered | UNVERIFIED |
| 4 | POST | `/api/merchant/authoring/drafts/{draftId}` | registered | UNVERIFIED |
| 5 | POST | `/api/merchant/authoring/jobs` | registered | UNVERIFIED |
| 6 | GET | `/api/merchant/authoring/jobs` | registered | UNVERIFIED |
| 7 | POST | `/api/merchant/authoring/jobs/cancel` | registered | UNVERIFIED |
| 8 | GET | `/api/merchant/authoring/main-line` | registered | UNVERIFIED |
| 9 | GET | `/api/merchant/authoring/environment` | registered | UNVERIFIED |
| 10 | POST | `/api/merchant/authoring/draft-selection/list` | registered | UNVERIFIED |
| 11 | POST | `/api/merchant/authoring/draft-selection/resolve` | registered | UNVERIFIED |
| 12 | POST | `/api/merchant/authoring/releases` | registered, functionally dead | UNVERIFIED |
| 13 | GET | `/api/merchant/authoring/releases` | registered | UNVERIFIED |
| 14 | POST | `/api/merchant/authoring/releases/{id}/withdraw` | registered | UNVERIFIED |
| 15 | GET | `/api/merchant/authoring/public` | registered | UNVERIFIED |
| 16 | GET | `/api/merchant/authoring/player/{merchantId}/game` | registered | UNVERIFIED |
| 17 | GET | `/api/merchant/authoring/player/{merchantId}/requests/{requestId}` | registered | UNVERIFIED |
| 18 | GET | `/api/merchant/city-value/report` | UNREGISTERED | UNVERIFIED |
| 19 | GET | `/api/merchant/city-value/events` | UNREGISTERED | UNVERIFIED |
| 20 | GET | `/api/merchant/city-value/event/{id}/benefit` | UNREGISTERED | UNVERIFIED |
| 21 | GET | `/api/merchant/city-value/result/{id}` | registered, functionally 503 | UNVERIFIED |
| 22 | POST | `/api/merchant/crm/customers/{customerMemberId}/detail` | registered | UNVERIFIED |
| 23 | POST | `/api/merchant/crm/customers/{customerMemberId}/contact` | registered | UNVERIFIED |
| 24 | POST | `/api/merchant/crm/exports/{taskId}/status` | registered | UNVERIFIED |
| 25 | GET | `/api/merchant/crm/exports/{taskId}/download` | registered | UNVERIFIED |
| 26 | POST | `/api/ai/merchant/insight` | registered | UNVERIFIED |
| 27 | POST | `/api/merchant/npc/avatar/generate` | registered | UNVERIFIED |
| 28 | POST | `/api/merchant/npc/avatar/status` | registered | UNVERIFIED |
| 29 | POST | `/api/merchant/npc/knowledge-review` | registered | UNVERIFIED |
| 30 | GET | `/api/merchant/npc/knowledge-review/request` | registered | UNVERIFIED |
| 31 | POST | `/api/club/channels` | registered | UNVERIFIED |
| 32 | POST | `/api/club/admission/receipt` | registered | UNVERIFIED |
| 33 | POST | `/api/club/badge/original-receipt` | registered | UNVERIFIED |
| 34 | POST | `/api/club/event-ops/series/original-result` | registered | UNVERIFIED |
| 35 | POST | `/api/club/post/operation/create` | registered | UNVERIFIED |
| 36 | POST | `/api/club/post/operation/update` | registered | UNVERIFIED |
| 37 | POST | `/api/club/post/operation/receipt` | registered | UNVERIFIED |
| 38 | POST | `/api/club/post/operation/comment/create` | registered | UNVERIFIED |
| 39 | POST | `/api/club/post/operation/comment/receipt` | registered | UNVERIFIED |
| 40 | POST | `/api/club/open-settings/welcome-note-receipt` | registered only if flag true | UNVERIFIED |
| 41 | GET | `/api/city-game/acquisition/state` | UNREGISTERED | UNVERIFIED |
| 42 | GET | `/api/city-game/acquisition/titles` | UNREGISTERED | UNVERIFIED |
| 43 | GET | `/api/city-game/acquisition/quote/{id}` | UNREGISTERED | UNVERIFIED |
| 44 | POST | `/api/city-game/acquisition/command` | UNREGISTERED | UNVERIFIED |
| 45 | GET | `/api/city-game/acquisition/request/{requestId}` | UNREGISTERED | UNVERIFIED |
| 46 | GET | `/api/city-game/action-budget/state` | UNREGISTERED | UNVERIFIED |
| 47 | POST | `/api/city-game/action-budget/command` | UNREGISTERED | UNVERIFIED |
| 48 | GET | `/api/city-game/action-budget/result/{resultId}` | UNREGISTERED | UNVERIFIED |
| 49 | GET | `/api/city-game/action-budget/request/{requestId}` | UNREGISTERED | UNVERIFIED |
| 50 | GET | `/api/city-game/arrival-evidence/state` | UNREGISTERED | UNVERIFIED |
| 51 | GET | `/api/city-game/arrival-evidence/merchant` | UNREGISTERED | UNVERIFIED |
| 52 | GET | `/api/city-game/arrival-evidence/evidence/{id}` | UNREGISTERED | UNVERIFIED |
| 53 | POST | `/api/city-game/arrival-evidence/command` | UNREGISTERED | UNVERIFIED |
| 54 | GET | `/api/city-game/arrival-evidence/request/{id}` | UNREGISTERED | UNVERIFIED |
| 55 | GET | `/api/city-game/neutral-tasks/state` | UNREGISTERED | UNVERIFIED |
| 56 | POST | `/api/city-game/neutral-tasks/command` | UNREGISTERED | UNVERIFIED |
| 57 | GET | `/api/city-game/neutral-tasks/request/{requestId}` | UNREGISTERED | UNVERIFIED |
| 58 | GET | `/api/city-game/onsite-tasks/state` | UNREGISTERED | UNVERIFIED |
| 59 | GET | `/api/city-game/onsite-tasks/result/{id}` | UNREGISTERED | UNVERIFIED |
| 60 | POST | `/api/city-game/onsite-tasks/command` | UNREGISTERED | UNVERIFIED |
| 61 | GET | `/api/city-game/onsite-tasks/request/{requestId}` | UNREGISTERED | UNVERIFIED |
| 62 | GET | `/api/city-game/merchant/operations/availability` | UNREGISTERED, no registration helper | UNVERIFIED |
| 63 | POST | `/api/city-game/merchant/operations/intent` | UNREGISTERED, no registration helper | UNVERIFIED |
| 64 | GET | `/api/city-game/merchant/operations/request/{requestId}` | UNREGISTERED, no registration helper | UNVERIFIED |
| 65 | GET | `/api/city-game/player-rules` | UNREGISTERED, no registration helper | UNVERIFIED |
| 66 | GET | `/api/city-game/state/deltas` | UNREGISTERED, no registration helper | UNVERIFIED |
| 67 | GET | `/api/friend/list` | listed | UNVERIFIED |
| 68 | POST | `/api/friend/accept` | listed | UNVERIFIED |
| 69 | POST | `/api/friend/cancel` | listed | UNVERIFIED |
| 70 | GET | `/api/friend/directory` | listed | UNVERIFIED |
| 71 | GET | `/api/friend/directory/detail` | listed | UNVERIFIED |
| 72 | GET | `/api/friend/group/list` | listed | UNVERIFIED |
| 73 | POST | `/api/friend/group/save` | listed | UNVERIFIED |
| 74 | POST | `/api/friend/group/delete` | listed | UNVERIFIED |
| 75 | GET | `/api/friend/relationship` | listed | UNVERIFIED |
| 76 | GET | `/api/friend/receipt` | listed | UNVERIFIED |
| 77 | POST | `/api/friend/reject` | listed | UNVERIFIED |
| 78 | GET | `/api/friend/metadata` | listed | UNVERIFIED |
| 79 | POST | `/api/friend/remark` | listed | UNVERIFIED |
| 80 | GET | `/api/friend/metadata/receipt` | listed | UNVERIFIED |
| 81 | POST | `/api/friend/metadata/settle` | listed | UNVERIFIED |
| 82 | GET | `/api/friend/removal/receipt` | listed | UNVERIFIED |
| 83 | POST | `/api/friend/removal/settle` | listed | UNVERIFIED |
| 84 | GET | `/api/friend/progress` | listed | UNVERIFIED |
| 85 | POST | `/api/reward-pledge/drafts` | listed | UNVERIFIED |
| 86 | POST | `/api/reward-pledge/{pledgeId}/submit` | listed | UNVERIFIED |
| 87 | POST | `/api/reward-pledge/{pledgeId}/confirm` | listed | UNVERIFIED |
| 88 | POST | `/api/reward-pledge/{pledgeId}/freeze` | listed | UNVERIFIED |
| 89 | GET | `/api/reward-pledge/{pledgeId}` | listed | UNVERIFIED |
| 90 | GET | `/api/reward-pledge/{pledgeId}/stats` | listed | UNVERIFIED |
| 91 | POST | `/api/reward-pledge/awards/{awardId}/return-to-pool` | listed | UNVERIFIED |
| 92 | GET | `/api/reward-pledge/fulfilment/awards` | listed | UNVERIFIED |
| 93 | POST | `/api/reward-pledge/fulfilment/resolve` | listed | UNVERIFIED |
| 94 | POST | `/api/reward-pledge/fulfilment/preview` | listed | UNVERIFIED |
| 95 | POST | `/api/reward-pledge/fulfilment/redeem` | listed | UNVERIFIED |
| 96 | POST | `/api/reward-pledge/fulfilment/expire` | listed | UNVERIFIED |
| 97 | GET | `/api/reward-pledge/pledges` | listed | UNVERIFIED |
| 98 | GET | `/api/reward-pledge/review` | listed | UNVERIFIED |
| 99 | GET | `/api/reward-pledge/review/{versionId}` | listed | UNVERIFIED |
| 100 | GET | `/api/reward-pledge/ops/{op}/{key}` | listed | UNVERIFIED |
| 101 | POST | `/api/reward-pledge/versions/{versionId}/hold` | listed | UNVERIFIED |
| 102 | POST | `/api/reward-pledge/versions/{versionId}/withdraw` | listed | UNVERIFIED |
| 103 | POST | `/api/workshop/owned/list` | listed | UNVERIFIED |
| 104 | POST | `/api/workshop/owned/detail` | listed | UNVERIFIED |
| 105 | POST | `/api/workshop/owned/package` | listed | UNVERIFIED |
| 106 | POST | `/api/workshop/creator/pending-packages/author` | listed | UNVERIFIED |
| 107 | POST | `/api/workshop/creator/pending-packages/list` | listed | UNVERIFIED |
| 108 | POST | `/api/workshop/creator/pending-packages/detail` | listed | UNVERIFIED |
| 109 | POST | `/api/workshop/creator/public-theme-use/preview` | listed | UNVERIFIED |
| 110 | POST | `/api/workshop/creator/public-theme-use/status` | listed | UNVERIFIED |
| 111 | POST | `/api/workshop/creator/public-theme-use/declare` | listed | UNVERIFIED |
| 112 | GET | `/api/topic/cover/selection/current` | listed | UNVERIFIED |
| 113 | POST | `/api/topic/cover/upload` | listed | UNVERIFIED |
| 114 | POST | `/api/topic/cover/selection` | listed | UNVERIFIED |
| 115 | POST | `/api/topic/cover/selection/status` | listed | UNVERIFIED |
| 116 | GET | `/api/topic/cover/{assetId}/content` | listed | UNVERIFIED |
| 117 | POST | `/api/topic/attribute-author` | listed | UNVERIFIED |
| 118 | GET | `/api/topic/attribute-author/request` | listed | UNVERIFIED |
| 119 | GET | `/api/native/blacklist/list` | listed | UNVERIFIED |
| 120 | GET | `/api/native/blacklist/current` | listed | UNVERIFIED |
| 121 | GET | `/api/native/blacklist/receipt` | listed | UNVERIFIED |
| 122 | POST | `/api/native/blacklist/unblock` | listed | UNVERIFIED |
| 123 | POST | `/api/native/blacklist/settle` | listed | UNVERIFIED |
| 124 | POST | `/api/native/channels/read-through` | listed | UNVERIFIED |
| 125 | GET | `/api/channels/{id}` | listed | UNVERIFIED |
| 126 | PATCH | `/api/channels/{id}` | listed | UNVERIFIED |
| 127 | DELETE | `/api/channels/{id}` | listed | UNVERIFIED |
| 128 | POST | `/api/channels/{id}/archive` | listed | UNVERIFIED |
| 129 | POST | `/api/channels/{id}/restore` | listed | UNVERIFIED |
| 130 | GET | `/api/channels/{id}/permissions` | listed | UNVERIFIED |
| 131 | PUT | `/api/channels/{id}/permissions/{type}/{target}` | listed | UNVERIFIED |
| 132 | DELETE | `/api/channels/{id}/permissions/{type}/{target}` | listed | UNVERIFIED |
| 133 | GET | `/api/channels/{id}/effective/{memberId}` | listed | UNVERIFIED |
| 134 | GET | `/api/channels/{id}/members` | listed | UNVERIFIED |
| 135 | GET | `/api/channels/{id}/op-log` | listed | UNVERIFIED |
| 136 | POST | `/api/channels/{id}/member-state` | listed | UNVERIFIED |
| 137 | GET | `/api/channels/member-state-requests/{requestId}` | listed | UNVERIFIED |
| 138 | POST | `/api/im/message/edit` | listed | UNVERIFIED |
| 139 | POST | `/api/im/message/recall` | listed | UNVERIFIED |
| 140 | GET | `/api/im/message/request` | listed | UNVERIFIED |
| 141 | GET | `/api/im/message/mutations` | listed | UNVERIFIED |
| 142 | GET | `/api/im/message/context` | listed | UNVERIFIED |
| 143 | GET | `/api/im/message/{messageId}/revisions` | listed | UNVERIFIED |
| 144 | GET | `/api/im/message/{messageId}/attachment` | listed | UNVERIFIED |
| 145 | POST | `/api/rewards/noncash/claims` | listed | UNVERIFIED |
| 146 | POST | `/api/rewards/noncash/claims/recover` | listed | UNVERIFIED |
| 147 | GET | `/api/rewards/noncash` | listed | UNVERIFIED |
| 148 | GET | `/api/rewards/noncash/subjects/{subjectId}` | listed | UNVERIFIED |
| 149 | GET | `/api/rewards/noncash/versions/{versionId}` | listed | UNVERIFIED |
| 150 | POST | `/api/rewards/noncash/cases` | listed | UNVERIFIED |
| 151 | GET | `/api/rewards/noncash/cases/{caseId}` | listed | UNVERIFIED |
| 152 | GET | `/api/rewards/noncash/{awardId}` | listed | UNVERIFIED |
| 153 | POST | `/api/approved-topic-release/v1/prepare` | listed | UNVERIFIED |
| 154 | POST | `/api/approved-topic-release/v1/publish` | listed | UNVERIFIED |
| 155 | POST | `/api/approved-topic-release/v1/status` | listed | UNVERIFIED |
| 156 | POST | `/api/approved-topic-release/v1/review/sources` | listed | UNVERIFIED |
| 157 | POST | `/api/approved-topic-release/v1/review/prepare` | listed | UNVERIFIED |
| 158 | POST | `/api/approved-topic-release/v1/review/submit` | listed | UNVERIFIED |
| 159 | POST | `/api/approved-topic-release/v1/review/status` | listed | UNVERIFIED |
| 160 | POST | `/api/approved-topic-release/v1/review/current` | listed | UNVERIFIED |
| 161 | POST | `/api/activity/create-requests/submit` | listed | UNVERIFIED |
| 162 | POST | `/api/activity/create-requests/read` | listed | UNVERIFIED |
| 163 | POST | `/api/activity/create-requests/resume-post-processing` | listed | UNVERIFIED |
| 164 | POST | `/api/club/update` | listed | UNVERIFIED |
| 165 | GET | `/api/club/workbench` | listed | UNVERIFIED |
| 166 | POST | `/api/club/workbench` | listed | UNVERIFIED |
| 167 | GET | `/api/club/settlements` | listed | UNVERIFIED |
| 168 | POST | `/api/club/settlements` | listed | UNVERIFIED |
| 169 | GET | `/api/club/settlements/export` | listed | UNVERIFIED |
| 170 | POST | `/api/club/settlements/export` | listed | UNVERIFIED |
| 171 | GET | `/api/club/settings/notify-level` | listed | UNVERIFIED |
| 172 | POST | `/api/club/settings/notify-level` | listed | UNVERIFIED |
| 173 | GET | `/api/city/walking/target` | listed | UNVERIFIED |
| 174 | GET | `/api/im/roles` | listed | UNVERIFIED |
| 175 | POST | `/api/im/roles` | listed | UNVERIFIED |
| 176 | PATCH | `/api/im/roles/{id}` | listed | UNVERIFIED |
| 177 | DELETE | `/api/im/roles/{id}` | listed | UNVERIFIED |
| 178 | PUT | `/api/im/roles/{id}/members` | listed | UNVERIFIED |
| 179 | POST | `/api/im/moderation/timeout` | listed | UNVERIFIED |
| 180 | POST | `/api/im/moderation/kick` | listed | UNVERIFIED |
| 181 | POST | `/api/im/moderation/ban` | listed | UNVERIFIED |
| 182 | POST | `/api/im/moderation/{actionId}/revoke` | listed | UNVERIFIED |
| 183 | GET | `/api/im/moderation/actions` | listed | UNVERIFIED |
| 184 | GET | `/api/im/moderation/me` | listed | UNVERIFIED |
| 185 | GET | `/api/im/webhook/context` | listed | UNVERIFIED |
| 186 | GET | `/api/im/webhook/subscriptions` | listed | UNVERIFIED |
| 187 | POST | `/api/im/webhook/subscriptions` | listed | UNVERIFIED |
| 188 | GET | `/api/im/webhook/subscriptions/{id}` | listed | UNVERIFIED |
| 189 | PUT | `/api/im/webhook/subscriptions/{id}` | listed | UNVERIFIED |
| 190 | DELETE | `/api/im/webhook/subscriptions/{id}` | listed | UNVERIFIED |
| 191 | POST | `/api/im/webhook/subscriptions/{id}/rotate-secret` | listed | UNVERIFIED |
| 192 | GET | `/api/im/webhook/subscriptions/{id}/deliveries` | listed | UNVERIFIED |
| 193 | POST | `/api/im/webhook/subscriptions/{id}/test` | listed | UNVERIFIED |
| 194 | POST | `/api/im/webhook/subscriptions/{id}/deliveries/{deliveryId}/retry` | listed | UNVERIFIED |
| 195 | GET | `/api/im/webhook/endpoints` | listed | UNVERIFIED |
| 196 | POST | `/api/im/webhook/endpoints` | listed | UNVERIFIED |
| 197 | GET | `/api/im/webhook/endpoints/{id}` | listed | UNVERIFIED |
| 198 | PUT | `/api/im/webhook/endpoints/{id}` | listed | UNVERIFIED |
| 199 | DELETE | `/api/im/webhook/endpoints/{id}` | listed | UNVERIFIED |
| 200 | POST | `/api/im/webhook/endpoints/{id}/rotate-token` | listed | UNVERIFIED |
| 201 | GET | `/api/im/webhook/endpoints/{id}/logs` | listed | UNVERIFIED |
| 202 | POST | `/api/friend/request` | listed | UNVERIFIED |
| 203 | POST | `/api/friend/remove` | listed | UNVERIFIED |
| 204 | GET | `/api/friend/requests` | listed | UNVERIFIED |
| 205 | GET | `/api/friend/team-invite/picker` | listed | UNVERIFIED |
| 206 | GET | `/api/friend/team-invite/landing` | listed | UNVERIFIED |
| 207 | GET | `/api/friend/team-invite/mine` | listed | UNVERIFIED |
| 208 | POST | `/api/im/chain/create` | listed | UNVERIFIED |
| 209 | POST | `/api/im/chain/join` | listed | UNVERIFIED |
| 210 | POST | `/api/im/chain/withdraw` | listed | UNVERIFIED |
| 211 | POST | `/api/im/chain/close` | listed | UNVERIFIED |
| 212 | GET | `/api/im/chain/info` | listed | UNVERIFIED |
| 213 | POST | `/api/im/appeals` | listed | UNVERIFIED |
| 214 | GET | `/api/im/appeals/{appealId}` | listed | UNVERIFIED |
| 215 | POST | `/api/im/appeals/{appealId}/evidence` | listed | UNVERIFIED |
| 216 | POST | `/api/im/appeals/{appealId}/withdraw` | listed | UNVERIFIED |
| 217 | POST | `/api/im/file/upload` | listed | UNVERIFIED |
| 218 | GET | `/api/im/file/receipt` | listed | UNVERIFIED |
| 219 | POST | `/api/im/file/scan` | listed | UNVERIFIED |
| 220 | GET | `/api/im/file/message/{messageId}/authorization` | listed | UNVERIFIED |
| 221 | GET | `/api/im/file/message/{messageId}/preview` | listed | UNVERIFIED |
| 222 | GET | `/api/im/video/policy` | listed | UNVERIFIED |
| 223 | POST | `/api/im/video/upload` | listed | UNVERIFIED |
| 224 | GET | `/api/im/video/receipt` | listed | UNVERIFIED |
| 225 | GET | `/api/im/video/message/{id}/authorization` | listed | UNVERIFIED |
| 226 | GET | `/api/im/video/message/{id}/preview` | listed | UNVERIFIED |
| 227 | POST | `/api/join-request/submit` | listed | UNVERIFIED |
| 228 | POST | `/api/join-request/cancel` | listed | UNVERIFIED |
| 229 | POST | `/api/join-request/approve` | listed | UNVERIFIED |
| 230 | POST | `/api/join-request/reject` | listed | UNVERIFIED |
| 231 | GET | `/api/play/advanced/time-window` | listed | UNVERIFIED |
| 232 | GET | `/api/play/route-action` | listed | UNVERIFIED |
| 233 | POST | `/api/play/city-orientation/answer` | listed | UNVERIFIED |
| 234 | GET | `/api/play/city-orientation/receipt` | listed | UNVERIFIED |
| 235 | GET | `/api/progress/meter` | listed | UNVERIFIED |
| 236 | GET | `/api/progress/requests/{requestId}` | listed | UNVERIFIED |
| 237 | POST | `/api/merchant/poi/detail` | listed | UNVERIFIED |
| 238 | POST | `/api/merchant/shop/apply` | listed | UNVERIFIED |
| 239 | POST | `/api/topic/detail` | listed | UNVERIFIED |
| 240 | GET | `/api/merchant/offer-withdrawal/request/current` | listed | UNVERIFIED |
| 241 | GET | `/api/merchant/offer-withdrawal/request/result` | listed | UNVERIFIED |
| 242 | POST | `/api/merchant/offer-withdrawal/request/withdraw` | listed | UNVERIFIED |
| 243 | POST | `/api/topic/edit-requests/submit` | listed | UNVERIFIED |
| 244 | POST | `/api/topic/edit-requests/read` | listed | UNVERIFIED |
| 245 | POST | `/api/topic/edit-requests/resume-post-processing` | listed | UNVERIFIED |
| 246 | GET | `/api/topic/module-preflight` | listed | UNVERIFIED |
| 247 | GET | `/api/channel/{channelId}/board` | listed | UNVERIFIED |
| 248 | GET | `/api/channel/{channelId}/board/{key}/top` | listed | UNVERIFIED |
| 249 | GET | `/api/channel/{channelId}/board/{key}/detail` | listed | UNVERIFIED |
| 250 | GET | `/api/channel/{channelId}/board/{key}/version` | listed | UNVERIFIED |
| 251 | GET | `/api/channel/{channelId}/board/{key}/me/best` | listed | UNVERIFIED |
| 252 | GET | `/api/channel/{channelId}/board/{key}/me/recent` | listed | UNVERIFIED |
| 253 | GET | `/api/channel/{channelId}/progress/overview` | listed | UNVERIFIED |
| 254 | GET | `/api/channel/{channelId}/progress/privacy` | listed | UNVERIFIED |
| 255 | POST | `/api/channel/{channelId}/progress/privacy` | listed | UNVERIFIED |
| 256 | GET | `/api/channel-platform/{family}/requests/{requestId}` | listed | UNVERIFIED |
| 257 | GET | `/api/im/channel/checkin-status` | listed | UNVERIFIED |
| 258 | GET | `/api/im/channel/checkin-rank` | listed | UNVERIFIED |
| 259 | GET | `/api/im/channel/checkin-request` | listed | UNVERIFIED |
| 260 | POST | `/api/im/channel/checkin` | listed | UNVERIFIED |
| 261 | POST | `/api/im/voice/upload` | listed | UNVERIFIED |
| 262 | GET | `/api/im/voice/receipt` | listed | UNVERIFIED |
| 263 | GET | `/api/im/voice/message/{messageId}` | listed | UNVERIFIED |
| 264 | GET | `/api/im/voice/message/{messageId}/authorization` | listed | UNVERIFIED |
| 265 | POST | `/api/project/state-requests/context` | listed | UNVERIFIED |
| 266 | POST | `/api/project/state-requests/submit` | listed | UNVERIFIED |
| 267 | POST | `/api/project/state-requests/read` | listed | UNVERIFIED |
| 268 | POST | `/api/template/author-requests/submit` | listed | UNVERIFIED |
| 269 | POST | `/api/template/author-requests/read` | listed | UNVERIFIED |
| 270 | GET | `/api/template/report-receipt` | listed | UNVERIFIED |
| 271 | POST | `/api/template/report-receipt` | listed | UNVERIFIED |
| 272 | POST | `/api/us/auth/apple/challenges` | listed | UNVERIFIED |
| 273 | POST | `/api/us/auth/apple/exchange` | listed | UNVERIFIED |
| 274 | GET | `/api/us/auth/session` | listed | UNVERIFIED |
| 275 | GET | `/api/common/uploadOSS/receipt` | listed | UNVERIFIED |
| 276 | GET | `/api/free-explore/bundle/transfer/preview` | listed | UNVERIFIED |
| 277 | POST | `/api/free-explore/bundle/transfer` | listed | UNVERIFIED |
| 278 | GET | `/api/free-explore/bundle/transfer` | listed | UNVERIFIED |
| 279 | GET | `/api/free-explore/bundle/transfer/receipt` | listed | UNVERIFIED |
| 280 | POST | `/api/free-explore/bundle/transfer/{id}/revoke` | listed | UNVERIFIED |
| 281 | POST | `/api/free-explore/bundle/voucher/appeal` | listed | UNVERIFIED |
| 282 | GET | `/api/free-explore/bundle/voucher/appeal/receipt` | listed | UNVERIFIED |
| 283 | GET | `/api/free-explore/bundle/voucher/appeal` | listed | UNVERIFIED |
| 284 | GET | `/api/guilds/{kind}/{guildId}/channels` | listed | UNVERIFIED |
| 285 | GET | `/api/guilds/{kind}/{guildId}/channels/manage` | listed | UNVERIFIED |
| 286 | GET | `/api/im/pins` | listed | UNVERIFIED |
| 287 | POST | `/api/im/pins/sort` | listed | UNVERIFIED |
| 288 | GET | `/api/mod-settlement/mine` | listed | UNVERIFIED |
| 289 | GET | `/api/mod-settlement/mine/income` | listed | UNVERIFIED |
| 290 | POST | `/api/onboarding/get` | listed | UNVERIFIED |
| 291 | POST | `/api/onboarding/submit` | listed | UNVERIFIED |
| 292 | GET | `/api/compliance/usage-records` | listed | UNVERIFIED |
| 293 | GET | `/api/compliance/usage-records/request` | listed | UNVERIFIED |
| 294 | POST | `/api/growth/leaderboard/anonymous` | listed | UNVERIFIED |
| 295 | POST | `/api/space/leave` | listed | UNVERIFIED |
| 296 | POST | `/api/space/join-pause` | listed | UNVERIFIED |
| 297 | POST | `/api/ugc/block` | listed | UNVERIFIED |
| 298 | POST | `/api/ugc/report` | listed | UNVERIFIED |
| 299 | GET | `/api/user/follow-list` | listed | UNVERIFIED |
| 300 | POST | `/api/user/sms/send` | listed | UNVERIFIED |
| 301 | GET | `/api/im/device/attempts` | listed | UNVERIFIED |
| 302 | GET | `/api/im/notify-log` | listed | UNVERIFIED |
| 303 | GET | `/api/im/notify-pref` | listed | UNVERIFIED |
| 304 | POST | `/api/im/notify-pref` | listed | UNVERIFIED |
| 305 | GET | `/api/im/notification-requests/{requestId}` | listed | UNVERIFIED |
| 306 | GET | `/api/im/mute-state` | listed | UNVERIFIED |
| 307 | GET | `/api/im/mute-receipt` | listed | UNVERIFIED |
| 308 | GET | `/api/im/interaction/request` | listed | UNVERIFIED |
| 309 | POST | `/api/im/pin` | listed | UNVERIFIED |
| 310 | GET | `/api/im/poll/create-receipt` | listed | UNVERIFIED |
| 311 | GET | `/api/im/read-state` | listed | UNVERIFIED |
| 312 | GET | `/api/im/read-receipt` | listed | UNVERIFIED |
| 313 | POST | `/api/im/route-share-source` | listed | UNVERIFIED |
| 314 | GET | `/api/im/unread-summary` | listed | UNVERIFIED |
| 315 | GET | `/api/im/search` | listed | UNVERIFIED |
| 316 | POST | `/api/map/public-layers` | listed | UNVERIFIED |
| 317 | GET | `/api/privacy/progress` | listed | UNVERIFIED |
| 318 | POST | `/api/privacy/progress` | listed | UNVERIFIED |
| 319 | POST | `/api/support/tickets/list` | listed | UNVERIFIED |
| 320 | POST | `/api/support/tickets/detail` | listed | UNVERIFIED |
| 321 | POST | `/api/registration/original-event` | listed | UNVERIFIED |
| 322 | GET | `/api/official/v2/events/{id}/publish-check` | listed | UNVERIFIED |
| 323 | POST | `/api/welcome-screen/get` | listed | UNVERIFIED |
| 324 | GET | `/api/play/compatibility` | listed | UNVERIFIED |
| 325 | POST | `/api/play/compatibility` | listed | UNVERIFIED |
| 326 | GET | `/api/play/help` | listed | UNVERIFIED |
| 327 | GET | `/api/play/help/quota` | listed | UNVERIFIED |
| 328 | POST | `/api/play/help/use` | listed | UNVERIFIED |
| 329 | GET | `/api/play/run-score-detail` | listed | UNVERIFIED |
| 330 | POST | `/api/play/help/skip` | listed | UNVERIFIED |
| 331 | GET | `/api/play/help/skip/receipt` | listed | UNVERIFIED |
| 332 | POST | `/api/play/hangman/state` | listed | UNVERIFIED |
| 333 | POST | `/api/play/hangman/submit` | listed | UNVERIFIED |
| 334 | GET | `/api/play/accusation` | listed | UNVERIFIED |
| 335 | POST | `/api/play/accusation/confirm` | listed | UNVERIFIED |
| 336 | GET | `/api/play/accusation/receipt` | listed | UNVERIFIED |
| 337 | GET | `/api/play/action-receipt/state` | listed | UNVERIFIED |
| 338 | GET | `/api/topic/publish-check/fields-g47` | listed | UNVERIFIED |
| 339 | GET | `/api/topic/author-config/hints-g47` | listed | UNVERIFIED |
| 340 | POST | `/api/topic/author-config/hints/validate-g47` | listed | UNVERIFIED |
| 341 | GET | `/api/topic/publish-status-g47` | listed | UNVERIFIED |
| 342 | GET | `/api/topic/publish-result-g52` | listed | UNVERIFIED |
| 343 | GET | `/api/topic/my-projects-status-g52` | listed | UNVERIFIED |
| 344 | GET | `/business/ug-audit/topic/{topicId}/config` | listed | UNVERIFIED |
| 345 | GET | `/business/ug-audit/run/{runId}/quota` | listed | UNVERIFIED |
| 346 | GET | `/business/ug-audit/run/{runId}/detail` | listed | UNVERIFIED |
| 347 | POST | `/api/template/topic-template/adoption-info` | listed | UNVERIFIED |
| 348 | GET | `/api/template/topic-template/location-todos-g50` | listed | UNVERIFIED |
| 349 | POST | `/api/template/topic-template/location-reconfirm-g50` | listed | UNVERIFIED |
| 350 | POST | `/api/template/topic-template/source-g51/adoption/record` | listed | UNVERIFIED |
| 351 | GET | `/api/template/topic-template/source-g51/adoption` | listed | UNVERIFIED |
| 352 | POST | `/api/template/topic-template/source-g51/credits/save` | listed | UNVERIFIED |
| 353 | GET | `/api/template/topic-template/source-g51/credits` | listed | UNVERIFIED |
| 354 | GET | `/api/template/topic-template/source-g51/preview` | listed | UNVERIFIED |
| 355 | GET | `/api/play/node-closure` | listed | UNVERIFIED |
| 356 | GET | `/api/play/reading-g54/manifest` | listed | UNVERIFIED |
| 357 | GET | `/api/play/reading-g54/position` | listed | UNVERIFIED |
| 358 | POST | `/api/play/reading-g54/position` | listed | UNVERIFIED |
| 359 | POST | `/api/team/seats` | listed | UNVERIFIED |
| 360 | GET | `/api/team/state-g56` | listed | UNVERIFIED |
| 361 | GET | `/api/team/leave-impact-g56` | listed | UNVERIFIED |
| 362 | POST | `/api/team/quit-g56` | listed | UNVERIFIED |
| 363 | GET | `/api/team/shared-outcome-g56` | listed | UNVERIFIED |
| 364 | POST | `/api/team/handle-g56` | listed | UNVERIFIED |
| 365 | POST | `/api/registration/delivery-g57` | listed | UNVERIFIED |
| 366 | POST | `/api/registration/order-check-g57` | listed | UNVERIFIED |
| 367 | GET | `/api/refund/impact-g58` | listed | UNVERIFIED |
| 368 | GET | `/api/creator/revenue-g58` | listed | UNVERIFIED |
| 369 | GET | `/api/topic/post-game-outcome-g58` | listed | UNVERIFIED |
| 370 | GET | `/api/leaderboard/rank-basis-g58` | listed | UNVERIFIED |

## Outside the 370

The static tables also name the following. They were not requested. They are not in the executed count.

| Item | Static table | This run |
|---|---|---|
| `GET /api/play/nodes` | rt-04 G37-3: advice on an existing route, not its own mapping | not executed |
| G43 | rt-04: no controller (`QaOptionMediaG43`) | not executed |
| G46 | rt-04: no controller; `ClueTransformG46Support.apply` sits inside `/api/play/nodes` | not executed |
| `POST /api/merchant/npc/voice/script` | rt-03: NOT ON THIS BRANCH | not executed |
| `POST /api/merchant/npc/voice/revoke` | rt-03: NOT ON THIS BRANCH | not executed |
| `GET /api/city-game/state/snapshot` (`sync=TRANSACTIONAL_EVENTS_V1`) | rt-01 row 37: not counted | not executed |
| `POST /api/merchant/insight` | rt-01: no mapping; the mapped path is `POST /api/ai/merchant/insight` (row in the ledger) | not executed |
| `/api/club/activity/join` | rt-01 no-route table, G04 | not executed |
| `/api/club/activity/cancel` | rt-01 no-route table, G04 | not executed |
| `/api/club/activity/detail` | rt-01 no-route table, G04 | not executed |
| `/api/club/events` | rt-01 no-route table, G04 | not executed |
| `/api/club/events/Checkin` | rt-01 no-route table, G04 | not executed |
| `/api/club/events/proxy-enroll` | rt-01 no-route table, G04 | not executed |
| `/api/club/join-requests/apply` | rt-01 no-route table, G05 | not executed |
| `/api/club/notices/send` | rt-01 no-route table, G05 | not executed |
| `/api/club/notices` | rt-01 no-route table, G05 | not executed |
| `/api/club/events/save` | rt-01 no-route table, G05 | not executed |
| `/api/club/group-code` | rt-01 no-route table, G05 | not executed |
| `/api/club/group-code/save` | rt-01 no-route table, G05 | not executed |
| `GET /api/topic/attribute-author` | rt-01 no-route table | not executed |
| `DELETE /api/topic/attribute-author` | rt-01 no-route table | not executed |
| `GET /api/topic/attribute-author/references` | rt-01 no-route table | not executed |
| `POST /api/topic/attribute-author/validate` | rt-01 no-route table | not executed |
| `/api/workshop/purchased/**` | rt-01: no `workshop/purchased` Java on the branch | not executed |
| `PUT /api/im/members/{memberId}/roles` | rt-03 G33: BLOCKED, no route | not executed |
| `POST /api/im/unpin` | rt-03 G34: BLOCKED, no route | not executed |
| `POST /api/invite/revoke` | rt-03 G34: BLOCKED, no route | not executed |
| `/api/location-share/personal/*` | rt-03 G34: BLOCKED, no route | not executed |
| `/api/mod-commerce/*` | rt-03 G34: BLOCKED, no route | not executed |
| `/api/mod-installation/` | rt-03 G35: BLOCKED, no route | not executed |
| `/api/mod-owned-report/licenses/` | rt-03 G35: BLOCKED, no route | not executed |
| `/api/mod-upgrade/` | rt-03 G35: BLOCKED, no route | not executed |
| `/api/pay/create` | rt-03 G35: BLOCKED, no route | not executed |
| `/api/team/original-request` | rt-03 G35: BLOCKED, no route | not executed |

rt-01 also says the `/api/city-game/` prefixes and the catalogue template `/api/city-game/{}/request/{}` are not separate routes. The concrete routes are the G06/G07 rows already in the ledger.

## Not done

No SSH. No contact with `47.103.124.64`. No deploy. No change to a production database. No CI ledger refresh. No visual change. No secret is written here.

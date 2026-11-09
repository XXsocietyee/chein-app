# Backend deploy plan

This is a plan. It is not an approval. Deploy happens only after the owner writes "deploy now".

This document does not deploy, does not change code, and does not change `application.yml`. It does not SSH. It does not contact `47.103.124.64`. It does not run a rehearsal against production. It does not record secrets. Facts recorded here are the only facts this plan relies on. Anything not stated below is unknown.

## Commits

The candidate backend commit is `623d18ca` on the private backend repo `liboyang42-cpu/chengyin`. That repo is not this repo.

The production commit is `014fc0d8` on `liboyang42-cpu/chengyin`. The production jar described under Rollback is the build of that commit.

The full commit object ids were not resolved in this checkout. They stay unknown, and this plan does not invent the remaining digits. The diff between the two commits is unknown. The candidate artifact name, path, and checksum are unknown.

## Runtime flag

A throwaway boot of `623d18ca` reached Started and HTTP 200 only when the JVM flag `--spring.main.allow-circular-references=true` was passed.

The flag was not added to `application.yml`.

The runtime environment needs `--spring.main.allow-circular-references=true` for that candidate boot.

That boot result was not shown for the older production jar. Whether the older production jar starts with this flag, without this flag, or at all is unknown.

The boot host, the URL that returned HTTP 200, and the way the runtime environment passes the flag are unknown. This plan does not boot either jar.

## Staging rehearsal

Staging rehearsal uses a throwaway database with a copy of the production schema, never production data. The copy is schema only.

The script is `docs/release/staging-schema-rehearsal.py`. It reads a local SQL file and writes table and index DDL to a new local directory outside this repo. A schema-only dump prologue (`SET` session assignments, and `LOCK TABLES` / `UNLOCK TABLES`) is dropped from the written copy. A row statement, `SELECT`, grant, user, routine, view, or any other unreviewed statement rejects the whole file and writes nothing.

The script also rejects a symlink, an ambient database variable (`DATABASE_URL`, `MYSQL_PWD`, `MYSQL_HOST`, `SPRING_DATASOURCE_URL`, `SPRING_DATASOURCE_PASSWORD`, `SPRING_DATASOURCE_USERNAME`), secret-like material, a remote shell, and any input that names `47.103.124.64`, `chengyinhub.com`, or `chengyinhub.cn`. It does not open a socket, start a database client, SSH, or deploy.

```bash
python3 docs/release/staging-schema-rehearsal.py --schema-copy-only --schema-file <schema.sql> --out <local-dir>
```

`<schema.sql>` and `<local-dir>` are local paths. `<local-dir>` must be outside this repo and must not already exist. The script has no host argument and no apply step. The database host, name, engine, and credentials are still unknown, so this plan does not load the copy into a database.

`python3 docs/release/staging-schema-rehearsal.py --self-check` uses temporary fixtures only. That command was run in this workspace before this plan was committed. It passed. It did not open a socket and did not contact production. A rehearsal has not been run against production.

## Rollback

The rollback target is the production jar whose SHA-256 digest starts with `655a377a`. The rest of the digest was not recorded. The remaining digits are unknown and are not filled in here.

That jar is the build of backend commit `014fc0d8` on private repo `liboyang42-cpu/chengyin`. The jar path, file name, and size are unknown.

This procedure does not run as part of this change. Deploy happens only after the owner writes "deploy now".

1. Keep the jar on the operator's own machine. Do not fetch it from `47.103.124.64`. Do not open SSH. Do not copy a route table or `application.yml` into this repo.
2. Verify the local file with `python3 docs/release/staging-schema-rehearsal.py --verify-rollback-jar <local-jar>`. The path must be a regular local file, not a symlink. Continue only when the script prints `rollback-jar-prefix-match`. That line means the digest starts with `655a377a`. The script does not print the rest of the digest, and the rest must not be added to this plan. `rollback-jar-prefix-mismatch` means stop. The script does not copy the file, start it, or send it anywhere.
3. Treat a prefix match as the production jar of commit `014fc0d8` only when the operator can show that identity outside this repo. This script cannot resolve the full commit object id. If that identity is not shown, stop.
4. Do not start the jar from this script. Do not assume `--spring.main.allow-circular-references=true` for this older jar. The flag was observed only on candidate `623d18ca`.
5. Replacing the running process is a production change. This plan supplies no host, service name, remote path, or command for that swap. It stays unperformed until the owner writes "deploy now".
6. After a future approved swap, smoke is still the four read-only checks below. Their URLs stay unknown.

## Smoke

Smoke after a future deploy is four read-only checks.

The check URLs were not recorded. They are unknown. This plan does not name them.

What each check reads, and which responses count as success, are unknown.

## Route tables

Route tables must not be copied into the public `chengyin-ios` repo.

This plan does not include a route table.

## Not in this plan

- Deploy happens only after the owner writes "deploy now". This document is not that phrase.
- No deploy is performed now.
- No SSH is opened.
- `47.103.124.64` is not contacted.
- The rehearsal is not run against production.
- No secret is recorded.
- No host, command, or route table is supplied for a future deploy.

# Backend deploy plan

This is a plan. Production deploy is not approved. No deploy now.

This document does not deploy, does not change code, and does not change `application.yml`. Facts recorded here are the only facts this plan relies on. Anything not stated below is unknown.

## Commits

The candidate backend commit is `623d18ca` on the private backend repo. That repo is not this iOS repo.

The production commit is `014fc0d8`.

The full commit object ids, the private backend repo location, and the diff between these two commits are unknown. The candidate artifact name, path, and checksum are unknown.

## Runtime flag

A throwaway boot of `623d18ca` reached Started and HTTP 200 only when the JVM flag `--spring.main.allow-circular-references=true` was passed.

The flag was not added to `application.yml`.

The runtime environment needs `--spring.main.allow-circular-references=true`.

That boot result was not shown for the older production jar. Whether the older production jar starts with this flag, without this flag, or at all is unknown.

The boot host, the URL that returned HTTP 200, and the way the runtime environment passes the flag are unknown.

## Staging rehearsal

Staging rehearsal uses a throwaway database with a copy of the production schema, never production data.

The database host, name, engine, credentials, and the method that copies the schema are unknown. Whether a rehearsal has already been run is unknown.

## Rollback

The rollback target jar sha256 is known only by the prefix `655a377a`. The rest of the hash was not recorded. The remaining digits are unknown and are not filled in here.

The rollback jar path, file name, size, and the commit it was built from are unknown.

## Smoke

Smoke after a future deploy is four read-only checks.

The check URLs were not recorded. They are unknown. This plan does not name them.

What each check reads, and which responses count as success, are unknown.

## Route tables

Route tables must not be copied into the public `chengyin-ios` repo.

This plan does not include a route table.

## Not in this plan

- Production deploy is not approved.
- No deploy is performed now.
- No host, command, or route table is supplied for a future deploy.

# CB90 — GitHub Actions billing block

Owner note for [iOS CI run 42605481564](https://github.com/liboyang42-cpu/chengyin-app/actions/runs/42605481564).

Base of this note: `origin/rc/20261108` `2f6d5041a57d876d3b0a953f56ecf5208089622f`.
Branch: `cursor/cb90`.

This note does not rerun the workflow, does not edit `.github/workflows`, and does not refresh the CI manifest.

## What failed

Workflow **iOS CI** (`.github/workflows/ios-ci.yml`), attempt 1, event `pull_request`.
Head branch `cursor/cb81`, head SHA `dca94228a905a86279d92ca28e260aa46d707a4a`.
Display title: `docs: CB81 note that ios-ci.yml has no failure list yet`.
Conclusion: `failure`. The repository is private.

Times below are America/Los_Angeles (PST, UTC−8).

| | UTC | Pacific |
| --- | --- | --- |
| Run created | 2026-11-09 11:00:29Z | 2026-11-09 3:00:29 AM |
| Jobs started | 2026-11-09 11:00:30Z | 2026-11-09 3:00:30 AM |
| Jobs completed | 2026-11-09 11:00:31Z or 11:00:32Z | 3:00:31 AM or 3:00:32 AM |
| Run updated | 2026-11-09 11:00:33Z | 2026-11-09 3:00:33 AM |

All 8 jobs failed in about 2 seconds. Each job’s step list is empty, and each job’s runner name is empty. No checkout, build, or test log exists for this run.

| Job | Label | Completed (Pacific) | Link |
| --- | --- | --- | --- |
| debug-build | `xcode-27` | 3:00:32 AM | [129120272572](https://github.com/liboyang42-cpu/chengyin-app/actions/runs/42605481564/job/129120272572) |
| core-tests | `xcode-27` | 3:00:31 AM | [129120272817](https://github.com/liboyang42-cpu/chengyin-app/actions/runs/42605481564/job/129120272817) |
| appunit (0) | `xcode-27` | 3:00:32 AM | [129120272937](https://github.com/liboyang42-cpu/chengyin-app/actions/runs/42605481564/job/129120272937) |
| appunit (1) | `xcode-27` | 3:00:32 AM | [129120273040](https://github.com/liboyang42-cpu/chengyin-app/actions/runs/42605481564/job/129120273040) |
| appunit (2) | `xcode-27` | 3:00:31 AM | [129120272838](https://github.com/liboyang42-cpu/chengyin-app/actions/runs/42605481564/job/129120272838) |
| appunit (3) | `xcode-27` | 3:00:32 AM | [129120272929](https://github.com/liboyang42-cpu/chengyin-app/actions/runs/42605481564/job/129120272929) |
| release-gate | `ubuntu-24.04` | 3:00:32 AM | [129120273016](https://github.com/liboyang42-cpu/chengyin-app/actions/runs/42605481564/job/129120273016) |
| design-lint | `ubuntu-24.04` | 3:00:32 AM | [129120272962](https://github.com/liboyang42-cpu/chengyin-app/actions/runs/42605481564/job/129120272962) |

Every job carries the same check annotation on `.github`:

> The job was not started because recent account payments have failed or your spending limit needs to be increased. Please check the 'Billing & plans' section in your settings

The annotation names the account. It does not name a test, an assertion, or a line in `cursor/cb81`.

## macOS minute cost of a full ios-ci run

Prices below are the public list, read on November 9, 2026:

- [Actions runner pricing](https://docs.github.com/en/billing/reference/actions-runner-pricing)
- [GitHub-hosted runners reference](https://docs.github.com/en/actions/reference/runners/github-hosted-runners), private-repository table

For a private repository, `xcode-27` is the standard macOS runner: 3-core M1, 7 GB RAM, 14 GB SSD, arm64. That hardware is billing SKU `actions_macos` (“macOS 3-core or 4-core (M1 or Intel)”) at **$0.062 per minute**. The larger-runner SKUs are different machines (`macos_l` 12-core at $0.077, `macos_xl` 5-core M2 Pro at $0.102). `ios-ci.yml` does not use them.

A full iOS CI run starts six `xcode-27` jobs together:

| Job | `timeout-minutes` |
| --- | --- |
| debug-build | 90 |
| core-tests | 180 |
| appunit shard 0 | 180 |
| appunit shard 1 | 180 |
| appunit shard 2 | 180 |
| appunit shard 3 | 180 |

GitHub rounds each job’s minutes up to the next whole minute. Private standard runners draw from the account’s included compute at this rate, and further minutes are charged at the same rate.

**Minute cost of the macOS half of one full run:**

- One `xcode-27` job: **$0.062 per minute**.
- All six macOS jobs at once: **6 × $0.062 = $0.372 per minute**.

The dollar total is `$0.062` times the sum of those six jobs’ rounded minutes. Run 42605481564 has no such sum. The jobs ended with an empty runner name and an empty step list, so this note does not record a measured minute count from it.

The `timeout-minutes` column is the longest each job is allowed to run. The jobs run in parallel, so the longest wall clock among them is 180 minutes. The billed-minute cap is the sum of the six caps, 990 minutes. At the public rate that cap is **990 × $0.062 = $61.38**, and only if every macOS job runs until its own timeout. The minutes a finished run actually uses are whatever those jobs take once a runner accepts them.

`release-gate` and `design-lint` use `ubuntu-24.04`. On a private repository that label is a 2-core x64 Linux runner, SKU `actions_linux`, at **$0.006 per minute**. They are outside the macOS estimate. This run did not start them either.

This note did not open the account’s plan, remaining included compute, payment history, or current budget. Those sit on the owner’s billing page: <https://github.com/settings/billing> (user `liboyang42-cpu`).

## What the owner can do

The annotation leaves two account-side causes. Either one matches the empty jobs. This note cannot see which one is active.

1. **Raise the spending limit.** In [Billing](https://github.com/settings/billing), open **Budgets and alerts** and raise the budget that caps GitHub Actions (a product budget, or a SKU budget that includes `actions_macos`). GitHub’s current page calls this a budget; the job text still says “spending limit.” A budget that stops usage at the current amount will keep rejecting these jobs. [Setting up budgets](https://docs.github.com/en/billing/how-tos/set-up-budgets). [Troubleshooting workflows — reviewing billing errors](https://docs.github.com/en/actions/how-tos/troubleshoot-workflows#reviewing-billing-errors).
2. **Fix billing.** If recent payments failed, update the payment method under Billing → Payment information and let the new charge succeed. [Unlocking a locked account](https://docs.github.com/en/billing/how-tos/troubleshooting/locked-account). [Managing payment information](https://docs.github.com/en/billing/how-tos/set-up-payment/manage-payment-info). GitHub’s doc says a successful payment unlocks the account, and that payments may take up to 24 hours to process.
3. **Use the separate Xcode Cloud path.** Setup for team 9VHY8N755R is already in [`docs/release/xcode-cloud-setup.md`](xcode-cloud-setup.md). That path bills Apple compute. It does not spend GitHub Actions minutes, and it stays available while Actions refuses to start jobs.

After the account can start hosted jobs again, a later iOS CI run is what produces build and test logs. This note does not start that run.

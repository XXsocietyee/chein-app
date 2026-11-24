# Second self-hosted runner on the same Mac

Register a second GitHub Actions self-hosted runner for [liboyang42-cpu/chengyin-app](https://github.com/liboyang42-cpu/chengyin-app) on the Mac that already has one runner registered for these labels:

- `self-hosted`
- `macOS`
- `ARM64`
- `chengyin-app`

The runner already registered for those labels stays as it is. Do not remove it, replace it, or run `config.sh` in its directory. The new runner needs its own directory, its own name, and its own `_work` directory.

This file has no registration token, personal access token, password, or other secret. The placeholder `<TOKEN>` below is not a token.

## 1. Copy the token and the download URL from GitHub

On the repository, open **Settings → Actions → Runners → New self-hosted runner**. Choose **macOS** and **ARM64**.

From that page, copy:

- the registration token
- the tarball download URL

The token stays on the Mac. It never goes in git, and it does not belong in this file, a commit, or a pull request. Use it only in the `config.sh` command below, in place of `<TOKEN>`.

## 2. Unpack into a new directory

`mkdir` a new directory. Do not use the directory of the runner that is already registered, and do not run the commands below inside that directory.

`$HOME/actions-runner-2` is only a suggestion. If that path is the existing runner directory, pick a different new directory. The directory name and the runner name do not have to match. The labels stay `self-hosted,macOS,ARM64,chengyin-app`.

`<DOWNLOAD_URL>` is the tarball URL copied from the GitHub page in the previous step. Do not reuse a tarball that belongs to the existing runner.

```sh
mkdir "$HOME/actions-runner-2"
cd "$HOME/actions-runner-2"
curl -o actions-runner-osx-arm64.tar.gz -L "<DOWNLOAD_URL>"
tar xzf ./actions-runner-osx-arm64.tar.gz
```

## 3. Configure and start the new runner

Run this from the new directory. Do not pass `--replace`.

```sh
./config.sh --url https://github.com/liboyang42-cpu/chengyin-app --token <TOKEN> --name fanning-air-5-2 --labels self-hosted,macOS,ARM64,chengyin-app --work _work --unattended
./svc.sh install && ./svc.sh start
```

`--work _work` is this runner’s work directory, inside the new directory (`$HOME/actions-runner-2/_work` if you used the suggested path). It is not the existing runner’s `_work`.

Suggested runner name: `fanning-air-5-2`. The owner must change `--name` if that name is already taken. Use a free name, keep all four labels, and still do not pass `--replace`.

## What this changes

One Mac with two runner processes can run two jobs at once. Each process takes one job. Registering the second runner does not by itself change the workflow file.

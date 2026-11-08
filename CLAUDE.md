# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

An Ansible-based provisioner that configures a personal development machine (shell, dotfiles, CLI tools, language runtimes). There is no application to build — the "product" is the playbook itself, applied to the local host.

## Commands

Bootstrap a fresh machine (installs Ansible, then runs the playbook via `ansible-pull`):

```bash
./setup.sh                 # local checkout
# or remote, one-shot:
curl -s https://raw.githubusercontent.com/mtkhawaja/dev-environment/main/setup.sh | bash
```

Once Ansible is installed, iterate on the playbook directly against the local host:

```bash
ansible-galaxy collection install -r requirements.yml   # one-time: pulls community.general
ansible-playbook -i localhost, local.yaml               # full run
ansible-playbook -i localhost, local.yaml --tags modern-cli   # run one area only
```

Test a full run in a throwaway Ubuntu container (the safest way to validate end-to-end):

```bash
./run_docker.sh                                          # build + run interactive shell
docker build --build-arg TAGS="--tags modern-cli" -t mtkhawaja/dev-env:latest .   # scope the in-image run
```

**A local full run mutates your real home directory** — `zsh.yaml` deletes and reinstalls `~/.oh-my-zsh`, and `dotfiles.yaml` force-resets `~/.dotfiles` to `origin/main` (unpushed dotfiles commits are discarded) and restows it. When testing changes, use Docker or a `--tags` scope rather than a bare local run.

`setup.sh` writes timestamped logs to `~/.ansible-dev-env-bootstrap/`.

## Architecture

- **`local.yaml`** is the single play and the entry point. It loads `src/ansible/vars/main.yml` via `vars_files`, runs `pre_tasks` (apt cache, base packages) and `directories`, then imports one task file per area from `src/ansible/tasks/` (zsh, dotfiles, tools, sdkman, neovim, java, js, bun, bitwarden-cli, python, yazi, go, opentofu, tflint, awscli, github-cli, sonarqube-cli, acli, modern-cli, apps, claude-code). Adding a new area = new file in `src/ansible/tasks/` + an `import_tasks` line in `local.yaml`.
- **`setup.sh`** is the bootstrap layer, kept separate from the playbook: it detects the OS (`uname`), installs Ansible (Homebrew on macOS, `ppa:ansible/ansible` apt on Linux), installs collections from `requirements.yml`, then hands off to `ansible-pull`.
- **`Dockerfile`** mirrors a real run on `ubuntu:resolute` (26.04 LTS) in a multi-stage build (`base` → `setup` creates the `mtkhawaja` sudo user → `runnable` copies the repo and runs `ansible-playbook $TAGS local.yaml`). Use it to verify changes without touching your own machine. On Apple Silicon, build natively (arm64): under amd64 emulation (Rosetta) 26.04's GNU tar fails to create directories ("Function not implemented"), breaking every tarball extraction.
- Dotfiles are **not** in this repo — `dotfiles.yaml` clones `github.com/mtkhawaja/dotfiles` (force-overwriting, backing up uncommitted local changes first) and applies them with GNU Stow.

## Conventions

- **Tags are mandatory.** Every task carries tags: a broad `initial-setup` (or `cleanup`) plus an area tag (`zsh`, `modern-cli`, `eza`, …). These are how you scope partial runs and how the Docker `TAGS` build-arg works — keep tagging new tasks the same way.
- **The repo is cross-platform** (macOS Apple Silicon + Ubuntu 26.04 "Resolute"/WSL, x86_64 or arm64). Every install task branches on `ansible_facts.os_family`: `== "Darwin"` (Homebrew) vs `== "Debian"` (apt / `.deb` / release binary). Per-OS package lists live in `src/ansible/vars/main.yml`. Node is managed by **nvm**, Java by **SDKMAN**, Python by **uv** (Astral), plus **Bun** — all curl/git-based and cross-platform. Release-asset URLs pick the arch via `linux_arch` (`x86_64`/`aarch64`) or `deb_arch` (`amd64`/`arm64`) from `vars/main.yml`. When adding a tool, follow `.claude/skills/adding-a-tool/`; the migration history is in `docs/superpowers/specs/` and `docs/superpowers/plans/`.
- **ansible-lint must pass** (`ansible-lint`, production profile; blocking in CI). Use FQCNs, `true`/`false`, and run upstream install scripts through `src/ansible/tasks/common/install-script.yaml` (`import_tasks` + vars) rather than `curl | sh`.
- **Per-OS config is centralized** in `src/ansible/vars/main.yml` — version pins and the macOS/Debian package + release-binary maps. Add new cross-platform package data here rather than inlining it in tasks.
- **Tool install patterns**, in rough order of preference: native package manager (`apt` / `community.general.homebrew`) → upstream `.deb` (yazi on Debian) → release tarball/zip via `unarchive` into `~/.local/bin` (already on PATH). Prefer apt even when it lags upstream a little. Release archives need per-asset `extra_opts` to normalize layout (`--strip-components=1`, `-j`); build URLs with `linux_arch`/`deb_arch` so arm64 works. Pin versions in `vars/main.yml`.
- Downloaded installers and `.deb`/temp files are cleaned up in a follow-up task — match that when adding downloads. Use `creates:` / `when: ... is changed` to keep tasks idempotent.

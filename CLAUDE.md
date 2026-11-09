# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

An Ansible-based provisioner that configures a personal development machine (shell, dotfiles, CLI tools, language runtimes). There is no application to build — the "product" is the playbook itself, applied to the local host.

## Commands

Bootstrap a fresh machine (installs Ansible, then runs the playbook via `ansible-pull`):

Three target environments (details in README "Set up a machine"); `setup.sh` always pulls `main` from GitHub, not your checkout:

```bash
bash setup.sh                              # macOS (installs Homebrew if missing)
bash setup.sh                              # Linux with a desktop (asks for the sudo password once)
HEADLESS=true bash setup.sh                # Linux server: skips GUI apps + desktop-only packages
```

Once Ansible is installed, iterate on the playbook directly against the local host:

```bash
ansible-galaxy collection install -r requirements.yml   # one-time: pulls community.general
ansible-playbook -i localhost, local.yaml               # full run
ansible-playbook -i localhost, local.yaml --tags modern-cli   # run one area only
ansible-playbook -i localhost, -K -e headless=true local.yaml # Linux server flavor (-K: sudo password)
```

Test a full run in a throwaway Ubuntu container (the safest way to validate end-to-end):

```bash
./run_docker.sh                                          # build + run interactive shell
docker build --build-arg TAGS="--tags modern-cli" -t mtkhawaja/dev-env:latest .   # scope the in-image run
docker build --build-arg TAGS="-e headless=true" -t mtkhawaja/dev-env:headless .   # headless/server flavor
```

**A local full run mutates your real home directory** — `zsh.yaml` deletes and reinstalls `~/.oh-my-zsh`, and `dotfiles.yaml` force-resets `~/.dotfiles` to `origin/main` (unpushed dotfiles commits are discarded) and restows it. When testing changes, use Docker or a `--tags` scope rather than a bare local run.

`setup.sh` writes timestamped logs to `~/.ansible-dev-env-bootstrap/`.

## Architecture

- **`local.yaml`** is the single play and the entry point. It loads `src/ansible/vars/main.yml` via `vars_files`, runs `pre_tasks` (apt cache, base packages) and `directories`, then imports one task file per area from `src/ansible/tasks/` (zsh, dotfiles, tools, sdkman, neovim, java, js, bun, bitwarden, python, yazi, go, opentofu, tflint, awscli, auto-updates, power, ssh, github-cli, sonarqube-cli, acli, browser-testing, modern-cli, apps, claude-code). Adding a new area = new file in `src/ansible/tasks/` + an `import_tasks` line in `local.yaml`.
- **`ssh-server.yaml`** is a second, opt-in playbook (never imported by `local.yaml` or run by `setup.sh`; the regular install only adds the SSH client). It installs the OpenSSH server already hardened in one go: authorizes `-e ssh_authorized_keys=<key or URL>`, refuses (installing nothing) without a key, then installs `openssh-server` with a key-only/no-root drop-in validated by `sshd -t`, and enables `ssh.socket`.
- **`tailscale.yaml`** is another opt-in playbook (Linux only) wrapping `src/ansible/tasks/tailscale.yaml`; `local.yaml` imports the same tasks only with `-e tailscale=true`. Joins the tailnet only when `TS_AUTHKEY` is set (env, `no_log`).
- **`setup.sh`** is the bootstrap layer, kept separate from the playbook: it detects the OS (`uname`), installs Ansible (Homebrew on macOS, `ppa:ansible/ansible` apt on Linux), installs collections from `requirements.yml`, then hands off to `ansible-pull`.
- **`Dockerfile`** mirrors a real run on `ubuntu:resolute` (26.04 LTS) in a multi-stage build (`base` → `setup` creates the `mtkhawaja` sudo user → `runnable` copies the repo and runs `ansible-playbook $TAGS local.yaml`). Use it to verify changes without touching your own machine. On Apple Silicon, build natively (arm64): under amd64 emulation (Rosetta) 26.04's GNU tar fails to create directories ("Function not implemented"), breaking every tarball extraction.
- Dotfiles are **not** in this repo — `dotfiles.yaml` clones `github.com/mtkhawaja/dotfiles` (force-overwriting, backing up uncommitted local changes first) and applies them with GNU Stow.

## Conventions

- **Tags are mandatory.** Every task carries tags: a broad `initial-setup` (or `cleanup`) plus an area tag (`zsh`, `modern-cli`, `eza`, …). These are how you scope partial runs and how the Docker `TAGS` build-arg works — keep tagging new tasks the same way.
- **The repo is cross-platform** (the one deliberate exception: `browser-testing.yaml` is Linux-only) (macOS Apple Silicon + Ubuntu 26.04 "Resolute"/WSL, x86_64 or arm64). Every install task branches on `ansible_facts.os_family`: `== "Darwin"` (Homebrew) vs `== "Debian"` (apt / `.deb` / release binary). Per-OS package lists live in `src/ansible/vars/main.yml`. Node is managed by **nvm**, Java by **SDKMAN**, Python by **uv** (Astral), plus **Bun** — all curl/git-based and cross-platform. Release-asset URLs pick the arch via `linux_arch` (`x86_64`/`aarch64`) or `deb_arch` (`amd64`/`arm64`) from `vars/main.yml`. When adding a tool, follow `.claude/skills/adding-a-tool/`; the migration history is in `docs/superpowers/specs/` and `docs/superpowers/plans/`.
- **ansible-lint must pass** (`ansible-lint`, production profile; blocking in CI). Use FQCNs, `true`/`false`, and run upstream install scripts through `src/ansible/tasks/common/install-script.yaml` (`import_tasks` + vars) rather than `curl | sh`.
- **`headless` flag** (`-e headless=true`, or `HEADLESS=true ./setup.sh`) is for desktop-less servers: GUI apps and desktop-only packages are skipped. New GUI/desktop-only installs must be guarded with `not (headless | bool)` (always `| bool`: extra vars are strings).
- **Third-party apt repos must be added to `auto_updates.origins_patterns`** (usually `site=<repo host>`) or unattended-upgrades won't update their packages.
- **sudo on Ubuntu 26.04 is sudo-rs.** ansible-core < 2.22 can't parse its password prompt, so `ansible_become_exe` (vars/main.yml) falls back to the bundled classic `/usr/bin/sudo.ws` there. Ansible can't reuse cached sudo credentials, so password-protected sudo needs `-K`; `setup.sh` instead asks once and passes the password via `--become-password-file` (0600 file in a private temp dir, removed on exit) unless sudo is passwordless.
- **Use `systemd_running`** (not `ansible_facts.service_mgr`, which says "systemd" in plain containers) to guard tasks that start/reload units.
- **Per-OS config is centralized** in `src/ansible/vars/main.yml` — the macOS/Debian package + release-binary maps and download URLs. Add new cross-platform package data here rather than inlining it in tasks.
- **Tool install patterns**, in rough order of preference: native package manager (`apt` / `community.general.homebrew`) → upstream `.deb` (yazi on Debian) → release tarball/zip via `unarchive` into `~/.local/bin` (already on PATH). Prefer apt even when it lags upstream a little. Release archives need per-asset `extra_opts` to normalize layout (`--strip-components=1`, `-j`); build URLs with `linux_arch`/`deb_arch` so arm64 works.
- **No version pins.** Install the latest release at install time: unpinned package managers, `releases/latest/download/<asset>` URLs, or a "latest" lookup at runtime (go.dev `VERSION`, SonarQube `stable.version`, the `github.com/<repo>/releases/latest` web redirect for nvm, Eclipse's milestones index for jdtls) gated on the tool not being installed yet. **Never use the GitHub REST API (`api.github.com`)**: anonymous calls are limited to 60/hour per IP, which shared CI runners exhaust (it broke the macOS CI job). Re-runs don't upgrade (`creates:` / stat guards keep them idempotent). Pin only when upstream offers no way to get the latest, and say why in a comment.
- Downloaded installers and `.deb`/temp files are cleaned up in a follow-up task — match that when adding downloads. Use `creates:` / `when: ... is changed` to keep tasks idempotent.

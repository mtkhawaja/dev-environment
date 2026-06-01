# Sub-project 1 — Cross-platform Foundation

**Date:** 2026-05-30
**Status:** Approved (design)
**Repo:** `dev-environment`

## Goal

Make `dev-environment` provisionable on **macOS, Linux, and WSL** using an
**OS-branching** strategy (apt on Debian/WSL, Homebrew on macOS). This sub-project
establishes the cross-platform conventions and bootstrap, and proves them with a
pilot task that installs a set of modern CLI tools on every platform.

This is the first of four sub-projects in the broader whole-repo migration:

1. **Cross-platform foundation** (this spec)
2. Core packages & shell (`pre_tasks`, `directories`, `zsh`, `dotfiles`, `tools`)
3. Language runtimes (`go`, `js`, `java`/`sdkman`, `neovim`, `yazi`, `bitwarden-cli`, `python`→uv)
4. Testing / CI (macOS GitHub Actions runner + idempotency validation)

## Current state

- Linux-only by design: `ubuntu:noble` Docker image, `apt` throughout, and a
  `setup.sh` that bootstraps Ansible via the Ubuntu PPA.
- Orchestration is a single play in `local.yaml` importing per-area task files
  from `src/ansible/tasks/`.
- Conventions already present: version pinning via `set_fact` (`go.yaml`),
  release-artifact downloads via `get_url`/`unarchive` (`yazi.yaml`, `go.yaml`),
  binaries placed in `~/.local/bin` (already on `PATH`).
- `sdkman.yaml` and `java.yaml` are already cross-platform (curl + SDKMAN).

## Scope

**In scope**
- OS-detection convention + shared per-platform vars file.
- Cross-platform `setup.sh` bootstrap (macOS Homebrew path + existing Linux path).
- New pilot task `modern-cli.yaml` installing: `delta`, `lazygit`, `dust`, `duf`,
  `procs`, `sd`, `hyperfine` — cross-platform.
- Wiring into `local.yaml`.

**Out of scope** (later sub-projects)
- Migrating existing tasks (`pre_tasks`, `zsh`, `tools`, language runtimes, etc.).
- macOS CI automation (SP4).
- Linux **arm64** release-binary support (see Known Limitations).
- Any changes to the separate `dotfiles` repo (the "afterwards" follow-up).

## Design

### 1. OS detection & shared vars

Facts are gathered by default (the play does not disable `gather_facts`), so
`ansible_facts.os_family` is available:

- `"Debian"` → Ubuntu / WSL (Ubuntu) → apt path
- `"Darwin"` → macOS → Homebrew path

Branching convention for the whole migration:

```yaml
when: ansible_facts.os_family == "Darwin"   # or == "Debian"
```

Shared configuration lives in a new **`src/ansible/vars/main.yml`**, loaded from
`local.yaml` via `vars_files:`. It holds version pins and per-OS package-name maps.
This is the single home later sub-projects reuse.

Example structure:

```yaml
# src/ansible/vars/main.yml
modern_cli:
  # macOS: Homebrew formula names
  brew_formulae: [git-delta, lazygit, dust, duf, procs, sd, hyperfine]
  # Debian: split between apt and pinned release binaries
  apt_packages: [hyperfine, duf]
  versions:           # pin to latest stable; confirm at implementation time
    delta: "0.18.2"
    lazygit: "0.44.2"
    dust: "1.1.1"
    procs: "0.14.6"
    sd: "1.0.0"
```

> Version numbers above are initial pins to be confirmed against each project's
> latest stable release during implementation. They are not placeholders — the
> mechanism (pinned vars) is fixed; the exact strings get verified.

### 2. Cross-platform bootstrap (`setup.sh`)

Branch on `uname -s`:

- **`Darwin`:** install Homebrew if absent (official installer), then
  `brew install ansible`. Homebrew also provides `git`/`curl`.
- **`Linux`** (incl. WSL, which reports `Linux`): keep the existing apt +
  `ppa:ansible/ansible` flow unchanged.
- **Shared tail:** ensure the `community.general` collection is present
  (`ansible-galaxy collection install -r requirements.yml`), then
  `ansible-pull -U https://github.com/mtkhawaja/dev-environment.git -i localhost, local.yaml`.

Add a `requirements.yml` declaring `community.general`. (The full `ansible`
package bundles it; installing explicitly makes the `homebrew` module guaranteed
and documents the dependency.)

Logging structure (`LOG_DIR`, timestamped logfile, `log()` helper) is preserved.

### 3. Pilot task — `modern-cli.yaml`

**macOS branch** (single task):

```yaml
- name: "Install modern CLI tools (macOS)"
  community.general.homebrew:
    name: "{{ modern_cli.brew_formulae }}"
    state: present
  when: ansible_facts.os_family == "Darwin"
  tags: [modern-cli]
```

**Debian branch** (hybrid, `when: ansible_facts.os_family == "Debian"`):

- `apt`: install `modern_cli.apt_packages` (`hyperfine`, `duf` — both in Noble's
  `universe`).
- `delta`: `get_url` the pinned `.deb` from `dandavison/delta` releases →
  install via `ansible.builtin.apt: deb: <path>` → clean up.
- `lazygit`, `dust`, `procs`, `sd`: `get_url` the pinned release tarball →
  `unarchive` (flattened) into `~/.local/bin` → ensure executable. Guarded by
  `creates: ~/.local/bin/<tool>` for idempotency (matching the `yazi.yaml`
  pattern). Asset URLs built from `modern_cli.versions`.

All tasks tagged `modern-cli` plus a per-tool tag (e.g. `delta`, `lazygit`) to
match the existing `eza`/`yazi` tagging style.

### 4. Wiring

`local.yaml`:

```yaml
- hosts: localhost
  connection: local
  vars_files:
    - src/ansible/vars/main.yml
  pre_tasks:
    ...
  tasks:
    ...
    - import_tasks: src/ansible/tasks/modern-cli.yaml
```

## Idempotency

- `apt` and `community.general.homebrew` are idempotent.
- `.deb` install via `apt: deb:` is idempotent (apt skips if same version present).
- Release-binary tasks use `creates:` guards keyed to the destination binary path.
  Note: a version bump requires removing the existing binary (or the guard) to
  re-fetch — acceptable for the pilot and consistent with `yazi.yaml`.

## Testing strategy

- **Linux:** existing `docker build -t mtkhawaja/dev-env:latest .` runs the full
  playbook; the new task runs automatically once imported. Slice it with
  `docker build --build-arg TAGS="--tags modern-cli" .`. Verify each binary
  resolves on `PATH` and `--version` works inside the container.
- **macOS:** run locally — `ansible-playbook --tags modern-cli local.yaml` — and
  verify `brew list` + each `--version`. Automated macOS CI is SP4.

## Acceptance criteria

1. `setup.sh` bootstraps Ansible on both macOS (Homebrew) and Linux/WSL (apt)
   and reaches `ansible-pull`/playbook execution.
2. Running the playbook with `--tags modern-cli` installs all seven tools on:
   - Ubuntu Noble (verified via Docker), and
   - macOS (verified locally).
3. All seven binaries are on `PATH` and report a version after a fresh run.
4. A second run is idempotent (no changes reported for already-installed tools,
   aside from the documented release-binary version-bump caveat).
5. Existing Linux behavior for all other tasks is unchanged.

## Known limitations

- **Linux arm64** is not handled by the release-binary path (assumes `x86_64`,
  consistent with the current `go.yaml`). Flagged as a follow-up; per-tool arch
  maps are intentionally not built in the pilot. macOS arm64 is handled by brew.
- Release-binary version bumps are not auto-detected (see Idempotency).

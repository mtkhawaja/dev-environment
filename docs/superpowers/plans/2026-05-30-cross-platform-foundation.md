# Cross-platform Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `dev-environment` provisionable on macOS, Linux, and WSL via OS-branching (apt on Debian/WSL, Homebrew on macOS), proven by a pilot `modern-cli.yaml` task.

**Architecture:** A single Ansible play (`local.yaml`) imports per-area task files. Tasks branch on `ansible_facts.os_family` (`Debian` vs `Darwin`). Shared version pins / per-OS package data live in `src/ansible/vars/main.yml`. `setup.sh` bootstraps Ansible per-OS before invoking `ansible-pull`.

**Tech Stack:** Ansible (ansible-core + `community.general`), Bash, Homebrew (macOS), apt (Debian/WSL), Docker (`ubuntu:noble`) as the Linux test harness.

**Testing note:** Ansible provisioning is verified via `ansible-playbook --syntax-check` per task and a Docker integration run at the end, not classic unit tests. The macOS branch is verified by a manual local run (no containerization possible).

**Spec:** `docs/superpowers/specs/2026-05-30-cross-platform-foundation-design.md`

---

## File Structure

- `requirements.yml` (create) — declares the `community.general` collection.
- `src/ansible/vars/main.yml` (create) — version pins + per-OS package data for modern CLI tools. Sole home for shared cross-platform config.
- `src/ansible/tasks/modern-cli.yaml` (create) — pilot task; macOS (brew) + Debian (apt/.deb/release-binary) branches.
- `local.yaml` (modify) — add `vars_files` and the `modern-cli.yaml` import.
- `setup.sh` (modify) — OS-branching bootstrap (Darwin: Homebrew+Ansible; Linux: existing apt/PPA) + collection install.

---

## Task 1: Versions, vars file, and collection requirements

**Files:**
- Create: `requirements.yml`
- Create: `src/ansible/vars/main.yml`
- Modify: `local.yaml` (add `vars_files`)

- [ ] **Step 1: Resolve current stable versions and confirm asset names**

The release-binary asset names differ per project, so confirm both the version and the exact Linux asset filename before pinning.

Run:
```bash
for repo in dandavison/delta jesseduffield/lazygit bootandy/dust dalance/procs chmln/sd; do
  echo "== $repo =="
  curl -fsSL "https://api.github.com/repos/$repo/releases/latest" \
    | grep -E '"tag_name"|"name": ".*(amd64|x86_64|Linux|linux).*(deb|tar\.gz|zip)"'
done
```
Expected: a `tag_name` (e.g. `"0.18.2"` or `"v0.44.2"`) and matching asset names per repo. Record the bare version (strip a leading `v`) for each tool and confirm the asset filename patterns used in Step 2.

- [ ] **Step 2: Create `src/ansible/vars/main.yml`**

Substitute the five version strings resolved in Step 1. If any asset filename differs from the patterns below, update that item's `url`.

```yaml
---
# Shared cross-platform configuration. Loaded by local.yaml via vars_files.

modern_cli_versions:
  delta: "0.18.2"     # confirm via Step 1
  lazygit: "0.44.2"   # confirm via Step 1
  dust: "1.1.1"       # confirm via Step 1
  procs: "0.14.6"     # confirm via Step 1
  sd: "1.0.0"         # confirm via Step 1

modern_cli:
  # macOS: install everything through Homebrew (handles arch automatically).
  brew_formulae:
    - git-delta
    - lazygit
    - dust
    - duf
    - procs
    - sd
    - hyperfine

  # Debian/WSL: tools reliably packaged in Ubuntu Noble universe.
  apt_packages:
    - hyperfine
    - duf

  # Debian/WSL: delta installed from an upstream .deb release.
  delta_deb_url: "https://github.com/dandavison/delta/releases/download/{{ modern_cli_versions.delta }}/git-delta_{{ modern_cli_versions.delta }}_amd64.deb"

  # Debian/WSL: release binaries extracted into ~/.local/bin (x86_64 only).
  # extra_opts handles each archive's layout: tarballs with a nested dir use
  # --strip-components=1; zips with files at root use -j; lazygit's tarball is flat.
  release_binaries:
    - name: lazygit
      url: "https://github.com/jesseduffield/lazygit/releases/download/v{{ modern_cli_versions.lazygit }}/lazygit_{{ modern_cli_versions.lazygit }}_Linux_x86_64.tar.gz"
      extra_opts: []
    - name: dust
      url: "https://github.com/bootandy/dust/releases/download/v{{ modern_cli_versions.dust }}/dust-v{{ modern_cli_versions.dust }}-x86_64-unknown-linux-gnu.tar.gz"
      extra_opts: ["--strip-components=1"]
    - name: sd
      url: "https://github.com/chmln/sd/releases/download/v{{ modern_cli_versions.sd }}/sd-v{{ modern_cli_versions.sd }}-x86_64-unknown-linux-gnu.tar.gz"
      extra_opts: ["--strip-components=1"]
    - name: procs
      url: "https://github.com/dalance/procs/releases/download/v{{ modern_cli_versions.procs }}/procs-v{{ modern_cli_versions.procs }}-x86_64-linux.zip"
      extra_opts: ["-j"]
```

- [ ] **Step 3: Create `requirements.yml`**

```yaml
---
collections:
  - name: community.general
```

- [ ] **Step 4: Wire `vars_files` into `local.yaml`**

Modify the play header so it reads:

```yaml
- hosts: localhost
  connection: local
  vars_files:
    - src/ansible/vars/main.yml
  pre_tasks:
    - import_tasks: src/ansible/tasks/pre_tasks.yaml
    - import_tasks: src/ansible/tasks/directories.yaml

  tasks:
    - import_tasks: src/ansible/tasks/zsh.yaml
    - import_tasks: src/ansible/tasks/dotfiles.yaml
    - import_tasks: src/ansible/tasks/tools.yaml
    - import_tasks: src/ansible/tasks/sdkman.yaml
    - import_tasks: src/ansible/tasks/neovim.yaml
    - import_tasks: src/ansible/tasks/java.yaml
    - import_tasks: src/ansible/tasks/js.yaml
    - import_tasks: src/ansible/tasks/bitwarden-cli.yaml
    - import_tasks: src/ansible/tasks/python.yaml
    - import_tasks: src/ansible/tasks/yazi.yaml
    - import_tasks: src/ansible/tasks/go.yaml
```

(The `modern-cli.yaml` import is added in Task 3 — keeping these changes separate so the syntax-check in this task passes without the not-yet-created file.)

- [ ] **Step 5: Verify the vars load and the playbook parses**

Run:
```bash
ansible-playbook --syntax-check local.yaml
```
Expected: `playbook: local.yaml` with no errors. (If `community.general` is missing, this still passes — `--syntax-check` does not require modules.)

- [ ] **Step 6: Commit**

```bash
git add requirements.yml src/ansible/vars/main.yml local.yaml
git commit -m "feat: add cross-platform vars file and community.general requirement"
```

---

## Task 2: Cross-platform `setup.sh` bootstrap

**Files:**
- Modify: `setup.sh` (full rewrite of the OS-specific section; logging helpers preserved)

- [ ] **Step 1: Rewrite `setup.sh`**

The current script assumes apt and does a `sudo` precheck before anything. macOS uses Homebrew (which must NOT run as root) and has no `sudo` precheck need, so the `sudo` check moves inside the Linux branch. Replace the file contents with:

```bash
#!/usr/bin/env bash

set -e
set -o pipefail

LOG_DIR="${HOME}/.ansible-dev-env-bootstrap"
mkdir -p "$LOG_DIR"
LOGFILE="${LOG_DIR}/$(date +%Y%m%d-%H%M%S).log"

log() {
  local level=$1
  local message=$2
  echo "[$(date +"%Y-%m-%d %H:%M:%S")] [${level}] $message" | tee -a "$LOGFILE"
}

REPO_URL="https://github.com/mtkhawaja/dev-environment.git"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log "INFO" "Saving logs to: $LOGFILE"
log "INFO" "Starting Ansible bootstrap script"

OS="$(uname -s)"
log "INFO" "Detected OS: $OS"

install_ansible_macos() {
  if ! command -v brew >/dev/null 2>&1; then
    log "INFO" "Homebrew not found; installing Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
      || { log "ERROR" "Failed to install Homebrew"; exit 1; }
    if [[ -x /opt/homebrew/bin/brew ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  fi
  log "INFO" "Installing Ansible via Homebrew"
  brew install ansible || { log "ERROR" "Failed to install Ansible via Homebrew"; exit 1; }
}

install_ansible_linux() {
  if [[ $EUID -ne 0 ]] && ! sudo -n true 2>/dev/null; then
    log "ERROR" "This script must be run with sudo privileges on Linux"
    exit 1
  fi
  log "INFO" "Updating package lists"
  sudo apt update || { log "ERROR" "Failed to update package lists"; exit 1; }
  log "INFO" "Installing software-properties-common"
  sudo apt install -y software-properties-common || { log "ERROR" "Failed to install software-properties-common"; exit 1; }
  log "INFO" "Adding Ansible repository"
  sudo add-apt-repository --yes --update ppa:ansible/ansible || { log "ERROR" "Failed to add Ansible repository"; exit 1; }
  log "INFO" "Installing Ansible"
  sudo apt install -y ansible || { log "ERROR" "Failed to install Ansible"; exit 1; }
}

case "$OS" in
  Darwin) install_ansible_macos ;;
  Linux)  install_ansible_linux ;;
  *) log "ERROR" "Unsupported OS: $OS"; exit 1 ;;
esac

if ! command -v ansible >/dev/null 2>&1; then
  log "ERROR" "Ansible installation failed or not found in PATH"
  exit 1
fi

ansible_version=$(ansible --version | head -n 1)
log "INFO" "Successfully installed: $ansible_version"

log "INFO" "Installing required Ansible collections"
if [[ -f "${SCRIPT_DIR}/requirements.yml" ]]; then
  ansible-galaxy collection install -r "${SCRIPT_DIR}/requirements.yml" \
    || { log "ERROR" "Failed to install Ansible collections"; exit 1; }
else
  ansible-galaxy collection install community.general \
    || { log "ERROR" "Failed to install community.general"; exit 1; }
fi

log "INFO" "Running ansible-pull to configure the system"
ansible-pull -U "$REPO_URL" -i localhost, local.yaml || {
  log "ERROR" "ansible-pull failed"
  exit 1
}

log "INFO" "Bootstrap completed successfully"
log "INFO" "Log file saved to: $LOGFILE"
```

- [ ] **Step 2: Verify the script parses**

Run:
```bash
bash -n setup.sh && echo "syntax OK"
```
Expected: `syntax OK`. If `shellcheck` is installed, also run `shellcheck setup.sh` and resolve any errors (warnings are acceptable).

- [ ] **Step 3: Commit**

```bash
git add setup.sh
git commit -m "feat: make setup.sh bootstrap cross-platform (macOS Homebrew + Linux apt)"
```

---

## Task 3: Pilot `modern-cli.yaml` and wire it in

**Files:**
- Create: `src/ansible/tasks/modern-cli.yaml`
- Modify: `local.yaml` (add the import line)

- [ ] **Step 1: Create `src/ansible/tasks/modern-cli.yaml`**

```yaml
---
# Modern CLI tools. Cross-platform pilot:
#   macOS  -> Homebrew (all formulae)
#   Debian -> apt (hyperfine, duf) + delta .deb + release binaries (lazygit, dust, sd, procs)

# ---------- macOS ----------
- name: "Install modern CLI tools (macOS)"
  community.general.homebrew:
    name: "{{ modern_cli.brew_formulae }}"
    state: present
  when: ansible_facts.os_family == "Darwin"
  tags:
    - modern-cli

# ---------- Debian / WSL ----------
- name: "Install modern CLI tools available via apt (Debian)"
  become: true
  ansible.builtin.apt:
    name: "{{ modern_cli.apt_packages }}"
    state: present
    update_cache: true
  when: ansible_facts.os_family == "Debian"
  tags:
    - modern-cli

- name: "Download delta .deb (Debian)"
  ansible.builtin.get_url:
    url: "{{ modern_cli.delta_deb_url }}"
    dest: "/tmp/git-delta_{{ modern_cli_versions.delta }}_amd64.deb"
    mode: '0644'
  when: ansible_facts.os_family == "Debian"
  tags:
    - modern-cli
    - delta

- name: "Install delta from .deb (Debian)"
  become: true
  ansible.builtin.apt:
    deb: "/tmp/git-delta_{{ modern_cli_versions.delta }}_amd64.deb"
    state: present
  when: ansible_facts.os_family == "Debian"
  tags:
    - modern-cli
    - delta

- name: "Remove delta .deb (Debian)"
  ansible.builtin.file:
    path: "/tmp/git-delta_{{ modern_cli_versions.delta }}_amd64.deb"
    state: absent
  when: ansible_facts.os_family == "Debian"
  tags:
    - modern-cli
    - delta

- name: "Ensure unzip is available for .zip release archives (Debian)"
  become: true
  ansible.builtin.apt:
    name: unzip
    state: present
  when: ansible_facts.os_family == "Debian"
  tags:
    - modern-cli

- name: "Ensure ~/.local/bin exists (Debian)"
  ansible.builtin.file:
    path: "{{ ansible_env.HOME }}/.local/bin"
    state: directory
    mode: '0755'
  when: ansible_facts.os_family == "Debian"
  tags:
    - modern-cli

- name: "Install release-binary modern CLI tools (Debian)"
  ansible.builtin.unarchive:
    src: "{{ item.url }}"
    dest: "{{ ansible_env.HOME }}/.local/bin"
    remote_src: true
    extra_opts: "{{ item.extra_opts }}"
    creates: "{{ ansible_env.HOME }}/.local/bin/{{ item.name }}"
  loop: "{{ modern_cli.release_binaries }}"
  when: ansible_facts.os_family == "Debian"
  tags:
    - modern-cli

- name: "Ensure release binaries are executable (Debian)"
  ansible.builtin.file:
    path: "{{ ansible_env.HOME }}/.local/bin/{{ item.name }}"
    mode: '0755'
    state: file
  loop: "{{ modern_cli.release_binaries }}"
  when: ansible_facts.os_family == "Debian"
  tags:
    - modern-cli
```

- [ ] **Step 2: Add the import to `local.yaml`**

Append to the `tasks:` list (after `go.yaml`):

```yaml
    - import_tasks: src/ansible/tasks/go.yaml
    - import_tasks: src/ansible/tasks/modern-cli.yaml
```

- [ ] **Step 3: Verify the playbook parses with the new task**

Run:
```bash
ansible-playbook --syntax-check local.yaml
```
Expected: `playbook: local.yaml` with no errors.

- [ ] **Step 4: Commit**

```bash
git add src/ansible/tasks/modern-cli.yaml local.yaml
git commit -m "feat: add cross-platform modern-cli pilot task (delta, lazygit, dust, duf, procs, sd, hyperfine)"
```

---

## Task 4: Linux integration test (Docker, Ubuntu Noble)

**Files:** none (verification only; commit any fixes discovered).

- [ ] **Step 1: Build the image targeting only the modern-cli tag**

Run:
```bash
docker build --build-arg TAGS="--tags modern-cli" -t mtkhawaja/dev-env:modern-cli .
```
On **Apple Silicon** add `--platform linux/amd64` — the x86_64 release-binary
path (and the `amd64` delta `.deb`) will fail on the default arm64 build:
```bash
docker build --platform linux/amd64 --build-arg TAGS="--tags modern-cli" -t mtkhawaja/dev-env:modern-cli .
```
Expected: build succeeds; the modern-cli tasks report `ok`/`changed`, no failed tasks. (`community.general` is bundled with the apt `ansible` package installed in the Dockerfile, so the `homebrew` task parses but is skipped via its `when`.)

- [ ] **Step 2: Verify every tool resolves and reports a version**

Run:
```bash
docker run --rm mtkhawaja/dev-env:modern-cli -lc '
  set -e
  for t in hyperfine duf delta; do command -v "$t" && "$t" --version; done
  for t in lazygit dust sd procs; do "$HOME/.local/bin/$t" --version; done
'
```
Expected: each command prints a version string with no "command not found" / non-zero exit. (`delta` is on `PATH` from the .deb; `hyperfine`/`duf` from apt; the four release binaries live in `~/.local/bin`.)

- [ ] **Step 3: Verify idempotency**

Run a second build with no cache for the playbook layer:
```bash
docker build --no-cache --build-arg TAGS="--tags modern-cli" -t mtkhawaja/dev-env:modern-cli .
```
Expected: the release-binary `unarchive` tasks report `ok` (skipped via `creates:`), `apt`/`.deb` tasks report `ok` (already present). Note the documented caveat: a version bump in `vars/main.yml` requires removing the old binary to re-fetch.

- [ ] **Step 4: If fixes were needed, commit them**

```bash
git add -A
git commit -m "fix: corrections from modern-cli Linux integration test"
```

---

## Task 5: macOS verification (manual, on a Mac)

**Files:** none (verification only).

> This task runs on a macOS machine; it cannot be containerized. If no Mac is available now, mark it deferred and record it as a release-blocking check before SP1 is considered done.

- [ ] **Step 1: Install collection and run the tagged playbook locally**

Run (from a clone of the repo on macOS, with Ansible installed via `brew install ansible`):
```bash
ansible-galaxy collection install -r requirements.yml
ansible-playbook --tags modern-cli local.yaml
```
Expected: the macOS Homebrew task reports `ok`/`changed`; Debian tasks are skipped via `when`.

- [ ] **Step 2: Verify the tools**

Run:
```bash
for t in delta lazygit dust duf procs sd hyperfine; do command -v "$t" && "$t" --version; done
```
Expected: every tool resolves and prints a version (note: the Homebrew formula `git-delta` installs the `delta` binary).

- [ ] **Step 3: Verify idempotency**

Run `ansible-playbook --tags modern-cli local.yaml` again.
Expected: the Homebrew task reports `ok` (no changes).

---

## Self-Review

**Spec coverage:**
- OS-detection convention (`os_family`) → Task 1 (vars wiring) + Task 3 (`when:` on every task). ✓
- Shared vars file (`src/ansible/vars/main.yml` via `vars_files`) → Task 1. ✓
- Cross-platform `setup.sh` bootstrap (Darwin/Linux + collection install) → Task 2. ✓
- `requirements.yml` / `community.general` → Tasks 1–2. ✓
- Pilot `modern-cli.yaml` (all seven tools, macOS brew + Debian hybrid) → Task 3. ✓
- Wiring into `local.yaml` → Tasks 1 (vars) and 3 (import). ✓
- Linux test via Docker `--tags modern-cli` + idempotency → Task 4. ✓
- macOS local verification → Task 5. ✓
- Known limitations (x86_64-only, version-bump caveat) → reflected in vars comments + Task 4 Step 3. ✓

**Placeholder scan:** Version strings carry "confirm via Step 1" notes and are resolved by an executable command (Task 1 Step 1) — concrete mechanism, not a TBD. No other placeholders.

**Type/name consistency:** Var names used consistently across tasks — `modern_cli.brew_formulae`, `modern_cli.apt_packages`, `modern_cli.delta_deb_url`, `modern_cli.release_binaries` (each item `{name, url, extra_opts}`), and `modern_cli_versions.<tool>`. The delta `.deb` filename in the download/install/remove steps all use `git-delta_{{ modern_cli_versions.delta }}_amd64.deb`. ✓

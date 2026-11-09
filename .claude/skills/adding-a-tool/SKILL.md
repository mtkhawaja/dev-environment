---
name: adding-a-tool
description: Use when adding a new CLI tool, package, language runtime, or binary to this dev-environment Ansible repo — ensures the install works on BOTH macOS (Homebrew) and Debian/Ubuntu/WSL (apt), follows repo conventions, and never silently becomes Linux-only.
---

# Adding a Tool

## Core principle

**Every tool must install on both macOS and Debian/Ubuntu/WSL.** A task that only runs on one OS is a bug, not a
feature. Every existing task file already branches per-OS — follow that pattern (`modern-cli.yaml`, `tools.yaml`,
`yazi.yaml` are good models). Branch on `ansible_facts.os_family`: `"Darwin"` → Homebrew, `"Debian"` → apt / `.deb` /
release binary.

## Procedure

1. **Find the package name on each platform** and the latest stable version. macOS uses the Homebrew formula name (e.g.
   `git-delta`), Debian may differ or not exist in apt at all.
2. **Add config to `src/ansible/vars/main.yml`** — never inline package data in the task. Put brew formulae, apt package
   names, `.deb` URLs, and release-binary entries under a named key (see `modern_cli`).
3. **Write/extend a task file in `src/ansible/tasks/`** with OS-branched tasks (pattern below).
4. **Wire it into `local.yaml`** with an `import_tasks` line (only if it's a new file).
5. **Tag every task** — a broad tag (`initial-setup`) plus an area tag (e.g. `modern-cli`). This is how partial runs and
   the Docker `TAGS` arg work.
6. **Verify in Docker**, not on your real machine (see Verification).

## Choosing the Debian install method

macOS is always Homebrew. For Debian, pick the first that works, in this order:

```dot
digraph debian_install {
    rankdir=TB;
    apt [shape=diamond, label="In apt (Ubuntu Resolute)\nat an acceptable version?"];
    use_apt [shape=box, label="apt_packages (preferred)"];
    deb [shape=diamond, label="Upstream ships a .deb?"];
    use_deb [shape=box, label="get_url -> apt deb: -> remove .deb"];
    use_rel [shape=box, label="Release tarball/zip -> unarchive\ninto ~/.local/bin (arch via linux_arch/deb_arch)"];

    apt -> use_apt [label="yes"];
    apt -> deb [label="no"];
    deb -> use_deb [label="yes"];
    deb -> use_rel [label="no"];
}
```

## Task pattern

```yaml
# macOS
- name: "Install <tool> (macOS)"
  community.general.homebrew:
    name: "{{ mytool.brew_formulae }}"
    state: present
  when: ansible_facts.os_family == "Darwin"
  tags: [ initial-setup, <area> ]

# Debian: apt
- name: "Install <tool> via apt (Debian)"
  become: true
  ansible.builtin.apt:
    name: "{{ mytool.apt_packages }}"
    state: present
    update_cache: true
  when: ansible_facts.os_family == "Debian"
  tags: [ initial-setup, <area> ]
```

For release binaries on Debian, follow `tflint.yaml` / `neovim.yaml` (stylua): ensure `~/.local/bin` exists (already on PATH), `unarchive`
with per-asset `extra_opts` to normalize layout (`--strip-components=1` for nested tarballs, `-j` for flat zips), set
the binary executable, and use `creates:` for idempotency. Build the URL with `{{ linux_arch }}` (`x86_64`/`aarch64`)
or `{{ deb_arch }}` (`amd64`/`arm64`) so it works on both architectures. For `.zip` assets, `unzip` must be installed first.

## Versions: always latest, never pinned

Install the **latest release at install time**; do not pin versions. In order of preference:

1. Package managers unpinned (`state: present`).
2. A version-free download URL: GitHub's `https://github.com/<owner>/<repo>/releases/latest/download/<asset>` works
   whenever the asset name has no version in it (see `tflint`, `neovim.release_binaries`), or a vendor redirect
   endpoint (JetBrains Toolbox).
3. A runtime "latest" lookup when the URL must contain the version: a vendor version endpoint (go.dev `VERSION`,
   SonarQube `stable.version`), GitHub's web redirect `https://github.com/<owner>/<repo>/releases/latest` (read the
   tag from the `302` `location`; see `js.yaml`), a package registry (npm, see `bitwarden-cli.yaml`), or a vendor
   index + `community.general.version_sort` (see `java.yaml`). Gate lookups on the tool not being installed.
   **Do not use the GitHub REST API (`api.github.com`)**: anonymous calls are limited to 60/hour per IP, and shared CI
   runners and NAT'd networks exhaust that (it broke the macOS CI job).

Re-runs don't upgrade; `creates:` / stat guards keep them idempotent. Pin only if upstream offers no way to get the
latest, and explain why in a comment.

## Guardrails

| Guardrail                                                         | Why                                                                          |
|-------------------------------------------------------------------|------------------------------------------------------------------------------|
| Branch on `os_family` for every install task                      | A bare apt task silently breaks macOS; this is the #1 mistake here.          |
| Package data → `vars/main.yml`, not inline                        | Single source of truth the whole migration reuses.                           |
| Clean up downloads (`.deb`, installers, temp) in a follow-up task | Matches existing tasks (`common/install-script.yaml`).                      |
| Make tasks idempotent (`creates:`, `when: ... is changed`)        | The playbook is re-run often; second run must be a no-op.                    |
| Tag everything                                                    | Enables `--tags <area>` scoped runs and Docker `TAGS`.                       |
| Linux release URLs use `linux_arch` / `deb_arch`                  | Hosts may be x86_64 or arm64; never hardcode one arch.                       |
| `ansible-lint` passes                                             | Blocking in CI; FQCNs; install scripts via `common/install-script.yaml`.     |
| Third-party Homebrew taps: `homebrew_tap` + `brew trust`            | Homebrew no longer auto-taps or loads untrusted tap formulae (see `acli.yaml`). |
| New collections → `requirements.yml`                              | `community.general` (Homebrew module) is installed from there by `setup.sh`. |

## Verification

```bash
# Scoped local run (safe-ish) — NOT a bare full run (that reinstalls ~/.oh-my-zsh and force-resets ~/.dotfiles)
ansible-playbook -i localhost, local.yaml --tags <area>

# Full end-to-end on a throwaway Ubuntu container
docker build --build-arg TAGS="--tags <area>" -t mtkhawaja/dev-env:latest .
```

A second run with the same tags must report `changed=0` (idempotent). To prove macOS works, run the scoped playbook on a
Mac — the Docker image only covers the Debian branch.

## Common mistakes

- **Writing an apt-only task** — forgetting the `Darwin` branch. Every install task needs both OSes.
- **Pinning a version** when a `releases/latest/download` URL or a runtime "latest" lookup would work.
- **Hardcoding a package name/URL in the task** instead of `vars/main.yml`.
- **Forgetting `unzip`** before a `.zip` release archive on Debian, or omitting `extra_opts` so the binary lands in a
  nested dir off PATH.
- **Skipping cleanup**, leaving `.deb`/temp files behind.
- **Reaching for a release binary when apt/brew has the tool** — a release binary is the *last* resort;
  check apt (Debian) first, even if it lags upstream a little.
- **Assuming install == activation** — some tools (e.g. `zoxide`, `fzf`, `direnv`) need a shell-init hook (
  `eval "$(zoxide init zsh)"`) to do anything. Shell config lives in the **separate `mtkhawaja/dotfiles` repo**, not
  here; this repo only installs the binary. Note the dotfiles follow-up when the tool needs one.

# dev-environment

Reproducible, Ansible-driven setup for a personal development machine — shell, dotfiles, CLI tools, editors, and language runtimes — applied to the local host with a single command.

See **[docs/CATALOG.md](./docs/CATALOG.md)** for the full list of tools that get installed, what each one is, and why it's useful.

## Platform support

| Platform | Status |
|----------|--------|
| Ubuntu / Debian | Supported (the original target) |
| WSL (Ubuntu) | Supported (same apt path) |
| macOS (Apple Silicon) | Supported — every task installs via Homebrew on the Darwin branch; verified by the `macos` CI job |
| Windows (native) | Use WSL or the Docker image below |

## Try it in a throwaway container

The safest way to see a full run without touching your own machine:

```bash
docker build -t mtkhawaja/dev-env:latest . && docker run -it --rm mtkhawaja/dev-env:latest
```

On Windows (PowerShell):

```powershell
docker build -t mtkhawaja/dev-env:latest . ; if ($?) { docker run -it --rm mtkhawaja/dev-env:latest }
```

`./run_docker.sh` is a shortcut for the build-and-run above.

## Set up a real machine

> **Warning:** A full run modifies your home directory — it replaces `~/.zshrc`, `~/.zshenv`, and `~/.oh-my-zsh`, and force-overwrites `~/.dotfiles`. Try it in the Docker container first.

Run the [convenience script](./setup.sh), which detects your OS, installs Ansible (Homebrew on macOS, the Ansible PPA on Linux), installs the required collections, and then runs the playbook:

```bash
curl -s https://raw.githubusercontent.com/mtkhawaja/dev-environment/main/setup.sh | bash
```

Bootstrap logs are written to `~/.ansible-dev-env-bootstrap/`.

### Manual install (Linux)

```bash
# Install Ansible
sudo apt update
sudo apt install -y software-properties-common
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt install -y ansible

# Run the playbook directly from this repo
ansible-pull -U https://github.com/mtkhawaja/dev-environment.git -i localhost, local.yaml
```

## Iterating on the playbook

With Ansible already installed, run against the local host from a checkout:

```bash
ansible-galaxy collection install -r requirements.yml   # one-time: community.general
ansible-playbook -i localhost, local.yaml               # full run
ansible-playbook -i localhost, local.yaml --tags modern-cli   # run one area only
```

Every task is tagged (a broad `initial-setup` plus an area tag like `zsh`, `python`, `modern-cli`), so `--tags` lets you run or re-run a single area. A second run with the same tags should report `changed=0`.

## How it works

`local.yaml` is the single play and entry point: it loads shared variables from `src/ansible/vars/main.yml`, runs pre-tasks (base packages, directories), then imports one task file per area from `src/ansible/tasks/`. Adding a new area means adding a task file there and an `import_tasks` line in `local.yaml`. Dotfiles live in a separate repo ([`mtkhawaja/dotfiles`](https://github.com/mtkhawaja/dotfiles)) and are applied with GNU Stow.

Contributors: see [CLAUDE.md](./CLAUDE.md) for repo conventions and `.claude/skills/adding-a-tool/` for the cross-platform tool-install guide.

## References

- [Developer Productivity](https://frontendmasters.com/courses/developer-productivity/introduction/)
- [dev-productivity](https://github.com/ThePrimeagen/dev-productivity)
- [Explain DEBIAN_FRONTEND apt-get variable for Ubuntu / Debian](https://www.cyberciti.biz/faq/explain-debian_frontend-apt-get-variable-for-ubuntu-debian)
- [Ansible Pull Arguments playbook.yml](https://docs.ansible.com/ansible/latest/cli/ansible-pull.html#cmdoption-ansible-pull-arg-playbook.yml)
- [Ansible Installation](https://docs.ansible.com/ansible/latest/installation_guide/installation_distros.html#installing-ansible-on-ubuntu)

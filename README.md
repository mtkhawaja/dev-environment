# dev-environment

Reproducible, Ansible-driven setup for a personal development machine — shell, dotfiles, CLI tools, editors, and language runtimes — applied to the local host with a single command.

See **[docs/CATALOG.md](./docs/CATALOG.md)** for the full list of tools that get installed, what each one is, and why it's useful.

## Platform support

| Environment | Status |
|-------------|--------|
| macOS (Apple Silicon) | Supported — everything installs via Homebrew; verified by the `macos` CI job |
| Ubuntu 26.04 LTS (Resolute) with a desktop | Supported, x86_64 and arm64 |
| Ubuntu 26.04 LTS server / headless | Supported, x86_64 and arm64 — `HEADLESS=true` |
| WSL (Ubuntu 26.04) | Supported — desktop flavor with WSLg, otherwise headless |
| Windows (native) | Use WSL or the Docker image below |

Versions are never pinned: every tool installs the latest release available at install time.

## Set up a machine

> **Warning:** A full run modifies your home directory. It reinstalls `~/.oh-my-zsh`, force-resets `~/.dotfiles` to
> `origin/main` of the [dotfiles repo](https://github.com/mtkhawaja/dotfiles) (push any local dotfiles commits first),
> and stows them over `~/.zshrc`, `~/.zshenv` and friends. Try it in the Docker container first.

All three environments use the same bootstrap script, [`setup.sh`](./setup.sh): it installs Ansible (Homebrew on
macOS, the Ansible PPA on Linux) and the required collections, then runs the playbook with `ansible-pull` straight
from this repo's `main` branch on GitHub. Download it and run it from a terminal (rather than piping it into `bash`)
so installers can prompt for your password. Logs go to `~/.ansible-dev-env-bootstrap/`.

| | macOS | Linux desktop | Linux server / headless |
|---|---|---|---|
| CLI tools, shell, dotfiles, editors, runtimes | ✅ | ✅ | ✅ |
| GUI apps (Ghostty, VLC, JetBrains Toolbox; AeroSpace and bloom on macOS) | ✅ | ✅ | — |
| Desktop-only packages (`fonts-powerline`) | n/a | ✅ | — |
| Headless browser testing (Google Chrome, fonts, `xvfb`) | — (not managed) | ✅ | ✅ |
| OpenSSH client | built in | ✅ | ✅ |
| OpenSSH server, hardened (opt-in: `ssh-server.yaml`) | — (never) | opt-in | opt-in |

### macOS (Apple Silicon)

```bash
curl -fsSL https://raw.githubusercontent.com/mtkhawaja/dev-environment/main/setup.sh -o setup.sh && bash setup.sh
```

- Installs Homebrew first if it's missing (the Homebrew installer asks for your password).
- Everything installs through Homebrew formulae and casks. Apps already in `/Applications` are adopted when the
  versions match; JetBrains Toolbox is left alone if it's already installed.
- Browsers / browser-testing are intentionally not managed on macOS.

### Linux with a desktop (Ubuntu 26.04)

```bash
curl -fsSL https://raw.githubusercontent.com/mtkhawaja/dev-environment/main/setup.sh -o setup.sh && sudo -v && bash setup.sh
```

- Needs sudo. `setup.sh` checks with `sudo -n true`, so authenticate first (`sudo -v`) or use passwordless sudo.
- Installs the CLI tooling plus the GUI apps (Ghostty, VLC, JetBrains Toolbox), `xclip`, Powerline fonts, and Google
  Chrome for browser tests. Works on x86_64 and arm64.

### Linux server / headless (Ubuntu 26.04, no desktop)

```bash
curl -fsSL https://raw.githubusercontent.com/mtkhawaja/dev-environment/main/setup.sh -o setup.sh && sudo -v && HEADLESS=true bash setup.sh
```

- `HEADLESS=true` skips GUI apps (Ghostty, VLC, JetBrains Toolbox) and desktop-only packages (`fonts-powerline`).
  `xclip` isn't installed directly, but Neovim and Yazi still pull it in as a recommended package (harmless: Chrome
  brings the same X11 libraries).
- Still sets up headless, Chrome-based Playwright and Selenium tests: Google Chrome stable (which brings the shared
  libraries browsers need), fonts, and `xvfb` for tests that must run headed (`xvfb-run -a <cmd>`). Projects then only
  need their own sudo-free step, e.g. `npx playwright install chromium`; Selenium Manager fetches a matching
  chromedriver. Inside Docker, Chrome's sandbox needs `--no-sandbox` (Playwright's default) or
  `--security-opt seccomp=unconfined`. See [docs/CATALOG.md](./docs/CATALOG.md#headless-browser-testing-linux-only).

### Optional: SSH server (Linux)

The regular install only adds the SSH client. To accept SSH logins, run the separate `ssh-server.yaml` playbook: it
installs OpenSSH already hardened, as one step. It's never run by `setup.sh` or `local.yaml`:

```bash
ansible-pull -U https://github.com/mtkhawaja/dev-environment.git -i localhost, -K \
  -e ssh_authorized_keys=https://github.com/<user>.keys ssh-server.yaml
ansible-playbook -i localhost, -K -e ssh_authorized_keys=https://github.com/<user>.keys ssh-server.yaml   # from a checkout
```

In order, it:

1. authorizes the key(s) you pass (a key line, or a URL like `https://github.com/<user>.keys`); this is optional if
   `~/.ssh/authorized_keys` already has a key,
2. refuses to continue, installing nothing, if there's still no key, so the server never runs with password logins,
3. writes `/etc/ssh/sshd_config.d/10-dev-env-hardening.conf` (no password, keyboard-interactive, or root logins; it
   wins over cloud-init's `50-cloud-init.conf`) *before* installing `openssh-server`, so `sshd` is hardened from its
   first start, then validates with `sshd -t`; on failure it stops and disables the server (fails closed),
4. enables the socket-activated server (`ssh.socket`, port 22) and reloads `sshd` if it's running.

### Optional: Tailscale (Linux)

Not installed by default. Install it when a machine needs it, either standalone or as part of a normal run:

```bash
ansible-pull -U https://github.com/mtkhawaja/dev-environment.git -i localhost, -K tailscale.yaml   # standalone
ansible-playbook -i localhost, -K tailscale.yaml                                                  # standalone, from a checkout
ansible-playbook -i localhost, -K -e tailscale=true local.yaml                                     # with a normal run
```

It adds Tailscale's official apt repo, installs `tailscale`, and enables `tailscaled`. To join your tailnet
automatically, export an auth key first (`export TS_AUTHKEY=tskey-auth-...`; it's read from the environment and never
logged); otherwise run `sudo tailscale up` afterwards. Extra `tailscale up` flags go in
`-e tailscale_up_args="--ssh --advertise-tags=tag:server"`.

### Without `setup.sh`

With Ansible already installed, run the playbook from GitHub (`ansible-pull`) or from a checkout (`ansible-playbook`,
which uses your local changes). `-K` asks for your sudo password up front on Linux; macOS doesn't need it.

```bash
ansible-galaxy collection install -r requirements.yml   # one-time: community.general

# from GitHub
ansible-pull -U https://github.com/mtkhawaja/dev-environment.git -i localhost, local.yaml            # macOS
ansible-pull -U https://github.com/mtkhawaja/dev-environment.git -i localhost, -K local.yaml         # Linux desktop
ansible-pull -U https://github.com/mtkhawaja/dev-environment.git -i localhost, -K -e headless=true local.yaml  # Linux server

# from a checkout
ansible-playbook -i localhost, local.yaml                       # macOS
ansible-playbook -i localhost, -K local.yaml                    # Linux desktop
ansible-playbook -i localhost, -K -e headless=true local.yaml   # Linux server
```

To install Ansible by hand on Ubuntu: `sudo apt install -y software-properties-common && sudo add-apt-repository
--yes --update ppa:ansible/ansible && sudo apt install -y ansible`.

## Try it in a throwaway container

The safest way to see a full Linux run without touching your own machine:

```bash
docker build -t mtkhawaja/dev-env:latest . && docker run -it --rm mtkhawaja/dev-env:latest
docker build --build-arg TAGS="-e headless=true" -t mtkhawaja/dev-env:headless .   # server / headless flavor
```

On Windows (PowerShell):

```powershell
docker build -t mtkhawaja/dev-env:latest . ; if ($?) { docker run -it --rm mtkhawaja/dev-env:latest }
```

`./run_docker.sh` is a shortcut for the first build-and-run. The image is x86_64 or arm64 to match your host. On Apple
Silicon, build natively (the default): under amd64 emulation, Ubuntu 26.04's `tar` fails to create directories.

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

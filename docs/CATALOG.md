# Tool Catalog

Everything this repo installs when you provision a machine, grouped by purpose, with a one-line "what" and "why". This
is generated from the Ansible task files in `src/ansible/tasks/` — when you add or remove a tool, update this list too.

**Platform note:** every tool below installs on **both macOS (Apple Silicon, via Homebrew) and Debian / Ubuntu / WSL
(Ubuntu 26.04, x86_64 or arm64, via apt + a few release binaries)** — the cross-platform migration is complete. Each task branches on
`ansible_facts.os_family`. A few macOS substitutes apply where the Linux tool is platform-specific: `xclip` →
`pbcopy`/`pbpaste` (built in), and `tofrodos` → `dos2unix`.

**Versions:** nothing is pinned. Each tool installs the latest release available at install time; re-runs don't
upgrade (self-updating tools such as JetBrains Toolbox, SonarQube CLI and Claude Code keep themselves current).

---

## Shell & prompt

*(`zsh.yaml`, `pre_tasks.yaml`)*

| Tool                        | What it is                  | Why it's useful                                                                                                     |
|-----------------------------|-----------------------------|---------------------------------------------------------------------------------------------------------------------|
| **zsh**                     | The Z shell                 | More powerful interactive shell than bash — better completion, globbing, and theming. The default login shell here. |
| **oh-my-zsh**               | zsh configuration framework | Manages themes and plugins so the shell is productive out of the box.                                               |
| **zsh-autosuggestions**     | oh-my-zsh plugin            | Suggests commands as you type based on history — accept with → for fewer keystrokes.                                |
| **zsh-syntax-highlighting** | oh-my-zsh plugin            | Colors commands as you type so typos/invalid commands are obvious before you hit enter.                             |
| **fonts-powerline**         | Patched fonts               | Provides the glyphs (arrows, branch icons) that Powerline-style prompts and themes need to render correctly. Skipped when `headless` (glyphs render on the SSH client). |

## Dotfiles

*(`dotfiles.yaml`)*

| Tool         | What it is           | Why it's useful                                                                                                                                           |
|--------------|----------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------|
| **GNU Stow** | Symlink farm manager | Cleanly symlinks the [`mtkhawaja/dotfiles`](https://github.com/mtkhawaja/dotfiles) repo into `$HOME`, keeping config version-controlled and reproducible. |

## Editor

*(`neovim.yaml`)*

| Tool                             | What it is            | Why it's useful                                                                                 |
|----------------------------------|-----------------------|-------------------------------------------------------------------------------------------------|
| **Neovim** | Modern Vim fork       | Fast, extensible modal editor. apt on Debian; Homebrew on macOS. |
| **tree-sitter** *(`tree-sitter-cli`)* | Parser generator CLI | Required by nvim-treesitter's `main` branch to compile syntax parsers locally (needs ≥ 0.26.1). Latest release binary on Debian (apt is too old). |
| **StyLua**                       | Lua formatter         | Formats the Neovim config (`.stylua.toml`); also what the config repo's CI checks. Release binary on Debian. |

## AI assistant

*(`claude-code.yaml`)*

| Tool | What it is | Why it's useful |
|------|------------|-----------------|
| **Claude Code** (`claude`) | Agentic coding CLI | Anthropic's terminal coding agent. Self-updating; installed via the official `claude.ai/install.sh` script to `~/.local/bin/claude` on both OSes. |

## Core CLI utilities

*(`tools.yaml`)*

| Tool                           | What it is            | Why it's useful                                                                                      |
|--------------------------------|-----------------------|------------------------------------------------------------------------------------------------------|
| **tmux**                       | Terminal multiplexer  | Persistent sessions and split panes — keep work running after disconnect, organize multiple shells.  |
| **fzf**                        | Fuzzy finder          | Interactive fuzzy search over files, history, and any list; powers `Ctrl-R`, file pickers, and Yazi. |
| **jq**                         | JSON processor        | Slice, filter, and transform JSON on the command line — essential for APIs and config.               |
| **ripgrep** (`rg`)             | Recursive grep        | Extremely fast code/text search that respects `.gitignore`; the standard backend for editor search.  |
| **bat**                        | `cat` with wings      | Syntax-highlighted, paged file viewer with line numbers and git markers.                             |
| **tldr** *(tealdeer)*          | Simplified man pages  | Community-driven, example-first command help — faster than reading full `man` output. Pages pre-fetched on install. |
| **btop**                       | Resource monitor      | Pretty, interactive CPU/memory/process/network monitor (a modern `top`/`htop`).                      |
| **tree**                       | Directory lister      | Renders directory structure as a tree for quick orientation.                                         |
| **rsync**                      | File sync/transfer    | Efficient incremental copy/sync locally or over SSH.                                                 |
| **curl** / **wget**            | HTTP clients          | Fetch URLs, APIs, and release artifacts from scripts.                                                |
| **lsof**                       | Open-files lister     | See which process holds a file or port — key for debugging "address in use".                         |
| **xclip**                      | Clipboard bridge      | Pipe terminal output to/from the X clipboard. Skipped when `headless`.                               |
| **expect**                     | TTY automation        | Script interactive prompts (passwords, confirmations).                                               |
| **zip** / **unzip**            | Archive tools         | Create and extract `.zip` archives (also required to unpack some release binaries).                  |
| **tofrodos**                   | Line-ending converter | Convert between DOS (CRLF) and Unix (LF) line endings — handy across Windows/WSL.                    |
| **fastfetch**                  | System info           | At-a-glance OS/hardware summary for the terminal (maintained successor to the discontinued neofetch). |
| **gettext**                    | i18n utilities        | Provides `envsubst` and translation tooling.                         |
| **man-db**, **manpages-posix** | Manual pages          | Local documentation for commands and POSIX APIs.                                                     |
| **locales**, **locales-all**   | Locale data           | Ensures UTF-8 and locale settings work correctly (avoids `LC_*` warnings).                           |

## Modern CLI replacements

*(`modern-cli.yaml`, `tools.yaml`, `yazi.yaml`)* — **cross-platform (macOS + Debian/WSL)**

| Tool                    | What it is            | Why it's useful                                                                       |
|-------------------------|-----------------------|---------------------------------------------------------------------------------------|
| **eza**                 | Modern `ls`           | Colorized listings with icons, git status, and tree view.                             |
| **fd** *(`fd-find`)*    | Modern `find`         | Simpler syntax, fast, `.gitignore`-aware file finding (symlinked to `fd`).            |
| **zoxide**              | Smarter `cd`          | Jumps to frequently/recently used directories by partial name (`z proj`).             |
| **delta** (`git-delta`) | Git/diff pager        | Syntax-highlighted, side-by-side diffs that make code review far more readable.       |
| **lazygit**             | Git TUI               | Full-screen terminal UI for staging, committing, branching, and rebasing.             |
| **dust**                | Modern `du`           | Visual, intuitive disk-usage tree — find what's eating space fast.                    |
| **duf**                 | Modern `df`           | Clean, colorized view of disk/mount usage.                                            |
| **procs**               | Modern `ps`           | Human-friendly process listing with colors, tree view, and search.                    |
| **sd**                  | Modern `sed`          | Intuitive find-and-replace with plain strings/regex — no `sed` arcana.                |
| **hyperfine**           | Benchmarking tool     | Statistically rigorous command-line benchmarking with warmup and comparison.          |
| **yazi**                | Terminal file manager | Fast, image-previewing TUI file manager with fzf/zoxide integration. |

## Language runtimes & toolchains

### Java *(`sdkman.yaml`, `java.yaml`)*

| Tool                  | What it is            | Why it's useful                                                       |
|-----------------------|-----------------------|-----------------------------------------------------------------------|
| **SDKMAN**            | SDK version manager   | Installs and switches JVM SDKs/tools; cross-platform (curl-based).    |
| **Java 21 (Temurin)** | LTS JDK               | Long-term-support JDK for building/running JVM apps.                  |
| **Maven**             | Build/dependency tool | Standard build lifecycle and dependency management for Java projects. |
| **Gradle**            | Build tool            | Flexible, incremental builds for JVM (and other) projects.            |

### JavaScript *(`js.yaml`, `bun.yaml`)*

| Tool | What it is | Why it's useful |
|------|------------|-----------------|
| **nvm** | Node version manager | Install and switch between Node.js versions per project; curl-installed, cross-platform. |
| **Node.js** *(LTS via nvm)* | JS runtime | Run JavaScript/TypeScript tooling and servers; ships with `npm`. The LTS is installed and set as the nvm default. |
| **Bun** | JS runtime + toolkit | Fast all-in-one runtime, package manager, bundler, and test runner; drop-in `npm`/`node` alternative. Installed to `~/.bun`. |

### Python *(`python.yaml`)*

| Tool | What it is | Why it's useful |
|------|------------|-----------------|
| **uv** | Python package/version manager | Astral's fast all-in-one tool: installs interpreters and CLI tools, downloads prebuilt standalone Pythons (no system build deps). Replaces pyenv + pipx. |
| **Python 3.13 & 3.12** | Interpreters | Installed via uv; 3.13 is the default `python`/`python3` on `PATH`, 3.12 available alongside. |
| **ruff** | Linter & formatter | Astral's fast all-in-one linter + formatter; replaces black and pylint. Installed as a `uv tool`. |
| **mypy** | Static type checker | Catches type errors before runtime. Installed as a `uv tool`. |

### Go *(`go.yaml`)*

| Tool          | What it is         | Why it's useful                                                           |
|---------------|--------------------|---------------------------------------------------------------------------|
| **Go** | Go toolchain       | Compiler and tooling for Go development. Latest go.dev release on Debian (updated on re-run); Homebrew on macOS. |
| **gopls**     | Go language server | LSP backend powering editor completion, diagnostics, and refactoring.     |

## Desktop apps

*(`apps.yaml`)* — skipped when `headless`.

| Tool | What it is | Why it's useful |
|------|------------|-----------------|
| **Ghostty** | GPU-accelerated terminal | Fast native terminal; config comes from the dotfiles repo (`~/.config/ghostty/`). Homebrew cask on macOS; Ubuntu's archive on Debian. |
| **JetBrains Toolbox** | JetBrains IDE manager | Installs and updates IntelliJ, PyCharm, etc. Homebrew cask on macOS (skipped if the app is already installed); latest tarball on Debian (x86_64/arm64), self-updating after first launch. Sign-in and IDE choice stay manual. |
| **VLC** | Media player | Plays nearly any audio/video format. Homebrew cask on macOS; apt on Debian. |
| **bloom**, **AeroSpace** | macOS utilities | File manager and tiling window manager (macOS only). |

## Developer platform CLIs

*(`github-cli.yaml`, `sonarqube-cli.yaml`, `acli.yaml`)*

| Tool | What it is | Why it's useful |
|------|------------|-----------------|
| **GitHub CLI** (`gh`) | GitHub from the terminal | PRs, issues, Actions runs, releases and API calls without the browser. Homebrew on macOS; GitHub's official apt repo on Debian (Ubuntu's package lags by years). |
| **SonarQube CLI** (`sonar`) | SonarQube in the terminal | Code-quality and security analysis from scripts and agents. Homebrew cask on macOS (Apple Silicon only); latest binary on Debian (amd64/arm64). |
| **Atlassian CLI** (`acli`) | Jira / Confluence CLI | Script Jira and Confluence work from the shell. Atlassian's Homebrew tap on macOS; Atlassian's apt repo on Debian. |

## Headless browser testing (Linux only)

*(`browser-testing.yaml`)* — Debian/Ubuntu only; intentionally not managed on macOS.

Lets Chrome-based Playwright and Selenium tests run on a server with no desktop. Projects only need the
per-project, sudo-free `playwright install`; Selenium Manager fetches a matching chromedriver for the system Chrome.

| Tool | What it is | Why it's useful |
|------|------------|-----------------|
| **Google Chrome** (`google-chrome-stable`) | Browser (amd64/arm64) | System Chrome for Selenium / Playwright `channel: 'chrome'`, and it pulls in the shared libraries Playwright's bundled Chromium needs. Installed from Google's apt repo, which the package then manages itself. |
| **fonts-liberation**, **fonts-noto-color-emoji** | Fonts | Correct text and emoji rendering in screenshots and visual tests. |
| **xvfb** | Virtual X display | Only for tests that must run headed: `xvfb-run -a <cmd>`. |

Inside Docker, Chrome's sandbox needs namespaces that the default seccomp profile blocks: use `--no-sandbox` there
(Playwright already does) or run the container with `--security-opt seccomp=unconfined`. On a real Ubuntu host,
Ubuntu's AppArmor profile for `/opt/google/chrome/chrome` lets the sandbox work as-is.

## Secrets & signing

*(`bitwarden-cli.yaml`, `pre_tasks.yaml`)*

| Tool | What it is | Why it's useful |
|------|------------|-----------------|
| **Bitwarden CLI** (`bw`) | Password-manager CLI | Retrieve secrets/credentials from Bitwarden in scripts and the terminal. |
| **GnuPG** (`gpg`) | OpenPGP encryption/signing | Encrypt/sign files and git commits/tags. Installed on both OSes; on macOS it's paired with **pinentry-mac** for a native passphrase dialog (the dotfiles' gpg-agent points at it). |

## Media & file inspection

*(Yazi dependencies, `yazi.yaml`)*

| Tool              | What it is     | Why it's useful                                                  |
|-------------------|----------------|------------------------------------------------------------------|
| **ffmpeg**        | Media toolkit  | Transcode/inspect audio and video; powers Yazi video thumbnails. |
| **imagemagick**   | Image toolkit  | Convert and manipulate images; enables image previews.           |
| **poppler-utils** | PDF utilities  | Render/extract from PDFs (e.g. `pdftoppm`) for previews.         |
| **7zip**          | 7-Zip archiver | Handle `.7z` and many other archive formats.                     |

## Build toolchain

*(`tools.yaml`, `neovim.yaml`)*

Building native dependencies needs a C/C++ toolchain. Installed on Debian via apt: **build-essential** (gcc/g++/make), **cmake**, **ninja-build**, **pkg-config**, **libtool**/**libtool-bin**, **lua5.1**, **libpthread-stubs0-dev**. macOS relies on the Xcode Command Line Tools plus the Homebrew equivalents (`cmake`, `ninja`, `pkg-config`, `libtool`, `lua`). Python needs no build deps — uv installs prebuilt standalone interpreters.

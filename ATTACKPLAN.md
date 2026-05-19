# ATTACKPLAN.md — mysettings consolidation

Strategy and migration plan for collapsing the Mac + Ubuntu kitting paths
onto a single declarative base. Living document — update as phases land.

## 1. Goals

1. **One canonical kit** for 10 Ubuntu lab servers + N MacBooks. `git pull
   && converge` produces an identical "kit state" on every box, regardless
   of OS, with the only differences being genuinely platform-specific
   (Xcode, dock, mas vs. apt, docker-ce, r2u).
2. **Maximise shared code.** Every cross-platform tool installed by the
   same upstream installer (one invocation, both OSes). No per-OS forks
   of the install logic where one recipe suffices.
3. **Fleet-converge, not single-shot kit.** Re-running the kit must be
   safe, fast, idempotent, and `--check`-able. Drift detection across the
   10 servers is a first-class concern.
4. **Thin platform sections.** `ubuntu/` and `mac/` only contain what
   is genuinely OS-bound: package-manager invocations for system
   libraries, kernel/sysctl, docker, R-via-r2u, mas, dockutil, AppleScript.
   (The dirs keep their current names — the consolidation work is in
   shared `common/` + `packages/`, not in renaming.)

## 2. Non-goals

- **Not** porting linuxbrew onto servers, **not even as a curated allowlist
  of "pre-built binaries only"** (LOCKED). The discipline cost — per-formula
  deps audit, allowlist enforcement in `check_tools.sh`, PATH-ordering
  guarantees across 10 boxes, team education for every new lab member —
  exceeds the consolidation it would buy. The failure mode isn't the
  first `brew install bat`; it's the next `brew install <something>`
  whose transitive deps quietly pull `openssl` / `libuv` / `libxml2` /
  `hdf5` / `harfbuzz` into `/home/linuxbrew/Cellar/`, duplicating system
  libs and creating subtle breakage (the exact pain we already lived
  through). The shared `packages/` YAML lists give us the consolidation
  we actually want — canonical tool lists per OS, two thin per-OS
  installers — without putting that footgun back in the kitchen.
  If a specific tool ever needs a route apt+cargo can't cover, it goes
  via cargo (statically linked, lives in `~/.cargo/bin`, no system
  pollution). This decision is locked: changing it requires re-opening
  ATTACKPLAN.md, not an offhand `brew install` somewhere.
- **Not** killing brew on macOS. Brew is the canonical Mac package manager;
  we use it for system libraries, GUI casks, fonts, and tools without a
  better upstream installer.
- **Not** making Ansible drive interactive Mac steps (Xcode license, mas
  App Store login, opening Android Studio for SDK Manager). Those stay as
  a thin bash post-step.
- **Not** rewriting the chezmoi dotfile work in flight. Extend it.

## 3. Principles (install-source decision tree)

For every tool, ask in this order:

1. **Is there an official cross-platform `curl | sh` / language-toolchain
   installer that works the same on macOS and Linux?**
   → use it (uv, bun, rustup, mise, claude-native, fvm via dart pub).
2. **Is it a language toolchain that mise manages cleanly?**
   → use mise (node, dart). Future-proof: same install pin everywhere.
3. **Is it a Rust binary with no good binary release path?**
   → `cargo install --locked` on both platforms. Acceptable build cost.
4. **Is it a system library, kernel module, or platform service?**
   → use the platform-native package manager (apt on Linux, brew on Mac).
5. **Is it a GUI app, font, or App Store binary?**
   → brew cask / mas on Mac, apt or .deb on Linux (rare — we only have
   Chrome / Android Studio on Linux today).

When 1–3 apply, the install logic lives in `common/`. When 4–5 apply, it
lives in `ubuntu/` or `mac/`.

6. **Host chases modern versions; version-sensitive work runs in Docker.**
   Like Homebrew, the host runs current upstream of each tool. apt LTS lag
   for fast-moving CLIs (eza, ripgrep, bat, fd, git-delta — frequent
   feature releases) is a real cost, so we push those off apt onto the
   cargo route — `cargo binstall --locked` driven by chezmoi, identical
   recipe on Mac and Linux. When a workload genuinely needs an older
   version (e.g. ghostscript 9.55 for the Japanese PDF mojibake fix),
   that workload runs inside a Docker container, not as a pinned host
   package. Consequence: **no ghostscript pin, no apt version pin
   anywhere in the kit**, no IMEI source-build path. Every Ubuntu kit
   begins with `apt-get update && apt-get upgrade -y` so the host is
   current before our own installs run.

## 4. Tool inventory and dissection

Symbol legend:
- ✅ already installed by the same upstream installer on both OSes
- 🔀 currently differs between Mac and Ubuntu — **consolidation target**
- ⬛ genuinely platform-specific — stays split

### 4.1 Cross-platform, one installer (target: `common/`)

| Tool                       | Today on Mac          | Today on Ubuntu             | Target (both)                                     | Status |
|----------------------------|-----------------------|-----------------------------|---------------------------------------------------|--------|
| **zsh as login shell**     | bundled               | apt zsh                     | bundled / apt prereq + `chsh`                     | ✅      |
| **p10k + .zshrc + .gitconfig** | chezmoi (in flight) | chezmoi (in flight)         | chezmoi (`dotfiles/`)                             | ✅      |
| **GitHub ed25519 key import** | `common/setup_zsh_and_keys.sh` | same                | same (no change)                                  | ✅      |
| **mise**                   | `brew install mise`   | apt repo (mise.jdx.dev)     | `curl https://mise.run \| sh`                     | 🔀     |
| **node @lts**              | `mise use -g node@lts`| `mise use -g node@lts`      | `mise use -g node@lts`                            | ✅      |
| **uv (Python toolchain)**  | `brew install uv` + chezmoi `run_onchange_install-uv.sh` | chezmoi `run_onchange` + curl | `curl https://astral.sh/uv/install.sh \| sh` via chezmoi | ✅      |
| **Python 3.13 venv (`~/p313`)** | `uv venv` post-install | not present today           | `uv venv --python 3.13 ~/p313` in common          | 🔀 (also adds it to Linux) |
| **uv-managed lab pip set** (polars, pandas, numpy, requests, pyarrow, scikit-learn, jupyter) | yes | no | `uv pip install …` in common | 🔀 |
| **bun**                    | `brew install bun`    | `curl bun.sh/install \| bash` | `curl bun.sh/install \| bash`                   | 🔀     |
| **rustup**                 | chezmoi `run_onchange` | chezmoi `run_onchange`     | `curl sh.rustup.rs \| sh` via chezmoi             | ✅      |
| **cargo-binstall** (prebuilt cargo binaries) | —                  | —                          | `curl install-from-binstall-release.sh \| bash`   | 🔀 |
| **Rust modern-path CLIs**: git-trim, du-dust, jless, zellij, qsv, **bat, eza, ripgrep, fd-find, git-delta** | brew | apt (+ batcat/fdfind symlinks) | `cargo binstall --locked` via chezmoi `run_onchange` | 🔀 |
| **dart SDK**               | `brew install dart-sdk` | apt repo (Google)         | `mise use -g dart@stable`                         | 🔀     |
| **fvm**                    | `dart pub global activate fvm` | same               | `dart pub global activate fvm`                    | ✅      |
| **Flutter stable**         | `fvm install stable && fvm global stable` | same   | same                                              | ✅      |
| **claude (native)**        | `cli_tools/llms_update.sh` (curl claude.ai/install.sh) | same | unchanged                                        | ✅      |
| **gemini, codex**          | `bun add -g` via llms_update.sh | same              | unchanged                                         | ✅      |
| **git defaults** (user.name/email, pull.rebase, fetch.prune…, alias.sync) | inline append | community.general.git_config | shared bash function in `common/git_defaults.sh` | 🔀 |
| **cli_tools/ on PATH**     | imperative append     | imperative append           | chezmoi `dot_zshrc.tmpl` (already does this)      | ✅      |
| **login_check.sh / check_tools.sh runs** | yes | yes        | same — invoked from common end-of-kit             | ✅      |

### 4.2 Different package manager, same logical tool (slow-movers only)

These exist in apt AND brew at currentish versions and don't add new
features often. The package-manager IS the official installer for these.
Keep platform-split but the names live in their respective per-OS lists
(`packages/linux_base.yml` for apt, `packages/darwin_brew_system.yml` for
brew) — the lists differ only in apt-name vs. brew-name. Fast-moving CLIs
(bat, eza, ripgrep, fd, git-delta) moved up to §4.1 — they go via cargo
so the host stays current with upstream feature releases (§3 principle 6).

| Tool         | apt name (Ubuntu)         | brew name (Mac) | Notes |
|--------------|---------------------------|-----------------|-------|
| jq           | jq                        | jq              | stable, no new features for years |
| zoxide       | zoxide                    | zoxide          | 1.x, slow cadence |
| duf          | duf                       | duf             | Go, slow cadence |
| btop         | btop                      | btop            | apt 26.04+ current |
| hyperfine    | hyperfine                 | hyperfine       | 1.x, slow |
| tealdeer     | tealdeer                  | tealdeer        | 1.x, slow |
| sd           | sd                        | sd              | 1.x, slow |
| procs        | procs                     | procs           | 0.14, slow |
| yq (mikefarah) | snap yq                 | yq              | snap → snap-tolerant on minimal images |
| gh           | apt cli.github.com        | gh              | both use upstream-current channel (already modern path) |
| qpdf, mupdf, imagemagick, ghostscript | apt | brew | no pinning anywhere (§3.6) |
| parallel     | parallel                  | parallel        | GNU, stable |
| iftop, htop  | iftop / —                 | iftop, htop     |       |
| tmux, tree, wget, rclone | wget+rclone present, tmux+tree added | yes | small drift today, normalise |

### 4.3 Linux-only (lives in `ubuntu/`)

System pieces with no Mac analogue.

- **base apt build/system packages:** zsh, avahi-daemon, parallel,
  wireguard-tools, nkf, iotop, lm-sensors, build-essential, pkg-config,
  libssl-dev, libxcb1-dev, libxcb-render0-dev, libxcb-shape0-dev,
  libxcb-xfixes0-dev, gpg, software-properties-common, dirmngr, snapd,
  apt-transport-https, ca-certificates, curl, wget.
- **apt rustc/cargo purge** (preserves rustup's per-user toolchain). The
  old `/usr/local/bin/bat → /usr/bin/batcat` and `fd → fdfind` symlinks
  are removed in Phase 4 once bat/fd move to the cargo route — the cargo
  binaries land in `~/.cargo/bin` with their canonical names.
- **timezone Asia/Tokyo, vm.swappiness=10.**
- **mise apt repo** → replaced by mise.run; only Linux build deps stay.
- **gh apt repo, Google linux signing key + Dart apt repo** — replaced by
  brew on Mac side; on Linux we keep apt for gh (cli.github.com is the
  modern path), dart goes to mise.
- **docker-ce + plugins, /etc/apt/keyrings/docker.asc, docker.io
  migration logic, docker group membership.**
- **mailab root CA cert** → `/usr/local/share/ca-certificates/`,
  `update-ca-certificates`, restart docker on cert change.
- **netdata kickstart.**
- **R via r2u + bspm + Marutter CRAN + r-install wrapper + r-installers
  group + /etc/sudoers.d/r-installers + /etc/R/Rprofile.site block.**
- **ghostscript + PDF tools + ImageMagick** — current apt versions, no
  pinning (§3.6). Version-sensitive PDF work runs in Docker.
- **linuxbrew detection + deprecation warning.**
- **ubuntu_on_macbook.sh** (SPI keyboard, audio driver) — only relevant
  on Apple hardware running Ubuntu.
- **MOTD strip, superclean, GUI tools (Chrome, Android Studio via PPA)** —
  separate playbooks already, leave as-is.

### 4.4 macOS-only (lives in `mac/`)

System pieces with no Linux analogue.

- **Homebrew bootstrap** (curl install.sh from brew.sh).
- **brew system libraries** (libgit2, libsodium, libtiff, cmake,
  libxml2, openssl, curl, harfbuzz, fribidi, hdf5, hexyl, libuv,
  little-cms2, oath-toolkit, pigz, poppler, pstree, rename, shellcheck,
  subversion, telnet, unar, zlib, aria2, automake, awscli,
  google-cloud-sdk, graphicsmagick, mtr, watch).
- **GNU coreutils PATH block** (`coreutils`, `findutils`, `grep`,
  `gnu-sed`, `gnu-tar`, `gnu-getopt`) — Linux already has GNU by default.
- **bash** (newer than system bash 3.2).
- **ruby + cocoapods + xcodeproj gem** — iOS dev path; Linux doesn't ship
  iOS builds.
- **Xcode via mas (mas install 497799835), `wait $install_pid`, license
  prompt, "open -a Xcode" on completion.**
- **brew cask GUI**: iterm2, temurin, wireshark, cyberduck, mountain-duck,
  sublime-text, onyx, discord, google-chrome, keka, github,
  vnc-viewer, visual-studio-code, android-studio, r (CRAN GUI build).
- **brew cask fonts**: font-fira-code-nerd-font, font-fira-mono-nerd-font,
  font-noto-sans-cjk, font-source-code-pro, font-source-sans-3.
- **iTerm2 plist copy** from `mac/resources/`.
- **dockutil + `defaults write`** for menubar/dock auto-hide, magnification,
  size, app placement.
- **R + tidyverse via CRAN cask + `pacman::p_load(tidyverse, languageserver)`.**
- **`~/.Rprofile`** with CRAN mirror.
- **Android Studio SDK Manager AppleScript invocation.**
- **flutter doctor** (final convenience).
- **postinstall_note.md browser open.**

### 4.5 Lab Python preload (currently Mac-only)

`mac/setup_cli_tools.sh` creates `~/p313` and `uv pip install polars
pandas numpy requests pyarrow scikit-learn jupyter`. Linux side doesn't
do this — but the lab is a Polars-first data-science shop on both
platforms. **Decision: lift this into common/.** Costs ~200MB per Linux
host; gains uniform "open a shell, `source ~/p313/bin/activate`, `polars`
works" on all 10+ servers.

## 5. Target repository layout

Directory names stay as today (`ubuntu/`, `mac/`) — the consolidation
shows up in shared `common/` + a new `packages/`, not in renames.

```
mysettings/
├── ATTACKPLAN.md                    ← this file
├── README.md                        ← entry-point docs
├── setup_mailab_mac.sh              ← thin orchestrator
├── setup_mailab_ubuntu.sh           ← thin orchestrator
│
├── common/                          ← runs on Mac AND Linux
│   ├── setup_zsh_and_keys.sh        (unchanged)
│   ├── install_mise.sh              NEW — curl mise.run
│   ├── install_uv_and_p313.sh       NEW — curl astral + p313 venv + lab pip
│   ├── install_bun.sh               NEW — curl bun.sh/install
│   ├── install_rustup_and_cargo.sh  via chezmoi run_onchange (extended list)
│   ├── install_node_dart.sh         NEW — mise use -g node@lts dart@stable
│   ├── install_fvm_flutter.sh       NEW — dart pub global activate fvm + install stable
│   ├── install_llms.sh              NEW — wraps cli_tools/llms_update.sh
│   ├── git_defaults.sh              NEW — git config block
│   └── post_kit_checks.sh           NEW — login_check.sh + check_tools.sh
│
├── ubuntu/                          ← Linux-only (kept as-is)
│   ├── my_ubuntu_setup.sh           (existing — reads packages/*.yml)
│   ├── setup_gui_tools.sh           Chrome, Android Studio PPA
│   └── ubuntu_on_macbook.sh         (unchanged)
│
├── mac/                             ← Mac-only (kept as-is)
│   ├── setup_cli_tools.sh           (existing — reads packages/*.yml)
│   ├── setup_gui_apps.sh            (existing)
│   ├── brew_tidyverse.sh            (existing — reads packages/darwin_brew_r_build_deps.yml)
│   └── resources/                   iTerm2 plist etc.
│
├── packages/                        ← single source of truth lists (plain YAML arrays)
│   ├── README.md                    explains the layout
│   ├── linux_base.yml               apt: base system + modern CLI for Ubuntu
│   ├── darwin_brew_system.yml       brew formulae (system libs + modern CLI)
│   ├── darwin_brew_casks.yml        GUI casks
│   ├── darwin_brew_fonts.yml        font casks
│   ├── darwin_brew_r_build_deps.yml brew formulae required to build R+tidyverse
│   └── lab_python.yml               polars, pandas, numpy, ... for uv pip
│
├── automated/                       ← Ansible — fleet convergence
│   ├── bootstrap.sh                 extend: detect macOS, brew install pipx
│   ├── inventory.yml                ← add 10 lab server hostnames
│   ├── group_vars/
│   │   ├── all.yml
│   │   ├── linux.yml
│   │   └── darwin.yml
│   ├── kitting.yml                  os-dispatch: imports ubuntu_kitting.yml or mac_kitting.yml
│   ├── ubuntu_kitting.yml           (existing — vars_files from packages/*.yml)
│   ├── mac_kitting.yml              NEW
│   └── tasks/
│       ├── common_mise.yml          ↔ common/install_mise.sh
│       ├── common_uv.yml
│       ├── common_bun.yml
│       ├── common_rustup.yml
│       ├── common_node_dart.yml
│       ├── common_fvm.yml
│       ├── common_llms.yml
│       └── common_git.yml
│
├── cli_tools/                       ← unchanged
├── dotfiles/                        ← chezmoi, extended
├── certs/, multipass/, p312/        ← unchanged
└── _zshrc, _p10k.zsh                ← deleted post-chezmoi migration
```

Each `common/install_*.sh` script and its `tasks/common_*.yml` Ansible
counterpart must produce the same end state. They are two callable forms
of the same operation: bash for single-host kit, Ansible for fleet
convergence. **One of them is the source of truth, the other is a
thin wrapper.** Default direction: **Ansible task is source of truth,
bash wrapper is `ansible-playbook --tags <name> -i localhost,`**. The
bash form is preserved only as a documentation surface / fallback.

## 6. Migration phases

Each phase is independently shippable as one PR. Both kit paths
(`setup_mailab_mac.sh`, `setup_mailab_ubuntu.sh`,
`setup_mailab_ubuntu-ansible.sh`) must keep working after every phase.

### Phase 0 — Land ATTACKPLAN.md
- This document, plus a tracking issue / PR series referenced by phase.
- No code change.
- **Exit criteria:** ATTACKPLAN.md merged.

### Phase 1 — Immediate cleanup (LOCKED, this commit)
Lockable items resolved by the same PR that lands ATTACKPLAN.md, because
each is small, low-risk, and removes work that subsequent phases would
otherwise have to migrate:
- **Drop the ghostscript 9.55 pin** from `ubuntu/my_ubuntu_setup.sh`
  and `automated/ubuntu_kitting.yml`. No more `ghostscript_pinned`
  variable, no more pin-then-fallback-then-warn task chain. Plain
  `apt install ghostscript qpdf mupdf imagemagick`. Version-sensitive
  PDF workloads move to Docker (§3.6). Ubuntu 26.04+ ships ImageMagick 7
  in apt, so no IMEI source build path remains either.
- **Run `apt-get update && apt-get upgrade -y` as the very first kitting
  action** in `ubuntu/my_ubuntu_setup.sh` (after the root + SUDO_USER
  guards), in `setup_mailab_ubuntu-ansible.sh` (right after the sudo
  prompt + keep-alive), and as the first task of the system play in
  `automated/ubuntu_kitting.yml`. The host arrives at current upstream
  before any of the kit's own installs run.
- **Lock the no-linuxbrew decision** in §2 with the failure-mode
  rationale spelled out — future reviewers see why brew-on-Linux stays
  closed even for "simple pre-built binaries only" experiments.
- **Exit criteria:** ghostscript pin gone everywhere; first kit action
  on every Ubuntu entry path is apt update + upgrade; ATTACKPLAN §2
  carries the locked rationale.

### Phase 2 — Extract canonical package lists into `packages/`
Plain YAML arrays so the lists are diffable, greppable, and edit-only.
No metadata format — apt-vs-brew name differences just live in their
respective per-OS file.

- `mac/brew_list.txt` → `packages/darwin_brew_system.yml` (one entry per
  formula; modern CLI tools stay listed here for now — Phase 4 moves
  the fast-movers to cargo).
- `mac/brew_cask.txt` → split into `packages/darwin_brew_casks.yml` +
  `packages/darwin_brew_fonts.yml` (the `font-*` entries are casks but
  named differently and updated less often).
- The inline `brew install …` list at the top of `mac/brew_tidyverse.sh`
  → `packages/darwin_brew_r_build_deps.yml`.
- The inline `uv pip install …` list at the bottom of
  `mac/setup_cli_tools.sh` → `packages/lab_python.yml` (sets up the
  rails Phase 5 will run on; no Linux behaviour change in this phase).
- Apt `base_packages` from `automated/ubuntu_kitting.yml` and the inline
  `apt-get install` block at the top of `ubuntu/my_ubuntu_setup.sh` →
  `packages/linux_base.yml`.
- Bash consumers read with `awk '/^- / { print $2 }'` (no yq dep — that
  would be a bootstrap chicken-and-egg). Ansible consumers use
  `lookup('file', playbook_dir + '/../packages/<list>.yml') | from_yaml`.
- **No behaviour change** — same package set installed before and after.
- **Exit criteria:** Re-kit one Mac + one Ubuntu host, diff against
  pre-Phase-2 state — identical packages installed.

### Phase 3 — Introduce `common/install_*.sh` for the easy wins
For each of `mise`, `bun`, `node@lts`, `dart`, `fvm + flutter`, `git_defaults`:
- Write `common/install_<tool>.sh` that does the official-installer recipe
  with OS-detection only where genuinely necessary (almost none —
  rustup/uv/bun/mise are OS-agnostic).
- Replace the corresponding section in `mac/setup_cli_tools.sh` and
  `ubuntu/my_ubuntu_setup.sh` with `source common/install_<tool>.sh`.
- For each, also write `automated/tasks/common_<tool>.yml` mirroring the
  same end state. The Ansible kit playbook starts using these.
- **Exit criteria:** mise/bun/node/dart/fvm/git on a fresh Mac and a
  fresh Ubuntu come from common scripts. Both `check_tools.sh` runs
  return clean.

### Phase 4 — Expand the cargo route (modern-path policy)
This is where §3.6 actually shows up in the code — fast-moving Rust CLIs
leave apt+brew and converge on `~/.cargo/bin`.
- Install `cargo-binstall` via its official curl-pipe-sh installer so
  the cargo route pulls prebuilt GitHub-release binaries (~1 min total
  on first kit) instead of compiling from source (~35 min for the full
  list — qsv alone is ~10 min).
- Extend `dotfiles/run_onchange_install-rustup-and-cargo-tools.sh`
  with `cargo binstall --locked` for: `git-trim`, `du-dust`, `jless`,
  `zellij`, `qsv --features apply` (existing four) **plus** `bat`, `eza`,
  `ripgrep`, `fd-find`, `git-delta` (newly migrated off apt+brew per
  §3.6). Fall back to `cargo install --locked` when no binstall release
  exists.
- Remove these nine tools from `packages/darwin_brew_system.yml` and
  from `packages/linux_base.yml`.
- Remove the `/usr/local/bin/bat → /usr/bin/batcat` and
  `/usr/local/bin/fd → /usr/bin/fdfind` symlinks from
  `ubuntu/my_ubuntu_setup.sh` + the equivalent tasks in
  `automated/ubuntu_kitting.yml` (the cargo binaries land in
  `~/.cargo/bin` with the canonical name; no rename quirks to
  compensate for).
- Teach `check_tools.sh` that `~/.cargo/bin` is canonical for all nine.
- **Exit criteria:** Fresh Mac kit ends with these tools in
  `~/.cargo/bin` (not `/opt/homebrew/bin`); fresh Ubuntu kit has no apt
  versions of them; `bat --version` / `rg --version` / `eza --version`
  show latest upstream on both OSes; `check_tools.sh` clean.

### Phase 5 — Lift Python p313 + lab pip into common
- New `common/install_uv_and_p313.sh`: install uv (delegating to existing
  chezmoi `run_onchange_install-uv.sh`), then `uv venv ~/p313`, then
  `uv pip install $(yq … packages/lab_python.yml)`.
- Wire `~/p313/bin/activate` into `dot_zshrc.tmpl` for both OSes (Mac
  block exists; add an OS-agnostic version).
- **Exit criteria:** `source ~/p313/bin/activate && python -c "import
  polars"` succeeds on a freshly kitted Ubuntu lab server.

### Phase 6 — Ansible cross-platform dispatch
- Extend `automated/bootstrap.sh` with macOS branch (`brew install pipx
  && pipx install ansible` or `brew install ansible` directly).
- Add `automated/group_vars/{all,linux,darwin}.yml`.
- Add an `automated/kitting.yml` dispatcher that includes either
  `ubuntu_kitting.yml` (existing) or a new `mac_kitting.yml` based on
  the host's OS family, sharing the `common_*.yml` task files.
- `mac_kitting.yml` plays: brew bootstrap, brew system pkgs (from
  `packages/darwin_brew_system.yml`), GNU utils, ruby/cocoapods, brew gh,
  brew casks (from `packages/darwin_brew_casks.yml`), iterm plist, dock
  defaults, R tidyverse. `mas`, Xcode wait, AppleScript bits remain in
  `setup_mailab_mac.sh` as a post-step — Ansible doesn't drive those.
- **Exit criteria:** `ansible-playbook -i localhost, kitting.yml` on a
  fresh Mac kits the declarative half end-to-end.

### Phase 7 — Roll out to lab fleet
- Add the 10 lab server hostnames to `automated/inventory.yml` under a
  `lab_servers` group.
- Verify SSH-key login works to all 10 from the controller (use the
  ed25519 key already on the boxes via `setup_zsh_and_keys.sh`).
- First convergence pass: `ansible-playbook -i inventory.yml --check
  --diff --limit lab_servers kitting.yml` — review diff per host.
- Apply: `ansible-playbook -i inventory.yml --limit lab_servers
  kitting.yml`, ideally in batches (`--forks 3`, or `serial: 3` in the
  play) to limit blast radius if anything misbehaves.
- Decision point: do we run kitting.yml on a schedule (drift correction)?
  Recommend **not yet** — start with on-demand only, revisit after a
  month of stable runs.
- **Exit criteria:** all 10 servers green on a clean `--check` run;
  `check_tools.sh` clean on each.

### Phase 8 — Documentation + decommission
- Update `README.md` to describe the new layout and the
  `common/`/`ubuntu/`/`mac/`/`packages/`/`automated/` split.
- Mark `setup_mailab_ubuntu-ansible.sh` as the canonical Ubuntu kit
  (the orchestrator now is just `ansible-playbook` under the hood);
  keep `setup_mailab_ubuntu.sh` working as the lighter no-Ansible
  fallback.
- Delete `_zshrc`, `_p10k.zsh` once every active machine is on chezmoi.
- Update `automated/README.md` to describe the cross-platform layout
  and the lab-fleet workflow.

## 7. Risks and mitigations

| Risk | Mitigation |
|------|------------|
| Phase 4 expands the cargo route to nine tools; source builds would be ~35 min total on first kit (qsv alone ~10 min). | `cargo binstall` pulls upstream prebuilt GitHub-release binaries first, falling back to source compile only when no release exists. First-kit cost drops to ~1 min total. chezmoi `run_onchange` re-runs only when the script changes. |
| mise install via `curl mise.run` differs from apt's mise (config path, shim layout). | Verify on one host before flipping — both write to `~/.local/share/mise` for user installs, same shim resolution. |
| Moving dart to mise changes the binary path (`~/.local/share/mise/installs/dart/...` vs `/usr/lib/dart/bin`); fvm path resolution + `~/.pub-cache/bin` PATH wire-up has to follow. | Test fvm flow on one host before flipping. Keep the apt dart repo install around in a `--tags apt-dart-fallback` branch for one cycle. |
| Existing 10 lab servers may have drift we don't know about (`/etc/sudoers.d/`, custom systemd units, manual installs). | First fleet pass is `--check --diff --limit one-server-at-a-time`. Build a "drift report" before any apply. |
| `check_tools.sh` may flag duplicate installs during phase transitions (e.g. brew jless still present while cargo jless landing). | Add a Phase-3 cleanup step that purges the brew copy explicitly. |
| Ansible bootstrap on Mac introduces a new dep (`pipx` or `ansible` via brew). | Acceptable — single command, well-trodden path. Document in README. |

## 8. Definition of done (per-phase smoke test)

After every phase, both of these must succeed on a freshly kitted box:

```bash
# Mac
./setup_mailab_mac.sh && cli_tools/check_tools.sh && cli_tools/login_check.sh

# Ubuntu
./setup_mailab_ubuntu.sh && cli_tools/check_tools.sh && cli_tools/login_check.sh
```

And the Ansible variant against localhost:
```bash
cd automated && make bootstrap && make kit
```

And, by Phase 7, the fleet:
```bash
ansible-playbook -i inventory.yml --check --diff --limit lab_servers kitting.yml
```

returns "ok" everywhere with zero unexpected diffs.

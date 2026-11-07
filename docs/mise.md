# Mise machine setup and migration

## Inventory and decisions

Inspection on 2026-11-07 found a clean tracked tree plus an existing untracked `.serena/`
directory (left untouched). There was no repository `AGENTS.md`, `CLAUDE.md` or CodeGraph index.
The supplied RTK instructions were followed. Shell scripts and Ansible duplicated installation;
chezmoi templates and `_zshrc` deployed shell configuration, often supplemented by installer appends.

Previously: mise selected Node `lts`; Homebrew owned Ruby/CocoaPods/Dart/uv on Mac;
FVM selected Flutter `stable`; uv installed Python 3.13 and populated `~/p313`; rustup and
cargo-binstall installed Rust and CLI tools; Bun and Claude had separate installers/updaters.
Shells added FVM, standalone pnpm, Bun, Homebrew Ruby and even Linuxbrew, and activated p313.
The tracked `p312/pyvenv.cfg` points to Homebrew Python 3.12.7; this legacy environment is retained.
No application Gemfile, pnpm lock, FVM project, editor SDK config or application service unit
was present. No RVM installation or repository RVM hooks/gemsets were found on the available Mac.

Host inspection found Homebrew-owned mise **2026.11.0**, global Node **26**, pnpm **latest**
(resolved **12.4.2**), Java **temurin-17**, and a manually registered HTTP gcloud **591.0.0**.
Installed Ruby **3.4.12**, Python **3.14.10**, uv **0.13.6**, Bun **1.3.14**, Rust **1.96.0**,
and Flutter **3.47.5 / 3.44.4** informed the initial locks. The latter Flutter is an existing
SDK symlink, not copied or removed. Python **3.13** remains installed for the lab requirement.
No global compiler/library flags, GEM_HOME/GEM_PATH or Bundler path overrides were active.
PNPM_HOME and an unrelated project VIRTUAL_ENV were inherited. Doctor also found old Homebrew
Ruby/FVM and FVM SDK paths in the current shell; these remain pending the explicit shell switch.

The moving `lts`, `latest` pnpm and `stable` Flutter defaults are deliberately bounded to the
observed Node 26 and pnpm 12 majors and explicit Flutter releases. Ruby stays in 3.4, Python
in 3.14/3.13, uv in 0.13, Bun in 1.3 and Java in 17. Rust and gcloud retain observed pins.
Standalone personal CLIs intentionally follow `latest`, resolved into committed locks.
Applications requiring another version must declare it in their own repository before activation.

## Ownership

| Area | Owner and update path |
| --- | --- |
| Node, pnpm, Python, uv, Ruby, Flutter/bundled Dart, Bun, Java | Mise; `machine update-tools` |
| Rust | Mise core Rust backend delegates installation to rustup; same update command; project rust-toolchain files enabled |
| bat, rg, fd, delta, dust, jless, zellij, qsv | Mise registry prebuilt releases; no self-updaters. Omarchy keeps native bat/rg/fd (required by its desktop) |
| Codex / Claude | Self-managed; no repository installation, version pins, update controls or cleanup. Historical llms entry points only print a notice |
| git-trim | Mise `cargo:` backend, locked upstream crate dependencies; source build once per version |
| gcloud 591.0.0 | Mise HTTP backend, explicit official archive URL and lock; no `gcloud components update` |
| Bundler | Selected Ruby's gems; toolchain/bundler.version (4.0.23) ensured during setup/apply; projects use lockfile-compatible Bundler |
| Ruby / JS / Python application dependencies | Bundler / pnpm / uv respectively; no machine-level dependency updates |
| CocoaPods and xcodeproj | Project Gemfile + Gemfile.lock, invoke `bundle exec pod`; no global Brew/gem duplicate |
| Native libraries, Git, gh, AWS CLI, R/r2u, system utilities | Existing native package manifests/ecosystem; `machine update-system` |
| eza | Native exception: Homebrew on Mac, Omarchy/pacman on Linux; registry vfox plugin fails metadata loading on 2026.11.0 |
| macOS GUI apps, Xcode, Android SDKs | Homebrew casks / Apple App Store / Android Studio SDK Manager |
| Shell prompt/plugins | Existing cached zinit plugin directories; explicitly update through zinit in a maintenance session, never shell startup |
| mise itself | Existing Homebrew, official Ubuntu apt repository, or Omarchy/pacman installation; system update owns it |
| Services | Native service manager; independent pinned deployment runtimes |

The eza GitHub backend was also rejected: its generic asset matching selected a man-page archive
on macOS. Eza's native exception avoids an unreliable installer. There is **no Linuxbrew exception**.
OS-owned executables that provide platform services remain installed; selection through mise does
not justify removing system Python, Ruby, Rust, compilers or libraries. Existing duplicate user
installations remain for rollback, but no setup/update command installs a second independent copy.

## Configuration and selection

`toolchain/config.toml` is common; `config.macos.toml`, `config.linux.toml`,
`config.omarchy.toml`, `config.ubuntu.toml`, `config.workstation.toml` and `config.server.toml`
are independent mise environment modules. Platform-only files can be intentionally empty.
The macOS module supplies mise bat/fd/ripgrep; Omarchy keeps its existing native copies.
`miserc.toml` disables automatic environment selection. `machine select` writes ignored
`toolchain/miserc.local.toml` with one of:

| Profile | Environments, in order |
| --- | --- |
| macos-workstation | macos, workstation |
| omarchy-workstation | linux, omarchy, workstation |
| ubuntu-server | linux, ubuntu, server |

`machine setup` links the **whole** global mise directory to this checkout only after installation
succeeds. Thus ordinary mise global commands see the same source of truth. Machine-local tool
choices belong in ignored `config.local.toml` (and its local lock), not a second global file.
Keep one checkout per machine. Do not share this checkout's local selector over a network mount.
Review/port previous global entries from the automatic backup; unknown local tools are not guessed.
The known gcloud archive entry has been made reproducibly installable rather than retaining an
HTTP declaration with no URL. Project configuration still overrides global tool defaults.

Check selection with `machine plan`, then `mise config` in a new shell after activation.
Maintenance fixes its working directory, config directory and ceiling, excludes `/etc/mise`, and
clears session version overrides. It does not use `mise upgrade --global`, whose scope would also
include system config. `MISE_ENV` remains available for explicit project sessions outside maintenance.
No conf.d recursion or directory-name-based conditional behavior is assumed.

## Setup and regular maintenance

```sh
./cli_tools/machine select macos-workstation  # or omarchy-workstation / ubuntu-server
./cli_tools/machine native                  # optional if prerequisites already installed
./cli_tools/machine plan
./cli_tools/machine setup
```

On macOS first install Homebrew and Apple Command Line Tools. Native dependencies are declared
in the macOS module using mise bootstrap packages. On Ubuntu, `native` uses apt and the existing
official mise apt bootstrap. Omarchy reuses its mise and runs its complete update workflow before
installing missing build prerequisites; never `pacman -Sy` or a replacement generic system upgrade.
Native package changes are explicit and separate from a warm tool apply.

```sh
./cli_tools/machine sync          # normal: clean tree, pull --ff-only, execute updated apply script
./cli_tools/machine update-tools  # opt-in version advance inside policies; review/commit toolchain/*.lock
```

`sync` refuses dirty or untracked work, including an unignored `.serena/`; it never resets,
stashes, force-pulls or pushes. Keep unrelated machine scratch directories out of Git using your
local `.git/info/exclude` if appropriate. `apply` uses `--locked` and does not advance the locks.
Global default updates can change projects that inherit them; pin important projects first.
`machine upgrade-versions node@26` deliberately rewrites only named tool policies using mise's
`--bump --no-prune`; every argument must explicitly name tool@version. Choose the new version yourself.
Alternatively edit the relevant module and run `machine lock`, review the lock, then apply.
`lock` refreshes metadata without re-resolving matching locked versions; `update-tools` advances them.
No routine command passes `upgrade --bump`, updates application dependencies or deletes old versions.
Commit new/changed locks with policy edits.

`machine update-system` is separate: Homebrew update/upgrade plus an Apple update listing on Mac;
apt update/upgrade on Ubuntu (review held packages/reboot notices separately); full `omarchy update`
on Omarchy, including migrations and config maintenance. Omarchy also upgrades mise tools, so do
not run `update-tools` again that cycle. It inherits this checkout's isolated configuration and
pruning prohibition. App Store and Android SDK updates remain explicit in their owning interfaces.

`machine lab` performs `uv sync --locked` for `packages/lab-python` using mise Python 3.13;
then use `uv run --project ~/mysettings/packages/lab-python jupyter lab`. It creates that project's
`.venv`, never replaces `~/p313` and is not part of setup or routine updates.

## Existing-machine migration and rollback

1. Inventory before switching: `type -a mise ruby bundle node pnpm corepack python uv flutter dart`,
   `mise config`, `mise ls --installed`, `bundle config list`; inspect `.ruby-version`, `.ruby-gemset`,
   `.rvmrc`, RVM hooks/@global gems, `.fvmrc`, `.fvm/fvm_config.json`, `.tool-versions`, packageManager,
   engines, requires-python, lockfiles, IDE paths and service unit files in each relevant project.
   Do not print credentials from npm/pip/environment files. Pin existing required versions first.
2. Select the machine, run `plan` and `apply`. This installs without replacing the active global
   configuration or shell files. Verify through the isolated config, e.g.
   `MISE_CONFIG_DIR="$PWD/toolchain" mise -C toolchain exec -- ruby -v`.
3. Run `machine activate` (or setup). It backs up the previous mise directory and shell/npmrc
   files under `~/.local/state/mysettings/<timestamp>-<pid>/` and links the repo. The shell files
   are still untouched. Keep that backup path and a terminal with the old environment open.
4. Review `chezmoi diff` before `chezmoi apply`, or manually back up/copy `_zshrc` to `~/.zshrc`.
   The templates remove competing manager initialization. For a minimal shell, keep exactly one
   `eval "$(mise activate zsh)"` (or bash) at the end of the existing rc file. Omarchy users retain
   its supported shell configuration and existing mise hook; do not overwrite it with the zsh template.
   Disable RVM/NVM/Volta/FVM/standalone-pnpm blocks and global venv activation only after checks pass.
   Inspect `.zlocal`, `.zshrc.local`, login files and `/etc/profile.d` too: these are not auto-rewritten.
5. Open a fresh shell; run `machine doctor`, `mise config`, `type -a` and project workflows. Remove
   stale GEM_HOME/GEM_PATH and inappropriate global BUNDLE_PATH; do not transplant RVM gemsets or
   compiled extensions. Reinstall gems with the new Ruby/Bundler. Keep useful @global CLI tools in
   project Gemfiles or declare a suitable mise tool. Binstubs may contain old absolute paths.

Rollback: unlink the `~/.config/mise` symlink (only after confirming it points here), move the
backup's `mise` directory back, restore only shell files you actually changed, and open a fresh
shell. Old installations, virtual environments and services were retained. For a former absent
mise config, simply remove the symlink. Do not delete the checkout while the link is in use.

`machine cleanup` is **preview-only**. Mise's default upgrade pruning is disabled in both config
and maintenance environment. Before manually removing versions, inspect project/IDE/service/venv
absolute paths: mise cannot discover every external reference. `mise prune --dry-run` lists candidates;
remove only individually confirmed unused versions. Native package uninstall/autoremove is separate.

## Project workflows

**Ruby:** preserve Gemfile.lock, including `BUNDLED WITH`. Mise's default Bundler 4.0.23 supports
this Ruby; older application Rubies may require Bundler 2.x. Install the lockfile's compatible version
inside that project's selected Ruby, then `bundle _VERSION_ install` and `bundle exec ...`.
Do not use a global `gem:bundler` environment to run another Ruby's application. For iOS, keep
`gem 'cocoapods'` and `gem 'xcodeproj'` in the app Gemfile; retain its existing versions/lock.

**Node/pnpm:** declare Node and the exact packageManager version in project mise config; preserve
pnpm-lock.yaml and run `pnpm install --frozen-lockfile` / `pnpm run <script>`. Machine pnpm 12 uses
`pmOnFail=error`, `runtime=false`, `runtimeOnFail=error`; older pnpm gets the supported manager-version
switching settings. Align pnpm major with the project's lockfile. Disable Corepack shims using the
Node installation that created them, after recording paths. Remove standalone PNPM_HOME from rc
files after verifying mise pnpm. Do not run `pnpm setup`, `pnpm env use`, `pnpm self-update`, enable
Corepack, or configure useNodeVersion/devEngines runtime downloads in migrated projects.
TypeScript/ESLint/test runners remain project dependencies.

**Python:** mise selects Python; uv has `python-downloads=never` and `python-preference=only-system`
(uv calls externally installed interpreters “system”; this includes mise). No global UV_PYTHON or
venv path is forced. In each project use `uv sync --locked --python "$(mise which python)"`;
then `uv run ...`. Preserve requires-python/uv.lock. Inspect `.venv/pyvenv.cfg` and `readlink .venv/bin/python`;
rename/recreate only venvs pointing to retired or missing interpreters. The retained p312 environment
is one such candidate, not a template to copy. Never use OS-wide pip or `uv python install`.

**Flutter:** the backend does not translate FVM conventions. Copy the exact SDK version from
`.fvmrc` or `.fvm/fvm_config.json` into the app's mise.toml; preserve custom forks/channels until
an equivalent backend has been tested. Replace `fvm flutter` with `flutter` (including CI).
Run `mise install`, `mise which flutter`, `mise which dart`, `flutter --version`, `dart --version`.
From the **project directory**, `mise where flutter` returns the SDK directory an IDE needs.
For editors needing a stable relative path, `mkdir -p .sdk; ln -s "$(mise where flutter)" .sdk/flutter`
and gitignore `.sdk/`; point the editor at `.sdk/flutter` and bundled `bin/cache/dart-sdk`.
Refresh this link after project version changes. Do not commit resolved absolute SDK paths or
run `flutter upgrade` on mise installations. Android Studio SDK Manager/Xcode setup remains separate.

## Linux build isolation and linkage

No Linux shell template initializes Homebrew. Known inherited Linuxbrew PATH entries are removed;
other project flags are preserved. Before native builds/updates the maintenance command rejects
Linuxbrew/Homebrew references in PATH, compiler selectors, C/C++/preprocessor/linker flags,
CPATH, LIBRARY_PATH, LD_LIBRARY_PATH, PKG_CONFIG_PATH/LIBDIR, CMAKE_PREFIX_PATH and Ruby/Python
configure options. It also refuses **any discoverable brew** on Linux: ruby-build 20261023 probes
Homebrew OpenSSL through `brew --prefix` even without explicit flags. That builder has no
`RUBY_BUILD_SKIP_HOMEBREW` control; none is invented here. Clean the stale global source and open
a clean shell. Do not globally erase intentional project build variables.

After removing Linuxbrew discovery, inspect existing native linkage, not just PATH:
`ldd "$(mise which ruby)"`, `ldd "$(mise which python)"`, and relevant `openssl.so`, `_ssl*.so`,
`psycopg*.so` or other extension modules. Locate them with the selected interpreter, then use ldd.
On Mac use `otool -L`; Apple/Homebrew libraries are intentional there. Reinstall only interpreters
or extensions actually linked to the retired prefix; reinstall project dependencies through their
owner. No Linux interpreter was rebuilt during this Mac-only migration. Scoped build flags belong
in the specific tool's `install_env` or project config, not global shell startup.

## Server execution

There are no application services to migrate in this repository. Existing Docker/SSH/OS service
management is unchanged and is not invoked by developer maintenance. Server modules supply only
administrator tool defaults. See `examples/server/` for an **undeployed** Ruby systemd example:
service account `mailapp`, working directory `/srv/mailapp/current`, explicit production environment,
absolute versioned executable and PATH. No shell activation or mise install runs at service startup.

During an explicitly authorized deployment, create that service account, copy the app's own pinned
mise config/lock, install as that account using an isolated config directory, and run Bundler with
its lockfile-required version and frozen dependencies. Verify `mise which ruby` resolves the exact
path used in the unit, then execute the app's smoke check as that account. Unit installation and
restart are separate deployment actions. Node/Python services follow the same pattern with an
absolute Node binary or a project venv built from a pinned interpreter. Keep deployment config
out of the administrator's global directory and outside this checkout's update scope.

## References

Validated against installed mise 2026.11.0 help and current official documentation:
[mise configuration](https://mise.jdx.dev/configuration.html),
[machine modules](https://mise.jdx.dev/bootstrap/modules.html),
[upgrade/pruning](https://mise.jdx.dev/cli/upgrade.html),
[Ruby](https://mise.jdx.dev/lang/ruby.html), [Python](https://mise.jdx.dev/lang/python.html),
[Rust](https://mise.jdx.dev/lang/rust.html),
[uv interpreter discovery](https://docs.astral.sh/uv/concepts/python-versions/),
[pnpm CLI settings](https://pnpm.io/settings/cli),
[Omarchy development tools](https://omarchy.org/manual/development-tools/),
[Omarchy updates](https://omarchy.org/manual/updates/).

## Verification results (2026-11-07)

Executed on **macOS arm64**, with mise 2026.11.0. Real user global config and shell files were
not activated/replaced. Tool installation is non-destructive: 13 missing mise tool versions were
installed in the first pass (70.8 seconds), plus Python 3.13.18 and the lab project `.venv`.
Mise's Rust backend installed the pinned toolchain and updated its rustup helper from 1.29.0 to
1.29.3 as part of its normal install; it did not remove old toolchains. No OS packages or services
were changed. No project outside this repository was edited.

- All three module combinations loaded the intended files; Ubuntu server excludes workstation SDKs.
  Omarchy's native bat/fd/ripgrep were confirmed against its official package list and excluded from
  mise declarations. This was configuration validation on Mac, not Linux execution.
- Fresh interactive login zsh using the repository template and a temporary home, plus explicit
  noninteractive mise exec, resolved Ruby 3.4.12/Bundler 4.0.23, Node 26.9.0, pnpm 12.4.2,
  Python 3.14.10, uv 0.13.6 and Flutter 3.47.5/Dart 3.13.4 from the intended installations.
  Flutter and Dart paths share the selected SDK; its actual SDK/cache directories exist.
- Temporary Bundler lock/exec with OpenSSL passed. Temporary pnpm frozen install and package script
  passed; a pnpm 11 declaration correctly failed under pnpm 12 without a download/switch.
- The actual lab `uv sync --locked` passed on Python 3.13.18; a Polars aggregation and SSL import
  passed. Existing p312/p313/project virtual environments were retained.
- Real `apply` and repeated warm applies left canonical locks byte-identical. A warm apply took
  **0.36–0.51 seconds**, installed zero tools and checked 23 declared versions. No dependency installs,
  runtime rebuilds or forced cache refresh occur on that path.
- Setup executed twice against a temporary config/state destination: one link, one backup, no rc
  edits. Current user's global config remains the original directory. Both shell sources match.
- Update dry-run from an unrelated temporary project with a Node 20 override selected only this
  repository's updates (Node 26, pnpm 12, uv 0.13). The caller's sentinel lock and repository locks
  remained unchanged. No actual tool version update was performed.
- ShellCheck passed for the new interface/wrappers; Bash/zsh syntax, all Ansible YAML, module TOML
  and lock parsing passed. `git diff --check` passed. No Ansible deployment was run.
- Ruby executable/OpenSSL extension and Python executable linkage checks showed Apple system
  libraries, with no Linuxbrew references. No interpreter rebuild was indicated on this Mac.
- Actual current-shell doctor still reports old Homebrew Ruby/FVM, FVM SDK paths, PNPM_HOME and an
  inherited project VIRTUAL_ENV. The clean-shell test confirms the new configuration works;
  disabling old initialization remains the explicit migration step, not a hidden host mutation.

Not verified: Ubuntu/Omarchy runtime installation, apt/pacman/Homebrew upgrades, real service
startup, an actual application's native extensions, Android/iOS builds, GUI IDE behavior or remote
hosts. Workstation artifacts are currently available for **macos-arm64 and linux-x64**. Upstream
lacks these locked Flutter releases/jless on linux-arm64 and delta/qsv releases on macos-x64;
those workstation architectures require reviewed native/backend overrides before apply, not a claim
of cross-platform success. Common server runtime locks cover Linux x64/arm64. Native eza and
system package installation are documented exceptions, not silently duplicated mise installations.

### Agent ownership correction

Codex and Claude were subsequently removed from mise declarations and locks at the owner's request.
No auto-updater suppression is configured. The historical verification counts above describe the
earlier run; the current Mac profile has 21 declared tool versions. Existing agent installations
were retained, and no self-updater was invoked. Shell authentication checks may still report agent
login status; they do not own installation or version management.

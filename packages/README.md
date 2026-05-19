# `packages/` — canonical package lists

Single source of truth for what gets installed on each platform.
Plain YAML arrays so both bash and Ansible can read them without
bootstrapping a YAML parser first (apt/brew install yq is a chicken-
and-egg problem for the kit itself).

## Files

| File | Consumer | Manager | Contents |
|------|----------|---------|----------|
| `linux_base.yml` | `ubuntu/my_ubuntu_setup.sh`, `automated/ubuntu_kitting.yml` | apt | Base system + modern CLI for Ubuntu |
| `darwin_brew_system.yml` | `mac/setup_cli_tools.sh` | brew (formula) | System libs, GNU utils, modern CLI for Mac |
| `darwin_brew_casks.yml` | `mac/setup_cli_tools.sh` | brew (cask) | GUI apps |
| `darwin_brew_fonts.yml` | `mac/setup_cli_tools.sh` | brew (cask) | Fonts |
| `darwin_brew_r_build_deps.yml` | `mac/brew_tidyverse.sh` | brew (formula) | Headers for R/tidyverse source compile |
| `lab_python.yml` | `common/install_uv_and_p313.sh` | uv pip | DS preload for `~/p313` (cross-platform) |

## Format

Top-level YAML array, one package per line:

```yaml
# section comment
- package-name
- another-package
```

Comments + blank lines are allowed and grouped by purpose. Order within
a section is alphabetical when convenient, but not enforced.

## Adding a package

1. Edit the relevant file. Put it under the right section comment, or
   add a new section.
2. Re-run the kit on a representative host. The script will pick up the
   addition automatically.
3. If the package belongs on both Mac and Linux, add it to **both**
   `linux_base.yml` and `darwin_brew_system.yml` — the package-manager
   names sometimes differ (`fd-find` vs `fd`, `ripgrep` vs `rg`).

## Consumer recipes

### bash

```bash
PACKAGES_DIR="$(dirname "$(readlink -f "$0")")/../packages"
xargs apt-get install -y < <(awk '/^- / { print $2 }' "$PACKAGES_DIR/linux_base.yml")
```

### Ansible

```yaml
vars:
  base_packages: "{{ lookup('file', playbook_dir + '/../packages/linux_base.yml') | from_yaml }}"
tasks:
  - name: Install base apt packages
    ansible.builtin.apt:
      name: "{{ base_packages }}"
      state: present
```

## Why no metadata format

We deliberately chose plain arrays over a richer schema (per-package
`source:`, `notes:` fields, etc.). Reasons:

- **Grep-friendly.** `grep ripgrep packages/*.yml` immediately tells you
  which OSes install it.
- **No parser dep.** `awk '/^- /'` works without yq on a freshly booted
  box. The kit can't depend on yq because yq is one of the things the
  kit installs.
- **Diffs read cleanly.** Adding/removing a line shows up as one-line
  changes, not nested YAML noise.

If a package ever genuinely needs metadata (an obscure flag, a tap, a
version pin), prefer to wrap it in the consumer script with a clearly
named special case rather than expanding this format. The `packages/`
files should stay boring lists.

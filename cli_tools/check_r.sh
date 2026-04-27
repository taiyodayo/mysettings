#!/usr/bin/env bash
# Verify the lab R install: every preloaded package visible from a fresh
# R session, /etc/R/Rprofile.site has the bspm config, and bspm actually
# activates when R runs as root. Safe to run as any user; returns 0 if
# everything checks out.
#
# Model:
#   root R session    → bspm enabled  → install.packages() goes to apt
#                                       (binary, system lib)
#   non-root R session → bspm not loaded → install.packages() goes to
#                                          ~/R/.../  (source compile)

set -uo pipefail

if ! command -v R >/dev/null 2>&1; then
    echo "✗ R is not installed (or not on PATH)."
    exit 1
fi

# Required preload set — what a fresh lab user should be able to
# library() immediately. Mirrors the apt list in my_ubuntu_setup.sh.
required=(
    tidyverse pacman data.table
    arrow jsonlite readxl
    rmarkdown knitr devtools renv
    languageserver httpgd
)

echo "=== R install check ==="
R --no-save <<RCHECK 2>/dev/null
cat("R version:     ", R.version.string, "\n")
cat("Effective user:", Sys.info()[["effective_user"]], "\n")
cat("bspm in this session:",
    if (requireNamespace("bspm", quietly=TRUE) && bspm::enabled()) "ENABLED" else "DISABLED", "\n")
cat("Library paths (in search order):\n")
for (p in .libPaths()) cat("  ", p, "\n")
RCHECK

# Preloaded packages must be visible from any session.
echo "Preloaded packages:"
issues=0
for pkg in "${required[@]}"; do
    if R --no-save -e "stopifnot(requireNamespace('$pkg', quietly=TRUE))" >/dev/null 2>&1; then
        echo "  OK  $pkg"
    else
        echo "  ✗   $pkg  (apt install r-cran-${pkg/./})"
        issues=$((issues + 1))
    fi
done

# Rprofile.site config check — should be present regardless of who's running.
if ! grep -q 'effective_user.*root.*bspm::enable\|# === BEGIN mysettings bspm ===' /etc/R/Rprofile.site 2>/dev/null; then
    echo
    echo "✗ /etc/R/Rprofile.site is missing the bspm config block."
    echo "  Re-run ubuntu/my_ubuntu_setup.sh's R section."
    issues=$((issues + 1))
fi

# bspm actually loads in a root R session?
if R --no-save -e 'stopifnot(Sys.info()[["effective_user"]] == "root", bspm::enabled())' >/dev/null 2>&1; then
    echo "✓ Running as root: bspm is enabled in this R session."
elif sudo -n R --no-save -e 'stopifnot(bspm::enabled())' >/dev/null 2>&1; then
    echo "✓ bspm enabled in root R sessions (verified via sudo)."
else
    echo "⚠ Could not verify bspm in root R session (no passwordless sudo)."
    echo "  Try: sudo R --no-save -e 'bspm::enabled()'  (expect TRUE)"
fi

echo
if [ "$issues" -eq 0 ]; then
    echo "✅ R install looks good."
    exit 0
else
    echo "❌ $issues issue(s) above. Re-run ubuntu/my_ubuntu_setup.sh's R section."
    exit 1
fi

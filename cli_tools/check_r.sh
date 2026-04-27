#!/usr/bin/env bash
# Verify the lab R install: bspm enabled, every preloaded package visible
# from a fresh R session, library paths in the expected order.
# Returns 0 if everything checks out, 1 otherwise. Safe to run anytime.

set -uo pipefail

if ! command -v R >/dev/null 2>&1; then
    echo "✗ R is not installed (or not on PATH)."
    exit 1
fi

# Required preload set — the packages a new lab user should be able to
# library() the moment they SSH in. Edit here when you change the deploy
# script's apt list.
required=(
    tidyverse
    pacman
    data.table
    arrow
    jsonlite
    readxl
    rmarkdown
    knitr
    devtools
    renv
    languageserver
    httpgd
)

echo "=== R install check ==="
R --no-save <<RCHECK 2>/dev/null
cat("R version:    ", R.version.string, "\n")
cat("bspm:         ", if (requireNamespace("bspm", quietly=TRUE) && bspm::enabled()) "ENABLED" else "DISABLED", "\n")
cat("Library paths (in search order):\n")
for (p in .libPaths()) cat("  ", p, "\n")
RCHECK

echo "Preloaded packages:"
missing=0
for pkg in "${required[@]}"; do
    if R --no-save -e "stopifnot(requireNamespace('$pkg', quietly=TRUE))" >/dev/null 2>&1; then
        echo "  OK  $pkg"
    else
        echo "  ✗   $pkg  (not installed system-wide — apt install r-cran-$pkg)"
        missing=$((missing + 1))
    fi
done

# bspm enabled?
if ! R --no-save -e 'stopifnot(bspm::enabled())' >/dev/null 2>&1; then
    echo
    echo "✗ bspm is not enabled in fresh R sessions."
    echo "  Add to /etc/R/Rprofile.site:"
    echo "    suppressMessages(bspm::enable())"
    echo "    options(bspm.version.check=FALSE)"
    missing=$((missing + 1))
fi

echo
if [ "$missing" -eq 0 ]; then
    echo "✅  All preloaded packages installed and bspm is enabled."
    exit 0
else
    echo "❌  $missing issue(s) above. Re-run ubuntu/my_ubuntu_setup.sh's R section,"
    echo "   or apt install the missing r-cran-* packages."
    exit 1
fi

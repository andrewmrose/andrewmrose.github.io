#!/usr/bin/env bash
# Publish workflow for this Distill site (GitHub Pages from docs/).
#
# Usage:
#   ./publish.sh                    Git pull, then render_site() only
#   ./publish.sh --push             Same, then commit + push
#   ./publish.sh --install-deps     Install R packages for THIS Rscript, then exit
#   ./publish.sh --install-deps --push   Install packages, then full publish flow
#
# Requires: git, R (see --install-deps). Make executable: chmod +x publish.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

DO_PUSH=false
DO_INSTALL_DEPS=false
for arg in "$@"; do
  case "$arg" in
    --push) DO_PUSH=true ;;
    --install-deps) DO_INSTALL_DEPS=true ;;
    *)
      echo "Unknown option: $arg" >&2
      echo "Usage: $0 [--install-deps] [--push]" >&2
      exit 1
      ;;
  esac
done

find_rscript() {
  # Prefer CRAN’s .pkg R: it supports CRAN macOS binaries. Homebrew R often only builds from source.
  local r
  for r in /Library/Frameworks/R.framework/Resources/bin/Rscript \
           /opt/homebrew/bin/Rscript \
           /usr/local/bin/Rscript; do
    if [[ -x "$r" ]]; then
      echo "$r"
      return 0
    fi
  done
  r="$(command -v Rscript 2>/dev/null || true)"
  if [[ -n "${r:-}" && -x "$r" ]]; then
    echo "$r"
    return 0
  fi
  echo "Error: Rscript not found. Install R from https://cran.r-project.org/bin/macosx/ or ensure Rscript is on your PATH." >&2
  exit 1
}

RSCRIPT="$(find_rscript)"

install_r_deps() {
  echo "==> Installing R packages into the library used by: $RSCRIPT"
  # Helps clang find libc++ when compiling from source (macOS / Xcode SDK quirks)
  if [[ "$(uname -s)" == "Darwin" ]]; then
    export SDKROOT="${SDKROOT:-$(xcrun --sdk macosx --show-sdk-path 2>/dev/null || true)}"
    [[ -n "${SDKROOT:-}" ]] && echo "==> SDKROOT=$SDKROOT"
  fi
  "$RSCRIPT" --vanilla "$ROOT/scripts/install-r-deps.R"
}

require_rmarkdown() {
  if "$RSCRIPT" -e 'if (!requireNamespace("rmarkdown", quietly = TRUE)) quit(save = "no", status = 2)' 2>/dev/null; then
    return 0
  fi
  echo "" >&2
  echo "Error: R package 'rmarkdown' is not installed for this R:" >&2
  echo "  $RSCRIPT" >&2
  echo "" >&2
  echo "Run (prefers macOS binaries, see scripts/install-r-deps.R):" >&2
  echo "  $0 --install-deps" >&2
  echo "" >&2
  echo "If installs fail with 'cstring' / 'cstdlib' file not found, fix Xcode CLT or use CRAN’s .pkg R:" >&2
  echo "  https://cran.r-project.org/bin/macosx/" >&2
  exit 1
}

BRANCH="$(git branch --show-current 2>/dev/null || true)"
if [[ -z "$BRANCH" ]]; then
  echo "Error: not in a git repository." >&2
  exit 1
fi

echo "==> Using $RSCRIPT"

if $DO_INSTALL_DEPS; then
  install_r_deps
  if ! $DO_PUSH; then
    echo "==> Done. Next: ./publish.sh   or   ./publish.sh --push"
    exit 0
  fi
fi

require_rmarkdown

# --autostash: stash local edits, pull --rebase, then re-apply (needs Git ≥ 2.9)
echo "==> git pull --rebase --autostash origin $BRANCH"
git pull --rebase --autostash origin "$BRANCH"

echo "==> rmarkdown::render_site()"
"$RSCRIPT" -e "setwd('$ROOT'); rmarkdown::render_site(encoding = 'UTF-8')"

if $DO_PUSH; then
  git add -A
  if git diff --staged --quiet; then
    echo "==> No file changes after render; pushing to sync remote (if any)"
  else
    echo "==> Committing rendered site and other local changes"
    git commit -m "Rebuild site $(date -u +%Y-%m-%dT%H:%MZ)"
  fi
  git push origin "$BRANCH"
  echo "==> Done."
else
  echo "==> Render finished. To commit and push: ./publish.sh --push"
fi

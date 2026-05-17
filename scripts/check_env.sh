#!/usr/bin/env bash
set -euo pipefail

missing=0

check_command() {
  local name="$1"
  if command -v "$name" >/dev/null 2>&1; then
    printf "[ok] %s: %s\n" "$name" "$(command -v "$name")"
  else
    printf "[missing] %s\n" "$name"
    missing=1
  fi
}

check_command git
check_command colmap

if command -v sips >/dev/null 2>&1; then
  printf "[ok] sips: %s\n" "$(command -v sips)"
else
  printf "[info] sips not found; HEIC conversion script may not work on this system.\n"
fi

if [[ "$missing" -ne 0 ]]; then
  cat <<'MSG'

Install COLMAP before running reconstruction. On macOS, try one of:

  brew install colmap
  conda install -c conda-forge colmap

MSG
  exit 1
fi

printf "\nEnvironment looks ready.\n"


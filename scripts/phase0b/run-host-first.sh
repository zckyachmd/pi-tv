#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cargo_bin="${CARGO_HOME:-$HOME/.cargo}/bin/cargo"
if [[ ! -x "$cargo_bin" ]]; then
  echo "rustup-managed cargo not found at CARGO_HOME/bin/cargo" >&2
  exit 1
fi
if [[ ! -x "${CHROME_BIN:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}" ]]; then
  echo "Google Chrome executable not found; set CHROME_BIN" >&2
  exit 1
fi

export PITV_PORT="${PITV_PORT:-8765}"
export CHROME_BIN="${CHROME_BIN:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
umask 077
if [[ -z "${PITV_PROFILE_DIR:-}" ]]; then
  export PITV_PROFILE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/pitv-host-first.XXXXXX")"
  cleanup_profile=1
else
  cleanup_profile=0
fi
cleanup() {
  if [[ "$cleanup_profile" == 1 ]]; then rm -rf "$PITV_PROFILE_DIR"; fi
}
trap cleanup EXIT
"$cargo_bin" run --locked --manifest-path "$repo_root/prototypes/host-first/daemon/Cargo.toml"

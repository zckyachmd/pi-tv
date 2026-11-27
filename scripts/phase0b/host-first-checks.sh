#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cargo_bin="${CARGO_HOME:-$HOME/.cargo}/bin/cargo"
"$cargo_bin" fmt --manifest-path "$repo_root/prototypes/host-first/daemon/Cargo.toml" --check
"$cargo_bin" test --manifest-path "$repo_root/prototypes/host-first/daemon/Cargo.toml" --locked
"$cargo_bin" clippy --manifest-path "$repo_root/prototypes/host-first/daemon/Cargo.toml" --locked -- -D warnings

ios_sdk="$(xcrun --sdk iphonesimulator --show-sdk-path)"
swift build --package-path "$repo_root/prototypes/host-first/ios-swift" \
  --triple arm64-apple-ios27.2-simulator --sdk "$ios_sdk"
python3 "$repo_root/scripts/phase0b/ios-simulator-smoke.py"
node "$repo_root/scripts/phase0b/chrome-runtime-smoke.mjs"

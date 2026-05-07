#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
swift_dir="$(cd "$script_dir/.." && pwd)"
workspace_dir="$(cd "$swift_dir/.." && pwd)"

profile="${1:-debug}"
target_dir="$workspace_dir/target/$profile"

case "$(uname -s)" in
  Darwin)
    lib_ext="dylib"
    ;;
  Linux)
    lib_ext="so"
    ;;
  *)
    echo "unsupported platform: $(uname -s)" >&2
    exit 1
    ;;
esac

pushd "$workspace_dir" >/dev/null
if [[ "$profile" == "release" ]]; then
  cargo build -p quaynor-uniffi --release
else
  cargo build -p quaynor-uniffi
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

cargo run -p quaynor-uniffi --bin uniffi-bindgen -- generate \
  --library "$target_dir/libquaynor_uniffi.$lib_ext" \
  --language swift \
  --out-dir "$tmp_dir"
popd >/dev/null

mkdir -p "$swift_dir/Sources/CQuaynorFFI" "$swift_dir/Sources/QuaynorFFI"

install -m 0644 "$tmp_dir/CQuaynorFFI.h" "$swift_dir/Sources/CQuaynorFFI/CQuaynorFFI.h"
install -m 0644 "$tmp_dir/CQuaynorFFI.modulemap" "$swift_dir/Sources/CQuaynorFFI/module.modulemap"
install -m 0644 "$tmp_dir/QuaynorFFI.swift" "$swift_dir/Sources/QuaynorFFI/QuaynorFFI.swift"

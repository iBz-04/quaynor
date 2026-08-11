#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kotlin_dir="$(cd "$script_dir/.." && pwd)"
workspace_dir="$(cd "$kotlin_dir/.." && pwd)"

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

cargo run -p quaynor-uniffi --bin uniffi-bindgen -- generate \
  --library "$target_dir/libquaynor_uniffi.$lib_ext" \
  --language kotlin \
  --out-dir "$kotlin_dir/common/generated"
popd >/dev/null

# The Message enum has a variant also named Message. Inside the generated
# `sealed class Message { ... }`, the unqualified supertype reference
# `: Message()` resolves to the nested variant class instead of the outer
# sealed class, which Kotlin rejects as an inheritance cycle. Fully qualify
# the supertype for the variant declarations.
generated_kt="$kotlin_dir/common/generated/uniffi/quaynor/quaynor.kt"
perl -pi -e 's/\) : Message\(\)/) : uniffi.quaynor.Message()/' "$generated_kt"

echo "Bindings written to $generated_kt"

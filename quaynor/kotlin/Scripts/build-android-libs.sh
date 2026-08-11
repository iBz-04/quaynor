#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kotlin_dir="$(cd "$script_dir/.." && pwd)"
workspace_dir="$(cd "$kotlin_dir/.." && pwd)"

profile="${1:-release}"

# Must match `minSdk` in android/build.gradle.kts.
api_level=26

if ! command -v cargo >/dev/null 2>&1; then
  echo "cargo not found" >&2
  exit 1
fi

if ! command -v cargo-ndk >/dev/null 2>&1; then
  echo "cargo-ndk not found — install it with: cargo install cargo-ndk" >&2
  exit 1
fi

# cargo-ndk locates the toolchain through one of these, in order.
if [[ -z "${ANDROID_NDK_HOME:-}" && -z "${ANDROID_NDK_ROOT:-}" ]]; then
  sdk_root="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
  # Pick the highest installed NDK version.
  detected="$(ls -d "$sdk_root"/ndk/* 2>/dev/null | sort -V | tail -1 || true)"
  if [[ -z "$detected" ]]; then
    echo "No Android NDK found under $sdk_root/ndk." >&2
    echo "Install it via Android Studio (SDK Manager -> SDK Tools -> NDK)," >&2
    echo "or set ANDROID_NDK_HOME to an existing NDK." >&2
    exit 1
  fi
  export ANDROID_NDK_HOME="$detected"
  echo "Using NDK: $ANDROID_NDK_HOME"
fi

for target in aarch64-linux-android x86_64-linux-android; do
  if ! rustup target list --installed | grep -qx "$target"; then
    echo "Missing Rust target $target — add it with: rustup target add $target" >&2
    exit 1
  fi
done

# The :android module reads jniLibs from its build directory, so `gradlew clean`
# wipes these. Stage them after any clean and before assembling the AAR.
jni_dir="$kotlin_dir/android/build/jniLibs"
rm -rf "$jni_dir"
mkdir -p "$jni_dir"

build_args=(build -p quaynor-uniffi)
if [[ "$profile" == "release" ]]; then
  build_args+=(--release)
fi

pushd "$workspace_dir" >/dev/null
cargo ndk \
  --platform "$api_level" \
  --target arm64-v8a \
  --target x86_64 \
  --output-dir "$jni_dir" \
  "${build_args[@]}"
popd >/dev/null

echo
echo "Native libraries staged for the AAR:"
find "$jni_dir" -name '*.so' -exec ls -lh {} \; | awk '{print "  " $NF " (" $5 ")"}'
echo
echo "Next: build or publish the AAR without cleaning first, e.g."
echo "  ./gradlew :android:assembleRelease"

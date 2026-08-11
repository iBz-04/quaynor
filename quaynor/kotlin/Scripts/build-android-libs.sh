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

ndk_home="${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-${ANDROID_NDK:-${NDK_ROOT:-}}}}"

if [[ -z "$ndk_home" ]]; then
  sdk_root="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
  # Pick the highest installed NDK version.
  ndk_home="$(ls -d "$sdk_root"/ndk/* 2>/dev/null | sort -V | tail -1 || true)"
  if [[ -z "$ndk_home" ]]; then
    echo "No Android NDK found under $sdk_root/ndk." >&2
    echo "Install it via Android Studio (SDK Manager -> SDK Tools -> NDK)," >&2
    echo "or set ANDROID_NDK_HOME to an existing NDK." >&2
    exit 1
  fi
fi

# Strip any trailing slash, then export every spelling the toolchain might read.
# cargo-ndk itself uses ANDROID_NDK_HOME, but llama-cpp-sys-2's build script only
# checks ANDROID_NDK / NDK_ROOT / ANDROID_NDK_ROOT and panics without one of them.
ndk_home="${ndk_home%/}"
export ANDROID_NDK_HOME="$ndk_home"
export ANDROID_NDK_ROOT="$ndk_home"
export ANDROID_NDK="$ndk_home"
export NDK_ROOT="$ndk_home"
echo "Using NDK: $ndk_home"

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

if [[ "$profile" == "release" ]]; then
  # Debug symbols roughly a third of the shipped size and are useless to consumers.
  # The unstripped copies stay under target/<triple>/release/ for symbolicating crashes.
  strip_bin="$(ls "$ndk_home"/toolchains/llvm/prebuilt/*/bin/llvm-strip 2>/dev/null | head -1 || true)"
  if [[ -z "$strip_bin" ]]; then
    echo "warning: llvm-strip not found in the NDK; shipping unstripped libraries" >&2
  else
    find "$jni_dir" -name '*.so' -print0 | while IFS= read -r -d '' lib; do
      "$strip_bin" --strip-unneeded "$lib"
    done
    echo "Stripped debug symbols from the staged libraries."
  fi
fi

echo
echo "Native libraries staged for the AAR:"
find "$jni_dir" -name '*.so' -exec ls -lh {} \; | awk '{print "  " $NF " (" $5 ")"}'
echo
echo "Next: build or publish the AAR without cleaning first, e.g."
echo "  ./gradlew :android:assembleRelease"

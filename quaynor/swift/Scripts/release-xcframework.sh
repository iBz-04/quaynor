#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
swift_dir="$(cd "$script_dir/.." && pwd)"
workspace_dir="$(cd "$swift_dir/.." && pwd)"

version="${1:-}"
if [[ -z "$version" ]]; then
  echo "usage: $0 <version>" >&2
  echo "example: $0 0.1.0" >&2
  exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild not found" >&2
  exit 1
fi

if ! command -v swift >/dev/null 2>&1; then
  echo "swift not found" >&2
  exit 1
fi

if ! command -v cargo >/dev/null 2>&1; then
  echo "cargo not found" >&2
  exit 1
fi

output_root="$workspace_dir/target/swift-release"
build_root="$output_root/build"
artifact_root="$output_root/artifacts"

rm -rf "$build_root"
mkdir -p "$build_root/device" "$build_root/sim" "$build_root/macos" "$artifact_root"

pushd "$workspace_dir" >/dev/null

IPHONEOS_DEPLOYMENT_TARGET=13.0 cargo build -p quaynor-uniffi --target aarch64-apple-ios --release
IPHONEOS_DEPLOYMENT_TARGET=13.0 cargo build -p quaynor-uniffi --target aarch64-apple-ios-sim --release
IPHONEOS_DEPLOYMENT_TARGET=13.0 cargo build -p quaynor-uniffi --target x86_64-apple-ios --release
cargo build -p quaynor-uniffi --target aarch64-apple-darwin --release
cargo build -p quaynor-uniffi --target x86_64-apple-darwin --release

popd >/dev/null

lipo -create \
  "$workspace_dir/target/aarch64-apple-ios-sim/release/libquaynor_uniffi.a" \
  "$workspace_dir/target/x86_64-apple-ios/release/libquaynor_uniffi.a" \
  -output "$build_root/sim/libquaynor_uniffi.a"

lipo -create \
  "$workspace_dir/target/aarch64-apple-darwin/release/libquaynor_uniffi.a" \
  "$workspace_dir/target/x86_64-apple-darwin/release/libquaynor_uniffi.a" \
  -output "$build_root/macos/libquaynor_uniffi.a"

cp "$workspace_dir/target/aarch64-apple-ios/release/libquaynor_uniffi.a" \
  "$build_root/device/libquaynor_uniffi.a"

xcodebuild -create-xcframework \
  -library "$build_root/device/libquaynor_uniffi.a" \
  -headers "$swift_dir/Sources/CQuaynorFFI" \
  -library "$build_root/sim/libquaynor_uniffi.a" \
  -headers "$swift_dir/Sources/CQuaynorFFI" \
  -library "$build_root/macos/libquaynor_uniffi.a" \
  -headers "$swift_dir/Sources/CQuaynorFFI" \
  -output "$artifact_root/QuaynorFFI.xcframework"

zip_path="$artifact_root/QuaynorFFI.xcframework.zip"
rm -f "$zip_path"
(
  cd "$artifact_root"
  zip -r -y "QuaynorFFI.xcframework.zip" "QuaynorFFI.xcframework" >/dev/null
)

checksum="$(swift package compute-checksum "$zip_path")"
tag="quaynor-swift-$version"

echo
echo "Release artifact ready:"
echo "  $zip_path"
echo
echo "SHA-256 checksum:"
echo "  $checksum"
echo
echo "Suggested GitHub release tag:"
echo "  $tag"
echo
echo "Suggested asset name:"
echo "  QuaynorFFI.xcframework.zip"

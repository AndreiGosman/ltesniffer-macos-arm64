#!/usr/bin/env bash
# Build the LTESniffer macOS ARM64 port from the pinned upstream commits plus the
# patch series in this kit. No RF, no capture; this only produces the binary.
set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${WORK_DIR:-$KIT_DIR/work}"

# Pinned upstream sources (same model as the srsRAN-4G kit).
SRSRAN2_REPO="${SRSRAN2_REPO:-https://github.com/ShaoPaoLao/srsRAN2.git}"
SRSRAN2_COMMIT="${SRSRAN2_COMMIT:-0acc79d3fe5b153a18b62e8ef5af1a0fb2327a18}"
LTESNIFFER_REPO="${LTESNIFFER_REPO:-https://github.com/SysSec-KAIST/LTESniffer.git}"
LTESNIFFER_COMMIT="${LTESNIFFER_COMMIT:-a694803082017ac2b349e6b113940e8b9ba2fe5b}"

# Dependency prefixes.
MBEDTLS2_PREFIX="${MBEDTLS2_PREFIX:-$(brew --prefix mbedtls@2 2>/dev/null || true)}"
# The libsctp-compat shim (netinet/sctp.h + libsctp) from the companion kit
# libsctp-compat-macos-arm64. Point SCTP_PREFIX at its install prefix.
SCTP_PREFIX="${SCTP_PREFIX:-}"

say(){ printf '\n== %s ==\n' "$*"; }

for tool in git cmake ninja brew pkg-config; do
  command -v "$tool" >/dev/null 2>&1 || { echo "Missing required tool: $tool" >&2; exit 1; }
done
if [ -z "$MBEDTLS2_PREFIX" ] || [ ! -d "$MBEDTLS2_PREFIX" ]; then
  echo "mbedtls@2 not found. Install it: brew install mbedtls@2" >&2; exit 1
fi

# pkg-config: mbedtls@2 first, then the libsctp shim if given, then any caller value.
export PKG_CONFIG_PATH="$MBEDTLS2_PREFIX/lib/pkgconfig${SCTP_PREFIX:+:$SCTP_PREFIX/lib/pkgconfig}${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"

clone_pin(){ # repo commit dest
  local repo="$1" commit="$2" dest="$3"
  if [ ! -d "$dest/.git" ]; then
    say "Cloning $repo"
    git clone "$repo" "$dest"
  fi
  git -C "$dest" fetch --all --tags --quiet || true
  git -C "$dest" checkout --quiet "$commit"
}

apply_series(){ # repo_dir patch_dir
  local repo="$1" pdir="$2"
  say "Applying $(basename "$pdir") to $(basename "$repo")"
  git -C "$repo" config user.email "port@localhost" >/dev/null 2>&1 || true
  git -C "$repo" config user.name "port" >/dev/null 2>&1 || true
  git -C "$repo" am "$pdir"/*.patch
}

mkdir -p "$WORK_DIR"
SRSRAN2_DIR="$WORK_DIR/srsRAN2"
LTESNIFFER_DIR="$WORK_DIR/LTESniffer"

# 1. srsRAN2 21.10 fork, pinned + patched (built as a subproject of LTESniffer).
clone_pin "$SRSRAN2_REPO" "$SRSRAN2_COMMIT" "$SRSRAN2_DIR"
git -C "$SRSRAN2_DIR" checkout --quiet -B port-macos-arm64 "$SRSRAN2_COMMIT"
apply_series "$SRSRAN2_DIR" "$KIT_DIR/patches/srsran2-macos-arm64"

# 2. LTESniffer, pinned + patched.
clone_pin "$LTESNIFFER_REPO" "$LTESNIFFER_COMMIT" "$LTESNIFFER_DIR"
git -C "$LTESNIFFER_DIR" checkout --quiet -B port-macos-arm64 "$LTESNIFFER_COMMIT"
apply_series "$LTESNIFFER_DIR" "$KIT_DIR/patches/ltesniffer-macos-arm64"

# 3. Configure + build the CLI binary. GUI and the UL/GPSDO measurement module off.
say "Configuring"
BUILD_DIR="$LTESNIFFER_DIR/build"
rm -rf "$BUILD_DIR"; mkdir -p "$BUILD_DIR"
cmake -G Ninja -S "$LTESNIFFER_DIR" -B "$BUILD_DIR" \
  -DCMAKE_BUILD_TYPE=Release \
  -DENABLE_GUI=OFF -DENABLE_MEAS=OFF \
  -DSRSRAN_CXX_STANDARD=c++17 \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DSRSRAN_SOURCE_DIR="$SRSRAN2_DIR"
say "Building"
cmake --build "$BUILD_DIR" --target LTESniffer

BIN="$BUILD_DIR/src/LTESniffer"
say "Done"
echo "Binary: $BIN"
file "$BIN" || true

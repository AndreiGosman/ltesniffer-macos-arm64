# Shared setup for the loopback examples. Sourced by the scripts in dl/ and ul/.
# Point these at your installs before running any example:
#   SRSRAN_BIN      dir with srsenb, srsepc, srsue (from the srsRAN-4G macOS kit)
#   LTESNIFFER_BIN  the LTESniffer binary built by this kit (scripts/install.sh)
#   SCTP_PREFIX     the libsctp-compat-macos-arm64 install prefix
set -euo pipefail
: "${SRSRAN_BIN:?Set SRSRAN_BIN to the srsRAN-4G bin dir (srsenb, srsepc, srsue)}"
: "${LTESNIFFER_BIN:?Set LTESNIFFER_BIN to the LTESniffer binary from this kit}"
: "${SCTP_PREFIX:?Set SCTP_PREFIX to the libsctp-compat install prefix}"

EXROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # the examples/ directory
CFGSRC="$EXROOT/cfg"
HELPERS="$EXROOT/helpers"
LOGS="${LOGS:-$EXROOT/run/logs}"
RUNCFG="${RUNCFG:-$EXROOT/run/cfg}"
mkdir -p "$LOGS" "$RUNCFG"

# The srsRAN binaries and LTESniffer link the libsctp shim; keep it reachable.
export DYLD_LIBRARY_PATH="$SCTP_PREFIX/lib:${DYLD_LIBRARY_PATH:-}"
export PKG_CONFIG_PATH="$SCTP_PREFIX/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

# Render the config templates (cfg/*) into RUNCFG with real paths.
render_cfg(){
  local f
  for f in "$CFGSRC"/*.conf "$CFGSRC"/user_db.csv; do
    [ -e "$f" ] || continue
    sed -e "s#@CFG@#$RUNCFG#g" -e "s#@LOGS@#$LOGS#g" "$f" > "$RUNCFG/$(basename "$f")"
  done
}

# Build the ZeroMQ helpers if missing.
build_helpers(){ make -C "$HELPERS" >/dev/null; }

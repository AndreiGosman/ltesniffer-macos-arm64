#!/usr/bin/env bash
# Uplink loopback: LTESniffer decodes UL grants and PUSCH from a test UE's traffic.
# Topology (all localhost ZeroMQ, no RF):
#   srsenb DL TX 2000 -> DL fan-out -> {srsue RX 2200, LTESniffer ch0 2201}
#   srsue  UL TX 2101 -> UL fan-out -> {srsenb RX 2300, LTESniffer ch1 2301}
# srsepc (4G core) must already be running (it needs sudo on macOS; see examples/README.md).
source "$(cd "$(dirname "$0")/.." && pwd)/common.sh"
render_cfg; build_helpers
pkill -x srsenb srsue LTESniffer 2>/dev/null || true
pkill -f "zmq_dl_fanout|zmq_ul_fanout" 2>/dev/null || true
sleep 2
rm -f "$LOGS"/*.pcap "$RUNCFG"/dci.csv "$RUNCFG"/stats.csv

# 1. srsenb: S1 to the MME via the libsctp shim (encaps mirror 9902/9901), DL TX 2000,
#    UL RX from the UL fan-out (2300).
LIBSCTP_COMPAT_UDP_ENCAPS_PORT=9902 LIBSCTP_COMPAT_UDP_ENCAPS_REMOTE_PORT=9901 \
  "$SRSRAN_BIN/srsenb" "$RUNCFG/enb-ul.conf" > "$LOGS/ul-enb.log" 2>&1 & ENB=$!
for i in $(seq 1 40); do grep -q "S1Setup procedure completed successfully" "$LOGS/ul-enb.log" && break; sleep 1; done

# 2. DL fan-out and 3. UL fan-out (same generic tee, different ports).
"$HELPERS/zmq_dl_fanout" "tcp://localhost:2000" "tcp://*:2200" "tcp://*:2201" > "$LOGS/ul-fanout-dl.log" 2>&1 & FOD=$!
"$HELPERS/zmq_ul_fanout" "tcp://localhost:2101" "tcp://*:2300" "tcp://*:2301" > "$LOGS/ul-fanout-ul.log" 2>&1 & FOU=$!
sleep 1

# 4. LTESniffer: uplink mode, two RX channels (ch0 DL 2201, ch1 UL 2301), identity on.
"$LTESNIFFER_BIN" -A 2 -m 1 -f 1815000000 -u 1720000000 \
  -a "rx_port0=tcp://localhost:2201,rx_port1=tcp://localhost:2301,id=sniffer,base_srate=11.52e6" \
  -C -W 2 -z 0 -D "$RUNCFG/dci.csv" -E "$RUNCFG/stats.csv" > "$LOGS/ul-sniffer.log" 2>&1 & SN=$!
sleep 2

# 5. srsue via the DL fan-out (2200), UL TX 2101.
"$SRSRAN_BIN/srsue" "$RUNCFG/ue-fanout.conf" > "$LOGS/ul-ue.log" 2>&1 & UE=$!
sleep 45

kill -INT "$SN" 2>/dev/null || true; sleep 3
pkill -x srsue LTESniffer 2>/dev/null || true
kill "$FOD" "$FOU" "$ENB" 2>/dev/null || true
pkill -f "zmq_dl_fanout|zmq_ul_fanout" 2>/dev/null || true
pkill -x srsenb 2>/dev/null || true
echo "Done. Logs in $LOGS, outputs (dci.csv, stats.csv) in $RUNCFG."

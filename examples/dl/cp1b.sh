#!/usr/bin/env bash
# Downlink loopback, no core, no UE: srsenb transmits the cell and LTESniffer
# decodes it. srsenb's uplink receiver is fed silence by zmq_zeros_rep so it
# advances without a UE. No srsepc, no sudo.
# Topology: srsenb DL TX 2000 -> LTESniffer 2000; zeros -> srsenb RX 2101.
source "$(cd "$(dirname "$0")/.." && pwd)/common.sh"
render_cfg; build_helpers
pkill -x srsenb LTESniffer 2>/dev/null || true
pkill -f "zmq_zeros_rep" 2>/dev/null || true
sleep 2
rm -f "$LOGS"/*.pcap "$RUNCFG"/dci.csv "$RUNCFG"/stats.csv

# Silence source on srsenb's uplink port so it is not blocked without a UE.
"$HELPERS/zmq_zeros_rep" "tcp://*:2101" 5760 > "$LOGS/zeros.log" 2>&1 & ZR=$!
sleep 1

# srsenb standalone (no core; S1 fails but the PHY transmits the cell).
"$SRSRAN_BIN/srsenb" "$RUNCFG/enb.conf" > "$LOGS/dl-standalone-enb.log" 2>&1 & ENB=$!
for i in $(seq 1 30); do grep -q "Starting RX/TX thread" "$LOGS/dl-standalone-enb.log" && break; sleep 1; done
sleep 2

# LTESniffer as the sole consumer of srsenb's downlink.
"$LTESNIFFER_BIN" -A 1 -a "rx_port=tcp://localhost:2000,id=sniffer,base_srate=11.52e6" \
  -f 1815000000 -C -W 2 -D "$RUNCFG/dci.csv" -E "$RUNCFG/stats.csv" > "$LOGS/dl-standalone-sniffer.log" 2>&1 & SN=$!
sleep 30

kill -INT "$SN" 2>/dev/null || true; sleep 2
pkill -x LTESniffer 2>/dev/null || true
kill "$ENB" "$ZR" 2>/dev/null || true
pkill -x srsenb 2>/dev/null || true; pkill -f "zmq_zeros_rep" 2>/dev/null || true
echo "Done. Logs in $LOGS, outputs in $RUNCFG."

#!/usr/bin/env bash
# Downlink loopback with a full attach: LTESniffer decodes the cell, the control
# channel, the attached UE's C-RNTI and the RNTI-TMSI identity mapping.
# Topology: srsenb DL TX 2000 -> DL fan-out -> {srsue RX 2200, LTESniffer 2201};
#           srsue UL TX 2101 -> srsenb RX 2101 (direct).
# srsepc (4G core) must already be running (needs sudo on macOS; see examples/README.md).
source "$(cd "$(dirname "$0")/.." && pwd)/common.sh"
render_cfg; build_helpers
pkill -x srsenb srsue LTESniffer 2>/dev/null || true
pkill -f "zmq_dl_fanout" 2>/dev/null || true
sleep 2
rm -f "$LOGS"/*.pcap "$RUNCFG"/dci.csv "$RUNCFG"/stats.csv

# srsenb: S1 to the MME (shim encaps mirror 9902/9901), DL TX 2000, UL RX 2101 direct.
LIBSCTP_COMPAT_UDP_ENCAPS_PORT=9902 LIBSCTP_COMPAT_UDP_ENCAPS_REMOTE_PORT=9901 \
  "$SRSRAN_BIN/srsenb" "$RUNCFG/enb.conf" > "$LOGS/dl-enb.log" 2>&1 & ENB=$!
for i in $(seq 1 40); do grep -q "S1Setup procedure completed successfully" "$LOGS/dl-enb.log" && break; sleep 1; done

# DL fan-out: srsenb TX 2000 -> srsue RX 2200 + LTESniffer 2201.
"$HELPERS/zmq_dl_fanout" "tcp://localhost:2000" "tcp://*:2200" "tcp://*:2201" > "$LOGS/dl-fanout.log" 2>&1 & FO=$!
sleep 1

# LTESniffer: downlink mode, identity on.
"$LTESNIFFER_BIN" -A 1 -a "rx_port=tcp://localhost:2201,id=sniffer,base_srate=11.52e6" \
  -f 1815000000 -C -W 2 -z 0 -D "$RUNCFG/dci.csv" -E "$RUNCFG/stats.csv" > "$LOGS/dl-sniffer.log" 2>&1 & SN=$!
sleep 2

# srsue via the DL fan-out (2200), UL TX 2101.
"$SRSRAN_BIN/srsue" "$RUNCFG/ue-fanout.conf" > "$LOGS/dl-ue.log" 2>&1 & UE=$!
sleep 40

kill -INT "$SN" 2>/dev/null || true; sleep 3
pkill -x srsue LTESniffer 2>/dev/null || true
kill "$FO" "$ENB" 2>/dev/null || true
pkill -f "zmq_dl_fanout" 2>/dev/null || true
pkill -x srsenb 2>/dev/null || true
echo "Done. Logs in $LOGS, outputs in $RUNCFG."

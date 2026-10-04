# Loopback examples

These scripts drive LTESniffer against a synthetic LTE network over a ZeroMQ
virtual radio on localhost. No SDR, no over-the-air capture. They are the
scripts used to validate the decode end to end (see ../docs/validation-loopback.md).

## Prerequisites

- The LTESniffer binary built by this kit (`../scripts/install.sh`).
- The srsRAN 4G binaries srsenb, srsepc and srsue, from the companion macOS kit
  srsRAN-4G-macos-arm64. They are the ground-truth network.
- The libsctp-compat-macos-arm64 shim prefix (srsenb, srsepc and LTESniffer link it).
- ZeroMQ (`brew install zeromq`) for the helper tees.

Point the examples at your installs:

```sh
export SRSRAN_BIN=/path/to/srsRAN-4G/bin        # srsenb, srsepc, srsue
export LTESNIFFER_BIN=/path/to/LTESniffer       # built by scripts/install.sh
export SCTP_PREFIX=/path/to/libsctp-compat      # install prefix of the shim
```

`common.sh` reads those three variables, renders the config templates in `cfg/`
into `run/cfg/` with real paths, and builds the ZeroMQ helpers in `helpers/`.
There are no absolute paths in the kit; everything resolves from these variables
and the repo layout. The config templates use `@CFG@` and `@LOGS@` placeholders
that `common.sh` fills at run time.

The SIM values in `cfg/user_db.csv` and the UE config are the standard srsRAN
test credentials (IMSI 001010000000001, PLMN 001/01, the default test Ki and OPc).
They are public test values.

Every example passes `--rf-dev zmq` (patch 011), so the sniffer opens the ZeroMQ
driver and no other. Without it the binary probes the drivers in order and a
connected SDR would be opened in place of the loopback.

## Downlink

- `dl/cp1b.sh`: no core, no UE. srsenb transmits the cell; LTESniffer decodes it.
  A silence source keeps srsenb's uplink from blocking. No sudo.
- `dl/cp2-epc.sh`: full attach. Needs srsepc running first (see below). LTESniffer
  decodes the attached UE's C-RNTI and the RNTI-TMSI identity mapping.

## Uplink

- `ul/cp3-ul.sh`: LTESniffer in uplink mode with two RX channels (downlink and
  uplink), fed by two fan-outs. It decodes the uplink grants (DCI format 0), the
  PUSCH, and the identity, cross-checked against the test UE. Needs srsepc first.

## Starting srsepc (needs sudo on macOS)

srsepc creates the SGi utun and binds the S11 sockets, which need root on macOS.
Start it in a separate terminal before `cp2-epc.sh` or `cp3-ul.sh`:

```sh
sudo env LIBSCTP_COMPAT_UDP_ENCAPS_PORT=9901 LIBSCTP_COMPAT_UDP_ENCAPS_REMOTE_PORT=9902 \
  "$SRSRAN_BIN/srsepc" run/cfg/epc.conf
```

Run an example once (`cp3-ul.sh`) so `run/cfg/epc.conf` is rendered first, or
render it by hand with the `@CFG@`/`@LOGS@` substitution. Stop srsepc with
`sudo pkill -x srsepc` and remove its S11 sockets with
`sudo rm -f /tmp/srsran_mme_s11 /tmp/srsran_spgw_s11`.

## Honest boundary

The loopback uses a synthetic signal and a test SIM. It validates the decode
code and the identity mapping, not real radio performance, not GPSDO
synchronisation, and not over-the-air uplink.

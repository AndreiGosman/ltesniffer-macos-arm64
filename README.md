# LTESniffer macOS ARM64 port kit

This kit builds [LTESniffer](https://github.com/SysSec-KAIST/LTESniffer) on macOS
ARM64 (Apple Silicon). LTESniffer is an open-source LTE downlink and uplink
analyzer from KAIST. It decodes the control channel (PDCCH DCI) and the shared
channels (PDSCH, PUSCH), and it carries a security API for identity mapping,
IMSI collection and UE capability profiling.

Upstream targets Ubuntu and x86. This kit is a patch kit, not a copy of the
upstream source. It carries two patch series and a build script that clones the
pinned upstream commits, applies the patches, and builds the command-line binary.

## What it ports

LTESniffer builds its radio stack from a fork of srsRAN, `ShaoPaoLao/srsRAN2`,
which is srsRAN 21.10 (the 4G line). This kit therefore ports two trees:

- srsRAN2 21.10: the PHY, common, RF and upper layers that LTESniffer links.
- LTESniffer itself: the FALCON-derived analysis layer and the CLI.

The port covers the command-line sniffer in both downlink and uplink modes. The
uplink decode (DCI format 0 grants, PUSCH, and the identity mapping on the
uplink) is built into the binary and validated on a ZeroMQ loopback. The Qt GUI
is not built.

## Requirements

- macOS on Apple Silicon, with the Command Line Tools.
- Homebrew packages: `ninja cmake fftw boost zeromq mbedtls@2 uhd`.
  `mbedtls@2` is required because srsRAN 21.10 uses the mbedtls 2.x API; mbedtls
  4.x removed the headers it needs.
- The companion kit `libsctp-compat-macos-arm64`, which provides the `libsctp`
  shim (version 0.4.1). srsRAN common includes `<netinet/sctp.h>`, which Darwin
  does not have; the shim supplies it and the binary links it. Install that kit
  first and pass its prefix to the build (see below).

## Build

```sh
brew install ninja cmake fftw boost zeromq mbedtls@2 uhd
# Build and install the libsctp-compat shim kit first, into some prefix, then:
SCTP_PREFIX=/path/to/libsctp-compat/prefix ./scripts/install.sh
```

`scripts/install.sh` clones `SysSec-KAIST/LTESniffer` at commit `a694803` and
`ShaoPaoLao/srsRAN2` at commit `0acc79d`, applies both patch series, and builds
the binary at `work/LTESniffer/build/src/LTESniffer`. The script pins the
commits, so a later upstream change does not move the base.

Run the binary with no arguments to print the usage and the active RF plugins.

Name the RF driver with `--rf-dev <driver>` (zmq, uhd, soapy, bladeRF, file)
when more than one could open. Without it the binary probes every driver and
keeps the first that answers, which on a machine with a USRP class device is
that device even for a ZeroMQ loopback run. See docs/port-overview.md.

## Honest boundary

This is a passive sniffer. It decodes the downlink and uplink control and data
channels and the identity layer. Without a SIM and an active connection, a
passive receiver does not give real UE throughput, real uplink power, handover
as the UE experiences it, or QoS. It gives the scanner and the passive observer
of the control channel and of identities.

The uplink decode is built and loopback-validated, but over-the-air uplink
capture is gated on hardware and authorisation: it needs a second SDR and a
GPSDO for a shared time reference. The multi-USRP GPSDO synchronisation module
(the `ENABLE_MEAS` path, which pulls the CMNALIB dependency) is not included in
this kit; it is only needed for two separate physical SDRs and can be validated
only on that hardware.

## Attribution and licence

- LTESniffer: SysSec, KAIST. https://github.com/SysSec-KAIST/LTESniffer
- srsRAN2 fork: https://github.com/ShaoPaoLao/srsRAN2 (srsRAN 21.10 line).
- srsRAN: Software Radio Systems.

Both upstream trees are AGPL-3.0. The patches in this kit modify AGPL-3.0 code
and are distributed under AGPL-3.0. See LICENSE and NOTICE.

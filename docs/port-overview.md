# Port overview

## Base

LTESniffer builds its radio stack from `ShaoPaoLao/srsRAN2`, which is srsRAN
21.10 (the 4G line), not the old srsLTE 18.x. This matters: the Darwin patch
classes are the same ones a current srsRAN 4G port needs, applied to a 2021 tree.

## Darwin patch classes

- Arch and SIMD. CMAKE_SYSTEM_PROCESSOR is arm64 on Darwin and aarch64 on Linux.
  The tree guards NEONv8 and the 32-bit ARM compiler flags on those strings.
  Normalise arm64 to aarch64, and drop -mfpu and -mfloat-abi on 64-bit ARM.
  arch_select returns NEON unconditionally on Apple Silicon, which has no
  getauxval.
- Missing Linux headers and primitives. No <endian.h> (byte order macros map to
  libkern/OSByteOrder.h), no <sys/timerfd.h> (a kqueue-backed compat header),
  no CPU affinity (compiled out), pthread_setname_np takes one argument.
- Toolchain strictness. Apple clang is far newer than the gcc this tree targets,
  so -Werror is dropped, a template disambiguator is removed, pthread_self is
  cast through uintptr_t, and high_resolution_clock lacks to_time_t on libc++.
- Include priority. The bundled fmt and the selected mbedtls must come before a
  Homebrew copy on the include path, or headers and libraries disagree.
- mbedtls version. srsRAN 21.10 needs the mbedtls 2.x API; mbedtls 4.x removed
  those headers. The build uses mbedtls@2 from Homebrew.
- UHD and C++17. UHD 4.x public headers use C++17, so the C++ standard is a cache
  variable and the build selects c++17.

## The srsRAN2 integration decision (Option B)

LTESniffer calls find_package(SRSRAN), but srsRAN2 ships no config package and
LTESniffer has no FindSRSRAN module, so the call never succeeds. The upstream
path then downloads srsRAN2 master and builds it in-tree. On macOS that download
is unpatched and does not build.

This kit replaces the download with add_subdirectory of a local patched srsRAN2
tree, passed through the SRSRAN_SOURCE_DIR cache variable. The kit propagates the
library-only, C++17 configuration into the subproject and skips its tests and
examples. There is no hardcoded path; the build fails fast if SRSRAN_SOURCE_DIR
is not given, and scripts/install.sh passes the clone it made.

## RF driver selection (--rf-dev)

Upstream opens the radio with srsran_rf_open_multi, which is the srsRAN auto
mode: it probes the RF drivers in order (UHD, SoapySDR, bladeRF, ZeroMQ, file)
and keeps the first that opens. With a USRP class device connected, that is the
device, whatever the device argument string says, so a ZeroMQ loopback run
lands on real hardware, and on a machine with several SDRs the first one found
wins. Patch 011 adds `--rf-dev <driver>`, which passes the name to
srsran_rf_open_devname: that driver opens or the run fails, with no fallback to
the next driver. The names are the ones srsRAN prints in its device list (zmq,
uhd, soapy, bladeRF, file). Without the option the upstream behaviour stays.
The loopback examples pass `--rf-dev zmq`. This is a robustness fix, not a
Darwin one, and like patch 010 it is a candidate for upstream.

## What is left out

The Qt GUI is not built. The UL/GPSDO measurement module is optional and off by
default; it is the only consumer of CMNALIB, and the CLI binary does not link it.

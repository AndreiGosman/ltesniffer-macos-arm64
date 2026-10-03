# Patch index

One line per patch. The series apply in order on the pinned upstream commits.

## srsran2-macos-arm64 (base: ShaoPaoLao/srsRAN2 @ 0acc79d, srsRAN 21.10)

- 001 build: treat Darwin arm64 as aarch64 for NEON and arch flags.
- 002 phy: select NEON unconditionally on Apple Silicon (no getauxval on Darwin).
- 003 build: do not force -Werror on Apple clang.
- 004 srslog: give the bundled fmt priority over a system fmt.
- 005 build: raise cmake_minimum_required in the generated buildinfo script.
- 006 srslog: cast pthread_self() through uintptr_t for the TID field.
- 007 srslog: convert timestamps without steady_clock::to_time_t.
- 008 common: timerfd for Darwin, backed by kqueue.
- 009 common: wrap pthread_setname_np for Darwin's one-argument form.
- 010 adt: drop the template disambiguator clang rejects in circular_map.
- 011 build: give the selected mbedtls include priority over any other.
- 012 common: resolve netinet/sctp.h for a standalone library build.
- 013 common: no thread affinity on Darwin.
- 014 common: byte order macros for platforms without endian.h.
- 015 build: make the C++ standard selectable for recent UHD.
- 016 build: gate tests and examples so the tree embeds as a library subproject.

## ltesniffer-macos-arm64 (base: SysSec-KAIST/LTESniffer @ a694803)

- 001 build: do not pass 32-bit ARM flags on Apple Silicon.
- 002 build: link against a patched srsRAN2 passed via SRSRAN_SOURCE_DIR.
- 003 build: make the measurement module optional (ENABLE_MEAS).
- 004 falcon: avoid C++ stdlib under extern "C" in falcon_ue_dl.h.
- 005 falcon: include the srsran debug header for ERROR in ul_sniffer_pusch.
- 006 falcon: use int instead of auto in a C loop in falcon_dci.
- 007 core: no thread affinity on Darwin.
- 008 args: fix option parsing for BSD/macOS getopt.
- 009 worker: enable the per-subframe DCI-to-file consumer.

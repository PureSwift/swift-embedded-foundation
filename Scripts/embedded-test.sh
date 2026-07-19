#!/bin/bash
#
# embedded-test.sh — verify the package under Embedded Swift.
#
# Two things, both gating (any failure exits non-zero):
#   1. Cross-compile the sources for bare-metal targets (Cortex-M, RISC-V, …)
#      in `-enable-experimental-feature Embedded` mode. This is the "does it
#      build for a microcontroller" check.
#   2. On macOS, build the EmbeddedTests smoke test in Embedded mode and RUN it,
#      so the shims' behavior is validated under embedded, not just compiled.
#      (swift-testing/XCTest cannot run under Embedded Swift, so this standalone
#      executable is how embedded behavior gets exercised.)
#
# Requires a Swift toolchain that ships the Embedded standard library — the
# Xcode-bundled toolchain does not; a swift.org toolchain does. Point at one
# explicitly with EMBEDDED_TOOLCHAIN=/path/to/xctoolchain, otherwise the script
# searches the standard toolchain locations.
#
set -euo pipefail

cd "$(dirname "$0")/.."

BARE_METAL_TARGETS=(
    armv7em-none-none-eabi   # Cortex-M4/M7
    riscv32-none-none-eabi   # RISC-V 32
    arm64-apple-none-macho   # bare-metal arm64 (Mach-O)
)

# --- Locate an Embedded-capable toolchain ----------------------------------

has_embedded() {
    [ -d "$1/usr/lib/swift/embedded" ] && [ -x "$1/usr/bin/swiftc" ]
}

find_toolchain() {
    # 1. Explicit override.
    if [ -n "${EMBEDDED_TOOLCHAIN:-}" ]; then
        echo "$EMBEDDED_TOOLCHAIN"
        return
    fi
    # 2. The toolchain a `swiftc` on PATH belongs to (e.g. one installed by
    #    setup-swift in CI).
    local sc root
    sc="$(command -v swiftc || true)"
    if [ -n "$sc" ]; then
        root="$(cd "$(dirname "$sc")/../.." && pwd)"
        if has_embedded "$root"; then
            echo "$root"
            return
        fi
    fi
    # 3. Installed .xctoolchains — prefer RELEASE/newest first.
    local base tc
    for base in "$HOME/Library/Developer/Toolchains" "/Library/Developer/Toolchains"; do
        [ -d "$base" ] || continue
        for tc in $(ls -d "$base"/*.xctoolchain 2>/dev/null | sort -r); do
            if has_embedded "$tc"; then
                echo "$tc"
                return
            fi
        done
    done
    return 1
}

TOOLCHAIN="$(find_toolchain || true)"
if [ -z "$TOOLCHAIN" ] || [ ! -x "$TOOLCHAIN/usr/bin/swiftc" ]; then
    echo "error: no Embedded-capable Swift toolchain found." >&2
    echo "       Install a swift.org toolchain (it bundles the Embedded stdlib)" >&2
    echo "       or set EMBEDDED_TOOLCHAIN=/path/to/xctoolchain." >&2
    exit 1
fi

SWIFTC="$TOOLCHAIN/usr/bin/swiftc"
EMBEDDED_LIB="$TOOLCHAIN/usr/lib/swift/embedded"
echo "==> Toolchain: $TOOLCHAIN"
"$SWIFTC" --version | head -1

SOURCES=(Sources/FoundationEmbedded/*.swift)

# This script drives swiftc directly, so SwiftPM's traits are not applied
# automatically — the package's default-enabled traits are passed by hand.
TRAITS=(-D FloatingPointParsingShims)

# --- 1. Bare-metal cross-compile gates -------------------------------------

for target in "${BARE_METAL_TARGETS[@]}"; do
    if [ ! -d "$EMBEDDED_LIB/$target" ]; then
        echo "==> Skipping $target (stdlib not in toolchain)"
        continue
    fi
    echo "==> Compiling for $target"
    "$SWIFTC" -target "$target" -enable-experimental-feature Embedded -wmo \
        -parse-as-library "${TRAITS[@]}" -c "${SOURCES[@]}" -o /dev/null

    # The library must also build with every optional trait disabled.
    "$SWIFTC" -target "$target" -enable-experimental-feature Embedded -wmo \
        -parse-as-library -c "${SOURCES[@]}" -o /dev/null
done

# --- 2. Host build + run (macOS only) --------------------------------------

if [ "$(uname -s)" != "Darwin" ]; then
    echo "==> Host is not macOS; skipping embedded run (compile gates passed)."
    exit 0
fi

ARCH="$(uname -m)" # arm64 or x86_64
HOST_TARGET="${ARCH}-apple-macos14"
HOST_LIB="$EMBEDDED_LIB/${ARCH}-apple-macos"
SDK="$(xcrun --show-sdk-path)"
BIN="$(mktemp -t embedded-smoke-test)"

echo "==> Building + running smoke test for $HOST_TARGET"
"$SWIFTC" -target "$HOST_TARGET" -sdk "$SDK" \
    -enable-experimental-feature Embedded -wmo "${TRAITS[@]}" \
    "${SOURCES[@]}" EmbeddedTests/main.swift \
    -L "$HOST_LIB" -lswiftUnicodeDataTables \
    -o "$BIN"

"$BIN"
echo "==> Embedded smoke test passed."

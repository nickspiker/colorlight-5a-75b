#!/usr/bin/env bash
# Build greyscale NTSC display test for Colorlight 5A-75B v8.0
# Usage: bash scripts/build_grey.sh [--program] [--flash]
#
# Steps:
#   1. cargo run (img2mem) — convert test.jpg → build/grey{0,1,2}.mem
#   2. yosys — synthesise
#   3. nextpnr — place & route
#   4. ecppack — generate bitstream
#   5. (optional) openFPGALoader — program SRAM or flash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$SCRIPT_DIR/.."
RTL="$ROOT/rtl"
BUILD="$ROOT/build"
LPF="$ROOT/constraints/colorlight.lpf"
SEED="${SEED:-4}"

mkdir -p "$BUILD"

PROGRAM=0
FLASH=0
for arg in "$@"; do
    case "$arg" in
        --program) PROGRAM=1 ;;
        --flash)   FLASH=1   ;;
    esac
done

# -------------------------------------------------------------------------
echo "--- Convert image ---"
(cd "$ROOT" && cargo run --release -- test.jpg build)

# -------------------------------------------------------------------------
echo ""
echo "--- Synthesise ---"
yosys -p "
    read_verilog $RTL/pll_200.v
    read_verilog $RTL/ntsc_grey.v
    read_verilog $RTL/top_grey_test.v
    synth_ecp5 -nowidelut -abc2 -top top_grey_test -json $BUILD/grey.json
    stat
" > "$BUILD/grey_yosys.log" 2>&1
grep -E "^(=== |   Number of|   Estimated)" "$BUILD/grey_yosys.log" || tail -5 "$BUILD/grey_yosys.log"

# -------------------------------------------------------------------------
echo ""
echo "--- Place & Route ---"
nextpnr-ecp5 --25k --package CABGA256 --speed 6 --seed "$SEED" \
    --lpf "$LPF" \
    --freq 800 \
    --json "$BUILD/grey.json" \
    --textcfg "$BUILD/grey.config" \
    2>&1 | tee "$BUILD/grey_pnr.log" | grep -E "(Info|Warning|Error|MHz)"

# -------------------------------------------------------------------------
echo ""
echo "--- Pack bitstream ---"
ecppack --svf "$BUILD/grey.svf" "$BUILD/grey.config" "$BUILD/grey.bit"
echo "Bitstream: $BUILD/grey.bit"

# -------------------------------------------------------------------------
if [ "$PROGRAM" -eq 1 ]; then
    echo ""
    echo "--- Program SRAM ---"
    openFPGALoader -c ft232 "$BUILD/grey.svf"
fi

if [ "$FLASH" -eq 1 ]; then
    echo ""
    echo "--- Write flash ---"
    openFPGALoader -c ft232 --write-flash "$BUILD/grey.bit"
fi

echo ""
echo "Done."

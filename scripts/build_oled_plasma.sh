#!/usr/bin/env bash
# Build OLED plasma test for Colorlight 5A-75B v8.0
# Usage: bash scripts/build_oled_plasma.sh [--program] [--flash]
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$SCRIPT_DIR/.."
RTL="$ROOT/rtl"
BUILD="$ROOT/build"
LPF="$ROOT/constraints/colorlight.lpf"
SEED="${SEED:-4}"

mkdir -p "$BUILD"

PROGRAM=0; FLASH=0
for arg in "$@"; do
    case "$arg" in
        --program) PROGRAM=1 ;;
        --flash)   FLASH=1   ;;
    esac
done

echo "--- Synthesise ---"
yosys -p "
    read_verilog $RTL/ssd1306_i2c.v
    read_verilog $RTL/oled_plasma.v
    read_verilog $RTL/top_oled_plasma.v
    synth_ecp5 -nowidelut -abc2 -top top_oled_plasma -json $BUILD/oled_plasma.json
    stat
" > "$BUILD/oled_plasma_yosys.log" 2>&1
grep -E "^(=== |   Number of|   Estimated)" "$BUILD/oled_plasma_yosys.log" || tail -5 "$BUILD/oled_plasma_yosys.log"

echo ""
echo "--- Place & Route ---"
nextpnr-ecp5 --25k --package CABGA256 --speed 6 --seed "$SEED" \
    --lpf "$LPF" \
    --freq 25 \
    --json "$BUILD/oled_plasma.json" \
    --textcfg "$BUILD/oled_plasma.config" \
    2>&1 | tee "$BUILD/oled_plasma_pnr.log" | grep -E "(Info|Warning|Error|MHz)"

echo ""
echo "--- Pack bitstream ---"
ecppack --svf "$BUILD/oled_plasma.svf" "$BUILD/oled_plasma.config" "$BUILD/oled_plasma.bit"
echo "Bitstream: $BUILD/oled_plasma.bit"

if [ "$PROGRAM" -eq 1 ]; then
    echo ""
    echo "--- Program SRAM ---"
    openFPGALoader -c ft232 "$BUILD/oled_plasma.svf"
fi

if [ "$FLASH" -eq 1 ]; then
    echo ""
    echo "--- Write flash ---"
    openFPGALoader -c ft232 --write-flash "$BUILD/oled_plasma.bit"
fi

echo ""
echo "Done."

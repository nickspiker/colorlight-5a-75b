#!/usr/bin/env bash
# Build pin continuity scanner for Colorlight 5A-75B v8.0
# Active scan: tristate one pin at a time, drive other 66 LOW, sample after 1ms.
# Results: OLED display (top half = pin states, bottom = binary ruler), LED on any hit.
# Usage: bash scripts/build_pin_scan.sh [--program] [--flash] [--clkdiv=N]
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$SCRIPT_DIR/.."
RTL="$ROOT/rtl"
BUILD="$ROOT/build"
LPF="$ROOT/constraints/pin_scan.lpf"
SEED="${SEED:-4}"

mkdir -p "$BUILD"

PROGRAM=0; FLASH=0; CLKDIV=7
for arg in "$@"; do
    case "$arg" in
        --program)   PROGRAM=1 ;;
        --flash)     FLASH=1   ;;
        --clkdiv)    shift; CLKDIV="$1" ;;
        --clkdiv=*)  CLKDIV="${arg#--clkdiv=}" ;;
    esac
done
I2C_KHZ=$(awk "BEGIN { printf \"%.1f\", 25000 / $CLKDIV }")
echo "CLK_DIV=$CLKDIV  I2C=${I2C_KHZ}kHz"

echo "--- Synthesise ---"
yosys -p "
    read_verilog $RTL/ssd1306_i2c.v
    read_verilog $RTL/top_pin_scan.v
    chparam -set CLK_DIV $CLKDIV top_pin_scan
    synth_ecp5 -nowidelut -abc2 -top top_pin_scan -json $BUILD/pin_scan.json
    stat
" > "$BUILD/pin_scan_yosys.log" 2>&1
grep -E "^(=== |   Number of|   Estimated)" "$BUILD/pin_scan_yosys.log" || tail -5 "$BUILD/pin_scan_yosys.log"

echo ""
echo "--- Place & Route ---"
nextpnr-ecp5 --25k --package CABGA256 --speed 6 --seed "$SEED" \
    --lpf "$LPF" \
    --freq 25 --ignore-loops \
    --json "$BUILD/pin_scan.json" \
    --textcfg "$BUILD/pin_scan.config" \
    2>&1 | tee "$BUILD/pin_scan_pnr.log" | grep -E "(Info|Warning|Error|MHz)"

echo ""
echo "--- Pack bitstream ---"
ecppack --svf "$BUILD/pin_scan.svf" "$BUILD/pin_scan.config" "$BUILD/pin_scan.bit"
echo "Bitstream: $BUILD/pin_scan.bit"

if [ "$PROGRAM" -eq 1 ]; then
    echo ""
    echo "--- Program SRAM ---"
    openFPGALoader -c ft232 "$BUILD/pin_scan.svf"
fi

if [ "$FLASH" -eq 1 ]; then
    echo ""
    echo "--- Write flash ---"
    openFPGALoader -c ft232 --write-flash "$BUILD/pin_scan.bit"
fi

echo ""
echo "Done."

#!/usr/bin/env bash
# Build dithered OLED image display for Colorlight 5A-75B v8.0
# Usage: bash scripts/build_oled_img.sh [--program] [--flash]
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

echo "--- Dither image ---"
(cd "$ROOT" && cargo run --release --bin oled_img -- test.jpg "$BUILD/oled_img.mem")

echo ""
echo "--- Synthesise ---"
yosys -p "
    read_verilog $RTL/ssd1306_i2c.v
    read_verilog $RTL/oled_img.v
    read_verilog $RTL/top_oled_img.v
    synth_ecp5 -nowidelut -abc2 -top top_oled_img -json $BUILD/oled_img.json
    stat
" > "$BUILD/oled_img_yosys.log" 2>&1
grep -E "^(=== |   Number of|   Estimated)" "$BUILD/oled_img_yosys.log" || tail -5 "$BUILD/oled_img_yosys.log"

echo ""
echo "--- Place & Route ---"
nextpnr-ecp5 --25k --package CABGA256 --speed 6 --seed "$SEED" \
    --lpf "$LPF" \
    --freq 25 \
    --json "$BUILD/oled_img.json" \
    --textcfg "$BUILD/oled_img.config" \
    2>&1 | tee "$BUILD/oled_img_pnr.log" | grep -E "(Info|Warning|Error|MHz)"

echo ""
echo "--- Pack bitstream ---"
ecppack --svf "$BUILD/oled_img.svf" "$BUILD/oled_img.config" "$BUILD/oled_img.bit"
echo "Bitstream: $BUILD/oled_img.bit"

if [ "$PROGRAM" -eq 1 ]; then
    echo ""
    echo "--- Program SRAM ---"
    openFPGALoader -c ft232 "$BUILD/oled_img.svf"
fi

if [ "$FLASH" -eq 1 ]; then
    echo ""
    echo "--- Write flash ---"
    openFPGALoader -c ft232 --write-flash "$BUILD/oled_img.bit"
fi

echo ""
echo "Done."

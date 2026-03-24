#!/usr/bin/env bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$SCRIPT_DIR/.."
RTL="$ROOT/rtl"
BUILD="$ROOT/build"
LPF="$ROOT/constraints/oled_fb_test.lpf"
SEED="${SEED:-4}"

mkdir -p "$BUILD"

PROGRAM=0; FLASH=0; HZ=40; CLKDIV=32
for arg in "$@"; do
    case "$arg" in
        --program)   PROGRAM=1 ;;
        --flash)     FLASH=1   ;;
        --hz)        shift; HZ="$1" ;;
        --hz=*)      HZ="${arg#--hz=}" ;;
        --clkdiv)    shift; CLKDIV="$1" ;;
        --clkdiv=*)  CLKDIV="${arg#--clkdiv=}" ;;
    esac
done
HALF_PERIOD=$(awk "BEGIN { printf \"%d\", int(25000000 / ($HZ * 2) + 0.5) }")
I2C_KHZ=$(awk "BEGIN { printf \"%.1f\", 25000 / $CLKDIV }")
echo "Hz=$HZ  HALF_PERIOD=$HALF_PERIOD  CLK_DIV=$CLKDIV  I2C=${I2C_KHZ}kHz"

echo "--- Synthesise ---"
yosys -p "
    read_verilog $RTL/ssd1306_i2c.v
    read_verilog $RTL/ssd1306_fb.v
    read_verilog $RTL/top_oled_fb_test.v
    chparam -set HALF_PERIOD $HALF_PERIOD top_oled_fb_test
    chparam -set CLK_DIV $CLKDIV top_oled_fb_test
    synth_ecp5 -nowidelut -abc2 -top top_oled_fb_test -json $BUILD/oled_fb_test.json
    stat
" > "$BUILD/oled_fb_test_yosys.log" 2>&1
grep -E "^(=== |   Number of|   Estimated)" "$BUILD/oled_fb_test_yosys.log" || tail -10 "$BUILD/oled_fb_test_yosys.log"

echo ""
echo "--- Place & Route ---"
nextpnr-ecp5 --25k --package CABGA256 --speed 6 --seed "$SEED" \
    --lpf "$LPF" --freq 25 \
    --json "$BUILD/oled_fb_test.json" \
    --textcfg "$BUILD/oled_fb_test.config" \
    2>&1 | tee "$BUILD/oled_fb_test_pnr.log" | grep -E "(Info|Warning|Error|MHz)"

echo ""
echo "--- Pack bitstream ---"
ecppack --svf "$BUILD/oled_fb_test.svf" "$BUILD/oled_fb_test.config" "$BUILD/oled_fb_test.bit"
echo "Bitstream: $BUILD/oled_fb_test.bit"

if [ "$PROGRAM" -eq 1 ]; then
    echo ""
    echo "--- Program SRAM ---"
    openFPGALoader -c ft232 "$BUILD/oled_fb_test.svf"
fi

if [ "$FLASH" -eq 1 ]; then
    echo ""
    echo "--- Write flash ---"
    openFPGALoader -c ft232 --write-flash "$BUILD/oled_fb_test.bit"
fi

echo ""
echo "Done."

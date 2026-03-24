#!/usr/bin/env bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$SCRIPT_DIR/.."
RTL="$ROOT/rtl"
BUILD="$ROOT/build"
LPF="$ROOT/constraints/oled_fb_test.lpf"
SEED="${SEED:-4}"

mkdir -p "$BUILD"

PROGRAM=0; FLASH=0; CLKDIV=32
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

# Convert image (skip with --no-img)
NO_IMG=0
for arg in "$@"; do [[ "$arg" == "--no-img" ]] && NO_IMG=1; done
if [ "$NO_IMG" -eq 0 ]; then
    cargo build --manifest-path "$ROOT/Cargo.toml" --release --bin img_to_fb -q
    "$ROOT/target/release/img_to_fb" "$ROOT/lines.png" "$BUILD/fb_image.mem"
fi

echo "--- Synthesise ---"

# Patch $readmemh path to absolute so Yosys finds it regardless of CWD
TOP_V="$BUILD/top_oled_image_patched.v"
sed "s|build/fb_image.mem|$BUILD/fb_image.mem|" "$RTL/top_oled_image.v" > "$TOP_V"
yosys -p "
    read_verilog $RTL/ssd1306_i2c.v
    read_verilog $TOP_V
    chparam -set CLK_DIV $CLKDIV top_oled_image
    synth_ecp5 -nowidelut -abc2 -top top_oled_image -json $BUILD/oled_image.json
    stat
" > "$BUILD/oled_image_yosys.log" 2>&1
grep -E "^(=== |   Number of|   Estimated)" "$BUILD/oled_image_yosys.log" || tail -10 "$BUILD/oled_image_yosys.log"

echo ""
echo "--- Place & Route ---"
nextpnr-ecp5 --25k --package CABGA256 --speed 6 --seed "$SEED" \
    --lpf "$LPF" --freq 25 \
    --json "$BUILD/oled_image.json" \
    --textcfg "$BUILD/oled_image.config" \
    2>&1 | tee "$BUILD/oled_image_pnr.log" | grep -E "(Info|Warning|Error|MHz)"

echo ""
echo "--- Pack bitstream ---"
ecppack --svf "$BUILD/oled_image.svf" "$BUILD/oled_image.config" "$BUILD/oled_image.bit"
echo "Bitstream: $BUILD/oled_image.bit"

if [ "$PROGRAM" -eq 1 ]; then
    echo ""
    echo "--- Program SRAM ---"
    openFPGALoader -c ft232 "$BUILD/oled_image.svf"
fi

if [ "$FLASH" -eq 1 ]; then
    echo ""
    echo "--- Write flash ---"
    openFPGALoader -c ft232 --write-flash "$BUILD/oled_image.bit"
fi

echo ""
echo "Done."

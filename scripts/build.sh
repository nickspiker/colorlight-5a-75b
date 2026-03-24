#!/bin/bash
# Build FPGA designs for Colorlight 5A-75B (ECP5-25F).
#
# Usage:
#   DUT=<name> ./build.sh [FREQ_MHZ] [--program]
#
# DUTs:
#   display_test   button toggles PASS/FAIL on NTSC + OLED (default)
#   keypad_test    4x5 matrix keypad scanner, col/row shown on OLED
#   pin_scan       drive all HUB75 data pins to find keypad wires
#
# FREQ_MHZ=25 uses raw clock (no PLL). Any other value uses PLL.
#
# Examples:
#   ./build.sh                           # display_test @ 25 MHz
#   DUT=keypad_test ./build.sh --program # keypad_test @ 25 MHz, program
#   DUT=pin_scan    ./build.sh --program

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJ_DIR="$SCRIPT_DIR/.."
RTL="$PROJ_DIR/rtl"
LPF_DEFAULT="$PROJ_DIR/constraints/colorlight_5a75b_v8.lpf"
LPF="$LPF_DEFAULT"
BUILD="$PROJ_DIR/build"

FREQ="${1:-25}"
PROGRAM="${2:-}"
DUT="${DUT:-display_test}"

mkdir -p "$BUILD"
cd "$PROJ_DIR"

# -------------------------------------------------------------------------
# Compute PLL parameters (skip if 25 MHz)
# -------------------------------------------------------------------------
PLL_DEFINES=""
if [ "$FREQ" != "25" ]; then
    PLL_OUT=$(ecppll -i 25 -o "$FREQ" -f /dev/null 2>&1)
    CLKI=$(echo "$PLL_OUT"    | awk '/Refclk divisor:/  {print $3}')
    CLKFB=$(echo "$PLL_OUT"   | awk '/Feedback divisor:/ {print $3}')
    CLKOP=$(echo "$PLL_OUT"   | awk '/clkout0 divisor:/  {print $3}')
    ACTUAL_FREQ=$(echo "$PLL_OUT" | awk '/clkout0 frequency:/ {print $3}')
    FVCO=$(echo "$PLL_OUT"    | awk '/VCO frequency:/    {print $3}')
    if [ -z "$CLKI" ] || [ -z "$CLKFB" ] || [ -z "$CLKOP" ]; then
        echo "ERROR: ecppll failed for ${FREQ} MHz"
        echo "$PLL_OUT"
        exit 1
    fi
    CPHASE=$(( (CLKOP - 1) / 2 ))
    PLL_DEFINES="-DPLL_CLKI_DIV=$CLKI -DPLL_CLKFB_DIV=$CLKFB -DPLL_CLKOP_DIV=$CLKOP -DPLL_CLKOP_CPHASE=$CPHASE"
    echo "================================================================"
    echo " $DUT @ ${ACTUAL_FREQ} MHz"
    echo " PLL: CLKI=$CLKI CLKFB=$CLKFB CLKOP=$CLKOP (VCO=${FVCO} MHz)"
    echo "================================================================"
else
    echo "================================================================"
    echo " $DUT @ 25 MHz (no PLL)"
    echo "================================================================"
fi

# -------------------------------------------------------------------------
# DUT selection
# -------------------------------------------------------------------------
PNR_EXTRA=""
case "$DUT" in
    display_test)
        echo "  display test: button toggles PASS/FAIL on NTSC + OLED"
        ;;
    keypad_test)
        echo "  keypad test: 4x5 matrix scanner, col/row on OLED"
        PNR_EXTRA="--ignore-loops --timing-allow-fail"
        ;;
    pin_scan)
        echo "  pin scanner: drive all HUB75 data pins, probe for shorts"
        LPF="$PROJ_DIR/constraints/pin_scan.lpf"
        PNR_EXTRA="--ignore-loops --timing-allow-fail"
        ;;
    *)
        echo "ERROR: unknown DUT='$DUT'. Use: display_test | keypad_test | pin_scan"
        exit 1
        ;;
esac

# -------------------------------------------------------------------------
# Synthesize
# -------------------------------------------------------------------------
echo ""
echo "--- Synthesize ---"
case "$DUT" in
    display_test)
        yosys -p "
            read_verilog $RTL/ntsc_framebuf.v
            read_verilog $RTL/ssd1306_i2c.v
            read_verilog $RTL/ssd1306_oled.v
            read_verilog $RTL/top_display_test.v
            synth_ecp5 -nowidelut -top top_display_test -json $BUILD/top.json
            stat
        " > "$BUILD/yosys.log" 2>&1
        ;;
    keypad_test)
        # -abc2 avoids ABC9 loop assertion on combinational keypad feedback
        yosys -p "
            read_verilog $RTL/keypad_scan.v
            read_verilog $RTL/ssd1306_i2c.v
            read_verilog $RTL/ssd1306_oled.v
            read_verilog $RTL/top_keypad_test.v
            synth_ecp5 -nowidelut -abc2 -top top_keypad_test -json $BUILD/top.json
            stat
        " > "$BUILD/yosys.log" 2>&1
        ;;
    pin_scan)
        yosys -p "
            read_verilog $RTL/ntsc_framebuf.v
            read_verilog $RTL/ssd1306_i2c.v
            read_verilog $RTL/ssd1306_oled.v
            read_verilog $RTL/top_pin_scan.v
            synth_ecp5 -nowidelut -abc2 -top top_pin_scan -json $BUILD/top.json
            stat
        " > "$BUILD/yosys.log" 2>&1
        ;;
esac

grep -E '^\s+[0-9]+ +(LUT4|TRELLIS_FF|MULT18X18D|CCU2C|EHXPLLL|DP16KD)$' "$BUILD/yosys.log" || true
if grep -q 'ERROR' "$BUILD/yosys.log"; then
    echo "YOSYS ERROR — see $BUILD/yosys.log"
    exit 1
fi

# -------------------------------------------------------------------------
# Place and route
# -------------------------------------------------------------------------
echo ""
echo "--- Place & Route ---"
SEED="${SEED:-1}"
nextpnr-ecp5 --25k --package CABGA256 --speed 6 --seed "$SEED" \
    $PNR_EXTRA \
    --json "$BUILD/top.json" \
    --lpf  "$LPF" \
    --textcfg "$BUILD/top.config" \
    > "$BUILD/pnr.log" 2>&1 || true

grep -E '(Max frequency|logic,)' "$BUILD/pnr.log" || true
if grep -q 'ERROR' "$BUILD/pnr.log"; then
    echo "PNR ERROR — see $BUILD/pnr.log"
    exit 1
fi

# -------------------------------------------------------------------------
# Pack bitstream + SVF
# -------------------------------------------------------------------------
echo ""
echo "--- Pack ---"
ecppack --svf "$BUILD/top.svf" "$BUILD/top.config" "$BUILD/top.bit"
echo "Bitstream: $BUILD/top.bit ($(stat -c%s "$BUILD/top.bit") bytes)"

# -------------------------------------------------------------------------
# Program
# -------------------------------------------------------------------------
if [ "$PROGRAM" = "--program" ]; then
    echo ""
    echo "--- Program (SVF/SRAM) ---"
    openFPGALoader -c ft232 "$BUILD/top.svf"
    echo "Done."
else
    echo ""
    echo "Done. To program:"
    echo "  openFPGALoader -c ft232 $BUILD/top.svf"
fi

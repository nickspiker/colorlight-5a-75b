// ECP5 PLL: 25 MHz → 800 MHz (CLKOP) + 25 MHz (CLKOS)
//
// VCO = 25 × 32 / 1 = 800 MHz
// CLKOP = 800 / 1 = 800 MHz  (PWM clock)
// CLKOS = 800 / 32 = 25 MHz  (NTSC + BRAM clock)

`default_nettype none

module pll_200 (
    input  wire clk_25,
    output wire clk_800,
    output wire clk_25_pll,
    output wire locked
);

    EHXPLLL #(
        .PLLRST_ENA      ("DISABLED"),
        .INTFB_WAKE      ("DISABLED"),
        .STDBY_ENABLE    ("DISABLED"),
        .DPHASE_SOURCE   ("DISABLED"),
        .OUTDIVIDER_MUXA ("DIVA"),
        .OUTDIVIDER_MUXB ("DIVB"),
        .OUTDIVIDER_MUXC ("DIVC"),
        .OUTDIVIDER_MUXD ("DIVD"),
        .CLKI_DIV        (1),
        .CLKFB_DIV       (32),
        .CLKOP_DIV       (1),
        .CLKOP_ENABLE    ("ENABLED"),
        .CLKOP_CPHASE    (0),
        .CLKOP_FPHASE    (0),
        .CLKOS_DIV       (32),
        .CLKOS_ENABLE    ("ENABLED"),
        .CLKOS_CPHASE    (0),
        .CLKOS_FPHASE    (0),
        .CLKOS2_ENABLE   ("DISABLED"),
        .CLKOS3_ENABLE   ("DISABLED"),
        .FEEDBK_PATH     ("CLKOP"),
        .CLKOP_TRIM_POL  ("RISING"),
        .CLKOP_TRIM_DELAY(0)
    ) pll (
        .CLKI   (clk_25),
        .CLKFB  (clk_800),
        .CLKOP  (clk_800),
        .CLKOS  (clk_25_pll),
        .LOCK   (locked),
        .PHASESEL0(1'b0),
        .PHASESEL1(1'b0),
        .PHASEDIR (1'b0),
        .PHASESTEP(1'b0),
        .PHASELOADREG(1'b0),
        .PLLWAKESYNC (1'b0),
        .RST    (1'b0),
        .STDBY  (1'b0)
    );

endmodule

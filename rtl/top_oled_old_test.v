// Minimal wrapper: old ssd1306_oled + ssd1306_i2c (self-contained CLK_DIV=64)
// All 4 registers = all-1s → every pixel white on the register-bar display
module top_oled_old_test (
    input  wire clk,
    output wire oled_scl,
    output wire oled_sda,
    output wire led
);
    assign led = 1'b0;  // solid on (active-low) = new bitstream running

    ssd1306_oled oled (
        .clk  (clk),
        .rst  (1'b0),
        .reg0 (128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .reg1 (128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .reg2 (128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .reg3 (128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .scl  (oled_scl),
        .sda  (oled_sda)
    );
endmodule

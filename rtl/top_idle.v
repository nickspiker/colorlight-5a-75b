// Idle bitstream — I2C bus held high (safe idle), LED blinks at ~1Hz
// Uses the same CLK_DIV counter structure proven to work in blink test
module top_idle #(
    parameter integer CLK_DIV = 12500000
)(
    input  wire clk,
    output wire oled_scl,
    output wire oled_sda,
    output wire led
);
    assign oled_scl = scl_tog;  // SCL blinks — confirms P2 drives
    assign oled_sda = 1'b1;

    localparam [31:0] CNT_TOP = CLK_DIV - 1;
    reg [31:0] cnt = 32'd0;
    wire       at_top = (cnt == CNT_TOP);
    always @(posedge clk)
        cnt <= at_top ? 32'd0 : (cnt + 32'd1);

    reg ce = 1'b0;
    always @(posedge clk)
        ce <= at_top;

    reg scl_tog = 1'b0;
    always @(posedge clk)
        if (ce) scl_tog <= ~scl_tog;

    assign led = ~scl_tog;  // same as working blink test
endmodule

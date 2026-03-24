// top_grey_test — greyscale NTSC display, dual-clock
// clk_25_pll → NTSC logic + BRAM
// clk_800    → PWM counter + video output

`default_nettype none

module top_grey_test (
    input  wire clk,
    output reg  led,
    input  wire btn,
    output wire ntsc_sync,
    output wire ntsc_vid
);

    wire clk_800, clk_25_pll, locked;

    pll_200 u_pll (
        .clk_25     (clk),
        .clk_800    (clk_800),
        .clk_25_pll (clk_25_pll),
        .locked     (locked)
    );

    ntsc_grey u_ntsc (
        .clk_25   (clk_25_pll),
        .clk_800  (clk_800),
        .sync_pin (ntsc_sync),
        .video_pin(ntsc_vid)
    );

    reg [24:0] blink_ctr = 0;
    always @(posedge clk) begin
        blink_ctr <= blink_ctr + 1;
        led       <= ~blink_ctr[24];
    end

endmodule

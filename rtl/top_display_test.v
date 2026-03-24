// Display test — button toggles PASS/FAIL on CRT + LED on/off
// No DUT, no PLL, just 25 MHz raw clock.

module top_display_test (
    input  wire clk,       // 25 MHz
    output reg  led,       // active-low
    input  wire btn,       // active-low
    output reg  ntsc_sync,
    output reg  ntsc_vid,
    output wire oled_scl,
    output wire oled_sda
);

    // Button sync (2-FF)
    reg [1:0] btn_sync = 2'b11;
    always @(posedge clk) btn_sync <= {btn_sync[0], btn};
    wire btn_pressed = ~btn_sync[1];

    // Edge detect for toggle
    reg btn_prev = 0;
    always @(posedge clk) btn_prev <= btn_pressed;
    wire btn_edge = btn_pressed & ~btn_prev;

    // Toggle state: 0=PASS (white bg, black text), 1=FAIL (black bg, white text)
    reg fail_mode = 1;
    always @(posedge clk)
        if (btn_edge) fail_mode <= ~fail_mode;

    // OLED reset: hold reset for first ~50ms after FPGA config (25MHz * 1.25M)
    reg [20:0] oled_rst_ctr = 0;
    wire oled_rst = ~&oled_rst_ctr;  // active-high, drops after counter saturates
    always @(posedge clk)
        if (!(&oled_rst_ctr)) oled_rst_ctr <= oled_rst_ctr + 1;

    // Status: 1=PASS, 2=FAIL
    wire [1:0] status = fail_mode ? 2'd2 : 2'd1;

    // LED: active-low, ON in pass mode, OFF in fail mode
    always @(posedge clk) led <= fail_mode;

    // NTSC
    wire ntsc_sync_w, ntsc_vid_w;

    ntsc_framebuf #(
        .FB_W    (320),
        .FB_H    (240),
        .H_SCALE (4)
    ) ntsc (
        .clk       (clk),
        .status    (status),
        .hash      (32'hDEADBEEF),
        .hash2     (32'hCAFEBABE),
        .sync_pin  (ntsc_sync_w),
        .video_pin (ntsc_vid_w)
    );

    always @(posedge clk) begin
        ntsc_sync <= ntsc_sync_w;
        ntsc_vid  <= ntsc_vid_w;
    end

    // OLED — RUN text encoded as bar columns (each bit = 1 col, 16px tall)
    ssd1306_oled oled (
        .clk          (clk),
        .rst          (oled_rst),
        .reg0         (128'h00000F80001FFFFFFFFFFFF0000FFF80),
        .reg1         (128'hC0000F80001F0000000001F00000FFFF),
        .reg2         (128'hFFF00F80001F0000000001F00007FC00),
        .reg3         (128'h00FFFF80001F0000000001F00007FFFF),
        .overlay_gate (16'h0000),
        .scl          (oled_scl),
        .sda          (oled_sda)
    );

endmodule

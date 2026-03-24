// NTSC greyscale — 320×240, 5-bit intensity (32 levels), dual clock
//
// clk_25:  NTSC timing, BRAM reads, pixel counters  (25 MHz, H_SCALE=4)
// clk_800: PWM sub-tick counter + video_pin output   (800 MHz)
//
// Each 25 MHz pixel slot = 32 × 800 MHz ticks → 32 grey levels.
// PWM: video HIGH for first `intensity` ticks out of 32.
//
// ROM: 4 bitplanes (grey0/grey1/grey2/grey3), 9600 bytes each, read at 25 MHz.
// Pixel intensity = {plane0_bit, plane1_bit, plane2_bit, plane3_bit} (4-bit, 0-15).
// 5-bit intensity = {pixel_int, 1'b0} → 0→0, 15→30 (even levels).
//
// Half-step blending: 16-stage 800 MHz shift register on CDC path.
// Intensity updates at tick 16 of each pixel slot rather than tick 0.
// At boundaries: 16 ticks of old pixel then 16 ticks of new → blended PWM.
// Odd intermediate levels appear at every pixel edge.
//
// Pixel stable for 40 ns; 16-tap delay = 20 ns — still safe for CDC.

`default_nettype none

module ntsc_grey #(
    parameter FB_W    = 320,
    parameter FB_H    = 240,
    parameter H_SCALE = 4
)(
    input  wire clk_25,   // 25 MHz — NTSC logic + BRAM
    input  wire clk_800,  // 800 MHz — PWM + video output
    output reg  sync_pin,
    output reg  video_pin
);

    // =========================================================================
    // NTSC timing (25 MHz — identical to original ntsc_framebuf)
    // =========================================================================
    localparam H_TOTAL   = 1589;
    localparam H_SYNC    =  118;
    localparam H_BACK    =  142;
    localparam H_MAX_ACT = 1280;
    localparam V_TOTAL   = 262;
    localparam V_SYNC    =   3;
    localparam V_TOP     =  19;
    localparam V_MAX_ACT = 240;

    localparam H_CONTENT       = FB_W * H_SCALE;
    localparam H_BORDER        = (H_MAX_ACT - H_CONTENT) / 2;
    localparam H_CONTENT_START = H_SYNC + H_BACK + H_BORDER;
    localparam V_BORDER        = (V_MAX_ACT - FB_H) / 2;
    localparam V_CONTENT_START = V_SYNC + V_TOP + V_BORDER;

    localparam FB_BYTES = (FB_W / 8) * FB_H;   // 9600

    reg [10:0] h_cnt = 0;
    reg  [8:0] v_cnt = 0;
    wire h_end = (h_cnt == H_TOTAL - 1);

    always @(posedge clk_25) begin
        if (h_end) begin
            h_cnt <= 0;
            v_cnt <= (v_cnt == V_TOTAL - 1) ? 0 : v_cnt + 1;
        end else
            h_cnt <= h_cnt + 1;
    end

    wire in_sync = (h_cnt < H_SYNC) | (v_cnt < V_SYNC);

    wire h_in_content = (h_cnt >= H_CONTENT_START) &&
                        (h_cnt <  H_CONTENT_START + H_CONTENT);
    wire v_in_content = (v_cnt >= V_CONTENT_START) &&
                        (v_cnt <  V_CONTENT_START + FB_H);

    reg [1:0] h_scale_cnt = 0;
    reg [9:0] fb_x        = 0;

    always @(posedge clk_25) begin
        if (h_cnt == H_CONTENT_START - 1) begin
            h_scale_cnt <= 0;
            fb_x        <= 0;
        end else if (h_in_content) begin
            if (h_scale_cnt == H_SCALE - 1) begin
                h_scale_cnt <= 0;
                fb_x        <= fb_x + 1;
            end else
                h_scale_cnt <= h_scale_cnt + 1;
        end
    end

    wire [8:0] fb_y = v_cnt - V_CONTENT_START;

    // =========================================================================
    // 4-bitplane ROM (25 MHz)
    // =========================================================================
    reg [7:0] rom0 [0:FB_BYTES-1];
    reg [7:0] rom1 [0:FB_BYTES-1];
    reg [7:0] rom2 [0:FB_BYTES-1];
    reg [7:0] rom3 [0:FB_BYTES-1];
    initial $readmemh("build/grey0.mem", rom0);
    initial $readmemh("build/grey1.mem", rom1);
    initial $readmemh("build/grey2.mem", rom2);
    initial $readmemh("build/grey3.mem", rom3);

    wire [13:0] row_offset  = {fb_y, 5'b0} + {2'b0, fb_y, 3'b0};
    wire [13:0] fb_addr     = row_offset + fb_x[9:3];
    wire  [2:0] fb_bit      = fb_x[2:0];

    reg [7:0] byte0, byte1, byte2, byte3;
    reg [2:0] fb_bit_d1;
    reg       content_d1, sync_d1;

    always @(posedge clk_25) begin
        byte0      <= rom0[fb_addr];
        byte1      <= rom1[fb_addr];
        byte2      <= rom2[fb_addr];
        byte3      <= rom3[fb_addr];
        fb_bit_d1  <= fb_bit;
        content_d1 <= h_in_content & v_in_content;
        sync_d1    <= in_sync;
    end

    // 4-bit pixel; scale to 5-bit: {p[3:0], 1'b0} → 0→0, 15→30 (even steps)
    // rom0=MSB, rom3=LSB
    wire [3:0] pixel_int = {
        byte0[7 - fb_bit_d1],
        byte1[7 - fb_bit_d1],
        byte2[7 - fb_bit_d1],
        byte3[7 - fb_bit_d1]
    };
    wire [4:0] intensity = {pixel_int, 1'b0};

    // =========================================================================
    // CDC: 16-stage 800 MHz shift register for half-step blending
    //
    // Intensity is stable for 40 ns (one clk_25 period).
    // 16 stages × 1.25 ns = 20 ns delay — still 20 ns of valid window.
    // The delay places the CDC capture at tick 16 of each 32-tick pixel slot:
    //   ticks  0-15 → old pixel's intensity drives PWM
    //   ticks 16-31 → new pixel's intensity drives PWM
    // Result: boundary pixels blend, producing odd intermediate PWM levels.
    // =========================================================================
    reg [6:0] pipe [0:15];   // [6:2]=intensity [1]=content [0]=sync

    integer i;
    always @(posedge clk_800) begin
        pipe[0] <= {intensity, content_d1, sync_d1};
        for (i = 1; i < 16; i = i + 1)
            pipe[i] <= pipe[i-1];
    end

    wire [4:0] intensity_800 = pipe[15][6:2];
    wire       content_800   = pipe[15][1];
    wire       sync_800      = pipe[15][0];

    // =========================================================================
    // PWM counter + video output (800 MHz)
    // =========================================================================
    reg [4:0] pwm_cnt = 0;

    always @(posedge clk_800)
        pwm_cnt <= pwm_cnt + 1;

    wire video_pwm = (pwm_cnt < intensity_800);

    always @(posedge clk_800) begin
        sync_pin  <= ~sync_800;
        video_pin <= content_800 & video_pwm;
    end

endmodule

// top_pin_scan.v — active pin continuity scanner with SH1106 OLED display
//
// Scans 67 I/O pins sequentially: one pin tristated (pullup → HIGH),
// other 66 driven LOW. 1 kHz tick → 1 ms settling per pin, 67 ms full cycle.
//
// Display (128×64, SH1106 I2C):
//   Pages 0–3 (top 32 rows): columns 0–66 = pin state (white=HIGH, black=LOW)
//   Page 4: binary ruler bits 0–3 (2 px thick each)
//   Page 5: binary ruler bits 4–6 (2 px thick each)
//   Pages 6–7: blank
//
// LED (active-low): lit when any pin reads LOW.

module top_pin_scan #(
    parameter integer CLK_DIV = 7
)(
    input  wire clk,
    output wire oled_scl,
    output wire oled_sda,
    output wire led,
    input  wire btn,
    output wire ntsc_sync,
    output wire ntsc_vid,
    inout  wire p0,  inout  wire p1,  inout  wire p2,  inout  wire p3,
    inout  wire p4,  inout  wire p5,  inout  wire p6,  inout  wire p7,
    inout  wire p8,  inout  wire p9,  inout  wire p10, inout  wire p11,
    inout  wire p12, inout  wire p13, inout  wire p14, inout  wire p15,
    inout  wire p16, inout  wire p17, inout  wire p18, inout  wire p19,
    inout  wire p20, inout  wire p21, inout  wire p22, inout  wire p23,
    inout  wire p24, inout  wire p25, inout  wire p26, inout  wire p27,
    inout  wire p28, inout  wire p29, inout  wire p30, inout  wire p31,
    inout  wire p32, inout  wire p33, inout  wire p34, inout  wire p35,
    inout  wire p36, inout  wire p37, inout  wire p38, inout  wire p39,
    inout  wire p40, inout  wire p41, inout  wire p42, inout  wire p43,
    inout  wire p44, inout  wire p45, inout  wire p46, inout  wire p47,
    inout  wire p48, inout  wire p49, inout  wire p50, inout  wire p51,
    inout  wire p52, inout  wire p53, inout  wire p54, inout  wire p55,
    inout  wire p56, inout  wire p57, inout  wire p58, inout  wire p59,
    inout  wire p60, inout  wire p61, inout  wire p62, inout  wire p63,
    inout  wire p64, inout  wire p65, inout  wire p66
);

    // Unused outputs
    assign ntsc_sync = 1'b0;
    assign ntsc_vid  = 1'b0;

    // =========================================================================
    // Explicit BB primitives — Yosys can't infer tristate from ? 1'bz : 1'b0
    // BB: T=1 → tristate (input), T=0 → drive I onto B
    // =========================================================================
    reg [6:0] scan_idx = 0;
    wire [66:0] pin_in;
    wire [66:0] pin_t;  // per-pin tristate: 1 = input (being scanned), 0 = drive LOW

    genvar gi;
    generate
        for (gi = 0; gi < 67; gi = gi + 1) begin : pin_bb
            assign pin_t[gi] = 1'b1;  // DIAGNOSTIC: all tristated, no driving
        end
    endgenerate

    BB bb_p0  (.B(p0),  .I(1'b0), .T(pin_t[ 0]), .O(pin_in[ 0]));
    BB bb_p1  (.B(p1),  .I(1'b0), .T(pin_t[ 1]), .O(pin_in[ 1]));
    BB bb_p2  (.B(p2),  .I(1'b0), .T(pin_t[ 2]), .O(pin_in[ 2]));
    BB bb_p3  (.B(p3),  .I(1'b0), .T(pin_t[ 3]), .O(pin_in[ 3]));
    BB bb_p4  (.B(p4),  .I(1'b0), .T(pin_t[ 4]), .O(pin_in[ 4]));
    BB bb_p5  (.B(p5),  .I(1'b0), .T(pin_t[ 5]), .O(pin_in[ 5]));
    BB bb_p6  (.B(p6),  .I(1'b0), .T(pin_t[ 6]), .O(pin_in[ 6]));
    BB bb_p7  (.B(p7),  .I(1'b0), .T(pin_t[ 7]), .O(pin_in[ 7]));
    BB bb_p8  (.B(p8),  .I(1'b0), .T(pin_t[ 8]), .O(pin_in[ 8]));
    BB bb_p9  (.B(p9),  .I(1'b0), .T(pin_t[ 9]), .O(pin_in[ 9]));
    BB bb_p10 (.B(p10), .I(1'b0), .T(pin_t[10]), .O(pin_in[10]));
    BB bb_p11 (.B(p11), .I(1'b0), .T(pin_t[11]), .O(pin_in[11]));
    BB bb_p12 (.B(p12), .I(1'b0), .T(pin_t[12]), .O(pin_in[12]));
    BB bb_p13 (.B(p13), .I(1'b0), .T(pin_t[13]), .O(pin_in[13]));
    BB bb_p14 (.B(p14), .I(1'b0), .T(pin_t[14]), .O(pin_in[14]));
    BB bb_p15 (.B(p15), .I(1'b0), .T(pin_t[15]), .O(pin_in[15]));
    BB bb_p16 (.B(p16), .I(1'b0), .T(pin_t[16]), .O(pin_in[16]));
    BB bb_p17 (.B(p17), .I(1'b0), .T(pin_t[17]), .O(pin_in[17]));
    BB bb_p18 (.B(p18), .I(1'b0), .T(pin_t[18]), .O(pin_in[18]));
    BB bb_p19 (.B(p19), .I(1'b0), .T(pin_t[19]), .O(pin_in[19]));
    BB bb_p20 (.B(p20), .I(1'b0), .T(pin_t[20]), .O(pin_in[20]));
    BB bb_p21 (.B(p21), .I(1'b0), .T(pin_t[21]), .O(pin_in[21]));
    BB bb_p22 (.B(p22), .I(1'b0), .T(pin_t[22]), .O(pin_in[22]));
    BB bb_p23 (.B(p23), .I(1'b0), .T(pin_t[23]), .O(pin_in[23]));
    BB bb_p24 (.B(p24), .I(1'b0), .T(pin_t[24]), .O(pin_in[24]));
    BB bb_p25 (.B(p25), .I(1'b0), .T(pin_t[25]), .O(pin_in[25]));
    BB bb_p26 (.B(p26), .I(1'b0), .T(pin_t[26]), .O(pin_in[26]));
    BB bb_p27 (.B(p27), .I(1'b0), .T(pin_t[27]), .O(pin_in[27]));
    BB bb_p28 (.B(p28), .I(1'b0), .T(pin_t[28]), .O(pin_in[28]));
    BB bb_p29 (.B(p29), .I(1'b0), .T(pin_t[29]), .O(pin_in[29]));
    BB bb_p30 (.B(p30), .I(1'b0), .T(pin_t[30]), .O(pin_in[30]));
    BB bb_p31 (.B(p31), .I(1'b0), .T(pin_t[31]), .O(pin_in[31]));
    BB bb_p32 (.B(p32), .I(1'b0), .T(pin_t[32]), .O(pin_in[32]));
    BB bb_p33 (.B(p33), .I(1'b0), .T(pin_t[33]), .O(pin_in[33]));
    BB bb_p34 (.B(p34), .I(1'b0), .T(pin_t[34]), .O(pin_in[34]));
    BB bb_p35 (.B(p35), .I(1'b0), .T(pin_t[35]), .O(pin_in[35]));
    BB bb_p36 (.B(p36), .I(1'b0), .T(pin_t[36]), .O(pin_in[36]));
    BB bb_p37 (.B(p37), .I(1'b0), .T(pin_t[37]), .O(pin_in[37]));
    BB bb_p38 (.B(p38), .I(1'b0), .T(pin_t[38]), .O(pin_in[38]));
    BB bb_p39 (.B(p39), .I(1'b0), .T(pin_t[39]), .O(pin_in[39]));
    BB bb_p40 (.B(p40), .I(1'b0), .T(pin_t[40]), .O(pin_in[40]));
    BB bb_p41 (.B(p41), .I(1'b0), .T(pin_t[41]), .O(pin_in[41]));
    BB bb_p42 (.B(p42), .I(1'b0), .T(pin_t[42]), .O(pin_in[42]));
    BB bb_p43 (.B(p43), .I(1'b0), .T(pin_t[43]), .O(pin_in[43]));
    BB bb_p44 (.B(p44), .I(1'b0), .T(pin_t[44]), .O(pin_in[44]));
    BB bb_p45 (.B(p45), .I(1'b0), .T(pin_t[45]), .O(pin_in[45]));
    BB bb_p46 (.B(p46), .I(1'b0), .T(pin_t[46]), .O(pin_in[46]));
    BB bb_p47 (.B(p47), .I(1'b0), .T(pin_t[47]), .O(pin_in[47]));
    BB bb_p48 (.B(p48), .I(1'b0), .T(pin_t[48]), .O(pin_in[48]));
    BB bb_p49 (.B(p49), .I(1'b0), .T(pin_t[49]), .O(pin_in[49]));
    BB bb_p50 (.B(p50), .I(1'b0), .T(pin_t[50]), .O(pin_in[50]));
    BB bb_p51 (.B(p51), .I(1'b0), .T(pin_t[51]), .O(pin_in[51]));
    BB bb_p52 (.B(p52), .I(1'b0), .T(pin_t[52]), .O(pin_in[52]));
    BB bb_p53 (.B(p53), .I(1'b0), .T(pin_t[53]), .O(pin_in[53]));
    BB bb_p54 (.B(p54), .I(1'b0), .T(pin_t[54]), .O(pin_in[54]));
    BB bb_p55 (.B(p55), .I(1'b0), .T(pin_t[55]), .O(pin_in[55]));
    BB bb_p56 (.B(p56), .I(1'b0), .T(pin_t[56]), .O(pin_in[56]));
    BB bb_p57 (.B(p57), .I(1'b0), .T(pin_t[57]), .O(pin_in[57]));
    BB bb_p58 (.B(p58), .I(1'b0), .T(pin_t[58]), .O(pin_in[58]));
    BB bb_p59 (.B(p59), .I(1'b0), .T(pin_t[59]), .O(pin_in[59]));
    BB bb_p60 (.B(p60), .I(1'b0), .T(pin_t[60]), .O(pin_in[60]));
    BB bb_p61 (.B(p61), .I(1'b0), .T(pin_t[61]), .O(pin_in[61]));
    BB bb_p62 (.B(p62), .I(1'b0), .T(pin_t[62]), .O(pin_in[62]));
    BB bb_p63 (.B(p63), .I(1'b0), .T(pin_t[63]), .O(pin_in[63]));
    BB bb_p64 (.B(p64), .I(1'b0), .T(pin_t[64]), .O(pin_in[64]));
    BB bb_p65 (.B(p65), .I(1'b0), .T(pin_t[65]), .O(pin_in[65]));
    BB bb_p66 (.B(p66), .I(1'b0), .T(pin_t[66]), .O(pin_in[66]));

    // =========================================================================
    // Pin scanner — 1 kHz tick, 67 ms full cycle
    // =========================================================================
    reg [17:0] scan_timer = 0;
    reg [66:0] pin_result = {67{1'b1}};

    wire scan_tick = (scan_timer == 18'd199999);  // 25MHz / 200000 = 125 Hz (~8ms per pin)
    always @(posedge clk) begin
        scan_timer <= scan_tick ? 18'd0 : scan_timer + 1;
        if (scan_tick) begin
            pin_result[scan_idx] <= pin_in[scan_idx];
            scan_idx <= (scan_idx == 7'd66) ? 7'd0 : scan_idx + 1;
        end
    end

    // LED: ~12 Hz heartbeat
    reg [20:0] led_cnt = 0;
    always @(posedge clk) led_cnt <= led_cnt + 1;
    assign led = led_cnt[20];  // 25MHz / 2^21 ≈ 11.9 Hz toggle, 50% duty

    // =========================================================================
    // CE — ticks OLED FSM at I2C speed
    // =========================================================================
    reg [$clog2(CLK_DIV)-1:0] cnt = 0;
    wire at_top = (cnt == CLK_DIV - 1);
    always @(posedge clk) cnt <= at_top ? 0 : cnt + 1;
    reg ce = 0;
    always @(posedge clk) ce <= at_top;

    // =========================================================================
    // I2C driver
    // =========================================================================
    reg  [7:0] i2c_data;
    reg        i2c_start;
    reg        i2c_send_stop;
    wire       i2c_busy;

    ssd1306_i2c #(.CLK_DIV(CLK_DIV)) i2c (
        .clk(clk), .rst(1'b0),
        .data(i2c_data),
        .start(i2c_start),
        .send_start(1'b0),
        .send_stop(i2c_send_stop),
        .busy(i2c_busy),
        .scl(oled_scl), .sda(oled_sda)
    );

    // =========================================================================
    // Init command table
    // =========================================================================
    localparam I2C_ADDR    = 8'h78;
    localparam CMD_PREFIX  = 8'h00;
    localparam DATA_PREFIX = 8'h40;
    localparam INIT_LEN    = 25;

    reg [7:0] init_cmds [0:INIT_LEN-1];
    initial begin
        init_cmds[ 0] = 8'hAE;
        init_cmds[ 1] = 8'hD5;
        init_cmds[ 2] = 8'h80;
        init_cmds[ 3] = 8'hA8;
        init_cmds[ 4] = 8'h3F;
        init_cmds[ 5] = 8'hD3;
        init_cmds[ 6] = 8'h00;
        init_cmds[ 7] = 8'h40;
        init_cmds[ 8] = 8'h8D;
        init_cmds[ 9] = 8'h14;
        init_cmds[10] = 8'hAD;
        init_cmds[11] = 8'h8B;
        init_cmds[12] = 8'hA1;
        init_cmds[13] = 8'hC8;
        init_cmds[14] = 8'hDA;
        init_cmds[15] = 8'h12;
        init_cmds[16] = 8'h81;
        init_cmds[17] = 8'hCF;
        init_cmds[18] = 8'hD9;
        init_cmds[19] = 8'hF1;
        init_cmds[20] = 8'hDB;
        init_cmds[21] = 8'h40;
        init_cmds[22] = 8'hA4;
        init_cmds[23] = 8'hA6;
        init_cmds[24] = 8'hAF;
    end

    // =========================================================================
    // Compute px_byte from page, col, and pin_result (no ROM, no gather)
    // =========================================================================
    wire pin_val = (col < 7'd67) ? pin_result[col] : 1'b0;

    wire scan_here = (col < 7'd67) && (col == scan_idx);

    wire [7:0] px_computed =
        (page <= 3'd2) ? {8{pin_val}} :                // pages 0-2: pin state
        (page == 3'd3) ? {scan_here, {7{pin_val}}} :   // page 3: D7 scan cursor + pin state
        (page == 3'd4) ? (col < 7'd67 ? {{2{col[3]}}, {2{col[2]}}, {2{col[1]}}, {2{col[0]}}}
                                       : 8'h00) :      // page 4: ruler bits 0-3
        (page == 3'd5) ? (col < 7'd67 ? {2'b00, {2{col[6]}}, {2{col[5]}}, {2{col[4]}}}
                                       : 8'h00) :      // page 5: ruler bits 4-6
        8'h00;

    // =========================================================================
    // OLED FSM — no gather state, px_byte computed directly
    // =========================================================================
    localparam [2:0]
        ST_RESET   = 3'd0,
        ST_SEND    = 3'd1,
        ST_WAIT    = 3'd2,
        ST_NEXT    = 3'd3,
        ST_BUSFREE = 3'd4,
        ST_COMPUTE = 3'd5;  // 1-tick: latch px_computed after col/page update

    localparam [1:0]
        PH_INIT      = 2'd0,
        PH_PAGE_CMD  = 2'd1,
        PH_PAGE_DATA = 2'd2;

    reg [2:0]  state       = ST_RESET;
    reg [1:0]  phase       = PH_INIT;
    reg [19:0] reset_cnt   = 0;
    reg [9:0]  busfree_cnt = 0;
    reg [4:0]  cmd_idx     = 0;
    reg [2:0]  page        = 0;
    reg [6:0]  col         = 0;
    reg [7:0]  px_byte     = 0;

    always @(posedge clk) if (ce) begin
        i2c_start <= 0;

        case (state)

            ST_RESET: begin
                reset_cnt <= reset_cnt + 1;
                if (&reset_cnt) begin
                    phase   <= PH_INIT;
                    cmd_idx <= 0;
                    page    <= 0;
                    col     <= 0;
                    state   <= ST_SEND;
                end
            end

            ST_SEND: begin
                if (!i2c_busy) begin
                    case (phase)
                        PH_INIT: begin
                            if (cmd_idx == 0) begin
                                i2c_data      <= I2C_ADDR;
                                i2c_send_stop <= 0;
                            end else if (cmd_idx == 1) begin
                                i2c_data      <= CMD_PREFIX;
                                i2c_send_stop <= 0;
                            end else begin
                                i2c_data      <= init_cmds[cmd_idx - 2];
                                i2c_send_stop <= (cmd_idx == INIT_LEN + 1);
                            end
                        end
                        PH_PAGE_CMD: begin
                            case (cmd_idx[2:0])
                                3'd0: begin i2c_data <= I2C_ADDR;             i2c_send_stop <= 0; end
                                3'd1: begin i2c_data <= CMD_PREFIX;            i2c_send_stop <= 0; end
                                3'd2: begin i2c_data <= 8'hB0 | {5'd0, page}; i2c_send_stop <= 0; end
                                3'd3: begin i2c_data <= 8'h02;                i2c_send_stop <= 0; end
                                3'd4: begin i2c_data <= 8'h10;                i2c_send_stop <= 1; end
                                default: ;
                            endcase
                        end
                        PH_PAGE_DATA: begin
                            if (cmd_idx == 0) begin
                                i2c_data      <= I2C_ADDR;
                                i2c_send_stop <= 0;
                            end else if (cmd_idx == 1) begin
                                i2c_data      <= DATA_PREFIX;
                                i2c_send_stop <= 0;
                            end else begin
                                i2c_data      <= px_byte;
                                i2c_send_stop <= (col == 7'd127);
                            end
                        end
                    endcase
                    i2c_start <= 1;
                    state     <= ST_WAIT;
                end
            end

            ST_WAIT: begin
                if (i2c_busy)
                    state <= ST_NEXT;
            end

            ST_NEXT: begin
                if (!i2c_busy) begin
                    case (phase)
                        PH_INIT: begin
                            if (cmd_idx == INIT_LEN + 1) begin
                                phase   <= PH_PAGE_CMD;
                                cmd_idx <= 0;
                                page    <= 0;
                                state   <= ST_BUSFREE;
                            end else begin
                                cmd_idx <= cmd_idx + 1;
                                state   <= ST_SEND;
                            end
                        end
                        PH_PAGE_CMD: begin
                            if (cmd_idx == 4) begin
                                phase   <= PH_PAGE_DATA;
                                cmd_idx <= 0;
                                col     <= 0;
                                state   <= ST_BUSFREE;
                            end else begin
                                cmd_idx <= cmd_idx + 1;
                                state   <= ST_SEND;
                            end
                        end
                        PH_PAGE_DATA: begin
                            if (cmd_idx < 2) begin
                                cmd_idx <= cmd_idx + 1;
                                state   <= (cmd_idx == 1) ? ST_COMPUTE : ST_SEND;
                            end else if (col == 7'd127) begin
                                phase   <= PH_PAGE_CMD;
                                cmd_idx <= 0;
                                page    <= (page == 3'd7) ? 3'd0 : page + 1;
                                state   <= ST_BUSFREE;
                            end else begin
                                col     <= col + 1;
                                state   <= ST_COMPUTE;
                            end
                        end
                    endcase
                end
            end

            ST_BUSFREE: begin
                busfree_cnt <= busfree_cnt + 1;
                if (&busfree_cnt) begin
                    busfree_cnt <= 0;
                    state       <= ST_SEND;
                end
            end

            // 1-tick compute: col/page updated last tick, px_computed now valid
            ST_COMPUTE: begin
                px_byte <= px_computed;
                state   <= ST_SEND;
            end

        endcase
    end

endmodule

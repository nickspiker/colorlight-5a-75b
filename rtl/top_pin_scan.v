// top_pin_scan.v — active pin scanner with 8bpp framebuffer + TRNG dithered OLED
//
// 67-pin sequential scanner with BB tristate I/O.
// 8-bit framebuffer (8192 bytes, 128×64) written continuously from pin state.
// TRNG dithering: 29 ring oscillators → temporal XOR → rotation mix → 8-bit threshold.
// Geiger-counter LED: random toggles from TRNG.

module top_pin_scan #(
    parameter integer CLK_DIV = 7
)(
    input  wire clk,
    output wire oled_scl,
    output wire oled_sda,
    output reg  led,
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
    inout  wire p64, output wire ext_led, inout  wire p66
);

    assign ntsc_sync = 1'b0;
    assign ntsc_vid  = 1'b0;

    // =========================================================================
    // BB tristate I/O — PIN FINDER MODE: all driven LOW, scan_idx driven HIGH
    // =========================================================================
    reg [6:0] scan_idx = 0;
    wire [66:0] pin_in;
    wire [66:0] pin_t;
    wire [66:0] pin_drv = 67'd0;  // drive LOW

    genvar gi;
    generate
        for (gi = 0; gi < 67; gi = gi + 1) begin : pin_bb
            // Active scan: only drive button pins LOW, tristate scanned pin. Float everything else.
            wire active = (gi==27)||(gi==28)||(gi==44)||(gi==49)||(gi==50)||(gi==51)||(gi==56)||(gi==62)||(gi==63);
            assign pin_t[gi] = !active || (scan_idx == gi[6:0]);
        end
    endgenerate

    BB bb_p0  (.B(p0),  .I(pin_drv[ 0]), .T(pin_t[ 0]), .O(pin_in[ 0]));
    BB bb_p1  (.B(p1),  .I(pin_drv[ 1]), .T(pin_t[ 1]), .O(pin_in[ 1]));
    BB bb_p2  (.B(p2),  .I(pin_drv[ 2]), .T(pin_t[ 2]), .O(pin_in[ 2]));
    BB bb_p3  (.B(p3),  .I(pin_drv[ 3]), .T(pin_t[ 3]), .O(pin_in[ 3]));
    BB bb_p4  (.B(p4),  .I(pin_drv[ 4]), .T(pin_t[ 4]), .O(pin_in[ 4]));
    BB bb_p5  (.B(p5),  .I(pin_drv[ 5]), .T(pin_t[ 5]), .O(pin_in[ 5]));
    BB bb_p6  (.B(p6),  .I(pin_drv[ 6]), .T(pin_t[ 6]), .O(pin_in[ 6]));
    BB bb_p7  (.B(p7),  .I(pin_drv[ 7]), .T(pin_t[ 7]), .O(pin_in[ 7]));
    BB bb_p8  (.B(p8),  .I(pin_drv[ 8]), .T(pin_t[ 8]), .O(pin_in[ 8]));
    BB bb_p9  (.B(p9),  .I(pin_drv[ 9]), .T(pin_t[ 9]), .O(pin_in[ 9]));
    BB bb_p10 (.B(p10), .I(pin_drv[10]), .T(pin_t[10]), .O(pin_in[10]));
    BB bb_p11 (.B(p11), .I(pin_drv[11]), .T(pin_t[11]), .O(pin_in[11]));
    BB bb_p12 (.B(p12), .I(pin_drv[12]), .T(pin_t[12]), .O(pin_in[12]));
    BB bb_p13 (.B(p13), .I(pin_drv[13]), .T(pin_t[13]), .O(pin_in[13]));
    BB bb_p14 (.B(p14), .I(pin_drv[14]), .T(pin_t[14]), .O(pin_in[14]));
    BB bb_p15 (.B(p15), .I(pin_drv[15]), .T(pin_t[15]), .O(pin_in[15]));
    BB bb_p16 (.B(p16), .I(pin_drv[16]), .T(pin_t[16]), .O(pin_in[16]));
    BB bb_p17 (.B(p17), .I(pin_drv[17]), .T(pin_t[17]), .O(pin_in[17]));
    BB bb_p18 (.B(p18), .I(pin_drv[18]), .T(pin_t[18]), .O(pin_in[18]));
    BB bb_p19 (.B(p19), .I(pin_drv[19]), .T(pin_t[19]), .O(pin_in[19]));
    BB bb_p20 (.B(p20), .I(pin_drv[20]), .T(pin_t[20]), .O(pin_in[20]));
    BB bb_p21 (.B(p21), .I(pin_drv[21]), .T(pin_t[21]), .O(pin_in[21]));
    BB bb_p22 (.B(p22), .I(pin_drv[22]), .T(pin_t[22]), .O(pin_in[22]));
    BB bb_p23 (.B(p23), .I(pin_drv[23]), .T(pin_t[23]), .O(pin_in[23]));
    BB bb_p24 (.B(p24), .I(pin_drv[24]), .T(pin_t[24]), .O(pin_in[24]));
    BB bb_p25 (.B(p25), .I(pin_drv[25]), .T(pin_t[25]), .O(pin_in[25]));
    BB bb_p26 (.B(p26), .I(pin_drv[26]), .T(pin_t[26]), .O(pin_in[26]));
    BB bb_p27 (.B(p27), .I(pin_drv[27]), .T(pin_t[27]), .O(pin_in[27]));
    BB bb_p28 (.B(p28), .I(pin_drv[28]), .T(pin_t[28]), .O(pin_in[28]));
    BB bb_p29 (.B(p29), .I(pin_drv[29]), .T(pin_t[29]), .O(pin_in[29]));
    BB bb_p30 (.B(p30), .I(pin_drv[30]), .T(pin_t[30]), .O(pin_in[30]));
    BB bb_p31 (.B(p31), .I(pin_drv[31]), .T(pin_t[31]), .O(pin_in[31]));
    BB bb_p32 (.B(p32), .I(pin_drv[32]), .T(pin_t[32]), .O(pin_in[32]));
    BB bb_p33 (.B(p33), .I(pin_drv[33]), .T(pin_t[33]), .O(pin_in[33]));
    BB bb_p34 (.B(p34), .I(pin_drv[34]), .T(pin_t[34]), .O(pin_in[34]));
    BB bb_p35 (.B(p35), .I(pin_drv[35]), .T(pin_t[35]), .O(pin_in[35]));
    BB bb_p36 (.B(p36), .I(pin_drv[36]), .T(pin_t[36]), .O(pin_in[36]));
    BB bb_p37 (.B(p37), .I(pin_drv[37]), .T(pin_t[37]), .O(pin_in[37]));
    BB bb_p38 (.B(p38), .I(pin_drv[38]), .T(pin_t[38]), .O(pin_in[38]));
    BB bb_p39 (.B(p39), .I(pin_drv[39]), .T(pin_t[39]), .O(pin_in[39]));
    BB bb_p40 (.B(p40), .I(pin_drv[40]), .T(pin_t[40]), .O(pin_in[40]));
    BB bb_p41 (.B(p41), .I(pin_drv[41]), .T(pin_t[41]), .O(pin_in[41]));
    BB bb_p42 (.B(p42), .I(pin_drv[42]), .T(pin_t[42]), .O(pin_in[42]));
    BB bb_p43 (.B(p43), .I(pin_drv[43]), .T(pin_t[43]), .O(pin_in[43]));
    BB bb_p44 (.B(p44), .I(pin_drv[44]), .T(pin_t[44]), .O(pin_in[44]));
    BB bb_p45 (.B(p45), .I(pin_drv[45]), .T(pin_t[45]), .O(pin_in[45]));
    BB bb_p46 (.B(p46), .I(pin_drv[46]), .T(pin_t[46]), .O(pin_in[46]));
    BB bb_p47 (.B(p47), .I(pin_drv[47]), .T(pin_t[47]), .O(pin_in[47]));
    BB bb_p48 (.B(p48), .I(pin_drv[48]), .T(pin_t[48]), .O(pin_in[48]));
    BB bb_p49 (.B(p49), .I(pin_drv[49]), .T(pin_t[49]), .O(pin_in[49]));
    BB bb_p50 (.B(p50), .I(pin_drv[50]), .T(pin_t[50]), .O(pin_in[50]));
    BB bb_p51 (.B(p51), .I(pin_drv[51]), .T(pin_t[51]), .O(pin_in[51]));
    BB bb_p52 (.B(p52), .I(pin_drv[52]), .T(pin_t[52]), .O(pin_in[52]));
    BB bb_p53 (.B(p53), .I(pin_drv[53]), .T(pin_t[53]), .O(pin_in[53]));
    BB bb_p54 (.B(p54), .I(pin_drv[54]), .T(pin_t[54]), .O(pin_in[54]));
    BB bb_p55 (.B(p55), .I(pin_drv[55]), .T(pin_t[55]), .O(pin_in[55]));
    BB bb_p56 (.B(p56), .I(pin_drv[56]), .T(pin_t[56]), .O(pin_in[56]));
    BB bb_p57 (.B(p57), .I(pin_drv[57]), .T(pin_t[57]), .O(pin_in[57]));
    BB bb_p58 (.B(p58), .I(pin_drv[58]), .T(pin_t[58]), .O(pin_in[58]));
    BB bb_p59 (.B(p59), .I(pin_drv[59]), .T(pin_t[59]), .O(pin_in[59]));
    BB bb_p60 (.B(p60), .I(pin_drv[60]), .T(pin_t[60]), .O(pin_in[60]));
    BB bb_p61 (.B(p61), .I(pin_drv[61]), .T(pin_t[61]), .O(pin_in[61]));
    BB bb_p62 (.B(p62), .I(pin_drv[62]), .T(pin_t[62]), .O(pin_in[62]));
    BB bb_p63 (.B(p63), .I(pin_drv[63]), .T(pin_t[63]), .O(pin_in[63]));
    BB bb_p64 (.B(p64), .I(pin_drv[64]), .T(pin_t[64]), .O(pin_in[64]));
    // p65 (T2) = J4 pin 6, ext_led through 74HC245T buffer
    assign ext_led = ext_led_state;  // separate geiger (1/256 on, 13/256 off)
    assign pin_in[65] = 1'b1;  // stub: always reads HIGH
    BB bb_p66 (.B(p66), .I(pin_drv[66]), .T(pin_t[66]), .O(pin_in[66]));

    // =========================================================================
    // Fast pin scanner — only 9 button pins, no divider
    // =========================================================================
    reg [66:0] pin_result = {67{1'b1}};

    // Scan only button pins: 27,28,44,49,50,51,56,57,62,63 (10 pins)
    // scan_idx cycles through these specific pins
    reg [3:0] btn_scan = 0;  // 0-9 index into button pin list

    // Same scan_div timing as original (proven to work), but only 10 button pins.
    // Original: 67 pins × 1792 clocks = 4.8ms. This: 10 pins × 1792 = 0.72ms.
    reg [5:0] scan_div = 0;
    wire scan_tick = ce && (&scan_div);
    always @(posedge clk) if (ce) scan_div <= scan_div + 1;

    always @(posedge clk) begin
        if (scan_tick) begin
            pin_result[scan_idx] <= pin_in[scan_idx];
            case (btn_scan)
                4'd0: scan_idx <= 7'd27;
                4'd1: scan_idx <= 7'd28;
                4'd2: scan_idx <= 7'd44;
                4'd3: scan_idx <= 7'd49;
                4'd4: scan_idx <= 7'd50;
                4'd5: scan_idx <= 7'd51;
                4'd6: scan_idx <= 7'd56;
                4'd7: scan_idx <= 7'd57;
                4'd8: scan_idx <= 7'd62;
                default: scan_idx <= 7'd63;
            endcase
            btn_scan <= (btn_scan == 4'd9) ? 4'd0 : btn_scan + 1;
        end
    end

    // =========================================================================
    // TRNG — 29 ring oscillators, temporal XOR, rotation mix, fold to 8 bits
    // =========================================================================
    wire [28:0] ro_out;
    generate
        for (gi = 0; gi < 29; gi = gi + 1) begin : ro_gen
            (* keep, syn_keep="true" *) wire fb;
            (* keep *) LUT4 #(.INIT(16'h0100)) ro (
                .A(fb), .B(1'b0), .C(1'b0), .D(1'b1), .Z(fb)
            );
            assign ro_out[gi] = fb;
        end
    endgenerate

    reg [28:0] ro_prev = 0;
    always @(posedge clk) ro_prev <= ro_out;
    wire [28:0] jitter = ro_out ^ ro_prev;

    // Rotation mix: coprime offsets 7, 13 for period 29
    wire [28:0] mixed;
    generate
        for (gi = 0; gi < 29; gi = gi + 1) begin : mix_gen
            assign mixed[gi] = jitter[gi] ^ jitter[(gi + 7) % 29] ^ jitter[(gi + 13) % 29];
        end
    endgenerate

    // XOR-fold 29 → 8 bits
    wire [7:0] trng_out = mixed[7:0] ^ mixed[15:8] ^ mixed[23:16] ^ {3'b0, mixed[28:24]};

    // =========================================================================
    // Geiger-counter LED — toggle on random TRNG events
    // =========================================================================
    reg [14:0] geiger_cnt = 0;
    reg ext_led_state = 1'b0;
    always @(posedge clk) begin
        geiger_cnt <= geiger_cnt + 1;
        if (&geiger_cnt) begin
            if (led && trng_out < 8'd8)
                led <= 1'b0;
            else if (!led && trng_out < 8'd100)
                led <= 1'b1;
        end
        // ext_led: solid ON when button held, geiger when idle
        if (btn_id != 5'd0)
            ext_led_state <= 1'b1;
        else if (&geiger_cnt[7:0]) begin
            if (!ext_led_state && trng_out < 8'd1)
                ext_led_state <= 1'b1;
            else if (ext_led_state && trng_out < 8'd254)
                ext_led_state <= 1'b0;
        end
    end

    // =========================================================================
    // Button decoder — detect pin pairs from matrix
    // =========================================================================
    // Active-low: pin_result[N] == 0 means pin N is LOW (pressed)
    wire [4:0] btn_id;  // 0 = none, 1-17 = button
    wire p27L = !pin_result[27], p28L = !pin_result[28], p44L = !pin_result[44];
    wire p49L = !pin_result[49], p50L = !pin_result[50], p51L = !pin_result[51];
    wire p56L = !pin_result[56], p57L = !pin_result[57], p62L = !pin_result[62];
    wire p63L = !pin_result[63];

    assign btn_id =
        // Digits (two-pin matrix)
        (p51L && p62L) ? 5'd1  :  // Zil
        (p51L && p63L) ? 5'd2  :  // Zila
        (p49L && p51L) ? 5'd3  :  // Zilor
        (p44L && p62L) ? 5'd4  :  // Ter
        (p44L && p63L) ? 5'd5  :  // Tera
        (p44L && p49L) ? 5'd6  :  // Teror
        (p28L && p62L) ? 5'd7  :  // Lun
        (p28L && p63L) ? 5'd8  :  // Luna
        (p28L && p49L) ? 5'd9  :  // Lunor
        (p27L && p62L) ? 5'd10 :  // Stel
        (p27L && p63L) ? 5'd11 :  // Stela
        (p27L && p49L) ? 5'd12 :  // Stelor
        // Operators
        (p50L && p62L) ? 5'd13 :  // Ƨ (negate)
        (p28L && p56L) ? 5'd14 :  // +
        (p50L && p63L) ? 5'd15 :  // ÷
        (p51L && p56L) ? 5'd16 :  // ↑ (enter)
        // GND buttons (swapped: * on 62, · on 57)
        (p62L && !p27L && !p28L && !p44L && !p50L && !p51L) ? 5'd17 :  // * (multiply)
        (p57L) ? 5'd18 :  // · (decimal / shift)
        5'd0;  // none

    // =========================================================================
    // Glyph ROM — 18 glyphs × 16×16 × 8bpp = 4608 bytes
    // =========================================================================
    reg [7:0] glyph_rom [0:4607];
    initial $readmemh("glyphs.mem", glyph_rom);

    // =========================================================================
    // 8bpp Framebuffer (8192 bytes, 128×64)
    // =========================================================================
    reg [7:0] fb [0:8191];

    wire [6:0] wr_col = fb_wr_addr[6:0];
    wire [5:0] wr_row = fb_wr_addr[12:7];

    // Live press glyph: 16x16 centered (rows 24-39, cols 56-71)
    wire glyph_active = (btn_id != 5'd0) &&
                        (wr_row >= 6'd24) && (wr_row < 6'd40) &&
                        (wr_col >= 7'd56) && (wr_col < 7'd72);
    wire [3:0] glyph_y = wr_row - 6'd24;
    wire [3:0] glyph_x = wr_col - 7'd56;
    wire [12:0] glyph_addr = {btn_id - 5'd1, glyph_y, glyph_x};
    wire [7:0] glyph_pixel = (btn_id != 5'd0) ? glyph_rom[glyph_addr] : 8'h00;

    wire [7:0] fb_wr_pixel = glyph_active ? glyph_pixel : 8'h00;

    reg [12:0] fb_wr_addr = 0;
    always @(posedge clk) begin
        fb[fb_wr_addr] <= fb_wr_pixel;
        fb_wr_addr <= fb_wr_addr + 1;
    end

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
    // OLED FSM — gather loop reads framebuffer, dithers with TRNG
    // =========================================================================
    localparam [2:0]
        ST_RESET   = 3'd0,
        ST_SEND    = 3'd1,
        ST_WAIT    = 3'd2,
        ST_NEXT    = 3'd3,
        ST_BUSFREE = 3'd4,
        ST_GATHER  = 3'd5;

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
    reg [3:0]  gather_cnt  = 0;

    // Framebuffer read: combinational address, registered output (no rom_addr register)
    reg [7:0] fb_dout = 0;

    always @(posedge clk) if (ce) begin
        fb_dout <= fb[{page, gather_cnt[2:0], col}];
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
                                phase      <= PH_PAGE_DATA;
                                cmd_idx    <= 0;
                                col        <= 0;
                                gather_cnt <= 0;
                                state      <= ST_BUSFREE;
                            end else begin
                                cmd_idx <= cmd_idx + 1;
                                state   <= ST_SEND;
                            end
                        end
                        PH_PAGE_DATA: begin
                            if (cmd_idx < 2) begin
                                cmd_idx <= cmd_idx + 1;
                                if (cmd_idx == 1) begin
                                    gather_cnt <= 0;
                                    state      <= ST_GATHER;
                                end else begin
                                    state <= ST_SEND;
                                end
                            end else if (col == 7'd127) begin
                                phase   <= PH_PAGE_CMD;
                                cmd_idx <= 0;
                                page    <= (page == 3'd7) ? 3'd0 : page + 1;
                                state   <= ST_BUSFREE;
                            end else begin
                                col        <= col + 1;
                                gather_cnt <= 0;
                                state      <= ST_GATHER;
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

            // Gather 8 rows: fb address = {page, gather_cnt[2:0], col}
            // gc=0: fb reads row 0 → fb_dout available at gc=1
            // gc=1..8: dither fb_dout against TRNG, shift into px_byte
            ST_GATHER: begin
                gather_cnt <= gather_cnt + 1;
                if (gather_cnt >= 4'd1) begin
                    px_byte <= {(fb_dout >= trng_out), px_byte[7:1]};
                end
                if (gather_cnt == 4'd8) begin
                    gather_cnt <= 0;
                    state      <= ST_SEND;
                end
            end

        endcase
    end

endmodule

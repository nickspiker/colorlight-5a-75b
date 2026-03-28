// top_pin_scan.v — dozenal calculator input with OLED display
//
// 10-pin button scanner (columns-first: 62,63,49,56,27,28,44,50,51,57).
// Chord shift: hold · + button = shifted function. Latch-on-first, commit-on-release.
// Multiply detected from sampled data only (not combinational decoder).
// 8bpp framebuffer with registered TRNG dither. Geiger-counter LEDs.

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
    // BB tristate I/O — all button pins driven LOW, scan one at a time
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
            // Columns first, then rows — prevents ghost multiply on col62 release
            case (btn_scan)
                4'd0: scan_idx <= 7'd62;
                4'd1: scan_idx <= 7'd63;
                4'd2: scan_idx <= 7'd49;
                4'd3: scan_idx <= 7'd56;
                4'd4: scan_idx <= 7'd27;
                4'd5: scan_idx <= 7'd28;
                4'd6: scan_idx <= 7'd44;
                4'd7: scan_idx <= 7'd50;
                4'd8: scan_idx <= 7'd51;
                default: scan_idx <= 7'd57;
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

    // XOR-fold 29 → 8 bits, registered to clean glitches
    wire [7:0] trng_raw = mixed[7:0] ^ mixed[15:8] ^ mixed[23:16] ^ {3'b0, mixed[28:24]};
    reg [7:0] trng_out = 0;
    always @(posedge clk) trng_out <= trng_raw;

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
        // Multi-press: count LOW button pins (excl p57). Single = 2, p50/p51 coupling = 3.
        // 4+ = multi-press.
        // ext_led: solid ON = single press, OFF = multi-press, geiger = idle
        if (eff_btn != 5'd0) begin
            if ((!pin_result[27]) + (!pin_result[28]) + (!pin_result[44]) +
                (!pin_result[49]) + (!pin_result[50]) + (!pin_result[51]) +
                (!pin_result[56]) + (!pin_result[62]) + (!pin_result[63]) > 4'd3)
                ext_led_state <= 1'b0;  // multi-press: LED dark
            else
                ext_led_state <= 1'b1;  // single press: LED on
        end else if (&geiger_cnt[7:0]) begin
            if (!ext_led_state && trng_out < 8'd1)
                ext_led_state <= 1'b1;
            else if (ext_led_state && trng_out < 8'd255)
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
        // · (GND+57)
        (p57L) ? 5'd18 :
        // Multiply NOT in combinational decoder — detected from sampled data only
        // (p62L && !all_rows fires as ghost during any col62 button scan)
        5'd0;

    // =========================================================================
    // Shift logic — chord: hold · + button = shifted, sticky until release
    // =========================================================================
    // Shift = chord: hold · + press button = shifted. · alone = decimal.
    // If · released while button still held, stay shifted.
    wire dot_held = !pin_result[57];

    reg was_shifted = 0;       // latches when a chord starts, clears on button release
    reg [5:0] held_slot = 0;   // last shifted glyph while · held

    always @(posedge clk) begin
        // Chord start: · held + button pressed
        if (dot_held && eff_btn != 5'd0 && eff_btn != 5'd18) begin
            was_shifted <= 1;
            held_slot <= eff_btn + 6'd17;
        end
        // Button released (without ·): clear shift
        if (!dot_held && eff_btn == 5'd0)
            was_shifted <= 0;
        // · released: clear held slot
        if (!dot_held)
            held_slot <= 0;
    end

    wire shifted = dot_held || was_shifted;

    wire [5:0] glyph_slot =
        (shifted && eff_btn != 5'd0 && eff_btn != 5'd18) ? (eff_btn + 6'd17) :
        (dot_held && held_slot != 6'd0) ? held_slot :
        (eff_btn != 5'd0) ? (eff_btn - 6'd1) :
        6'd0;

    // =========================================================================
    // Glyph ROM — 36 glyphs × 16×16 × 8bpp = 9216 bytes
    // =========================================================================
    reg [7:0] glyph_rom [0:16383];  // 39 glyphs × 256 bytes (oversized for address space)
    initial $readmemh("glyphs.mem", glyph_rom);

    // =========================================================================
    // 8bpp Framebuffer (8192 bytes, 128×64)
    // =========================================================================
    reg [7:0] fb [0:8191];

    wire [6:0] wr_col = fb_wr_addr[6:0];
    wire [5:0] wr_row = fb_wr_addr[12:7];

    // =========================================================================
    // Latch-on-first + commit-on-release
    // =========================================================================
    reg [5:0] display_slot = 0;
    reg display_locked = 0;
    reg prev_dot_held = 0;
    reg was_locked = 0;    // edge detect for commit

    // Sample btn_id only at end of full scan cycle (all 10 pins fresh)
    // Sample at btn_scan==0: all previous pins (62,63,49,56,27,28,44,50,51)
    // have had their non-blocking assignments take effect. No stale data.
    wire scan_complete = scan_tick && (btn_scan == 4'd0);
    reg [4:0] sampled_btn = 0;
    reg [4:0] prev_sampled = 0;
    always @(posedge clk) begin
        if (scan_complete) begin
            prev_sampled <= sampled_btn;
            sampled_btn <= eff_btn;
        end
    end
    // Stable = same btn_id for 2 full scan cycles
    wire btn_stable = (sampled_btn == prev_sampled);

    // Multiply: detected only at scan_complete (all pins fresh, no race)
    reg mul_detected = 0;
    always @(posedge clk) begin
        if (scan_complete)
            // btn_id==0 or 18 (· held): no matrix button, just p62 LOW = multiply
            mul_detected <= ((btn_id == 5'd0 || btn_id == 5'd18) && p62L && !p27L && !p28L && !p44L && !p50L && !p51L);
    end

    // Effective btn_id: merge sampled multiply with live decoder
    wire [4:0] eff_btn = mul_detected ? 5'd17 : btn_id;

    // Also sample glyph_slot at scan_complete (all pins fresh, no race)
    // Use eff_btn for glyph computation at sample time
    reg [5:0] sampled_glyph = 0;
    always @(posedge clk) begin
        if (scan_complete) begin
            sampled_glyph <=
                (shifted && eff_btn != 5'd0 && eff_btn != 5'd18) ? (eff_btn + 6'd17) :
                (dot_held && held_slot != 6'd0) ? held_slot :
                (eff_btn != 5'd0) ? (eff_btn - 6'd1) :
                6'd0;
        end
    end
    // Idle ready: set when sampled_btn==0 for 2 full cycles, clear on lock
    wire idle_confirmed = (sampled_btn == 5'd0) && (prev_sampled == 5'd0);
    reg idle_ready = 1;
    always @(posedge clk) begin
        if (idle_confirmed)
            idle_ready <= 1;
        if (display_locked)
            idle_ready <= 0;
    end

    always @(posedge clk) begin
        prev_dot_held <= dot_held;
        was_locked <= display_locked;

        // Lock when btn stable for 2 scan cycles AND idle was confirmed
        // idle_confirmed = sampled_btn==0 for 2 full cycles — kills scan-race ghosts
        if (!display_locked && idle_ready && btn_stable &&
            sampled_btn != 5'd0) begin
            display_slot <= sampled_glyph;  // captured at scan_complete, all pins fresh
            display_locked <= 1;
        end
        // Upgrade: · held + button appears while locked on decimal → shifted
        // Also: button held + · added → shifted
        if (display_locked && dot_held && eff_btn != 5'd0 && eff_btn != 5'd18 &&
            (display_slot == 6'd17 || !prev_dot_held))
            display_slot <= eff_btn + 6'd17;
        // Full release: clear lock
        if (eff_btn == 5'd0 && !dot_held)
            display_locked <= 0;
    end

    // Show locked slot if locked, otherwise live glyph_slot (for · preview)
    wire [5:0] active_slot = display_locked ? display_slot : glyph_slot;
    wire active_valid = display_locked || (eff_btn != 5'd0) || (dot_held && held_slot != 6'd0);

    // =========================================================================
    // History buffer — commit on release (locked→unlocked edge)
    // =========================================================================
    // Four display lines: T (top), Z, Y, X/entry (bottom)
    // Entry buffer: 16 slots (digits can go off-screen left)
    // Stack lines: 16 slots each (will hold formatted scalars later)
    reg [5:0] entry [0:15];
    reg [4:0] entry_len = 0;
    reg [5:0] line_y [0:15];
    reg [4:0] y_len = 0;
    reg [5:0] line_z [0:15];
    reg [4:0] z_len = 0;
    reg [5:0] line_t [0:15];
    reg [4:0] t_len = 0;

    integer hi;
    initial begin
        for (hi = 0; hi < 16; hi = hi + 1) begin
            entry[hi] = 6'd0;
            line_y[hi] = 6'd0;
            line_z[hi] = 6'd0;
            line_t[hi] = 6'd0;
        end
    end

    // Classify committed glyph slots
    wire is_digit  = (display_slot <= 6'd11) || (display_slot == 6'd17);  // 0-11 = dozenal, 17 = decimal
    wire is_enter  = (display_slot == 6'd15);
    wire is_ce     = (display_slot == 6'd30);  // clear entry (erase last)
    wire is_clear  = (display_slot == 6'd33);  // clear all
    wire is_negate = (display_slot == 6'd12);  // toggle sign
    // Everything else = operator (add, subtract, multiply, divide, etc.)
    wire is_operator = !is_digit && !is_enter && !is_ce && !is_clear && !is_negate;

    // Pending operator (flashes on live display, later triggers computation)
    reg [5:0] pending_op = 0;
    reg pending_valid = 0;

    always @(posedge clk) begin
        conv_start <= 0;  // self-clearing pulse
        if (was_locked && !display_locked) begin
            if (is_ce) begin
                // Erase last digit
                if (entry_len > 0)
                    entry_len <= entry_len - 1;
                pending_valid <= 0;
            end else if (is_clear) begin
                // Clear everything (y_len cleared in formatter block via signal)
                entry_len <= 0;
                z_len <= 0;
                t_len <= 0;
                pending_valid <= 0;
                pending_op <= 0;
            end else if (is_enter) begin
                // Start digit→scalar conversion, then push
                if (entry_len > 0)
                    conv_start <= 1;
                pending_valid <= 0;
            end else if (is_digit) begin
                // Append digit to entry line (max 16)
                if (entry_len < 5'd16) begin
                    entry[entry_len[3:0]] <= display_slot;
                    entry_len <= entry_len + 1;
                end
                pending_valid <= 0;
            end else if (is_negate || is_operator) begin
                // If entry has digits, auto-enter first
                if (entry_len > 0) begin
                    conv_start <= 1;
                end
                // Latch operator for dispatch (handled in calc dispatch block)
                pending_op <= display_slot;
                pending_valid <= 1;
            end
        end

        // Conversion done → clear entry, shift display up
        if (conv_done) begin
            for (hi = 0; hi < 16; hi = hi + 1) line_t[hi] <= line_z[hi];
            t_len <= z_len;
            for (hi = 0; hi < 16; hi = hi + 1) line_z[hi] <= line_y[hi];
            z_len <= y_len;
            entry_len <= 0;
            pending_valid <= 0;
        end
    end

    // =========================================================================
    // Digit → Scalar converter (F5E4: 32-bit frac, 16-bit exp)
    // =========================================================================
    // Walks entry buffer: acc = acc * 12 + digit. Tracks decimal position.
    // Normalizes to N1 format on completion.
    reg conv_start = 0;
    wire conv_done;

    reg [1:0] conv_state = 0;
    localparam C_IDLE = 2'd0, C_ACCUM = 2'd1, C_NORM = 2'd2, C_DONE = 2'd3;

    reg [47:0] conv_acc = 0;       // 48-bit integer accumulator
    reg [3:0]  conv_idx = 0;       // current entry index
    reg [3:0]  conv_dec_pos = 0;   // digits after decimal (0 = integer only)
    reg        conv_saw_dec = 0;   // seen decimal point
    reg        conv_negative = 0;  // negate was in entry

    reg [31:0] result_frac = 0;    // F5E4 output
    reg signed [15:0] result_exp = 0;

    // Scalar stack (stores actual computed values)
    reg [31:0] stack_frac [0:3];   // X=0, Y=1, Z=2, T=3
    reg signed [15:0] stack_exp [0:3];
    reg [2:0] stack_depth = 0;

    integer si;
    initial begin
        for (si = 0; si < 4; si = si + 1) begin
            stack_frac[si] = 0;
            stack_exp[si] = 0;
        end
    end

    assign conv_done = (conv_state == C_DONE);

    // Combinational CLZ on 48-bit conv_acc (handles 0-47 leading zeros)
    wire [5:0] clz_val;
    wire [47:0] clz_shifted;
    // Stage 0: check top 16 bits (shift 32 if all zero in top 32)
    wire [47:0] clz_s0 = |conv_acc[47:16] ? conv_acc : {conv_acc[15:0], 32'd0};
    wire [5:0]  clz_c0 = |conv_acc[47:16] ? 6'd0 : 6'd32;
    // Stage 1: check top 8 of remaining
    wire [47:0] clz_s1 = |clz_s0[47:40] ? clz_s0 : {clz_s0[39:0], 8'd0};
    wire [5:0]  clz_c1 = |clz_s0[47:40] ? clz_c0 : clz_c0 + 6'd8;
    // Stage 2: check top 4
    wire [47:0] clz_s2 = |clz_s1[47:44] ? clz_s1 : {clz_s1[43:0], 4'd0};
    wire [5:0]  clz_c2 = |clz_s1[47:44] ? clz_c1 : clz_c1 + 6'd4;
    // Stage 3: check top 2
    wire [47:0] clz_s3 = |clz_s2[47:46] ? clz_s2 : {clz_s2[45:0], 2'd0};
    wire [5:0]  clz_c3 = |clz_s2[47:46] ? clz_c2 : clz_c2 + 6'd2;
    // Stage 4: check top 1
    wire [47:0] clz_s4 = clz_s3[47]     ? clz_s3 : {clz_s3[46:0], 1'd0};
    wire [5:0]  clz_c4 = clz_s3[47]     ? clz_c3 : clz_c3 + 6'd1;
    assign clz_val = clz_c4;
    assign clz_shifted = clz_s4;

    always @(posedge clk) begin
        case (conv_state)
            C_IDLE: begin
                if (conv_start) begin
                    conv_acc <= 0;
                    conv_idx <= 0;
                    conv_dec_pos <= 0;
                    conv_saw_dec <= 0;
                    conv_negative <= 0;
                    conv_state <= C_ACCUM;
                end
            end

            C_ACCUM: begin
                if ({1'b0, conv_idx} < entry_len) begin
                    if (entry[conv_idx] == 6'd17) begin
                        // Decimal point
                        conv_saw_dec <= 1;
                    end else if (entry[conv_idx] == 6'd12) begin
                        // Negate symbol in entry
                        conv_negative <= ~conv_negative;
                    end else if (entry[conv_idx] <= 6'd11) begin
                        // Dozenal digit: acc = acc * 12 + digit
                        conv_acc <= (conv_acc << 3) + (conv_acc << 2) + {42'd0, entry[conv_idx]};
                        if (conv_saw_dec)
                            conv_dec_pos <= conv_dec_pos + 1;
                    end
                    conv_idx <= conv_idx + 1;
                end else begin
                    conv_state <= C_NORM;
                end
            end

            C_NORM: begin
                // Normalize 48-bit integer to Spirix N1 format (32-bit frac, 16-bit exp)
                // CLZ + shift done combinationally via clz_val/clz_shifted wires below
                if (conv_acc == 0) begin
                    result_frac <= 0;
                    result_exp <= 0;
                end else begin
                    // N1 positive: 0_1xxxxx. Shift so leading 1 is at bit 30 (not 31).
                    // clz_shifted has leading 1 at bit 47. Take [47:17] = 31 data bits,
                    // prepend 0 sign bit.
                end

                // Result (stack push happens in unified stack block below)
                // Spirix convention: value = frac * 2^(exp - 31).
                // Converter exp = 48 - clz_val.
                result_frac <= (conv_acc == 0) ? 32'd0 :
                               (conv_negative ? -{1'b0, clz_shifted[47:17]}
                                              :  {1'b0, clz_shifted[47:17]});
                result_exp  <= (conv_acc == 0) ? 16'sd0 :
                               $signed({10'd0, 6'd48 - clz_val});

                conv_state <= C_DONE;
            end

            C_DONE: begin
                // Single-clock pulse, caught by commit logic above
                conv_state <= C_IDLE;
            end
        endcase
    end

    // =========================================================================
    // Calculator core — ALU instances + operator FSM
    // =========================================================================
    reg [5:0]  calc_op_slot = 0;
    reg        calc_op_start = 0;
    wire       calc_busy;
    wire       calc_done;
    wire [31:0] calc_res_frac;
    wire signed [15:0] calc_res_exp;
    wire       calc_is_binary;

    // Formatter signals
    reg        fmt_start_pulse = 0;
    wire       fmt_busy_w;
    wire       fmt_done_w;
    wire [5:0] fmt_glyph_w;
    wire [3:0] fmt_pos_w;
    wire       fmt_wr_w;
    wire [4:0] fmt_len_w;

    spirix_calc_core u_calc (
        .clk(clk),
        .stk_x_frac(stack_frac[0]), .stk_x_exp(stack_exp[0]),
        .stk_y_frac(stack_frac[1]), .stk_y_exp(stack_exp[1]),
        .stk_depth(stack_depth),
        .op_slot(calc_op_slot), .op_start(calc_op_start),
        .op_busy(calc_busy), .op_done(calc_done),
        .res_frac(calc_res_frac), .res_exp(calc_res_exp),
        .res_is_binary(calc_is_binary),
        // Formatter
        .fmt_frac(stack_frac[0]), .fmt_exp(stack_exp[0]),
        .fmt_start(fmt_start_pulse), .fmt_busy(fmt_busy_w), .fmt_done(fmt_done_w),
        .fmt_glyph(fmt_glyph_w), .fmt_pos(fmt_pos_w), .fmt_wr(fmt_wr_w),
        .fmt_len(fmt_len_w)
    );

    // Calc dispatch: combinational — fires when pending_valid + ready
    wire calc_ready = pending_valid && !calc_busy && (conv_state == C_IDLE);
    always @(posedge clk) begin
        calc_op_start <= calc_ready;
        if (calc_ready)
            calc_op_slot <= pending_op;
    end

    // Unified stack management — single driver for all stack regs
    always @(posedge clk) begin
        if (conv_done) begin
            // Push: shift stack up, put converted value in X
            stack_frac[3] <= stack_frac[2]; stack_exp[3] <= stack_exp[2];
            stack_frac[2] <= stack_frac[1]; stack_exp[2] <= stack_exp[1];
            stack_frac[1] <= stack_frac[0]; stack_exp[1] <= stack_exp[0];
            stack_frac[0] <= result_frac;   stack_exp[0] <= result_exp;
            if (stack_depth < 3'd4)
                stack_depth <= stack_depth + 1;
        end
        if (calc_done) begin
            // Operator result → X
            stack_frac[0] <= calc_res_frac;
            stack_exp[0] <= calc_res_exp;
            if (calc_is_binary && stack_depth > 1) begin
                stack_frac[1] <= stack_frac[2];
                stack_exp[1] <= stack_exp[2];
                stack_frac[2] <= stack_frac[3];
                stack_exp[2] <= stack_exp[3];
                stack_depth <= stack_depth - 1;
            end
        end
    end

    // Formatter trigger: format stack[0] after conv_done or calc_done
    // Write result to Y line (where it was just pushed)
    always @(posedge clk) begin
        fmt_start_pulse <= 0;
        // After conv_done (Enter pushed entry to stack), format the pushed value
        if (conv_done && !fmt_busy_w)
            fmt_start_pulse <= 1;
        // After calc_done (operator result), format the result
        if (calc_done && !fmt_busy_w)
            fmt_start_pulse <= 1;
    end

    // line_y and y_len owned by this block only (no multi-driver)
    always @(posedge clk) begin
        if (fmt_wr_w)
            line_y[fmt_pos_w] <= fmt_glyph_w;
        if (fmt_done_w)
            y_len <= fmt_len_w;
        // Clear signal: is_clear in the commit block can't write y_len directly,
        // so we check the condition here too
        if (was_locked && !display_locked && is_clear)
            y_len <= 0;
    end

    // =========================================================================
    // Display: 4 lines × 8 visible glyphs, right-aligned, 16px each
    // =========================================================================
    // T: rows 0-15, Z: rows 16-31, Y: rows 32-47, X/entry: rows 48-63
    wire [2:0] glyph_col = wr_col[6:4];  // 0-7 display column
    wire [3:0] glyph_x = wr_col[3:0];    // 0-15 within slot
    wire [3:0] glyph_y = wr_row[3:0];    // 0-15 within line
    wire [1:0] line_sel = wr_row[5:4];   // 0=T, 1=Z, 2=Y, 3=X

    // Right-aligned index: display col + len - 8. Valid when col + len >= 8.
    // Shows rightmost 8 of up to 16 stored glyphs.
    wire [4:0] t_idx = {2'b0, glyph_col} + t_len - 5'd8;
    wire [4:0] z_idx = {2'b0, glyph_col} + z_len - 5'd8;
    wire [4:0] y_idx = {2'b0, glyph_col} + y_len - 5'd8;
    wire [4:0] e_idx = {2'b0, glyph_col} + entry_len - 5'd8;

    wire t_valid = ({2'b0, glyph_col} + t_len >= 5'd8) && (t_len > 0);
    wire z_valid = ({2'b0, glyph_col} + z_len >= 5'd8) && (z_len > 0);
    wire y_valid = ({2'b0, glyph_col} + y_len >= 5'd8) && (y_len > 0);
    wire e_valid = ({2'b0, glyph_col} + entry_len >= 5'd8) && (entry_len > 0);

    wire [5:0] t_slot = t_valid ? line_t[t_idx[3:0]] : 6'd0;
    wire [5:0] z_slot = z_valid ? line_z[z_idx[3:0]] : 6'd0;
    wire [5:0] y_slot = y_valid ? line_y[y_idx[3:0]] : 6'd0;
    wire [5:0] e_slot = e_valid ? entry[e_idx[3:0]] : 6'd0;

    wire [5:0] render_slot = (line_sel == 2'd0) ? t_slot :
                             (line_sel == 2'd1) ? z_slot :
                             (line_sel == 2'd2) ? y_slot : e_slot;
    wire render_valid = (line_sel == 2'd0) ? t_valid :
                        (line_sel == 2'd1) ? z_valid :
                        (line_sel == 2'd2) ? y_valid : e_valid;
    wire [3:0] render_y = glyph_y;
    wire [3:0] render_x = glyph_x;

    wire [13:0] glyph_addr = {render_slot, render_y, render_x};
    wire [7:0] glyph_pixel = render_valid ? glyph_rom[glyph_addr] : 8'h00;

    wire [7:0] fb_wr_pixel = {8{render_valid}} & glyph_pixel;

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
                    px_byte <= {(fb_dout > trng_out), px_byte[7:1]};
                end
                if (gather_cnt == 4'd8) begin
                    gather_cnt <= 0;
                    state      <= ST_SEND;
                end
            end

        endcase
    end

endmodule

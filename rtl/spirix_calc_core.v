// spirix_calc_core.v — RPN calculator core with Spirix ALU + formatter
//
// Fixed F5E4: 32-bit fraction (MSB-aligned), 16-bit exponent (LSB-aligned).
// ALU modules with constant width pins (Yosys constant-folds unused paths).
// Operator FSM for basic ops + formatter FSM for scalar→dozenal digits.

module spirix_calc_core (
    input  wire        clk,

    // Stack interface
    input  wire [31:0] stk_x_frac, stk_y_frac,
    input  wire signed [15:0] stk_x_exp, stk_y_exp,
    input  wire [2:0]  stk_depth,

    // Operator command
    input  wire [5:0]  op_slot,
    input  wire        op_start,
    output wire        op_busy,
    output reg         op_done = 0,
    output reg  [31:0] res_frac = 0,
    output reg  signed [15:0] res_exp = 0,
    output reg         res_is_binary = 0,

    // Formatter command
    input  wire [31:0] fmt_frac,      // scalar to format
    input  wire signed [15:0] fmt_exp,
    input  wire        fmt_start,     // pulse to begin formatting
    output wire        fmt_busy,
    output reg         fmt_done = 0,

    // Formatter output: writes glyph slots to display
    output reg  [5:0]  fmt_glyph = 0,  // glyph slot to write
    output reg  [3:0]  fmt_pos = 0,    // position in line (0-15)
    output reg         fmt_wr = 0,     // write pulse
    output reg  [4:0]  fmt_len = 0     // final digit count
);

    // =========================================================================
    // Constants
    // =========================================================================
    localparam [1:0] FRAC_W = 2'b10;  // 32-bit
    localparam [1:0] EXP_W  = 2'b01;  // 16-bit

    // Spirix constants: value = (frac / 2^30) * 2^exp
    // Spirix convention: value = frac * 2^(exp - 31)
    // 12: 0x60000000 * 2^(4-31) = 1.5 * 2^(-27) * 2^31 = 12
    localparam [31:0] CONST_12_FRAC = 32'h60000000;
    localparam signed [15:0] CONST_12_EXP = 16'sd4;

    // 0.5: 0x40000000 * 2^(0-31) = 1.0 * 2^(-31) * 2^31 = ... wait
    // 0x40000000 * 2^(0-31) = 2^30 * 2^(-31) = 0.5. ✓
    localparam [31:0] CONST_HALF_FRAC = 32'h40000000;
    localparam signed [15:0] CONST_HALF_EXP = 16'sd0;

    // =========================================================================
    // A/B input registers — muxed between stack (operator) and work (formatter)
    // =========================================================================
    reg [31:0] work_a_frac = 0;
    reg signed [15:0] work_a_exp = 0;
    reg [31:0] work_b_frac = 0;
    reg signed [15:0] work_b_exp = 0;
    reg use_work = 0;  // 0 = stack inputs, 1 = work register inputs

    // A/B mux: operator uses stack (Y=A, X=B), formatter uses work regs
    wire [63:0] a_frac_64 = use_work ? {work_a_frac, 32'd0} : {stk_y_frac, 32'd0};
    wire [63:0] a_exp_64  = use_work ? {{48{work_a_exp[15]}}, work_a_exp}
                                     : {{48{stk_y_exp[15]}}, stk_y_exp};
    wire [63:0] b_frac_64 = use_work ? {work_b_frac, 32'd0} : {stk_x_frac, 32'd0};
    wire [63:0] b_exp_64  = use_work ? {{48{work_b_exp[15]}}, work_b_exp}
                                     : {{48{stk_x_exp[15]}}, stk_x_exp};

    // Unary A input (for NEG/ABS): use X for operators, work_a for formatter
    wire [63:0] unary_frac_64 = use_work ? {work_a_frac, 32'd0} : {stk_x_frac, 32'd0};
    wire [63:0] unary_exp_64  = use_work ? {{48{work_a_exp[15]}}, work_a_exp}
                                         : {{48{stk_x_exp[15]}}, stk_x_exp};

    // =========================================================================
    // ALU instances
    // =========================================================================
    wire [63:0] add_res_frac, add_res_exp;
    reg  [2:0]  add_op = 0;
    spirix_alu_addbit u_addbit (
        .clk(clk), .ce(1'b1), .op(add_op),
        .frac_width(FRAC_W), .exp_width(EXP_W),
        .a_frac(a_frac_64), .a_exp(a_exp_64),
        .b_frac(b_frac_64), .b_exp(b_exp_64),
        .result_frac(add_res_frac), .result_exp(add_res_exp)
    );

    wire [63:0] mul_res_frac, mul_res_exp;
    spirix_alu_multiply u_mul (
        .frac_width(FRAC_W), .exp_width(EXP_W),
        .a_frac(a_frac_64), .a_exp(a_exp_64),
        .b_frac(b_frac_64), .b_exp(b_exp_64),
        .result_frac(mul_res_frac), .result_exp(mul_res_exp)
    );

    wire [63:0] div_res_frac, div_res_exp;
    reg  [1:0]  div_op = 0;
    reg         div_start = 0;
    wire        div_busy, div_done;
    spirix_alu_divmodsqrt u_divmod (
        .clk(clk), .op(div_op),
        .frac_width(FRAC_W), .exp_width(EXP_W),
        .a_frac(a_frac_64), .a_exp(a_exp_64),
        .b_frac(b_frac_64), .b_exp(b_exp_64),
        .start(div_start),
        .result_frac(div_res_frac), .result_exp(div_res_exp),
        .busy(div_busy), .done(div_done)
    );

    wire [63:0] floor_res_frac, floor_res_exp;
    spirix_alu_round u_round (
        .op(2'b00), .frac_width(FRAC_W), .exp_width(EXP_W),
        .a_frac(a_frac_64), .a_exp(a_exp_64),
        .result_frac(floor_res_frac), .result_exp(floor_res_exp)
    );

    wire [63:0] basic_res_frac, basic_res_exp;
    reg  [2:0]  basic_op = 0;
    spirix_alu_basic u_basic (
        .op(basic_op), .frac_width(FRAC_W), .exp_width(EXP_W),
        .a_frac(unary_frac_64), .a_exp(unary_exp_64),
        .b_frac(64'd0), .b_exp(64'd0),
        .result_frac(basic_res_frac), .result_exp(basic_res_exp)
    );

    // =========================================================================
    // Operator FSM
    // =========================================================================
    localparam [4:0]
        S_IDLE     = 5'd0,
        S_EXEC     = 5'd1,
        S_DIV_WAIT = 5'd2,
        // Formatter states
        S_FMT_ABS     = 5'd3,   // ABS(value) → magnitude
        S_FMT_DIVSET  = 5'd4,   // set up DIV inputs (work_a = magnitude, work_b = 12)
        S_FMT_DIV     = 5'd5,   // start DIV (inputs settled from previous clock)
        S_FMT_DWAIT   = 5'd6,   // wait for div done
        S_FMT_FLOOR   = 5'd7,   // FLOOR(quotient), set up SUB inputs
        S_FMT_SUBWAIT = 5'd8,   // wait for addbit registered output
        S_FMT_FCAP    = 5'd9,   // capture SUB result, set up MUL inputs
        S_FMT_MULWAIT = 5'd10,  // wait for MUL inputs to settle
        S_FMT_ADDHALF = 5'd11, // set up ADD(mul_result, 0.5) for rounding
        S_FMT_HALFWT  = 5'd12, // wait for addbit registered output
        S_FMT_DIGIT   = 5'd13, // extract digit from rounded result
        S_FMT_DCAP    = 5'd14, // store digit, check loop
        S_FMT_EMIT    = 5'd15, // write digits to output (reversed)
        S_FMT_DONE    = 5'd16; // signal completion

    reg [4:0] state = S_IDLE;
    reg [2:0] alu_sel = 0;

    assign op_busy  = (state != S_IDLE);
    assign fmt_busy = (state != S_IDLE);

    // Formatter work registers
    reg [31:0] fmt_magnitude_frac = 0;
    reg signed [15:0] fmt_magnitude_exp = 0;
    reg [31:0] fmt_scaled_frac = 0;       // div result (before floor)
    reg signed [15:0] fmt_scaled_exp = 0;
    reg [31:0] fmt_floor_frac = 0;        // floored quotient
    reg signed [15:0] fmt_floor_exp = 0;
    reg        fmt_is_negative = 0;

    // Digit buffer: extract LSB-first, emit MSB-first
    reg [5:0] digit_buf [0:11];  // up to 12 digits
    reg [3:0] digit_count = 0;
    reg [3:0] emit_idx = 0;

    // Zero check: is the value zero? (exp == AMBIG or frac == 0)
    wire fmt_is_zero = (fmt_magnitude_frac == 32'd0) ||
                       (fmt_magnitude_exp == -16'sd32768);

    integer di;
    initial for (di = 0; di < 12; di = di + 1) digit_buf[di] = 6'd0;

    // Combinational digit extraction: to_u8 on MUL result (Spirix scalar → 0-11)
    // Convention: value = frac * 2^(exp - 31). Integer = frac >> (31 - exp).
    // For digits 0-11, exp is 0-4 (values up to 11 = 0xB need 4 bits).
    // Read from FLOOR output: FLOOR(MUL_result + 0.5) = rounded integer digit
    wire [31:0] dex_frac = floor_res_frac[63:32];
    wire signed [15:0] dex_exp = floor_res_exp[15:0];

    // Integer = frac >> (31 - exp). Shift the full 32-bit frac right.
    // For digits 0-11, exp ranges 1-4. Shift amounts: 30, 29, 28, 27.
    wire [31:0] dex_shifted =
        (dex_exp <= 16'sd0)  ? 32'd0 :
        (dex_exp == 16'sd1)  ? (dex_frac >> 30) :  // >> 30: value 0-1
        (dex_exp == 16'sd2)  ? (dex_frac >> 29) :  // >> 29: value 0-3
        (dex_exp == 16'sd3)  ? (dex_frac >> 28) :  // >> 28: value 0-7
        (dex_exp == 16'sd4)  ? (dex_frac >> 27) :  // >> 27: value 0-15
        32'd0;

    // Round: check the bit just below the shift point
    // For exp=0: value < 1, but might round up (e.g. 0.999 → 1)
    wire dex_round =
        (dex_exp == 16'sd0)  ? dex_frac[30] :  // bit 30 = 0.5, round if >= 0.5
        (dex_exp == 16'sd1)  ? dex_frac[29] :
        (dex_exp == 16'sd2)  ? dex_frac[28] :
        (dex_exp == 16'sd3)  ? dex_frac[27] :
        (dex_exp == 16'sd4)  ? dex_frac[26] :
        1'b0;

    // No extra rounding — the +0.5 ADD step already handles it
    wire [5:0] dex_val = dex_shifted[5:0];

    wire [5:0] digit_extract =
        (dex_frac == 32'd0 || dex_frac[31]) ? 6'd0 :  // zero or negative
        (dex_val > 6'd11) ? 6'd11 :                    // clamp
        dex_val;

    always @(posedge clk) begin
        op_done <= 0;
        fmt_done <= 0;
        div_start <= 0;
        fmt_wr <= 0;

        case (state)
            S_IDLE: begin
                use_work <= 0;
                if (op_start && !fmt_start) begin
                    // --- Operator dispatch ---
                    case (op_slot)
                        6'd13: begin add_op <= 3'd0; alu_sel <= 3'd0; res_is_binary <= 1; state <= S_EXEC; end
                        6'd31: begin add_op <= 3'd1; alu_sel <= 3'd0; res_is_binary <= 1; state <= S_EXEC; end
                        6'd16: begin alu_sel <= 3'd1; res_is_binary <= 1; state <= S_EXEC; end
                        6'd14: begin div_op <= 2'd0; div_start <= 1; alu_sel <= 3'd2; res_is_binary <= 1; state <= S_DIV_WAIT; end
                        6'd32: begin div_op <= 2'd2; div_start <= 1; alu_sel <= 3'd2; res_is_binary <= 1; state <= S_DIV_WAIT; end
                        6'd12: begin basic_op <= 3'd0; alu_sel <= 3'd4; res_is_binary <= 0; state <= S_EXEC; end
                        default: state <= S_IDLE;
                    endcase
                end else if (fmt_start) begin
                    // --- Formatter start ---
                    use_work <= 1;
                    work_a_frac <= fmt_frac;
                    work_a_exp <= fmt_exp;
                    basic_op <= 3'd1;  // ABS
                    fmt_is_negative <= fmt_frac[31];
                    digit_count <= 0;
                    fmt_len <= 0;
                    state <= S_FMT_ABS;
                end
            end

            // --- Operator execution ---
            S_EXEC: begin
                case (alu_sel)
                    3'd0: begin res_frac <= add_res_frac[63:32]; res_exp <= add_res_exp[15:0]; end
                    3'd1: begin res_frac <= mul_res_frac[63:32]; res_exp <= mul_res_exp[15:0]; end
                    3'd4: begin res_frac <= basic_res_frac[63:32]; res_exp <= basic_res_exp[15:0]; end
                endcase
                op_done <= 1;
                state <= S_IDLE;
            end

            S_DIV_WAIT: begin
                if (div_done) begin
                    res_frac <= div_res_frac[63:32];
                    res_exp <= div_res_exp[15:0];
                    op_done <= 1;
                    state <= S_IDLE;
                end
            end

            // --- Formatter FSM ---
            S_FMT_ABS: begin
                // ABS result available — capture magnitude
                fmt_magnitude_frac <= basic_res_frac[63:32];
                fmt_magnitude_exp <= basic_res_exp[15:0];
                state <= S_FMT_DIVSET;
            end

            S_FMT_DIVSET: begin
                // Check zero
                if (fmt_is_zero) begin
                    digit_buf[0] <= 6'd0;
                    digit_count <= 1;
                    state <= S_FMT_EMIT;
                end else begin
                    // Set up DIV inputs (settle for 1 clock before start)
                    work_a_frac <= fmt_magnitude_frac;
                    work_a_exp <= fmt_magnitude_exp;
                    work_b_frac <= CONST_12_FRAC;
                    work_b_exp <= CONST_12_EXP;
                    div_op <= 2'd0;
                    state <= S_FMT_DIV;
                end
            end

            S_FMT_DIV: begin
                // Inputs settled — start divider
                div_start <= 1;
                state <= S_FMT_DWAIT;
            end

            S_FMT_DWAIT: begin
                if (div_done) begin
                    // Capture scaled = magnitude / 12
                    fmt_scaled_frac <= div_res_frac[63:32];
                    fmt_scaled_exp <= div_res_exp[15:0];
                    // Set up FLOOR: input A = scaled
                    work_a_frac <= div_res_frac[63:32];
                    work_a_exp <= div_res_exp[15:0];
                    // synthesis translate_off
                    $display("  DIV result: frac=0x%08x exp=%0d (value=%f)",
                        div_res_frac[63:32], $signed(div_res_exp[15:0]),
                        $itor(div_res_frac[63:32]) / (2.0**30) * (2.0**$itor($signed(div_res_exp[15:0]))));
                    // synthesis translate_on
                    state <= S_FMT_FLOOR;
                end
            end

            S_FMT_FLOOR: begin
                // FLOOR result available (combinational from round module)
                fmt_floor_frac <= floor_res_frac[63:32];
                fmt_floor_exp <= floor_res_exp[15:0];
                // synthesis translate_off
                $display("  FLOOR: frac=0x%08x exp=%0d", floor_res_frac[63:32], $signed(floor_res_exp[15:0]));
                // synthesis translate_on
                // Set up SUB: (scaled - floor) → remainder
                work_a_frac <= fmt_scaled_frac;
                work_a_exp <= fmt_scaled_exp;
                work_b_frac <= floor_res_frac[63:32];
                work_b_exp <= floor_res_exp[15:0];
                add_op <= 3'd1;  // SUB
                state <= S_FMT_SUBWAIT;
            end

            S_FMT_SUBWAIT: begin
                // Wait 1 clock for addbit registered output to settle
                state <= S_FMT_FCAP;
            end

            S_FMT_FCAP: begin
                // SUB result now valid — set up MUL: remainder * 12
                // synthesis translate_off
                $display("  SUB result (remainder): frac=0x%08x exp=%0d",
                    add_res_frac[63:32], $signed(add_res_exp[15:0]));
                // synthesis translate_on
                work_a_frac <= add_res_frac[63:32];
                work_a_exp <= add_res_exp[15:0];
                work_b_frac <= CONST_12_FRAC;
                work_b_exp <= CONST_12_EXP;
                state <= S_FMT_MULWAIT;
            end

            S_FMT_MULWAIT: begin
                // MUL result available. Set up ADD(mul_result, 0.5) for rounding.
                work_a_frac <= mul_res_frac[63:32];
                work_a_exp <= mul_res_exp[15:0];
                work_b_frac <= CONST_HALF_FRAC;
                work_b_exp <= CONST_HALF_EXP;
                add_op <= 3'd0;  // ADD
                state <= S_FMT_ADDHALF;
            end

            S_FMT_ADDHALF: begin
                // Wait for addbit to latch
                state <= S_FMT_HALFWT;
            end

            S_FMT_HALFWT: begin
                // ADD result valid. Now FLOOR it to get the integer digit.
                // Set work_a to the ADD result for FLOOR.
                work_a_frac <= add_res_frac[63:32];
                work_a_exp <= add_res_exp[15:0];
                state <= S_FMT_DIGIT;
            end

            S_FMT_DIGIT: begin
                // FLOOR result available (combinational, 1 settle clock).
                // This is the digit value as a Spirix integer.
                // Extract using shift: integer = frac >> (31 - exp)
                // MUL result (combinational): remainder * 12 = digit (0-11)
                // synthesis translate_off
                $display("  DIGIT: add_res frac=0x%08x exp=%0d → digit=%0d (shifted=%0d round=%0d)",
                    add_res_frac[63:32], $signed(add_res_exp[15:0]),
                    digit_extract, dex_shifted, dex_round);
                // synthesis translate_on
                digit_buf[digit_count] <= digit_extract;
                digit_count <= digit_count + 1;
                state <= S_FMT_DCAP;
            end

            S_FMT_DCAP: begin
                // Check if quotient (fmt_floor) is zero → done
                // Also limit to 9 digits max
                if (fmt_floor_frac == 32'd0 || fmt_floor_exp == -16'sd32768 ||
                    digit_count >= 5'd9) begin
                    state <= S_FMT_EMIT;
                end else begin
                    // Continue: magnitude = floor (integer quotient)
                    fmt_magnitude_frac <= fmt_floor_frac;
                    fmt_magnitude_exp <= fmt_floor_exp;
                    state <= S_FMT_DIVSET;
                end
            end

            S_FMT_EMIT: begin
                // Emit digits reversed (MSB first). Sign only for non-zero.
                if (emit_idx == 0 && digit_count > 0 && !fmt_is_zero) begin
                    // Sign glyph (skip for zero)
                    fmt_glyph <= fmt_is_negative ? 6'd37 : 6'd38;
                    fmt_pos <= 0;
                    fmt_wr <= 1;
                    emit_idx <= 1;
                    fmt_len <= digit_count + 1;
                end else if (emit_idx == 0 && fmt_is_zero) begin
                    // Zero: skip sign, start digits directly
                    emit_idx <= 1;
                    fmt_len <= digit_count;
                end else if (fmt_is_zero && emit_idx == 1) begin
                    // Zero: emit single "0" at position 0
                    fmt_glyph <= 6'd0;
                    fmt_pos <= 0;
                    fmt_wr <= 1;
                    emit_idx <= emit_idx + 1;
                end else if (!fmt_is_zero && emit_idx <= digit_count) begin
                    // Emit digit (reversed: digit_count-1 down to 0)
                    fmt_glyph <= digit_buf[digit_count - emit_idx[3:0]];
                    fmt_pos <= emit_idx[3:0];
                    fmt_wr <= 1;
                    emit_idx <= emit_idx + 1;
                end else begin
                    emit_idx <= 0;
                    state <= S_FMT_DONE;
                end
            end

            S_FMT_DONE: begin
                fmt_done <= 1;
                use_work <= 0;
                state <= S_IDLE;
            end
        endcase
    end

endmodule

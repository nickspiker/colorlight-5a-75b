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
    // 12 = 1.5 * 2^3:  frac = 0x60000000, exp = 3
    localparam [31:0] CONST_12_FRAC = 32'h60000000;
    localparam signed [15:0] CONST_12_EXP = 16'sd3;

    // 0.5 = 1.0 * 2^(-1): frac = 0x40000000, exp = -1
    localparam [31:0] CONST_HALF_FRAC = 32'h40000000;
    localparam signed [15:0] CONST_HALF_EXP = -16'sd1;

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
    localparam [3:0]
        S_IDLE     = 4'd0,
        S_EXEC     = 4'd1,
        S_DIV_WAIT = 4'd2,
        // Formatter states
        S_FMT_ABS     = 4'd3,   // ABS(value) → magnitude
        S_FMT_DIVSET  = 4'd4,   // set up DIV inputs (work_a = magnitude, work_b = 12)
        S_FMT_DIV     = 4'd5,   // start DIV (inputs settled from previous clock)
        S_FMT_DWAIT   = 4'd6,   // wait for div done
        S_FMT_FLOOR   = 4'd7,   // FLOOR(quotient), set up SUB inputs
        S_FMT_SUBWAIT = 4'd8,   // wait for addbit registered output
        S_FMT_FCAP    = 4'd9,   // capture SUB result, set up MUL inputs
        S_FMT_MULWAIT = 4'd10,  // wait for MUL inputs to settle
        S_FMT_DIGIT   = 4'd11,  // extract digit from MUL result
        S_FMT_DCAP    = 4'd12,  // store digit, check loop
        S_FMT_EMIT    = 4'd13,  // write digits to output (reversed)
        S_FMT_DONE    = 4'd14;

    reg [3:0] state = S_IDLE;
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
    // Includes rounding: check next fractional bit below extracted digits
    wire [31:0] dex_frac = mul_res_frac[63:32];
    wire signed [15:0] dex_exp = mul_res_exp[15:0];

    wire [5:0] dex_raw =
        (dex_exp == 16'sd0) ? {5'd0, dex_frac[30]} :
        (dex_exp == 16'sd1) ? {4'd0, dex_frac[30:29]} :
        (dex_exp == 16'sd2) ? {3'd0, dex_frac[30:28]} :
        (dex_exp == 16'sd3) ? {2'd0, dex_frac[30:27]} :
        6'd0;

    wire dex_round =
        (dex_exp == 16'sd0) ? dex_frac[29] :
        (dex_exp == 16'sd1) ? dex_frac[28] :
        (dex_exp == 16'sd2) ? dex_frac[27] :
        (dex_exp == 16'sd3) ? dex_frac[26] :
        1'b0;

    wire [5:0] dex_rounded = dex_raw + {5'd0, dex_round};

    wire [5:0] digit_extract =
        (dex_frac == 32'd0 || dex_exp < 16'sd0) ? 6'd0 :
        (dex_rounded > 6'd11) ? 6'd11 :
        dex_rounded;

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
                    state <= S_FMT_FLOOR;
                end
            end

            S_FMT_FLOOR: begin
                // FLOOR result available (combinational from round module)
                fmt_floor_frac <= floor_res_frac[63:32];
                fmt_floor_exp <= floor_res_exp[15:0];
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
                work_a_frac <= add_res_frac[63:32];
                work_a_exp <= add_res_exp[15:0];
                work_b_frac <= CONST_12_FRAC;
                work_b_exp <= CONST_12_EXP;
                state <= S_FMT_MULWAIT;
            end

            S_FMT_MULWAIT: begin
                // Wait for MUL inputs to settle through combinational path
                state <= S_FMT_DIGIT;
            end

            S_FMT_DIGIT: begin
                // MUL result (combinational): remainder * 12 = digit (0-11)
                // digit_extract is a combinational wire using to_u8 logic
                digit_buf[digit_count] <= digit_extract;
                digit_count <= digit_count + 1;
                state <= S_FMT_DCAP;
            end

            S_FMT_DCAP: begin
                // Check if quotient (fmt_floor) is zero → done
                // Also limit to 9 digits max
                if (fmt_floor_frac == 32'd0 || fmt_floor_exp == -16'sd32768 ||
                    digit_count >= 4'd9) begin
                    state <= S_FMT_EMIT;
                end else begin
                    // Continue: magnitude = floor (integer quotient)
                    fmt_magnitude_frac <= fmt_floor_frac;
                    fmt_magnitude_exp <= fmt_floor_exp;
                    state <= S_FMT_DIVSET;
                end
            end

            S_FMT_EMIT: begin
                // Emit digits in reverse order (MSB first) + sign
                // First emit: sign glyph
                if (emit_idx == 0 && digit_count > 0) begin
                    fmt_glyph <= fmt_is_negative ? 6'd37 : 6'd38;  // neg/pos sign
                    fmt_pos <= 0;
                    fmt_wr <= 1;
                    emit_idx <= 1;
                    fmt_len <= digit_count + 1;  // digits + sign
                end else if (emit_idx <= digit_count) begin
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

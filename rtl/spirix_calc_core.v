// spirix_calc_core.v — RPN calculator core with Spirix ALU
//
// Fixed F5E4: 32-bit fraction (MSB-aligned), 16-bit exponent (LSB-aligned).
// Instantiates ALU modules with constant width pins (Yosys optimizes away unused paths).
// Phase 1: hardcoded FSM for basic operators (add, sub, mul, div, mod, neg).
// Phase 3 will replace FSM with microcode sequencer + formatter.

module spirix_calc_core (
    input  wire        clk,

    // Stack interface (active values from top_pin_scan)
    input  wire [31:0] stk_x_frac, stk_y_frac,
    input  wire signed [15:0] stk_x_exp, stk_y_exp,
    input  wire [2:0]  stk_depth,

    // Command
    input  wire [5:0]  op_slot,     // glyph slot of operator
    input  wire        op_start,    // pulse to begin
    output wire        op_busy,
    output reg         op_done = 0, // pulse when result ready

    // Result (top writes back to stack)
    output reg  [31:0] res_frac = 0,
    output reg  signed [15:0] res_exp = 0,
    output reg         res_is_binary = 0  // 1 = consumed Y+X, 0 = unary on X
);

    // =========================================================================
    // Constants — F5E4 (32-bit frac, 16-bit exp)
    // =========================================================================
    localparam [1:0] FRAC_W = 2'b10;  // 32-bit
    localparam [1:0] EXP_W  = 2'b01;  // 16-bit

    // Pad 32-bit frac to 64-bit MSB-aligned, 16-bit exp to 64-bit LSB-aligned
    // For binary ops: A=Y (first entered), B=X (second entered). Y op X.
    // For unary ops: A=X. B unused.
    wire [63:0] a_frac_64 = {stk_y_frac, 32'd0};
    wire [63:0] a_exp_64  = {{48{stk_y_exp[15]}}, stk_y_exp};
    wire [63:0] b_frac_64 = {stk_x_frac, 32'd0};
    wire [63:0] b_exp_64  = {{48{stk_x_exp[15]}}, stk_x_exp};
    // Unary: use X directly
    wire [63:0] unary_frac_64 = {stk_x_frac, 32'd0};
    wire [63:0] unary_exp_64  = {{48{stk_x_exp[15]}}, stk_x_exp};

    // =========================================================================
    // ALU instances — all wired in parallel, result mux selects
    // =========================================================================

    // --- ADD/SUB ---
    wire [63:0] add_res_frac, add_res_exp;
    reg  [2:0]  add_op = 0;
    spirix_alu_addbit u_addbit (
        .clk(clk), .ce(1'b1),
        .op(add_op),
        .frac_width(FRAC_W), .exp_width(EXP_W),
        .a_frac(a_frac_64), .a_exp(a_exp_64),
        .b_frac(b_frac_64), .b_exp(b_exp_64),
        .result_frac(add_res_frac), .result_exp(add_res_exp)
    );

    // --- MULTIPLY ---
    wire [63:0] mul_res_frac, mul_res_exp;
    spirix_alu_multiply u_mul (
        .frac_width(FRAC_W), .exp_width(EXP_W),
        .a_frac(a_frac_64), .a_exp(a_exp_64),
        .b_frac(b_frac_64), .b_exp(b_exp_64),
        .result_frac(mul_res_frac), .result_exp(mul_res_exp)
    );

    // --- DIV/MOD ---
    wire [63:0] div_res_frac, div_res_exp;
    reg  [1:0]  div_op = 0;
    reg         div_start = 0;
    wire        div_busy, div_done;
    spirix_alu_divmodsqrt u_divmod (
        .clk(clk),
        .op(div_op),
        .frac_width(FRAC_W), .exp_width(EXP_W),
        .a_frac(a_frac_64), .a_exp(a_exp_64),
        .b_frac(b_frac_64), .b_exp(b_exp_64),
        .start(div_start),
        .result_frac(div_res_frac), .result_exp(div_res_exp),
        .busy(div_busy), .done(div_done)
    );

    // --- FLOOR ---
    wire [63:0] floor_res_frac, floor_res_exp;
    spirix_alu_round u_round (
        .op(2'b00),  // FLOOR
        .frac_width(FRAC_W), .exp_width(EXP_W),
        .a_frac(a_frac_64), .a_exp(a_exp_64),
        .result_frac(floor_res_frac), .result_exp(floor_res_exp)
    );

    // --- NEG/ABS ---
    wire [63:0] basic_res_frac, basic_res_exp;
    reg  [2:0]  basic_op = 0;
    spirix_alu_basic u_basic (
        .op(basic_op),
        .frac_width(FRAC_W), .exp_width(EXP_W),
        .a_frac(unary_frac_64), .a_exp(unary_exp_64),
        .b_frac(64'd0), .b_exp(64'd0),
        .result_frac(basic_res_frac), .result_exp(basic_res_exp)
    );

    // =========================================================================
    // Operator FSM
    // =========================================================================
    localparam [2:0]
        S_IDLE     = 3'd0,
        S_EXEC     = 3'd1,  // combinational ops: result ready same cycle
        S_DIV_WAIT = 3'd2,  // waiting for iterative divider
        S_DONE     = 3'd3;

    reg [2:0] state = S_IDLE;
    reg [2:0] alu_sel = 0;  // which ALU result to capture

    assign op_busy = (state != S_IDLE);

    always @(posedge clk) begin
        op_done <= 0;
        div_start <= 0;

        case (state)
            S_IDLE: begin
                if (op_start) begin
                    // Decode glyph slot → ALU unit + op
                    case (op_slot)
                        6'd13: begin  // add (→)
                            add_op <= 3'd0;
                            alu_sel <= 3'd0;
                            res_is_binary <= 1;
                            state <= S_EXEC;
                        end
                        6'd31: begin  // subtract (←)
                            add_op <= 3'd1;
                            alu_sel <= 3'd0;
                            res_is_binary <= 1;
                            state <= S_EXEC;
                        end
                        6'd16: begin  // multiply
                            alu_sel <= 3'd1;
                            res_is_binary <= 1;
                            state <= S_EXEC;
                        end
                        6'd14: begin  // divide
                            div_op <= 2'd0;
                            div_start <= 1;
                            alu_sel <= 3'd2;
                            res_is_binary <= 1;
                            state <= S_DIV_WAIT;
                        end
                        6'd32: begin  // modulus
                            div_op <= 2'd2;
                            div_start <= 1;
                            alu_sel <= 3'd2;
                            res_is_binary <= 1;
                            state <= S_DIV_WAIT;
                        end
                        6'd12: begin  // negate
                            basic_op <= 3'd0;
                            alu_sel <= 3'd4;
                            res_is_binary <= 0;
                            state <= S_EXEC;
                        end
                        default: begin
                            // Unknown op — ignore
                            state <= S_IDLE;
                        end
                    endcase
                end
            end

            S_EXEC: begin
                // Combinational result ready — capture and output
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
        endcase
    end

endmodule

// tb_formatter.v — Testbench for spirix_calc_core formatter
//
// Tests the formatter with known scalar values and checks digit output.
// Run: iverilog -o tb_fmt bench/tb_formatter.v rtl/spirix_calc_core.v \
//        ../spirix/fpga/cores/ops/spirix_neg.v \
//        ../spirix/fpga/cores/ops/spirix_alu_basic.v \
//        ../spirix/fpga/cores/ops/spirix_alu_addbit.v \
//        ../spirix/fpga/cores/ops/spirix_alu_multiply.v \
//        ../spirix/fpga/cores/ops/spirix_alu_divmodsqrt.v \
//        ../spirix/fpga/cores/ops/spirix_alu_round.v && vvp tb_fmt

`timescale 1ns/1ps

module tb_formatter;
    reg clk = 0;
    always #20 clk = ~clk;  // 25 MHz

    // Calc core signals
    reg [31:0] stk_x_frac = 0, stk_y_frac = 0;
    reg signed [15:0] stk_x_exp = 0, stk_y_exp = 0;
    reg [2:0] stk_depth = 0;
    reg [5:0] op_slot = 0;
    reg op_start = 0;
    wire op_busy, op_done;
    wire [31:0] res_frac;
    wire signed [15:0] res_exp;
    wire res_is_binary;

    reg [31:0] fmt_frac = 0;
    reg signed [15:0] fmt_exp = 0;
    reg fmt_start = 0;
    wire fmt_busy, fmt_done;
    wire [5:0] fmt_glyph;
    wire [3:0] fmt_pos;
    wire fmt_wr;
    wire [4:0] fmt_len;

    spirix_calc_core uut (
        .clk(clk),
        .stk_x_frac(stk_x_frac), .stk_x_exp(stk_x_exp),
        .stk_y_frac(stk_y_frac), .stk_y_exp(stk_y_exp),
        .stk_depth(stk_depth),
        .op_slot(op_slot), .op_start(op_start),
        .op_busy(op_busy), .op_done(op_done),
        .res_frac(res_frac), .res_exp(res_exp),
        .res_is_binary(res_is_binary),
        .fmt_frac(fmt_frac), .fmt_exp(fmt_exp),
        .fmt_start(fmt_start), .fmt_busy(fmt_busy), .fmt_done(fmt_done),
        .fmt_glyph(fmt_glyph), .fmt_pos(fmt_pos), .fmt_wr(fmt_wr),
        .fmt_len(fmt_len)
    );

    // Capture emitted glyphs
    reg [5:0] emitted [0:15];
    reg [3:0] emit_count = 0;
    integer i;
    initial for (i = 0; i < 16; i = i + 1) emitted[i] = 6'd63;

    always @(posedge clk) begin
        if (fmt_wr) begin
            emitted[fmt_pos] <= fmt_glyph;
            emit_count <= emit_count + 1;
            $display("  emit[%0d] = %0d (glyph slot)", fmt_pos, fmt_glyph);
        end
    end

    task format_value;
        input [31:0] frac;
        input signed [15:0] exp;
        input [8*20-1:0] label;  // string label
        begin
            $display("\n=== Format %0s: frac=0x%08x exp=%0d ===", label, frac, exp);
            fmt_frac = frac;
            fmt_exp = exp;
            emit_count = 0;
            for (i = 0; i < 16; i = i + 1) emitted[i] = 6'd63;

            @(posedge clk);
            fmt_start = 1;
            @(posedge clk);
            fmt_start = 0;

            // Wait for done
            while (!fmt_done) @(posedge clk);

            $display("  Total emitted: %0d, fmt_len=%0d", emit_count, fmt_len);
            $write("  Digits: ");
            for (i = 0; i < fmt_len; i = i + 1) begin
                if (emitted[i] == 6'd38) $write("+");
                else if (emitted[i] == 6'd37) $write("-");
                else if (emitted[i] <= 6'd9) $write("%0d", emitted[i]);
                else if (emitted[i] == 6'd10) $write("A");
                else if (emitted[i] == 6'd11) $write("B");
                else $write("?%0d?", emitted[i]);
            end
            $display("");
        end
    endtask

    initial begin
        $dumpfile("tb_fmt.vcd");
        $dumpvars(0, tb_formatter);

        // Wait for reset
        repeat(10) @(posedge clk);

        // Test 1: value = 0 (frac=0, exp=AMBIG)
        format_value(32'h00000000, -16'sd32768, "zero");

        // Values from Rust: cargo run --example gen_calc_vectors
        // Convention: value = frac * 2^(exp - 31)
        format_value(32'h40000000, 16'sd1,  "one");        // 1
        format_value(32'h40000000, 16'sd2,  "two");        // 2
        format_value(32'h60000000, 16'sd2,  "three");      // 3
        format_value(32'h70000000, 16'sd3,  "seven");      // 7
        format_value(32'h58000000, 16'sd4,  "eleven");     // 11 = B
        format_value(32'h60000000, 16'sd4,  "twelve");     // 12 = 10
        format_value(32'h60000000, 16'sd5,  "twentyfour"); // 24 = 20
        format_value(32'h48000000, 16'sd8,  "144");        // 144 = 100
        format_value(32'hA0000000, 16'sd2,  "neg_three");  // -3
        format_value(32'h80000000, 16'sd0,  "neg_one");    // -1

        // Direct operator multiply test: 3 * 4 should be 12
        $display("\n=== Operator MUL test: 3 * 4 ===");
        stk_y_frac = 32'h60000000; stk_y_exp = 16'sd2;  // Y = 3
        stk_x_frac = 32'h40000000; stk_x_exp = 16'sd3;  // X = 4
        stk_depth = 3'd2;
        @(posedge clk);
        op_slot = 6'd16;  // multiply
        op_start = 1;
        @(posedge clk);
        op_start = 0;
        while (!op_done) @(posedge clk);
        $display("  3 * 4 = frac=0x%08x exp=%0d", res_frac, $signed(res_exp));
        $display("  Expected: frac=0x60000000 exp=4 (=12)");

        $display("\n=== All tests complete ===");
        $finish;
    end
endmodule

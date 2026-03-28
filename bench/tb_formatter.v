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

        // Convention: value = frac * 2^(exp - 31)
        // Test 2: value = 1. frac=0x40000000, exp=1. (2^30 * 2^(1-31) = 2^30 * 2^-30 = 1)
        format_value(32'h40000000, 16'sd1, "one");

        // Test 3: value = 3. frac=0x60000000, exp=2. (1.5*2^30 * 2^(2-31) = 1.5*2 = 3)
        format_value(32'h60000000, 16'sd2, "three");

        // Test 4: value = 12. frac=0x60000000, exp=4. (1.5*2^30 * 2^(4-31) = 1.5*8 = 12)
        format_value(32'h60000000, 16'sd4, "twelve");

        // Test 5: value = 7. frac=0x70000000, exp=3. (1.75*2^30 * 2^(3-31) = 1.75*4 = 7)
        format_value(32'h70000000, 16'sd3, "seven");

        // Test 6: value = 144. frac=0x48000000, exp=8. (1.125*2^30 * 2^(8-31) = 1.125*128 = 144)
        format_value(32'h48000000, 16'sd8, "144");

        // Direct MUL test: 0.0833 * 12 should be 1.0
        $display("\n=== Direct MUL test ===");
        // Set work registers and observe MUL output
        @(posedge clk);
        // Can't directly access work regs, but let's test via operator
        // Actually, let's just test the formatter output for now

        // Add more test values
        // value 2: frac=0x40000000, exp=2. (2^30 * 2^(2-31) = 2)
        format_value(32'h40000000, 16'sd2, "two");

        // value 11: frac=0x58000000, exp=4. Check: 0x58000000 * 2^(4-31)
        // 0x58000000 = 1476395008. * 2^(-27) = 11.0
        format_value(32'h58000000, 16'sd4, "eleven");

        // value 24: frac=0x60000000, exp=5. 1.5 * 16 = 24
        format_value(32'h60000000, 16'sd5, "twentyfour");

        $display("\n=== All tests complete ===");
        $finish;
    end
endmodule

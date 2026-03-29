// tb_state.v — Testbench for spirix_state module
//
// Verifies state detection against known Spirix values.
// Run: iverilog -o tb_state bench/tb_state.v rtl/spirix_state.v && vvp tb_state

`timescale 1ns/1ps

module tb_state;
    reg [31:0] frac;
    reg signed [15:0] exp;
    wire is_zero, is_positive, is_negative, is_n1, is_normal;
    wire is_infinite, is_exploded, is_vanished;

    spirix_state uut (
        .frac(frac), .exp(exp),
        .is_zero(is_zero), .is_positive(is_positive), .is_negative(is_negative),
        .is_n1(is_n1), .is_normal(is_normal),
        .is_infinite(is_infinite), .is_exploded(is_exploded), .is_vanished(is_vanished)
    );

    integer pass_count = 0;
    integer fail_count = 0;

    task check;
        input [8*30-1:0] label;
        input exp_zero, exp_pos, exp_neg, exp_n1, exp_normal;
        input exp_inf, exp_expl, exp_van;
        begin
            #1;
            if (is_zero !== exp_zero || is_positive !== exp_pos ||
                is_negative !== exp_neg || is_n1 !== exp_n1 ||
                is_normal !== exp_normal || is_infinite !== exp_inf ||
                is_exploded !== exp_expl || is_vanished !== exp_van) begin
                $display("FAIL %0s: frac=0x%08x exp=%0d", label, frac, exp);
                $display("  got:  z=%b p=%b n=%b n1=%b norm=%b inf=%b expl=%b van=%b",
                    is_zero, is_positive, is_negative, is_n1, is_normal,
                    is_infinite, is_exploded, is_vanished);
                $display("  want: z=%b p=%b n=%b n1=%b norm=%b inf=%b expl=%b van=%b",
                    exp_zero, exp_pos, exp_neg, exp_n1, exp_normal,
                    exp_inf, exp_expl, exp_van);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS %0s", label);
                pass_count = pass_count + 1;
            end
        end
    endtask

    initial begin
        //                              label              zero pos  neg  n1   norm inf  expl van

        // === ZERO ===
        frac = 32'h00000000; exp = 16'sh8000;
        check("zero",                  1,   0,   0,   0,   0,   0,   0,   0);

        // === POSITIVE NORMAL ===
        // Value 1: frac=0x40000000, exp=1
        frac = 32'h40000000; exp = 16'sd1;
        check("pos_one",               0,   1,   0,   1,   1,   0,   0,   0);

        // Value 3: frac=0x60000000, exp=2
        frac = 32'h60000000; exp = 16'sd2;
        check("pos_three",             0,   1,   0,   1,   1,   0,   0,   0);

        // Value 0.5: frac=0x40000000, exp=0
        frac = 32'h40000000; exp = 16'sd0;
        check("pos_half",              0,   1,   0,   1,   1,   0,   0,   0);

        // Max positive N1: frac=0x7FFFFFFF, exp=32767
        frac = 32'h7FFFFFFF; exp = 16'sh7FFF;
        check("pos_max",               0,   1,   0,   1,   1,   0,   0,   0);

        // === NEGATIVE NORMAL ===
        // Value -1: frac=0x80000000, exp=0 (NEG_ONE at normal exp)
        frac = 32'h80000000; exp = 16'sd0;
        check("neg_one",               0,   0,   1,   1,   1,   0,   0,   0);

        // Value -3: frac=0xA0000000, exp=2
        frac = 32'hA0000000; exp = 16'sd2;
        check("neg_three",             0,   0,   1,   1,   1,   0,   0,   0);

        // Value -0.5: frac=0xC0000000, exp=1 (NEG_ONE shifted)
        // Wait: 0xC0000000 top 2 bits = 11 → NOT N1. That's N2.
        // This shouldn't be a normal value. Let me use 0x80000000 exp=0 instead.
        // Actually -0.5 in Spirix: negate(0.5) = negate(0x40000000 exp=0)
        // POS_ONE special case: frac=0x80000000, exp=-1
        frac = 32'h80000000; exp = -16'sd1;
        check("neg_half",              0,   0,   1,   1,   1,   0,   0,   0);

        // Min negative N1: frac=0xBFFFFFFF, exp=anything
        frac = 32'hBFFFFFFF; exp = 16'sd5;
        check("neg_min_n1",            0,   0,   1,   1,   1,   0,   0,   0);

        // === INFINITY ===
        // Infinity: frac=AMBIG(0x80000000), exp=AMBIG. is_n1=1 (bits 10 differ).
        frac = 32'h80000000; exp = 16'sh8000;
        check("infinity",              0,   0,   1,   1,   0,   1,   0,   0);

        // === EXPLODED (positive) ===
        // N1 positive fraction at AMBIG exp (not AMBIG frac)
        frac = 32'h60000000; exp = 16'sh8000;
        check("exploded_pos",          0,   1,   0,   1,   0,   0,   1,   0);

        // === EXPLODED (negative) ===
        frac = 32'hA0000000; exp = 16'sh8000;
        check("exploded_neg",          0,   0,   1,   1,   0,   0,   1,   0);

        // === VANISHED (positive N2) ===
        // N2 positive: top 2 bits = 00, non-zero
        frac = 32'h20000000; exp = 16'sh8000;
        check("vanished_pos",          0,   1,   0,   0,   0,   0,   0,   1);

        // === VANISHED (negative N2) ===
        // N2 negative: top 2 bits = 11
        frac = 32'hC0000001; exp = 16'sh8000;
        check("vanished_neg",          0,   0,   1,   0,   0,   0,   0,   1);

        // === UNDEFINED ===
        // Undefined values have specific prefix patterns (top 3 bits all same)
        // 0x00000001 at AMBIG exp: frac non-zero, N2 (00...) → vanished
        frac = 32'h00000001; exp = 16'sh8000;
        check("undefined_like",        0,   1,   0,   0,   0,   0,   0,   1);
        // Note: our module doesn't distinguish undefined from vanished yet.
        // Full undefined detection needs prefix table lookup (future work).

        $display("\n=== Results: %0d PASS, %0d FAIL ===", pass_count, fail_count);
        if (fail_count > 0) $display("*** FAILURES DETECTED ***");
        $finish;
    end
endmodule

// spirix_state.v — Combinational Spirix scalar state detection
//
// Fixed F5E4: 32-bit fraction (signed i32), 16-bit exponent (signed i16).
// Detects: zero, positive, negative, normal, N1 form, infinite,
//          exploded, vanished. Pure combinational (no clock).
//
// Spirix N1 form: top 2 fraction bits differ (01=pos, 10=neg).
// AMBIG exponent (0x8000 = i16::MIN) marks special states.
// AMBIG fraction (0x80000000 = i32::MIN) = NEG_ONE or infinity sentinel.
//
// Reference: spirix/src/implementations/basic_scalar.rs

module spirix_state (
    input  wire [31:0]        frac,
    input  wire signed [15:0] exp,

    output wire is_zero,       // frac == 0 (exp should be AMBIG)
    output wire is_positive,   // frac > 0 (sign bit clear, non-zero)
    output wire is_negative,   // frac < 0 (sign bit set)
    output wire is_n1,         // N1 form: top 2 bits differ (valid normal fraction)
    output wire is_normal,     // N1 fraction AND non-AMBIG exponent
    output wire is_infinite,   // frac == AMBIG AND exp == AMBIG
    output wire is_exploded,   // N1 fraction AND exp == AMBIG (not infinite)
    output wire is_vanished    // N2 fraction AND exp == AMBIG (not zero, not infinite)
);

    // Spirix constants for F5E4
    localparam [31:0] AMBIG_FRAC = 32'sh80000000;  // i32::MIN
    localparam signed [15:0] AMBIG_EXP = 16'sh8000; // i16::MIN

    // N1: top 2 fraction bits differ (01 or 10)
    assign is_n1 = (frac[31] != frac[30]);

    // Zero: fraction is exactly 0
    assign is_zero = (frac == 32'd0);

    // Sign detection
    assign is_positive = !frac[31] && !is_zero;  // MSB=0 and non-zero
    assign is_negative = frac[31];                 // MSB=1 (includes AMBIG frac)

    // AMBIG checks
    wire is_ambig_exp = (exp == AMBIG_EXP);
    wire is_ambig_frac = (frac == AMBIG_FRAC);

    // Normal: valid N1 fraction with non-special exponent
    assign is_normal = is_n1 && !is_ambig_exp;

    // Infinity: both frac and exp are AMBIG
    assign is_infinite = is_ambig_frac && is_ambig_exp;

    // Exploded: N1 fraction at AMBIG exponent (overflow, but not infinity)
    assign is_exploded = is_n1 && is_ambig_exp && !is_ambig_frac;

    // Vanished: N2 fraction at AMBIG exponent (underflow, not zero, not infinity)
    assign is_vanished = !is_n1 && is_ambig_exp && !is_zero && !is_ambig_frac;

endmodule

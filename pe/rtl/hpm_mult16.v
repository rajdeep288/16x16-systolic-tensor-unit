`timescale 1ns / 1ps

// ============================================================================
// Precision-Scalable Signed Multiplier (INT4 / INT8 / INT16), 32-bit result.
//
//   a, b     : 16-bit operands (bits not used by mode must already be zero-masked).
//   is_int4  : active-high for INT4 mode
//   is_int8  : active-high for INT8 mode
//   is_int16 : active-high for INT16 mode
//   p        : raw 32-bit result. Valid bits:
//                INT4  -> p[7:0]
//                INT8  -> p[15:0]
//                INT16 -> p[31:0]
//              Upper bits above valid precision are held at 0 (not sign-extended).
//              PE top-level handles sign extension into the 36-bit accumulator.
// Pure Verilog-2001
// ============================================================================

module hpm_mult16 (
    input  wire [15:0] a,
    input  wire [15:0] b,
    input  wire        is_int4,
    input  wire        is_int8,
    input  wire        is_int16,
    output wire [31:0] p
);
    // ---- 5th-bit (sign) extension of every nibble ----
    wire [4:0] ea0, ea1, ea2, ea3;
    wire [4:0] eb0, eb1, eb2, eb3;
    nibble_ext u_ext_a (
        .x        (a),
        .is_int4  (is_int4),
        .is_int8  (is_int8),
        .is_int16 (is_int16),
        .e0       (ea0),
        .e1       (ea1),
        .e2       (ea2),
        .e3       (ea3)
    );
    nibble_ext u_ext_b (
        .x        (b),
        .is_int4  (is_int4),
        .is_int8  (is_int8),
        .is_int16 (is_int16),
        .e0       (eb0),
        .e1       (eb1),
        .e2       (eb2),
        .e3       (eb3)
    );

    // ---- four clusters: cluster CIJ multiplies A byte I by B byte J ----
    wire [15:0] c00, c01, c10, c11;
    hpm_cluster u_c00 (.ah(ea1), .al(ea0), .bh(eb1), .bl(eb0), .c(c00));  // A_lo x B_lo
    hpm_cluster u_c01 (.ah(ea1), .al(ea0), .bh(eb3), .bl(eb2), .c(c01));  // A_lo x B_hi
    hpm_cluster u_c10 (.ah(ea3), .al(ea2), .bh(eb1), .bl(eb0), .c(c10));  // A_hi x B_lo
    hpm_cluster u_c11 (.ah(ea3), .al(ea2), .bh(eb3), .bl(eb2), .c(c11));  // A_hi x B_hi

    // ---- central adder: shift and extend each cluster output to 32 bits ----
    wire [31:0] t00 = {16'b0,           c00};            // shift 0,  zero-extend (always)
    wire [31:0] t01 = {{8{c01[15]}},    c01, 8'b0};      // shift 8,  sign-extend
    wire [31:0] t10 = {{8{c10[15]}},    c10, 8'b0};      // shift 8,  sign-extend
    wire [31:0] t11 = {c11,             16'b0};          // shift 16, fills bits [31:16]

    assign p = t00 + t01 + t10 + t11;                    // carry-out of bit 31 dropped
endmodule

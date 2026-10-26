`timescale 1ns / 1ps

// ============================================================================
// 5x5 Baugh-Wooley Signed Multiplier with Dadda Tree Reduction
// Computes signed product p[9:0] = a[4:0] * b[4:0]
// Pure Verilog-2001
// ============================================================================

module hpm_bw_mult5x5 (
    input  wire [4:0] a,
    input  wire [4:0] b,
    output wire [9:0] p
);

    // ========================================================================
    // 1. Partial Product Generation (Baugh-Wooley logic)
    // ========================================================================
    wire pp_0_0, pp_1_0, pp_2_0, pp_3_0, pp_4_0_n;
    wire pp_0_1, pp_1_1, pp_2_1, pp_3_1, pp_4_1_n;
    wire pp_0_2, pp_1_2, pp_2_2, pp_3_2, pp_4_2_n;
    wire pp_0_3, pp_1_3, pp_2_3, pp_3_3, pp_4_3_n;
    wire pp_0_4_n, pp_1_4_n, pp_2_4_n, pp_3_4_n, pp_4_4;

    // Row 0
    and (pp_0_0, a[0], b[0]);
    and (pp_1_0, a[1], b[0]);
    and (pp_2_0, a[2], b[0]);
    and (pp_3_0, a[3], b[0]);
    nand(pp_4_0_n, a[4], b[0]);

    // Row 1
    and (pp_0_1, a[0], b[1]);
    and (pp_1_1, a[1], b[1]);
    and (pp_2_1, a[2], b[1]);
    and (pp_3_1, a[3], b[1]);
    nand(pp_4_1_n, a[4], b[1]);

    // Row 2
    and (pp_0_2, a[0], b[2]);
    and (pp_1_2, a[1], b[2]);
    and (pp_2_2, a[2], b[2]);
    and (pp_3_2, a[3], b[2]);
    nand(pp_4_2_n, a[4], b[2]);
    
    // Row 3
    and (pp_0_3, a[0], b[3]);
    and (pp_1_3, a[1], b[3]);
    and (pp_2_3, a[2], b[3]);
    and (pp_3_3, a[3], b[3]);
    nand(pp_4_3_n, a[4], b[3]);
 
    // Row 4
    nand(pp_0_4_n, a[0], b[4]);
    nand(pp_1_4_n, a[1], b[4]);
    nand(pp_2_4_n, a[2], b[4]);
    nand(pp_3_4_n, a[3], b[4]);
    and (pp_4_4, a[4], b[4]);

    // ========================================================================
    // 2. Optimized Tree Reduction (Dadda-style Triangular Layout)
    // ========================================================================
    
    // LEVEL 1
    wire s51, c51, sh41, ch41;
    FULL_ADDER FA51 (.a(pp_4_1_n), .b(pp_3_2), .cin(pp_2_3), .sum(s51), .cout(c51));
    HALF_ADDER HA41 (.a(pp_4_0_n), .b(pp_3_1), .sum(sh41), .cout(ch41));

    // LEVEL 2
    wire s61, c61, s52, c52, s41, c41, sh31, ch31;
    FULL_ADDER FA61 (.a(pp_4_2_n), .b(pp_3_3), .cin(c51), .sum(s61), .cout(c61));
    FULL_ADDER FA52 (.a(pp_1_4_n), .b(s51), .cin(ch41), .sum(s52), .cout(c52));
    FULL_ADDER FA41 (.a(pp_2_2), .b(pp_1_3), .cin(sh41), .sum(s41), .cout(c41));
    HALF_ADDER HA31 (.a(pp_3_0), .b(pp_2_1), .sum(sh31), .cout(ch31));
    
    // LEVEL 3
    wire s71, c71, s62, c62, s53, c53, s42, c42, s31, c31, sh21, ch21;
    FULL_ADDER FA71 (.a(pp_4_3_n), .b(pp_3_4_n), .cin(c61), .sum(s71), .cout(c71));
    FULL_ADDER FA62 (.a(pp_2_4_n), .b(s61), .cin(c52), .sum(s62), .cout(c62));
    FULL_ADDER FA53 (.a(1'b1), .b(s52), .cin(c41), .sum(s53), .cout(c53));
    FULL_ADDER FA42 (.a(pp_0_4_n), .b(s41), .cin(ch31), .sum(s42), .cout(c42));
    FULL_ADDER FA31 (.a(pp_1_2), .b(pp_0_3), .cin(sh31), .sum(s31), .cout(c31));
    HALF_ADDER HA21 (.a(pp_1_1), .b(pp_2_0), .sum(sh21), .cout(ch21));

    // ------------------------------------------------------------------------
    // LEVEL 4 (Carry Propagate Adder Row)
    // ------------------------------------------------------------------------
    assign p[0] = pp_0_0;

    wire c1, c2, c3, c4, c5, c6, c7, c8;
    HALF_ADDER HA11_cpa (.a(pp_1_0), .b(pp_0_1), .sum(p[1]), .cout(c1));
    FULL_ADDER FA21_cpa (.a(pp_0_2), .b(sh21), .cin(c1), .sum(p[2]), .cout(c2));
    FULL_ADDER FA32_cpa (.a(ch21), .b(s31), .cin(c2), .sum(p[3]), .cout(c3));
    FULL_ADDER FA43_cpa (.a(s42), .b(c31), .cin(c3), .sum(p[4]), .cout(c4));
    FULL_ADDER FA54_cpa (.a(c42), .b(s53), .cin(c4), .sum(p[5]), .cout(c5));
    FULL_ADDER FA63_cpa (.a(s62), .b(c53), .cin(c5), .sum(p[6]), .cout(c6));
    FULL_ADDER FA72_cpa (.a(s71), .b(c62), .cin(c6), .sum(p[7]), .cout(c7));
    FULL_ADDER FA81_cpa (.a(pp_4_4), .b(c71), .cin(c7), .sum(p[8]), .cout(c8));

    not u_inv_p9 (p[9], c8);

endmodule

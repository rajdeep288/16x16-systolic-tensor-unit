`timescale 1ns / 1ps

// ============================================================================
// Multiplier Cluster Module (CIJ)
// Multiplies byte I (ah:al) by byte J (bh:bl) using four 5x5 Baugh-Wooley multipliers.
// Pure Verilog-2001
// ============================================================================

module hpm_cluster (
    input  wire [4:0]  ah, al,
    input  wire [4:0]  bh, bl,
    output wire [15:0] c
);
    wire [9:0] p00, p01, p10, p11;

    hpm_bw_mult5x5 m00 (.a(al), .b(bl), .p(p00));
    hpm_bw_mult5x5 m01 (.a(al), .b(bh), .p(p01));
    hpm_bw_mult5x5 m10 (.a(ah), .b(bl), .p(p10));
    hpm_bw_mult5x5 m11 (.a(ah), .b(bh), .p(p11));

    wire [15:0] r00 = {8'b0,         p00[7:0]};
    wire [15:0] r01 = {{2{p01[9]}},  p01, 4'b0};
    wire [15:0] r10 = {{2{p10[9]}},  p10, 4'b0};
    wire [15:0] r11 = {p11[7:0],     8'b0};

    assign c = r00 + r01 + r10 + r11;      // 16-bit sum, carry-out dropped
endmodule

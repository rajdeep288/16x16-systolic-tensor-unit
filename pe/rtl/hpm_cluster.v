`timescale 1ns / 1ps

// ============================================================================
// Multiplier Cluster Module (CIJ)
// 4 bricks (5x5 signed) + 16-bit internal adder:
//   - Carry-save reduction (csa3: 3:2 compressor)
//   - 12-bit Carry-lookahead adder (cla_nb)
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

    // rows r01 and r10 (shift 4, sign-extended)
    wire [15:0] r01 = {{2{p01[9]}}, p01, 4'b0};
    wire [15:0] r10 = {{2{p10[9]}}, p10, 4'b0};

    // rows r00 (bits [7:0], zero-extended) and r11 (bits [15:8]) never overlap,
    // so r00 + r11 is just the two placed side by side
    wire [15:0] x = {p11[7:0], p00[7:0]};

    // bits [15:4] have exactly three rows (x, r01, r10): one 3:2 carry-save level leaves two rows
    wire [11:0] s_hi, cy_hi;
    csa3 #(.W(12)) u_csa (.x(x[15:4]), .y(r01[15:4]), .z(r10[15:4]), .s(s_hi), .cy(cy_hi));

    // the carry row has the weight of the next bit (shift up by one); 12-bit CLA adds the two rows
    cla_nb #(.NB(3)) u_cla (.a(s_hi), .b({cy_hi[10:0], 1'b0}), .cin(1'b0), .sum(c[15:4]), .cout());

    // bits [3:0] have only x: nothing to add and no carry into bit 4
    assign c[3:0] = x[3:0];
endmodule

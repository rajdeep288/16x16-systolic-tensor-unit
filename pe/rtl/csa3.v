`timescale 1ns / 1ps

// ============================================================================
// 3:2 Carry-Save Compressor (CSA)
// Compresses three input rows (x, y, z) into two output rows (sum and carry).
// Carry 'cy' has the weight of the NEXT bit: x + y + z = s + 2*cy.
// Pure Verilog-2001
// ============================================================================

module csa3 #(parameter W = 12) (
    input  wire [W-1:0] x, y, z,
    output wire [W-1:0] s,
    output wire [W-1:0] cy
);
    assign s  = x ^ y ^ z;
    assign cy = (x & y) | (x & z) | (y & z);
endmodule

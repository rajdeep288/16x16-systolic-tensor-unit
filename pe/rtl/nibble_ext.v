`timescale 1ns / 1ps

// ============================================================================
// Nibble Sign-Extension Unit
// Builds the 5th (sign) bit for each nibble of a 16-bit operand.
// top[i] = 1 only for the top nibble of the current mode:
//   INT4: 0001, INT8: 0010, INT16: 1000.
// Pure Verilog-2001
// ============================================================================

module nibble_ext (
    input  wire [15:0] x,
    input  wire [3:0]  top,
    output wire [4:0]  e0, e1, e2, e3
);
    assign e0 = {top[0] & x[3],  x[3:0]};
    assign e1 = {top[1] & x[7],  x[7:4]};
    assign e2 = {1'b0,           x[11:8]};   // never the top nibble: no gate
    assign e3 = {top[3] & x[15], x[15:12]};
endmodule

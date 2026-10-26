`timescale 1ns / 1ps

// ============================================================================
// Nibble Sign-Extension Unit
// Generates the 5th sign bit for each 4-bit nibble dynamically based on precision mode.
// Pure Verilog-2001
// ============================================================================

module nibble_ext (
    input  wire [15:0] x,
    input  wire        is_int4,
    input  wire        is_int8,
    input  wire        is_int16,
    output wire [4:0]  e0, e1, e2, e3
);
    assign e0 = {is_int4  & x[3],  x[3:0]};
    assign e1 = {is_int8  & x[7],  x[7:4]};
    assign e2 = {1'b0,             x[11:8]};   // never the top nibble: no sign bit
    assign e3 = {is_int16 & x[15], x[15:12]};
endmodule

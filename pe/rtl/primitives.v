`timescale 1ns / 1ps

// ============================================================================
// Primitive Gate-Level Adder Modules
// Standard full adder and half adder cells for partial product reduction.
// Pure Verilog-2001
// ============================================================================

module HALF_ADDER (
    input  wire a,
    input  wire b,
    output wire sum,
    output wire cout
);
    xor (sum,  a, b);
    and (cout, a, b);
endmodule

module FULL_ADDER (
    input  wire a,
    input  wire b,
    input  wire cin,
    output wire sum,
    output wire cout
);
    wire ab_xor;
    wire n1, n2;
    
    xor (ab_xor, a, b);
    xor (sum,    ab_xor, cin);
    
    and (n1,     a, b);
    and (n2,     ab_xor, cin);
    or  (cout,   n1, n2);
endmodule

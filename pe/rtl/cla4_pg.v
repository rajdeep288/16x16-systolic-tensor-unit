`timescale 1ns / 1ps

// ============================================================================
// 4-bit Carry-Lookahead Adder with Block (P, G) Outputs
// Generates sum[3:0], ripple cout, and group generate (gg) & propagate (pg)
// for hierarchical carry lookahead unit interconnection.
// Pure Verilog-2001
// ============================================================================

module cla4_pg (
    input  wire [3:0] a,
    input  wire [3:0] b,
    input  wire       cin,
    output wire [3:0] sum,
    output wire       cout,
    output wire       pg,  // Block Propagate
    output wire       gg   // Block Generate
);
    wire [3:0] p, g;
    wire [3:1] c;

    assign p = a ^ b;
    assign g = a & b;

    assign c[1] = g[0] | (p[0] & cin);
    assign c[2] = g[1] | (p[1] & g[0]) | (p[1] & p[0] & cin);
    assign c[3] = g[2] | (p[2] & g[1]) | (p[2] & p[1] & g[0]) | (p[2] & p[1] & p[0] & cin);

    assign sum[0] = p[0] ^ cin;
    assign sum[1] = p[1] ^ c[1];
    assign sum[2] = p[2] ^ c[2];
    assign sum[3] = p[3] ^ c[3];

    assign pg = p[3] & p[2] & p[1] & p[0];
    assign gg = g[3] | (p[3] & g[2]) | (p[3] & p[2] & g[1]) | (p[3] & p[2] & p[1] & g[0]);

    assign cout = gg | (pg & cin);
endmodule

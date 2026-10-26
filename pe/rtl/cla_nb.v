`timescale 1ns / 1ps

// ============================================================================
// (4*NB)-bit Carry-Lookahead Adder (CLA)
// Composed of NB blocks of 4-bit lookahead generators with second-level lookahead.
// Pure Verilog-2001
// ============================================================================

module cla_nb #(parameter NB = 3) (
    input  wire [4*NB-1:0] a, b,
    input  wire            cin,
    output wire [4*NB-1:0] sum,
    output wire            cout
);
    localparam W = 4*NB;

    wire [W-1:0] p = a ^ b;          // bit propagate
    wire [W-1:0] g = a & b;          // bit generate

    // group (4-bit block) generate / propagate
    wire [NB-1:0] gg, pg;
    genvar k;
    generate
        for (k = 0; k < NB; k = k + 1) begin : grp
            wire [3:0] pk = p[4*k +: 4];
            wire [3:0] gk = g[4*k +: 4];
            assign gg[k] = gk[3] | (pk[3] & gk[2]) | (pk[3] & pk[2] & gk[1])
                         | (pk[3] & pk[2] & pk[1] & gk[0]);
            assign pg[k] = pk[3] & pk[2] & pk[1] & pk[0];
        end
    endgenerate

    // second-level lookahead: cb[i] = carry into block i
    wire [NB:0] cb;
    assign cb[0] = cin;
    genvar j;
    generate
        for (k = 1; k <= NB; k = k + 1) begin : la
            wire [k-1:0] t;
            for (j = 0; j < k; j = j + 1) begin : term
                if (j == k - 1) begin : last
                    assign t[j] = gg[j];
                end else begin : rest
                    assign t[j] = gg[j] & (&pg[k-1:j+1]);
                end
            end
            assign cb[k] = (|t) | (cin & (&pg[k-1:0]));
        end
    endgenerate
    assign cout = cb[NB];

    // carry into every bit of each block, then the sum bits
    generate
        for (k = 0; k < NB; k = k + 1) begin : blk
            wire [3:0] pk = p[4*k +: 4];
            wire [3:0] gk = g[4*k +: 4];
            wire [3:0] c;
            assign c[0] = cb[k];
            assign c[1] = gk[0] | (pk[0] & cb[k]);
            assign c[2] = gk[1] | (pk[1] & gk[0]) | (pk[1] & pk[0] & cb[k]);
            assign c[3] = gk[2] | (pk[2] & gk[1]) | (pk[2] & pk[1] & gk[0]) | (pk[2] & pk[1] & pk[0] & cb[k]);
            assign sum[4*k +: 4] = pk ^ c;
        end
    endgenerate
endmodule

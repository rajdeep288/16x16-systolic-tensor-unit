`timescale 1ns / 1ps

// ============================================================================
// 36-bit Segmented Carry-Lookahead Adder (Clean Segmented Architecture)
//
// Operands:
//   a, b     : 36-bit pre-processed operands (from accumulator and formatted product).
//   en_s1    : Carry-kill enable for Segment S1 (bits [19:12]).
//   en_s2    : Carry-kill enable for Segment S2 (bits [35:20]).
//   sum_out  : 36-bit accumulated sum.
//
// Structure:
//   - 9 x 4-bit CLA blocks (cla4_pg)
//   - Hierarchical Level-2 Lookahead Carry Unit (LCU)
//   - Dynamic carry kill at bit 11->12 (en_s1) and bit 19->20 (en_s2)
//   - Zero internal MUXes; operand isolation handled externally
// Pure Verilog-2001
// ============================================================================

module segmented_cla_adder (
    input  wire [35:0] a,       // Operand A (from accumulator)
    input  wire [35:0] b,       // Operand B (from formatted product)
    input  wire        en_s1,   // Enable carry into Segment S1
    input  wire        en_s2,   // Enable carry into Segment S2
    output wire [35:0] sum_out
);

    // -------------------------------------------------------------------------
    // A. 9 Blocks of 4-bit CLA (36 bits total)
    // -------------------------------------------------------------------------
    wire [8:0] pg_blk;
    wire [8:0] gg_blk;
    wire [8:0] cin_blk;

    genvar i;
    generate
        for (i = 0; i < 9; i = i + 1) begin : gen_cla_blocks
            cla4_pg u_cla4 (
                .a    (a[4*i +: 4]),
                .b    (b[4*i +: 4]),
                .cin  (cin_blk[i]),
                .sum  (sum_out[4*i +: 4]),
                .cout (),
                .pg   (pg_blk[i]),
                .gg   (gg_blk[i])
            );
        end
    endgenerate

    // -------------------------------------------------------------------------
    // B. Second-Level Lookahead Carry Unit (LCU) with Carry-Kill Boundaries
    // -------------------------------------------------------------------------

    // --- Segment S0 (Blocks 0, 1, 2) [11:0] ---
    assign cin_blk[0] = 1'b0;
    assign cin_blk[1] = gg_blk[0];
    assign cin_blk[2] = gg_blk[1] | (pg_blk[1] & gg_blk[0]);
    wire c12          = gg_blk[2] | (pg_blk[2] & gg_blk[1])
                      | (pg_blk[2] & pg_blk[1] & gg_blk[0]);

    // Carry-Kill Boundary 1 (Bit 11 -> 12)
    wire cin_s1       = c12 & en_s1;

    // --- Segment S1 (Blocks 3, 4) [19:12] ---
    assign cin_blk[3] = cin_s1;
    assign cin_blk[4] = gg_blk[3] | (pg_blk[3] & cin_s1);
    wire c20          = gg_blk[4] | (pg_blk[4] & gg_blk[3])
                      | (pg_blk[4] & pg_blk[3] & cin_s1);

    // Carry-Kill Boundary 2 (Bit 19 -> 20)
    wire cin_s2       = c20 & en_s2;

    // --- Segment S2 (Blocks 5, 6, 7, 8) [35:20] ---
    assign cin_blk[5] = cin_s2;
    assign cin_blk[6] = gg_blk[5] | (pg_blk[5] & cin_s2);
    assign cin_blk[7] = gg_blk[6] | (pg_blk[6] & gg_blk[5])
                      | (pg_blk[6] & pg_blk[5] & cin_s2);
    assign cin_blk[8] = gg_blk[7] | (pg_blk[7] & gg_blk[6])
                      | (pg_blk[7] & pg_blk[6] & gg_blk[5])
                      | (pg_blk[7] & pg_blk[6] & pg_blk[5] & cin_s2);

endmodule

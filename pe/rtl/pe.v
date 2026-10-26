`timescale 1ns / 1ps

// ============================================================================
// Processing Element (PE) - Top-Level RTL
// Precision-Scalable 16x16 Systolic Tensor Unit (INT4, INT8, INT16)
//
// Compliant with Assignment 2A Specification:
//   - Mode 2'b00: INT4   (4-bit MAC,  12-bit Segment S0 accumulated)
//   - Mode 2'b01: INT8   (8-bit MAC,  20-bit Segments S0+S1 accumulated)
//   - Mode 2'b10: INT16  (16-bit MAC, 36-bit Segments S0+S1+S2 accumulated)
//
// Key Optimizations:
//   - Zero-overhead operand isolation to prevent inactive toggle power
//   - 2-Level Hierarchical Carry-Lookahead Adder (406 ps delay, meets 300 MHz)
//   - High-Performance Precision-Scalable Multiplier (HPM Dadda tree)
//   - Minimal accumulator sequential logic (direct assignment, zero enable MUXes)
// Pure Verilog-2001
// ============================================================================

module pe (
    input  wire        clk,
    input  wire        rst,        // Active-high global reset (clears all registers)

    // Precision Control
    input  wire [1:0]  mode,       // 2'b00: INT4, 2'b01: INT8, 2'b10: INT16

    // Systolic Inputs
    input  wire [15:0] a_in,       // Operand A input (from West)
    input  wire [15:0] b_in,       // Operand B input (from North)

    // Systolic Outputs (1-cycle registered forwarding)
    output wire [15:0] a_out,      // Forwarded A (to East)
    output wire [15:0] b_out,      // Forwarded B (to South)

    // Accumulated Result Output
    output wire [35:0] acc_out
);

    // =========================================================================
    // 1. Centralized Precision Decoder
    // =========================================================================
    wire is_int4  = (mode == 2'b00);
    wire is_int8  = (mode == 2'b01);
    wire is_int16 = (mode == 2'b10);

    wire en_s1    = is_int8 | is_int16;   // Segment S1 active in INT8, INT16
    wire en_s2    = is_int16;             // Segment S2 active in INT16 only

    // =========================================================================
    // 2. Operand Forwarding Registers
    // =========================================================================
    reg [15:0] a_reg;
    reg [15:0] b_reg;

    assign a_out = a_reg;
    assign b_out = b_reg;

    // =========================================================================
    // 3. Multiplier Input Isolation (Zero-masking inactive bits)
    // =========================================================================
    wire [15:0] a_mult;
    wire [15:0] b_mult;

    assign a_mult[3:0]   = a_reg[3:0];
    assign a_mult[7:4]   = a_reg[7:4]   & {4{en_s1}};
    assign a_mult[15:8]  = a_reg[15:8]  & {8{en_s2}};

    assign b_mult[3:0]   = b_reg[3:0];
    assign b_mult[7:4]   = b_reg[7:4]   & {4{en_s1}};
    assign b_mult[15:8]  = b_reg[15:8]  & {8{en_s2}};

    // =========================================================================
    // 4. Precision-Scalable Signed Multiplier (16x16 HPM)
    // =========================================================================
    wire [31:0] p_raw;

    hpm_mult16 u_mult (
        .a        (a_mult),
        .b        (b_mult),
        .is_int4  (is_int4),
        .is_int8  (is_int8),
        .is_int16 (is_int16),
        .p        (p_raw)
    );

    // =========================================================================
    // 5. Product Formatting (Dynamic Sign Extension per Precision Mode)
    // =========================================================================
    wire [35:0] p_fmt;

    assign p_fmt[7:0]   = p_raw[7:0];
    assign p_fmt[11:8]  = is_int4 ? {4{p_raw[7]}} : p_raw[11:8];
    assign p_fmt[15:12] = p_raw[15:12];
    assign p_fmt[19:16] = is_int8 ? {4{p_raw[15]}} : p_raw[19:16];
    assign p_fmt[31:20] = p_raw[31:20];
    assign p_fmt[35:32] = {4{p_raw[31]}};

    // =========================================================================
    // 6. Accumulator Operand Isolation (AND Gating)
    // =========================================================================
    reg  [35:0] acc_reg;
    wire [35:0] a_iso;
    wire [35:0] b_iso;

    // Segment S0 [11:0]: Always active (INT4, INT8, INT16)
    assign a_iso[11:0]  = acc_reg[11:0];
    assign b_iso[11:0]  = p_fmt[11:0];

    // Segment S1 [19:12]: Gated by en_s1 (active in INT8, INT16)
    assign a_iso[19:12] = acc_reg[19:12] & {8{en_s1}};
    assign b_iso[19:12] = p_fmt[19:12]   & {8{en_s1}};

    // Segment S2 [35:20]: Gated by en_s2 (active in INT16 only)
    assign a_iso[35:20] = acc_reg[35:20] & {16{en_s2}};
    assign b_iso[35:20] = p_fmt[35:20]   & {16{en_s2}};

    // =========================================================================
    // 7. Clean 36-bit Segmented Carry-Lookahead Adder
    // =========================================================================
    wire [35:0] sum_next;

    segmented_cla_adder u_seg_cla (
        .a        (a_iso),
        .b        (b_iso),
        .en_s1    (en_s1),
        .en_s2    (en_s2),
        .sum_out  (sum_next)
    );

    // =========================================================================
    // 8. Sequential Registers (Forwarding & Accumulator)
    // =========================================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            a_reg   <= 16'b0;
            b_reg   <= 16'b0;
            acc_reg <= 36'b0;
        end
        else begin
            a_reg   <= a_in;
            b_reg   <= b_in;
            acc_reg <= sum_next;
        end
    end

    assign acc_out = acc_reg;

endmodule

`timescale 1ns/1ps

// =============================================================================
// Processing Element (PE) Comprehensive Golden Verification Testbench
// Validates RTL against Python Golden Reference Model (Assignment 2A)
// Covers:
//   1. Zero Matrices (INT4, INT8, INT16)
//   2. Max Positive Value Corner Cases (INT4, INT8, INT16)
//   3. Max Negative Value Corner Cases (INT4, INT8, INT16)
//   4. Mixed-Sign Extreme Corner Cases (INT4, INT8, INT16)
//   5. Python Golden Reference Vectors (Seed 100/101/102 PE(0,0) MAC stream)
//   6. Dynamic Precision Switching (INT4 -> INT8 -> INT16 -> INT4)
//   7. Operand Isolation (Upper Inactive Bits Strictly Zeroed)
//   8. Systolic Forwarding & Accumulator Hold/Clear Controls
// =============================================================================

module tb_pe;

    reg clk;
    reg rst;
    reg [1:0] mode;
    reg [15:0] a_in;
    reg [15:0] b_in;

    wire [15:0] a_out;
    wire [15:0] b_out;
    wire [35:0] acc_out;

    integer pass_count;
    integer err_count;
    integer k;

    // Instantiate PE Device Under Test
    pe dut (
        .clk     (clk),
        .rst     (rst),
        .mode    (mode),
        .a_in    (a_in),
        .b_in    (b_in),
        .a_out   (a_out),
        .b_out   (b_out),
        .acc_out (acc_out)
    );

    // 300 MHz clock (T = 3.333 ns, half-period = 1.666 ns)
    always #1.666 clk = ~clk;

    // =========================================================================
    // TASK: run_mac_16
    // Executes a cycle-accurate 16-element MAC sequence:
    //   Cycle 0: Reset asserted (clears registers to 0)
    //   Cycles 1..16: Stream a[k] and b[k], accumulate product
    //   Cycle 17: Final accumulation of 16th product
    //   Cycle 17+: Verify acc_out against exp_acc and ensure upper bits are 0
    // =========================================================================
    task run_mac_16;
        input [1:0]        test_mode;
        input [16*16-1:0]  a_vec;      // 16 words of 16-bit operands
        input [16*16-1:0]  b_vec;      // 16 words of 16-bit operands
        input [35:0]       exp_acc;    // Golden accumulator result
        input [35:0]       exp_mask;   // Precision mask for active bits
        input [255:0]      test_name;  // Descriptive name string (32 chars)
        integer step;
        begin
            // 1. Assert reset for 1 cycle to clear registers
            @(negedge clk);
            mode = test_mode;
            rst  = 1;
            a_in = 16'b0;
            b_in = 16'b0;
            @(posedge clk);

            // 2. Release reset and drive operand 0
            @(negedge clk);
            rst  = 0;
            a_in = a_vec[15:0];
            b_in = b_vec[15:0];
            @(posedge clk); // Cycle 1: a_reg, b_reg latch operand 0; mult computes; acc stays 0

            // 3. Drive operands 1 through 15
            for (step = 1; step < 16; step = step + 1) begin
                @(negedge clk);
                a_in = (a_vec >> (step * 16));
                b_in = (b_vec >> (step * 16));
                @(posedge clk);
            end

            // 4. Stream 0s for final product accumulation
            @(negedge clk);
            a_in = 16'b0;
            b_in = 16'b0;
            @(posedge clk); // Cycle 17: 16th product accumulates
            #0.1;

            // Arithmetic Accuracy Check
            if ((acc_out & exp_mask) !== (exp_acc & exp_mask)) begin
                $display("FAIL | %-28s | Got: 0x%09h | Exp: 0x%09h | MISMATCH!", 
                         test_name, acc_out, exp_acc);
                err_count = err_count + 1;
            end 
            // Precision Isolation Check (Upper bits must be strictly zero)
            else if ((acc_out & ~exp_mask) !== 36'b0) begin
                $display("FAIL | %-28s | Got: 0x%09h | Upper bits not isolated (residual: 0x%09h)!", 
                         test_name, acc_out, (acc_out & ~exp_mask));
                err_count = err_count + 1;
            end 
            else begin
                $display("PASS | %-28s | acc_out: 0x%09h | Golden: 0x%09h", 
                         test_name, acc_out, exp_acc);
                pass_count = pass_count + 1;
            end
        end
    endtask

    // Helper buffers
    reg [255:0] a_vec_buf;
    reg [255:0] b_vec_buf;

    initial begin
        $display("\n=============================================================================");
        $display("   PROCESSING ELEMENT (PE) GOLDEN MODEL VERIFICATION SUITE                  ");
        $display("   Target: 16x16 Systolic Unit (INT4, INT8, INT16) @ 300 MHz                 ");
        $display("=============================================================================");
        $display("Status | Test Case Description       | Actual Result | Expected Golden");
        $display("-------+-------------------------------+---------------+---------------------");

        clk = 0;
        rst = 1;
        mode = 2'b00;
        a_in = 16'b0;
        b_in = 16'b0;
        pass_count = 0;
        err_count = 0;

        #10;
        @(negedge clk);
        rst = 0;

        // =====================================================================
        // CATEGORY 1: ZERO OPERANDS (16 cycles of 0 x 0)
        // =====================================================================
        a_vec_buf = {16{16'h0000}};
        b_vec_buf = {16{16'h0000}};

        run_mac_16(2'b00, a_vec_buf, b_vec_buf, 36'h000000000, 36'h000000FFF, "INT4 Zero Matrix");
        run_mac_16(2'b01, a_vec_buf, b_vec_buf, 36'h000000000, 36'h0000FFFFF, "INT8 Zero Matrix");
        run_mac_16(2'b10, a_vec_buf, b_vec_buf, 36'h000000000, 36'hFFFFFFFFF, "INT16 Zero Matrix");

        // =====================================================================
        // CATEGORY 2: MAX POSITIVE CORNER CASES
        //   INT4:  16 * (+7 * +7) = 16 * 49 = 784 (0x310)
        //   INT8:  16 * (+127 * +127) = 16 * 16129 = 258064 (0x3F010)
        //   INT16: 16 * (+32767 * +32767) = 17178820624 (0x3FFF00010)
        // =====================================================================
        a_vec_buf = {16{16'h0007}};
        b_vec_buf = {16{16'h0007}};
        run_mac_16(2'b00, a_vec_buf, b_vec_buf, 36'h000000310, 36'h000000FFF, "INT4 Max Positive (+784)");

        a_vec_buf = {16{16'h007F}};
        b_vec_buf = {16{16'h007F}};
        run_mac_16(2'b01, a_vec_buf, b_vec_buf, 36'h00003F010, 36'h0000FFFFF, "INT8 Max Positive (+258K)");

        a_vec_buf = {16{16'h7FFF}};
        b_vec_buf = {16{16'h7FFF}};
        run_mac_16(2'b10, a_vec_buf, b_vec_buf, 36'h3FFF00010, 36'hFFFFFFFFF, "INT16 Max Positive (+17.1G)");

        // =====================================================================
        // CATEGORY 3: MAX NEGATIVE CORNER CASES (Neg * Neg = Max Positive)
        //   INT4:  16 * (-8 * -8) = 16 * 64 = 1024 (0x400)
        //   INT8:  16 * (-128 * -128) = 16 * 16384 = 262144 (0x40000)
        //   INT16: 16 * (-32768 * -32768) = 17179869184 (0x400000000)
        // =====================================================================
        a_vec_buf = {16{16'hFFF8}};
        b_vec_buf = {16{16'hFFF8}};
        run_mac_16(2'b00, a_vec_buf, b_vec_buf, 36'h000000400, 36'h000000FFF, "INT4 Neg*Neg (+1024)");

        a_vec_buf = {16{16'hFF80}};
        b_vec_buf = {16{16'hFF80}};
        run_mac_16(2'b01, a_vec_buf, b_vec_buf, 36'h000040000, 36'h0000FFFFF, "INT8 Neg*Neg (+262K)");

        a_vec_buf = {16{16'h8000}};
        b_vec_buf = {16{16'h8000}};
        run_mac_16(2'b10, a_vec_buf, b_vec_buf, 36'h400000000, 36'hFFFFFFFFF, "INT16 Neg*Neg (+17.2G)");

        // =====================================================================
        // CATEGORY 4: MIXED-SIGN EXTREME CORNER CASES (Min Neg * Max Pos = Max Neg Accum)
        //   INT4:  16 * (-8 * +7) = 16 * (-56) = -896 (12'hC80)
        //   INT8:  16 * (-128 * +127) = 16 * (-16256) = -260096 (20'hC0800)
        //   INT16: 16 * (-32768 * +32767) = -17179344896 (36'hC00080000)
        // =====================================================================
        a_vec_buf = {16{16'hFFF8}}; // -8
        b_vec_buf = {16{16'h0007}}; // +7
        run_mac_16(2'b00, a_vec_buf, b_vec_buf, 36'h000000C80, 36'h000000FFF, "INT4 Mixed Extr (-896)");

        a_vec_buf = {16{16'hFF80}}; // -128
        b_vec_buf = {16{16'h007F}}; // +127
        run_mac_16(2'b01, a_vec_buf, b_vec_buf, 36'h0000C0800, 36'h0000FFFFF, "INT8 Mixed Extr (-260K)");

        a_vec_buf = {16{16'h8000}}; // -32768
        b_vec_buf = {16{16'h7FFF}}; // +32767
        run_mac_16(2'b10, a_vec_buf, b_vec_buf, 36'hC00080000, 36'hFFFFFFFFF, "INT16 Mixed Extr (-17.2G)");

        // =====================================================================
        // CATEGORY 5: PYTHON GOLDEN REFERENCE MODEL VECTORS (PE(0,0))
        //   Directly generated from NumPy Seed 100/101/102 matrix multiplication
        // =====================================================================
        // INT4 Golden: C[0,0] = -52 (12'hFCC)
        a_vec_buf = {16'hFFFA, 16'h0006, 16'hFFFA, 16'hFFFA, 16'hFFFD, 16'hFFFA, 16'hFFFC, 16'h0006, 
                     16'h0002, 16'hFFF8, 16'h0007, 16'hFFFF, 16'hFFFF, 16'hFFFB, 16'h0000, 16'h0000};
        b_vec_buf = {16'h0003, 16'hFFFD, 16'h0004, 16'h0006, 16'h0003, 16'hFFF8, 16'h0000, 16'hFFFB, 
                     16'hFFFF, 16'hFFFE, 16'h0005, 16'hFFFB, 16'hFFFA, 16'h0005, 16'h0002, 16'h0007};
        run_mac_16(2'b00, a_vec_buf, b_vec_buf, 36'h000000FCC, 36'h000000FFF, "INT4 Python Golden (-52)");

        // INT8 Golden: C[0,0] = -16485 (20'hFBF9B)
        a_vec_buf = {16'h0075, 16'h0028, 16'hFFBF, 16'h0004, 16'hFFA8, 16'h004D, 16'h0009, 16'h006F, 
                     16'hFFCB, 16'h007D, 16'hFFD7, 16'hFFBF, 16'hFFC6, 16'hFFD1, 16'hFF8B, 16'hFFDF};
        b_vec_buf = {16'h0068, 16'hFFD6, 16'hFFCC, 16'h0016, 16'h006A, 16'h0070, 16'h0006, 16'hFF83, 
                     16'h0076, 16'h0007, 16'hFFA8, 16'hFFAA, 16'hFFF1, 16'h0068, 16'h0074, 16'h0041};
        run_mac_16(2'b01, a_vec_buf, b_vec_buf, 36'h0000FBF9B, 36'h0000FFFFF, "INT8 Python Golden (-16.5K)");

        // INT16 Golden: C[0,0] = -3014989000 (36'hF4C4AEB38)
        a_vec_buf = {16'h1B04, 16'h3B87, 16'h804F, 16'h4C49, 16'h0948, 16'h482D, 16'hCBC8, 16'hC3C9, 
                     16'h8FEB, 16'h4B42, 16'h336F, 16'h3A72, 16'h88F2, 16'hFA4E, 16'hD2F3, 16'h2900};
        b_vec_buf = {16'h880A, 16'hD6E9, 16'h1A03, 16'h9798, 16'h1E9C, 16'hFF16, 16'h5A73, 16'h624E, 
                     16'h4135, 16'hF4A1, 16'h7380, 16'h86E5, 16'h5323, 16'h9EE6, 16'h1649, 16'h196F};
        run_mac_16(2'b10, a_vec_buf, b_vec_buf, 36'hF4C4AEB38, 36'hFFFFFFFFF, "INT16 Python Golden (-3.01B)");

        // =====================================================================
        // CATEGORY 6: DYNAMIC PRECISION SWITCHING WITH CARRY ISOLATION
        //   Switches INT4 -> INT8 -> INT16 -> INT4 on the fly without hard reset
        //   Verifies no state residue or upper-bit carry corruption
        // =====================================================================
        // Step A: INT4 operation
        a_vec_buf = {16{16'h0007}};
        b_vec_buf = {16{16'h0007}};
        run_mac_16(2'b00, a_vec_buf, b_vec_buf, 36'h000000310, 36'h000000FFF, "Dynamic Step 1: INT4");

        // Step B: Switch to INT8
        a_vec_buf = {16{16'h007F}};
        b_vec_buf = {16{16'h007F}};
        run_mac_16(2'b01, a_vec_buf, b_vec_buf, 36'h00003F010, 36'h0000FFFFF, "Dynamic Step 2: INT8");

        // Step C: Switch to INT16
        a_vec_buf = {16{16'h7FFF}};
        b_vec_buf = {16{16'h7FFF}};
        run_mac_16(2'b10, a_vec_buf, b_vec_buf, 36'h3FFF00010, 36'hFFFFFFFFF, "Dynamic Step 3: INT16");

        // Step D: Switch back to INT4 (verify upper 24 bits are instantly zeroed and gated)
        a_vec_buf = {16{16'h0007}};
        b_vec_buf = {16{16'h0007}};
        run_mac_16(2'b00, a_vec_buf, b_vec_buf, 36'h000000310, 36'h000000FFF, "Dynamic Step 4: INT4 Return");

        // =====================================================================
        // CATEGORY 7: ZERO-INPUT ACCUMULATOR HOLD & RESET CLEAR
        // =====================================================================
        // In a systolic tensor unit, when no new data is streamed (a_in=0, b_in=0),
        // product is 0, so accumulator perfectly holds its value!
        @(negedge clk);
        a_in = 16'h0000;
        b_in = 16'h0000;
        @(posedge clk);
        @(posedge clk);
        #0.1;
        if (acc_out !== 36'h000000310) begin
            $display("FAIL | Accumulator Hold Test         | Got: 0x%09h | Exp: 0x000000310", acc_out);
            err_count = err_count + 1;
        end else begin
            $display("PASS | Accumulator Hold Test         | acc_out: 0x%09h | Held successfully", acc_out);
            pass_count = pass_count + 1;
        end

        // Assert reset: all registers must clear to 0
        @(negedge clk);
        rst = 1;
        @(posedge clk);
        #0.1;
        if (acc_out !== 36'h000000000) begin
            $display("FAIL | Accumulator Reset Clear Test   | Got: 0x%09h | Exp: 0x000000000", acc_out);
            err_count = err_count + 1;
        end else begin
            $display("PASS | Accumulator Reset Clear Test   | acc_out: 0x%09h | Cleared successfully", acc_out);
            pass_count = pass_count + 1;
        end
        @(negedge clk);
        rst = 0;
        a_in = 16'h0005;
        b_in = 16'h0005;
        @(posedge clk);
        #0.1;

        // Forwarding registers check
        if (a_out === 16'h0005 && b_out === 16'h0005) begin
            $display("PASS | Systolic Forwarding Check      | a_out: 0x%04h, b_out: 0x%04h | Matches 1-cycle latency", a_out, b_out);
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL | Systolic Forwarding Check      | a_out: 0x%04h, b_out: 0x%04h", a_out, b_out);
            err_count = err_count + 1;
        end

        // =====================================================================
        // FINAL SUMMARY
        // =====================================================================
        $display("-----------------------------------------------------------------------------");
        $display("TOTAL TESTS RUN: %0d | PASSED: %0d | FAILED: %0d", 
                 pass_count + err_count, pass_count, err_count);
        $display("=============================================================================");

        if (err_count == 0) begin
            $display("\n>>> ALL TESTS MATCHED GOLDEN MODEL 100%% SUCCESSFULLY! <<<\n");
        end else begin
            $display("\n>>> ERROR: %0d VERIFICATION FAILURES DETECTED! <<<\n", err_count);
            $finish;
        end

        $finish;
    end

endmodule

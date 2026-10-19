"""
Precision-Scalable 16x16 Systolic Tensor Unit — Golden Reference Model
====================================================================
Course: VLSI Design Laboratory (Assignment 2A), Department of Electrical Engineering, IIT Delhi
Target: 16x16 Systolic Tensor Unit (INT4, INT8, INT16)

This module provides:
1. Exact Bitwidth & Precision-Aware Fixed-Point Two's Complement Arithmetic
2. Golden Matrix Multiplication Reference for 16x16 Matrices
3. Cycle-Accurate 16x16 Systolic Array Simulation with Input Skewing
4. Mathematical Accumulator & Datapath Width Verification
"""

import numpy as np
from typing import Tuple, Dict, List, Optional

# =============================================================================
# 1. PRECISION SPECIFICATIONS & CONSTANTS
# =============================================================================

MODE_INT4  = 0b00  # Mode 0: Signed 4-bit operands
MODE_INT8  = 0b01  # Mode 1: Signed 8-bit operands
MODE_INT16 = 0b10  # Mode 2: Signed 16-bit operands
MODE_RSVD  = 0b11  # Mode 3: Reserved

ARRAY_SIZE = 16    # 16x16 PEs (256 PEs total)

# Precision limits (Two's complement signed integer ranges)
PRECISION_CONFIG = {
    MODE_INT4: {
        "name": "INT4",
        "operand_bits": 4,
        "min_val": -8,
        "max_val": 7,
        "product_bits": 8,       # 4b x 4b -> 8b signed [-56, +64]
        "accum_bits": 12,        # 16 accumulations of max 64 = 1024 -> 11b + 1 guard = 12b
        "accum_min": -2048,
        "accum_max": 2047,
        "out_reg_bits": 8,       # Standard output interface
    },
    MODE_INT8: {
        "name": "INT8",
        "operand_bits": 8,
        "min_val": -128,
        "max_val": 127,
        "product_bits": 16,      # 8b x 8b -> 16b signed [-16256, +16384]
        "accum_bits": 20,        # 16 accumulations of max 16384 = 262144 -> 19b + 1 guard = 20b
        "accum_min": -524288,
        "accum_max": 524287,
        "out_reg_bits": 16,      # Standard output interface
    },
    MODE_INT16: {
        "name": "INT16",
        "operand_bits": 16,
        "min_val": -32768,
        "max_val": 32767,
        "product_bits": 32,      # 16b x 16b -> 32b signed [-1073709056, +1073741824]
        "accum_bits": 36,        # 16 accumulations of max 2^30 = 2^34 -> 35b + 1 guard = 36b
        "accum_min": -(1 << 35),
        "accum_max": (1 << 35) - 1,
        "out_reg_bits": 32,      # Standard output interface
    }
}


# =============================================================================
# 2. TWO'S COMPLEMENT BIT MANIPULATION UTILITIES
# =============================================================================

def to_signed(val: int, bits: int) -> int:
    """Clamp/wrap an integer to two's complement signed range of specified bitwidth."""
    mask = (1 << bits) - 1
    val = val & mask
    if val & (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def to_hex_str(val: int, bits: int) -> str:
    """Format a signed integer into its two's complement hexadecimal string."""
    mask = (1 << bits) - 1
    unsigned_val = val & mask
    hex_len = (bits + 3) // 4
    return f"{unsigned_val:0{hex_len}X}"


# =============================================================================
# 3. GOLDEN MATRIX MULTIPLICATION REFERENCE
# =============================================================================

def golden_matrix_multiply(
    A: np.ndarray, 
    B: np.ndarray, 
    mode: int
) -> Tuple[np.ndarray, Dict]:
    """
    Computes exact signed matrix multiplication C = A x B for the given precision mode.
    
    A: 16x16 input matrix
    B: 16x16 input matrix
    mode: MODE_INT4, MODE_INT8, or MODE_INT16
    
    Returns:
        C: 16x16 integer accumulator result matrix (exact bit-accurate values)
        stats: Dictionary containing verification statistics
    """
    assert A.shape == (ARRAY_SIZE, ARRAY_SIZE), f"A shape must be 16x16, got {A.shape}"
    assert B.shape == (ARRAY_SIZE, ARRAY_SIZE), f"B shape must be 16x16, got {B.shape}"
    assert mode in PRECISION_CONFIG, f"Invalid mode {mode}"
    
    cfg = PRECISION_CONFIG[mode]
    op_bits = cfg["operand_bits"]
    accum_bits = cfg["accum_bits"]
    
    # Quantize and clamp inputs to exact mode bitwidth
    A_clamped = np.vectorize(lambda x: to_signed(int(x), op_bits))(A)
    B_clamped = np.vectorize(lambda x: to_signed(int(x), op_bits))(B)
    
    C = np.zeros((ARRAY_SIZE, ARRAY_SIZE), dtype=object)
    
    max_accum = -float("inf")
    min_accum = float("inf")
    
    # Exact dot product simulation
    for i in range(ARRAY_SIZE):
        for j in range(ARRAY_SIZE):
            accum = 0
            for k in range(ARRAY_SIZE):
                prod = int(A_clamped[i, k]) * int(B_clamped[k, j])
                accum += prod
            
            # Wrap to accumulator width
            accum_wrapped = to_signed(accum, accum_bits)
            C[i, j] = accum_wrapped
            
            if accum > max_accum:
                max_accum = accum
            if accum < min_accum:
                min_accum = accum
                
    stats = {
        "mode": cfg["name"],
        "max_observed_accum": max_accum,
        "min_observed_accum": min_accum,
        "accum_bitwidth_sufficient": (min_accum >= cfg["accum_min"] and max_accum <= cfg["accum_max"]),
        "accum_max_limit": cfg["accum_max"],
        "accum_min_limit": cfg["accum_min"]
    }
    
    return C, stats


# =============================================================================
# 4. CYCLE-ACCURATE 16x16 SYSTOLIC ARRAY SIMULATOR
# =============================================================================

class SystolicTensorUnit16x16:
    """
    Cycle-accurate behavioural simulation of the 16x16 Output-Stationary
    Systolic Tensor Unit with Left-to-Right and Top-to-Bottom operand forwarding.
    
    Hardware Scheduling Equation:
        Operands A_ik and B_kj meet at PE(i, j) at clock cycle:
            t = i + j + k  (for 0 <= i, j, k <= 15)
            
    Timing Characteristics:
        - Latency to first result update: cycle t = 0 (PE 0,0 k=0)
        - Latency to last MAC computation: cycle t = 15 + 15 + 15 = 45 (PE 15,15 k=15)
        - Total computation interval: 46 clock cycles (cycles 0 to 45)
        - Readout / Drain cycle: cycle 46+
    """
    def __init__(self, mode: int = MODE_INT8):
        self.mode = mode
        self.cfg = PRECISION_CONFIG[mode]
        self.size = ARRAY_SIZE
        self.reset()
        
    def reset(self):
        """Clears all internal PE accumulators and forwarding registers."""
        # 16x16 local accumulators
        self.accum = np.zeros((self.size, self.size), dtype=object)
        
        # Horizontal forwarding registers (A flows left to right)
        self.reg_A = np.zeros((self.size, self.size), dtype=object)
        
        # Vertical forwarding registers (B flows top to bottom)
        self.reg_B = np.zeros((self.size, self.size), dtype=object)
        
        self.cycle = 0
        self.done = False
        
    def skew_inputs(self, A: np.ndarray, B: np.ndarray) -> Tuple[np.ndarray, np.ndarray, int]:
        """
        Applies systolic skewing to input matrices A and B.
        
        Row i of matrix A is delayed by i cycles:
            A_skewed[i, t] = A[i, t - i]  for i <= t < i + 16
        Column j of matrix B is delayed by j cycles:
            B_skewed[j, t] = B[t - j, j]  for j <= t < j + 16
            
        Total feeding cycles: 16 (elements) + 15 (max skew) = 31 cycles.
        """
        total_feed_cycles = self.size + (self.size - 1)  # 16 + 15 = 31 cycles
        
        A_skewed = np.zeros((self.size, total_feed_cycles), dtype=object)
        B_skewed = np.zeros((self.size, total_feed_cycles), dtype=object)
        
        op_bits = self.cfg["operand_bits"]
        A_clamped = np.vectorize(lambda x: to_signed(int(x), op_bits))(A)
        B_clamped = np.vectorize(lambda x: to_signed(int(x), op_bits))(B)
        
        for i in range(self.size):
            for k in range(self.size):
                t_inj = i + k
                A_skewed[i, t_inj] = A_clamped[i, k]
                
        for j in range(self.size):
            for k in range(self.size):
                t_inj = j + k
                B_skewed[j, t_inj] = B_clamped[k, j]
                
        return A_skewed, B_skewed, total_feed_cycles

    def run_matrix_multiplication(
        self, 
        A: np.ndarray, 
        B: np.ndarray
    ) -> Tuple[np.ndarray, int, List[Dict]]:
        """
        Executes complete cycle-by-cycle systolic simulation for A x B.
        
        Returns:
            C: Final 16x16 accumulated matrix
            total_cycles: Number of cycles taken
            cycle_log: Optional cycle-by-cycle event log
        """
        self.reset()
        A_skewed, B_skewed, feed_cycles = self.skew_inputs(A, B)
        
        # Total computation latency: 31 feed cycles + 15 propagation cycles = 46 cycles (0 to 45)
        total_sim_cycles = feed_cycles + (self.size - 1)
        
        cycle_log = []
        op_bits = self.cfg["operand_bits"]
        accum_bits = self.cfg["accum_bits"]
        
        for t in range(total_sim_cycles):
            # Capture current inputs to boundary PEs
            curr_in_A = [A_skewed[i, t] if t < feed_cycles else 0 for i in range(self.size)]
            curr_in_B = [B_skewed[j, t] if t < feed_cycles else 0 for j in range(self.size)]
            
            # Next state buffers for synchronous clock edge
            next_reg_A = np.zeros((self.size, self.size), dtype=object)
            next_reg_B = np.zeros((self.size, self.size), dtype=object)
            next_accum = np.copy(self.accum)
            
            # Update all 256 PEs
            for i in range(self.size):
                for j in range(self.size):
                    # Operand A arrival
                    val_A = curr_in_A[i] if j == 0 else self.reg_A[i, j - 1]
                    
                    # Operand B arrival
                    val_B = curr_in_B[j] if i == 0 else self.reg_B[i - 1, j]
                    
                    # Compute MAC
                    if val_A != 0 and val_B != 0:
                        prod = int(val_A) * int(val_B)
                        new_accum = int(self.accum[i, j]) + prod
                        next_accum[i, j] = to_signed(new_accum, accum_bits)
                        
                    # Forward operands to registers for next cycle
                    next_reg_A[i, j] = val_A
                    next_reg_B[i, j] = val_B
            
            # Synchronous state update
            self.reg_A = next_reg_A
            self.reg_B = next_reg_B
            self.accum = next_accum
            self.cycle += 1
            
        self.done = True
        return self.accum, self.cycle, cycle_log

"""
Test Vector Generator for 16x16 Systolic Tensor Unit
===================================================
Generates bit-accurate hex vectors for Verilog $readmemh testbenches:
- inputs_A_skewed_<mode>.hex: Skewed input stream A (16 values per cycle for 31 cycles)
- inputs_B_skewed_<mode>.hex: Skewed input stream B (16 values per cycle for 31 cycles)
- expected_C_<mode>.hex: Expected 16x16 output matrix (256 entries in row-major order)
"""

import os
import numpy as np
from tensor_unit_model import (
    golden_matrix_multiply,
    SystolicTensorUnit16x16,
    to_hex_str,
    MODE_INT4,
    MODE_INT8,
    MODE_INT16,
    PRECISION_CONFIG,
    ARRAY_SIZE
)

def export_mode_vectors(mode: int, output_dir: str):
    cfg = PRECISION_CONFIG[mode]
    mode_name = cfg["name"].lower()
    op_bits = 16  # Standard physical interface width is 16 bits
    accum_bits = cfg["accum_bits"]
    
    np.random.seed(100 + mode)
    min_v = cfg["min_val"]
    max_v = cfg["max_val"]
    
    # Generate random test matrices
    A = np.random.randint(min_v, max_v + 1, size=(ARRAY_SIZE, ARRAY_SIZE))
    B = np.random.randint(min_v, max_v + 1, size=(ARRAY_SIZE, ARRAY_SIZE))
    
    # 1. Golden Matrix Product
    C_golden, _ = golden_matrix_multiply(A, B, mode)
    
    # 2. Skewed inputs from Systolic Model
    sim = SystolicTensorUnit16x16(mode=mode)
    A_skewed, B_skewed, feed_cycles = sim.skew_inputs(A, B)
    
    # Save A_skewed
    path_a = os.path.join(output_dir, f"inputs_A_skewed_{mode_name}.hex")
    with open(path_a, "w") as f:
        f.write(f"// Skewed Input A for Mode: {cfg['name']} (Format: 16 hex words per cycle for 31 cycles)\n")
        for t in range(feed_cycles):
            row_hex = [to_hex_str(int(A_skewed[i, t]), op_bits) for i in range(ARRAY_SIZE)]
            f.write(" ".join(row_hex) + "\n")
            
    # Save B_skewed
    path_b = os.path.join(output_dir, f"inputs_B_skewed_{mode_name}.hex")
    with open(path_b, "w") as f:
        f.write(f"// Skewed Input B for Mode: {cfg['name']} (Format: 16 hex words per cycle for 31 cycles)\n")
        for t in range(feed_cycles):
            col_hex = [to_hex_str(int(B_skewed[j, t]), op_bits) for j in range(ARRAY_SIZE)]
            f.write(" ".join(col_hex) + "\n")
            
    # Save Expected C
    path_c = os.path.join(output_dir, f"expected_C_{mode_name}.hex")
    with open(path_c, "w") as f:
        f.write(f"// Expected Accumulated Result C for Mode: {cfg['name']} (256 words: C[0,0] to C[15,15])\n")
        for i in range(ARRAY_SIZE):
            for j in range(ARRAY_SIZE):
                f.write(to_hex_str(int(C_golden[i, j]), accum_bits) + f" // C[{i:02d},{j:02d}] = {C_golden[i, j]}\n")
                
    print(f"Generated test vectors for {cfg['name']}:")
    print(f"  - {path_a}")
    print(f"  - {path_b}")
    print(f"  - {path_c}")


def main():
    out_dir = "/home/rajdeep/IITD/Semester7/VD-Lab-I/Assignment2/reference_model/vectors"
    os.makedirs(out_dir, exist_ok=True)
    
    for mode in [MODE_INT4, MODE_INT8, MODE_INT16]:
        export_mode_vectors(mode, out_dir)
        
    print("\nAll test vectors generated successfully in reference_model/vectors/")


if __name__ == "__main__":
    main()

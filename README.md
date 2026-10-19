# 16×16 Precision-Scalable Systolic Tensor Unit

A power-aware, precision-scalable **16×16 2D Systolic Tensor Processing Unit** supporting runtime-configurable **INT4, INT8, and INT16** matrix multiplication. Designed for high-throughput deep learning acceleration targeting **300 MHz in a 65nm CMOS standard-cell flow**.

**Course:** VLSI Design Laboratory (Assignment 2A) — Department of Electrical Engineering, IIT Delhi  
**Developers:** Rajdeep Vora & Siddharth Chandiramani  

---

## Key Architectural Specifications

* **Array Organization:** $16 \times 16$ 2D mesh of Processing Elements (PEs) with output-stationary accumulation.
* **Precision Modes:**
  * **INT4:** 4-bit weights & inputs $\rightarrow$ 12-bit accumulator ($[-2048, 2047]$)
  * **INT8:** 8-bit weights & inputs $\rightarrow$ 20-bit accumulator ($[-524288, 524287]$)
  * **INT16:** 16-bit weights & inputs $\rightarrow$ 36-bit accumulator ($[-34359738368, 34359738367]$)
* **Target Operating Frequency:** 300 MHz ($T_{\text{clk}} = 3.33\text{ ns}$)
* **Throughput:**
  * INT4: $256 \text{ MACs/cycle} \rightarrow 153.6 \text{ GOPS}$
  * INT8: $256 \text{ MACs/cycle} \rightarrow 153.6 \text{ GOPS}$
  * INT16: $256 \text{ MACs/cycle} \rightarrow 153.6 \text{ GOPS}$
* **Total Latency:** 46 cycles for $16 \times 16$ matrix multiplication ($K = 16$).

---

## Power-Aware Design Techniques

1. **True Integrated Clock Gating (ICG):**
   * Employs Latch-and-AND ICG cells (Samsung US20250077182A1) on input registers and accumulator slices.
   * In **INT4 mode**, upper 12 bits of input registers are clock-gated at the DFF clock pin ($\text{GCLK} = 0$), saving **66.7% dynamic clock power**.
   * In **INT8 mode**, upper 8 bits are clock-gated, saving **50.0% dynamic clock power**.

2. **Precision-Segmented Accumulator with Carry-Kill Boundaries:**
   * 36-bit accumulator divided into $S_0$ (12b), $S_1$ (8b), and $S_2$ (16b) built from $9 \times \text{4-bit CLA}$ blocks.
   * Carry propagation is dynamically forced to `0` at Bit 11 $\rightarrow$ 12 and Bit 19 $\rightarrow$ 20 to prevent cross-precision corruption and isolate inactive bits (NVIDIA US9268528B2).

---

## Repository Structure

```
├── README.md                      # Project documentation and specifications
├── .gitignore                     # Git ignore rules for Python, EDA tools, and temp files
├── reference_model/               # Golden software model & verification suite
│   ├── tensor_unit_model.py       # Bit-accurate and cycle-accurate systolic array simulator
│   ├── run_verification.py        # Automated 24-test verification suite across 8 categories
│   ├── generate_test_vectors.py   # Test vector generator emitting .hex files for RTL TB
│   ├── README.md                  # Reference model usage guide
│   └── vectors/                   # Pre-generated bit-accurate .hex stimulus files
├── photos/                        # Architectural block diagrams and circuit schematics
│   ├── 16bit_input_register_icg_gated_clock.png  # True ICG gated clock diagram
│   ├── 36bit_accumulator_segment_clock_enable.png # Segmented accumulator diagram
│   └── ...
└── rtl/                           # Verilog RTL source files (Week 2 onwards)
```

---

## Running the Golden Reference Model

### 1. Run Full Verification Suite (24 Tests)
```bash
python3 reference_model/run_verification.py
```
*Tests all 8 categories (Zero, Identity, Positive, Negative, Mixed-Sign, Max Positive, Max Negative, Uniform Random) across INT4, INT8, and INT16. Expected output: `24/24 PASSED (100% match, 0 mismatches)`.*

### 2. Generate Verilog Testbench Hex Vectors
```bash
python3 reference_model/generate_test_vectors.py
```
*Generates skewed input streams (`inputs_a.hex`, `inputs_b.hex`) and golden expected matrices (`expected_c.hex`) in `reference_model/vectors/` for `$readmemh` co-simulation.*

---

## Milestone Schedule

* **Week 1:** Architectural specifications, Literature review, Bit-accurate reference model & test vector generation. *(Complete)*
* **Week 2:** Precision-scalable multiplier & accumulator RTL, Mode-select logic, Forwarding registers, Single-PE synthesis.
* **Week 3:** $16 \times 16$ array interconnects, Top-level control FSM, Skewing & output draining logic.
* **Week 4:** Automated self-checking testbenches, Full test suite execution, Initial 65nm synthesis & timing constraints (SDC).
* **Week 5:** Timing closure (300 MHz), Dynamic power extraction (VCD/SAIF), Power savings verification, Final report.

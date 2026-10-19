# Week 1 Deliverables: 16×16 Systolic Tensor Unit Reference Model

**Course:** VLSI Design Laboratory (Assignment 2A)  
**Department of Electrical Engineering, IIT Delhi**  
**Milestone:** Week 1 — Architecture Review & Golden Reference Model  

---

## 1. Overview of Week 1 Deliverables

Per Section 22 of the Assignment 2A specification, Week 1 requires:
1. **Complete PE Specification & Precision-Width Derivation**
2. **Accumulator-Width Calculation** for INT4, INT8, and INT16
3. **Control & Data Interface Definition**
4. **16×16 Systolic Scheduling Equation & Latency Analysis**
5. **Bit-Accurate Behavioural Reference Model in Python**
6. **Automated Verification Suite with 0 Mismatches**
7. **Exportable Test Vectors for Verilog `$readmemh` Testbenches**

---

## 2. Mathematical Accumulator Width Derivation

For a $16 \times 16$ array, each Processing Element $PE_{ij}$ computes a 16-element inner product:
$$C_{ij} = \sum_{k=0}^{15} A_{ik} \cdot B_{kj}$$

### A. INT4 Mode (`mode = 2'b00`)
* **Input Operands:** 4-bit signed integers in range $[-8, +7]$.
* **Worst-Case Product:** $(-8) \times (-8) = +64$ (fits in 8 bits signed $[-56, +64]$).
* **Maximum 16-Element Accumulation:**
  $$\text{Max Positive Accumulation} = 16 \times (+64) = +1024$$
  $$\text{Max Negative Accumulation} = 16 \times (-56) = -896$$
* **Required Width:**
  $$\lceil \log_2(1024 + 1) \rceil + 1 \text{ (sign bit)} = 11 + 1 = \mathbf{12\text{ bits}}$$
* **Accumulator Range:** $[-2048, +2047]$ $\implies$ **12-bit signed accumulator**.

### B. INT8 Mode (`mode = 2'b01`)
* **Input Operands:** 8-bit signed integers in range $[-128, +127]$.
* **Worst-Case Product:** $(-128) \times (-128) = +16384$ (fits in 16 bits signed $[-16256, +16384]$).
* **Maximum 16-Element Accumulation:**
  $$\text{Max Positive Accumulation} = 16 \times (+16384) = +262,144$$
* **Required Width:**
  $$\lceil \log_2(262144 + 1) \rceil + 1 \text{ (sign bit)} = 19 + 1 = \mathbf{20\text{ bits}}$$
* **Accumulator Range:** $[-524,288, +524,287]$ $\implies$ **20-bit signed accumulator**.

### C. INT16 Mode (`mode = 2'b10`)
* **Input Operands:** 16-bit signed integers in range $[-32768, +32767]$.
* **Worst-Case Product:** $(-32768) \times (-32768) = +1,073,741,824 = 2^{30}$ (fits in 32 bits signed).
* **Maximum 16-Element Accumulation:**
  $$\text{Max Positive Accumulation} = 16 \times 2^{30} = 2^{34} = +17,179,869,184$$
* **Required Width:**
  $$34 + 1 \text{ (guard/sign bit)} + 1 = \mathbf{36\text{ bits}}$$
* **Accumulator Range:** $[-2^{35}, +2^{35} - 1]$ $\implies$ **36-bit signed accumulator**.

---

## 3. Segmented Accumulator Design Alignment

Notice how the accumulator widths partition into standard 4-bit nibbles:
* **Segment $S_0$ (Lower):** 12 bits (`[11:0]`) $= 3 \times 4\text{b}$ CLA blocks $\rightarrow$ Active in **INT4, INT8, INT16**.
* **Segment $S_1$ (Middle):** 8 bits (`[19:12]`) $= 2 \times 4\text{b}$ CLA blocks $\rightarrow$ Active in **INT8, INT16** (Gated in INT4).
* **Segment $S_2$ (Upper):** 16 bits (`[35:20]`) $= 4 \times 4\text{b}$ CLA blocks $\rightarrow$ Active in **INT16 only** (Gated in INT4, INT8).

Total width: $12 + 8 + 16 = \mathbf{36\text{ bits}}$ ($9 \times 4\text{b}$ CLA blocks).

---

## 4. Systolic Array Scheduling Equations

Operands propagate across the $16 \times 16$ array:
* **Matrix A:** Propagates horizontally (Left $\rightarrow$ Right).
* **Matrix B:** Propagates vertically (Top $\rightarrow$ Bottom).

### Schedule Equation:
For coordinate $(i, j)$ and inner-product index $k$ ($0 \le i, j, k \le 15$):
$$t_{\text{compute}}(i, j, k) = i + j + k$$

* **Input Injection Schedule:**
  * Element $A_{ik}$ enters Row $i$ at clock cycle: $t_{\text{inj}} = i + k$
  * Element $B_{kj}$ enters Column $j$ at clock cycle: $t_{\text{inj}} = j + k$
* **Array Filling Time:** Cycles $0 \le t \le 15$
* **Useful Computation Interval:** Cycles $0 \le t \le 45$ (Total **46 clock cycles**)
  * First MAC: $PE_{0,0}$ with $k=0$ at cycle $t = 0 + 0 + 0 = \mathbf{0}$.
  * Last MAC: $PE_{15,15}$ with $k=15$ at cycle $t = 15 + 15 + 15 = \mathbf{45}$.
* **Done Assertion:** Cycle 46 (computation complete, results stable for readout).

---

## 5. Top-Level Control Interface Specification

```
                ┌─────────────────────────────────┐
                │   16x16 SYSTOLIC TENSOR UNIT    │
                │                                 │
     clk ───────►                                 │
   reset ───────►                                 │
   start ───────►                                 ├─────► busy
mode[1:0] ───────►                                 ├─────► done
in_valid ───────►                                 │
                │                                 ├─────► out_data [31:0]
   in_A [15:0] ─► 16-element parallel input bus   │
   in_B [15:0] ─► 16-element parallel input bus   │
                └─────────────────────────────────┘
```

| Signal Name | Width | Direction | Function |
| :--- | :---: | :---: | :--- |
| `clk` | 1 | Input | Master clock target (300 MHz nominal, $T = 3.33\text{ ns}$) |
| `reset` | 1 | Input | Synchronous active-high reset |
| `start` | 1 | Input | Initiates a new matrix multiplication run |
| `mode[1:0]` | 2 | Input | Precision selection (`00`: INT4, `01`: INT8, `10`: INT16, `11`: Rsvd) |
| `in_valid` | 1 | Input | Indicates valid skewed operands at boundary ports |
| `in_A[15:0]` | 16 × 16b | Input | 16 parallel horizontal inputs (1 per row) |
| `in_B[15:0]` | 16 × 16b | Input | 16 parallel vertical inputs (1 per column) |
| `busy` | 1 | Output | High from cycle 0 to cycle 45 (computing) |
| `done` | 1 | Output | Pulses high at cycle 46 when all 256 accumulations are valid |

---

## 6. Running the Python Reference Model & Verification

### Running the Full Test Suite:
```bash
python3 reference_model/run_verification.py
```
**Results:** Executes 24 tests across all Section 13 test categories (Zero, Identity, Positive, Negative, Mixed, Max Positive, Max Negative, Random) and reports **100% Zero Mismatches**.

### Generating Verilog `$readmemh` Hex Vectors:
```bash
python3 reference_model/generate_test_vectors.py
```
Generates bit-accurate hex vectors in `reference_model/vectors/`:
* `inputs_A_skewed_<mode>.hex`
* `inputs_B_skewed_<mode>.hex`
* `expected_C_<mode>.hex`

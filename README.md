# Fault-Tolerant Reversible Quantum ALU with Synthesizable Verilog Decoder

A hybrid quantum-classical computing architecture combining a reversible Peres-gate full adder in Qiskit, a 3-qubit quantum error correction (QEC) repetition code, and a cycle-accurate synthesizable Verilog decoder for single-cycle bit-flip repair on FPGA.

---

## System Co-Design Pipeline

\\\	ext
[ Data Inputs: A, B, Cin ] --? [ Reversible Peres ALU ]
                                      ¦
                         [ 3-Qubit Repetition Encoding ]
                                      ¦
                         [ Depolarizing / Bit-Flip Noise ]
                                      ¦
                         [ Stabilizer Check: Z0Z1, Z1Z2 ]
                                      ¦
                                      ?
                           Syndrome Bits [S1, S0]
                                      ¦
                                      ?
                         [ Synthesizable Verilog RTL ]
                                      ¦
                         [ Error-Corrected Logical Sum ]
\\\

---

## Stabilizer Syndrome Decoding Logic

The FPGA co-processor decodes stabilizer measurements (\ Z_1\$ and \ Z_2\$) to detect which physical qubit suffered decoherence without destroying the underlying quantum state:

| Stabilizer Condition | Syndrome \[S1, S0]\ | Fault Location | Classical RTL Decoder Action | Corrected Logical Sum |
| :--- | :--- | :--- | :--- | :--- |
| **No Injected Noise** | \2'b00\ | None | Pass raw measured qubit | Intact |
| **Primary Qubit Error** | \2'b01\ | Qubit 0 (\\$) | Invert corrupted bit (\~raw_sum\) | **Repaired** |
| **Ancilla 1 Error** | \2'b11\ | Ancilla 1 (\\$) | Pass raw measured qubit | Intact |
| **Ancilla 2 Error** | \2'b10\ | Ancilla 2 (\\$) | Pass raw measured qubit | Intact |

---

## Simulation Waveform & Timing

\\\	ext
Time (ns)       0        10        20        30        40        50
clk          ___/???\___/???\___/???\___/???\___/???\___/???\___/???\___
rst_n        ___________/???????????????????????????????????????????????
syndrome     XXXXXXXXXXX(  2'b00  )(  2'b01  )(  2'b11  )XXXXXXXXXXXXX
raw_sum      XXXXXXXXXXX(   1'b0  )(   1'b1  )(   1'b0  )XXXXXXXXXXXXX
                        ?          ?          ?
                        ¦          ¦          +-- Ancilla error (Flag=1, Sum=0)
                        ¦          +------------- Bit-flip repaired (Flag=1, Sum: 1->0)
                        +------------------------ Clean execution (Flag=0, Sum=0)

corrected_sum ____________(   1'b0  )__________(   1'b0  )____________
correction_flg ____________________/?????????????????????\_____________
\\\

---

## Simulation Verification Output

### Quantum Aer Simulator (Python / Qiskit)
\\\	ext
=== QUANTUM FAULT-TOLERANT ALU SIMULATION ===
[Normal (No Noise)]     Inputs (A=1, B=1, Cin=0) -> Measured Raw [Cout,Sum]: 10 | Stabilizer Syndrome (S1,S0): 00
[Bit-Flip on Primary]   Inputs (A=1, B=1, Cin=0) -> Measured Raw [Cout,Sum]: 11 | Stabilizer Syndrome (S1,S0): 01
[Bit-Flip on Ancilla 1] Inputs (A=1, B=1, Cin=0) -> Measured Raw [Cout,Sum]: 10 | Stabilizer Syndrome (S1,S0): 11
[Bit-Flip on Ancilla 2] Inputs (A=1, B=1, Cin=0) -> Measured Raw [Cout,Sum]: 10 | Stabilizer Syndrome (S1,S0): 10
\\\

---

## Execution Instructions

### 1. Run Quantum Stabilizer Simulation
\\\powershell
python quantum\circuit_quantum_alu.py
\\\

### 2. Run Verilog Simulation
Load \lsi/syndrome_decoder.v\ and \lsi/tb_decoder.v\ in Vivado or EDA Playground to generate timing waveforms.

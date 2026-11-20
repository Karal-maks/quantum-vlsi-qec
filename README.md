# Reversible Quantum Full Adder with 3-Qubit Bit-Flip Code and Verilog Syndrome Decoder

A hybrid quantum-classical demo: a reversible Peres-gate full adder in Qiskit,
a 3-qubit repetition code protecting the sum bit against single bit-flip errors,
and a synthesizable Verilog decoder that corrects the sum from the measured syndrome.

## Pipeline

```
[A, B, Cin] -> [Reversible Peres full adder] -> [Sum, Cout]
                         |
        [3-qubit repetition encoding of Sum]
                         |
        [Single bit-flip fault injection (X gate)]
                         |
        [Stabilizer checks: Z0Z1, Z1Z2] -> syndrome {S1, S0}
                         |
        [Verilog syndrome decoder (registered output)]
                         |
                [Corrected Sum]
```

## Syndrome decoding

| Fault location | Syndrome {S1,S0} | Decoder action | error_location |
| :--- | :--- | :--- | :--- |
| None | 2'b00 | Pass raw sum | 2'b00 |
| Qubit 0 (sum qubit) | 2'b01 | Invert raw sum | 2'b01 |
| Qubit 1 (ancilla 1) | 2'b11 | Pass raw sum | 2'b10 |
| Qubit 2 (ancilla 2) | 2'b10 | Pass raw sum | 2'b11 |

## Repository structure

```
quantum/circuit_quantum_alu.py   Qiskit adder, encoding, fault injection, syndrome extraction
vlsi/syndrome_decoder.v          Verilog decoder (async active-low reset, registered outputs)
vlsi/tb_decoder.v                Self-checking testbench (54 checks)
vlsi/qiskit_vectors.mem          Measured Qiskit results replayed in the testbench
docs/waveform.png                Decoder simulation waveform
```

## Run

### Quantum circuit (Qiskit)

```bash
pip install -r requirements.txt
python quantum/circuit_quantum_alu.py                   # demo + 32-case verification
python quantum/circuit_quantum_alu.py --export-vectors  # also regenerate vlsi/qiskit_vectors.mem
```

### Verilog decoder (Icarus Verilog)

```bash
cd vlsi
iverilog -g2012 -Wall -o sim syndrome_decoder.v tb_decoder.v
vvp sim
```

Run it from the `vlsi/` folder so the testbench can find `qiskit_vectors.mem`.
In Vivado or EDA Playground, add `qiskit_vectors.mem` to the project as well.

The testbench checks:

1. **All 16 input combinations** (4 syndromes x raw sum x raw carry), every output, against a reference model.
2. **Asynchronous reset**: outputs clear immediately, between clock edges.
3. **Registered outputs**: inputs reach the outputs only on a clock edge.
4. **Qiskit replay**: the 32 measured results from the quantum simulation are fed to the decoder,
   which must output the true sum and carry of A + B + Cin for every input and fault location.

It prints `ALL TESTS PASSED (54 checks)` or exits with an error.
It catches bugs such as a synchronous reset, a stuck carry, or a wrong correction for one syndrome.

## Results

Qiskit:

```
=== QUANTUM ALU WITH 3-QUBIT BIT-FLIP CODE ===
[Normal (No Noise)] Inputs (A=1, B=1, Cin=0) -> Raw [Cout,Sum]: 10 | Syndrome (S1,S0): 00 | Corrected Sum: 0
[Bit-Flip on Primary] Inputs (A=1, B=1, Cin=0) -> Raw [Cout,Sum]: 11 | Syndrome (S1,S0): 01 | Corrected Sum: 0
[Bit-Flip on Ancilla 1] Inputs (A=1, B=1, Cin=0) -> Raw [Cout,Sum]: 10 | Syndrome (S1,S0): 11 | Corrected Sum: 0
[Bit-Flip on Ancilla 2] Inputs (A=1, B=1, Cin=0) -> Raw [Cout,Sum]: 10 | Syndrome (S1,S0): 10 | Corrected Sum: 0

All 32 cases passed
```

Verilog (Icarus Verilog 12):

```
Part 1: 16 exhaustive cases checked
Part 2: asynchronous reset checked
Part 3: registered outputs checked
Part 4: 32 Qiskit measurements replayed
ALL TESTS PASSED (54 checks)
```

![Decoder waveform](docs/waveform.png)

## Limitations

- Local simulation only (Qiskit Aer); not run on quantum hardware.
- Only the sum qubit is encoded, and only after the adder. Errors inside the adder or on the carry are not protected.
- The code corrects single bit-flip (X) errors only, not phase errors.
- Faults are single deterministic X gates, not a statistical noise model.
- All inputs are computational basis states.- The Qiskit-to-Verilog link uses recorded vectors (`qiskit_vectors.mem`), not a live co-simulation.

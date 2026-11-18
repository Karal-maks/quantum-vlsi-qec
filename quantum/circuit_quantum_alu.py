import numpy as np
from qiskit import QuantumCircuit, QuantumRegister, ClassicalRegister
from qiskit_aer import AerSimulator
from itertools import product

def build_reversible_peres_adder(qc, a, b, cin, cout, s):
    """
    Full adder from two Peres gates. Each Peres gate is a Toffoli followed by a CNOT.
    """
    # Peres gate 1 on (A, B, Cout): Cout = A&B, B = A^B
    qc.ccx(a, b, cout)
    qc.cx(a, b)

    # Peres gate 2 on (Cin, B, Cout): Cout ^= Cin&(A^B), B = A^B^Cin
    qc.ccx(cin, b, cout)
    qc.cx(cin, b)

    # B now holds the sum, so copy it to the Sum qubit
    qc.cx(b, s)

def construct_fault_tolerant_alu(a_val: int, b_val: int, cin_val: int, error_target: int = 1):
    """
    Constructs a Reversible Quantum ALU connected to a 3-qubit Error Correction code.
    error_target: 0 = No error, 1 = Error on qubit 0, 2 = Error on qubit 1, 3 = Error on qubit 2
    """
    q_data = QuantumRegister(5, name="data")       # [A, B, Cin, Cout, Sum]
    q_code = QuantumRegister(2, name="anc_code")   # Encodes logical sum into 3-qubit state
    q_synd = QuantumRegister(2, name="syndrome")   # Stabilizer syndrome measurement ancillas
    c_synd = ClassicalRegister(2, name="s_out")
    c_data = ClassicalRegister(2, name="res_out")  # [Sum_Logical, Cout]

    qc = QuantumCircuit(q_data, q_code, q_synd, c_synd, c_data)

    # 1. State Preparation
    if a_val:   qc.x(q_data[0])
    if b_val:   qc.x(q_data[1])
    if cin_val: qc.x(q_data[2])

    # 2. Reversible Full Adder
    build_reversible_peres_adder(qc, q_data[0], q_data[1], q_data[2], q_data[3], q_data[4])
    qc.barrier()

    # 3. QEC Encoding: Entangle Sum bit (q_data[4]) across q_code[0] and q_code[1]
    # Logical state |psi> = alpha|000> + beta|111>
    qc.cx(q_data[4], q_code[0])
    qc.cx(q_data[4], q_code[1])
    qc.barrier()

    # 4. Physical Noise / Hardware Fault Injection
    if error_target == 1:
        qc.x(q_data[4])  # Bit-flip error on primary sum qubit
    elif error_target == 2:
        qc.x(q_code[0])  # Bit-flip error on ancilla 1
    elif error_target == 3:
        qc.x(q_code[1])  # Bit-flip error on ancilla 2

    qc.barrier()

    # 5. Extract Stabilizer Generators: Z0*Z1 and Z1*Z2
    qc.cx(q_data[4], q_synd[0])
    qc.cx(q_code[0], q_synd[0])

    qc.cx(q_code[0], q_synd[1])
    qc.cx(q_code[1], q_synd[1])

    # 6. Readout: Syndromes go to FPGA decoder, Data goes to verification bus
    qc.measure(q_synd[0], c_synd[0])
    qc.measure(q_synd[1], c_synd[1])
    qc.measure(q_data[4], c_data[0])
    qc.measure(q_data[3], c_data[1])

    return qc

def run_case(sim, a, b, cin, err, shots=1):
    """Run one circuit. Returns (cout, raw_sum, syndrome_string)."""
    qc = construct_fault_tolerant_alu(a, b, cin, error_target=err)
    counts = sim.run(qc, shots=shots).result().get_counts()
    outcome = max(counts, key=counts.get)
    res_raw, syndrome = outcome.split(" ")   # "Cout Sum", "S1 S0"
    return int(res_raw[0]), int(res_raw[1]), syndrome


def decode(raw_sum, syndrome):
    """Python model of vlsi/syndrome_decoder.v: only syndrome 01 flips the sum."""
    return 1 - raw_sum if syndrome == "01" else raw_sum


EXPECTED_SYNDROME = {0: "00", 1: "01", 2: "11", 3: "10"}


def verify_all(sim):
    """Check every input (A, B, Cin) against every fault location: 8 x 4 = 32 cases."""
    for a, b, cin in product([0, 1], repeat=3):
        for err in range(4):
            cout, raw_sum, syndrome = run_case(sim, a, b, cin, err)
            total = a + b + cin
            case = f"(A={a}, B={b}, Cin={cin}, err={err})"
            assert cout == total // 2, f"Cout wrong {case}"
            assert syndrome == EXPECTED_SYNDROME[err], f"Syndrome wrong {case}"
            assert decode(raw_sum, syndrome) == total % 2, f"Sum wrong {case}"
    print("All 32 cases passed")


if __name__ == "__main__":
    sim = AerSimulator()
    print("=== QUANTUM ALU WITH 3-QUBIT BIT-FLIP CODE ===")

    test_cases = [
        {"desc": "Normal (No Noise)",     "a": 1, "b": 1, "cin": 0, "err": 0},
        {"desc": "Bit-Flip on Primary",   "a": 1, "b": 1, "cin": 0, "err": 1},
        {"desc": "Bit-Flip on Ancilla 1", "a": 1, "b": 1, "cin": 0, "err": 2},
        {"desc": "Bit-Flip on Ancilla 2", "a": 1, "b": 1, "cin": 0, "err": 3},
    ]

    for tc in test_cases:
        cout, raw_sum, syndrome = run_case(sim, tc["a"], tc["b"], tc["cin"], tc["err"], shots=1024)
        corrected = decode(raw_sum, syndrome)
        print(f"[{tc['desc']}] Inputs (A={tc['a']}, B={tc['b']}, Cin={tc['cin']}) -> "
              f"Raw [Cout,Sum]: {cout}{raw_sum} | Syndrome (S1,S0): {syndrome} | "
              f"Corrected Sum: {corrected}")

    print()
    verify_all(sim)
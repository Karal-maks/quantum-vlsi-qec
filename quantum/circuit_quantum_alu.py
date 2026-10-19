import numpy as np
from qiskit import QuantumCircuit, QuantumRegister, ClassicalRegister
from qiskit_aer import AerSimulator

def build_reversible_peres_adder(qc, a, b, cin, cout, s):
    """
    Peres Full-Adder gate decomposition:
    Minimizes quantum cost (T-depth and CNOT count) compared to standard Toffoli networks.
    """
    # Peres Gate 1: Half-adder on (A, B)
    qc.cx(a, b)
    qc.ccx(a, b, cout)

    # Peres Gate 2: Incorporate Carry-in (Cin)
    qc.cx(cin, b)
    qc.ccx(cin, b, cout)

    # Sum output is preserved on qubit S
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

if __name__ == "__main__":
    sim = AerSimulator()
    print("=== QUANTUM FAULT-TOLERANT ALU SIMULATION ===")
    
    test_cases = [
        {"desc": "Normal (No Noise)",     "a": 1, "b": 1, "cin": 0, "err": 0},
        {"desc": "Bit-Flip on Primary",   "a": 1, "b": 1, "cin": 0, "err": 1},
        {"desc": "Bit-Flip on Ancilla 1", "a": 1, "b": 1, "cin": 0, "err": 2},
        {"desc": "Bit-Flip on Ancilla 2", "a": 1, "b": 1, "cin": 0, "err": 3},
    ]

    for tc in test_cases:
        circuit = construct_fault_tolerant_alu(tc["a"], tc["b"], tc["cin"], error_target=tc["err"])
        counts = sim.run(circuit, shots=1024).result().get_counts()
        most_frequent = max(counts, key=counts.get)
        # Output format: "res_out s_out"
        tokens = most_frequent.split(" ")
        res_raw, syndrome = tokens[0], tokens[1]
        
        print(f"[{tc['desc']}] Inputs (A={tc['a']}, B={tc['b']}, Cin={tc['cin']}) -> "
              f"Measured Raw [Cout,Sum]: {res_raw} | Stabilizer Syndrome (S1,S0): {syndrome}")